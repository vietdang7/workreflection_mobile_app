# Kế hoạch chỉnh sửa theo file khách 09/09/2026

Nguồn: `Các nội dung cần điều chỉnh_ 090926.docx` (23 ảnh chụp màn hình + bảng
"Cũ / Sửa thành"), cộng với bảng checklist tổng hợp sau buổi họp.

Tổng cộng: **61 thay đổi câu chữ**, **6 thay đổi logic/giao diện**, **5 hạng mục
toàn app**, **4 việc đang chờ khách**.

Mỗi mục dưới đây đã được đối chiếu với mã nguồn thật — cột "ở đâu" là file:dòng
đã kiểm tra, không phải phỏng đoán.

---

## 0. Ba việc chặn, cần khách gửi trước khi làm

| # | Việc | Chờ ai |
|---|------|--------|
| B1 | Nguyên tắc gộp "Trải nghiệm hiện tại" vào "Career Health Check" | Chị quản lý chốt, gửi qua Zalo |
| B2 | File tài liệu **22 màn hình** để đối chiếu màn còn thiếu | Chị quản lý (không có trong FileTam) |
| B3 | Ảnh chụp chỗ ghi sai **"tình thường"** — đã quét toàn bộ `lib/`, `supabase/`, `docs/`, KHÔNG có chuỗi này. Nó nằm trong dữ liệu trên Supabase (bảng tình huống / thư viện) hoặc trong một câu do AI sinh ra | Khách gửi ảnh, hoặc cho phép quét toàn bộ nội dung DB |

Ba việc này **không chặn 61 mục còn lại**. Làm song song được.

---

## 1. Màn Hôm nay (Home)

Ảnh: image2, image21.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 1.1 | Chạm để bắt đầu một Reflection, dựa trên đúng cảm giác lúc này. | Chọn cảm xúc sát nhất với bạn lúc này để bắt đầu nhìn lại (Reflection). | `wr_home_screen.dart:360` |
| 1.2 | Chưa có Insight nào. Bắt đầu một lần nhìn lại để lưu Insight đầu tiên. | Hãy bắt đầu với check-in cảm xúc để chia sẻ câu chuyện đầu tiên | `wr_home_screen.dart:982` |
| 1.3 | `"Tin và được tin": bước Nhận diện đang chờ` | `Chủ đề "Tin và được tin": bước Nhận diện đang chờ` | `wr_home_screen.dart:1087` (`_continueLabel`) |
| 1.4 | Có một lần nhìn lại bạn chưa khép lại. Mở tiếp từ chỗ đang đứng. | Bạn đang có một câu chuyện chưa hoàn thành. Tiếp tục viết tiếp từ chỗ dừng lại nhé! | `wr_home_screen.dart:707` |
| 1.5 | Đây là lần thứ 2 bạn gặp tình huống X. | Bạn đã gặp tình huống "X" 2 lần | `wr_home_surface.dart:52` (`SystemNotice.sentence`) |

**Ghi chú 1.5 — "đếm tổng số lần tích luỹ".** Con số hiện tại đã là TỔNG số lần,
không phải số thứ tự — nhưng đếm trong cửa sổ **30 lần nhìn lại gần nhất**
(`kRecentSituationsWindow`). Đề nghị **giữ nguyên cửa sổ 30**: đây là nguồn sự
thật duy nhất theo Kiến trúc v2.0 §4.3, và chính quy tắc đó đã chữa lỗi cũ ba
bảng cho ba con số khác nhau. Nếu khách muốn tổng trọn đời thì phải mở lại một
bảng đếm riêng — nên hỏi lại trước khi làm. Với người dùng thật hiện nay hai con
số bằng nhau.

Có 2 chỗ khác cũng viết "Đây là lần thứ…" cần rà cùng lúc để không lệch giọng:
`wr_career_memory_rules.dart:188,209` và bản dịch `app_localizations_vi.dart:405`.

---

## 2. Luồng nhìn lại — bước 0 Nhận diện

