// Edge Function `wr-google-notifications` — nhận Real-time Developer
// Notifications (RTDN) của Google Play qua Pub/Sub push.
//
// ---------------------------------------------------------------------------
// VÌ SAO CÓ HÀM NÀY
//
// Cùng lý do với `wr-apple-notifications`: `wr_entitlements.valid_until` chỉ
// được nới khi app gửi giao dịch lên `wr-verify-iap` — tức là khi người dùng MỞ
// APP. Người mua gói năm, tới kỳ gia hạn mà một tuần sau mới mở app thì suốt
// tuần đó bị coi là hết hạn dù Google đã trừ tiền. Ngược lại, người được hoàn
// tiền vẫn giữ Premium tới hết kỳ nếu không ai báo cho máy chủ.
//
// Google báo mọi thay đổi trạng thái thuê bao vào một Pub/Sub topic; topic đó
// có một push subscription đẩy thẳng vào hàm này.
//
// ---------------------------------------------------------------------------
// XÁC THỰC BẰNG `?token=` — VÀ VÌ SAO KHÔNG TIN NỘI DUNG THÔNG BÁO
//
// Pub/Sub push không mang JWT của Supabase, nên hàm này phải deploy với
// `--no-verify-jwt` (giống `wr-apple-notifications`). Thay vào đó URL push mang
// một bí mật `?token=<GOOGLE_PLAY_RTDN_TOKEN>`; sai là 401.
//
// Khác Apple, thông báo của Google KHÔNG có chữ ký. Token trong URL chỉ chứng
// minh "người gọi biết URL", không chứng minh nội dung là thật. Nên nội dung
// thông báo chỉ được dùng như một cái chuông: nó nói "token X vừa đổi trạng
// thái", còn trạng thái thật thì hỏi lại Google bằng subscriptionsv2.get. Kẻ
// biết được URL cũng chỉ làm được một việc là bắt máy chủ đồng bộ lại sớm.
//
// Ngoại lệ duy nhất là SUBSCRIPTION_REVOKED: API không có trường "đã thu hồi",
// nên loại thông báo đó được dùng — nhưng chỉ khi Google xác nhận thuê bao
// cũng đã thôi được hưởng.
//
// ---------------------------------------------------------------------------
// MÃ TRẠNG THÁI TRẢ VỀ
//
// Pub/Sub coi MỌI phản hồi không phải 2xx là thất bại và gửi lại tới 7 ngày.
// Nên thông báo hỏng / không liên quan / không biết của ai vẫn trả 200 — gửi
// lại bao nhiêu lần cũng thế. Chỉ trả 5xx khi thử lại thì có thể khỏi: lỗi ghi
// DB, Google trục trặc tạm thời, hoặc thiếu cấu hình (sửa xong thì các lần gửi
// lại sẽ qua).

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  fetchPlaySubscription,
  GooglePlayConfigError,
  GooglePlayTokenError,
  isPlayEntitled,
} from '../_shared/google_play.ts';

/// PHẢI khớp `applicationId` trong `android/app/build.gradle` và
/// `ANDROID_PACKAGE_NAME` trong `wr-verify-iap`.
const ANDROID_PACKAGE_NAME = 'app.workreflection.mobile';

/// `subscriptionNotification.notificationType` = SUBSCRIPTION_REVOKED: Google đã
/// hoàn tiền VÀ thu hồi quyền trước hạn.
const NOTIFICATION_SUBSCRIPTION_REVOKED = 12;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

const iso = (ms: number) => new Date(ms).toISOString();

