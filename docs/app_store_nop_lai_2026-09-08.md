# Hồ sơ nộp lại App Store — 08/09/2026

Mã hồ sơ bị từ chối: `4b138188-fa36-4886-8a47-23fe8a26c3bb`, bản 1.0 (6), review
06/09/2026 trên iPhone 17 Pro Max. Hai lỗi: **3.1.1** (In-App Purchase) và
**5.1.1(i)/5.1.2(i)** (xin phép trước khi gửi dữ liệu sang AI). Đọc lại nguyên
văn ngày 08/09 — Apple **không thêm mục nào mới**.

Phần mã nguồn của cả hai lỗi đã xong (PR #16 của repo app, PR #50 của repo web).
Tài liệu này chỉ ghi những việc **phải làm bằng tay trên App Store Connect** và
chữ nghĩa để dán vào.

---

## 0. Đường găng: Paid Apps Agreement — ĐÃ XONG 09/09/2026

> **Cập nhật 09/09/2026:** mở lại Business → Agreements thấy **Paid Apps
> Agreement Active** (hiệu lực 8/9/2026 – 15/8/2027). Ngân hàng CONG TY TNHH
> CLOUD & CORAL (0979) VND Active, W-8BEN-E + Substitute W-8BEN-E nộp 8/9
> Active, Digital Services Act Active. Chặn cứng dưới đây đã gỡ; phần còn lại
> giữ nguyên để tra cứu.

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

## 1. Khai hai gói trên App Store Connect — ĐÃ KHAI 09/09/2026

> **Đã làm 09/09:** nhóm `WorkReflection Premium` (Group ID `22370264`) và hai
> gói bên dưới. Trạng thái cả hai: **Prepare for Submission**.
>
> | Gói | Apple ID | Product ID | Duration | Giá VN | Phạm vi |
> |---|---|---|---|---|---|
> | Premium 1 nam | `6810036011` | `…premium.yearly` | 1 year | ₫499.000 | 175 nước |
> | Premium 1 thang | `6810037556` | `…premium.monthly` | 1 month | ₫70.000 | 175 nước |
>
> Cả hai bậc giá có sẵn **đúng số** — không phải chọn bậc gần đúng. Giá các nước
> khác Apple tự quy đổi (US $14.99/năm · $1.99/tháng). Localization Vietnamese
> đã khai cho cả hai; mô tả phải rút còn **≤55 ký tự** (ô Description của Apple
> giới hạn vậy), nên dùng câu ngắn chứ không phải đoạn dài ghi ở dưới. Reference
> Name để không dấu (`Premium 1 nam`/`Premium 1 thang`) vì đó là tên nội bộ; tên
> người dùng thấy nằm ở Localization và có dấu đầy đủ.
>
> **Còn thiếu đúng một thứ: ảnh chụp màn Paywall** ở mục Review Information của
> *mỗi* gói. Không có ảnh thì gói không lên được "Ready to Submit". Phải chụp
> trên máy thật hoặc Simulator — xem mục "Ảnh chụp màn hình để duyệt" bên dưới.

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

## 2. Tự động gia hạn — CHỐT, kèm lời nhắc trước hạn

**Khách chốt 08/09/2026: khai Auto-Renewable Subscription**, kèm yêu cầu "phải
thông báo nếu gần hết hạn". Phần nhắc đã dựng xong, xem mục 2b.

Câu hỏi đặt ra cùng ngày: nếu để tự động gia hạn thì khách có quyền từ chối gia
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
- Lối **"Quản lý gói đăng ký"** trỏ thẳng tới
  `https://apps.apple.com/account/subscriptions` đã nằm trong thẻ nhắc ở mục 2b.

So sánh với lựa chọn còn lại: **Non-Renewing Subscription** thì hết hạn là tự
dừng, người dùng muốn dùng tiếp phải mua lại. Khớp đúng mô hình VietQR bên web
(không auto-renew), nhưng đổi lại doanh thu rơi hết sau mỗi kỳ và phải sửa đoạn
chữ công bố trên Paywall. Mã backend đã xử lý được cả hai loại.

---

## 2b. Nhắc trước khi kỳ thuê bao kết thúc

Apple **không** tự nhắc trước mỗi kỳ gia hạn thường. Thông báo 27/7 ngày mà Apple
gửi là dành cho **đổi giá**; kỳ gia hạn bình thường chỉ có email biên lai gửi
*sau* khi đã trừ tiền. Nên muốn nhắc thì phải tự làm.

### Vì sao phải có webhook chứ không chỉ một cái `if`

Cùng một ngày trên lịch mang hai nghĩa ngược nhau:

| Trạng thái | Ngày đó nghĩa là | Câu phải nói |
|---|---|---|
| còn bật gia hạn | bị trừ tiền kỳ tiếp | "Gói tự động gia hạn ngày …" |
| đã tắt gia hạn | mất quyền | "Gói hết hạn ngày …" |

Biên lai giao dịch **không** chứa trạng thái gia hạn — nó chỉ nói kỳ vừa mua kết
thúc lúc nào. Chỗ duy nhất mang thông tin đó tới là **App Store Server
Notifications V2**.

Cái đó còn vá một lỗ khác, nặng hơn cả chuyện câu chữ: `wr_entitlements
.valid_until` chỉ được cập nhật khi app nhận được giao dịch mới từ StoreKit, tức
là khi người dùng **mở app**. Người mua gói năm, tới hạn gia hạn mà một tuần sau
mới mở app thì suốt tuần đó bị coi là hết hạn dù đã trả tiền.

### Đã dựng

| Phần | Tệp |
|---|---|
| Webhook nhận thông báo của Apple | `supabase/functions/wr-apple-notifications/` |
| Tách phần kiểm chữ ký dùng chung | `supabase/functions/_shared/apple_jws.ts` |
| Cột trạng thái gia hạn | `supabase/migrations/20260908000000_wr_iap_renewal_state.sql` |
| Quyết định nói gì, khi nào | `lib/core/logic/wr_iap_renewal.dart` |
| Thẻ nhắc (Home + Tài khoản) | `lib/core/widgets/wr_renewal_notice_card.dart` |
| Test | `test/features/wr_iap_renewal_test.dart` (15 test) |

Migration **đã push**. `wr-apple-notifications` **đã deploy**, `wr-verify-iap`
**đã deploy lại** vì đường dẫn `apple_jws.ts` đổi chỗ.

Ba trạng thái chứ không hai: `auto_renew` để `null` khi Apple chưa gửi thông báo
nào. Với gói tháng thì "chưa biết" là trạng thái của **cả tháng đầu** — trường
hợp thường gặp nhất, không phải ngoại lệ. Lúc đó thẻ nói cả hai vế thay vì đoán
bừa. Cửa sổ nhắc: 7 ngày cho người sắp bị trừ tiền, 14 ngày cho người sắp mất
quyền — người phải quyết định mua tiếp hay không thì cần nhiều thời gian hơn
người chỉ cần biết để tắt nếu muốn.

Hàm này là hàm **duy nhất** của dự án chạy với `verify_jwt = false`: Apple gọi
vào bằng một POST trần, không mang token của ai. Niềm tin nằm ở chữ ký trong
thân yêu cầu chứ không ở người gọi — cùng chuỗi `x5c` bắc về Apple Root CA G3 mà
`wr-verify-iap` đang dùng.

### Đã chạy thử trên bản deploy thật

| Trường hợp | Kết quả |
|---|---|
| POST không kèm Authorization | qua được — đúng ý, Apple không có token |
| Thân rỗng | 400 `missing_signed_payload` |
| Chuỗi chứng thư bịa | 400 `invalid_signature` |
| `alg: none` | 400 `invalid_signature` |
| GET | 405 |

Nhánh **chấp nhận** chưa chạy thử được: nó cần một thông báo do Apple ký thật, mà
nút "Request a Test Notification" lại thuộc App Store Server API — đúng thứ cần
API key `.p8`. Nhánh này sẽ tự chạy ở bước sandbox trên máy thật: mua thử xong là
Apple gửi `SUBSCRIBED`, huỷ gia hạn là gửi `DID_CHANGE_RENEWAL_STATUS`. Phần mật
mã thì đã được chứng minh qua `wr-verify-iap` — hai hàm dùng chung đúng một tệp.

### Địa chỉ webhook — ĐÃ KHAI 08/09/2026

App Store Connect → WorkReflection → **App Information** → *App Store Server
Notifications*. Cả hai ô đã điền, kiểm lại sau khi tải lại trang:

| Ô | Giá trị |
|---|---|
| Production Server URL | `https://sukpcxevcjnhiuyaoqxi.supabase.co/functions/v1/wr-apple-notifications` |
| Sandbox Server URL | **cùng** đường dẫn |

Dùng chung một địa chỉ được: hàm ghi `environment` của từng giao dịch nên vẫn
phân biệt được giao dịch sandbox với giao dịch thật lúc đối chiếu doanh thu.

Apple chỉ bắt đầu gọi vào đây khi có thuê bao thật — nên còn phải chờ tới bước
sandbox mới thấy thông báo đầu tiên.

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
  conversation, and a summary of the user's recent reflections -> Google (Gemini)
- Uploaded job description / CV: the full text of the document -> Google (Gemini)
- The "Diễn biến" (timeline narrative) section: the situations the user has
  recorded -> Google (Gemini)
- Text-to-speech playback: the text being read aloud -> Ausynclab
- The survey report: the job title, tenure and department the user entered, plus
  their survey scores, used to rephrase the commentary -> Google (Gemini)

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

1. ~~Khách ký **Paid Apps Agreement** + khai thuế + khai ngân hàng~~ → **Active
   09/09/2026.**
2. ~~Merge PR #50 repo web → deploy → mở
   `workreflection.app/privacy-policy` kiểm bằng mắt.~~ **Xong 09/09 qua PR #51.**
   PR #50 merge rồi phải revert: Vercel **chặn deploy khi người merge không có
   vai trò contributing trong project** — commit vào được `main` nhưng bản deploy
   đứng ở trạng thái `Blocked`, trang live vẫn là bản cũ mà GitHub không báo gì.
   Mở lại thành PR #51 cho người có quyền merge; deploy `55f8d89` success, đã
   kiểm tận mắt hai câu mới trên trang.
3. ~~Merge PR #16 repo app~~ → **đã merge 09/09** (commit `4029004`).
4. Khai Subscription Group + 2 gói (**Auto-Renewable**), đủ ảnh và mô tả, tới
   trạng thái **Ready to Submit**. *(Địa chỉ App Store Server Notifications ở
   mục 2b đã khai xong 08/09.)* — **khai xong 09/09 trừ ảnh Paywall**, xem mục 1.
5. Gỡ Premium khỏi tài khoản demo, xoá hàng consent của tài khoản đó.
6. ~~Chạy Codemagic bản `FORCE_STORE_POLICY=app_store` → TestFlight.~~ **Xong
   09/09:** build #7 (`iOS · TestFlight`, main, commit `4029004`) xanh hết bước,
   IPA 32.57 MB, đã đẩy lên TestFlight thành **1.0.0 (7)**.
7. **Chạy thử sandbox trên máy thật** — bước duy nhất kiểm được biên lai Apple
   thật, chưa ai làm được từ xa:
   - tạo Sandbox Tester, cài bản TestFlight, đăng nhập tài khoản sandbox
   - mua thử cả hai gói
   - kiểm `wr_iap_transactions` có hàng mới, `environment = 'Sandbox'`
   - kiểm `wr_entitlements` có `plan = 'premium'`, `source = 'apple_iap'`
   - gỡ app, cài lại, bấm **Khôi phục giao dịch** — quyền phải trở lại
   - mở Trò chuyện lần đầu: màn xin phép phải hiện; bấm "Để sau" thì không gửi
     gì; bật lại ở Tài khoản thì các phần AI sống lại
   - **tắt gia hạn trong Cài đặt → Thuê bao**, rồi kiểm
     `wr_iap_transactions.auto_renew` đã thành `false` và
     `last_notification_type` có `DID_CHANGE_RENEWAL_STATUS` — đây là lần duy
     nhất kiểm được nhánh chấp nhận của `wr-apple-notifications` trước khi phát
     hành. Sandbox chạy nhanh hơn thật: gói tháng gia hạn sau 5 phút, gói năm sau
     1 tiếng, nên ngồi đợi một lát là thấy cả `DID_RENEW`.
8. Nộp bản build mới **kèm cả hai gói**, dán thư trả lời ở mục 3.

---

## 4b. Đổi nhà cung cấp AI — 09/09/2026

Tài khoản OpenRouter hết credit và chưa nạp lại được, nên cả bốn Edge Function
chuyển sang **gọi thẳng Google (Gemini)**:

| Hàm | Trước | Sau |
|---|---|---|
| `wr-chat` | `deepseek-v4-flash-0731` qua OpenRouter | `gemini-3.1-flash-lite` |
| `wr-narrative` | `deepseek-v4-flash-0731` qua OpenRouter | `gemini-3.1-flash-lite` |
| `ai-personalize` | `gemini-3.1-flash-lite-preview` qua OpenRouter | `gemini-3.1-flash-lite` |
| `wr-doc-analyze` | `gemini-2.5-flash` qua OpenRouter | `gemini-2.5-flash` (endpoint gốc) |

Ba điều đáng ghi lại:

**Giá hai bên bằng nhau đúng từng cent.** OpenRouter bán lại đúng giá gốc của
Google ($0.30/$2.50 cho 2.5-flash, $0.25/$1.50 cho 3.1-flash-lite); họ chỉ ăn
phí lúc nạp tiền. Nên đây là chuyện dòng tiền, không phải tối ưu chi phí.

**Gemini 3.x "nghĩ trước khi trả lời", và phần nghĩ ĐẾM VÀO `max_tokens`.**
Để nguyên `max_tokens: 300` của `wr-chat` mà không tắt thì model tiêu sạch ngân
sách vào phần người dùng không bao giờ đọc rồi trả về **chuỗi rỗng** — hỏng im
lặng, không ném lỗi. Phải đặt `reasoning_effort: 'none'` (bản tương thích
OpenAI) hoặc `thinkingConfig.thinkingBudget: 0` (endpoint gốc).

**PDF không mất.** `wr-doc-analyze` từng nhờ bộ đọc PDF của OpenRouter
(`plugins: file-parser`), thứ đó là của riêng họ. Nhưng Gemini tự đọc PDF qua
`inline_data` ở endpoint gốc, đọc được cả bản scan vì nó nhìn trang giấy như
hình — đã thử thật với một PDF một trang, trả đúng tên và chức danh. Đổi lại,
hàm này là nơi duy nhất trong dự án phải nói tiếng Google thay vì tiếng OpenAI.

Kèm theo: bản công bố trong app lên **version 3**, danh sách bên nhận rút từ bốn
tên xuống còn **Google (Gemini)** và **Ausynclab**. Thư trả lời ở mục 3 đã sửa
theo. Trang privacy web cũng phải sửa cho khớp — nếu không là khai sai.

Secret cần đặt trước khi deploy: `GEMINI_API_KEY`.

---

## 5. Việc ngoài lần từ chối này, nhưng nên biết

~~Trang Business đang có băng đỏ: **chưa khai thông tin trader theo Digital
Services Act**.~~ **Đã khai xong** — kiểm 09/09, Digital Services Act (27 nước)
trạng thái Active.

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
> Gói thì em khai loại **tự động gia hạn** như đã chốt. Người mua vẫn tự tắt
> được bất cứ lúc nào trong Cài đặt → Thuê bao, tắt rồi vẫn dùng hết kỳ đã trả
> tiền. Và app sẽ nhắc trước khi tới hạn — còn bật gia hạn thì nhắc "sắp bị trừ
> tiền kỳ tiếp", đã tắt rồi thì nhắc "sắp hết hạn", kèm lối bấm thẳng sang trang
> quản lý gói của Apple.
