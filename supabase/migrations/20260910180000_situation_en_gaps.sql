-- Bịt hai lỗ hổng còn lại của bản tiếng Anh trong `wr_situations`.
--
-- ---------------------------------------------------------------------------
-- 1. SỬA MỘT CÂU DỊCH SAI NGHĨA
--
-- A3-05 "Tôi cứ ra quyết định theo cảm xúc" từng được dịch thành
-- "I keep deciding on feeling alone". Chữ "alone" không có trong câu gốc và
-- kéo câu sang một nghĩa khác hẳn — "quyết định trong cô đơn" thay vì "quyết
-- định theo cảm xúc".
--
-- Không phải một lỗi nằm im: A3-05 là tình huống lặp của tài khoản thật, nên
-- câu này đang chạy thẳng lên thẻ navy "Hệ thống nhận ra" ở màn Hôm nay — chỗ
-- trang trọng nhất của app.
--
-- ---------------------------------------------------------------------------
-- 2. DỊCH 60 MÃ TẦNG 1 `<DIM>-sit-NN`
--
-- Đợt dịch 10/09 chỉ phủ 110 mã thư viện `<DIM>-NN` + `P-NN`, vì đó là những mã
-- DUY NHẤT còn được đề xuất cho phiên mới (xem `resolveStoryFor`). 60 mã
-- `-sit-` bị coi là dữ liệu chết và bỏ qua.
--
-- Bỏ qua như thế là sai. Chúng không còn được ĐỀ XUẤT, nhưng vẫn được ĐỌC: mọi
-- Episode ghi trước đợt gộp mã đều mang một mã `-sit-`, và nhãn của chúng hiện
-- ra ở tiêu đề dòng Hành trình, ở thẻ "Hệ thống nhận ra", ở màn chi tiết điều
-- lặp lại. Tài khoản càng dùng lâu càng gặp nhiều — đúng nhóm người dùng mà
-- bản tiếng Anh phục vụ.
--
-- Giọng dịch: giữ đúng dạng NGỮ ĐOẠN của bản gốc. Mã `-sit-` là cụm danh/động
-- từ không chủ ngữ ("Quá tải công việc"), khác hẳn mã thư viện viết ở ngôi thứ
-- nhất trọn câu ("Tôi đang đi rất nhanh, nhưng đi đâu?"). Dịch chúng thành câu
-- đủ chủ ngữ là làm hai nhóm đọc như nhau trong khi bản gốc phân biệt rõ.

update public.wr_situations set text_en = 'I keep making decisions on how I feel' where code = 'A3-05';

update public.wr_situations set text_en = 'I don''t understand the organisation''s overall goal' where code = 'A1-sit-01';
update public.wr_situations set text_en = 'Not knowing what my work contributes' where code = 'A1-sit-02';
update public.wr_situations set text_en = 'Doing a lot without seeing the meaning' where code = 'A1-sit-03';
update public.wr_situations set text_en = 'Goals that keep changing with no explanation' where code = 'A1-sit-04';
update public.wr_situations set text_en = 'Wanting to move on because the fit is gone' where code = 'A1-sit-05';
update public.wr_situations set text_en = 'Not sure I am heading the right way' where code = 'A1-sit-06';

update public.wr_situations set text_en = 'Always busy, never effective' where code = 'A2-sit-01';
update public.wr_situations set text_en = 'Work that keeps getting interrupted' where code = 'A2-sit-02';
update public.wr_situations set text_en = 'Overloaded with work' where code = 'A2-sit-03';
update public.wr_situations set text_en = 'Always chasing the next deadline' where code = 'A2-sit-04';
update public.wr_situations set text_en = 'Never finishing what matters' where code = 'A2-sit-05';
update public.wr_situations set text_en = 'Feeling out of control of my work' where code = 'A2-sit-06';

update public.wr_situations set text_en = 'Not knowing if I am moving forward or back' where code = 'A3-sit-01';
update public.wr_situations set text_en = 'The same problem coming back again and again' where code = 'A3-sit-02';
update public.wr_situations set text_en = 'Not understanding where the disappointment comes from' where code = 'A3-sit-03';
update public.wr_situations set text_en = 'Making decisions on emotion' where code = 'A3-sit-04';
update public.wr_situations set text_en = 'Feeling stuck' where code = 'A3-sit-05';
update public.wr_situations set text_en = 'No time to look back' where code = 'A3-sit-06';

update public.wr_situations set text_en = 'Making the same mistake again' where code = 'A4-sit-01';
update public.wr_situations set text_en = 'Learning a lot, applying little' where code = 'A4-sit-02';
update public.wr_situations set text_en = 'Experience that never turns into a lesson' where code = 'A4-sit-03';
update public.wr_situations set text_en = 'Wanting to move up without a direction' where code = 'A4-sit-04';
update public.wr_situations set text_en = 'Wanting to change career without a path' where code = 'A4-sit-05';
update public.wr_situations set text_en = 'Not knowing the next step to grow' where code = 'A4-sit-06';