Ảnh: image18.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 2.1 | Điều gì gần giống với ngày hôm nay của bạn nhất? | Điều gì đang mô tả đúng nhất trạng thái công việc của bạn? | `wr_reflect_flow.dart:124` (`kNoticePrompt`) |
| 2.2 | nhãn **LẦN TRƯỚC** trên chip neo | Bỏ hẳn nhãn | `wr_reflect_flow.dart:135` (`kAnchorBadge`) + chỗ dùng ở `wr_step_screen` / `wr_flow_scaffold.dart:314` |

**Ghi chú 2.2.** Khách nói "nếu chưa làm được chỉ thị động thì bỏ hẳn". Chip neo
**đã** là tình huống gần nhất người dùng chọn — nhưng chỉ trong cụm cảm xúc đang
xét. Đổi cảm xúc check-in sang cụm khác thì chip neo là một lựa chọn cũ hơn, mà
nhãn vẫn ghi "Lần trước" → sai thật. Bỏ nhãn, giữ chip. Rẻ và đúng.

---

## 3. Luồng nhìn lại — bước 1 Chi tiết

Ảnh: image22.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 3.1 | Đây là tình huống mà nhiều người ở vị trí tương tự cũng từng gặp… | Rất nhiều người đi làm cũng từng trải qua giai đoạn những cảm xúc giống bạn. Thử xem tình huống dưới đây có quen thuộc không nhé. Đây có thể sẽ là điểm bắt đầu giúp bạn nhìn sâu hơn | `wr_reflect_flow.dart:186` (`kFamiliarStoryIntro`) |
| 3.2 | Câu hỏi gợi mở thay đổi theo từng tình huống ("Nếu cố nhớ lại, điều gì có thể là một thay đổi nhỏ…") | **Một câu cố định:** Viết ra bất cứ điều gì vừa xuất hiện trong đầu bạn lúc này. — và **giảm cỡ chữ còn 70%** | `wr_detail_screen.dart:233` + `detailPrompt()` ở `wr_reflect_flow.dart:180` |
| 3.3 | Nếu điều này giống với chuyện của bạn, hãy kể lại khoảnh khắc đó theo cách của riêng bạn. Có thể bắt đầu từ lúc nào, với ai… | Kể lại khoảnh khắc đó theo cách riêng của bạn. Để trống cũng không sao, miễn là bạn đã dành 1 phút để nghĩ về nó. | `wr_reflect_flow.dart:204` (`kStoryDetailInvite`) |

**Ghi chú 3.2 — đây là thay đổi có dư chấn.** `detailPrompt()` hiện đọc
`reflectionQuestion` của từng tình huống trong thư viện (hàng trăm câu trong DB).
Bỏ đi nghĩa là toàn bộ những câu đó **ngừng được dùng**, ở cả 3 nơi:

- màn Chi tiết (câu hỏi chính),
- khối đọc lại ở màn Ý nghĩa (`recap`),
- nhánh "Điều khác" (đang dùng `kCustomDetailPrompt`).

Đề nghị: giữ cột `reflection_question` trong DB (không xoá dữ liệu), chỉ ngừng
hiển thị. Đảo lại sau này chỉ tốn một dòng.

---

## 4. Luồng nhìn lại — bước 2 Ý nghĩa, lớp 1

Ảnh: image23.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 4.1 | Nếu giữ lại một điều từ lần nhìn lại này, đó là gì? | Nếu chọn ra một bài học cho lúc này, bạn sẽ viết gì? | `wr_meaning_screen.dart:206` |
| 4.2 | …vì đây không phải lần đầu / vì mình chưa từng nói ra / … | …có thể do mình đang ôm đồm quá nhiều / do thiếu giao tiếp với sếp / do chưa biết cách từ chối… | `wr_reflect_flow.dart:289` (`kInsightStemHint`) |
| 4.3 | Thẻ "Bạn đang đo sự phát triển bằng điều gì?" | **Bỏ hẳn thẻ** | `wr_meaning_screen.dart:269-295` (khối `selfReflection`) |
| 4.4 | Khối "CHƯA BIẾT VIẾT GÌ? THỬ MỘT TRONG SỐ NÀY" + 4 thẻ gợi ý | **Bỏ hẳn** | `wr_meaning_screen.dart:296-314`, kèm `_StemSuggestion`, `_useSuggestion`, `kInsightSuggestionsLabel`, `kInsightStemSuggestions` |
| 4.5 | Chưa muốn viết, bỏ qua bước này. | Tạm thời bỏ qua, bạn muốn suy nghĩ thêm. | `wr_reflect_flow.dart:312` (`kInsightSkipLabel`) |

