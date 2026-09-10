# Tiến độ chỉnh sửa nội dung theo file khách 09/09/2026

Kế hoạch gốc: `docs/chinh_sua_noi_dung_2026-09-09.md` (nhánh
`docs/ra-soat-noi-dung-090926`, commit `60ab831`).

File này là **bảng đối chiếu đã-xong**. Mỗi dòng ghi rõ đổi ở đâu, để lần sau mở
ra là biết ngay còn gì chưa làm, không phải đọc lại toàn bộ kế hoạch.

---

## ĐỢT 1 — ĐÃ XONG (10/09/2026)

Nhánh: `feat/noi-dung-dot-1-090926`, cắt từ `main`.

### §1 Màn Hôm nay — 5/5 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 1.1 | Chọn cảm xúc sát nhất với bạn lúc này để bắt đầu nhìn lại (Reflection). | `wr_home_screen.dart` |
| 1.2 | Hãy bắt đầu với check-in cảm xúc để chia sẻ câu chuyện đầu tiên | `wr_home_screen.dart` |
| 1.3 | Thêm tiền tố `Chủ đề "…"` | `wr_home_screen.dart` `_continueLabel` |
| 1.4 | Bạn đang có một câu chuyện chưa hoàn thành… | `wr_home_screen.dart` |
| 1.5 | Bạn đã gặp tình huống "X" N lần | `wr_home_surface.dart` `SystemNotice.sentence` |

**Rà thêm theo ghi chú 1.5** — hai chỗ khác cũng viết "Đây là lần thứ…", đã đổi
cùng giọng để không lệch:

- `wr_done_screen.dart` → "Bạn đã ghi lại tình huống này N lần"
- `wr_career_memory_rules.dart` → "Trong tháng này bạn đã nhìn vào một chuyện
  thuộc nhóm này N lần."

Chưa đụng `app_localizations_vi.dart:405` (bản l10n của cùng câu) — phần
WorkReflection không dùng l10n, khoá đó đang không ai gọi. Sẽ dọn ở đợt 5 (i18n).

### §2 Bước 0 Nhận diện — 2/2 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 2.1 | Điều gì đang mô tả đúng nhất trạng thái công việc của bạn? | `wr_reflect_flow.dart` `kNoticePrompt` |
| 2.2 | **Bỏ hẳn** nhãn "Lần trước" | hằng `kAnchorBadge` đã xoá; `wr_step_screen.dart` bỏ tham số `badge` |

Chip neo vẫn đứng đầu và vẫn cao hơn (92 vs 76) — đó là hai dấu hiệu đúng trong
mọi trường hợp, khác cái nhãn cũ. Test `wr_checkin_to_growth_chain_test.dart` đã
chuyển từ khoá-theo-nhãn sang khoá-theo-khoá-widget + chiều cao.

### §3 Bước 1 Chi tiết — 2/2 của đợt này ✅

| # | Đổi thành | File |
|---|-----------|------|
| 3.1 | Rất nhiều người đi làm cũng từng trải qua… | `kFamiliarStoryIntro` |
| 3.3 | Kể lại khoảnh khắc đó theo cách riêng của bạn… | `kStoryDetailInvite` |

3.2 (câu hỏi cố định + cỡ chữ 70%) → **đợt 2**, đụng dữ liệu thư viện.

### §4 Bước 2 Ý nghĩa — 3/3 của đợt này ✅

| # | Đổi thành | File |
|---|-----------|------|
| 4.1 | Nếu chọn ra một bài học cho lúc này, bạn sẽ viết gì? | `wr_meaning_screen.dart` |
| 4.2 | …có thể do mình đang ôm đồm quá nhiều / … | `kInsightStemHint` |
| 4.5 | Tạm thời bỏ qua, bạn muốn suy nghĩ thêm | `kInsightSkipLabel` |

4.3, 4.4 (bỏ thẻ + bỏ khối gợi ý) → **đợt 2**.

### §5 Góc nhìn khác — 3/3 của đợt này ✅

| # | Đổi thành | File |
|---|-----------|------|
| 5.1 | Thêm một cách tiếp cận khác để bạn tham khảo | `wr_meaning_screen.dart` |
| 5.2 | Một vấn đề luôn có thể được giải nghĩa theo nhiều cách… | `kInsightAhaNote` |
| 5.3 | Đúc kết phổ biến | `kInsightNormalizingLabel` |

5.4 (hai nút Đồng ý / Không đồng ý) → **đợt 2**, là đổi hành vi.

### §6 Lựa chọn + Xong — 5/5 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 6.1 | BƯỚC TIẾP THEO | `wr_commit_screen.dart` |
| 6.2 | Sau góc nhìn này, bước tiếp theo của bạn sẽ là gì? | `wr_commit_screen.dart` |
| 6.3 | Mỗi lần nhìn lại luôn mang đến cho bạn một cơ hội để chủ động thay đổi. | `wr_commit_screen.dart` |
| 6.4 | LƯU VÀO HÀNH TRÌNH | `wr_done_screen.dart` |
| 6.5 | Góc nhìn này đã được kết nối vào hành trình sự nghiệp của bạn. — **cỡ chữ 80%** | `wr_done_screen.dart` |

**Hạ tầng thêm cho 6.5:** `WrFlowScaffold` có tham số mới `titleScale`
(mặc định 1.0). Đây là tham số tuỳ chọn nên 17 nơi đang gọi không đổi gì.
Đợt 2 dùng lại được cho 3.2 (70%).

