# Đối chiếu HDSD khách gửi với bản chạy — 03/09/2026

Tài liệu đối chiếu: `WorkReflection_HDSD.docx` (khách gửi lại, thư mục FileTam).
Đối chiếu với mã nguồn nhánh `docs/apple-review-reply-sent`, commit `380ab9a`.

Trong repo đã có sẵn hai bản hướng dẫn viết sau và đã soi theo hằng số của app:

- `docs/huong_dan_su_dung.md` — bản chữ đầy đủ (nháp 25/08/2026),
- `lib/core/logic/wr_user_guide.dart` — bản rút gọn dựng thành màn
  Hồ sơ → Hướng dẫn sử dụng, mọi con số nội suy từ hằng số nguồn.

Bản HDSD.docx của khách viết theo cấu trúc app CŨ hơn cả hai bản trên. Dưới đây
là những chỗ nó nói ngược với bản đang chạy.

---

## A. Sai lệch nặng — phải sửa

### A1. Tên bốn tab (mục 1)

| Tài liệu | Bản chạy |
|---|---|
| Home | **Hôm nay** |
| Hiểu | **Hiểu mình** |
| Phát triển | Phát triển ✓ |
| Hành trình | Hành trình ✓ |

Nguồn: `lib/l10n/app_vi.arb:203-206`. Tài liệu cũng bỏ sót **Hồ sơ** — v1.6 §9.1
bỏ nó khỏi thanh tab, chuyển thành ảnh đại diện góc trên bên phải
(`app_router.dart:517-521`).

### A2. Ba trụ của bộ 15 câu Self-Check (mục 3.1)

| Tài liệu | Bản chạy |
|---|---|
| Sự rõ ràng trong công việc | **Sự rõ ràng** |
| Niềm tin & an toàn để lên tiếng | **Mối quan hệ** |
| Nhịp thực thi & nhìn lại | **Cách làm việc** |

Nguồn: `lib/core/logic/wr_self_check_questions.dart:16-18`. Người dùng đọc tài
liệu rồi mở app sẽ không tìm thấy hai cái tên sau.

### A3. Chủ đề Thực hành — người dùng KHÔNG chọn (mục 4.1)

Tài liệu: *"ứng dụng gợi ý các chủ đề phát triển cụ thể… bạn theo đuổi tối đa 2
chủ đề"*, đọc ra là có danh sách để chọn.

Bản chạy: phần mềm **tự thêm** chủ đề, không có danh sách và không có nút "Bắt
đầu" (khách bác cả danh sách lẫn thẻ gợi ý). Ngưỡng: cứ **15 lần nhìn lại** được
một chủ đề, cộng thêm một chủ đề cho mỗi lần làm xong bộ 15 câu tự soi.

Nguồn: `wr_practice_theme_grant.dart:16-36`. Con số 2 chủ đề cùng lúc thì đúng
(`wr_entitlement.dart:107`).

Tài liệu cũng bỏ sót phần **Kỹ năng đã hình thành**: ba bước đầu chỉ là làm
quen, giữ được **5 lần** phần mềm mới ghi nhận thành kỹ năng
(`wr_skill_formation.dart:32,44`).

### A4. Cột mốc trong Career Memory (mục 5)

Tài liệu nêu ví dụ *"lần đầu bạn hoàn thành bài đánh giá, hay lần đầu viết mô tả
công việc"*. Cả hai đều **không** sinh cột mốc.

Bản chạy chỉ có hai loại "lần đầu":
- lần nhìn lại đầu tiên của cả hành trình,
- lần đầu chạm vào một nhóm nhu cầu mới.

Và Cột mốc **không phải một mảnh riêng** — nó là cờ gắn lên chính Câu chuyện đó
(Changelog §8.2). Nguồn: `wr_career_memory_rules.dart:117-143`.

Tài liệu nói Career Memory "gồm 4 loại"; bản chạy có **sáu** nhãn: Câu chuyện,
Cột mốc, Chủ đề, Insight, **Kỹ năng**, **Ghi chú**
(`wr_journey_screen.dart:397-424`).

### A5. Premium — giá và đường mua (mục 8 + FAQ)

Đây là chỗ nguy hiểm nhất vì app đang nằm ở App Review.

