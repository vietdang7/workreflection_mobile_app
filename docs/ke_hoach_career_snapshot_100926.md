# Kế hoạch — Career Snapshot + Diễn giải sâu (khách gửi 10/09/2026)

Nguồn (FileTam/workreflection):
- `WorkReflection_Changelog_CareerSnapshot.docx` — gộp Self-Check và Pattern Reflection
- `WorkReflection_DienGiaiSau_NoiDung.docx` — đặc tả nội dung + kiến trúc AI ba lớp
- `WorkReflection_Sprint2_Mockup_v18.html` — giao diện tham chiếu (`careerSnapshotCard()`)

Tài liệu này nối tiếp `tien_do_chinh_sua_noi_dung_090926.md` (đợt 1 đã xong, PR #19).

---

## 0. Trả lời ngay: hai màn hình khách không tìm thấy

| Ảnh | Màn | File | Đường dẫn |
|---|---|---|---|
| `Pasted image (68).png` — "KHOẢNH KHẮC · Điều gì đang diễn ra với bạn?" | Chọn Human Moment (6 ô) | `lib/features/wr/presentation/flow/wr_moment_screen.dart` | `/wr/flow/moment` |
| `Pasted image (69).png` — "LÚC NÀY · Năng lượng của bạn thế nào?" | Chọn năng lượng (3 ô) | `lib/features/wr/presentation/flow/wr_energy_screen.dart` | `/wr/flow/energy` |

**Vì sao khách bấm mãi không ra:** cả hai màn chỉ nằm trên MỘT lối vào duy nhất, và
đó không phải lối chính.

```
Home  →  chạm ô cảm xúc 2×2  →  /wr/flow/step        ← lối chính, BỎ QUA cả hai màn
Hỏi (chatbox) → AI gợi ý "Ghi lại thành một Reflection"
      →  /wr/flow/energy  →  /wr/flow/moment  →  /wr/flow/step   ← lối duy nhất đi qua
```

- `wr_home_screen.dart:389` đặt sẵn `pendingEnergy` + `pendingMood` từ ô cảm xúc rồi
  nhảy thẳng `/wr/flow/step` (dòng 417).
- `wr_step_screen.dart:168` tự suy khoảnh khắc bằng `momentForMood(mood)`, nên luồng
  chính không cần hỏi.
- `wr_chat.dart:49` là chỗ duy nhất còn trỏ tới `/wr/flow/energy`.

**Hệ quả cần khách quyết:** màn Khoảnh khắc gần như đã chết. Với lối chính, giá trị
`human_moment` của Episode luôn là giá trị suy ra từ mood, không phải điều người dùng
tự chọn. Ba hướng: (a) giữ nguyên, coi hai màn là nhánh phụ của chatbox; (b) bỏ hẳn
hai màn, dọn `momentForMood` thành nguồn duy nhất; (c) đưa màn Khoảnh khắc vào lối
chính, chấp nhận thêm một bước.

---

## 1. Ước lượng tổng

| Nhóm | Hạng mục | Ngày công | Chặn |
|---|---|---|---|
| **A** | Career Snapshot — gộp hai khối | **2.0** | A7, A8 chờ khách |
| **B** | Diễn giải sâu — thư viện câu + lớp 1, 2 | **3.0** | — |
| **C** | Lớp 3 AI diễn đạt lại | **1.5** | cần bật cờ + Edge Function |
| **D** | Đồng ý / Không đồng ý (§10) | **1.5** | §19 câu hỏi chưa trả lời |
| **E** | Dọn kèm (em dash, tên ba trụ, "ghi nhận") | **0.5** | E2 chờ khách |
| | **Tổng** | **8.5 ngày công** | |

Tin tốt: phần backend §8 tài liệu lo lắng thì **app đã có sẵn gần hết**, xem mục 6.

---

## 2. Nhóm A — Career Snapshot (2.0 ngày) — **A1–A6 ĐÃ XONG 10/09**

Nhánh `feat/career-snapshot-100926` (cắt từ nhánh đợt 1, cần merge PR #19 trước).
Cổng: analyze sạch · **2240 pass / 24 skip / 1 đỏ** (đỏ đó là Trà Chiều "Buổi A",
hỏng sẵn trên `main`) · APK debug dựng được. So với nền 2224 → **+16 bài mới,
0 hồi quy**.


Đang có hai khối riêng trên `wr_discover_screen.dart`:
`_ScaCard` ("TRẢI NGHIỆM HIỆN TẠI", dòng 514) và `_CareerHealthCard`
("Career Health Check", dòng 668). Cả hai in ba trụ, cả hai dùng chung bộ nhãn
đánh giá — đúng cái mâu thuẫn khách chụp lại.

| # | Việc | File | Ngày | |
|---|---|---|---|---|
| A1 | Gộp thành một `_CareerSnapshotCard`, mỗi trụ MỘT dòng, hai cột "Bạn đánh giá" / "Xuất hiện" | `wr_discover_screen.dart` | 0.5 | ✅ |
| A2 | Cột phải chuyển hẳn sang tần suất `{count} / {total} lần`. Xoá `behaviourPillarLabel` + `behaviourPillarIsHealthy` | `wr_career_health.dart` | 0.3 | ✅ |
| A3 | Ba trạng thái mở khoá độc lập; ô trống là LỜI MỜI, **không blur** | `wr_discover_screen.dart` | 0.3 | ✅ |
| A4 | Dòng "Self-Check gần nhất: dd/MM/yyyy" + gợi ý làm lại sau 3 tháng | `wr_career_health.dart` | 0.2 | ✅ |
| A5 | `reflectionTotal` đếm thật, không qua `recentSituationIds` (chặn 30) | `wr_career_health.dart`, `wr_providers.dart` | 0.2 | ✅ |
| A6 | Dòng khoảng lệch: Free = lời mời mở khoá, Premium = câu diễn giải | `wr_discover_screen.dart` | 0.3 | ✅ |
| A7 | ⚠️ Đổi thang nhãn sang `Đang hỗ trợ tốt / Ổn, còn dư địa / Đang cản trở` | 4 file | 0.2 | chờ khách |
| A8 | ⚠️ Thống nhất tên ba trụ trên mọi màn | toàn app | — | chờ khách |

### Ba việc phát sinh khi làm thật, không có trong tài liệu

**Trần 50 Episode là cái chặn thật, không phải cửa sổ 30.** Tài liệu §8 cảnh báo
`recentSituationIds` chặn 30 mục. Đúng, và đã tránh — nhưng chặn thật nằm ở
`wrEpisodeHistoryProvider`, vốn gọi `fetchEpisodes(limit: 50)`. Người nhìn lại
200 lần vẫn đọc "14 / 50 lần". Đã nâng trần lên **500** (`kEpisodeHistoryLimit`).
Vẫn giữ một trần: bỏ hẳn thì tài khoản dùng nhiều năm kéo về danh sách không
giới hạn ngay lúc mở app. **Con số ở mọi màn đọc provider này sẽ đổi với người
dùng nặng** — đúng hướng, nhưng cần biết trước.

**Mockup dùng `else if` cho hai lời mời, code dùng hai `if` độc lập.** Với
`else if`, người mới — chưa Self-Check, mới nhìn lại vài lần — chỉ thấy lời mời
làm Self-Check và không bao giờ biết cột bên kia còn thiếu bao nhiêu. §4 nói hai
nguồn độc lập, vậy mỗi nguồn cũng tự nói phần của mình còn thiếu gì.

**Hai lời mời mua cùng một thứ.** Dòng khoảng lệch đã mang sẵn nút mở khoá Diễn
giải sâu, mà cuối màn còn một thẻ `_SelfCheckDeepLock` nữa. Nay thẻ đó chỉ dựng
khi dòng khoảng lệch KHÔNG hiện.

**A2 là điểm mấu chốt.** Tài liệu §2 nói rõ: tần suất cao KHÔNG đồng nghĩa với "tệ".
Hàm `behaviourPillarLabel` hiện đang gán "Ưu tiên cải thiện" cho tỉ trọng ≥ 0.45 —
đúng cái suy diễn vượt quá dữ liệu mà tài liệu yêu cầu bỏ hoàn toàn.

**A5 — cái bẫy đã có sẵn:** `recentSituationIds` giới hạn 30 mục gần nhất, nên nếu
lấy độ dài mảng làm mẫu số thì người nhìn lại 80 lần vẫn thấy "14 / 30 lần".

### ⚠️ A7 — chỗ cần khách chốt

Hai tài liệu ghi ba bộ nhãn khác nhau cho cùng một thang:

| Nguồn | Bộ nhãn |
|---|---|
| App đang chạy | Đang phát triển / Cần chú ý / Ưu tiên cải thiện |
| Changelog bảng 2 | Ổn định / Đang cải thiện / Cần chú ý |
| Changelog bảng 3 + mockup v18 + toàn bộ Diễn giải sâu | **Đang hỗ trợ tốt / Ổn, còn dư địa / Đang cản trở** |

Đề xuất: lấy bộ thứ ba, vì cả thư viện câu ở tài liệu Diễn giải sâu đều rẽ nhánh
theo đúng ba chữ đó.

**Ngưỡng phải quy đổi, không bê thẳng:** mockup chấm Likert 1–4 (`>=3`, `>=2`), app
chấm Likert 1–5. Quy đổi theo tỉ lệ ra `>=3.67` / `>=2.33`, rất sát ngưỡng app đang
dùng (`>=3.8` / `>=2.5`). **Giữ ngưỡng app, chỉ đổi chữ** — đổi ngưỡng là mọi người
dùng cũ thức dậy thấy đánh giá của mình tự nhiên khác đi.

### ⚠️ A8 — tên ba trụ, khách phải chốt

Tài liệu §7.2 tự ghi "đây là quyết định nội dung cần chị Yumi chốt trước khi dev áp
dụng đồng loạt". Ba bộ đang tồn tại:

- Màn Hiểu (bản dev + mockup v18): **Sự rõ ràng / Mối quan hệ / Cách làm việc**
- Mockup v17: Minh bạch vai trò / An toàn khi lên tiếng / Định hướng ý nghĩa
- Màn Diễn giải sâu: Sự rõ ràng trong công việc / Niềm tin và an toàn để lên tiếng / Nhịp thực thi và nhìn lại

Chưa chốt thì chưa làm — đây là sửa một chuỗi ở `SelfCheckPillar.displayName` nên
ngày công gần bằng không, nhưng chọn sai thì phải sửa lại trên hơn mười màn.

---

## 3. Nhóm B — Diễn giải sâu, lớp 1 và lớp 2 (3.0 ngày)

`wr_sca_deep_dive.dart` đã có sẵn khung ba lớp nhưng nội dung là bản 24/08, mỗi
nhánh đúng một câu. Tài liệu mới thay toàn bộ bằng thư viện 25 câu.

| # | Việc | Ngày |
|---|---|---|
| B1 | Lớp 1 dữ kiện: `dominantPillar` trả null khi **không trụ nào vượt 40%** | 0.3 |
| B2 | Tầng 1 Khoảng lệch — 4 nhánh A/B/C/D × 3 biến thể = 11 câu, xoay vòng | 0.8 |
| B3 | Tầng 2 Xu hướng Reflection — 2 cửa sổ liền kề, mỗi cửa sổ ≥ 10 lần, 5 câu | 0.7 |
| B4 | Tầng 3 Xu hướng Self-Check — ≥ 2 lần cách nhau ≥ 6 tuần, 6 câu | 0.5 |
| B5 | Ba câu "chưa đủ dữ liệu" theo giọng mời gọi, cấm mọi câu báo lỗi | 0.2 |
| B6 | Dựng lại màn: MỘT insight dẫn dắt + xu hướng + hai trụ còn lại rút gọn | 0.5 |

**B1 khác hẳn luật đang chạy.** `dominantPatternPillar` hiện chỉ loại trường hợp HOÀ
tuyệt đối, nên 10 / 9 / 8 lần vẫn tuyên bố có một trụ nổi trội — đúng cái tài liệu
cảnh báo. Luật mới: trụ cao nhất phải chiếm > 40% tổng, không thì trả null và đi
nhánh C.

> Luật 40% **đã có sẵn** ở `dominantPillar()` trong `wr_career_health.dart` (làm
> cùng nhóm A). B1 chỉ còn việc cho màn Diễn giải sâu dùng chung hàm đó thay vì
> `dominantPatternPillar` của riêng nó.

**⚠️ Một lỗi có sẵn phải sửa trong B1, chưa ai báo.** Có HAI hàm cùng tên
`pillarOfDimension`:

- `wr_career_health.dart` — trả `null` cho hai nhóm tình huống tích cực
  (P-ACHIEVE, P-STEADY).
- `wr_self_check_narrative.dart:328` — `_ => SelfCheckPillar.a`, tức **nuốt cả
  hai nhóm tích cực vào trụ A**.

`wr_sca_deep_dive.dart` import bản thứ hai, nên `pillarPatternCounts` đang cộng
mọi lượt "vừa làm được điều hay" vào "Cách làm việc". Hệ quả: trụ A bị thổi
phồng và có thể thành trụ nổi trội giả, rồi cả câu diễn giải dựng trên đó đều
sai. Career Snapshot không dính vì nó dùng bản đúng.

**B6 là thay đổi lớn nhất về hình.** Bản hiện tại in 3 trụ × 3 lớp = 9 khối văn bản.
Tài liệu gọi thẳng đó là một bản báo cáo và người dùng sẽ lướt qua. Thứ tự ưu tiên
chọn insight dẫn dắt: nhánh A (lệch pha) → B → D → C.

---

## 4. Nhóm C — Lớp 3 AI diễn đạt lại (1.5 ngày)

Tuỳ chọn, có cờ bật/tắt. Bỏ hẳn lớp này thì sản phẩm vẫn chạy đúng.

| # | Việc | Ngày |
|---|---|---|
| C1 | Edge Function nhận câu đã ghép ở lớp 2, gọi model với prompt §7.1 | 0.5 |
| C2 | Rào chắn 1 — trích mọi con số ở câu gốc và câu AI, khác nhau thì huỷ | 0.3 |
| C3 | Rào chắn 2 — quét danh sách từ cấm CCOS, dính thì huỷ | 0.2 |
| C4 | Rào chắn 3 — quá 2 giây thì dùng câu gốc, không bao giờ hiện vòng xoay | 0.2 |
| C5 | Chỉ gọi một lần lúc tạo mới nội dung rồi lưu lại; cờ cấu hình bật/tắt | 0.3 |

Cả ba rào chắn rơi về cùng một hành vi dự phòng: dùng câu lớp 2. Câu đó vốn đã hoàn
chỉnh nên AI hỏng không gây hậu quả gì.

---

## 5. Nhóm D — Đồng ý / Không đồng ý (1.5 ngày)

Đây là mục 5.4 của đợt 2, nay tài liệu mới cho đủ đặc tả. **Không phải sửa câu chữ,
là đổi luồng dữ liệu.**

| # | Việc | Ngày |
|---|---|---|
| D1 | Hai nút thay CTA "Tiếp tục" ở bước Góc nhìn khác | 0.3 |
| D2 | Bấm Đồng ý mới ghi Insight; Không đồng ý thì bỏ qua | 0.3 |
| D3 | Lần Reflection VẪN tạo STORY bình thường, chỉ không kèm đúc kết | 0.2 |
| D4 | Trạng thái phản hồi sau khi bấm Không đồng ý | 0.2 |
| D5 | Ghi log tỷ lệ đồng ý / không đồng ý theo `situationId` | 0.3 |
| D6 | Test khoá: phép đếm tần suất **không** loại lần bị từ chối | 0.2 |

**D6 là chỗ dễ làm sai nhất trong cả hạng mục** — tài liệu §10.1 nói thẳng như vậy.
Nếu lọc bỏ các lần bị từ chối khỏi phép đếm, cột "Xuất hiện" thiếu hụt và mọi kết
luận về khoảng lệch sai theo. Tần suất đo việc người dùng GẶP tình huống, không đo
việc họ ĐỒNG Ý với cách diễn giải.

---

## 6. Backend — §8 lo lắng, nhưng app đã có sẵn

| Tài liệu yêu cầu | Trạng thái trong app |
|---|---|
| Reflection lưu kèm timestamp và dim | ✅ `Episode.openedAt` + `situation.scaDimension` |
| `scaCompletedDate` | ✅ `ScaSelfCheckResponse.takenAt` |
| `scaHistory` — mảng bản ghi riêng, không ghi đè | ✅ mỗi lần là một dòng trong `wr_sca_self_check_responses` |
| `reflectionTotal` là số thật trong cửa sổ | ⚠️ **chưa** — xem A5 |
| `SNAPSHOT_DEMO_COUNTS`, `snapshotPreview` | ❌ demo của mockup, không đưa vào bản thật |

Chỉ còn đúng một việc backend, và nó nằm ở tầng tính toán của app chứ không cần
migration nào.

---

## 7. Nhóm E — dọn kèm (0.5 ngày)

| # | Việc | Trạng thái |
|---|---|---|
| E1 | §7.1 rà em dash trong copy màn Hiểu | Đợt 1 đã dọn, rà lại phần mới viết |
| E2 | §7.2 tên ba trụ | ⚠️ = A8, chờ khách |
| E3 | §9 "ghi nhận" cho tổng số Career Memory | ⚠️ **ngược với đợt 1**, xem dưới |

### ⚠️ E3 — đợt 1 đã làm ngược, phải sửa lại

Đợt 1 (PR #19, chưa merge) đổi "mảnh ký ức" → **"cột mốc"** cho tổng số Career
Memory. Tài liệu mới §9.1 bác đúng cách làm đó, và bác bằng chính lý do tôi đã ghi
lại lúc đó: "Cột mốc" là tên của MỘT trong bốn loại (Câu chuyện, Cột mốc, Chủ đề,
Insight), nên dùng nó cho vật chứa sẽ ra "42 cột mốc" ở tiêu đề mà bên dưới chỉ có
vài mục thật sự mang nhãn Cột mốc.

**Chốt mới: dùng "ghi nhận" cho tổng số, giữ "Cột mốc" cho riêng loại MILESTONE.**
Câu mẫu: `Bạn đã có 42 ghi nhận trên hành trình sự nghiệp.`

Việc phải làm: sửa lại toàn bộ chỗ đợt 1 vừa đổi — thẻ xem trước ở tab Hành trình,
màn danh sách đầy đủ, màn trống khi chưa có dữ liệu. Rà cả "mảnh ký ức" lẫn "cột
mốc" dùng cho vật chứa.

---

## 8. Thứ tự đề nghị

1. **E3** trước tiên, gộp vào PR #19 khi chưa merge — sửa sớm thì không phải sửa hai lần.
2. **A1–A6** — chính cái mâu thuẫn khách chụp lại.
3. **B1–B6** — thư viện câu, làm được ngay, không chờ ai.
4. **D** — chờ §19 trả lời "Không đồng ý khi chưa viết gì thì sao".
5. **C** — cuối cùng, vì bỏ đi vẫn chạy.
6. **A7, A8** — chờ khách chốt chữ.

## 9. Câu hỏi gửi khách

1. **Tên ba trụ** (A8) — tài liệu tự đánh dấu cần chị Yumi chốt.
2. **Bộ nhãn thang đánh giá** (A7) — xác nhận lấy "Đang hỗ trợ tốt / Ổn, còn dư địa / Đang cản trở".
3. **Hai màn Khoảnh khắc và Năng lượng** (mục 0) — giữ làm nhánh phụ, bỏ hẳn, hay đưa vào lối chính?
4. Bốn câu cũ của §19 kế hoạch 09/09 vẫn chưa có trả lời.
