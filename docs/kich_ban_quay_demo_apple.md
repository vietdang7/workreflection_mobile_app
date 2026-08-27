# Kịch bản quay video demo cho App Review (Apple)

> **Bản 2 · 27/08/2026** — viết lại sau khi Apple từ chối bản 1.0 build 2 vì
> **Guideline 2.1 Information Needed**. Bản 1 (25/08) soạn theo yêu cầu §6 họp
> 26_1 nhưng chưa quay; nó thiếu đúng ba thứ Apple đòi lần này (đăng ký tài
> khoản, xoá tài khoản, hộp xin quyền) và có bốn chi tiết sai so với app hiện
> tại. Chi tiết sai ở mục cuối file.
>
> Người quay: chị quản lý, quay bằng iPhone thật.
> Nộp bằng cách dán link vào **Resolution Center** và ô **App Review
> Information → Notes** — nội dung trả lời xem `apple_review_reply_2026-08-27.md`.

---

## Apple đòi gì trong video

Thư từ chối liệt kê rõ. Đối chiếu để không thiếu cảnh nào:

| Apple đòi | Cảnh nào đáp |
|---|---|
| Quay trên **máy thật**, **iOS mới nhất** | toàn bộ |
| Bắt đầu từ lúc **mở app** | Cảnh 1 |
| Luồng người dùng điển hình qua các tính năng lõi | Cảnh 7 → 12 |
| **Đăng ký** tài khoản | Cảnh 2–3 |
| **Đăng nhập** | Cảnh 6 |
| **Xoá tài khoản** | Cảnh 5 |
| Luồng mua / nội dung trả tiền | *không có trong app* — Cảnh 13 cho thấy điều đó |
| Nội dung người dùng tạo, cơ chế báo cáo/chặn | *không có* — app là nhật ký riêng tư, không có mạng xã hội, không ai xem được bài của ai |
| **Hộp xin quyền nhạy cảm** (vị trí, danh bạ, camera, ATT…) | Cảnh 9 (micro) và Cảnh 12 (thư viện ảnh) |

App **không** dùng vị trí, danh bạ, App Tracking Transparency, không có quảng
cáo, không có bộ đo lường bên thứ ba. Không cần quay gì cho mấy mục đó.

---

## Trước khi bấm quay — chuẩn bị bắt buộc

| Việc | Vì sao |
|---|---|
| **Xoá app khỏi iPhone rồi cài lại từ TestFlight** (bản 1.0 build 2) | Đây là bước dễ quên nhất. Xoá app thì iOS quên hết quyền đã cấp, nhờ vậy **hộp xin quyền mới hiện lại** trong video. App còn trên máy từ trước thì micro và thư viện ảnh đã được cấp rồi, quay không ra hộp nào — mà đó là mục Apple hỏi thẳng |
| Máy chạy **iOS mới nhất** | Apple ghi rõ "latest operating system". Vào Cài đặt → Cài đặt chung → Cập nhật phần mềm, cập nhật trước khi quay |
| Ghi lại **tên máy + phiên bản iOS** đang dùng | Phải khai ở mục 2 của bài trả lời. Xem tại Cài đặt → Cài đặt chung → Giới thiệu |
| Chuẩn bị **một email thật chưa từng đăng ký**, dùng để quay cảnh đăng ký | Tài khoản này sẽ bị xoá thật ngay trong video ở Cảnh 5. Gợi ý: dạng `ten+test1@gmail.com` |
| Tài khoản demo đã có sẵn dữ liệu và đang là **Premium** | Kiểm 26/08: 9 episode, 5 check-in, 3 tình huống lặp, 1 chủ đề thực hành, 1 lượt self-check, 4 tin nhắn chat, 3 mốc dòng thời gian. Nếu màn nào rỗng thì dùng thêm ~15 phút cho đầy trước khi quay |
| Wi-Fi ổn định | Chatbot và phần đọc tài liệu gọi máy chủ; mạng chập là video treo giữa chừng |
| Bật **Không làm phiền** | Không để thông báo cá nhân lọt vào khung hình |
| Xoay dọc, độ sáng cao, **tắt Zoom hiển thị** | |

