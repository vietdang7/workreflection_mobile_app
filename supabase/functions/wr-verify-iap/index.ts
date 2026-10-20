// Edge Function `wr-verify-iap` — xác minh biên lai In-App Purchase rồi cấp
// quyền Premium.
//
// ---------------------------------------------------------------------------
// VÌ SAO CÓ HÀM NÀY
//
// App Store từ chối bản 1.0 (6) ngày 06/09/2026 theo Guideline 3.1.1: app cho
// dùng Premium mua từ web, mà gói đó lại không mua được bằng IAP trong app.
// Muốn bán bằng IAP thì phải có chỗ nào đó biến "người dùng vừa trả tiền cho
// Apple" thành "hàng `wr_entitlements` có plan = premium". Đây là chỗ đó.
//
// Không có đường nào làm việc này ở phía app. Bảng `wr_entitlements` cố ý chỉ
// cho chủ sở hữu SELECT (migration `20260722000000_wr_two_layer_v1_2.sql`) —
// client mà ghi được vào đấy thì ai cũng tự cấp Premium cho mình bằng vài dòng
// gọi REST, và toàn bộ chuyện bán hàng thành trang trí.
//
// ⚠️ Bài học `wr_pattern_narratives`: RLS ở bảng đó ghi chú "AI backend ghi",
// nhưng suốt một tháng không hề có backend nào ghi thật, nên bảng rỗng và ba
// màn hình đọc nó đều trống. Hàm này phải được DEPLOY và chạy thử thật, không
// phải chỉ tồn tại trong repo.
//
// ---------------------------------------------------------------------------
// SECRET
//
// iOS không cần secret nào: biên lai StoreKit 2 tự kiểm chứng được bằng chuỗi
// chứng thư kèm trong nó — xem `apple_jws.ts`.
//
// Android CẦN `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: `purchaseToken` của Google
// không tự chứng minh được gì, phải cầm nó đi hỏi Google Play Developer API —
// xem `google_play.ts`. Thiếu secret thì nhánh Android trả 500 và ghi log rõ,
// nhánh iOS vẫn chạy bình thường.
//
// SUPABASE_URL, SUPABASE_ANON_KEY và SUPABASE_SERVICE_ROLE_KEY do nền tảng tự
// cấp.

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import {
  AppleReceiptError,
  verifyAppleTransaction,
} from '../_shared/apple_jws.ts';
import {
  fetchPlaySubscription,
  GooglePlayConfigError,
  GooglePlayTokenError,
  isPlayEntitled,
  playInactiveMessage,
  SUBSCRIPTION_STATE,
} from '../_shared/google_play.ts';

// ---------------------------------------------------------------------------
// Cấu hình
// ---------------------------------------------------------------------------

/// Bundle id của bản iOS.
///
/// PHẢI khớp `kIosBundleId` trong `lib/core/logic/wr_iap_catalog.dart` và
/// `PRODUCT_BUNDLE_IDENTIFIER` trong `ios/Runner.xcodeproj/project.pbxproj`.
/// Không so trường này thì biên lai mua một app Apple khác — cũng do Apple ký
/// thật, cũng qua được mọi lớp kiểm chữ ký — sẽ đổi được thành Premium ở đây.
const IOS_BUNDLE_ID = 'app.workreflection.mobile';

/// Package name của bản Android (`applicationId` trong
/// `android/app/build.gradle`).
///
/// Khác Apple, đây không phải trường để so mà là tham số của lời gọi API: hỏi
/// Google "token này của app nào" bằng chính package của mình, nên token mua ở
/// app khác sẽ bị Google trả 404 thay vì lọt qua.
const ANDROID_PACKAGE_NAME = 'app.workreflection.mobile';

/// Thời hạn dự phòng của từng gói, tính bằng ngày.
///
/// Bản sao của `kWrIapProducts` bên Dart. Cố ý chép chứ không chia sẻ: app và
/// hàm này chạy hai runtime khác nhau, mà quan trọng hơn là danh sách phía máy
/// chủ phải là danh sách quyết định — app gửi lên product id gì cũng không
/// thêm được gói mới vào đây.
///
/// Chỉ dùng khi biên lai không có `expiresDate`. Gói tự động gia hạn thì Apple
/// luôn trả `expiresDate` và con số đó mới đúng: Apple có thể tặng thêm ngày
/// (đền bù sự cố, gia hạn khuyến mãi) mà app không hề biết.
///
const PRODUCT_DURATION_DAYS: Record<string, number> = {
  'app.workreflection.mobile.premium.yearly': 365,
  'app.workreflection.mobile.premium.monthly': 30,
};

