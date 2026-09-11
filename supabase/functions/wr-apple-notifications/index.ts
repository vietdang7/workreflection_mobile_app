// Edge Function `wr-apple-notifications` — nhận App Store Server Notifications
// V2 của Apple.
//
// ---------------------------------------------------------------------------
// VÌ SAO CÓ HÀM NÀY
//
// Khách chốt 08/09/2026 bán gói tự động gia hạn, kèm yêu cầu "phải thông báo
// nếu gần hết hạn". Hai chuyện app KHÔNG tự biết được, và thiếu chuyện nào thì
// lời nhắc cũng sai:
//
//   1. NGƯỜI DÙNG ĐÃ TẮT GIA HẠN CHƯA. Biên lai giao dịch chỉ nói kỳ vừa mua
//      kết thúc lúc nào. Với người vẫn bật gia hạn, câu đúng là "sắp bị trừ tiền
//      kỳ tiếp" chứ không phải "sắp hết hạn".
//
//   2. KỲ MỚI ĐÃ ĐƯỢC GIA HẠN CHƯA. `wr_entitlements.valid_until` chỉ được cập
//      nhật khi app nhận được giao dịch mới từ StoreKit — tức là khi người dùng
//      MỞ APP. Người mua gói năm, tới hạn gia hạn mà một tuần sau mới mở app thì
//      suốt tuần đó bị coi là hết hạn dù đã trả tiền.
//
// Apple gọi thẳng vào hàm này mỗi khi thuê bao đổi trạng thái, nên hai chuyện
// trên được biết ngay cả khi app đóng.
//
// ---------------------------------------------------------------------------
// KHÔNG XÁC THỰC BẰNG JWT — VÀ VÌ SAO VẪN AN TOÀN
//
// Apple gọi vào đây bằng một POST trần, không mang token của ai cả. Nên hàm này
// phải deploy với `verify_jwt = false`, khác mọi hàm còn lại của dự án.
//
// Chỗ đứng của niềm tin không nằm ở ai gọi mà ở CHỮ KÝ trong thân yêu cầu: nội
// dung là JWS do Apple ký ES256, kèm chuỗi chứng thư bắc về Apple Root CA G3 đã
// ghim cứng trong `_shared/apple_jws.ts`. Ai gọi cũng được, nhưng không ai giả
// được chữ ký đó. Ngược lại, có JWT hợp lệ mà chữ ký sai thì vẫn bị từ chối.
//
// ⚠️ Vì thế đừng bao giờ tin bất cứ trường nào nằm NGOÀI phần đã kiểm chữ ký.
// Cả `originalTransactionId` lẫn `bundleId` đều đọc từ payload đã kiểm, không
// đọc từ query string hay header.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  AppleReceiptError,
  verifyAppleJws,
  verifyAppleRenewalInfo,
  verifyAppleTransaction,
} from '../_shared/apple_jws.ts';

/// PHẢI khớp `kIosBundleId` trong `lib/core/logic/wr_iap_catalog.dart`.
///
/// Không so trường này thì thông báo của một app Apple khác — cũng do Apple ký
/// thật — cũng sửa được dữ liệu thuê bao ở đây.
const IOS_BUNDLE_ID = 'app.workreflection.mobile';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

