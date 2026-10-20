// Kiểm thuê bao Google Play bằng Google Play Developer API (subscriptionsv2).
//
// ---------------------------------------------------------------------------
// VÌ SAO KHÁC HẲN `apple_jws.ts`
//
// Biên lai StoreKit 2 là một JWS tự kiểm chứng được: có chuỗi chứng thư bắc về
// Apple Root CA, nên máy chủ không cần hỏi ai cả. `purchaseToken` của Google thì
// KHÔNG mang thông tin gì — nó chỉ là cái tên để đi hỏi Google. Muốn biết token
// đó mua gói gì, hết hạn lúc nào, thuộc tài khoản nào thì PHẢI gọi
// `purchases.subscriptionsv2.get`, và lời gọi đó phải được ký bằng service
// account có quyền trong Play Console.
//
// Hệ quả: đừng bao giờ tin product id hay ngày hết hạn do app gửi lên, và đừng
// tin nội dung thông báo RTDN — chỉ tin cái Google trả về từ API.
//
// ---------------------------------------------------------------------------
// SECRET
//
// `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: nguyên văn file JSON khoá của service
// account (tải từ Google Cloud › IAM › Service accounts › Keys). Không thêm thư
// viện OAuth ngoài: JWT RS256 ký được bằng Web Crypto có sẵn trong Deno, thêm
// một phụ thuộc chỉ để ký một chuỗi là thêm một chỗ có thể hỏng lúc deploy.

const GOOGLE_TOKEN_URI = 'https://oauth2.googleapis.com/token';
const ANDROID_PUBLISHER_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

// ---------------------------------------------------------------------------
// Kiểu dữ liệu
// ---------------------------------------------------------------------------

/// Thuê bao Play đã chuẩn hoá — chỉ giữ những trường máy chủ dùng để quyết
/// định cấp quyền, để hai hàm `wr-verify-iap` và `wr-google-notifications`
/// không phải tự đọc cấu trúc lồng nhau của Google mỗi chỗ một kiểu.
export interface PlaySubscription {
  purchaseToken: string;

  /// Product id của dòng có hạn xa nhất trong `lineItems`.
  productId: string;

  /// Mốc hết hạn (ms), lấy MAX trong `lineItems`. null khi Google chưa trả
  /// (thường gặp ở trạng thái PENDING).
  expiryTimeMs: number | null;

  /// `startTime` (ms) — lúc thuê bao bắt đầu.
  startTimeMs: number | null;

  /// Nguyên văn `subscriptionState`, ví dụ `SUBSCRIPTION_STATE_ACTIVE`.
  subscriptionState: string;

  /// null = không xác định được (không có dòng nào). Gói trả trước (prepaid)
  /// thì không bao giờ tự gia hạn → false.
  autoRenewEnabled: boolean | null;

  /// Id người dùng Supabase mà app gửi qua `applicationUserName` lúc mua.
  obfuscatedExternalAccountId?: string;

  /// Mã đơn của kỳ gần nhất (`GPA.xxxx..N`) — mỗi kỳ gia hạn một mã mới.
  latestOrderId?: string;

  /// Token cũ khi người dùng nâng/hạ gói hoặc đăng ký lại.
  linkedPurchaseToken?: string;

  acknowledgementState?: string;

  /// 'Sandbox' khi Google đánh dấu `testPurchase` (tài khoản thử nghiệm giấy
  /// phép), còn lại 'Production'. Cùng hai giá trị với cột `environment` bên
  /// Apple để đối chiếu doanh thu không lẫn giao dịch thử.
  environment: 'Sandbox' | 'Production';
}

/// Token không dùng được — câu tiếng Việt hiển thị thẳng cho người dùng.
///
/// Tách riêng với lỗi cấu hình và lỗi mạng vì cách xử lý ngược nhau: token sai
/// thì thử lại bao nhiêu lần cũng sai (trả 400), còn lỗi cấu hình / mạng thì
/// sửa xong là khỏi (trả 500).
export class GooglePlayTokenError extends Error {}

/// Máy chủ chưa cấu hình đúng: thiếu secret, JSON hỏng, hoặc service account
/// chưa được cấp quyền trong Play Console. Không phải lỗi của người dùng nên
/// không bao giờ hiện nguyên văn lên app.
export class GooglePlayConfigError extends Error {}

