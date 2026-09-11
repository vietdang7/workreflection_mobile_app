# Diễn giải sâu v2 — dựng lại theo đặc tả khách gửi 11/09/2026

Nguồn: `WorkReflection_DienGiaiSau_v2.docx` (FileTam, ngoài repo). Bản này
**thay thế hoàn toàn** `WorkReflection_DienGiaiSau_NoiDung.docx` (v1, 10/09).

---

## 1. Lỗi khách báo, đo lại trên dữ liệu thật

Tài khoản `3229092a-aeff-42ad-a513-b6bf80ca0b8f`, 30 ngày tính tới 11/09/2026:

| | Số lượt |
|---|---|
| Tổng nhìn lại | 31 |
| Tình huống thách thức | 17 (S 7 · C 5 · A 5) |
| Tình huống tích cực | 10 |
| Tự viết, không có mã | 4 |

`pillarPatternCounts` chỉ đếm 17 lượt thuộc S/C/A, còn
`totalReflectionInWindow` đếm cả 31. Trụ cao nhất ra **7/31 = 22%**, không chạm
ngưỡng 40%, nên màn hình rơi vào nhánh "chưa có nhóm nào nổi trội".

Chia đúng mẫu số: **7/17 = 41%**, chạm ngưỡng. Cùng một người, cùng một ngày,
chỉ khác cái mẫu số.

Code cũ đang làm **đúng theo v1**: `wr_sca_deep_dive.dart` có hẳn một đoạn chú
thích khẳng định tổng ba trụ nhỏ hơn mẫu số "là sự thật chứ không phải sai số".
v2 lật lại chính câu đó.

---

## 2. Bốn chỗ đặc tả lệch với app, và cách xử lý

### 2.1 §2.3 đúng một nửa

Đặc tả viết: gán trụ cho 10 tình huống P thì "mọi lần nhìn lại đều có trụ, nên
hai con số này sẽ bằng nhau và vấn đề tự hết".

Không hết. Nhánh **"Điều khác"** của luồng Reflect để `situation_code` trống —
4 trong 31 lượt của tài khoản trên. Gán trụ cho P chỉ vá 10 trong 14 lượt thất
lạc.

**Đã làm:** giữ ba mẫu số riêng biệt, mỗi cái trả lời một câu hỏi khác nhau.

| Con số | Trả lời | Ở tài khoản trên |
|---|---|---|
| `totalReflection` | công sức người dùng bỏ ra → ngưỡng mở tầng | 31 |
| `classifiedTotal` | mẫu số hiển thị của "{count} trong {total} lần" | 27 |
| `challengeTotal` | mẫu số của trụ nổi trội và khoảng lệch | 17 |

### 2.2 Thư viện có 110 tình huống, không phải 46

Đặc tả đếm theo mảng `SITUATIONS` của mockup HTML (36 + 10). DB thật: 100 mục
Career Situation Library đang hoạt động + 10 mục P = **110**, cộng 60 chip Tầng 1
cũ đã `retired`.

Hệ quả: với 110 lựa chọn, R1 ("lặp ≥3 lần VÀ hơn hạng nhì ≥2 lần") gần như không
chạm. Trên tài khoản khách, tình huống nhiều nhất chỉ 3 lần và hạng nhì cũng 3.

**Đã làm:** giữ nguyên ngưỡng của đặc tả. Nới xuống là tuyên bố "một điều đang
lặp lại với bạn" từ hai lần trùng ngẫu nhiên, mà R5 vốn đã lo đúng trường hợp đó
bằng một giọng nhẹ hơn nhiều.

### 2.3 Bảng §2.1 cắt ngang hai nhóm P

| Mã | `sca_dimension` | Trụ §2.1 |
|---|---|---|
| P-07, P-08 | P-STEADY | **A** |
| P-09 | P-STEADY | **C** |
| P-06, P-10 | P-STEADY | S |
| P-01, P-04 | P-ACHIEVE | A |
| P-02, P-03, P-05 | P-ACHIEVE | **C** |

Không phép biến đổi nào từ `sca_dimension` ra được bảng này — phải là dữ liệu.

**Đã làm:** cột `wr_situations.pillar`, nullable, backfill cả 170 dòng.
`pillarOfSituation()` đọc cột đó, rơi về `sca_dimension[0]` khi trống.

`pillarOfDimension()` **giữ nguyên**: nó còn nuôi cột Xuất hiện của Career
Snapshot, nhu cầu chủ đạo, gợi ý mở chuyện, thẻ màn Hôm nay. Mở nhóm P vào đó là
bốn màn đổi số trong im lặng.

### 2.4 Trường `valence` đã có sẵn

§2.2 yêu cầu thêm một trường; trường ấy đã tồn tại dưới tên
`ScaDimension.isPositive`. **Không cần migration.** Dựng thêm một cột nữa là mở
đường cho hai nguồn nói khác nhau về cùng một tình huống.

---

## 3. Mâu thuẫn trong chính đặc tả — cần khách xác nhận

Bảng §4 viết điều kiện R4 là "tỷ lệ tích cực từ 60% trở lên, **hoặc từ 20% trở
xuống**". Đọc chữ thì 0% cũng là "từ 20 trở xuống", nên R4 sẽ chạy.

Nhưng §9 việc 4 đưa **hai** bộ nghiệm thu không có lượt tích cực nào — "phân bố
đều 6/5/5" và "đúng 15 lần rải đều mỗi tình huống 1 lần" — và nói cả hai **phải
ra R5**.