/// Danh mục bên Google Play. Gói năm trùng mã App Store; gói tháng phải khác vì
/// Play giới hạn product id 40 ký tự (`…premium.monthly` dài 41). Bản sao của
/// `kIapMonthlyPlayProductId` bên Dart.
const PLAY_PRODUCT_DURATION_DAYS: Record<string, number> = {
  'app.workreflection.mobile.premium.yearly': 365,
  'app.workreflection.mobile.premium.month': 30,
};

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const DAY_MS = 24 * 60 * 60 * 1000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

/// Câu báo lỗi hiển thị thẳng cho người dùng: tiếng Việt, không mã lỗi, không
/// tên hệ thống. Người đang cầm điện thoại không làm gì được với "JWS x5c".
function fail(userMessage: string, status: number) {
  return json({ error: userMessage }, status);
}

// ---------------------------------------------------------------------------
// Phần chung của hai kho: chống dùng chung · ghi sổ · cấp quyền
// ---------------------------------------------------------------------------

/// Giao dịch ĐÃ được kho tương ứng xác nhận, quy về một hình dạng chung.
///
/// Tách ra để luật chống dùng chung và luật "không rút ngắn hạn đang có" chỉ
/// nằm ở một chỗ. Hai bản sao của cùng một luật là hai bản sẽ lệch nhau, và
/// lệch ở đây là cấp Premium cho người không trả tiền.
interface VerifiedPurchase {
  platform: 'ios' | 'android';

  /// Khoá thuê bao, giữ nguyên qua các kỳ gia hạn. Apple: originalTransactionId.
  /// Google: purchaseToken.
  originalTransactionId: string;

  /// Mã của kỳ gần nhất. Apple: transactionId. Google: latestOrderId.
  transactionId: string;

  productId: string;
  purchasedAtMs: number;
  validUntilMs: number;
  revoked: boolean;

  /// Giá trị ghi vào `revoked_at`. `undefined` = KHÔNG đụng tới cột này (xem
  /// nhánh Android: chỉ `wr-google-notifications` mới biết thu hồi).
  revokedAt?: string | null;

  environment: string | null;

  /// `undefined` = không đụng tới cột `auto_renew`. Biên lai Apple không mang
  /// thông tin này (nó tới từ `wr-apple-notifications`), Google thì có.
  autoRenew?: boolean | null;

  active: boolean;

  /// Câu báo khi `active` = false mà không phải do bị thu hồi.
  inactiveMessage: string;

  entitlementSource: 'apple_iap' | 'google_play';
}