export const SUBSCRIPTION_STATE = {
  PENDING: 'SUBSCRIPTION_STATE_PENDING',
  ACTIVE: 'SUBSCRIPTION_STATE_ACTIVE',
  PAUSED: 'SUBSCRIPTION_STATE_PAUSED',
  IN_GRACE_PERIOD: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  ON_HOLD: 'SUBSCRIPTION_STATE_ON_HOLD',
  CANCELED: 'SUBSCRIPTION_STATE_CANCELED',
  EXPIRED: 'SUBSCRIPTION_STATE_EXPIRED',
  PENDING_PURCHASE_CANCELED: 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED',
} as const;

// ---------------------------------------------------------------------------
// Phần thuần — không gọi mạng, có test trong `google_play_test.ts`
// ---------------------------------------------------------------------------

function parseTimeMs(value: unknown): number | null {
  if (typeof value !== 'string' || !value) return null;
  const ms = Date.parse(value);
  return Number.isNaN(ms) ? null : ms;
}

function nonEmpty(value: unknown): string | undefined {
  return typeof value === 'string' && value ? value : undefined;
}

/// Chuẩn hoá phản hồi `subscriptionsv2.get`.
///
/// Chọn dòng có `expiryTime` xa nhất chứ không lấy dòng đầu: một thuê bao có
/// thể có nhiều dòng (gói cộng thêm, hoặc lúc vừa đổi gói), và quyền của người
/// dùng kéo dài tới dòng muộn nhất.
export function normalizeSubscriptionV2(
  raw: Record<string, unknown>,
  purchaseToken: string,
): PlaySubscription {
  const lineItems = Array.isArray(raw.lineItems)
    ? (raw.lineItems as Record<string, unknown>[])
    : [];

  let chosen: Record<string, unknown> | null = null;
  let chosenExpiry: number | null = null;
  for (const item of lineItems) {
    if (!item || typeof item !== 'object') continue;
    const expiry = parseTimeMs(item.expiryTime);
    if (chosen === null || (expiry !== null && (chosenExpiry === null || expiry > chosenExpiry))) {
      chosen = item;
      chosenExpiry = expiry;
    }
  }

  const productId = nonEmpty(chosen?.productId) ?? '';

  // Google bỏ hẳn trường bool khi giá trị là false (JSON của proto3), nên
  // `autoRenewingPlan: {}` nghĩa là ĐÃ TẮT gia hạn, không phải "chưa biết".
  let autoRenewEnabled: boolean | null = null;
  if (chosen) {
    const plan = chosen.autoRenewingPlan as Record<string, unknown> | undefined;
    if (plan && typeof plan === 'object') {
      autoRenewEnabled = plan.autoRenewEnabled === true;
    } else if (chosen.prepaidPlan) {
      autoRenewEnabled = false;
    }
  }

  const accounts = (raw.externalAccountIdentifiers ?? {}) as Record<string, unknown>;

  return {
    purchaseToken,
    productId,
    expiryTimeMs: chosenExpiry,
    startTimeMs: parseTimeMs(raw.startTime),
    subscriptionState: nonEmpty(raw.subscriptionState) ??
      'SUBSCRIPTION_STATE_UNSPECIFIED',
    autoRenewEnabled,
    obfuscatedExternalAccountId: nonEmpty(accounts.obfuscatedExternalAccountId),
    latestOrderId: nonEmpty(raw.latestOrderId),
    linkedPurchaseToken: nonEmpty(raw.linkedPurchaseToken),
    acknowledgementState: nonEmpty(raw.acknowledgementState),
    // Có mặt là đủ: Google trả `testPurchase: {}` (rỗng) cho giao dịch thử.
    environment: raw.testPurchase !== undefined && raw.testPurchase !== null
      ? 'Sandbox'
      : 'Production',
  };
}

