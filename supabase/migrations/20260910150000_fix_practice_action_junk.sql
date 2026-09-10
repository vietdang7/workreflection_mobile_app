-- Dọn đuôi rác trong `wr_stories.practice_action` của bốn dòng.
--
-- ---------------------------------------------------------------------------
-- CHUYỆN GÌ ĐÃ XẢY RA
--
-- Bốn dòng A1-10, A3-10, S1-10, S2-10 — đều là dòng CUỐI của một nhóm — bị dán
-- thêm phần đầu của mục kế tiếp lúc nhập liệu từ tài liệu gốc. Ví dụ A1-10:
--
--     Viết ra một thay đổi nhỏ bạn muốn thực hiện trong 30 ngày tới.
--     A2 – Execution Rhythm
--     Human Need
--     Adaptability
--     SCA Dimension
--     A2 – Execution Rhythm
--     Câu hỏi cốt lõi
--     Tôi có đang biến điều mình biết thành điều mình làm không?
--
-- Phần từ dòng thứ hai trở đi là tiêu đề và siêu dữ liệu của nhóm A2, không
-- phải nội dung của A1-10. Nó ĐANG HIỆN LÊN MÀN HÌNH trong luồng đọc truyện.
--
-- Chỉ bốn dòng này dính, và đều đúng một kiểu: dòng cuối mỗi nhóm nuốt phần
-- mở đầu của nhóm sau. Đã quét cả bảng theo 'Human Need', 'SCA Dimension' và
-- 'Câu hỏi cốt lõi' trên cả sáu cột chữ — không còn chỗ nào khác.
--
-- ---------------------------------------------------------------------------
-- VÌ SAO CẮT THEO MỐC CHỨ KHÔNG GHI ĐÈ CẢ CÂU
--
-- Ghi đè bằng câu chép tay là đưa thêm một bản chép nữa vào chuỗi, và bản chép
-- đó sai một dấu là không ai phát hiện. Cắt tại mốc thì câu thật đi thẳng từ
-- dữ liệu hiện có sang dữ liệu mới, không qua tay ai.
--
-- Mốc của mỗi dòng là tên nhóm kế tiếp, đứng ngay sau một dấu xuống dòng. Cụ
-- thể tới mức đó vì `split_part` cắt tại lần khớp ĐẦU TIÊN: mốc mơ hồ hơn có
-- thể trùng vào giữa câu thật và cắt cụt nó.
--
-- ⚠ Dấu gạch ở đây là gạch ngang dài (–, U+2013) chứ không phải gạch nối (-).
-- Nhìn gần giống nhau trên phần lớn phông chữ, mà gõ nhầm thì `split_part`
-- không khớp gì cả và trả về NGUYÊN chuỗi cũ — migration vẫn xanh, rác vẫn còn.
--
-- ---------------------------------------------------------------------------
-- ĐIỀU KIỆN WHERE LÀM HAI VIỆC
--
-- `like '%...%'` không chỉ để lọc: nó khiến lệnh chạy lại lần hai không đụng
-- gì, và không cắt nhầm nếu ai đó đã sửa tay dòng đó trước. Bản đã sạch không
-- còn chứa mốc, nên không lọt vào WHERE.
--
-- Cột `practice_action_en` KHÔNG cần đụng: bản tiếng Anh ở migration
-- `20260910140000` ngay từ đầu chỉ dịch câu thật, không dịch phần rác.

begin;

update public.wr_stories
   set practice_action = split_part(practice_action, E'\nA2 – Execution Rhythm', 1)
 where story_id = 'A1-10'
   and practice_action like E'%\nA2 – Execution Rhythm%';

update public.wr_stories
   set practice_action = split_part(practice_action, E'\nA4 – Learning Loop', 1)
 where story_id = 'A3-10'
   and practice_action like E'%\nA4 – Learning Loop%';

update public.wr_stories
   set practice_action = split_part(practice_action, E'\nS2 – Collaboration Capability', 1)
 where story_id = 'S1-10'
   and practice_action like E'%\nS2 – Collaboration Capability%';

update public.wr_stories
   set practice_action = split_part(practice_action, E'\nS3 – Information Flow', 1)
 where story_id = 'S2-10'
   and practice_action like E'%\nS3 – Information Flow%';

-- ---------------------------------------------------------------------------
-- CHỐT CHẶN
--
-- Nếu còn dòng nào chở siêu dữ liệu thì hỏng cả migration thay vì lặng lẽ đi
-- tiếp. Một lệnh UPDATE khớp 0 dòng KHÔNG báo lỗi, nên không có chốt này thì
-- gõ sai mốc sẽ cho ra một migration xanh mà chẳng sửa gì.
do $$
declare con integer;
begin
  select count(*) into con
    from public.wr_stories
   where practice_action like '%Human Need%'
      or practice_action like '%SCA Dimension%'
      or practice_action like '%Câu hỏi cốt lõi%';
  if con > 0 then
    raise exception 'Còn % dòng practice_action chở siêu dữ liệu — chưa dọn hết.', con;
  end if;
end $$;

commit;