async function recordAndGrant(
  db: SupabaseClient,
  userId: string,
  p: VerifiedPurchase,
  now: Date,
): Promise<Response> {
  // ── 4 · Chống dùng chung một giao dịch ──────────────────────────────────
  //
  // Khoá theo `originalTransactionId`, không phải `transactionId`: mỗi kỳ gia
  // hạn sinh ra một `transactionId` mới, nên khoá theo nó thì cùng một thuê bao
  // vẫn cấp được cho nhiều tài khoản khác nhau qua các kỳ.
  const { data: existing, error: existingError } = await db
    .from('wr_iap_transactions')
    .select('user_id')
    .eq('original_transaction_id', p.originalTransactionId)
    .maybeSingle();

  if (existingError) {
    console.error('Không đọc được wr_iap_transactions:', existingError.message);
    return fail('Chưa xác nhận được giao dịch. Bạn thử lại sau nhé.', 500);
  }
  if (existing && existing.user_id !== userId) {
    console.error('Giao dịch đã thuộc tài khoản khác:', p.originalTransactionId);
    return fail('Giao dịch này đã được dùng cho một tài khoản khác.', 403);
  }

  // ── 6 · Ghi nhật ký giao dịch ───────────────────────────────────────────
  const txRow: Record<string, unknown> = {
    original_transaction_id: p.originalTransactionId,
    transaction_id: p.transactionId,
    user_id: userId,
    platform: p.platform,
    product_id: p.productId,
    purchased_at: new Date(p.purchasedAtMs).toISOString(),
    expires_at: new Date(p.validUntilMs).toISOString(),
    environment: p.environment,
    updated_at: now.toISOString(),
  };
  // Upsert của PostgREST chỉ cập nhật những cột có mặt trong hàng gửi lên, nên
  // bỏ hẳn khoá là cách "giữ nguyên giá trị đang có".
  if (p.revokedAt !== undefined) txRow.revoked_at = p.revokedAt;
  if (p.autoRenew !== undefined) txRow.auto_renew = p.autoRenew;

  const { error: txError } = await db
    .from('wr_iap_transactions')
    .upsert(txRow, { onConflict: 'original_transaction_id' });

  if (txError) {
    console.error('Không ghi được wr_iap_transactions:', txError.message);
    return fail('Chưa xác nhận được giao dịch. Bạn thử lại sau nhé.', 500);
  }

  if (p.revoked) {
    return fail('Giao dịch này đã được hoàn tiền nên không còn hiệu lực.', 400);
  }
  if (!p.active) {
    return fail(p.inactiveMessage, 400);
  }

  // ── 7 · Cấp quyền ───────────────────────────────────────────────────────
  //
  // Không rút ngắn hạn đang có. Người dùng có thể vừa mua gói tháng trong khi
  // gói năm mua trước đó còn hạn — ghi đè bằng ngày ngắn hơn là cướp mất phần
  // họ đã trả tiền.
  const { data: current } = await db
    .from('wr_entitlements')
    .select('valid_until')
    .eq('user_id', userId)
    .maybeSingle();

  const currentUntil = current?.valid_until
    ? Date.parse(current.valid_until as string)
    : 0;
  const finalUntil = Math.max(
    p.validUntilMs,
    Number.isNaN(currentUntil) ? 0 : currentUntil,
  );

  const row = {
    user_id: userId,
    plan: 'premium',
    valid_until: new Date(finalUntil).toISOString(),
    source: p.entitlementSource,
    updated_at: now.toISOString(),
  };

  const { error: entError } = await db
    .from('wr_entitlements')
    .upsert(row, { onConflict: 'user_id' });

  if (entError) {
    console.error('Không ghi được wr_entitlements:', entError.message);
    return fail('Đã nhận được giao dịch nhưng chưa mở khoá được. Bạn thử lại sau nhé.', 500);
  }

  return json({ entitlement: row });
}

// ---------------------------------------------------------------------------
// Nhánh Google Play
// ---------------------------------------------------------------------------

