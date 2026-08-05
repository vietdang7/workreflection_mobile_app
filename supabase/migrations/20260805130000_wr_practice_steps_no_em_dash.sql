-- 20260805130000_wr_practice_steps_no_em_dash.sql
--
-- Bỏ dấu gạch dài trong TÊN bước thực hành (yêu cầu 05/08).
--
-- Brand identity chốt 04/08 bỏ hẳn dấu gạch dài khỏi chữ hiển thị. Đợt dọn hôm
-- đó chỉ với tới chuỗi nằm trong mã nguồn; 30 tên bước này nằm trong DB nên
-- không ai đụng tới, và chúng vẫn hiện ra ở màn chủ đề:
--
--     Nhận diện — Ghi lại một lần chưa rõ kỳ vọng
--
-- Đổi dấu ngăn thành hai chấm, đúng vai trò nó đang làm: vế trước là nhãn giai
-- đoạn, vế sau là việc phải làm.
--
--     Nhận diện: Ghi lại một lần chưa rõ kỳ vọng
--
-- Vì sao `regexp_replace` KHÔNG có cờ 'g': chỉ đổi dấu ngăn ĐẦU TIÊN. Một tên
-- bước sau này có dấu gạch dài thứ hai thì đó là dấu trong câu, không phải dấu
-- ngăn nhãn — biến nó thành hai chấm là làm hỏng câu. (Hôm nay chưa tên nào
-- như vậy; luật này để dành cho nội dung viết thêm về sau.)
--
-- Bắt cả `—` (em dash) lẫn `–` (en dash), và bắt cả trường hợp thiếu khoảng
-- trắng một bên. Chỉ đụng những hàng thật sự có dấu, nên chạy lại lần hai
-- không đổi thêm gì.
--
-- PHẠM VI: chỉ cột `title`. Cột `content` còn 3 chỗ dùng dấu gạch dài, nhưng ở
-- đó nó là dấu trong câu văn ("Không cần hoàn hảo — chỉ cần lên tiếng"), thay
-- máy móc bằng hai chấm sẽ ra câu sai ngữ pháp. Ba câu ấy cần viết lại bằng
-- tay, không thuộc migration này.

update public.wr_practice_steps
   set title = regexp_replace(title, '\s*[—–]\s*', ': ')
 where title ~ '[—–]';

-- Kiểm ngay tại chỗ: không còn tên bước nào mang dấu gạch dài. Sai thì migration
-- dừng, không để lại một nửa đã đổi một nửa chưa.
do $$
declare
  remaining int;
begin
  select count(*) into remaining
    from public.wr_practice_steps
   where title ~ '[—–]';

  if remaining > 0 then
    raise exception 'Còn % tên bước mang dấu gạch dài sau khi đổi', remaining;
  end if;
end $$;