update public.wr_situations set text_en = 'Not trusting colleagues to finish the work' where code = 'C1-sit-01';
update public.wr_situations set text_en = 'Not being trusted by my manager' where code = 'C1-sit-02';
update public.wr_situations set text_en = 'Being watched over too closely' where code = 'C1-sit-03';
update public.wr_situations set text_en = 'Feeling I have to do everything myself' where code = 'C1-sit-04';
update public.wr_situations set text_en = 'Finding it hard to hand work over' where code = 'C1-sit-05';
update public.wr_situations set text_en = 'Not enough support from the team' where code = 'C1-sit-06';

update public.wr_situations set text_en = 'Not daring to speak up' where code = 'C2-sit-01';
update public.wr_situations set text_en = 'Not being listened to' where code = 'C2-sit-02';
update public.wr_situations set text_en = 'Input that gets passed over' where code = 'C2-sit-03';
update public.wr_situations set text_en = 'Afraid to give my manager feedback' where code = 'C2-sit-04';
update public.wr_situations set text_en = 'Feeling my voice does not count' where code = 'C2-sit-05';
update public.wr_situations set text_en = 'Afraid of getting it wrong in front of everyone' where code = 'C2-sit-06';

update public.wr_situations set text_en = 'A conflict no one can name' where code = 'C3-sit-01';
update public.wr_situations set text_en = 'Avoiding the hard conversations' where code = 'C3-sit-02';
update public.wr_situations set text_en = 'Feedback that turns into an argument' where code = 'C3-sit-03';
update public.wr_situations set text_en = 'Talking it through and still not understanding each other' where code = 'C3-sit-04';
update public.wr_situations set text_en = 'A tense atmosphere that will not lift' where code = 'C3-sit-05';
update public.wr_situations set text_en = 'Not knowing how to give feedback' where code = 'C3-sit-06';

update public.wr_situations set text_en = 'Unclear what is expected of me' where code = 'S1-sit-01';
update public.wr_situations set text_en = 'Unclear whose responsibility it is' where code = 'S1-sit-02';
update public.wr_situations set text_en = 'A role that overlaps with someone else''s' where code = 'S1-sit-03';
update public.wr_situations set text_en = 'Work that keeps changing, nothing settles' where code = 'S1-sit-04';
update public.wr_situations set text_en = 'Not knowing what good looks like' where code = 'S1-sit-05';
update public.wr_situations set text_en = 'Not knowing what to do first' where code = 'S1-sit-06';

update public.wr_situations set text_en = 'Hard to work with other departments' where code = 'S2-sit-01';
update public.wr_situations set text_en = 'Other people holding up my work' where code = 'S2-sit-02';
update public.wr_situations set text_en = 'Not knowing who to turn to for help' where code = 'S2-sit-03';
update public.wr_situations set text_en = 'Teamwork that does not work' where code = 'S2-sit-04';
update public.wr_situations set text_en = 'Redoing work because it was misunderstood' where code = 'S2-sit-05';
update public.wr_situations set text_en = 'Work that depends on too many people' where code = 'S2-sit-06';

update public.wr_situations set text_en = 'Not knowing where to find things' where code = 'S3-sit-01';
update public.wr_situations set text_en = 'Information that arrives too late' where code = 'S3-sit-02';
update public.wr_situations set text_en = 'Information that contradicts itself' where code = 'S3-sit-03';
update public.wr_situations set text_en = 'Not being told when things change' where code = 'S3-sit-04';
update public.wr_situations set text_en = 'Always feeling one step behind' where code = 'S3-sit-05';
update public.wr_situations set text_en = 'Not enough to go on to decide' where code = 'S3-sit-06';

-- Rào chắn. `update ... where code = '…'` khớp 0 dòng thì Postgres KHÔNG báo
-- lỗi gì cả — migration vẫn xanh trong khi không đổi được ô nào. Gõ sai một mã
-- ở đây là để lại đúng cái lỗ hổng mà migration này sinh ra để bịt.
do $$
declare
  missing int;
begin
  select count(*) into missing
  from public.wr_situations
  where text_en is null or btrim(text_en) = '';

  if missing > 0 then
    raise exception 'wr_situations còn % dòng chưa có text_en', missing;
  end if;

  if exists (
    select 1 from public.wr_situations
    where code = 'A3-05' and text_en like '%alone%'
  ) then
    raise exception 'A3-05 vẫn còn bản dịch cũ';
  end if;
end $$;