async function verifyAndroid(
  db: SupabaseClient,
  userId: string,
  purchaseToken: string,
  now: Date,
): Promise<Response> {
  // ── 3 · Hỏi Google trạng thái thật của token ────────────────────────────
  //
  // Không tin product id app gửi kèm: app nói mua gói năm thì vẫn phải hỏi
  // Google token này là gói gì.
  let sub;
  try {
    sub = await fetchPlaySubscription(ANDROID_PACKAGE_NAME, purchaseToken);
  } catch (e) {
    if (e instanceof GooglePlayTokenError) {
      return fail(e.message, 400);
    }
    if (e instanceof GooglePlayConfigError) {
      console.error('CẤU HÌNH Google Play chưa đúng:', e.message);
    } else {
      console.error('Lỗi khi hỏi Google Play:', e);
    }
    return fail('Chưa xác nhận được giao dịch. Bạn thử lại sau nhé.', 500);
  }

  // Đang chờ thanh toán (chuyển khoản, nạp thẻ cào…) thì chưa có đồng nào về
  // tay — dừng trước khi ghi sổ. Khi Google xác nhận, app nhận lại giao dịch
  // ở trạng thái đã mua và gửi lên lần nữa.
  if (
    sub.subscriptionState === SUBSCRIPTION_STATE.PENDING ||
    sub.subscriptionState === SUBSCRIPTION_STATE.PENDING_PURCHASE_CANCELED
  ) {
    return fail(playInactiveMessage(sub.subscriptionState), 400);
  }

  const durationDays = PLAY_PRODUCT_DURATION_DAYS[sub.productId];
  if (durationDays === undefined) {
    console.error('Product id Play không nằm trong danh mục:', sub.productId);
    return fail('Gói này không còn được bán.', 400);
  }

  // `obfuscatedExternalAccountId` là id người dùng Supabase mà app gửi qua
  // `applicationUserName` lúc mua — cùng vai trò `appAccountToken` bên Apple.
  // Có mà lệch là token của tài khoản khác. Không có thì rơi xuống lớp chặn
  // theo sổ (ai nhận giao dịch trước thì giữ).
  if (
    sub.obfuscatedExternalAccountId &&
    sub.obfuscatedExternalAccountId.toLowerCase() !== userId.toLowerCase()
  ) {
    console.error('obfuscatedExternalAccountId lệch với người gọi:', sub.latestOrderId);
    return fail('Giao dịch này thuộc về một tài khoản khác.', 403);
  }

  // Nâng/hạ gói hoặc đăng ký lại sau khi huỷ, Google cấp một `purchaseToken`
  // MỚI và trỏ ngược về token cũ qua `linkedPurchaseToken`. Không kiểm chỗ này
  // thì một thuê bao Google đã gắn với tài khoản A chỉ cần đổi gói một lần là
  // "sạch" — token mới chưa có trong sổ — rồi cấp được cho tài khoản B. Token
  // cũ chưa có trong sổ thì không có gì để so, để lớp chặn ở bước 4 lo.
  if (sub.linkedPurchaseToken) {
    const { data: linked, error: linkedError } = await db
      .from('wr_iap_transactions')
      .select('user_id')
      .eq('original_transaction_id', sub.linkedPurchaseToken)
      .maybeSingle();
    if (linkedError) {
      console.error('Không đọc được wr_iap_transactions:', linkedError.message);
      return fail('Chưa xác nhận được giao dịch. Bạn thử lại sau nhé.', 500);
    }
    if (linked && linked.user_id !== userId) {
      console.error('Token cũ của thuê bao thuộc tài khoản khác:', sub.latestOrderId);
      return fail('Giao dịch này đã được dùng cho một tài khoản khác.', 403);
    }
  }

  // ── 5 · Tính hạn ────────────────────────────────────────────────────────
  //
  // `expiryTime` của Google mới là mốc đúng (ân hạn, đổi gói, khuyến mãi đều
  // đã tính vào). Số ngày theo gói chỉ để có cái ghi vào sổ khi Google không
  // trả mốc — trường hợp đó `isPlayEntitled` đã coi là không được hưởng.
  const nowMs = now.getTime();
  const purchasedAt = sub.startTimeMs ?? nowMs;
  const validUntilMs = sub.expiryTimeMs ?? purchasedAt + durationDays * DAY_MS;

  return recordAndGrant(db, userId, {
    platform: 'android',
    // Token Play giữ nguyên qua mọi kỳ gia hạn — đúng vai trò của
    // `originalTransactionId` bên Apple.
    originalTransactionId: sub.purchaseToken,
    transactionId: sub.latestOrderId ?? sub.purchaseToken,
    productId: sub.productId,
    purchasedAtMs: purchasedAt,
    validUntilMs,
    // subscriptionsv2 không có trường "đã thu hồi" đáng tin: thuê bao bị hoàn
    // tiền chỉ hiện là EXPIRED với `expiryTime` ở quá khứ, và trạng thái + mốc
    // hết hạn đã đủ để không cấp quyền. `revoked_at` do
    // `wr-google-notifications` ghi khi nhận SUBSCRIPTION_REVOKED — nên ở đây
    // không đụng tới, kẻo xoá mất dấu thu hồi đã ghi.
    revoked: false,
    revokedAt: undefined,
    environment: sub.environment,
    autoRenew: sub.autoRenewEnabled,
    active: isPlayEntitled(sub.subscriptionState, sub.expiryTimeMs, nowMs),
    inactiveMessage: playInactiveMessage(sub.subscriptionState),
    entitlementSource: 'google_play',
  }, now);
}

