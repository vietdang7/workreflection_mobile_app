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
| 12.2 | Bạn đã ghi lại N cột mốc trên hành trình sự nghiệp. (6 chỗ) | `wr_journey_screen.dart`, `wr_user_guide.dart` |
| 12.3 | GÓC NHÌN PHÁT TRIỂN | `wr_journey_screen.dart` |
| 12.4 | Gợi ý này được đúc kết từ hoạt động nhìn lại của bạn… | `wr_mood_content.dart` `kConfidenceNote` |
| 12.5 | Cập nhật bối cảnh công việc | `wr_journey_screen.dart` |
| 12.6 | Để gợi ý chính xác hơn | `wr_journey_screen.dart` |
| 12.7 | Mở khóa bản đầy đủ để nhìn lại toàn bộ bức tranh thay đổi… | `wr_journey_screen.dart`, `wr_journey_narrative_screen.dart` |
| 12.8 | Nhật ký sự nghiệp của bạn chưa ghi nhận cột mốc nào… | `wr_journey_screen.dart` (2 chỗ) |

> ⚠ **Xung đột từ vựng, cần biết trước khi sửa tiếp.** Trong mã, "cột mốc" đã
> có nghĩa hẹp sẵn: **một CỜ trên STORY**, không phải bản ghi riêng (changelog
> 24/08). Khách nay dùng "cột mốc" cho MỌI mảnh Career Memory. Cách xử lý đã
> chọn: **đổi chữ trên màn hình, giữ nguyên từ "mảnh ký ức" trong chú thích và
> tên biến**. Đừng đổi tên biến theo — sẽ không phân biệt được hai khái niệm nữa.

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

## CÒN LẠI

### Đợt 2 — đụng luồng và dữ liệu
- 3.2 câu hỏi gợi mở cố định + cỡ chữ 70% (dùng `titleScale` đã có)
- 4.3 bỏ thẻ "Bạn đang đo sự phát triển bằng điều gì?"
- 4.4 bỏ khối "CHƯA BIẾT VIẾT GÌ?" + 4 thẻ gợi ý
- 5.4 hai nút Đồng ý / Không đồng ý (đổi hành vi, cần chốt ca "bỏ qua rồi Không
  đồng ý")

### Đợt 3 — toàn app
- 17.1 lọc dấu `*`/`**` do model sinh ra (4 Edge Function + một lớp phía app)
- 17.2 quét toàn bộ icon về line art
- 17.3 thêm test khoá hành vi onboarding 3 trang

### Đợt 4 — chờ khách
- B1 nguyên tắc gộp "Trải nghiệm hiện tại" vào Career Health Check
- B2 file 22 màn hình
- B3 ảnh chụp lỗi "tình thường"

### Đợt 5
- 17.5 bản tiếng Anh (~1.500 chuỗi trên 83 file, phải tách `.arb` trước)

### Bốn câu hỏi khách chưa trả lời
Xem §19 của `docs/chinh_sua_noi_dung_2026-09-09.md`. Đợt 1 không phụ thuộc câu
nào trong số đó.
