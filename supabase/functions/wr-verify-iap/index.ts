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
// KHÔNG CẦN SECRET NÀO CẢ
//
// Biên lai StoreKit 2 tự kiểm chứng được bằng chuỗi chứng thư kèm trong nó —
// xem `apple_jws.ts`. SUPABASE_URL, SUPABASE_ANON_KEY và
// SUPABASE_SERVICE_ROLE_KEY do nền tảng tự cấp.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  AppleReceiptError,
  verifyAppleTransaction,
} from '../_shared/apple_jws.ts';

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
const PRODUCT_DURATION_DAYS: Record<string, number> = {
  'app.workreflection.mobile.premium.yearly': 365,
  'app.workreflection.mobile.premium.monthly': 30,
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
  if (platform !== 'ios') {
    // CH Play chưa bật IAP — khi nào bật thì thêm nhánh xác minh riêng ở đây,
    // vì Google ký biên lai theo cách hoàn toàn khác.
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

  // ── 4 · Chống dùng chung một giao dịch ──────────────────────────────────
  //
  // Khoá theo `originalTransactionId`, không phải `transactionId`: mỗi kỳ gia
  // hạn sinh ra một `transactionId` mới, nên khoá theo nó thì cùng một thuê bao
  // vẫn cấp được cho nhiều tài khoản khác nhau qua các kỳ.
  const { data: existing, error: existingError } = await db
    .from('wr_iap_transactions')
    .select('user_id')
    .eq('original_transaction_id', tx.originalTransactionId)
    .maybeSingle();

  if (existingError) {
    console.error('Không đọc được wr_iap_transactions:', existingError.message);
    return fail('Chưa xác nhận được giao dịch. Bạn thử lại sau nhé.', 500);
  }
  if (existing && existing.user_id !== user.id) {
    console.error('Giao dịch đã thuộc tài khoản khác:', tx.originalTransactionId);
    return fail('Giao dịch này đã được dùng cho một tài khoản khác.', 403);
  }

  // ── 5 · Tính hạn ────────────────────────────────────────────────────────
  const purchasedAt = tx.purchaseDate > 0 ? tx.purchaseDate : now.getTime();
  const validUntilMs = tx.expiresDate ?? purchasedAt + durationDays * DAY_MS;
  const revoked = tx.revocationDate !== undefined;
  const active = !revoked && validUntilMs > now.getTime();

  // ── 6 · Ghi nhật ký giao dịch ───────────────────────────────────────────
  const { error: txError } = await db.from('wr_iap_transactions').upsert(
    {
      original_transaction_id: tx.originalTransactionId,
      transaction_id: tx.transactionId,
      user_id: user.id,
      platform: 'ios',
      product_id: tx.productId,
      purchased_at: new Date(purchasedAt).toISOString(),
      expires_at: new Date(validUntilMs).toISOString(),
      revoked_at: tx.revocationDate
        ? new Date(tx.revocationDate).toISOString()
        : null,
      environment: tx.environment ?? null,
      updated_at: now.toISOString(),
    },
    { onConflict: 'original_transaction_id' },
  );

  if (txError) {
    console.error('Không ghi được wr_iap_transactions:', txError.message);
    return fail('Chưa xác nhận được giao dịch. Bạn thử lại sau nhé.', 500);
  }

  if (revoked) {
    return fail('Giao dịch này đã được hoàn tiền nên không còn hiệu lực.', 400);
  }
  if (!active) {
    return fail('Gói này đã hết hạn.', 400);
  }

  // ── 7 · Cấp quyền ───────────────────────────────────────────────────────
  //
  // Không rút ngắn hạn đang có. Người dùng có thể vừa mua gói tháng trong khi
  // gói năm mua trước đó còn hạn — ghi đè bằng ngày ngắn hơn là cướp mất phần
  // họ đã trả tiền.
  const { data: current } = await db
    .from('wr_entitlements')
    .select('valid_until')
    .eq('user_id', user.id)
    .maybeSingle();

  const currentUntil = current?.valid_until
    ? Date.parse(current.valid_until as string)
    : 0;
  const finalUntil = Math.max(
    validUntilMs,
    Number.isNaN(currentUntil) ? 0 : currentUntil,
  );

  const row = {
    user_id: user.id,
    plan: 'premium',
    valid_until: new Date(finalUntil).toISOString(),
    source: 'apple_iap',
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
});
