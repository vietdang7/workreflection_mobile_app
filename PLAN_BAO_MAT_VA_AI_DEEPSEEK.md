# Kế hoạch Chi tiết: Bảo mật Dữ liệu & Thiết lập AI DeepSeek (Mô hình Hybrid)

Tài liệu này tổng hợp toàn bộ kế hoạch triển khai cho 2 bài toán cốt lõi:
1. **Bảo mật dữ liệu cá nhân (PII Redaction):** Tuyệt đối không để rò rỉ thông tin cá nhân (Họ tên, SĐT, Email, Địa chỉ, CCCD...) khi gửi tài liệu JD/CV và dữ liệu người dùng tới DeepSeek API.
2. **Thiết lập AI DeepSeek theo mô hình Hybrid (AI gợi ý + Thuật toán & Logic quy chuẩn):** AI đề xuất ý tưởng sát với ngữ cảnh thực tế, sau đó Thuật toán và Logic quy chuẩn của hệ thống sẽ kiểm duyệt, lọc trùng, chuẩn hóa văn phong và ép khung 4 bước an toàn 100%.

---

## 1. Bối cảnh & Mục tiêu

* **Vấn đề bảo mật:** Hiện tại tài liệu JD/CV khi người dùng tải lên được bóc tách toàn bộ text và gửi nguyên văn sang DeepSeek API. Đối với CV, văn bản có chứa họ tên ứng viên, số điện thoại, email, địa chỉ nhà, liên kết mạng xã hội cá nhân. Điều này cần được xử lý khử định danh (anonymize) triệt để ngay tại máy chủ trước khi gửi sang bên thứ ba nhằm tuân thủ Apple App Store Guideline 5.1.1(i), Google Play Policy và bảo vệ quyền riêng tư người dùng.
* **Mục tiêu tính năng AI mới:** 
  * Ứng dụng AI DeepSeek để hỗ trợ người dùng tạo chủ đề thực hành cá nhân hóa (ở bước "Chọn một cách" và "Câu hỏi cho lần sau").
  * Ứng dụng AI để viết lời nối (Bridging narrative) cho phần Tổng quan ở tab Hiểu mình.
  * Giữ nguyên tính kỷ luật và phương pháp sư phạm của WorkReflection: Mọi gợi ý AI đều phải đi qua bộ lọc logic (Deterministic Guardrails) và có phương án Fallback 100% khi mất mạng hoặc timeout.

---

## 2. Chi tiết 4 Trụ cột Kế hoạch (Action Plan)

### Trụ cột 1: Bảo mật Dữ liệu & Khử thông tin định danh cá nhân (PII Redaction)

Mục tiêu: Đảm bảo văn bản gửi sang DeepSeek là văn bản phi định danh (anonymized), DeepSeek chỉ nhìn thấy năng lực/kinh nghiệm/kỹ năng chứ không biết người đó là ai.

1. **Xây dựng module lọc PII (`supabase/functions/_shared/pii_redact.ts`):**
   * **Email:** Quét và thay thế bằng `[EMAIL]`.
   * **Số điện thoại:** Nhận diện toàn bộ định dạng SĐT Việt Nam (09x, 08x, 03x, 07x, +84, (+84)...) và quốc tế $\rightarrow$ thay bằng `[SỐ ĐIỆN THOẠI]`.
   * **CCCD / CMND / Passport:** Nhận diện dãy 9-12 số đi kèm tiền tố nhận diện $\rightarrow$ thay bằng `[SỐ ĐỊNH DANH]`.
   * **Ngày tháng năm sinh:** Nhận diện các mẫu ngày sinh có tiền tố $\rightarrow$ thay bằng `[NGÀY SINH]`.
   * **Địa chỉ cư trú:** Nhận diện phần địa chỉ cá nhân $\rightarrow$ thay bằng `[ĐỊA CHỈ]`.
   * **Liên kết cá nhân:** Nhận diện link cá nhân (Facebook, LinkedIn, Zalo, Telegram...) $\rightarrow$ thay bằng `[LIÊN KẾT CÁ NHÂN]`.
   * **Họ tên ứng viên trong CV:** Nhận diện qua tiền tố ("Họ và tên:", "Full name:") và heuristic dòng tiêu đề đầu trang CV $\rightarrow$ thay bằng `[HỌ TÊN]`.