**Tài khoản demo:**
`demo.review@workreflection.app` / `WrDemo!2026Review`

**Cách quay:** Cài đặt → Trung tâm điều khiển → thêm **Ghi màn hình**. Vuốt
xuống từ góc phải trên → chạm nút ghi.
**Để micro của bộ ghi màn hình TẮT.** Cảnh 9 cần app mượn micro để nhận giọng
nói; bật micro ghi màn hình cùng lúc dễ tranh nhau. Muốn thuyết minh thì lồng
tiếng sau, hoặc bỏ luôn — xem mục "Thuyết minh".

---

## Ba điều TUYỆT ĐỐI không được có trong video

1. **Không quay bất kỳ màn nào nhắc tới mua hàng, giá tiền, QR thanh toán,
   chuyển khoản, SePay.** Luồng mua đã ẩn trên bản iOS. Nếu lọt vào khung hình
   một trang có giá hoặc mã QR, Apple sẽ hiểu app đang bán hàng ngoài App Store —
   **Guideline 3.1.1**, lỗi nặng nhất.
2. **Không quay màn hình nào có nút đăng nhập bên thứ ba.** Nút Google đã gỡ khỏi
   giao diện, và chính vì đã gỡ nên app không phải làm Sign in with Apple
   (**Guideline 4.8**). Video mà có nút Google là tự chuốc lại điều đó.
3. **Không cắt ghép, không tua nhanh, không chèn chữ, không quay dữ liệu người
   thật.** Apple cần thấy app chạy thật, liền mạch. Chỗ nào chờ máy chủ thì cứ
   để nó chờ.

---

## Kịch bản — 14 cảnh, khoảng 6–7 phút

Quay **một mạch từ đầu đến cuối**, không dừng giữa chừng. Mỗi bước dừng 2 giây
trước khi chạm để reviewer kịp nhìn.

### Phần A · Đăng ký và xoá tài khoản (0:00 – 1:40)

Phần này dùng **email test**, không dùng tài khoản demo. Cuối phần A tài khoản
test bị xoá thật — đó chính là bằng chứng Apple muốn.

**Cảnh 1 · Mở app (0:00 – 0:15)**
Bắt đầu từ màn hình chính iPhone, thấy rõ biểu tượng WorkReflection. Chạm vào.
Để màn chào chạy hết, dừng ở màn đăng nhập.

**Cảnh 2 · Đăng ký (0:15 – 0:50)**
Chạm mục chuyển sang **Đăng ký**. Gõ chậm: tên, email test, mật khẩu. Chạm nút
đăng ký, chờ.

**Cảnh 3 · Thiết lập hồ sơ (0:50 – 1:10)**
Sau đăng ký app đi thẳng vào màn "Thông tin của bạn". Điền vài ô, chạm tiếp tục
cho tới khi vào tab **Hôm nay**. Dừng 3 giây cho thấy tài khoản mới thì màn hình
trống — đây là điều bình thường, không phải lỗi.

**Cảnh 4 · Vào Hồ sơ (1:10 – 1:20)**
Chạm ảnh đại diện góc trên phải. Cuộn chậm hết trang cho thấy các mục: thông tin,
nhắc nhở hằng ngày, ngôn ngữ, đổi mật khẩu, xuất dữ liệu, đăng xuất, và dưới cùng
là **Xoá tài khoản**.

**Cảnh 5 · Xoá tài khoản thật (1:20 – 1:40)**
Chạm **Xoá tài khoản** → hộp xác nhận hiện ra → gõ đúng chữ **XOÁ** vào ô → chạm
nút xoá. Chờ app tự đá về màn đăng nhập.

> Cảnh này là mục Apple hỏi thẳng (**Guideline 5.1.1(v)**: app cho tạo tài khoản
> thì phải cho xoá ngay trong app). Xoá tài khoản test nên không mất gì. **Tuyệt
> đối đừng làm cảnh này bằng tài khoản demo** — xoá là mất hồ sơ nộp review.

