# Nhật ký chuyển app sang tài khoản Apple của khách — 26/08/2026

Khách muốn app nằm trong tài khoản của họ, nên toàn bộ phần iOS được dựng lại từ
đầu trong team **CLOUD & CORAL COMPANY LIMITED**. Bản dựng cũ trong team cá nhân
**Quoc Viet Dang** (xem `app_store_release_log_2026-08-05.md`) coi như bỏ.

Ghi lại đủ số liệu để lần sau không phải mò lại. Lần trước nhật ký chỉ ghi
"Test Information đã điền" mà không lưu giá trị — hôm nay phải mở lại app cũ đọc
từng ô để chép sang, mất một lượt qua lại không đáng có.

## Số liệu cố định

| Mục | Giá trị |
|---|---|
| Team Apple | CLOUD & CORAL COMPANY LIMITED — `ZZDTT3X3VJ` |
| Team cũ (không dùng nữa) | Quoc Viet Dang — `4BFVKGCMCQ` |
| Bundle ID | `app.workreflection.mobile` |
| Apple ID của app | `6805322970` |
| Tên trên App Store | WorkReflection |
| SKU | `workreflection-ios` |
| Issuer ID (App Store Connect API) | `31833d86-f673-4f59-a14e-b036c56cb528` |
| API key | tên `codemagic-workreflection`, Key ID `DLFUYXK3QT`, Access **Admin** |
| File `.p8` | `~/Desktop/AuthKey_DLFUYXK3QT.p8` — Apple chỉ cho tải một lần |
| Tên integration trong Codemagic | `workreflection-asc-cloudcoral` |
| App Codemagic | `6a8ba5229cd81a393c15deaa`, tài khoản `ngduythong1412@gmail.com` (Personal) |
| Nhóm biến bí mật | `appstore_credentials` (chỉ chứa `CERTIFICATE_PRIVATE_KEY`) |
| Account Holder bên khách | `dung.tran@cloudncoral.com` |
| Tài khoản đang thao tác | `thedangs7@gmail.com` — **cần vai trò Admin** |

## Vì sao phải đổi bundle ID

Bundle ID là duy nhất trên toàn Apple. Chuỗi cũ
`app.workreflection.workreflectionMobile` đang do team cá nhân giữ, không chuyển
sang team khác được — và kể cả xoá bên đó, Apple cũng không cho đăng ký lại một
App ID đã xoá. Nên team khách đăng ký chuỗi mới.

Chuỗi mới trùng với URL scheme đăng nhập trong `ios/Runner/Info.plist`. Trùng
lành: scheme và bundle ID là hai không gian tên khác nhau, luồng OAuth Supabase
không đọc bundle ID.

Tên app cũng phải đổi: "WorkReflection Mobile" bị chính app cũ giữ, Apple báo
trùng ngay lúc bấm Create. Đặt là "WorkReflection" — đúng bằng `CFBundleDisplayName`.

## Hai chỗ chặn đã gặp

**1. Không thấy mục App Store Connect API để tạo key.**
Trang Users and Access → Integrations bên team khách chỉ hiện *Shared Secret*, và
`/access/integrations/api` đá thẳng về danh sách People. Nguyên nhân là vai trò:
`thedangs7@gmail.com` khi đó chỉ là **App Manager**. Cùng tài khoản đó, đổi sang
team cá nhân (nơi là Account Holder) thì mục này hiện đủ.
→ Nhờ Account Holder nâng lên **Admin**. Không có cách vòng nào khác; key phải do
Admin/Account Holder tạo.

Chọn Access = **Admin** cho key, đừng chọn App Manager: bước
`fetch-signing-files --create` không chỉ đọc mà còn **tạo** chứng chỉ phân phối.

**2. Build xanh nhưng post-processing đỏ ở bước nộp beta review.**

```
Failure: Complete test information is required to submit application
WorkReflection build for external testing.
App is missing required Beta App Information: Feedback Email.
App is missing required Beta App Review Information: First Name, Last Name,
Phone Number, Email.
```

Đây **không phải lỗi build**: IPA đã upload, Apple đã xử lý xong, bản build nằm
trên TestFlight ở trạng thái *Ready to Submit* và Internal Testing dùng được
ngay. Chỉ riêng việc nộp cho **External Testing** mới đòi Test Information, mà
app record vừa tạo thì hai mục đó trống.
→ Điền Test Information rồi chạy lại build. Bản build kế tiếp lên thẳng
*Waiting for Review*.

## Test Information — giá trị đang dùng

Chép nguyên từ app cũ. Đối chiếu bằng bộ đếm ký tự còn lại của hai ô văn bản:
Beta App Description còn **3289**, Review Notes còn **3180** — khớp cả hai thì
chắc chắn không rơi chữ nào.

| Ô | Giá trị |
|---|---|
| Ngôn ngữ | Vietnamese |
| Feedback Email | `thedangs7@gmail.com` |
| Marketing URL | để trống (app cũ cũng trống) |
| Privacy Policy URL | `https://www.workreflection.app/privacy-policy` |
| Contact | Thông · Nguyễn Duy · `+84 78 248 5283` · `thedangs7@gmail.com` |
| Sign-in required | có |
| User Name | `demo.review@workreflection.app` |
| Password | `WrDemo!2026Review` |

Beta App Description chứa luôn phần "What to Test" trong cùng một ô — không phải
hai trường riêng.

## Còn phải làm

1. **Trader status** (banner đỏ trên đầu App Store Connect) — thiếu là không phân
   phối được ở EU. Nay đã có quyền Admin nên tự khai được, ở mục Business.
2. **Business → Agreements** phải ở trạng thái Active.
3. **Trang bán hàng** (Distribution → App Information + phiên bản 1.0): ảnh chụp
   màn hình, mô tả, từ khoá, URL hỗ trợ, phân loại độ tuổi, hạng mục — app record
   mới nên toàn bộ đang trống.
4. **App Privacy**: khai lại 6 loại dữ liệu như bản cũ (Name, Email,
   Photos/Videos, Other User Content, User ID, Product Interaction — tất cả
   `App Functionality` + `Linked` + `No tracking`).
5. **Tài khoản demo**: kiểm lại `demo.review@workreflection.app` còn dữ liệu mẫu
   và còn `role = 'premium'` hay không, trước khi để reviewer mở.
6. Muốn cài lên iPhone thật ngay thì tạo nhóm **Internal Testing** — không cần
   Apple duyệt, không cần Test Information.

## Rủi ro còn treo

- Codemagic vẫn nằm ở tài khoản cá nhân `ngduythong1412@gmail.com`, không phải
  của khách. Build được bình thường, nhưng nếu khách muốn tự chủ hoàn toàn thì
  phải chuyển app Codemagic sang tài khoản của họ và nạp lại key.
- Key cũ `workreflection-asc` (Key `F78K35S54P`, team cá nhân) vẫn còn trong
  Codemagic. Giữ để đối chiếu, **không dùng** — nó không đọc được app bên team
  khách.
- Các rủi ro Guideline 4.8 và 3.1.1 ghi ở nhật ký 05/08 vẫn còn nguyên.
