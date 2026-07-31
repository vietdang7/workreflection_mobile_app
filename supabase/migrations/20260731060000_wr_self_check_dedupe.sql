-- Dọn bản ghi Self-Check bị ghi trùng, và chặn không cho lặp lại.
--
-- Nguyên nhân nằm ở app, đã vá ở `wr_self_check_screen.dart`: màn tự nhảy câu
-- sau 260ms bằng một `Future.delayed` không giữ tay cầm, nên mỗi lượt chạm hẹn
-- thêm một lần nhảy. Người dùng chọn một mức rồi đổi ý bấm mức khác — thao tác
-- bình thường — là hai lượt cùng nổ. Ở câu cuối, cả hai cùng gọi hàm lưu và ghi
-- xuống HAI bản ghi cho MỘT lần làm.
--
-- Dấu vết trên bảng này rất rõ: các bản ghi đi theo cặp cách nhau 20–150ms,
-- cùng `user_id`, cùng nội dung `answers`:
--
--   04:47:50.704  +  04:47:50.820   (2026-07-23)
--   09:57:09.643  +  09:57:09.663   (2026-07-29)
--   08:11:37.831  +  08:11:37.980   (2026-07-30)
--
-- Hệ quả người dùng nhìn thấy: màn Hiểu mình báo "Đã tự đánh giá 7 lần" trong
-- khi thật ra chỉ có 4 lần.
--
-- ---------------------------------------------------------------------------
-- 1 · Xoá bản trùng, GIỮ bản sớm nhất của mỗi cặp
-- ---------------------------------------------------------------------------
--
-- Giữ bản SỚM NHẤT chứ không phải bản mới nhất: hai bản của một cặp có nội dung
-- y hệt nhau, nhưng bản sớm hơn mới là lần ghi ứng với thao tác thật của người
-- dùng. `wr_sca_self_check_responses` không có bảng nào tham chiếu tới nên xoá
-- không kéo theo gì.
--
-- Cửa sổ 5 giây: hai lượt hẹn cách nhau tối đa 260ms cộng thời gian đi mạng.
-- Năm giây rộng rãi hơn nhiều lần mà vẫn không thể chạm tới hai lần làm thật —
-- không ai trả lời xong 15 câu trong 5 giây.
--
-- Điều kiện `answers` giống hệt là chốt chặn cuối: kể cả có ai bấm lại thật
-- nhanh, chỉ khi nội dung trùng khít mới bị coi là bản ghi thừa.

with paired as (
  select
    id,
    row_number() over (
      partition by user_id, answers
      order by taken_at
    ) as rn,
    taken_at,
    first_value(taken_at) over (
      partition by user_id, answers
      order by taken_at
    ) as first_taken_at
  from public.wr_sca_self_check_responses
)
delete from public.wr_sca_self_check_responses r
using paired p
where r.id = p.id
  and p.rn > 1
  and p.taken_at - p.first_taken_at < interval '5 seconds';

-- ---------------------------------------------------------------------------
-- 2 · Chặn ở tầng DB, không chỉ ở tầng app
-- ---------------------------------------------------------------------------
--
-- Bản vá phía app đã đủ cho đúng đường đã gãy, nhưng ràng buộc này bảo vệ được
-- cả những đường chưa nghĩ tới: mất mạng rồi client tự gửi lại, người dùng bấm
-- nút hai lần trên một màn khác, hay một bản build cũ còn nằm trên máy ai đó.
--
-- Mốc là GIÂY, không phải mili-giây: hai lượt ghi của cùng một lần làm luôn rơi
-- vào cùng một giây hoặc hai giây liền nhau. Cắt theo giây thì cặp 09:57:09.643
-- / 09:57:09.663 bị chặn, còn hai lần làm thật cách nhau vài phút thì không.
--
-- Cố tình KHÔNG ràng buộc theo `answers`: người dùng hoàn toàn có thể làm lại
-- bộ câu hỏi và trả lời y hệt lần trước sau vài tuần, đó là dữ liệu hợp lệ và
-- chính là thứ khối "xu hướng theo thời gian" cần.
--
-- `at time zone 'UTC'` là bắt buộc, không phải cho đẹp: `date_trunc(text,
-- timestamptz)` chỉ STABLE vì kết quả phụ thuộc tham số TimeZone của phiên,
-- nên Postgres từ chối cho vào biểu thức index. Ép về `timestamp` không múi
-- giờ trước thì cả hai hàm đều IMMUTABLE.

create unique index if not exists wr_sca_self_check_one_per_second_idx
  on public.wr_sca_self_check_responses (
    user_id,
    date_trunc('second', (taken_at at time zone 'UTC'))
  );

comment on index public.wr_sca_self_check_one_per_second_idx is
  'Chặn ghi trùng: một người không thể có hai bản Self-Check trong cùng một '
  'giây. Xem migration 20260731060000 để biết lỗi gốc.';