### Phần B · Đi hết tính năng bằng tài khoản demo (1:40 – 6:30)

**Cảnh 6 · Đăng nhập (1:40 – 2:10)**
Gõ email và mật khẩu tài khoản demo **thật chậm, thấy rõ từng ký tự**. Chạm
"Đăng nhập". Chờ vào tới tab Hôm nay.

> Cảnh quan trọng nhất với reviewer: nó chứng minh tài khoản demo ghi trong hồ sơ
> dùng được thật. Đừng dùng Face ID hay mật khẩu lưu sẵn — phải thấy thao tác gõ.

**Cảnh 7 · Tab Hôm nay (2:10 – 2:30)**
Dừng 3–4 giây cho thấy lời chào có tên, ngày hôm nay, các thẻ trên màn. Cuộn chậm
xuống hết màn rồi cuộn lên lại.

**Cảnh 8 · Một lần nhìn lại — bước 1 và 2 (2:30 – 2:55)**
Đây là chức năng lõi. Chạm một ô cảm xúc → chạm một tình huống có sẵn trong danh
sách chip.

**Cảnh 9 · Một lần nhìn lại — bước 3, có xin quyền micro (2:55 – 3:35)**
Tới màn "Một câu chuyện quen thuộc":

1. Chạm **biểu tượng micro** trong ô nhập → iOS hiện hộp xin quyền **micro** →
   chạm **Cho phép** → tiếp tục hiện hộp **nhận dạng giọng nói** → **Cho phép**.
2. Nói một câu tiếng Việt ngắn, ví dụ: *"Mình đã im lặng cho qua."* Cho thấy chữ
   hiện dần trong ô.
3. Chạm micro lần nữa để dừng, rồi gõ tay thêm vài chữ.

> Đây là hai hộp xin quyền Apple muốn thấy. Cứ để hộp hiện đủ 2 giây rồi mới
> chạm, đừng bấm vội.

**Cảnh 10 · Một lần nhìn lại — bước 4 và 5 (3:35 – 4:00)**
Ở "Điều bạn nhận ra": chạm một câu gợi ý bên dưới cho thấy nó điền vào ô, gõ thêm
vài chữ, rồi chạm nút kết thúc. Chờ về tab Hôm nay.

**Cảnh 11 · Ba tab còn lại (4:00 – 5:10)**

- **Hiểu mình**: cuộn chậm từ trên xuống hết màn. Dừng ở "Tình huống lặp lại" cho
  thấy có số lần thật, và thẻ **Career Health Check** cho thấy ba nhãn kết quả.
  Chạm "Xem những điều đang trở đi trở lại" → xem màn đầy đủ → quay lại.
- **Phát triển**: cuộn cho thấy chủ đề thực hành và các bước. Chạm vào một chủ đề,
  xem chi tiết, quay lại.
- **Hành trình**: chạm thẻ **Diễn biến theo thời gian** cho thấy nó bung ra. Cuộn
  xuống Career Memory, cho thấy dòng thời gian có dữ liệu thật.

**Cảnh 12 · Chatbot AI (5:10 – 5:55)**
Ở tab Hành trình, chạm **"Trò chuyện về hành trình của bạn"**.
Gõ: **"Mấy tuần nay tôi hay gặp chuyện gì nhất?"**
Gửi, **chờ trả lời xong**, để câu trả lời hiện đủ trên màn 5 giây.

> Trả lời trước câu Apple hay hỏi: tính năng AI dùng làm gì, có sinh nội dung
> ngoài tầm kiểm soát không. Phải thấy rõ nó chỉ nói về công việc của chính người
> dùng.

**Cảnh 13 · Đổi ảnh đại diện — xin quyền thư viện ảnh (5:55 – 6:15)**
Chạm ảnh đại diện góc trên phải → chạm vào ảnh để đổi → iOS hiện hộp xin quyền
**thư viện ảnh** → chạm cho phép → chọn một ảnh bất kỳ. Chờ ảnh mới hiện lên.

