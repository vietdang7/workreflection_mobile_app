# Rà soát 30 bài đọc — gửi đội nội dung

> Đối chiếu `wr_mood_content` trên project thật (`sukpcxevcjnhiuyaoqxi`) với
> **§4 changelog 24/08/2026**, ngày rà: **25/08/2026**.
>
> Toàn bộ 30 bài đang **`placeholder = false`** — tức đang phát hành, người dùng
> đọc được ngay, không có nhãn "Nháp".

---

## Kết luận một dòng

**11/30 bài theo đúng nguyên tắc brand "kết bằng câu hỏi mở". 19 bài còn lại kết
bằng câu khẳng định.** Ranh giới trùng khít với đợt viết: mọi bài viết trong đợt
24/08 đều đúng, mọi bài có từ trước đều không.

| Cụm cảm xúc | Kết bằng câu hỏi | Ghi chú |
|---|---|---|
| `foggy` (Mơ hồ) | **5/5** ✓ | viết mới đợt 24/08 |
| `outofsync` (Lệch nhau) | **5/5** ✓ | viết mới đợt 24/08 |
| `stress` (Căng thẳng) | 1/5 | bài duy nhất đúng là bài §4 nói đã sửa |
| `tired` (Mệt mỏi) | **0/5** | |
| `ok` (Khá ổn) | **0/5** | |
| `happy` (Vui) | **0/5** | |

---

## Việc 1 — 19 bài cần thêm câu hỏi mở ở cuối

Nội dung thân bài không có vấn đề: câu ngắn, giọng đồng cảm, không phán xét,
đúng văn phong đã thiết lập. Chỉ thiếu đúng **câu chót**.

**`stress` — Căng thẳng**
1. Căng thẳng không phải là kẻ thù, chỉ là tín hiệu
2. Căng thẳng vì sợ làm người khác thất vọng
3. Khi cơ thể lên tiếng trước khi mình kịp nhận ra
4. Khi mọi thứ đều gấp cùng một lúc

**`tired` — Mệt mỏi**
5. Cạn kiệt sau những cuộc trò chuyện, không chỉ sau công việc
6. Khi nào nên nghỉ, khi nào nên tiếp tục
7. Kiệt sức không phải là yếu đuối
8. Mệt vì luôn phải là người quyết định
9. Ngủ đủ mà vẫn không thấy khỏe lại

**`ok` — Khá ổn**
10. Điều gì đang vận hành tốt trong bạn?
11. Khi nhịp độ chậm lại, không phải vì có chuyện gì
12. Không cần một lý do để thấy ổn
13. Những ngày bình thường đáng được ghi nhớ
14. Sự ổn định cũng là một thành tựu

**`happy` — Vui**
15. Ai xứng đáng biết về điều này?
16. Ghi lại khoảnh khắc này trước khi nó trôi qua
17. Khi công việc bỗng nhẹ như không
18. Một ngày tốt không cần chứng minh điều gì
19. Niềm vui hôm nay, điều để nhớ cho ngày mai

> Bài số 10 và 15 có tựa đề là câu hỏi, nhưng **phần thân vẫn kết bằng câu
> khẳng định** — nguyên tắc nói về câu chót của nội dung, không phải tựa đề.

Mẫu tham chiếu, lấy từ bài đã đúng ("Khi áp lực đến từ việc muốn kiểm soát mọi
thứ"):

> …cũng đã đủ để căng thẳng nhẹ đi một chút. **Trong những điều đang khiến bạn
> lo lắng lúc này, đâu là phần bạn thực sự có thể tác động?**

---

## Việc 2 — 3 bài của §4 chưa bao giờ vào app

§4 liệt kê **5 tựa đề viết mới** thay cho các mục "âm thanh nền" cũ (mưa, nhạc
tập trung, nhạc ăn mừng). Kiểm trong DB:

| Tựa đề §4 | Cụm | Trong DB |
|---|---|---|
| Một khoảng lặng để sắp xếp lại suy nghĩ | `foggy` | **CÓ** |
| Tập trung giữa những thông tin ngổn ngang | `outofsync` | **CÓ** |
| Cho phép mình không làm gì, dù chỉ một lát | `tired` | **KHÔNG** |
| Những ngày làm việc trơn tru, không ồn ào | `ok` | **KHÔNG** |
| Cho phép mình ăn mừng, dù chỉ trong chốc lát | `happy` | **KHÔNG** |

Ba cụm `tired` / `ok` / `happy` hiện vẫn đang chạy **bộ bài cũ**, không phải bộ
đã viết lại trong mockup v16. Đây cũng chính là ba cụm có 0/5 bài kết bằng câu
hỏi — hai việc trên thực ra là một việc.

**Cần đội nội dung xác nhận:** ba bài này thay thế bài nào trong bộ cũ, hay là
bài thứ sáu thêm vào? Có câu trả lời là em viết migration import trong ngày.

---

## Việc 3 — quyết định về cờ `placeholder`

§4 dặn: *"Toàn bộ 30 bài vẫn giữ cờ `placeholder:true` … chưa qua biên tập chính
thức lần cuối. Nếu chốt xong nội dung, cần đổi cờ này thành `false`."*

Hiện cả 30 bài đang là `false` (phát hành) theo quyết định hôm 25/08. Nghĩa là
19 bài chưa đạt nguyên tắc brand đang hiển thị cho người dùng thật mà không có
nhãn "Nháp".

Hai lựa chọn, xin chị chọn:
- **(a)** Giữ nguyên, đội nội dung bổ sung câu hỏi rồi cập nhật dần. Người dùng
  đọc được ngay, đổi lại là 19 bài chưa đúng chuẩn đang chạy live.
- **(b)** Đặt lại `placeholder = true` cho đúng 19 bài đó — app hiện nhãn "Nháp"
  cho tới khi biên tập xong. Trung thực hơn, nhưng ba cụm `tired`/`ok`/`happy`
  sẽ toàn nhãn Nháp.

---

*Rà soát 25/08/2026 · WorkReflection Mobile*