/// Trạng thái này có được hưởng Premium không.
///
///   • ACTIVE, IN_GRACE_PERIOD — đang hưởng. Trong thời gian ân hạn Google đã
///     kéo `expiryTime` tới hết ân hạn, nên vẫn so với mốc đó.
///   • CANCELED — người dùng đã TẮT gia hạn, nhưng phần đã trả tiền vẫn còn
///     tới `expiryTime`. Cắt ngay là cướp mất những ngày họ đã mua.
///   • ON_HOLD, PAUSED, EXPIRED, PENDING… — không.
///
/// Mọi nhánh "có" đều đòi `expiryTime` còn ở tương lai: không có mốc hết hạn
/// thì không có gì để ghi vào `wr_entitlements.valid_until`.
export function isPlayEntitled(
  state: string,
  expiryTimeMs: number | null,
  nowMs: number,
): boolean {
  if (expiryTimeMs === null || expiryTimeMs <= nowMs) return false;
  return state === SUBSCRIPTION_STATE.ACTIVE ||
    state === SUBSCRIPTION_STATE.IN_GRACE_PERIOD ||
    state === SUBSCRIPTION_STATE.CANCELED;
}

/// Câu báo cho người dùng khi thuê bao không được hưởng quyền. Mỗi trạng thái
/// một câu vì việc người dùng cần làm khác nhau: thẻ bị từ chối thì phải đi sửa
/// phương thức thanh toán, còn hết hạn thì chỉ cần mua lại.
export function playInactiveMessage(state: string): string {
  switch (state) {
    case SUBSCRIPTION_STATE.PENDING:
      return 'Giao dịch đang chờ thanh toán. Khi Google Play xác nhận xong, gói sẽ tự mở.';
    case SUBSCRIPTION_STATE.ON_HOLD:
      return 'Google Play chưa thu được tiền kỳ này. Bạn cập nhật phương thức thanh toán trong Google Play nhé.';
    case SUBSCRIPTION_STATE.PAUSED:
      return 'Gói đang tạm dừng trong Google Play.';
    case SUBSCRIPTION_STATE.PENDING_PURCHASE_CANCELED:
      return 'Giao dịch chờ thanh toán đã bị huỷ.';
    default:
      return 'Gói này đã hết hạn.';
  }
}

export interface ServiceAccount {
  clientEmail: string;
  privateKeyPem: string;
  tokenUri: string;
}

/// Đọc file JSON khoá service account. Lỗi ở đây là lỗi cấu hình, không phải
/// lỗi của người dùng.
export function parseServiceAccount(raw: string | undefined): ServiceAccount {
  if (!raw || !raw.trim()) {
    throw new GooglePlayConfigError('Thiếu secret GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.');
  }
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new GooglePlayConfigError('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON không phải JSON hợp lệ.');
  }
  const clientEmail = nonEmpty(parsed.client_email);
  const privateKeyPem = nonEmpty(parsed.private_key);
  if (!clientEmail || !privateKeyPem) {
    throw new GooglePlayConfigError(
      'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON thiếu client_email hoặc private_key.',
    );
  }
  return {
    clientEmail,
    privateKeyPem,
    tokenUri: nonEmpty(parsed.token_uri) ?? GOOGLE_TOKEN_URI,
  };
}

// ---------------------------------------------------------------------------
// Ký JWT và lấy access token
// ---------------------------------------------------------------------------

function base64UrlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  // Secret dán qua dashboard hay CLI đôi khi giữ nguyên `\n` dạng hai ký tự
  // thay vì xuống dòng thật — gỡ cả hai kiểu.
  const body = pem
    .replace(/\\n/g, '\n')
    .replace(/-----BEGIN [^-]+-----/, '')
    .replace(/-----END [^-]+-----/, '')
    .replace(/\s+/g, '');
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/// Dựng JWT assertion RS256 cho luồng OAuth "service account".
export async function signServiceAccountJwt(
  account: ServiceAccount,
  nowSec: number,
): Promise<string> {
  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      'pkcs8',
      pemToDer(account.privateKeyPem),
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign'],
    );
  } catch {
    throw new GooglePlayConfigError('private_key của service account không đọc được.');
  }

  const enc = new TextEncoder();
  const header = base64UrlEncode(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = base64UrlEncode(
    enc.encode(
      JSON.stringify({
        iss: account.clientEmail,
        scope: ANDROID_PUBLISHER_SCOPE,
        aud: account.tokenUri,
        iat: nowSec,
        exp: nowSec + 3600,
      }),
    ),
  );
  const signingInput = `${header}.${claims}`;
  const signature = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(signingInput)),
  );
  return `${signingInput}.${base64UrlEncode(signature)}`;
}