### §7 Tab Hiểu mình — 4/4 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 7.1 | Bức tranh tổng quan sau N lần nhìn lại… | `wr_discover_screen.dart` |
| 7.2 | Xem các vấn đề thường lặp lại | `wr_discover_screen.dart` |
| 7.3 | Chỉ với 15 câu hỏi ngắn giúp hệ thống hiểu rõ hơn… | `wr_discover_screen.dart` |
| 7.4 | Cập nhật lại Self-Check | `wr_discover_screen.dart` |

Câu mới của 7.1 bỏ vế so sánh với "Trải nghiệm hiện tại", nên hai nhánh cũ trùng
nhau → đã gỡ luôn tham số `readsFromSelfCheck` của `_CareerHealthCard`. Việc
ẩn/gộp khối "Trải nghiệm hiện tại" vẫn chờ B1.

### §8 Tình huống lặp lại — 3/3 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 8.1 | NHỮNG VÒNG LẶP QUEN THUỘC | `wr_patterns_screen.dart`, `app_vi.arb`, `app_localizations_vi.dart`, `wr_user_guide.dart` |
| 8.2 | Những câu chuyện lặp lại | `wr_patterns_screen.dart` |
| 8.3 | Trong 30 ghi chép gần đây, có một vài tình huống thường xuyên quay trở lại… | `wr_patterns_screen.dart` |

Chú thích trong `wr_repeated_situations.dart` **giữ nguyên** vì đang trích
nguyên văn Kiến trúc v2.0 §4.3; đã thêm một ghi chú nói tên hiển thị đã đổi.

### §9 Kỹ năng của bạn — 3/3 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 9.1 | THÓI QUEN ĐANG RÈN LUYỆN | `wr_growth_skills_screen.dart` |
| 9.2 | MỨC ĐỘ TƯƠNG THÍCH VỚI CÔNG VIỆC | `wr_growth_skills_screen.dart` |
| 9.3 | Thêm vài dòng mô tả công việc (JD)… | `wr_growth_skills_screen.dart` |

### §10 Thông tin công việc — 7/7 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 10.1 | Chia sẻ vai trò hiện tại của bạn… | `wr_work_info_screen.dart` |
| 10.2 | VỊ TRÍ / CHỨC DANH HIỆN TẠI | `wr_work_info_screen.dart` |
| 10.3 | Tải lên file JD (Mô tả công việc) hoặc CV… | `wr_work_info_screen.dart` |
| 10.4 | Tải lên JD hoặc CV của bạn | `wr_work_info_screen.dart` + tiêu đề `wr_context_doc_screen.dart` |
| 10.5 | Nếu chưa có sẵn JD, bạn có thể tự phác thảo nhanh theo 5 bước hướng dẫn | `wr_work_info_screen.dart` |
| 10.6 | Mỗi bước chỉ mất 2–3 phút… | `wr_work_info_screen.dart` |
| 10.7 | Cùng tạo JD của bạn | `wr_jd_builder_screen.dart`, `wr_jd_builder.dart`, `app_router.dart` |

### §11 Cùng tạo JD — 3/3 ✅

"buổi" → "bước" trên toàn luồng JD, kể cả chú thích mã nguồn
(`wr_jd_builder.dart`, `wr_jd_builder_screen.dart`).

**KHÔNG đụng** `wr_tra_chieu.dart` — "buổi" ở đó là buổi workshop Trà Chiều,
việc khác hẳn.

| # | Đổi thành |
|---|-----------|
| 11.1 | BƯỚC 1 / 5 · KHOẢNG 2 PHÚT (và 2–5) |
| 11.2 | Đừng áp lực phải viết đúng chuẩn… |
| 11.3 | "Bước N" / "Bước N, chưa mở khoá" (nhãn trợ năng) |

### §12 Tab Hành trình — 8/8 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 12.1 | NHÌN LẠI DÒNG THỜI GIAN + bỏ icon ✦ | `wr_journey_screen.dart`, `wr_journey_narrative_screen.dart` |
| 12.2 | ~~Bạn đã ghi lại N cột mốc…~~ → **Bạn đã có N ghi nhận trên hành trình sự nghiệp.** (10 chỗ) — xem ghi chú đảo chiều bên dưới | `wr_journey_screen.dart`, `wr_user_guide.dart` |
| 12.3 | GÓC NHÌN PHÁT TRIỂN | `wr_journey_screen.dart` |
| 12.4 | Gợi ý này được đúc kết từ hoạt động nhìn lại của bạn… | `wr_mood_content.dart` `kConfidenceNote` |
| 12.5 | Cập nhật bối cảnh công việc | `wr_journey_screen.dart` |
| 12.6 | Để gợi ý chính xác hơn | `wr_journey_screen.dart` |
| 12.7 | Mở khóa bản đầy đủ để nhìn lại toàn bộ bức tranh thay đổi… | `wr_journey_screen.dart`, `wr_journey_narrative_screen.dart` |
| 12.8 | Nhật ký sự nghiệp của bạn chưa có ghi nhận nào… | `wr_journey_screen.dart` (2 chỗ) |