**Ghi chú 4.3.** Thẻ này là câu `selfReflection` của tình huống trong thư viện —
cùng họ với 3.2. Bỏ hiển thị, giữ dữ liệu.

---

## 5. Luồng nhìn lại — bước 2 lớp 2 "Góc nhìn khác" ⚠ có logic

Ảnh: image12.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 5.1 | Nhiều người cũng dừng lại ở đúng chỗ này | Thêm một cách tiếp cận khác để bạn tham khảo | `wr_meaning_screen.dart:334` |
| 5.2 | Điều này không phải để đúng hay sai, chỉ là một cách nhìn khác bạn có thể mang theo. | Một vấn đề luôn có thể được giải nghĩa theo nhiều cách. Đây là một lăng kính bổ sung, mở ra thêm không gian để bạn đối chiếu với công việc hiện tại. | `wr_reflect_flow.dart:329` (`kInsightAhaNote`) |
| 5.3 | NHIỀU NGƯỜI KHÁC CŨNG TỪNG THẤY ĐIỀU NÀY | ĐÚC KẾT PHỔ BIẾN | `wr_meaning_screen.dart:381` + `kInsightNormalizingLabel` |
| 5.4 | Một nút **Tiếp tục** | **Hai nút: Đồng ý (nút chính) / Không đồng ý** | `wr_meaning_screen.dart:341-343` |

**5.4 là thay đổi hành vi, không phải câu chữ.**

Hiện tại nút "Tiếp tục" luôn ghi vào `draft_meaning` bản **gộp** hai vế:
câu người dùng tự viết + câu đúc kết (`mergeInsight`, `wr_reflect_flow.dart:351`).

Quy tắc mới:

- **Đồng ý** → giữ nguyên hành vi hôm nay (ghi bản gộp vào Insight).
- **Không đồng ý** → chỉ ghi **câu của chính người dùng**, bỏ câu đúc kết, rồi
  vẫn đi tiếp sang bước Lựa chọn.

Một ca cần chốt: **người dùng bỏ qua không viết gì ở lớp 1, rồi bấm "Không đồng
ý"** → không còn chữ nào để lưu. Đề nghị mặc định: cho đi tiếp bình thường,
Episode đó không có Insight (đúng HXA §3.8 — Reflection kết thúc khi đủ ý nghĩa,
không phải khi đủ bước). Hiện tại code chặn đi tiếp khi nội dung rỗng
(`_confirm`, dòng 116) nên phải sửa chỗ đó.

Nên ghi lại lựa chọn Đồng ý/Không đồng ý vào Episode (một trường `aha_accepted`)
để về sau còn đo được câu đúc kết nào bị bác nhiều — nhưng đây là đề xuất thêm,
không nằm trong yêu cầu của khách. Chờ khách gật mới làm.

---

## 6. Luồng nhìn lại — bước 3 Lựa chọn và màn Xong