/// So hai chuỗi không lộ thời gian: so `===` dừng ở ký tự sai đầu tiên, đo
/// thời gian phản hồi là đoán dần được bí mật.
function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  const n = Math.max(x.length, y.length);
  for (let i = 0; i < n; i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

function decodeBase64Json(data: string): Record<string, unknown> | null {
  try {
    const bin = atob(data);
    const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
    const parsed = JSON.parse(new TextDecoder().decode(bytes));
    return parsed && typeof parsed === 'object' ? parsed : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  // ── 1 · Xác thực bằng token trong URL ───────────────────────────────────
  const expected = Deno.env.get('GOOGLE_PLAY_RTDN_TOKEN') ?? '';
  if (!expected) {
    // 500 chứ không 401: đây là lỗi của mình. Đặt secret xong thì các lần
    // Pub/Sub gửi lại sẽ qua, không mất thông báo nào.
    console.error('CẤU HÌNH: thiếu secret GOOGLE_PLAY_RTDN_TOKEN.');
    return json({ error: 'not_configured' }, 500);
  }
  const given = new URL(req.url).searchParams.get('token') ?? '';
  if (!timingSafeEqual(given, expected)) {
    console.error('Thông báo RTDN sai token.');
    return json({ error: 'unauthorized' }, 401);
  }

  // ── 2 · Mở phong bì Pub/Sub ─────────────────────────────────────────────
  let notification: Record<string, unknown> | null = null;
  try {
    const body = await req.json();
    const data = body?.message?.data;
    if (typeof data === 'string') notification = decodeBase64Json(data);
  } catch {
    notification = null;
  }
  if (!notification) {
    console.error('Thông báo RTDN không đọc được.');
    return json({ ok: true, skipped: 'unreadable' });
  }

  if (notification.packageName !== ANDROID_PACKAGE_NAME) {
    console.error('Thông báo RTDN của app khác:', notification.packageName);
    return json({ ok: true, skipped: 'wrong_package' });
  }

  // Nút "Gửi thông báo thử" trong Play Console.
  if (notification.testNotification) {
    console.log('Nhận thông báo thử từ Play Console.');
    return json({ ok: true, handled: 'test' });
  }

  // Thông báo thuê bao, hoặc thông báo giao dịch bị huỷ (hoàn tiền) của một
  // thuê bao (productType 1). Cả hai đều chỉ dùng để biết token nào cần đồng bộ.
  const subN = notification.subscriptionNotification as Record<string, unknown> | undefined;
  const voided = notification.voidedPurchaseNotification as Record<string, unknown> | undefined;

  let purchaseToken = '';
  let notificationType: number | null = null;
  let label = '';
  if (subN && typeof subN.purchaseToken === 'string') {
    purchaseToken = subN.purchaseToken;
    notificationType = typeof subN.notificationType === 'number' ? subN.notificationType : null;
    label = `subscription/${notificationType ?? '?'}`;
  } else if (voided && typeof voided.purchaseToken === 'string' && voided.productType === 1) {
    purchaseToken = voided.purchaseToken;
    label = 'voided';
  }

  if (!purchaseToken) {
    // Sản phẩm mua một lần, hoặc loại thông báo mới chưa xử lý.
    return json({ ok: true, skipped: 'not_a_subscription' });
  }

  const db = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // ── 3 · Tìm chủ của thuê bao ────────────────────────────────────────────
  //
  // Khác bên Apple, KHÔNG dựng hàng mới từ `obfuscatedExternalAccountId`: hàng
  // mới là việc của `wr-verify-iap`, nơi có người dùng đã đăng nhập và đủ các
  // lớp chặn dùng chung. Chưa có hàng nghĩa là app chưa gửi giao dịch lên —
  // app sẽ gửi khi mở, lúc đó quyền được cấp theo trạng thái mới nhất.
  const { data: existing, error: readError } = await db
    .from('wr_iap_transactions')
    .select('user_id, platform')
    .eq('original_transaction_id', purchaseToken)
    .maybeSingle();

  if (readError) {
    console.error('Không đọc được wr_iap_transactions:', readError.message);
    return json({ error: 'db_read_failed' }, 500);
  }
  if (!existing) {
    return json({ ok: true, skipped: 'unknown_subscription' });
  }
  if (existing.platform !== 'android') {
    console.error('Token RTDN trùng khoá một giao dịch không phải Android:', label);
    return json({ ok: true, skipped: 'not_android' });
  }
  const userId = existing.user_id as string;

  // ── 4 · Hỏi Google trạng thái thật ──────────────────────────────────────
  const now = new Date();
  const nowMs = now.getTime();
  let sub;
  try {
    sub = await fetchPlaySubscription(ANDROID_PACKAGE_NAME, purchaseToken);
  } catch (e) {
    if (e instanceof GooglePlayTokenError) {
      // Google không còn nhận token này (thường là thuê bao đã hết hạn quá
      // lâu). Gửi lại cũng thế.
      console.error('Google không nhận token trong thông báo:', label);
      return json({ ok: true, skipped: 'token_gone' });
    }
    console.error(
      e instanceof GooglePlayConfigError ? 'CẤU HÌNH Google Play chưa đúng:' : 'Lỗi khi hỏi Google Play:',
      e instanceof Error ? e.message : e,
    );
    return json({ error: 'google_unavailable' }, 500);
  }

  const entitled = isPlayEntitled(sub.subscriptionState, sub.expiryTimeMs, nowMs);

  // Thu hồi chỉ được ghi khi Google cũng xác nhận thuê bao đã thôi được hưởng.
  // Thông báo không có chữ ký; một thông báo REVOKED giả mạo gửi tới thuê bao
  // đang ACTIVE sẽ không cắt được quyền của ai.
  const revoked = notificationType === NOTIFICATION_SUBSCRIPTION_REVOKED && !entitled;
  if (notificationType === NOTIFICATION_SUBSCRIPTION_REVOKED && entitled) {
    console.error('Nhận REVOKED nhưng Google vẫn báo thuê bao còn hiệu lực:', sub.subscriptionState);
  }
  const revokedAtMs = revoked ? nowMs : null;

  // ── 5 · Ghi lại trạng thái ──────────────────────────────────────────────
  const row: Record<string, unknown> = {
    last_notification_type: label,
    last_notification_at: now.toISOString(),
    updated_at: now.toISOString(),
    environment: sub.environment,
  };
  if (sub.latestOrderId) row.transaction_id = sub.latestOrderId;
  if (sub.productId) row.product_id = sub.productId;
  if (sub.expiryTimeMs !== null) row.expires_at = iso(sub.expiryTimeMs);
  if (sub.autoRenewEnabled !== null) row.auto_renew = sub.autoRenewEnabled;
  // Chỉ GHI dấu thu hồi, không xoá: thông báo gia hạn tới sau một lần thu hồi
  // không có nghĩa là lần thu hồi đó chưa từng xảy ra.
  if (revokedAtMs !== null) row.revoked_at = iso(revokedAtMs);

  // `update` chứ không `upsert`: hàng chắc chắn đã có (bước 3), và update
  // không bao giờ vô tình tạo hàng thiếu `user_id`.
  const { error: writeError } = await db
    .from('wr_iap_transactions')
    .update(row)
    .eq('original_transaction_id', purchaseToken);

  if (writeError) {
    console.error('Không ghi được wr_iap_transactions:', writeError.message);
    return json({ error: 'db_write_failed' }, 500);
  }

  // ── 6 · Cập nhật quyền ──────────────────────────────────────────────────
  //
  // Đúng luật của `wr-apple-notifications`:
  //
  //   • GIA HẠN → nới hạn, không rút ngắn hạn đang có.
  //   • THU HỒI / HẾT HẠN → cắt, nhưng CHỈ khi quyền đang tới từ
  //     `google_play`. Người có Premium từ web hoặc App Store rồi mua thêm trên
  //     Play, tới lúc Google hoàn tiền mà cắt luôn là cướp phần họ đã trả nơi
  //     khác.
  const { data: current } = await db
    .from('wr_entitlements')
    .select('valid_until, source')
    .eq('user_id', userId)
    .maybeSingle();

  const currentUntil = current?.valid_until
    ? Date.parse(current.valid_until as string)
    : 0;
  const safeCurrentUntil = Number.isNaN(currentUntil) ? 0 : currentUntil;

  const endsAtMs = sub.expiryTimeMs;
  const effectiveEndMs = revoked ? revokedAtMs! : endsAtMs;

  if (effectiveEndMs === null) {
    return json({ ok: true, handled: label, entitlement: 'unchanged' });
  }

  // Bên Apple chỉ cần so mốc hết hạn. Bên Google còn phải xét trạng thái: ON_HOLD
  // hay PAUSED có thể vẫn mang `expiryTime` cũ, nhưng người dùng đã thôi được
  // hưởng — mà mốc đó đã nằm ở quá khứ nên phép so dưới đây cũng tự ra "cắt".
  // Chiều nới thì đòi `entitled`: không nới hạn cho một thuê bao Google nói là
  // không được hưởng.
  const cutting = revoked || effectiveEndMs <= nowMs;
  if (!cutting && !entitled) {
    return json({ ok: true, handled: label, entitlement: 'unchanged' });
  }
  if (cutting && current?.source !== 'google_play') {
    return json({ ok: true, handled: label, entitlement: 'kept_other_source' });
  }

  const validUntilMs = cutting
    ? effectiveEndMs
    : Math.max(effectiveEndMs, safeCurrentUntil);

  const { error: entError } = await db.from('wr_entitlements').upsert(
    {
      user_id: userId,
      plan: 'premium',
      valid_until: iso(validUntilMs),
      source: 'google_play',
      updated_at: now.toISOString(),
    },
    { onConflict: 'user_id' },
  );

  if (entError) {
    console.error('Không ghi được wr_entitlements:', entError.message);
    return json({ error: 'db_write_failed' }, 500);
  }

  return json({
    ok: true,
    handled: label,
    entitlement: cutting ? 'cut' : 'extended',
  });
});