> ⚠ **12.2 và 12.8 đã ĐẢO CHIỀU ngày 10/09 — khách tự bác lại.**
>
> Lúc làm đợt 1 tôi ghi lại một xung đột từ vựng: trong mã, "cột mốc" đã có
> nghĩa hẹp sẵn là **một CỜ trên STORY** (changelog 24/08), trong khi khách dùng
> nó cho MỌI mảnh Career Memory. Cách xử lý khi đó: đổi chữ trên màn hình, giữ
> "mảnh ký ức" trong tên biến và chú thích.
>
> `WorkReflection_Changelog_CareerSnapshot.docx` §9.1 (khách gửi 10/09) bác đúng
> cách đó, bằng đúng lý do trên: "Cột mốc" là tên của MỘT trong bốn loại (Câu
> chuyện · Cột mốc · Chủ đề · Insight), nên gọi vật chứa như vậy sẽ ra "42 cột
> mốc" ở tiêu đề trong khi bên dưới chỉ vài mục thật sự mang nhãn đó.
>
> **Chốt hiện hành: "ghi nhận" cho vật chứa, "Cột mốc" giữ riêng cho loại
> MILESTONE.** Đã sửa lại 10 chỗ hiển thị + 9 khẳng định test trong cùng nhánh
> này, trước khi PR #19 được merge. Tên biến vẫn để nguyên "mảnh ký ức".

Icon ✦ ở nhãn Premium khoá thì **giữ** ổ khoá `Icons.lock_outline`: nó nói một
điều có thật, không phải trang trí.

### §13 Thông tin của bạn — 2/2 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 13.1 | Tổng hợp toàn bộ bối cảnh cá nhân, môi trường và công việc… | `my_info_screen.dart` |
| 13.2 | Thông tin càng sát thực tế, trợ lý AI càng… + bỏ icon ✦ | `my_info_screen.dart` |

### §14 Chủ đề thực hành — 3/3 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 14.1 | Chưa xác định chủ đề trọng tâm | `wr_growth_screen.dart` |
| 14.2 | Bạn đã tích lũy 0/15 lượt nhìn lại… | `wr_growth_screen.dart` |
| 14.3 | Làm Self-Check ngay | `wr_growth_screen.dart` |

### §15 Self-Check — 5/5 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 15.1 | **Bỏ** chấm tròn ◉ ở đầu màn | `wr_self_check_screen.dart` |
| 15.2 | 15 câu hỏi phản chiếu (3 chỗ) | `wr_self_check_screen.dart`, `wr_paywall_screen.dart` |
| 15.3 | Hãy trả lời dựa trên trải nghiệm thực tế của bạn tại nơi làm việc. | `wr_self_check_screen.dart` |
| 15.4 | Bỏ emoji ⏱🔒↺ → `Icons.schedule_outlined` / `lock_outline` / `refresh_outlined` | `wr_self_check_screen.dart` (`_InfoRow` đổi `String icon` → `IconData icon`) |
| 15.5 | Mở khóa báo cáo đầy đủ để phân tích chi tiết từng khía cạnh… | `wr_self_check_screen.dart` |

### §16 Premium — 7/7 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 16.1 | So sánh kết quả theo thời gian… | `wr_discover_screen.dart` |
| 16.2 | Môi trường làm việc của bạn đang thay đổi ra sao? | `wr_paywall_screen.dart` |
| 16.3 | Theo dõi sự thay đổi qua thời gian từ bộ 15 câu hỏi đánh giá… | `wr_paywall_screen.dart` |
| 16.4 | Tự động phân tích dữ liệu từ Career Memory… | `wr_paywall_screen.dart` |
| 16.5 | Nhận diện các mẫu hình hành vi và cảm xúc lặp lại… | `wr_paywall_screen.dart` |
| 16.6 | Truy cập không giới hạn | `wr_paywall_screen.dart` |
| 16.7 | Mở khóa trọn vẹn kho bài viết, bài tập Thực hành và toàn bộ Career Memory. | `wr_paywall_screen.dart` |

> ⚠ **16.6 / 16.7 phải đối chiếu lại App Store Connect.** Đây là câu chữ mô tả
> gói bán hàng trên màn IAP. Apple đã từ chối một lần vì Guideline 3.1.1 — mô tả
> trong app và trong kho phải khớp. **Việc này CHƯA làm**, cần vào App Store
> Connect sửa mô tả sản phẩm cho khớp trước khi nộp bản mới.

---

## ĐỢT 1B — BẢN DOCX CẬP NHẬT NGÀY 10/09 (ĐÃ XONG)

Khách gửi lại chính file `Các nội dung cần điều chỉnh_ 090926.docx` với **các
trang mới ở cuối**. Dò lại toàn bộ 71 cặp "Cũ → Sửa thành": **48 cặp đã nằm sẵn
trong mã** (đợt 1), phần còn lại chia như bảng dưới.

### Ba màn mới — 14/14 ✅