Ảnh: image24, image19.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 6.1 | LỰA CHỌN | BƯỚC TIẾP THEO | `wr_commit_screen.dart:104` |
| 6.2 | Nếu hiểu như vậy, bạn sẽ chọn điều gì? | Sau góc nhìn này, bước tiếp theo của bạn sẽ là gì? | `wr_commit_screen.dart:105` |
| 6.3 | Reflection luôn mở ra một lựa chọn khác. | Mỗi lần nhìn lại luôn mang đến cho bạn một cơ hội để chủ động thay đổi. | `wr_commit_screen.dart:106` |
| 6.4 | ĐÃ LƯU | LƯU VÀO HÀNH TRÌNH | `wr_done_screen.dart:69` |
| 6.5 | Điều này đã thuộc về bạn. | Góc nhìn này đã được kết nối vào hành trình sự nghiệp của bạn. — **cỡ chữ 80%** | `wr_done_screen.dart:70` |

---

## 7. Tab Hiểu mình

Ảnh: image20.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 7.1 | Bức tranh tổng thể đã mở sau 27 lần nhìn lại. Đây là trụ nào đang bị chạm nhiều nhất… khác với "Trải nghiệm hiện tại" phía trên… | Bức tranh tổng quan sau 27 lần nhìn lại. Dựa trên những ghi nhận của bạn, hệ thống đã đúc kết ra trạng thái trải nghiệm của bạn trong thời gian qua. | `wr_discover_screen.dart:730-740` |
| 7.2 | Xem những điều đang trở đi trở lại → | Xem các vấn đề thường lặp lại → | `wr_discover_screen.dart:804` |
| 7.3 | 15 câu hỏi tình huống ngắn, giúp phác thảo điều kiện làm việc… | Chỉ với 15 câu hỏi ngắn giúp hệ thống hiểu rõ hơn trạng thái hiện tại của bạn. Đừng quên cập nhật lại bất cứ khi nào bạn thấy có sự thay đổi trong công việc nhé. | `wr_discover_screen.dart:858` |
| 7.4 | Làm lại Self-Check | Cập nhật lại Self-Check | `wr_discover_screen.dart:892` |

**7.1 kéo theo B1.** Câu mới **bỏ hẳn vế so sánh** với "Trải nghiệm hiện tại" —
đúng hướng gộp hai màn. Nhưng bản thân khối "Trải nghiệm hiện tại" vẫn đứng phía
trên. Làm 7.1 trước là an toàn (câu mới không nhắc tới khối kia nữa), phần ẩn/gộp
chờ B1.

---

## 8. Màn Tình huống lặp lại

Ảnh: image13.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 8.1 | Tình huống lặp lại | NHỮNG VÒNG LẶP QUEN THUỘC | `wr_patterns_screen.dart:40` + `wr_repeated_situations.dart:12,43,59,123`, `wr_user_guide.dart:19` |
| 8.2 | Những điều đang trở đi trở lại | Những câu chuyện lặp lại | `wr_patterns_screen.dart:40`, `wr_repeated_situations.dart:56` |
| 8.3 | Đếm trên [30] lần nhìn lại gần nhất có chọn tình huống, hiện những điều đã trở lại từ 2 lần. | Trong [30] ghi chép gần đây, có một vài tình huống thường xuyên quay trở lại. Hãy cùng xem lại để hiểu rõ hơn những gì bạn đang thực sự trải qua nhé. | `wr_patterns_screen.dart:58` |

---

## 9. Màn Kỹ năng của bạn

Ảnh: image15.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 9.1 | ĐANG HÌNH THÀNH | THÓI QUEN ĐANG RÈN LUYỆN | `wr_growth_skills_screen.dart:12,98` |
| 9.2 | ĐỐI CHIẾU VỚI CÔNG VIỆC | MỨC ĐỘ TƯƠNG THÍCH VỚI CÔNG VIỆC | `wr_growth_skills_screen.dart:14,396,432` |
| 9.3 | Chưa đối chiếu được. Viết một dòng mô tả công việc bạn đang làm… | Thêm vài dòng mô tả công việc (JD) bạn đang làm, hệ thống sẽ giúp bạn nhìn rõ những kỹ năng đang phát huy tốt và đâu là những khoảng trống cần hoàn thiện thêm. | `wr_growth_skills_screen.dart:399` |

---

## 10. Màn Thông tin công việc