2. **Tích hợp vào Edge Function đọc JD/CV (`supabase/functions/wr-doc-analyze/index.ts`):**
   * Sau khi bóc tách chữ từ PDF/Word, chạy qua hàm `redactPii(docText, { isCv })` trước khi gắn vào prompt gửi sang DeepSeek.
   * Bản gốc của tài liệu vẫn được lưu an toàn trong Storage/Database riêng tư của người dùng, nhưng bản gửi sang AI là bản đã sạch 100% PII.

3. **Cập nhật Lời dặn System Prompt (`supabase/functions/wr-doc-analyze/analysis.ts`):**
   * Bổ sung quy tắc bắt buộc: *"Tuyệt đối không suy đoán, trích xuất hay tái tạo thông tin nhận diện cá nhân. Chỉ tập trung vào kỹ năng chuyên môn, kinh nghiệm làm việc, trách nhiệm và yêu cầu công việc."*

---

### Trụ cột 2: Thiết lập AI DeepSeek cho Gợi ý Thực hành & Tổng quan (Mô hình Hybrid)

Mục tiêu: Cá nhân hóa sâu sắc nhưng kiểm soát chặt chẽ bằng thuật toán.

1. **Tạo Edge Function gợi ý thực hành (`supabase/functions/wr-practice-suggest/index.ts`):**
   * Nhận đầu vào: Tên chủ đề, Tình huống đang gặp, Mong muốn khác đi, Điều đã thử rồi mà chưa có kết quả.
   * Prompt dặn DeepSeek:
     * Đề xuất 3 cách làm cụ thể, thực tế theo đúng ngữ cảnh ngành nghề của người dùng.
     * Đề xuất 1 câu hỏi phản chiếu đắt giá sau khi thực hành.
     * **Ràng buộc thép:** Tuyệt đối không gợi ý lại cách mà người dùng đã thử.
   * Ép trả về `response_format: { type: "json_object" }` và làm sạch văn phong (lột markdown, emoji, gạch dài qua `stripMarkdown`).

2. **Nâng cấp Logic quy chuẩn trên App (`lib/core/logic/wr_practice_v47.dart`):**
   * Tổ chức kiến trúc 3 lớp:
     * **Lớp 1:** Khung sườn chuẩn 4 bước bất biến (*Nhận diện $\rightarrow$ Phần của tôi $\rightarrow$ Chọn một cách $\rightarrow$ Câu hỏi cho lần sau*).
     * **Lớp 2 (Rule-based Fallback):** Bộ ngân hàng giải pháp và thuật toán lọc từ khóa hiện tại.
     * **Lớp 3 (AI Dynamic Layer):** Nhận gợi ý từ AI, đối soát kiểm tra lại xem có trùng với điều đã thử không.
   * **Cơ chế Fallback an toàn:** Nếu AI không phản hồi kịp (timeout sau 5 giây) hoặc lỗi mạng, hệ thống tự động chạy theo Lớp 2 (Rule-based). Người dùng luôn tạo được chủ đề mượt mà, không bao giờ bị đứng app hay thấy màn hình báo lỗi.

3. **Nâng cấp màn hình Tạo chủ đề (`lib/features/wr/presentation/wr_add_practice_theme_screen.dart`):**
   * Khi bấm "Tạo chủ đề", app kiểm tra quyền đồng ý AI.
   * Hiển thị trạng thái chờ tinh tế (*"Đang phân tích tình huống của bạn..."*).
   * Ráp nội dung AI gợi ý vào đúng Bước 3 và Bước 4 của chủ đề.

4. **Nâng cấp phần Tổng quan ở tab Hiểu mình (`lib/core/logic/wr_experience_reading.dart`):**
   * Sử dụng AI để sinh câu chuyện kết nối (Bridging narrative) giải thích vì sao điều kiện làm việc (15 câu khảo sát) lại đang tác động tới trải nghiệm lặp lại (Dominant Pillar), giúp người dùng nhìn ra bức tranh toàn cảnh sâu sắc hơn.

---

### Trụ cột 3: Quản trị API, Quota & Giới hạn Chi phí

Mục tiêu: Bảo vệ ngân sách API DeepSeek và ngăn chặn hành vi spam.

