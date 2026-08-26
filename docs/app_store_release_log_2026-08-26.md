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

## Trang bán hàng — giá trị đang dùng

Điền xong chiều 26/08. App record mới nên không chép được gì từ app cũ: bên đó
hạng mục, phân loại độ tuổi, ảnh chụp màn hình đều trống từ đầu.

| Mục | Giá trị |
|---|---|
| Hạng mục | Chính **Productivity**, phụ **Lifestyle** |
| Ảnh chụp màn hình | 5 ảnh khổ iPhone 6.5" (1284×2778), sinh lại từ `test/screenshots/app_store_test.dart` |
| Support URL | `https://www.workreflection.app/contact` |
| Content Rights | Không chứa nội dung của bên thứ ba |
| Phân loại độ tuổi | **9+** (172 nước) · 12+ Việt Nam · A10 Brazil · ALL Hàn Quốc |
| Giá | **Free** ($0.00), gốc United States (USD), 175 nước |
| Phạm vi phát hành | All Countries or Regions (175), *Available on App Release* |
| Ghi chú cho reviewer | Đã viết, xem mục "Ghi chú gửi App Review" |

Ba chỗ dễ đi sai khi làm lại:

- App Store Connect **chỉ còn một ô ảnh iPhone 6.5"** và tự dùng bộ đó cho mọi cỡ
  máy. Không phải nộp riêng khổ 6.9" như tài liệu cũ nói.
- Nạp nhiều ảnh một lượt thì **thứ tự chạy theo lúc upload xong, không theo tên
  file** — kéo thả để sắp lại cũng không ăn. Nạp từng file một thì đúng thứ tự.
- Bộ câu hỏi độ tuổi tách "Medical or Treatment Information" (chẩn đoán, quản lý
  bệnh → **None**) khỏi "Health or Wellness Topics" (tự chăm sóc, lối sống →
  **Yes**). Chọn Health & Fitness làm hạng mục chính sẽ kéo theo thủ tục khai
  *Regulated Medical Device*; Productivity thì không.

## Còn phải làm

1. **DSA trader status** — cần làm khi có mặt người mở được hộp thư
   `info@cloudncoral.com`, vì Apple gửi mã xác minh 6 số về đó và mã chỉ sống vài
   phút. Đường đi:

   1. Vào `appstoreconnect.apple.com/business`, bấm **Complete Compliance
      Requirements** trên banner đỏ.
   2. Chọn **I'm a trader under the DSA** → Next.
   3. Địa chỉ công ty Apple lấy sẵn từ Dun & Bradstreet, để nguyên (muốn sửa phải
      liên hệ D&B, không sửa tại chỗ được). Điền phần còn thiếu:
      Country Calling Code **+84 (Việt Nam)** · Contact Phone Number
      **866883047** · Contact Email **info@cloudncoral.com** → Next.
   4. Mở `info@cloudncoral.com`, lấy mã 6 số, nhập vào → xong.

   Ba thông tin này sẽ **hiện công khai** trên trang App Store — đó là yêu cầu
   của DSA, không phải lộ dữ liệu ngoài ý muốn. Bỏ qua bước này thì app vẫn nộp
   review và phát hành bình thường, chỉ là **không bán được ở EU**.

2. **Ba người test chờ nhận lời mời tài khoản** — xem mục TestFlight bên dưới.
   Khi họ bấm nhận, vào nhóm internal "Cloud & Coral" thêm họ vào là xong.

Bản 1.0 đã đổi sang **Manually release this version** (26/08) — Apple duyệt xong
app nằm chờ, tự bấm mới lên kệ.

## TestFlight — người test

Chép người từ team cũ sang, thêm thẳng vào build 1.0.0 (2) dưới dạng
**Individual Testers**:

| Email | Tên | Nguồn |
|---|---|---|
| `vuducphuong16032004@gmail.com` | Phuong Duc | TestFlight app cũ |
| `ndt20071998@gmail.com` | Thông Duy | TestFlight app cũ |
| `dung.tran@cloudncoral.com` | Dung Tran | TestFlight app cũ |
| `thuynhi1703@icloud.com` | Thuỳ Nhi Nguyễn Nhật | TestFlight app cũ |
| `anhtran8129@gmail.com` | Anh Tran Duy | Users and Access team cũ |

Bên app cũ 4 người đầu nằm trong hai nhóm "Cloud & Coral" (internal) và
"Cloud & Coral Test External". Trần Duy Anh **không có trong danh sách TestFlight**
— chỉ nằm ở Users and Access của team cũ, và bên đó cũng đang chờ nhận lời mời.

Users and Access team cũ còn hai người nữa **chưa chép sang**, chưa ai yêu cầu:
`thuyha27122015@gmail.com` (Hà Thuý) và `vudaonhatminh2495@gmail.com` (Minh Vũ).

Team khách ban đầu **không hiện mục External Testing** trong thanh bên TestFlight,
chỉ có Internal Testing. Đường vòng lúc đó: mở thẳng trang build →
**Individual Testers → Add New Testers**. Sau khi tạo nhóm internal đầu tiên thì
mục External Testing tự hiện ra — hoá ra nó bị ẩn khi app chưa có nhóm nào.

