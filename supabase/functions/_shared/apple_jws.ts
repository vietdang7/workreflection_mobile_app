// Kiểm chứng biên lai giao dịch của App Store (StoreKit 2).
//
// ---------------------------------------------------------------------------
// VÌ SAO TỰ KIỂM CHỮ KÝ MÀ KHÔNG GỌI APP STORE SERVER API
//
// App Store Server API là đường chính thống, nhưng nó đòi một App Store Connect
// API key (`.p8`) mà chỉ vai trò Account Holder hoặc Admin mới tạo được. Tài
// khoản Apple của khách cấp cho chúng ta vai trò App Manager — đã thử 26/08 và
// không có mục tạo key. Chờ khách thao tác là chặn cả bản nộp lại.
//
// May là StoreKit 2 không cần đường đó. Từ iOS 15, mỗi giao dịch được Apple trả
// về dưới dạng JWS — một JWT ký bằng ES256, kèm luôn chuỗi chứng thư trong
// header `x5c`. Ai cũng kiểm được offline: bắc chuỗi chứng thư về tới Apple Root
// CA G3 rồi kiểm chữ ký bằng khoá công khai của chứng thư lá. Không khoá bí
// mật, không gọi mạng, không phụ thuộc quyền trên App Store Connect.
//
// (StoreKit 1 thì khác hẳn — `serverVerificationData` ở đó là app receipt và
// phải gửi sang `verifyReceipt`. App này chạy StoreKit 2, mặc định của
// `in_app_purchase_storekit` từ 0.4.x. Nếu có ngày phải hạ về StoreKit 1 thì
// file này KHÔNG dùng lại được.)
//
// ---------------------------------------------------------------------------
// ⚠️ VÌ SAO KHÔNG DÙNG `node:crypto`
//
// Bản đầu của file này dùng `X509Certificate` của `node:crypto`. Chạy thử ở máy
// (Deno 2.8.1) thì đúng, deploy lên thì hỏng — Edge Runtime của Supabase chạy
// một bản Deno cũ hơn, và polyfill node của nó chưa cài `X509Certificate
// .prototype.raw`:
//
//   Error [ERR_NOT_IMPLEMENTED]: Not implemented:
//   crypto.X509Certificate.prototype.raw
//     at ext:deno_node/internal/crypto/x509.ts:88:5
//
// Bài học không phải "thiếu mỗi .raw" mà là: polyfill đó cài dở dang và không
// có gì bảo đảm thành viên nào có thành viên nào không. `@peculiar/x509` là
// TypeScript thuần chạy trên WebCrypto, không đụng tới polyfill node, nên
// những gì chạy được ở máy cũng chạy được trên Edge Runtime.
//
// ---------------------------------------------------------------------------
// KIỂM NHỮNG GÌ
//
// Bốn lớp, thiếu lớp nào cũng thủng:
//   1. Chuỗi chứng thư bắc được về đúng Apple Root CA G3 đã ghim ở dưới. Thiếu
//      lớp này thì ai cũng tự ký một JWS bằng chứng thư nhà làm.
//   2. Chứng thư còn hạn tại thời điểm kiểm.
//   3. Chữ ký ES256 khớp với khoá công khai của chứng thư lá.
//   4. `bundleId` trong payload đúng là app này — kiểm ở `index.ts`. Biên lai
//      mua app KHÁC cũng do Apple ký thật và cũng qua được ba lớp trên.

import * as x509 from 'npm:@peculiar/x509@1.12.3';

x509.cryptoProvider.set(crypto);

/// Apple Root CA - G3, dạng DER mã hoá base64.
///
/// Nguồn: https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
/// Vân tay SHA-256:
///   63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:
///   7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79
/// Hiệu lực tới 30/04/2039.
///
/// Ghim cứng chứ không tải lúc chạy: tải về nghĩa là tin vào DNS và TLS tại
/// đúng khoảnh khắc đó, mà đây lại chính là thứ neo giữ toàn bộ niềm tin. Đổi
/// hằng này là một quyết định phải rà bằng vân tay ở trên.
const APPLE_ROOT_CA_G3_BASE64 = [
  'MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9v',
  'dCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UE',
  'CgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2',
  'WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmlj',
  'YXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqG',
  'SM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxE',
  'tX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNC',
  'MEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0P',
  'AQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3m',
  'eoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkL',
  'F1vLUagM6BgD56KyKA==',
].join('');