| # | Đổi thành | File |
|---|-----------|------|
| 18.1 | Mỗi ngày, hãy dành một khoảnh khắc dừng lại… | `app_vi.arb` `onb1Body` |
| 18.2 | 4 lựa chọn trang 2 viết lại (Mệt mỏi nhưng không rõ lý do. …) | `onb2Opt1–4` |
| 18.3 | Chấm màu trước mỗi lựa chọn: coral/teal → **xám** (`text3`) | `onboarding_screen.dart` `_SituationCard` |
| 18.4 | Nút trang 2: "Bắt đầu ngay" (coral) → **"Tiếp tục" (navy)** như trang 1 | `onb2Cta` + `_Step2` |
| 18.5 | Đồng hành cùng **bước tiến** sự nghiệp của bạn. | `onb3Title` |
| 18.6 | WorkReflection lưu giữ hành trình… | `onb3Body` |
| 18.7 | Góc nhìn khách quan / Ghi nhận và phản chiếu chân thực. | `onb3Promise3Title/Sub` |
| 18.8 | Bắt đầu hành trình | `onb3Cta` |
| 19.1 | HOẠT ĐỘNG KHÁC | `wr_growth_themes_screen.dart` |
| 19.2 | Đưa trải nghiệm "Nhìn lại" bước ra đời thực… | `wr_growth_themes_screen.dart` (thẻ mời Trà Chiều) |
| 19.3 | 10–12 người · 2 giờ chia sẻ | `wr_tra_chieu.dart` `kTraChieuFormatLabel` |
| 19.4 | Tinh thần của buổi Trà Chiều | `wr_tra_chieu_screen.dart` |
| 19.5 | Trà Chiều là một không gian tự do… | `kTraChieuWhy` |
| 19.6 | Hiện chưa có lịch sự kiện mới. Lịch tổ chức Trà Chiều thường sẽ được thông báo trước hai tuần… | `wr_tra_chieu_screen.dart` (2 chỗ) + `wr_growth_screen.dart` |
| 19.7 | 3 nguyên tắc cốt lõi | `wr_tra_chieu_screen.dart` |

**19.6 sửa ở BA chỗ, không phải một.** Câu "chưa có buổi nào" sống trên ba màn
khác nhau (thẻ Trà Chiều ở tab Phát triển · thẻ rỗng màn Trà Chiều · màn Lịch
các buổi). Docx chỉ chỉ vào một; để nguyên hai chỗ kia thì cùng một tình trạng
nói bằng hai giọng.

### Một chỗ đợt 1 làm THIẾU, nay đã bù

| # | Đổi thành | File |
|---|-----------|------|
| 11.1b | `Bước N **trên** 5` → `Bước N **/** 5` (5 chỗ) | `wr_jd_builder.dart` |

Đợt 1 đổi "buổi" → "bước" nhưng bỏ sót phần định dạng `1 / 5` của cùng dòng đó.

### Ba mục CỐ Ý không làm theo docx

1. **Dòng 57** — "Bức tranh tổng quan sau 27 lần nhìn lại…" (mục 7.1). Câu này
   sống trong `_CareerHealthCard`, mà `WorkReflection_Changelog_CareerSnapshot.docx`
   (khách gửi cùng ngày, mới hơn) yêu cầu **gộp thẻ đó vào Career Snapshot**.
   Nhóm A đã gộp, thẻ cũ không còn. Lời dẫn mới của thẻ gộp thay chỗ nó.
2. **Dòng 110** — "Nhật ký sự nghiệp của bạn chưa ghi nhận **cột mốc** nào".
   Chính khách bác lại chữ "cột mốc" ở §9.1 của changelog. Đang là
   **"chưa có ghi nhận nào"** — xem ghi chú đảo chiều ở §12 bên trên.
3. **Dòng 41** — "Tiếp tục" → "Đồng ý / Không đồng ý". Đây là **đổi hành vi**
   (chỉ "Đồng ý" mới ghi Insight), không phải đổi chữ. Thuộc **nhóm D** của
   `docs/ke_hoach_career_snapshot_100926.md`, chưa làm.

### Cổng chất lượng đợt 1B

| Cổng | Kết quả |
|------|---------|
| `flutter analyze` | **No issues found** |
| `flutter test` | **2266 pass · 24 skip · 1 đỏ** |
| APK debug | dựng được |

Nền trước khi sửa cũng là 2266 · 24 · 1 → **0 hồi quy**. Một đỏ vẫn là bài Trà
Chiều "Buổi A" đã hỏng sẵn trên `main`.

10 bài đỏ theo câu chữ đã sửa. Đáng ghi: `onboarding_test.dart` trước đây phân
biệt trang 1 với trang 2 **bằng nhãn nút** ("Tiếp tục" vs "Bắt đầu ngay"). Hai
nhãn nay bằng nhau nên cách đó chết. Đã chuyển sang khoá bằng **nhãn tag**
(Reflect · Understand · Grow) — thứ không đổi theo câu chữ.

---

## ĐỢT 2 + 3 + NHÓM C, D — ĐÃ XONG (10/09/2026)

### Đợt 2 — 4/4 ✅

| # | Việc | File |
|---|------|------|
| 3.2 | Câu gợi mở CỐ ĐỊNH "Viết ra bất cứ điều gì vừa xuất hiện trong đầu bạn lúc này." + cỡ chữ **70%** | `wr_reflect_flow.dart` (`kDetailPrompt`, `kDetailPromptScale`), `wr_detail_screen.dart` |
| 4.3 | Bỏ thẻ `selfReflection` ("Bạn đang đo sự phát triển bằng điều gì?") | `wr_meaning_screen.dart` |
| 4.4 | Bỏ khối "CHƯA BIẾT VIẾT GÌ?" + 4 thẻ gợi ý, xoá `_StemSuggestion`, `_useSuggestion` | `wr_meaning_screen.dart` |
| 5.4 | Hai nút Đồng ý / Không đồng ý → **nhóm D** bên dưới | |

**3.2 giữ dữ liệu, chỉ ngừng hiện.** `detailPrompt()` vẫn nhận
`reflectionQuestion` nhưng không dùng tới, nên cột `reflection_question` (hàng
trăm câu trong DB) không phải xoá — đảo lại sau này tốn một dòng.