const iso = (ms: number) => new Date(ms).toISOString();

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  // ── 1 · Đọc và kiểm chữ ký lớp ngoài ────────────────────────────────────
  let signedPayload: string;
  try {
    const body = await req.json();
    signedPayload =
      typeof body?.signedPayload === 'string' ? body.signedPayload : '';
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  if (!signedPayload) {
    return json({ error: 'missing_signed_payload' }, 400);
  }

  const now = new Date();
  let outer: Record<string, unknown>;
  try {
    outer = await verifyAppleJws(signedPayload, now);
  } catch (e) {
    // 400 chứ không 500: chữ ký sai thì Apple gửi lại bao nhiêu lần cũng vẫn
    // sai. Trả 500 là tự chuốc một chuỗi gọi lại vô ích trong 5 ngày.
    console.error(
      'Thông báo không do Apple ký:',
      e instanceof AppleReceiptError ? e.message : e,
    );
    return json({ error: 'invalid_signature' }, 400);
  }

  const notificationType = String(outer.notificationType ?? '');
  const subtype = outer.subtype ? String(outer.subtype) : null;
  const data = (outer.data ?? {}) as Record<string, unknown>;

  if (data.bundleId !== IOS_BUNDLE_ID) {
    console.error('Thông báo của app khác:', data.bundleId);
    return json({ error: 'wrong_bundle' }, 400);
  }

  // ── 2 · Kiểm hai JWS lồng bên trong ─────────────────────────────────────
  //
  // Mỗi phần lại là một JWS ký riêng. Kiểm từng phần chứ không tin lớp ngoài đã
  // kiểm: lớp ngoài chỉ chứng minh Apple ký cái phong bì.
  let tx = null;
  let renewal = null;
  try {
    if (typeof data.signedTransactionInfo === 'string') {
      tx = await verifyAppleTransaction(data.signedTransactionInfo, now);
    }
    if (typeof data.signedRenewalInfo === 'string') {
      renewal = await verifyAppleRenewalInfo(data.signedRenewalInfo, now);
    }
  } catch (e) {
    console.error(
      'Nội dung thông báo không kiểm được:',
      e instanceof AppleReceiptError ? e.message : e,
    );
    return json({ error: 'invalid_payload' }, 400);
  }

  if (tx && tx.bundleId !== IOS_BUNDLE_ID) {
    console.error('Giao dịch trong thông báo thuộc app khác:', tx.bundleId);
    return json({ error: 'wrong_bundle' }, 400);
  }

  const originalTransactionId =
    tx?.originalTransactionId ?? renewal?.originalTransactionId ?? '';
  if (!originalTransactionId) {
    console.error('Thông báo không có mã thuê bao:', notificationType);
    return json({ ok: true, skipped: 'no_transaction' });
  }

  const db = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // ── 3 · Tìm chủ của thuê bao ────────────────────────────────────────────
  const { data: existing, error: readError } = await db
    .from('wr_iap_transactions')
    .select('user_id, expires_at')
    .eq('original_transaction_id', originalTransactionId)
    .maybeSingle();

  if (readError) {
    console.error('Không đọc được wr_iap_transactions:', readError.message);
    // 500 để Apple gửi lại — lỗi này thử lại thì khỏi.
    return json({ error: 'db_read_failed' }, 500);
  }

  // Chưa có hàng nào là chuyện bình thường ở thông báo SUBSCRIBED: Apple có thể
  // gọi vào đây trước khi app kịp gửi biên lai lên `wr-verify-iap`. Lấy chủ sở
  // hữu từ `appAccountToken` — app gửi id người dùng Supabase vào đó lúc mua, và
  // trường này nằm trong phần Apple đã ký nên tin được.
  const userId = existing?.user_id ??
    (tx?.appAccountToken && UUID_RE.test(tx.appAccountToken)
      ? tx.appAccountToken
      : null);

  if (!userId) {
    // Không dựng được liên hệ với tài khoản nào. Trả 200: gửi lại cũng thế, và
    // khi người dùng mở app thì `wr-verify-iap` sẽ tạo hàng.
    console.error(
      'Thông báo không gắn được với tài khoản nào:',
      notificationType,
      originalTransactionId,
    );
    return json({ ok: true, skipped: 'unknown_subscription' });
  }

  // ── 4 · Ghi lại trạng thái ──────────────────────────────────────────────
  //
  // Mốc kết thúc kỳ hiện tại. Ưu tiên `expiresDate` của giao dịch; gói tự động
  // gia hạn thì Apple luôn trả trường này. `renewalDate` chỉ dùng khi thông báo
  // không kèm giao dịch nào.
  const endsAtMs = tx?.expiresDate ?? renewal?.renewalDate ?? null;
  const revokedAtMs = tx?.revocationDate ?? null;

  const row: Record<string, unknown> = {
    original_transaction_id: originalTransactionId,
    user_id: userId,
    platform: 'ios',
    last_notification_type: subtype
      ? `${notificationType}/${subtype}`
      : notificationType,
    last_notification_at: now.toISOString(),
    updated_at: now.toISOString(),
  };
  if (tx) {
    row.transaction_id = tx.transactionId;
    row.product_id = tx.productId;
    if (tx.purchaseDate > 0) row.purchased_at = iso(tx.purchaseDate);
    row.environment = tx.environment ?? null;
  }
  if (endsAtMs !== null) row.expires_at = iso(endsAtMs);
  row.revoked_at = revokedAtMs !== null ? iso(revokedAtMs) : null;
  if (renewal) {
    row.auto_renew = renewal.autoRenew;
    row.auto_renew_product_id = renewal.autoRenewProductId ?? null;
    row.expiration_intent = renewal.expirationIntent ?? null;
  }

  // Hàng mới cần đủ `transaction_id` và `product_id` vì hai cột đó NOT NULL.
  // Thông báo không kèm giao dịch (chỉ đổi trạng thái gia hạn) mà lại chưa có
  // hàng thì không dựng nổi — bỏ qua, `wr-verify-iap` sẽ tạo khi app mở lên.
  if (!existing && !tx) {
    return json({ ok: true, skipped: 'no_transaction_to_create_row' });
  }

  const { error: writeError } = await db
    .from('wr_iap_transactions')
    .upsert(row, { onConflict: 'original_transaction_id' });

  if (writeError) {
    console.error('Không ghi được wr_iap_transactions:', writeError.message);
    return json({ error: 'db_write_failed' }, 500);
  }

  // ── 5 · Cập nhật quyền ──────────────────────────────────────────────────
  //
  // Hai chiều, và chiều nào cũng có bẫy riêng:
  //
  //   • GIA HẠN → nới hạn. Không rút ngắn hạn đang có: người dùng có thể vừa
  //     mua gói tháng trong khi gói năm còn hạn.
  //   • HOÀN TIỀN / HẾT HẠN → cắt. Nhưng CHỈ cắt khi quyền đang tới từ
  //     `apple_iap`. Người mua Premium bên web rồi mua thêm trong app, tới lúc
  //     Apple hoàn tiền mà cắt luôn thì cướp mất phần họ đã trả cho web.
  const { data: current } = await db
    .from('wr_entitlements')
    .select('valid_until, source')
    .eq('user_id', userId)
    .maybeSingle();

  const currentUntil = current?.valid_until
    ? Date.parse(current.valid_until as string)
    : 0;
  const safeCurrentUntil = Number.isNaN(currentUntil) ? 0 : currentUntil;

  const revoked = revokedAtMs !== null;
  const effectiveEndMs = revoked ? revokedAtMs! : endsAtMs;

  if (effectiveEndMs === null) {
    return json({ ok: true, handled: notificationType, entitlement: 'unchanged' });
  }

  const cutting = revoked || effectiveEndMs <= now.getTime();
  if (cutting && current?.source !== 'apple_iap') {
    return json({ ok: true, handled: notificationType, entitlement: 'kept_other_source' });
  }

  const validUntilMs = cutting
    ? effectiveEndMs
    : Math.max(effectiveEndMs, safeCurrentUntil);

  const { error: entError } = await db.from('wr_entitlements').upsert(
    {
      user_id: userId,
      plan: 'premium',
      valid_until: iso(validUntilMs),
      source: 'apple_iap',
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
    handled: notificationType,
    entitlement: cutting ? 'cut' : 'extended',
  });
});