Ảnh: image11.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 10.1 | Bạn đang làm công việc gì? Một dòng thôi cũng đủ… | Chia sẻ vai trò hiện tại của bạn. Dựa vào đây, các bài thực hành sẽ được phác thảo riêng cho công việc của bạn. | `wr_work_info_screen.dart:99` |
| 10.2 | MÔ TẢ CỦA BẠN | VỊ TRÍ / CHỨC DANH HIỆN TẠI | `wr_work_info_screen.dart:109` |
| 10.3 | Có JD hoặc CV thì tải lên để bối cảnh đầy đủ hơn. Tuỳ chọn. | Tải lên file JD (Mô tả công việc) hoặc CV để hệ thống có thêm dữ liệu phân tích. (Không bắt buộc) | `wr_work_info_screen.dart:182` |
| 10.4 | Tài liệu bối cảnh (JD · CV) > | Tải lên JD hoặc CV của bạn > | `wr_work_info_screen.dart:191` (+ tiêu đề màn `wr_context_doc_screen.dart:224`) |
| 10.5 | Công ty chưa có JD? Cùng viết trong 5 buổi ngắn | Nếu chưa có sẵn JD, bạn có thể tự phác thảo nhanh theo 5 bước hướng dẫn | `wr_work_info_screen.dart:228` |
| 10.6 | Mỗi buổi khoảng 2–3 phút, không cần làm hết trong một lần | Mỗi bước chỉ mất 2–3 phút, bạn có thể dừng lại và quay lại làm tiếp bất cứ lúc nào. | `wr_work_info_screen.dart:233` |
| 10.7 | Viết JD cùng app | Cùng tạo JD của bạn | `wr_work_info_screen.dart:195`, `wr_jd_builder_screen.dart:155`, `app_router.dart:589` |

---

## 11. Màn Cùng tạo JD

Ảnh: image17.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 11.1 | BUỔI 1 TRÊN 5 · KHOẢNG 2 PHÚT (và buổi 2–5) | BƯỚC 1 / 5 · KHOẢNG 2 PHÚT (…) | `wr_jd_builder.dart:111,139,178,199,222` |
| 11.2 | Nếu chưa quen viết JD, đừng bắt đầu từ những trường chuẩn… | Đừng áp lực phải viết đúng chuẩn. Hãy thoải mái trả lời những câu hỏi, chia sẻ của bạn sẽ là chất liệu để tạo nên bản JD hoàn chỉnh. | `wr_jd_builder.dart:112` |
| 11.3 | "Buổi $n" / "Buổi $n, chưa mở khoá" (nhãn trợ năng) | "Bước $n" / "Bước $n, chưa mở khoá" | `wr_jd_builder_screen.dart:295-296` |

Đổi "buổi" → "bước" trên toàn màn cho nhất quán, kể cả trong chú thích mã nguồn.

---

## 12. Tab Hành trình

Ảnh: image10, image4.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 12.1 | ✦ DIỄN BIẾN THEO THỜI GIAN | NHÌN LẠI DÒNG THỜI GIAN — **bỏ biểu tượng dấu sao ở đầu** | `wr_journey_screen.dart:764`, `wr_journey_narrative_screen.dart:38` |
| 12.2 | Bạn đã để lại 42 mảnh ký ức nghề nghiệp. | Bạn đã ghi lại 42 cột mốc trên hành trình sự nghiệp. | `wr_journey_screen.dart:564,611,1117,1123,1170` + `wr_user_guide.dart:381` |
| 12.3 | ✦ CƠ HỘI PHÁT TRIỂN | GÓC NHÌN PHÁT TRIỂN | `wr_journey_screen.dart:894` |
| 12.4 | Gợi ý này dựa trên dữ liệu bạn đã chia sẻ qua Reflection, độ chính xác còn giới hạn. | Gợi ý này được đúc kết từ hoạt động nhìn lại của bạn. Bạn có thể cung cấp thêm bối cảnh để nhận phân tích "may đo" sát hơn | `wr_mood_content.dart:221` |
| 12.5 | Thông tin công việc hiện tại | Cập nhật bối cảnh công việc | `wr_journey_screen.dart:939` |
| 12.6 | Gợi ý sát hơn > | Để gợi ý chính xác hơn > | `wr_journey_screen.dart:940` |
| 12.7 | Bản đầy đủ kể lại những mẫu hình của bạn đã đổi thế nào qua từng giai đoạn… | Mở khóa bản đầy đủ để nhìn lại toàn bộ bức tranh thay đổi của bạn qua từng giai đoạn. | `wr_journey_screen.dart:788`, `wr_journey_narrative_screen.dart:45` |
| 12.8 | Chưa có mảnh ký ức nào. Mỗi lần nhìn lại sẽ để lại một dấu ở đây. | Nhật ký sự nghiệp của bạn chưa ghi nhận cột mốc nào. Hãy bắt đầu một lần nhìn lại để lưu giữ những dấu ấn của riêng bạn. | `wr_journey_screen.dart:563,1128` |