/// Nội dung một giao dịch, sau khi đã kiểm chữ ký.
///
/// Chỉ khai những trường app thật sự dùng. Apple còn trả nhiều trường nữa; thêm
/// vào đây khi nào cần chứ không khai sẵn cho đủ bộ.
export interface AppleTransaction {
  /// Mã giao dịch, duy nhất cho mỗi lần mua.
  transactionId: string;

  /// Mã giao dịch gốc — giữ nguyên qua mọi lần tự động gia hạn. Đây mới là thứ
  /// đại diện cho "một thuê bao", còn `transactionId` đổi theo từng kỳ.
  originalTransactionId: string;

  /// Bundle id của app đã phát sinh giao dịch.
  bundleId: string;

  /// Product id đã mua.
  productId: string;

  /// Mốc mua, tính bằng mili-giây epoch.
  purchaseDate: number;

  /// Mốc hết hạn, mili-giây epoch. Không có với hàng không tiêu hao.
  expiresDate?: number;

  /// Mốc hoàn tiền / thu hồi. Có giá trị là quyền phải bị cắt.
  revocationDate?: number;

  /// UUID app gửi kèm lúc mua. App này gửi id người dùng Supabase vào đây.
  appAccountToken?: string;

  /// 'Production' hoặc 'Sandbox'.
  environment?: string;
}

/// Phần "còn gia hạn nữa hay không" của một thuê bao.
///
/// Nội dung này **không nằm trong biên lai giao dịch**: biên lai chỉ nói kỳ vừa
/// mua kết thúc lúc nào, không nói người dùng đã tắt gia hạn hay chưa. Chỉ App
/// Store Server Notifications V2 mang nó tới. Thiếu nó thì thẻ nhắc trong app
/// buộc phải nói nước đôi, mà nói "sắp hết hạn" với người vẫn đang bật gia hạn
/// là nói sai — với họ câu đúng là "sắp bị trừ tiền kỳ tiếp".
export interface AppleRenewalInfo {
  originalTransactionId: string;

  /// `true` khi Apple sẽ tự trừ tiền kỳ tiếp.
  autoRenew: boolean;

  /// Product id của kỳ tiếp. Khác `productId` hiện tại khi người dùng vừa đổi
  /// gói (tháng ↔ năm) — kỳ này vẫn chạy hết theo gói cũ.
  autoRenewProductId?: string;

  /// Mốc gia hạn kế tiếp, mili-giây epoch.
  renewalDate?: number;

  /// Vì sao thuê bao sẽ dừng: 1 người dùng tự huỷ · 2 lỗi thanh toán ·
  /// 3 không đồng ý giá mới · 4 sản phẩm không còn bán.
  expirationIntent?: number;

  environment?: string;
}

export class AppleReceiptError extends Error {}

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function decodeBase64Url(part: string): Uint8Array {
  const padded = part.replace(/-/g, '+').replace(/_/g, '/');
  const pad = padded.length % 4 === 0 ? '' : '='.repeat(4 - (padded.length % 4));
  return base64ToBytes(padded + pad);
}

function decodeJsonPart(part: string): Record<string, unknown> {
  try {
    return JSON.parse(new TextDecoder().decode(decodeBase64Url(part)));
  } catch {
    throw new AppleReceiptError('Biên lai không đọc được.');
  }
}

/// Bỏ mọi khoảng trắng để so hai chuỗi base64 theo đúng nội dung.
///
/// `x5c` của JWS không được xuống dòng, nhưng hằng ghim ở trên thì viết thành
/// nhiều dòng cho dễ đọc. Chuẩn hoá cả hai bên rồi mới so.
const stripWs = (s: string) => s.replace(/\s+/g, '');