**Câu hỏi §19 số 3 đã có trả lời trong chính docx cập nhật:** khách viết "sửa
thành câu cố định", tức là xác nhận bỏ câu riêng của từng tình huống.

### Một lỗi ĐỢT 1 để lọt, phát hiện khi làm 4.4

Mục 5.3 đổi nhãn thành **"Đúc kết phổ biến"**. Đợt 1 sửa đúng hằng
`kInsightNormalizingLabel`, nhưng `wr_meaning_screen.dart:381` **ghi cứng chuỗi
cũ** `'NHIỀU NGƯỜI KHÁC CŨNG TỪNG THẤY ĐIỀU NÀY'`. Hằng thành mã chết và câu mới
chưa bao giờ lên màn hình. Nay màn đọc từ hằng.

> Bài học: sửa một hằng KHÔNG chứng minh câu đó đang được dùng. Phải grep chính
> chuỗi CŨ trên toàn `lib/`, không phải grep tên hằng.

### Nhóm D — Đồng ý / Không đồng ý — 6/6 ✅

| # | Việc | Ở đâu |
|---|------|-------|
| D1 | Hai nút thay CTA "Tiếp tục" | `wr_meaning_screen.dart` `_buildAhaLayer` |
| D2 | Chỉ "Đồng ý" mới ghi Insight | `confirmMeaning(..., recordInsight:)` |
| D3 | Không đồng ý VẪN chốt Episode → STORY vẫn sinh | cùng chỗ |
| D4 | Trạng thái xác nhận sau khi từ chối | `_disagreed` + thẻ `wr_meaning_disagree_ack` |
| D5 | Ghi log tỷ lệ theo `situation_code` | bảng mới `wr_insight_feedback` |
| D6 | Test khoá: phép đếm tần suất **không** loại lần bị từ chối | `wr_reflection_flow_test.dart` |

**Không đồng ý vẫn giữ chữ người dùng tự viết.** Câu lưu lại là phần họ tự viết,
không kèm câu aha. Từ chối một góc nhìn được ĐỀ XUẤT không có nghĩa là vứt bỏ chữ
của chính mình — tài liệu không nói, nhưng làm ngược lại là phạt người dùng vì đã
trả lời thật.

**§10.2 làm bằng một NHỊP DỪNG, không bằng thanh thông báo.** Bản đầu tôi dùng
`SnackBar` rồi đẩy sang bước sau ngay — nhưng nó trôi qua trong lúc màn sau đang
dựng, tức là vẫn "im lặng chuyển sang bước sau" đúng cái §10.2 cấm. Nay màn đổi
sang lời xác nhận, và chính người dùng bấm "Tiếp tục".

**Câu hỏi §19 số 2** ("Không đồng ý khi chưa viết gì") — làm theo phương án tài
liệu đề nghị: cho đi tiếp, không lưu Insight. Có test riêng.

**⚠️ Hai migration CHƯA push:** `20260910000000_wr_insight_feedback.sql`,
`20260910000001_wr_polished_text.sql`.

### Đợt 3 — 3/3 ✅

**17.1 lọc dấu sao.** Bộ lọc dùng chung mới ở
`supabase/functions/_shared/strip_markdown.ts` (chuyển nguyên vẹn từ
`wr-chat/reply_shaping.ts`, đã chạy thật từ 03/08). Nay `wr-narrative` và
`wr-doc-analyze` cùng gọi. **Cộng thêm một tầng Dart** ở
`lib/core/logic/wr_plain_text.dart`, đặt tại `fromJson` của từng model AI —
`PatternNarrative`, `WrDocAnalysis`, `GrowthOpportunity`, `WrChatMessage`,
`WrChatReply`, và cả 22 trường của `ai_personalization_models.dart`.

Ba lý do phải có tầng thứ hai, không phải để chắc ăn cho vui:

1. `ai-personalize` **không nằm trong repo này** — không sửa được ở phía hàm.
2. Dữ liệu lưu TRƯỚC hôm nay vẫn còn nguyên dấu sao trong database.
3. Hàm mới thêm sau sẽ quên gọi bộ lọc — đã xảy ra đúng ba lần với ba hàm.

**Chỗ dễ làm sai nhất:** `wr_chat_messages.content` chở CẢ HAI vai. Lọc cả lượt
người dùng là âm thầm sửa chữ của họ (họ gõ `*` thật, dán JD có gạch đầu dòng).
Phân biệt bằng `role`. `raw_text` của `wr-doc-analyze` cũng KHÔNG lọc, cùng lý do.

**17.2 icon line art.** Quét toàn bộ `Icons.` trong `lib/`. Đổi:
`check_circle` (15 chỗ) · `star` · `visibility`/`visibility_off` · `camera_alt` ·
`card_giftcard` · `auto_awesome` · `play_arrow`/`pause` · `check_circle_rounded`
→ biến thể `_outlined`. Gộp luôn hai bí danh `_outline`/`_outlined` về một.

> **Hai chỗ độ ĐẶC đang chở THÔNG TIN, không phải trang trí.** Đổi cả hai nhánh
> về viền là mất thông tin. Nên đổi GLYPH thay vì đổi độ đặc:
> - Premium: `star` → **`workspace_premium_outlined`**, free giữ `star_outline`.
> - Đang nghe (STT): `mic` → **`stop_circle_outlined`**, nghỉ giữ
>   `mic_none_outlined`. Cùng cách `wr_voice_field.dart:180` đang dùng.
>
> Bốn bài test đỏ vì đúng chuyện này — chúng khoá đúng cái phân biệt trạng thái.