// Cache trong bộ nhớ của một instance Edge Function. Không cần chia sẻ giữa các
// instance: lấy token mới chỉ tốn một lời gọi, còn cache dài hơn một instance
// thì phải cất token ở đâu đó — thêm một chỗ lộ khoá.
let cachedToken: { value: string; expiresAtMs: number } | null = null;

async function getAccessToken(): Promise<string> {
  const nowMs = Date.now();
  // Trừ hao 60 giây để token không hết hạn giữa chừng lời gọi.
  if (cachedToken && cachedToken.expiresAtMs - 60_000 > nowMs) {
    return cachedToken.value;
  }

  const account = parseServiceAccount(Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
  const assertion = await signServiceAccountJwt(account, Math.floor(nowMs / 1000));

  const res = await fetch(account.tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const text = await res.text();
  if (!res.ok) {
    // 400/401 ở đây gần như luôn là khoá sai / service account bị xoá — lỗi
    // cấu hình. 5xx là Google trục trặc tạm thời.
    if (res.status >= 500) {
      throw new Error(`Google OAuth ${res.status}: ${text.slice(0, 300)}`);
    }
    throw new GooglePlayConfigError(`Google OAuth từ chối service account (${res.status}): ${text.slice(0, 300)}`);
  }

  let body: Record<string, unknown>;
  try {
    body = JSON.parse(text);
  } catch {
    throw new Error('Google OAuth trả về dữ liệu không đọc được.');
  }
  const value = nonEmpty(body.access_token);
  if (!value) throw new Error('Google OAuth không trả access_token.');
  const expiresIn = typeof body.expires_in === 'number' ? body.expires_in : 3600;
  cachedToken = { value, expiresAtMs: nowMs + expiresIn * 1000 };
  return value;
}

// ---------------------------------------------------------------------------
// Gọi Google Play Developer API
// ---------------------------------------------------------------------------

/// Hỏi Google trạng thái thật của một `purchaseToken`.
///
/// Ném:
///   • `GooglePlayTokenError` — token không tồn tại / không thuộc app này
///     (Google trả 400, 404, 410). Câu lỗi hiển thị được cho người dùng.
///   • `GooglePlayConfigError` — thiếu secret, khoá hỏng, service account chưa
///     có quyền (401, 403).
///   • `Error` thường — Google trục trặc tạm thời / lỗi mạng; thử lại được.
export async function fetchPlaySubscription(
  packageName: string,
  purchaseToken: string,
): Promise<PlaySubscription> {
  const accessToken = await getAccessToken();
  const url = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
    `${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/` +
    encodeURIComponent(purchaseToken);

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const text = await res.text();

  if (res.status === 400 || res.status === 404 || res.status === 410) {
    console.error(`Google Play từ chối purchaseToken (${res.status}):`, text.slice(0, 300));
    throw new GooglePlayTokenError(
      'Không tìm thấy giao dịch này trên Google Play. Bạn thử khôi phục giao dịch đã mua nhé.',
    );
  }
  if (res.status === 401 || res.status === 403) {
    // Thường là service account chưa được mời vào Play Console, hoặc chưa đủ
    // quyền "Xem thông tin tài chính" / "Quản lý đơn đặt hàng và gói thuê bao".
    // Quyền mới cấp có khi mất tới 24 giờ mới có hiệu lực.
    if (res.status === 401) cachedToken = null;
    throw new GooglePlayConfigError(
      `Service account chưa có quyền gọi Google Play Developer API (${res.status}): ${text.slice(0, 300)}`,
    );
  }
  if (!res.ok) {
    throw new Error(`Google Play Developer API ${res.status}: ${text.slice(0, 300)}`);
  }

  let raw: Record<string, unknown>;
  try {
    raw = JSON.parse(text);
  } catch {
    throw new Error('Google Play Developer API trả về dữ liệu không đọc được.');
  }
  return normalizeSubscriptionV2(raw, purchaseToken);
}