**12.2 là đổi từ vựng, không chỉ đổi câu.** "mảnh ký ức" → "cột mốc" xuất hiện ở
6 chỗ. Phải đổi hết cùng lúc, không thì hai tên gọi cho một thứ.

---

## 13. Màn Thông tin của bạn

Ảnh: image6.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 13.1 | Gộp lại toàn bộ thông tin bạn đã chia sẻ ở Hồ sơ, Khảo sát tổ chức, và Thông tin công việc… | Tổng hợp toàn bộ bối cảnh cá nhân, môi trường và công việc của bạn. Bạn có thể kiểm tra hoặc cập nhật lại bất cứ lúc nào tại đây. | `my_info_screen.dart:105` |
| 13.2 | ✦ Đây cũng là thứ giúp trợ lý trò chuyện AI hiểu đúng hoàn cảnh của bạn hơn… | Thông tin càng sát thực tế, trợ lý AI càng đưa ra những tư vấn "may đo" chính xác cho bối cảnh của bạn — **bỏ biểu tượng dấu sao** | `my_info_screen.dart:131` (icon ở dòng 125) |

---

## 14. Màn Chủ đề thực hành

Ảnh: image5.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 14.1 | Chưa đủ dữ liệu để có chủ đề | Chưa xác định chủ đề trọng tâm | `wr_growth_screen.dart:454` |
| 14.2 | Bạn đã nhìn lại 0/15 lần. Đủ 15 lần là WorkReflection tự thêm một chủ đề hợp với bạn. Hoặc làm bộ tự đánh giá để có ngay. | Bạn đã tích lũy 0/15 lượt nhìn lại. Khi đạt mốc 15 lượt, ứng dụng sẽ tự động gợi ý chủ đề phù hợp nhất với bạn. Bạn cũng có thể hoàn thành Self-Check để mở khóa ngay. | `wr_growth_screen.dart` (khối quanh 454-494) |
| 14.3 | Làm bộ tự đánh giá → | Làm Self-Check ngay → | `wr_growth_screen.dart:494` |

---

## 15. Màn Self-Check

Ảnh: image3, image1, image7.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 15.1 | Chấm tròn ở đầu màn | **Bỏ** | `wr_self_check_screen.dart` (khối mở đầu, quanh 240) |
| 15.2 | 15 câu phản chiếu | 15 câu hỏi phản chiếu | `wr_self_check_screen.dart:547`, `wr_paywall_screen.dart:643` |
| 15.3 | Trả lời thành thật theo cảm nhận thực tế trong môi trường làm việc của bạn, không có câu trả lời đúng hay sai. | Hãy trả lời dựa trên trải nghiệm thực tế của bạn tại nơi làm việc. | `wr_self_check_screen.dart:259` |
| 15.4 | ⏱ Khoảng 3–4 phút / 🔒 Chỉ bạn thấy kết quả / ↺ Có thể làm lại bất cứ lúc nào | Thời gian: Khoảng 3–4 phút hoàn thành / Bảo mật tuyệt đối. Chỉ bạn mới thấy kết quả / Có thể làm lại bất cứ lúc nào bạn muốn — **bỏ emoji, dùng icon line art hoặc gạch đầu dòng** | cùng khối |
| 15.5 | Bản đầy đủ đọc kỹ từng mặt theo khoảng điểm của bạn… | Mở khóa báo cáo đầy đủ để phân tích chi tiết từng khía cạnh, nhận diện điểm mất cân bằng giữa các nhóm trải nghiệm, đồng thời so sánh với lịch sử nhìn lại và các tình huống bạn thường gặp. | `wr_self_check_screen.dart:1066` |

