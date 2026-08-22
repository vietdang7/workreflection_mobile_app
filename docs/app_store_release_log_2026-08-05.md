# Nhật ký đưa app lên App Store — 05/08/2026

Ghi lại toàn bộ đường đi từ chỗ chưa có cách build iOS đến khi bản build nằm trên TestFlight, kèm các lỗi đã gặp và cách gỡ. Dùng lại khi làm bản cập nhật hoặc khi đưa app lên Google Play.

## Số liệu cố định

| Mục | Giá trị |
|---|---|
| Bundle ID | `app.workreflection.workreflectionMobile` |
| Apple ID của app | `6798188505` |
| Tên trên App Store | WorkReflection Mobile |
| Team Codemagic | DGAI Forge |
| Tên integration API key | `workreflection-asc` |
| Nhóm biến bí mật | `appstore_credentials` |
| Private key chứng chỉ | `~/keys/ios_distribution_private_key` |
| Trial Codemagic hết hạn | 19/08/2026 |
| Tài khoản demo cho reviewer | `demo.review@workreflection.app` / `WrDemo!2026Review` (uid `894bdba6-c41f-4dde-812b-2329c3bba0ac`) |

## Đã xong

- **Codemagic**: repo kết nối qua URL + PAT (không dùng GitHub App nên **không có webhook**, phải bấm build tay). `codemagic.yaml` ở gốc repo, nhánh `main`.
- **Ký ứng dụng**: chứng chỉ Distribution và App Store provisioning profile do Codemagic tự tạo qua App Store Connect API. Không cần máy Mac.
- **Build**: `flutter analyze` sạch, toàn bộ test xanh trên CI, IPA archive và upload thành công. Apple đã xử lý xong binary.
- **App Privacy**: khai 6 loại dữ liệu (Name, Email, Photos/Videos, Other User Content, User ID, Product Interaction), tất cả đều `App Functionality` + `Linked` + `No tracking`. Đã Publish.
- **Test Information**: contact, số điện thoại, tài khoản demo, `Sign-in required` đã điền.
- **Chính sách quyền riêng tư**: trang `/privacy-policy` đã có sẵn trên web; đã bổ sung 3 mục cho phần di động (xử lý bằng AI, quyền thiết bị, xoá tài khoản) trong repo web `~/Documents/DuyThong/workreflection` — **chưa commit, chưa deploy**.

## Ba lỗi đã gặp và cách gỡ

**1. `No matching profiles found for bundle identifier ... app_store`**
Khối `environment.ios_signing` chỉ *tìm* provisioning profile đã có trong Codemagic, **không tạo mới**. Tài khoản Apple chưa có profile nào nên không tìm ra gì.
→ Bỏ hẳn `ios_signing`, thay bằng chuỗi script: `keychain initialize` → `app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create` → `keychain add-certificates` → `xcode-project use-profiles`.

**2. `App Store Connect integration "workreflection-asc" does not exist`**
API key nạp ở Personal Account, còn app thuộc team DGAI Forge. Integration **không dùng chung giữa các team**.
→ Nạp lại cùng API key (cùng Issuer ID / Key ID / file `.p8`) trong đúng team chứa app.

**3. `Cannot save Signing Certificates without certificate private key`**
Bước `--create` cần biến `CERTIFICATE_PRIVATE_KEY` (RSA sinh bằng `ssh-keygen -t rsa -b 2048 -m PEM`). Biến phải nằm trong nhóm được khai ở `groups:` của yaml, nếu không sẽ không được nạp vào máy build.
→ Apple ký chứng chỉ phân phối lên **đúng private key này**. Đổi key là sinh chứng chỉ mới, mà Apple chỉ cho tối đa 3 chứng chỉ Distribution mỗi tài khoản. Giữ file key cẩn thận.

## Còn phải làm trước khi nộp review

1. Đăng nhập tài khoản demo trên app và dùng thử ~10 phút — hiện nó **trống dữ liệu**, reviewer mở lên không thấy gì.
2. **Cấp `role = 'premium'`** cho uid `894bdba6-c41f-4dde-812b-2329c3bba0ac` để reviewer xem được phần đối chiếu JD/kỹ năng.
3. Commit + deploy phần bổ sung chính sách quyền riêng tư ở repo web.
4. Dán link `https://workreflection.app/privacy-policy` vào **cả hai** chỗ: TestFlight → Test Information, và Distribution → App Information.
5. Bật Internal Testing, cài lên iPhone thật kiểm tra trước khi để Apple xem.
6. Ảnh chụp màn hình, mô tả, từ khoá, phân loại độ tuổi cho trang App Store.
7. Bật billing Codemagic trước 19/08/2026.

## Rủi ro còn treo

- **Guideline 4.8**: app có cả Google Sign-In lẫn email/password nên không rơi vào diện miễn trừ. Quyết định 05/8 là cứ nộp trước; nếu bị từ chối thì làm Sign in with Apple (capability đã bật sẵn trong App ID, chỉ cần thêm code).
- **Guideline 3.1.1**: luồng mua QR đã ẩn trên cả hai kho, nhưng chính sách trên web có nhắc SePay và lịch sử giao dịch — đã thêm câu tách bạch rằng thanh toán chỉ diễn ra trên website.
- **MCP Supabase** từng trỏ nhầm sang project `zsvisvrmfssxkytuiuun`. Project đúng là `sukpcxevcjnhiuyaoqxi`. Luôn kiểm `get_project_url` trước khi ghi dữ liệu.