/// Bắc chuỗi chứng thư từ lá về gốc và kiểm từng mắt xích.
///
/// `x5c` của Apple xếp theo thứ tự lá → trung gian → gốc. Vẫn kiểm từng cặp chứ
/// không tin thứ tự đó — thứ tự sai sẽ tự lộ ra ở bước kiểm chữ ký.
async function verifyCertificateChain(
  x5c: string[],
  now: Date,
): Promise<x509.X509Certificate> {
  if (x5c.length < 2) {
    throw new AppleReceiptError('Biên lai thiếu chuỗi chứng thư.');
  }

  // Gốc phải đúng bằng byte với chứng thư đã ghim. So trên chuỗi base64 chính
  // là so byte của DER, chỉ khác cách viết — mà lại không cần đọc tới trường
  // nào của thư viện, nên không phụ thuộc gì vào runtime.
  //
  // So gốc TRƯỚC khi phân tích chứng thư: chuỗi lạ thì dừng ngay, khỏi đưa dữ
  // liệu của người lạ vào bộ phân tích ASN.1.
  if (stripWs(x5c[x5c.length - 1]) !== stripWs(APPLE_ROOT_CA_G3_BASE64)) {
    throw new AppleReceiptError('Biên lai không do Apple ký.');
  }

  const chain = x5c.map((b64) => {
    try {
      return new x509.X509Certificate(base64ToBytes(stripWs(b64)));
    } catch {
      throw new AppleReceiptError('Chuỗi chứng thư của biên lai không hợp lệ.');
    }
  });

  for (let i = 0; i < chain.length; i++) {
    const cert = chain[i];
    if (cert.notBefore > now || cert.notAfter < now) {
      throw new AppleReceiptError('Chứng thư của biên lai đã hết hạn.');
    }
    // Mắt xích cuối là gốc tự ký, đã so byte ở trên nên không kiểm tiếp.
    if (i === chain.length - 1) break;

    const issuer = chain[i + 1];
    let ok = false;
    try {
      // `signatureOnly: false` để thư viện kiểm cả tên chủ thể của bên ký khớp
      // với tên bên phát hành ghi trong chứng thư con, không chỉ kiểm chữ ký.
      ok = await cert.verify({ publicKey: await issuer.publicKey.export(), date: now });
    } catch {
      ok = false;
    }
    if (!ok) {
      throw new AppleReceiptError('Chuỗi chứng thư của biên lai không khớp.');
    }
  }

  return chain[0];
}

/// Kiểm chữ ký ES256 của JWS bằng khoá công khai của chứng thư lá.
async function verifySignature(
  signingInput: string,
  signature: Uint8Array,
  leaf: x509.X509Certificate,
): Promise<boolean> {
  // Ép đúng ECDSA P-256: khoá trong chứng thư của Apple là P-256, và khai rõ ở
  // đây thì một chứng thư dùng thuật toán khác sẽ hỏng ngay tại bước nhập khoá
  // thay vì lọt xuống dưới.
  const key = await leaf.publicKey.export(
    { name: 'ECDSA', namedCurve: 'P-256' },
    ['verify'],
  );
  return crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    signature,
    new TextEncoder().encode(signingInput),
  );
}