- Tài liệu: *"Bạn có thể xem chi tiết và nâng cấp bất cứ lúc nào từ trang Hồ sơ
  cá nhân."* — **sai với bản nộp kho**. IPA dựng bằng
  `--dart-define=HIDE_WEB_PURCHASE_LINK=true` (`codemagic.yaml:137`) chạy chính
  sách `WrStorePolicy.silent`: không giá, không nút mua, không cả lối dẫn sang
  web, ở mọi màn kể cả Hồ sơ. Route `/wr/payment` bị chặn ngay ở tầng router.
  Lý do nằm ở `wr_store_policy.dart` — Guideline 3.1.1 cộng anti-steering mà kho
  Việt Nam không được miễn.
- FAQ *"Tôi có thể huỷ Premium bất cứ lúc nào không? — Có, quản lý hoặc huỷ từ
  trang Hồ sơ cá nhân."* — **không có màn nào như vậy**. Gói không tự động gia
  hạn (thanh toán VietQR thủ công), hết hạn thì rơi về Free. Không có gì để huỷ.
- Tài liệu chỉ nói 499.000đ/năm; app còn bán gói **70.000đ/tháng**
  (`wr_pricing.dart:22-30`).

### A6. Trà Chiều — lời hứa chưa có trong code (mục 4.2)

Tài liệu: *"Ứng dụng sẽ báo cho bạn nếu chủ đề buổi sắp tới gần với điều bạn vừa
phản chiếu gần đây."*

Bản chạy không có bất kỳ phép so khớp nào giữa chủ đề buổi và nội dung người
dùng đã ghi — thẻ ở tab Phát triển chỉ hiện buổi **sắp tới gần nhất**, ai cũng
thấy như nhau (`wr_growth_screen.dart:543-601`). Cũng không có thông báo đẩy.

Thiếu ba chi tiết đang có thật: **định kỳ hai tuần một lần**, khuôn buổi
**2 tiếng · 1 câu hỏi**, và việc giữ chỗ làm **trên website / Zalo**, không đặt
trong app (`wr_tra_chieu.dart:64`, `wr_tra_chieu_screen.dart:339`).

---

## B. Sai lệch vừa — nên sửa cho khớp

### B1. Số bước một lượt Reflection (mục 2.2)

Tài liệu ghi 4 bước. `kReflectStepCount = 5` — có thêm màn cuối "Đã lưu"
(`wr_reflect_flow.dart:54`, `app_router.dart:348-352`).

Thứ tự bước 3 trong tài liệu cũng ngược: người dùng viết điều mình nhận ra
**trước**, câu "Nhiều người cũng dừng lại ở đúng chỗ này" hiện **sau**
(`wr_meaning_screen.dart:206,334`).

Bước 4 tài liệu không nói là bỏ qua được — màn có sẵn nút "Chưa cần bước nào"
và "Tự viết" (`wr_commit_screen.dart:120`).

### B2. Sáu ô cảm xúc, không phải "tâm trạng" gộp ba (mục 2.1)

Nhãn thật là câu đầy đủ: "Tôi đang căng thẳng", "Tôi mệt mỏi cần nghỉ ngơi",
"Tôi thấy mơ hồ", "Tôi thấy mọi thứ lệch nhau", "Tôi khá ổn", "Tôi đang vui"
(`wr_home_screen.dart:113-148`). Chạm một ô là **vào thẳng** luồng nhìn lại,
không quay về Home.

Thiếu một điều người dùng hay hiểu nhầm: **một lần nhìn lại chỉ được tính khi đã
chọn tình huống ở bước sau**; chạm ô cảm xúc rồi thoát thì lần đó không vào bộ
đếm (`wr_home_screen.dart:383-395`).

### B3. Gợi ý đọc (mục 2.3)

Tài liệu: *"ngay dưới phần Reflection, gợi ý một vài bài đọc"*. Bản chạy hiện
**đúng một mục**, là mục đầu của nhóm theo cảm xúc vừa check-in, cộng một dòng
"Xem thêm gợi ý trong thư viện" (v1.6 §8.3 — cố ý không xoay vòng).

### B4. Trợ lý AI (mục 7)

- *"góc dưới bên phải của hầu hết màn hình"* → chính xác là **cả bốn tab**, và
  chỉ bốn tab; các màn đẩy chồng lên không có bong bóng
  (`shell_screen.dart:38-46`).