// ---------------------------------------------------------------------------

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return fail('Yêu cầu không hợp lệ.', 405);
  }

  // ── 1 · Xác thực ────────────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return fail('Cần đăng nhập để xác nhận giao dịch.', 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const authClient = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: userData, error: authError } = await authClient.auth.getUser();
  const user = userData?.user;
  if (authError || !user) {
    return fail('Phiên đăng nhập đã hết hạn. Bạn đăng nhập lại nhé.', 401);
  }

  // ── 2 · Đọc yêu cầu ─────────────────────────────────────────────────────
  let receipt: string;
  let platform: string;
  try {
    const body = await req.json();
    receipt = typeof body?.receipt === 'string' ? body.receipt.trim() : '';
    platform = typeof body?.platform === 'string' ? body.platform : 'ios';
  } catch {
    return fail('Yêu cầu không hợp lệ.', 400);
  }

  if (!receipt) {
    return fail('Thiếu biên lai giao dịch.', 400);
  }
  if (platform === 'android') {
    // Với Android, `receipt` là `purchaseToken`. Google không ký biên lai như
    // Apple nên đi một nhánh riêng — xem `verifyAndroid`.
    const db = createClient(
      supabaseUrl,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { persistSession: false } },
    );
    return verifyAndroid(db, user.id, receipt, new Date());
  }
  if (platform !== 'ios') {
    return fail('Kho ứng dụng này chưa hỗ trợ mua trong app.', 400);
  }

  // ── 3 · Kiểm biên lai ───────────────────────────────────────────────────
  const now = new Date();
  let tx;
  try {
    tx = await verifyAppleTransaction(receipt, now);
  } catch (e) {
    if (e instanceof AppleReceiptError) {
      console.error('Biên lai không hợp lệ:', e.message);
      return fail(e.message, 400);
    }
    console.error('Lỗi khi kiểm biên lai:', e);
    return fail('Chưa xác nhận được giao dịch. Bạn thử lại sau nhé.', 500);
  }

  if (tx.bundleId !== IOS_BUNDLE_ID) {
    console.error('Biên lai của app khác:', tx.bundleId);
    return fail('Biên lai này không thuộc về ứng dụng WorkReflection.', 400);
  }

  const durationDays = PRODUCT_DURATION_DAYS[tx.productId];
  if (durationDays === undefined) {
    console.error('Product id không nằm trong danh mục:', tx.productId);
    return fail('Gói này không còn được bán.', 400);
  }

  // `appAccountToken` là id người dùng Supabase mà app gửi kèm lúc mua. Có mà
  // lệch nghĩa là biên lai của tài khoản khác — chặn thẳng. Không có thì rơi
  // xuống lớp chặn ở bước 4 (ai nhận giao dịch trước thì giữ).
  if (
    tx.appAccountToken &&
    tx.appAccountToken.toLowerCase() !== user.id.toLowerCase()
  ) {
    console.error('appAccountToken lệch với người gọi:', tx.transactionId);
    return fail('Giao dịch này thuộc về một tài khoản khác.', 403);
  }

  const db = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  // ── 5 · Tính hạn ────────────────────────────────────────────────────────
  //
  // (Tính trước bước 4 vì giờ bước 4 nằm trong `recordAndGrant`. Chỉ là phép
  // tính trên biên lai, không đọc DB, nên đổi thứ tự không đổi kết quả.)
  const purchasedAt = tx.purchaseDate > 0 ? tx.purchaseDate : now.getTime();
  const validUntilMs = tx.expiresDate ?? purchasedAt + durationDays * DAY_MS;
  const revoked = tx.revocationDate !== undefined;
  const active = !revoked && validUntilMs > now.getTime();

  // ── 4, 6, 7 · Chống dùng chung · ghi sổ · cấp quyền ─────────────────────
  return recordAndGrant(db, user.id, {
    platform: 'ios',
    originalTransactionId: tx.originalTransactionId,
    transactionId: tx.transactionId,
    productId: tx.productId,
    purchasedAtMs: purchasedAt,
    validUntilMs,
    revoked,
    revokedAt: tx.revocationDate
      ? new Date(tx.revocationDate).toISOString()
      : null,
    environment: tx.environment ?? null,
    // Không đụng `auto_renew`: biên lai Apple không mang thông tin này.
    autoRenew: undefined,
    active,
    inactiveMessage: 'Gói này đã hết hạn.',
    entitlementSource: 'apple_iap',
  }, now);
});
