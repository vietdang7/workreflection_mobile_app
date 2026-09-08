# Hồ sơ nộp lại App Store — 08/09/2026

Mã hồ sơ bị từ chối: `4b138188-fa36-4886-8a47-23fe8a26c3bb`, bản 1.0 (6), review
06/09/2026 trên iPhone 17 Pro Max. Hai lỗi: **3.1.1** (In-App Purchase) và
**5.1.1(i)/5.1.2(i)** (xin phép trước khi gửi dữ liệu sang AI). Đọc lại nguyên
văn ngày 08/09 — Apple **không thêm mục nào mới**.

Phần mã nguồn của cả hai lỗi đã xong (PR #16 của repo app, PR #50 của repo web).
Tài liệu này chỉ ghi những việc **phải làm bằng tay trên App Store Connect** và
chữ nghĩa để dán vào.

---

## 0. Đường găng: Paid Apps Agreement đang là `New`

Mở Business → Agreements ngày 08/09/2026 thấy:

| Hợp đồng | Trạng thái |
|---|---|
| Free Apps Agreement | Active (19/8/2026 – 15/8/2027) |
| **Paid Apps Agreement** | **New — chưa ký** |

**Chưa ký thì không tạo được gói IAP nào.** Khai đúng product id, đúng giá, đúng
mọi thứ cũng vô ích: Apple không cho gói rời khỏi trạng thái nháp, app hỏi kho
sẽ nhận về danh sách rỗng, và Paywall hiện "Chưa mở bán được trên thiết bị này".

Việc này **chỉ Account Holder làm được** (tài khoản Viet Dang Quoc — Cloud &
Coral Company Limited), gồm ba phần nối nhau:

1. **Ký Paid Apps Agreement** — Business → Agreements → Paid Apps → Request.
2. **Khai thuế** — thông tin thuế Hoa Kỳ (W-8BEN-E cho công ty Việt Nam) và
   thuế Việt Nam. Apple duyệt phần này, không xong trong một lần bấm.
3. **Khai tài khoản ngân hàng nhận tiền** — tên chủ tài khoản phải khớp tên pháp
   nhân trên hợp đồng.

Phần thuế và ngân hàng thường mất **vài ngày**, không phải vài giờ. Đây là việc
dài nhất trong toàn bộ danh sách — nên bắt đầu trước mọi việc khác.

> Nhân tiện, đáng đăng ký luôn **App Store Small Business Program**: doanh thu
> dưới 1 triệu USD/năm thì Apple lấy 15% thay vì 30%. Đăng ký một lần, áp cho
> năm dương lịch. Không đăng ký là mất đúng 15% doanh thu của mỗi gói bán ra.

---

## 1. Khai hai gói trên App Store Connect

Hiện **chưa có Subscription Group nào** (kiểm 08/09). Đường đi:
App Store Connect → WorkReflection → Distribution → Subscriptions.

### Nhóm gói

| Trường | Giá trị |
|---|---|
| Reference Name | `WorkReflection Premium` |
| App Store Localization (Vietnamese) — Group Display Name | `WorkReflection Premium` |

Hai gói nằm chung một nhóm để người dùng đổi qua lại được giữa tháng và năm, và
mỗi lúc chỉ giữ một gói.

### Hai gói

Product ID phải **đúng từng ký tự**, khớp `lib/core/logic/wr_iap_catalog.dart`.
Sai một ký tự là app không tìm thấy gói, mà lỗi đó nhìn giống hệt lỗi "chưa được
duyệt" nên rất mất thì giờ mò.

| Trường | Gói năm | Gói tháng |
|---|---|---|
| Reference Name | `Premium 1 năm` | `Premium 1 tháng` |
| Product ID | `app.workreflection.mobile.premium.yearly` | `app.workreflection.mobile.premium.monthly` |
| Duration | 1 Year | 1 Month |
| Giá | bậc gần `499.000đ` nhất | bậc gần `70.000đ` nhất |

Apple bán theo **bậc giá** chứ không nhập số tự do, nên chọn bậc gần nhất với
giá web rồi kiểm lại số hiện trên máy thật. Lưu ý Apple giữ lại 15% (nếu đã vào
Small Business Program) hoặc 30% — giá bán bằng web thì tiền thực nhận ít hơn
web, đó là chuyện phải chấp nhận để qua 3.1.1.

### Chữ hiển thị (bản Vietnamese, cho cả hai gói)

Gói năm:

- **Display Name**: `Premium 1 năm`
- **Description**: `Mở toàn bộ phần trả tiền của WorkReflection trong 12 tháng:
  trò chuyện không giới hạn với trợ lý phản chiếu, đọc JD/CV để đối chiếu kỹ
  năng, mục Diễn biến theo thời gian, báo cáo phản chiếu dạng video và nghe đọc
  thành tiếng.`

Gói tháng:

- **Display Name**: `Premium 1 tháng`
- **Description**: `Mở toàn bộ phần trả tiền của WorkReflection trong 1 tháng:
  trò chuyện không giới hạn với trợ lý phản chiếu, đọc JD/CV để đối chiếu kỹ
  năng, mục Diễn biến theo thời gian, báo cáo phản chiếu dạng video và nghe đọc
  thành tiếng.`

### Ảnh chụp màn hình để duyệt

Mỗi gói cần **một ảnh chụp màn Paywall** (chụp trên máy thật hoặc Simulator,
tối thiểu 640×920). Chụp đúng màn có nút mua đang hiện giá — đó là thứ người
duyệt đối chiếu.

### Trước khi bấm gửi duyệt

Trạng thái gói phải là **"Ready to Submit"**. Gói còn thiếu ảnh, thiếu mô tả
hoặc thiếu giá sẽ nằm ở "Missing Metadata" và **không đi kèm bản build**, kết
quả là bị từ chối lại đúng lý do 3.1.1.

---

## 2. Tự động gia hạn — người dùng huỷ thế nào

Câu hỏi đặt ra ngày 08/09: nếu để tự động gia hạn thì khách có quyền từ chối gia
hạn không, và từ chối bằng cách nào.

**Có, và đó là quyền Apple bắt buộc phải có.** Người dùng tự tắt gia hạn, không
cần hỏi ai, không cần liên hệ mình:

> Cài đặt → chạm tên mình ở trên cùng → **Thuê bao** (Subscriptions) → chọn
> WorkReflection → **Huỷ đăng ký**.

Tắt lúc nào cũng được, miễn là **trước thời điểm gia hạn ít nhất 24 giờ**. Tắt
rồi thì vẫn dùng hết kỳ đã trả tiền, hết kỳ mới mất quyền — không bị cắt giữa
chừng và không bị đòi tiền kỳ sau.

Ba điểm nên biết kèm theo:

- **Mình không chặn được và cũng không cần làm gì.** Việc huỷ nằm trong hệ thống
  của Apple. App chỉ nhận kết quả: hết hạn thì `wr-verify-iap` không còn thấy
  quyền còn hiệu lực nữa và tài khoản trở về Free.
- **Hoàn tiền cũng do Apple xử.** Người dùng khiếu nại thẳng với Apple, mình
  không cầm tiền nên không hoàn được.
- Đáng thêm một dòng **"Quản lý gói đăng ký"** trong màn Tài khoản trỏ tới
  `https://apps.apple.com/account/subscriptions` — không bắt buộc, nhưng người
  duyệt và người dùng đều thích lối đi ngắn. **Chưa làm.**

So sánh với lựa chọn còn lại: **Non-Renewing Subscription** thì hết hạn là tự
dừng, người dùng muốn dùng tiếp phải mua lại. Khớp đúng mô hình VietQR bên web
(không auto-renew), nhưng đổi lại doanh thu rơi hết sau mỗi kỳ và phải sửa đoạn
chữ công bố trên Paywall. Mã backend đã xử lý được cả hai loại.

---

## 3. Thư trả lời App Review

Dán vào ô **Reply to App Review** của hồ sơ, sau khi đã khai xong gói và tải bản
build mới lên.

```
Hello,

Thank you for the detailed review. We have addressed both issues.

Guideline 3.1.1 — In-App Purchase

You are right that the demo account we provided had Premium access that was
purchased on our website, while the app itself offered no way to buy it. We have
now implemented In-App Purchase with StoreKit 2. The same Premium plan is
available for purchase inside the app:

- app.workreflection.mobile.premium.yearly (1 year)
- app.workreflection.mobile.premium.monthly (1 month)

Both are submitted together with this build. The paywall is reachable from any
Premium feature and from Account > Premium. It shows the App Store price, a
"Restore purchases" button, the auto-renewal disclosure, the Terms of Use
(Apple standard EULA) and our Privacy Policy. The app contains no external
purchase link, no QR payment flow and no pricing that points outside the app.

Guidelines 5.1.1(i) and 5.1.2(i) — data sent to a third-party AI service

The app does send user content to third-party AI services, and we have added an
in-app consent screen that appears before the first time any data leaves the
device. It is a full screen the user must read and act on — not a line in the
Terms of Service or Privacy Policy.

The screen states exactly what is sent and to whom:

- Chat with the reflection assistant: the message, earlier turns of the same
  conversation, and a summary of the user's recent reflections -> OpenRouter ->
  DeepSeek
- Uploaded job description / CV: the full text of the document -> OpenRouter ->
  Google (Gemini)
- The "Diễn biến" (timeline narrative) section: the situations the user has
  recorded -> OpenRouter -> DeepSeek
- Text-to-speech playback: the text being read aloud -> Ausynclab

The user's name, email address, password, payment details and profile photo are
never included in any of these requests.

Consent is enforced in two places: in the app before each of these flows, and
again on our server before any user data is loaded, so an older build or a
direct API call cannot bypass it. Declining is a first-class choice, we do not
ask again, and the user can turn it on or off at any time in
Account > Xử lý dữ liệu bằng AI (AI data processing).

Our privacy policy at https://www.workreflection.app/privacy-policy has been
updated to name each recipient, describe what is collected and how, list every
use of that data, and confirm the protection those services provide.

To see the consent screen, please use the demo account and open "Trò chuyện"
(Chat) from the home screen — the consent screen appears before the first
message is sent.

Thank you,
WorkReflection team
```

### Ghi vào mục App Review Information

Thêm vào ô **Notes** (mục này người duyệt đọc trước khi mở app):

```
Premium is sold in the app via In-App Purchase (auto-renewable subscriptions,
submitted with this build). The demo account starts as a free account so that
the purchase flow can be tested; use Account > Premium to reach the paywall.

The app sends user content to third-party AI services. A consent screen is shown
before the first time any data leaves the device — open "Trò chuyện" (Chat) from
the home screen to see it. Consent can be reviewed and revoked at any time in
Account > Xử lý dữ liệu bằng AI.
```

> ⚠️ Tài khoản demo `demo.review@workreflection.app`
> (`894bdba6-c41f-4dde-812b-2329c3bba0ac`) kiểm ngày 08/09 vẫn đang là
> `role = 'premium'`. **Chính điều đó gây ra lỗi 3.1.1 lần trước**: người duyệt
> đăng nhập vào là dùng được đầy đủ tính năng trả tiền mà trong app không có chỗ
> nào mua. Ngay trước khi nộp lại, hạ về gói free:
>
> ```sql
> update cc_profiles set role = 'free'
> where email = 'demo.review@workreflection.app';
> ```
>
> Người duyệt vẫn thử được đầy đủ Premium — mua bằng tài khoản Sandbox thì Apple
> không thu tiền. Đó chính là thứ cần chứng minh.
>
> Phần consent thì đã sẵn sàng: tài khoản này hiện **0 hàng** trong
> `wr_ai_consent`, nên màn xin phép sẽ hiện ra đúng lúc người duyệt mở Trò
> chuyện. Đừng đăng nhập rồi bấm đồng ý thử trên chính tài khoản đó; lỡ bấm thì
> xoá hàng consent đi trước khi nộp.

---

## 4. Thứ tự làm, không đảo được

1. Khách ký **Paid Apps Agreement** + khai thuế + khai ngân hàng → chờ Active.
   *(Bắt đầu ngay hôm nay; các bước sau đứng chờ bước này.)*
2. Merge PR #50 repo web → deploy → mở
   `workreflection.app/privacy-policy` kiểm bằng mắt.
3. Merge PR #16 repo app.
4. Khai Subscription Group + 2 gói, đủ ảnh và mô tả, tới trạng thái
   **Ready to Submit**.
5. Gỡ Premium khỏi tài khoản demo, xoá hàng consent của tài khoản đó.
6. Chạy Codemagic bản `FORCE_STORE_POLICY=app_store` → TestFlight.
7. **Chạy thử sandbox trên máy thật** — bước duy nhất kiểm được biên lai Apple
   thật, chưa ai làm được từ xa:
   - tạo Sandbox Tester, cài bản TestFlight, đăng nhập tài khoản sandbox
   - mua thử cả hai gói
   - kiểm `wr_iap_transactions` có hàng mới, `environment = 'Sandbox'`
   - kiểm `wr_entitlements` có `plan = 'premium'`, `source = 'apple_iap'`
   - gỡ app, cài lại, bấm **Khôi phục giao dịch** — quyền phải trở lại
   - mở Trò chuyện lần đầu: màn xin phép phải hiện; bấm "Để sau" thì không gửi
     gì; bật lại ở Tài khoản thì các phần AI sống lại
8. Nộp bản build mới **kèm cả hai gói**, dán thư trả lời ở mục 3.

---

## 5. Việc ngoài lần từ chối này, nhưng nên biết

Trang Business đang có băng đỏ: **chưa khai thông tin trader theo Digital
Services Act**. Không liên quan lần từ chối này, nhưng chưa khai thì app không
bán được ở Liên minh châu Âu. Nếu chỉ nhắm thị trường Việt Nam thì để sau cũng
được.

Mục **App Privacy** đã publish (7 loại dữ liệu, đều "App Functionality", không
có mục theo dõi quảng cáo) — kiểm 08/09, không phải sửa gì.

---

## Phụ lục: tin nhắn gửi khách

Chỉ Account Holder làm được phần này, nên gửi luôn hôm nay:

> Chị ơi, phần code để gỡ hai lỗi Apple từ chối đã xong cả hai. Nhưng có một
> việc chỉ chị làm được và nó là việc dài nhất, nên chị làm sớm giúp em:
>
> Trong App Store Connect, vào **Business → Agreements**, mục **Paid Apps
> Agreement** đang ở trạng thái *New* — tức là chưa ký. Chừng nào hợp đồng này
> chưa Active thì em **không tạo được gói bán trong app**, mà Apple từ chối lần
> này chính vì trong app không mua được Premium.
>
> Phần này gồm ba bước nối nhau: ký hợp đồng, khai thông tin thuế (Apple duyệt,
> không xong ngay), và khai tài khoản ngân hàng nhận tiền — tên chủ tài khoản
> phải khớp tên công ty trên hợp đồng. Thường mất vài ngày chứ không phải vài
> giờ.
>
> Nhân tiện, ngay dưới đó có **App Store Small Business Program**: doanh thu
> dưới 1 triệu USD/năm thì Apple lấy 15% thay vì 30%. Đăng ký luôn một thể, chỉ
> mất mấy phút và giữ lại được 15% doanh thu mỗi gói bán ra.
>
> Ngoài ra em cần chị chốt một chuyện: gói Premium trên iPhone để **tự động gia
> hạn** hay **không tự động**? Tự động gia hạn thì khách vẫn tự tắt được bất cứ
> lúc nào trong Cài đặt → Thuê bao, tắt rồi vẫn dùng hết kỳ đã trả; đây là loại
> Apple ưu tiên. Không tự động thì hết hạn là dừng hẳn, giống mô hình chuyển
> khoản bên web, nhưng khách phải nhớ mua lại mỗi kỳ. Em làm được cả hai, chỉ
> cần chị chốt để em khai đúng loại.