/// Kiểm chữ ký của một JWS do Apple ký và trả về payload thô.
///
/// Dùng chung cho cả hai thứ Apple ký: biên lai giao dịch mà app gửi lên, và
/// thông báo máy-chủ-tới-máy-chủ (App Store Server Notifications V2) mà Apple
/// gọi thẳng vào ta. Hai đường đó khác nhau ở nội dung chứ **không khác gì ở
/// phần chữ ký** — cùng ES256, cùng chuỗi `x5c` bắc về Apple Root CA G3.
///
/// Hàm này chỉ trả lời đúng một câu: "Apple có ký cái này không". Nội dung bên
/// trong nói gì thì bên gọi tự đọc và tự kiểm — đặc biệt là `bundleId`, vì một
/// JWS của app Apple khác cũng do Apple ký thật.
export async function verifyAppleJws(
  jws: string,
  now: Date = new Date(),
): Promise<Record<string, unknown>> {
  const parts = jws.split('.');
  if (parts.length !== 3) {
    throw new AppleReceiptError('Biên lai không đúng định dạng.');
  }

  const header = decodeJsonPart(parts[0]);
  if (header.alg !== 'ES256') {
    // Chặn thẳng thuật toán lạ, đặc biệt là `none` — bẫy kinh điển của JWT là
    // nhận bừa alg do chính kẻ gửi khai.
    throw new AppleReceiptError('Biên lai dùng thuật toán ký không chấp nhận.');
  }
  const x5c = header.x5c;
  if (!Array.isArray(x5c) || x5c.some((c) => typeof c !== 'string')) {
    throw new AppleReceiptError('Biên lai thiếu chuỗi chứng thư.');
  }

  const leaf = await verifyCertificateChain(x5c as string[], now);

  let ok = false;
  try {
    ok = await verifySignature(
      `${parts[0]}.${parts[1]}`,
      decodeBase64Url(parts[2]),
      leaf,
    );
  } catch {
    ok = false;
  }
  if (!ok) {
    throw new AppleReceiptError('Chữ ký của biên lai không khớp.');
  }

  return decodeJsonPart(parts[1]);
}

/// Kiểm một JWS giao dịch và trả về nội dung đã tin được.
///
/// Ném [AppleReceiptError] với câu hiển thị được cho người dùng khi biên lai
/// không qua được bất kỳ lớp nào.
export async function verifyAppleTransaction(
  jws: string,
  now: Date = new Date(),
): Promise<AppleTransaction> {
  const payload = await verifyAppleJws(jws, now);
  const transactionId = payload.transactionId;
  const bundleId = payload.bundleId;
  const productId = payload.productId;
  if (
    typeof transactionId !== 'string' ||
    typeof bundleId !== 'string' ||
    typeof productId !== 'string'
  ) {
    throw new AppleReceiptError('Biên lai thiếu thông tin giao dịch.');
  }

  return {
    transactionId,
    originalTransactionId:
      typeof payload.originalTransactionId === 'string'
        ? payload.originalTransactionId
        : transactionId,
    bundleId,
    productId,
    purchaseDate:
      typeof payload.purchaseDate === 'number' ? payload.purchaseDate : 0,
    expiresDate:
      typeof payload.expiresDate === 'number' ? payload.expiresDate : undefined,
    revocationDate:
      typeof payload.revocationDate === 'number'
        ? payload.revocationDate
        : undefined,
    appAccountToken:
      typeof payload.appAccountToken === 'string'
        ? payload.appAccountToken
        : undefined,
    environment:
      typeof payload.environment === 'string' ? payload.environment : undefined,
  };
}

/// Kiểm một JWS `signedRenewalInfo` và trả về nội dung đã tin được.
export async function verifyAppleRenewalInfo(
  jws: string,
  now: Date = new Date(),
): Promise<AppleRenewalInfo> {
  const payload = await verifyAppleJws(jws, now);

  const originalTransactionId = payload.originalTransactionId;
  if (typeof originalTransactionId !== 'string') {
    throw new AppleReceiptError('Thông báo thiếu mã thuê bao.');
  }

  // `autoRenewStatus` là số 0/1 chứ không phải boolean. So `=== 1` chứ đừng ép
  // kiểu: thiếu trường thì `undefined` ép thành `false` một cách im lặng, mà ở
  // đây "không biết" và "đã tắt gia hạn" là hai chuyện phải phân biệt được.
  const autoRenewStatus = payload.autoRenewStatus;
  if (autoRenewStatus !== 0 && autoRenewStatus !== 1) {
    throw new AppleReceiptError('Thông báo thiếu trạng thái gia hạn.');
  }

  return {
    originalTransactionId,
    autoRenew: autoRenewStatus === 1,
    autoRenewProductId:
      typeof payload.autoRenewProductId === 'string'
        ? payload.autoRenewProductId
        : undefined,
    renewalDate:
      typeof payload.renewalDate === 'number' ? payload.renewalDate : undefined,
    expirationIntent:
      typeof payload.expirationIntent === 'number'
        ? payload.expirationIntent
        : undefined,
    environment:
      typeof payload.environment === 'string' ? payload.environment : undefined,
  };
}