**Cảnh 14 · Cho thấy app không bán gì (6:15 – 6:30)**
Vẫn ở màn Hồ sơ, cuộn chậm **hết trang từ trên xuống dưới một lượt nữa**, không
chạm gì. Mục đích: cho reviewer thấy không có nút mua, không có bảng giá, không
có gói nâng cấp ở đâu cả (**Guideline 3.1.1**). Dừng quay.

---

## Sau khi quay xong

1. Xem lại toàn bộ video, kiểm **ba điều cấm** ở trên. Đặc biệt soi Cảnh 11 và 14
   xem có mẩu giá tiền nào lọt vào không.
2. Kiểm đủ **9 dòng** trong bảng "Apple đòi gì trong video".
3. Xuất `.mp4` hoặc `.mov`, dưới 500 MB.
4. Tải lên Google Drive, đặt quyền **"Bất kỳ ai có đường liên kết"**. Apple không
   đăng nhập Drive được — link riêng tư coi như không nộp. Tự kiểm bằng cách mở
   link trong cửa sổ ẩn danh.
5. Dán link vào đúng hai chỗ:
   - **Resolution Center** (trả lời thư từ chối) — dùng nguyên văn bài trong
     `apple_review_reply_2026-08-27.md`.
   - **App Review Information → Notes** của bản 1.0, để các lần nộp sau có sẵn.

---

## Bản 1 (25/08) sai chỗ nào — ghi lại để khỏi lặp

| Chỗ sai | Thực tế |
|---|---|
| Cảnh 9 bảo chạm "Chính sách quyền riêng tư" trong Hồ sơ | **Trong app không có mục này.** Đã grep `lib/` 27/08: không có chuỗi "quyền riêng tư" nào. Chính sách chỉ nằm ở URL khai trong App Store Connect. Quay theo bản cũ là người quay đứng tìm một nút không tồn tại |
| Cảnh 9 bảo "Xoá tài khoản — chỉ cuộn tới, không chạm vào" | Apple lần này đòi thấy **trọn luồng xoá**. Nay quay thật, bằng tài khoản test |
| Bảng dự phòng bảo quay màn đăng nhập có "**cả** email/mật khẩu lẫn Google" | Nút Google đã gỡ khỏi giao diện từ trước 26/08. Quay vào là kéo Guideline 4.8 trở lại |
| Chân trang ghi bundle `app.workreflection.workreflectionMobile`, Apple ID `6798188505` | Đó là app cũ ở team cá nhân, đã bỏ |
| Không có cảnh đăng ký, không có cảnh xin quyền | Hai mục Apple hỏi thẳng trong thư 27/08 |

---

## Thuyết minh (không bắt buộc)

Apple không bắt buộc. Nếu muốn, lồng tiếng **tiếng Anh** sau khi quay, mỗi cảnh
một câu ngắn:

- Cảnh 2: *"Creating a new account with email and password — no third-party sign-in."*
- Cảnh 5: *"Account deletion is available inside the app and takes effect immediately."*
- Cảnh 6: *"Signing in with the demo account provided in App Review Information."*
- Cảnh 8: *"This is the core daily reflection flow — five short steps."*
- Cảnh 9: *"Voice input is optional; the microphone permission is requested only here."*
- Cảnh 11: *"The app shows patterns detected from the user's own entries."*
- Cảnh 12: *"An AI assistant that answers based only on the user's own reflections."*
- Cảnh 14: *"There are no purchases, prices, or upgrade offers anywhere in the app."*

Không thuyết minh cũng được — nhưng khi đó phải đi thật chậm để reviewer kịp đọc
màn hình.

---

*Bản 2 · 27/08/2026 · WorkReflection · Bundle `app.workreflection.mobile` ·
Apple ID `6805322970` · Team CLOUD & CORAL COMPANY LIMITED*