**Đã chọn theo §9**, vì nghiệm thu là định nghĩa của "xong", và vì R4 nói về
CÁN CÂN mà một cán cân thì cần cả hai bên. Điều kiện thành:
`share ≥ 60% || (positiveTotal > 0 && share ≤ 20%)`.

> Nếu khách muốn 0% cũng chạy R4b, bỏ vế `positiveTotal > 0` trong `deepRung()`
> là xong — nhưng phải sửa hai bộ nghiệm thu ở §9 theo.

---

## 4. Hai chỗ đặc tả bỏ ngỏ, đã tự chốt

### Phá hoà khi xếp hạng tình huống

Trên dữ liệu thật có ngay một ca hoà: C2-03 (thách thức) và P-09 (tích cực) cùng
3 lần. Luật:

1. nhiều lần hơn
2. hoà thì **thách thức** trước — người mở màn này đang đi tìm điều gì đang
   vướng
3. vẫn hoà thì theo mã, để hai lần mở app ra cùng một kết quả

### Phá hoà giữa các cụm R2

Ba cụm cùng tổng 5 lần trên dữ liệu thật. Luật: tổng lớn hơn → thách thức trước
→ nhiều thành viên hơn → thứ tự trụ.

Kèm theo: **cụm R2 cho phép thành viên chỉ 1 lần.** Đặc tả không đặt sàn cho
từng thành viên. Cụm trụ Sự rõ ràng của khách là 2 + 2 + 1: cho phép thì ra R2
và gọi tên ba tình huống, cấm thì tụt xuống R3. R2 cụ thể hơn, mà "cụ thể hơn
luôn tốt hơn trừu tượng" là nguyên tắc bất biến thứ hai ở §8.

---

## 5. Màn hình của khách sẽ nói gì

Chạy thang ưu tiên trên đúng phân bố 30 ngày của tài khoản đó:

| Bậc | Khớp? | Vì sao |
|---|---|---|
| R1 | không | cao nhất 3 lần, hạng nhì cũng 3 → chênh 0 |
| **R2** | **có** | cụm trụ *Sự rõ ràng*: 2 + 2 + 1 = 5 lần |
| R3 | (không tới) | nhưng nếu tới cũng khớp, S = 41% |

Khối chính ra câu R2a, gọi tên ba tình huống thật kèm số lần. Đạt cả bốn tiêu chí
của phép thử §9.1. Khoá trong test `Phép thử §9.1 · đúng tài khoản khách báo lỗi`.

---

## 6. Sáu việc của §9, ánh xạ sang repo

| § | Việc | Chỗ làm |
|---|---|---|
| 1 | Gán pillar + valence | `20260911100000_situation_pillar.sql`, `WrSituation.pillarCode` / `.valence` |
| 2 | Viết lại hàm đếm | `PillarTally` + `pillarTally()` thay `pillarReflectionCounts` (đã gỡ); `rankDeepSituations()` |
| 3 | Sửa mẫu số | cột Xuất hiện dùng `classifiedTotal`; `dominantPillar` dùng `challengeTotal` |
| 4 | Thang năm bậc | `DeepRung` + `deepRung()` + `deepLeadText()` |
| 5 | Nội dung + sắp xếp màn | 12 câu §5; `wr_sca_deep_dive_screen.dart` dựng lại |
| 6 | Xu hướng xuống lớp tình huống | `DeepSituationShift` + `_situationTrends()` |

### Đã gỡ hẳn

- `pillarReflectionCounts` — bỏ nhóm P ở tử số mà không bỏ ở mẫu số (§1.1)
- `scaPatternText` + `ScaDeepDivePillar.patternText` — lặp lại Career Snapshot và
  nói gần như giống hệt nhau ba lần (§1.3)
- Huy hiệu mức đánh giá trên thẻ trụ — trùng nguyên cột "Bạn đánh giá"

### Một thay đổi ngoài đặc tả, có chủ đích

`leadUnlocked` **không còn cần Self-Check**, chỉ cần 15 lần nhìn lại. Bốn trong
năm bậc đọc từ tình huống chứ không đọc từ điểm tự đánh giá, và §4 nói thẳng
"miễn là người dùng có từ 15 lần nhìn lại, luôn tồn tại một tình huống xuất hiện
nhiều nhất". Bản v1 buộc phải có Self-Check vì cả tầng 1 của nó là phép đối
chiếu; nay vế đó chỉ còn cần cho bậc R3.

---

## 7. Cổng kiểm tra

| Cổng | Kết quả |
|---|---|
| `flutter analyze` | 0 |
| `flutter test` | 2483 pass · 27 skip |
| `flutter build apk --debug` | OK |
| Nghiệm thu §9 việc 4, bốn bộ dữ liệu | pass |
| Phép thử §9.1 trên phân bố thật | pass |
| Quét "không bao giờ rỗng", n = 15…40 × 3 hình dạng | pass |

Migration `20260911100000_situation_pillar.sql` **đã push lên remote**
`sukpcxevcjnhiuyaoqxi`; sau khi chạy: 170/170 dòng có `pillar`, 0 null, 10 dòng P
chia 4 A · 4 C · 2 S — khớp đúng bảng §2.1.

---

## 8. Còn lại

- Chạy thật trên máy để nhìn màn Diễn giải sâu bằng tài khoản của khách
- Chờ khách chốt mâu thuẫn R4 ở mục 3
- Câu chữ 12 biến thể mới ở §5 chép nguyên từ đặc tả, bản tiếng Anh do đội dev
  dịch — nên rà lại nếu khách có bản EN riêng