**17.3 test onboarding.** `router_test.dart` đã khoá logic thuần của
`computeRedirect`. Chỗ còn hở là mắt xích giữa hai đầu: trang 3 có GHI cờ không,
cờ đã ghi có được ĐỌC RA không, và ghép lại có đóng cửa onboarding không. 6 bài
mới ở `test/core/onboarding_once_only_test.dart`, kể cả vế ngược ("chưa xem thì
VẪN phải đi qua") — thiếu vế đó thì một lần sửa làm cờ luôn true sẽ đi lọt.

### Nhóm C — lớp 3 AI diễn đạt lại — 5/5 ✅

| # | Việc | Ở đâu |
|---|------|-------|
| C1 | Edge Function + prompt §7.1 nguyên văn 8 quy tắc | `supabase/functions/wr-polish/` |
| C2 | Rào chắn 1 — con số | `inspectPolished` (Dart + Deno) |
| C3 | Rào chắn 2 — từ cấm | cùng chỗ |
| C4 | Rào chắn 3 — 2 giây thì dùng câu gốc | `kPolishTimeout` |
| C5 | Gọi một lần rồi đệm; cờ bật/tắt | bảng `wr_polished_text` · `kPolishEnabled` |

**MẶC ĐỊNH TẮT** (`--dart-define=WR_AI_POLISH=true` để bật). Có chủ đích: lớp 3
làm câu chữ **không còn định trước được** — hai người cùng dữ liệu đọc ra hai
câu khác nhau. Đội nội dung cần đọc một mẻ và khách cần đồng ý với giọng đó
trước khi bật cho người dùng thật.

**Rào chắn 1 phải đổi luật ngay khi viết test.** Bản đầu so hai dãy số theo THỨ
TỰ XUẤT HIỆN. Nghe thì chặt, nhưng nó huỷ đúng cái việc model được giao:

```
gốc:      "Bạn đã nhìn lại 21 lần trong 30 ngày qua, tăng so với 12 lần…"
viết lại: "Trong 30 ngày qua bạn nhìn lại 21 lần, nhiều hơn 12 lần…"
```

Không con số nào đổi — chỉ đảo mệnh đề, mà đảo mệnh đề CHÍNH LÀ cách viết lại
một câu cho tự nhiên hơn. So theo thứ tự thì phần lớn bản viết lại tốt đều bị
huỷ và lớp 3 không bao giờ hiện. So TẬP HỢP trần thì lại lọt ca nguy hiểm nhất
("3 lần trong 14 ngày" → "14 lần trong 3 ngày"). **Luật cuối: so các cặp SỐ +
ĐƠN VỊ đã sắp xếp** — đảo mệnh đề thì cặp y nguyên, tráo số giữa hai đơn vị thì
cặp đổi và bị bắt.

**Một hạn chế cố ý:** model viết "ba mươi" thay cho "30" thì bị huỷ. Chấp nhận
được — nhận ca đó nghĩa là phải phân giải số viết bằng chữ, tức là mở một tầng
ĐOÁN mới ngay giữa cái tầng sinh ra để chặn việc đoán. Có test ghi rõ.

**§7.3 cấm nhờ AI viết lại câu chỉ dẫn của mục 6.** `deepTextIsGuidance()` so
đúng bằng ba hằng. Rào chắn 1 chặn được con số nhưng không chặn được "làm bộ 15
câu" thành "hoàn thành bài đánh giá".

### Cổng chất lượng

| Cổng | Kết quả |
|------|---------|
| `flutter analyze` | **No issues found** |
| `flutter test` | **2310 pass · 24 skip · 1 đỏ** |
| `deno test supabase/functions/` | **123 passed · 0 failed** |
| APK debug | dựng được |

Nền trước đợt này: 2266 · 24 · 1 → **+44 bài mới, 0 hồi quy**.

---

## CỔNG CHẤT LƯỢNG ĐỢT 1

| Cổng | Kết quả |
|------|---------|
| `flutter analyze` | **No issues found** |
| `flutter test` | **2224 pass · 24 skip · 1 đỏ** |
| APK debug | dựng được |

**Số liệu nền đo trên `main` TRƯỚC khi sửa: 2224 pass · 24 skip · 1 đỏ.**
Giống hệt. Nghĩa là đợt 1 **không thêm một hồi quy nào**.

Cách đo: `git stash` → `flutter test` trên cây sạch → `git stash pop`. Log giữ
ở scratchpad phiên làm việc.

### Một đỏ đó là gì

`wr_meeting_2026_07_29_test.dart` › "Trà Chiều Nghề Nghiệp thẻ buổi nói đủ tên,
mô tả, giờ, địa điểm và giá" — tìm không thấy `"Buổi A"` trên màn.

**Đã đỏ sẵn trên `main`, không liên quan đợt 1.** Màn Trà Chiều vẫn bọc tiêu đề
trong ngoặc kép (`wr_tra_chieu_screen.dart:182,391`), nên nhiều khả năng thẻ
không được dựng ra chứ không phải sai câu chữ — nghi bộ lọc `category` (xem ghi
chú trong `wr_tra_chieu.dart`: web đặt tiếng Anh thì `category` xuống DB là bản
tiếng Anh). **Chưa sửa** — để riêng, không trộn vào đợt câu chữ.

### 45 test phải sửa theo

Đợt 1 làm đỏ 45 bài vì chúng khoá đúng chuỗi cũ. Đã sửa hết. Hai chỗ đáng ghi:

1. **`wr_self_check_screen.dart` `_InfoRow` tràn layout.** 12 bài đỏ cùng một
   lỗi `RenderFlex overflowed by 87 pixels`. Không phải sai chuỗi: `Row` cho con
   không co giãn chiều rộng vô hạn, nên `Text` trần không bao giờ xuống dòng. Ba
   câu mới của §15.4 dài hơn ba câu emoji cũ nên chạm đúng bẫy đó. Đã bọc
   `Expanded`. **Lỗi này có sẵn trong mã, chỉ chưa đủ chữ để lộ ra.**

2. **`wr_discover_two_tier_test.dart` › "nói rõ hai nguồn khác nhau".** Bài này
   khoá đúng cái vế mà §7.1 yêu cầu bỏ. Không đổi chuỗi cho qua — đã viết lại ý
   định: cái cần khoá là HÀNH VI (người đã tự đánh giá vẫn phải có bức tranh
   riêng tính từ hành vi, đúng lỗi khách báo ở họp 26_1), không phải câu chữ.
   Ba khối pillar vẫn khoá nguyên phần đó.

---

## A7 · A8 · B1 — ĐÃ XONG (10/09/2026, khách chốt)

### A7 — bộ nhãn thang đánh giá

Khách chọn **bộ thứ ba**: `Đang hỗ trợ tốt` / `Ổn, còn dư địa` / `Đang cản trở`.
Bộ này là bộ cả thư viện câu Diễn giải sâu rẽ nhánh theo.

**Ngưỡng KHÔNG đổi (3.8 / 2.5).** Mockup chấm Likert 1–4 còn app chấm 1–5; bê
ngưỡng mockup sang là mọi người dùng cũ mở app lên thấy đánh giá của mình tự
nhiên khác đi mà không ai chạm vào dữ liệu của họ.

Gộp về MỘT nguồn thay vì sửa chữ ở từng chỗ:

| Chỗ | Trước | Sau |
|---|---|---|
| `ScaPillarStatus.label` | bộ chữ cũ | bộ mới, là nguồn duy nhất |
| `pillarStatusLabel` (Hiểu mình) | **chép** cả ngưỡng lẫn chữ | uỷ lại `scaPillarStatus().label` |
| `_scaStatus` (`/understand`) | cắt ở **4.0**, bộ chữ riêng | đi qua `scaPillarStatus` (3.8) |

Màn `/understand` cắt ở 4.0 trong khi màn Hiểu mình cắt ở 3.8 — cùng một điểm
3.9 đọc ra hai kết luận ngược nhau ở hai màn, đúng lỗi §7.2 changelog bắt sửa.

Thêm `ScaPillarStatus.inlineLabel` cho dạng nhúng giữa câu: nhãn mức giữa mang
sẵn một dấu phẩy, nên `label.toLowerCase()` làm câu "tự đánh giá ổn, còn dư địa,
vừa là nơi…" vỡ thành hai mệnh đề rời.

### A8 — tên ba trụ

Chốt **bộ ngắn**: `Sự rõ ràng` / `Mối quan hệ` / `Cách làm việc`. Ba lý do: đó
là bộ mockup v18 dùng, bộ bản dev đang chạy, và bộ của nguồn 15 câu
`SCA_QUESTIONS`. Chọn nó nghĩa là **0 thay đổi trên lối chính** — không có rủi
ro áp một nửa.

Gỡ bộ thứ hai còn sót ở màn `/understand` (Minh bạch vai trò / An toàn khi lên
tiếng / Định hướng ý nghĩa).

### B1 — nguyên tắc gộp "Trải nghiệm hiện tại"

Đã xong từ nhóm A: `_CareerSnapshotCard` thay hẳn hai khối cũ. Khách gửi lại ba
file sáng 10/09 chính là nguồn của nhóm A–E, đã làm hết.

---

## BẢN TIẾNG ANH — ĐÃ XONG (10/09/2026)

1.891 nhóm chuỗi tiếng Việt viết thẳng trong mã, trải trên 99 file. Đã bọc
**1.863 nhóm**; 28 nhóm còn lại cố ý không dịch (bên dưới).

### Vì sao không dùng `.arb` như nửa còn lại của app

App có sẵn `AppLocalizations` sinh từ `app_vi.arb`, và onboarding · đăng nhập ·
khảo sát đi qua nó. Nhưng 49 file của phần WorkReflection không gọi nó lần nào,
và **khoảng một nửa câu chữ của phần WR không dựng trong widget** mà dựng trong
`lib/core/logic/*.dart` — thư viện câu Diễn giải sâu, câu Self-Check, câu tường
thuật Story, câu luồng Reflect. Đó là hàm THUẦN, không có `BuildContext`.

Dùng `.arb` nghĩa là luồn một tham số localizations qua khoảng một trăm hàm
thuần và toàn bộ bài test đang khoá chúng — sửa chữ ký của mọi hàm sinh câu chỉ
để đổi chỗ lấy chuỗi.

Nên: `tr('bản gốc', 'translation')` đặt ngay tại chỗ dùng
(`lib/core/l10n/wr_tr.dart`). Hàm thuần dùng được, widget cũng dùng được; đội
nội dung rà bản dịch ngay cạnh bản gốc; mặc định tiếng Việt nên **không phải sửa
bài test nào** trong 2.316 bài đang khoá chuỗi tiếng Việt.

Phần ĐÃ nằm trong `.arb` giữ nguyên ở `.arb`.

### Hai cái bẫy phải biết trước khi dịch thêm file mới

**1 · Hằng chở `tr()` phải thành GETTER, không phải `final`.** `final kFoo =
tr(…)` ở tầng file chốt ngôn ngữ tại lần đọc ĐẦU TIÊN, nên người đổi ngôn ngữ
giữa phiên vẫn thấy chữ cũ tới khi khởi động lại app. Không bài test nào đọc
hằng đúng một lần bắt được lỗi này — nên `wr_english_build_test.dart` đọc HAI
lần, hai bên một lần đổi ngôn ngữ.

**2 · Đối số hàm tạo của `enum` bắt buộc là hằng biên dịch.** Ba enum phải
chuyển nhãn sang getter: `ScaPillarStatus`, `OrgSurveyArea`, `OrgSurveyStanding`.

### Bốn file CỐ Ý không dịch

Không phải chữ trên màn hình mà là **dữ liệu đem đi SO KHỚP** với tiếng Việt của
người dùng. Dịch là làm hỏng chức năng:

| File | Là gì |
|---|---|
| `voice_answer_matcher.dart` | từ khoá nhận dạng giọng nói |
| `wr_skill_jd_match.dart` (dòng 39–82) | từ khoá dò trong JD người dùng tải lên |
| `wr_tra_chieu.dart` (dòng 89–95) | bảng bỏ dấu tiếng Việt |
| `wr_polish_guard.dart` | từ cấm của lớp 3 (lớp 3 đang TẮT, prompt tiếng Việt) |

Cùng lý do: regex đổi "tôi"→"mình" ở `wr_chat_starters.dart`, và các chuỗi chỉ
đi vào log/assert (`wr_flow_error.dart`, `wr_episode_repository.dart`).

### Ngôn ngữ được đặt ở đâu

`appLocaleProvider` (đã có sẵn, kèm nút đổi trong Tài khoản) → `wrSetLocale()`
gọi ở `main()` trước khung hình đầu tiên và ở đầu `WrApp.build` mỗi lần đổi.

---

## CÒN LẠI

Toàn bộ phần **làm được mà không chờ ai** đã xong: đợt 1, 1B, 2, 3, nhóm A, B,
C, D, E. Còn lại đúng ba loại.

### 1 · Chờ khách chốt câu chữ
- ~~**A7** bộ nhãn thang đánh giá~~ — **XONG 10/09**, khách chọn bộ thứ ba.
- ~~**A8 / E2** tên ba trụ~~ — **XONG 10/09**, chốt bộ ngắn.
- **Hai màn Khoảnh khắc / Năng lượng** — giữ làm nhánh phụ của chatbox, bỏ hẳn,
  hay đưa vào lối chính? (Xem §0 của `ke_hoach_career_snapshot_100926.md`.)
- **Bật lớp 3 AI hay không** — đã dựng xong, mặc định TẮT. Cần khách đọc một mẻ
  bản viết lại rồi đồng ý với giọng đó.
- ~~**B1** nguyên tắc gộp~~ — **XONG**: chính là `Changelog_CareerSnapshot.docx`
  khách gửi sáng 10/09, đã làm trọn ở nhóm A (`_CareerSnapshotCard`).
- **17.4** rà lỗi chính tả — vẫn chờ khách gửi ảnh chụp chỗ sai.

### 2 · Việc NGOÀI MÃ, phải làm bằng tay
- ⚠️ **Sửa mô tả sản phẩm trên App Store Connect** cho khớp câu chữ IAP mới
  (16.6 / 16.7). Apple đã từ chối một lần vì Guideline 3.1.1. **Chặn cứng việc
  nộp bản mới.**
- ⚠️ **Push 2 migration:** `20260910000000_wr_insight_feedback.sql`,
  `20260910000001_wr_polished_text.sql`. Chưa push thì nhóm D ghi log hỏng (âm
  thầm, best-effort) và lớp 3 không đệm được.
- ⚠️ **Deploy Edge Function `wr-polish`** — chỉ cần khi bật lớp 3.

### 3 · Việc lớn, nên tách riêng
- ~~**17.5 bản tiếng Anh**~~ — **XONG 10/09**, xem phần riêng phía trên. Không
  đi đường `.arb`; lý do ghi ở đó.

### Bốn câu hỏi §19 — nay còn một
| # | Câu hỏi | Trạng thái |
|---|---------|-----------|
| 1 | Đếm tổng số lần: cửa sổ 30 hay trọn đời? | **Đã giải** ở A5 — đếm thật, trần nâng lên 500 (`kEpisodeHistoryLimit`) |
| 2 | "Không đồng ý" khi chưa viết gì | **Đã làm** theo phương án tài liệu đề nghị, có test riêng |
| 3 | Câu gợi mở cố định | **Khách tự xác nhận** trong docx cập nhật ("sửa thành câu cố định") |
| 4 | Bản tiếng Anh: toàn app hay chỉ màn App Review? | **Đã giải** — khách chốt làm toàn app, đã xong 10/09 |