---

## 16. Màn Premium

Ảnh: image8, image7.

| # | Cũ | Mới | Ở đâu |
|---|----|-----|-------|
| 16.1 | Cùng 15 câu này, chạy lại theo thời gian để thấy điều kiện làm việc của bạn thay đổi ra sao… | So sánh kết quả theo thời gian để thấy điều kiện làm việc của bạn đã thay đổi ra sao và đối chiếu với các ghi chú trước đó. | `wr_self_check_screen.dart` (khối so sánh) |
| 16.2 | Điều kiện quanh bạn đang đổi thế nào | Môi trường làm việc của bạn đang thay đổi ra sao? | `wr_paywall_screen.dart:573` |
| 16.3 | Cùng 15 câu đó, chạy lại theo thời gian để thấy xu hướng… | Theo dõi sự thay đổi qua thời gian từ bộ 15 câu hỏi đánh giá, giúp bạn nhận diện xu hướng và đối chiếu với các góc nhìn trước đó. | `wr_paywall_screen.dart:574` |
| 16.4 | Phát hiện mô thức từ Career Memory của bạn. Ngày càng chính xác hơn. | Tự động phân tích dữ liệu từ Career Memory, mang lại những góc nhìn ngày càng sát với thực tế của bạn. | `wr_paywall_screen.dart:625` |
| 16.5 | Nhìn thấy các mô thức lặp lại trong hành trình nghề nghiệp theo thời gian. | Nhận diện các mẫu hình hành vi và cảm xúc lặp lại trong suốt hành trình phát triển. | `wr_paywall_screen.dart:630` |
| 16.6 | Không giới hạn | Truy cập không giới hạn | `wr_paywall_screen.dart:634` |
| 16.7 | Story không giới hạn, Thực hành không giới hạn, Career Memory đầy đủ. | Mở khóa trọn vẹn kho bài viết, bài tập Thực hành và toàn bộ Career Memory. | `wr_paywall_screen.dart:635` |

⚠ **16.6/16.7 là câu chữ mô tả gói bán hàng trên màn IAP.** Đổi xong phải đối
chiếu lại với phần mô tả sản phẩm đã khai trong App Store Connect — Apple đã từ
chối một lần vì Guideline 3.1.1, mô tả trong app và trong kho phải khớp.

---

## 17. Năm hạng mục toàn app

### 17.1 Bỏ dấu sao do AI sinh ra

Hai thứ khác nhau, phải làm cả hai:

- **Biểu tượng ✦** (`Icons.auto_awesome_outlined`) ở đầu các nhãn AI — mục 12.1,
  12.3, 13.2. Là do thiết kế, không phải AI.
- **Ký tự `*` / `**` markdown** trong chữ do model sinh ra. Hiện **không có lớp
  lọc nào**: `wr-narrative`, `wr-chat`, `wr-doc-analyze`, `ai-personalize` đều trả
  thẳng chữ model viết ra màn hình. Cần một hàm lọc dùng chung ở `_shared/`, gọi
  ở cả bốn Edge Function, **cộng thêm** một lớp lọc phía app — đã có bài học từ
  `reply_shaping`: prompt lo phần model làm đúng, tầng lọc lo phần model làm sai.

### 17.2 Icon về line art

Rà toàn bộ icon: bỏ emoji (⏱🔒↺ ở màn Self-Check), bỏ icon tô đặc, dùng biến thể
`_outlined`. Cần một lượt quét `Icons.` trên toàn `lib/` và duyệt theo màn.

