-- Bản tiếng Anh cho ba chủ đề thực hành đã NGỪNG PHÁT.
--
-- ---------------------------------------------------------------------------
-- VÌ SAO BA DÒNG NÀY BỊ BỎ SÓT
--
-- Đợt dịch 10/09 cố ý bỏ qua mọi dòng có `retired_at`, với lý do "chủ đề ngừng
-- phát thì không ai còn thấy nữa". Lý do đó SAI: `retired_at` chỉ chặn việc
-- GIAO chủ đề mới. Ai đã ghi danh trước lúc ngừng phát thì vẫn đang theo nó, và
-- chủ đề đó hiện trên màn Hôm nay MỖI NGÀY ở thẻ "Tiếp tục hôm nay".
--
-- Thời điểm viết migration này có 3 lượt ghi danh đang trỏ vào ba chủ đề dưới
-- đây. Khách chụp màn 10/09 là một trong số đó: cả màn Hôm nay tiếng Anh, riêng
-- thẻ tiếp tục đọc `Theme "Nhịp làm việc ổn định": step Shift waiting` — nhãn
-- "Theme"/"step" của app đã dịch, tên chủ đề lấy từ bảng này thì chưa.
--
-- ⚠ Quy tắc rút ra: `retired_at` KHÔNG phải căn cứ để bỏ qua khi dịch. Chỉ
--   những dòng không còn ai tham chiếu tới mới bỏ qua được, mà điều đó phải
--   kiểm bằng truy vấn chứ không suy từ tên cột.
--
-- `formed_line` của cả ba dòng đang NULL nên không có gì để dịch. Để trống thay
-- vì bịa ra một câu — cột đó là lời chúc mừng khi hoàn thành chủ đề, viết sai
-- giọng còn tệ hơn không có.

update public.wr_practice_themes set
  title_en = 'Speaking up',
  description_en = 'Build the habit of speaking up at the right moment, in the '
    'right way, at work.'
where theme_id = 'pt-voice';

update public.wr_practice_themes set
  title_en = 'A steady working rhythm',
  description_en = 'Find and hold a deep, steady working rhythm in an '
    'environment full of interruptions.'
where theme_id = 'pt-rhythm';

update public.wr_practice_themes set
  title_en = 'Feedback that lands',
  description_en = 'Turn looking back and sharing what you learned into a safe, '
    'specific and regular feedback rhythm.'
where theme_id = 'pt-feedback';

-- Rào chắn: `update ... where theme_id = '...'` khớp 0 dòng thì Postgres KHÔNG
-- báo lỗi. Không có khối này thì một mã chủ đề gõ sai sẽ đi qua im lặng và
-- migration báo thành công trong khi không dịch được gì.
do $$
declare
  missing int;
begin
  select count(*) into missing
  from public.wr_practice_themes
  where title_en is null or btrim(title_en) = '';

  if missing > 0 then
    raise exception 'Còn % chủ đề thực hành chưa có title_en', missing;
  end if;
end $$;