1. **Bảo mật API Key:**
   * Tuyệt đối không để API key trong mã nguồn client (Flutter APK/IPA).
   * Key `DEEPSEEK_API_KEY` chỉ lưu tại biến môi trường Supabase Secrets của Edge Functions.

2. **Hạn ngạch & Rate Limiting:**
   * Đặt trần số lần tạo chủ đề có AI mỗi ngày theo tài khoản (`WR_DOC_DAILY_LIMIT` hoặc `daily_ai_usage`) để tránh lạm dụng.
   * Phân quyền rõ ràng giữa gói Miễn phí (Free trial 1-2 lần tạo) và Trả phí (Premium không giới hạn trong trần ngày).

3. **Tối ưu Token & Độ trễ:**
   * Đặt `temperature: 0.2 - 0.3` (tăng tính thực tế, tránh ảo giác).
   * Đặt trần `max_tokens: 800` cho gợi ý thực hành (đủ cho 3 thẻ và 2 câu, tiết kiệm chi phí).
   * `timeoutMs: 6_000` (cắt sớm nếu mạng quốc tế chập chờn để app fallback về logic offline ngay).

---

### Trụ cột 4: Minh bạch AI & Tuân thủ Chính sách Store (Apple / Google)

Mục tiêu: Vượt qua kỳ duyệt của Apple App Store (Guideline 5.1.1) và tạo sự tin tưởng tuyệt đối cho người dùng.

1. **Cập nhật Bản công bố AI (`lib/core/logic/wr_ai_disclosure.dart`):**
   * Nêu rõ cam kết: *"Mọi tài liệu CV/JD trước khi gửi tới trợ lý AI phân tích đều được tự động loại bỏ các thông tin liên lạc và định danh cá nhân (Email, SĐT, Họ tên)"*.
   * Bổ sung tính năng "Gợi ý lộ trình thực hành cá nhân hóa" vào danh mục các tính năng có sử dụng AI bên thứ ba.

2. **Đồng thuận người dùng (User Consent):**
   * App đã có màn hình Thỏa thuận AI (`wr_ai_consent_sheet.dart`). Nếu người dùng tắt quyền AI, app vẫn hoạt động bình thường 100% nhờ bộ logic quy chuẩn Lớp 2.

---

## 3. Lộ trình Triển khai Đề xuất (Phasing)

| Giai đoạn | Hạng mục thực hiện | Kết quả bàn giao |
|---|---|---|
| **Phase 1: Bảo mật PII** | Viết module `pii_redact.ts`, test unit test với nhiều mẫu CV, tích hợp vào `wr-doc-analyze`. | Toàn bộ JD/CV gửi sang DeepSeek được khử sạch thông tin cá nhân. |
| **Phase 2: Edge Function AI Gợi ý** | Viết `wr-practice-suggest`, thiết lập prompt JSON schema, kiểm tra rate limit & auth. | API gợi ý thực hành chạy ổn định trên Supabase. |
| **Phase 3: Tích hợp Hybrid App** | Cập nhật `wr_practice_v47.dart`, nối API từ `wr_intelligence_repository.dart`, xử lý Fallback timeout trên màn hình tạo chủ đề. | Người dùng nhận được gợi ý thực hành thông minh và luôn tạo được chủ đề kể cả khi offline. |
| **Phase 4: Nâng cấp Tổng quan & Compliance** | Hoàn thiện lời nối màn Tổng quan, cập nhật `wr_ai_disclosure.dart`, chạy kiểm thử toàn diện E2E. | Hoàn thiện toàn bộ hệ thống, sẵn sàng release App Store & CH Play. |

---

## 4. Bảng câu hỏi lấy ý kiến (Decision Points)

1. **Về hạn ngạch gói Free:** Bạn muốn cho người dùng Free trải nghiệm AI gợi ý thực hành mấy lần trước khi yêu cầu nâng cấp gói? (Đề xuất: 1 - 2 lần dùng thử).
2. **Về tốc độ phản hồi:** Giới hạn thời gian chờ AI tối đa khi tạo chủ đề là bao nhiêu giây trước khi tự động chuyển sang bộ mẫu offline? (Đề xuất: 4.5 - 5 giây).