### 17.3 Onboarding 3 trang — **đã đúng, không cần sửa**

Đã kiểm tra `app_router.dart:88-130`: cờ `seen_onboarding` lưu trên máy, chỉ hiện
khi **chưa đăng nhập và chưa từng xem**. Đăng nhập lại không hiện. Chỉ cần thêm
một test khoá hành vi này để lần sửa sau không làm hỏng.

### 17.4 Rà lỗi chính tả

Chờ B3. Song song: quét chuỗi tiếng Việt trong `lib/` bằng công cụ, và quét nội
dung bảng tình huống / thư viện trên Supabase.

### 17.5 Bản tiếng Anh — **việc lớn nhất, nên tách riêng**

Số liệu đo được:

- Hệ thống đa ngôn ngữ **có sẵn** (`lib/l10n/`, ~800 khoá, đủ vi + en).
- Nhưng **toàn bộ 49 file của phần WorkReflection không dùng nó** — 0 file gọi
  `AppLocalizations`. Khoảng **1.500 chuỗi tiếng Việt viết thẳng trong mã**, trải
  trên 83 file.

Nghĩa là "cập nhật song song bản tiếng Anh" **không phải một lần dịch**, mà là:
tách 1.500 chuỗi ra file `.arb` → dịch → nối lại từng màn. Ước lượng thô: gấp
3–4 lần toàn bộ 61 mục câu chữ ở trên.

**Đề nghị thứ tự:** làm xong tiếng Việt (mục 1–16) rồi mới tách i18n — tách trước
thì mỗi câu phải sửa hai lần, ở hai chỗ.

Nếu khách cần bản tiếng Anh gấp cho App Store thì nên chốt phạm vi hẹp: chỉ
những màn App Review thật sự đi qua.

---

## 18. Thứ tự làm đề nghị

| Đợt | Nội dung | Vì sao đợt này |
|-----|----------|----------------|
| 1 | Mục 1–4, 6–16 (**58 mục câu chữ**) | Thuần thay chuỗi, rủi ro thấp, một lượt test là xong. Khách thấy kết quả ngay |
| 2 | Mục 5.4 (Đồng ý / Không đồng ý) + 3.2 (câu cố định 70%) + 4.3, 4.4 (bỏ thẻ) | Đụng luồng và dữ liệu — cần test riêng, cần chốt ca "bỏ qua rồi Không đồng ý" |
| 3 | Mục 17.1 (lọc dấu sao) + 17.2 (icon line art) + 17.3 (test onboarding) | Toàn app, cần rà từng màn |
| 4 | B1 (gộp Career Health Check), B2 (đối chiếu 22 màn), B3 (chính tả) | Chờ khách |
| 5 | Mục 17.5 (tiếng Anh) | Việc lớn, chốt phạm vi trước |

Mỗi đợt: `flutter analyze` sạch → chạy đủ bộ test → dựng APK → chạy thật trên máy
→ commit. Bộ test hiện có 2.301 bài; các mục bỏ thẻ/đổi nhãn chắc chắn làm đỏ một
số bài đang khoá đúng chuỗi cũ, sẽ sửa cùng lượt.

---

## 19. Việc cần hỏi lại khách

1. **Đếm tổng số lần** (mục 1.5): giữ cửa sổ 30 lần gần nhất, hay muốn tổng trọn
   đời? Tổng trọn đời phải mở lại một bảng đếm riêng.
2. **"Không đồng ý" khi chưa viết gì** (mục 5.4): cho đi tiếp và không lưu Insight
   — đúng ý khách chứ?
3. **Câu hỏi gợi mở cố định** (mục 3.2): xác nhận bỏ hết câu hỏi riêng của từng
   tình huống trong thư viện, dùng chung một câu cho mọi tình huống.
4. **Bản tiếng Anh** (mục 17.5): làm toàn bộ app hay chỉ các màn App Review đi qua?
