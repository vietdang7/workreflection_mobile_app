# Bán Premium bằng In-App Purchase — 07/09/2026

Dựng để gỡ **Guideline 3.1.1** của lần từ chối 06/09/2026 (submission
`4b138188-fa36-4886-8a47-23fe8a26c3bb`, bản 1.0 (6)).

## Tại sao ẩn hết đi vẫn bị từ chối

Bản 1.0 (6) build ở chế độ `WrStorePolicy.silent`: không màn QR, không giá,
không nút sang web. Vẫn dính 3.1.1. Nguyên văn Apple:

> The app accesses digital content purchased outside the app, but that content
> isn't available to purchase using In-App Purchase.

Lý do: tài khoản demo gửi App Review có `cc_profiles.role = 'premium'` mua từ
web, nên người duyệt đăng nhập vào là dùng được đầy đủ tính năng trả tiền.
Guideline 3.1.3(b) **cho phép** dùng chéo nền tảng, nhưng kèm điều kiện gói đó
phải mua được bằng IAP ngay trong app.

Nên chỉ có hai lối ra: hoặc bán bằng IAP, hoặc bản iOS không có Premium gì cả.
Chọn lối thứ nhất.

## Đã làm

| Phần | Tệp |
|---|---|
| Danh mục gói, bundle id | `lib/core/logic/wr_iap_catalog.dart` |
| Chính sách build `appStore` | `lib/core/logic/wr_store_policy.dart` |
| Bọc plugin StoreKit | `lib/core/data/wr_iap_repository.dart` |
| Trạng thái luồng mua | `lib/features/wr/iap_providers.dart` |
| Nút mua, khôi phục, liên kết pháp lý | `lib/features/wr/presentation/wr_paywall_screen.dart` |
| Xác minh biên lai phía máy chủ | `supabase/functions/wr-verify-iap/` |
| Sổ giao dịch | `supabase/migrations/20260907000000_wr_iap_transactions.sql` |
| Cờ build bản nộp | `codemagic.yaml` |
| Test | `test/features/wr_iap_test.dart` (23 test) |

Migration **đã push**, Edge Function **đã deploy và chạy thử thật** trên project
`sukpcxevcjnhiuyaoqxi`.

### Đổi tên có chủ đích

`WrStorePolicy.allowsInAppPurchase` → **`allowsVietQrCheckout`**. Trường đó
trước giờ mang nghĩa "mở màn QR chuyển khoản", không phải IAP. Để nguyên tên cũ
cạnh `allowsNativeIap` là bẫy: hai thứ ngược nhau hoàn toàn về mặt luật (QR là
thứ 3.1.1 CẤM, IAP là thứ 3.1.1 BẮT BUỘC).

### Hai chuyện phát hiện lúc làm, đáng nhớ

**1. `node:crypto` của Supabase Edge Runtime cài dở dang.**
Bản đầu của `apple_jws.ts` dùng `X509Certificate` của `node:crypto`. Chạy ở máy
(Deno 2.8.1) thì đúng, deploy lên thì 500:

```
Error [ERR_NOT_IMPLEMENTED]: Not implemented:
crypto.X509Certificate.prototype.raw
  at ext:deno_node/internal/crypto/x509.ts:88:5
```

Edge Runtime chạy một bản Deno cũ hơn. Đã chuyển sang `npm:@peculiar/x509` —
TypeScript thuần trên WebCrypto, không đụng polyfill node. **Bài học chung: chạy
được ở máy không có nghĩa là chạy được trên Edge Runtime, phải thử trên đó.**

**2. Plugin bật StoreKit 2 vô điều kiện.**
`in_app_purchase_storekit` 0.4.12 đặt `_useStoreKit2 = true` và không kiểm
phiên bản hệ điều hành. SK2 đòi iOS 15. Sàn iOS của app đã nâng **13.0 → 15.0**
(`ios/Podfile`, `ios/Runner.xcodeproj/project.pbxproj`). Không nâng thì máy iOS
13/14 cài được app nhưng mua xong không nhận được quyền — biên lai SK1 là app
receipt base64, không phải JWS, nên `wr-verify-iap` từ chối. Nâng sàn gần như
không mất ai: mọi máy chạy được iOS 13 đều lên được iOS 15.

## Xác minh biên lai — không cần App Store Connect API key

Tài khoản Apple của khách cấp cho ta vai trò **App Manager**, mà vai trò đó
không tạo được API key `.p8` (đã thử 26/08). Nên không dùng App Store Server API.

Thay vào đó dùng chính đặc tính của StoreKit 2: mỗi giao dịch là một **JWS** ký
ES256, kèm chuỗi chứng thư trong header `x5c`. Backend bắc chuỗi đó về **Apple
Root CA G3** đã ghim cứng trong mã nguồn rồi kiểm chữ ký. Không khoá bí mật,
không gọi mạng, không phụ thuộc quyền trên App Store Connect.

Bốn lớp kiểm, thiếu lớp nào cũng thủng:

1. Chứng thư gốc trong `x5c` khớp từng byte với Apple Root CA G3 đã ghim.
2. Chứng thư còn hạn, và từng mắt xích lá→trung gian→gốc ký đúng cho nhau.
3. Chữ ký ES256 của JWS khớp khoá công khai của chứng thư lá.
4. `bundleId` trong payload đúng là `app.workreflection.mobile` — **lớp này
   không bỏ được**: biên lai mua một app Apple khác cũng do Apple ký thật và
   cũng qua được ba lớp trên.

Cộng thêm hai lớp chống gian lận ở tầng dữ liệu:

- `appAccountToken` (app gửi kèm id người dùng Supabase lúc mua) phải khớp
  người đang gọi.
- `wr_iap_transactions.original_transaction_id` là khoá chính, nên một thuê bao
  không cấp được cho hai tài khoản. Khoá theo `original_transaction_id` chứ
  không phải `transaction_id`: mỗi kỳ gia hạn sinh mã mới.

### Đã chạy thử những gì

Cục bộ (Deno), dựng chuỗi 3 chứng thư tự ký rồi ghim tạm gốc đó:

| Trường hợp | Kết quả |
|---|---|
| Chuỗi hợp lệ, gốc khớp | chấp nhận, đọc đúng payload |
| Cùng JWS đó, ghim gốc Apple thật | từ chối — "không do Apple ký" |
| Sửa payload | từ chối — "chữ ký không khớp" |
| `alg: none` | từ chối |

Trên Edge Runtime thật: nhánh từ chối chạy đúng qua `wr-verify-iap`; nhánh
**chấp nhận** đã kiểm bằng một hàm tự-kiểm tạm thời (`wr-iap-selftest`, đã xoá
sau khi kiểm) để chắc `@peculiar/x509` bắc được chuỗi và kiểm được chữ ký trong
môi trường đó.

Còn **chưa** chạy qua biên lai Apple thật — việc đó chỉ làm được ở bước sandbox
trên TestFlight, xem dưới.

## Còn phải làm tay — KHÔNG có cái nào bỏ được

### 1. Khai gói trên App Store Connect

Chưa có gói nào tồn tại bên Apple. `queryProductDetails` sẽ trả về rỗng và
Paywall hiện "Chưa mở bán được trên thiết bị này" cho tới khi khai xong.

Product ID phải **đúng từng ký tự** với `lib/core/logic/wr_iap_catalog.dart`:

| Product ID | Thời hạn |
|---|---|
| `app.workreflection.mobile.premium.yearly` | 1 năm |
| `app.workreflection.mobile.premium.monthly` | 1 tháng |

Kèm theo: Subscription Group, tên hiển thị, mô tả, giá theo bậc của Apple, và
ảnh chụp màn hình review cho mỗi gói.

> ⚠️ **Cần bạn chốt: gói tự động gia hạn hay không?**
> Tôi đang viết chữ trên Paywall theo hướng **Auto-Renewable Subscription** (câu
> "Gói tự động gia hạn cho tới khi bạn tắt…" là bắt buộc với loại này). Đây
> khác với mô hình VietQR hiện tại — chuyển khoản thì không gia hạn được nên
> `cc_products` không auto-renew.
> Nếu khách muốn giữ đúng "không tự động gia hạn" thì khai
> **Non-Renewing Subscription** và phải sửa lại đoạn chữ đó. Mã backend đã xử lý
> được cả hai (có `expiresDate` thì dùng, không có thì cộng số ngày trong danh
> mục).

### 2. Điều khoản sử dụng

Paywall đang trỏ tới **EULA mẫu của Apple**
(`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`) vì
workreflection.app chưa có trang điều khoản riêng. Apple chấp nhận đường dẫn
này. Nếu khách có trang riêng thì đổi `kAppleStandardEulaUrl` trong
`wr_paywall_screen.dart`.

Chính sách quyền riêng tư đã trỏ đúng
`https://www.workreflection.app/privacy-policy`.

### 3. Thoả thuận thuế và ngân hàng

Mục **Agreements, Tax, and Banking** phải ở trạng thái Active thì gói mới bán
được. Chưa ký là gói không bao giờ hiện ra, kể cả khai đúng hết.

### 4. Chạy thử sandbox trên máy thật

Đây là bước **chưa ai làm được từ xa** và là chỗ duy nhất kiểm được biên lai
Apple thật:

1. Tạo Sandbox Tester trong App Store Connect.
2. Cài bản TestFlight lên iPhone, đăng nhập tài khoản sandbox.
3. Mua thử cả hai gói.
4. Kiểm `wr_iap_transactions` có hàng mới, `environment = 'Sandbox'`.
5. Kiểm `wr_entitlements` có `plan = 'premium'`, `source = 'apple_iap'`.
6. Gỡ app, cài lại, bấm **Khôi phục giao dịch** — quyền phải trở lại.

### 5. Trả lời App Review

Ngoài 3.1.1 còn **lỗi 5.1.1(i)/5.1.2(i)** về gửi dữ liệu sang AI bên thứ ba.
Phần đó **đã làm xong cùng ngày** — xem `docs/app_store_ai_consent_2026-09-07.md`.
Nhưng nó còn một việc nằm ngoài repo này chưa xong: **cập nhật trang
`/privacy-policy` bên web**. Đó là điều kiện thứ tư trong bốn điều kiện của
Apple, thiếu nó thì nộp lại vẫn trượt đúng lý do cũ.