- *"Giải đáp câu hỏi về Premium: quyền lợi, giá, cách nâng cấp hoặc huỷ"* — nên
  bỏ. Trên bản nộp kho app không được nói giá ở đâu cả; để câu này trong tài
  liệu là mời người dùng đi hỏi chatbot một thứ nó không được trả lời.
- Thiếu điểm mạnh nhất của nó: **đã đọc hồ sơ và toàn bộ những lần bạn nhìn
  lại**, nên không phải kể lại từ đầu.
- Thiếu **hạn mức lượt hỏi mỗi ngày của bản miễn phí** — hết lượt màn hình báo
  và mời xem gói (`wr_chat.dart:95-125`, `wr_ask_screen.dart:570-590`).

### B5. Lối vào Thông tin công việc (mục 6)

Tài liệu: *"Bổ sung thông tin công việc để chính xác hơn"* ở tab Hành trình.
Nhãn thật là **"Thông tin công việc hiện tại"**, phụ đề "Gợi ý sát hơn"
(`wr_journey_screen.dart:939-940`). Còn hai lối vào nữa tài liệu không nhắc:
màn "Kỹ năng của bạn" ở tab Phát triển, và Hồ sơ → Thông tin của bạn.

FAQ nói tải JD/CV lên được — đúng, nhưng **bản miễn phí chỉ 1 tệp**, và phần
**AI đọc & đối chiếu kỹ năng là Premium** (`wr_entitlement.dart:119`,
`wr_context_doc_screen.dart:205-208`).

### B6. Phạm vi bản miễn phí ở Career Memory (mục 5)

Tài liệu: *"xem được các mục gần nhất"*. Luật thật là **tuần hiện tại**; các
tuần trước khoá lại (`wr_journey_screen.dart:221,1105-1106`).

### B7. Danh sách quyền lợi Premium thiếu (mục 8)

Đang thiếu: **Điều bạn đang tìm kiếm**, **Diễn biến theo thời gian**, **đọc vị
từng tình huống lặp lại**, và **đọc JD/CV & đối chiếu kỹ năng**.

---

## C. Đúng, giữ nguyên

- Câu hỏi mở màn "Ngày hôm nay của bạn như thế nào?" — đúng nguyên văn.
- Bộ 15 câu, chia 3 trụ, mỗi trụ 5 câu.
- Mục 3.2 Diễn giải sâu: ba lớp (mức điểm · xu hướng so với lần liền trước ·
  đối chiếu với tình huống đã chọn) — đúng. Chỉ nên nói thêm cửa sổ đối chiếu là
  **30 ngày**.
- Trà Chiều 10–12 người.
- Năm buổi tự viết JD, tên năm buổi trùng khớp từng chữ.
- Free tối đa 2 chủ đề thực hành cùng lúc.
- FAQ về tính riêng tư và về việc không bắt buộc dùng mỗi ngày.

---

## D. Địa chỉ liên hệ — đã chốt 03/09/2026

Địa chỉ công bố ra ngoài là **`info@cloudncoral.com`**, hotline **086 688 3047**.

- `docs/privacy_policy.md` §9 — đã sửa, trước đó để `thedangs7@gmail.com`.
- HDSD v2 mục 10 — vốn đã đúng, giữ nguyên.

Còn hai chỗ nằm trên App Store Connect, phải sửa bằng tay ở đó (không sửa được
từ repo):

- **TestFlight → Feedback Email** đang là `thedangs7@gmail.com`
  (`docs/app_store_release_log_2026-08-26.md:83`). Người test bấm gửi phản hồi
  là thư về hộp cá nhân.
- **App Information → Support URL** vẫn đang `[CẦN CHỐT]`
  (`docs/app_store_listing.md:21`). Apple bắt buộc trường này và trang phải mở
  được — trang đó nên hiện đúng địa chỉ trên.

Ô **Contact** trong App Review Information (`…release_log:86`) thì để nguyên tên
và số của người nộp bản build — đó là đầu mối Apple gọi khi duyệt, không phải
địa chỉ hỗ trợ người dùng.

---

## Bản đã sửa

`docs/WorkReflection_HDSD_v2.docx` — giữ nguyên cấu trúc 10 mục và định dạng của
bản khách gửi, chỉ sửa nội dung theo các điểm A và B ở trên.