Cả 4 người ở diện external đều đứng ở trạng thái *No Builds Available*, vì
**external luôn phải chờ Beta App Review duyệt build** mới gửi thư mời. Build 2
đang trong hàng đợi đó.

Muốn có thư mời **ngay**, chỉ còn đường internal — mà internal bắt buộc tester
phải là user trong Users and Access của team khách. Ngày 26/08 làm như sau:

- Tạo nhóm internal **"Cloud & Coral"**, thêm 2 người đã có sẵn trong tài khoản:
  `thedangs7@gmail.com` và `dung.tran@cloudncoral.com` → nhận thư mời TestFlight
  ngay, cài được luôn.
- Mời 4 người còn lại vào tài khoản Apple của khách, vai trò **Developer**, quyền
  chỉ trên app WorkReflection: `vuducphuong16032004@gmail.com`,
  `ndt20071998@gmail.com`, `thuynhi1703@icloud.com`, `anhtran8129@gmail.com`.

**Chưa xong**: thư họ nhận lúc này là lời mời vào App Store Connect, *chưa phải*
thư mời TestFlight. Người đang chờ nhận lời mời **không hiện trong danh sách chọn
tester của nhóm internal** — phải đợi họ bấm nhận rồi mới thêm vào nhóm được, lúc
đó TestFlight mới gửi thư thứ hai.

Ô **What to Test** đã điền tiếng Việt, thư mời sẽ kèm nội dung đó.

## Đã nộp review — 16:30 ngày 26/08/2026

Bản **1.0 (build 2)** đang ở trạng thái *Waiting for Review*. Apple báo tối đa 48
giờ, có email khi xong.

Ô cuối cùng chặn nút Add for Review là **Copyright** — nó không nằm trong danh
sách "bắt buộc" nào hiện rõ trên trang, chỉ lộ ra khi bấm Add for Review. Đã điền
`2026 CLOUD & CORAL COMPANY LIMITED`.

Cách kiểm nhanh còn thiếu gì: cứ bấm **Add for Review**. Nút đó không nộp gì cả —
nó chạy kiểm tra rồi liệt kê ô còn trống trong khung đỏ, hoặc mở khung *Draft
Submission* bên phải. Nộp thật là nút **Submit for Review** trong khung đó.

Đã xong: App Privacy (6 loại dữ liệu, Published), Free Apps Agreement **Active**
(19/8/2026 – 15/8/2027). Paid Apps Agreement vẫn ở trạng thái *New* — không sao,
app phát hành miễn phí, tiền thu trên web.

Tài khoản demo kiểm 26/08: `role = 'premium'`, và có dữ liệu thật để reviewer
nhìn thấy màn hình không rỗng — 9 episode, 5 check-in, 3 tình huống lặp, 1 chủ đề
thực hành, 1 lượt self-check, 4 tin nhắn chat, 3 mốc dòng thời gian.

## Ghi chú gửi App Review

Nội dung đã điền ở ô Notes trang phiên bản 1.0 (tiếng Anh). Nói rõ bốn điều, để
chặn trước mấy hướng reviewer hay hỏi:

1. App miễn phí hoàn toàn, **không có in-app purchase, không có luồng mua nào**,
   và không có chỗ nào trong app quảng cáo/dẫn sang gói trả tiền.
2. Đăng nhập **chỉ bằng email/mật khẩu của hệ thống mình** — Google Sign-In đã gỡ
   khỏi giao diện (`auth_screen.dart` còn ghi chú, `signInWithGoogle()` vẫn nằm
   trong repository nhưng không nút nào gọi tới). Nhờ vậy **Guideline 4.8 không
   còn áp**, khác với đánh giá rủi ro ghi ở nhật ký 05/08.
3. Tài khoản demo là tài khoản thường, cờ premium bật ở server.
4. Ô chat AI gửi chữ người dùng sang backend của mình rồi mới gọi mô hình ngôn
   ngữ bên thứ ba; không bán dữ liệu, không dùng cho quảng cáo.

## Rủi ro còn treo

- Codemagic vẫn nằm ở tài khoản cá nhân `ngduythong1412@gmail.com`, không phải
  của khách. Build được bình thường, nhưng nếu khách muốn tự chủ hoàn toàn thì
  phải chuyển app Codemagic sang tài khoản của họ và nạp lại key.
- Key cũ `workreflection-asc` (Key `F78K35S54P`, team cá nhân) vẫn còn trong
  Codemagic. Giữ để đối chiếu, **không dùng** — nó không đọc được app bên team
  khách.
- **Guideline 4.8 đã hết rủi ro** (kiểm code 26/08): Google Sign-In không còn nút
  nào trong giao diện, app chỉ dùng hệ tài khoản email/mật khẩu của mình nên rơi
  vào diện miễn trừ. Nhật ký 05/08 ghi phải làm Sign in with Apple — nay không
  cần nữa. Nếu sau này bật lại nút Google thì rủi ro quay lại ngay.
- **Guideline 3.1.1** vẫn cần canh: hiện trong app không có chỗ nào bán, báo giá
  hay dẫn sang gói trả tiền (đã grep `lib/`, chỉ còn link đổi avatar và link đặt
  lại mật khẩu). Thêm bất kỳ lời mời mua nào vào app là vi phạm.
