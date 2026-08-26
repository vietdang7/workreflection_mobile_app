-- Career Memory: ba loại mảnh ký ức được SINH THÊM từ STORY.
-- Nguồn: WorkReflection_Changelog_20260824.docx §8.2.
--
-- `behavior` là cột text tự do, không có CHECK — nên migration này KHÔNG nới
-- ràng buộc nào (đã kiểm: bảng chỉ ràng buộc human_need, sca_dimension,
-- intensity). Nó ghi lại ý nghĩa của ba giá trị mới, vì bảng này dùng chung với
-- app web: bên đó đọc `behavior` mà không có chỗ nào tra được nghĩa thì sẽ hoặc
-- bỏ sót ba loại mới, hoặc tự đặt tên khác cho cùng một thứ.
--
--   career_milestone  Cột mốc — STORY vừa tạo là lần đầu thuộc một loại nào đó.
--   career_theme      Chủ đề — cùng một nhóm nhu cầu ≥3 lần trong 14 ngày.
--   career_insight    Insight — định kỳ (14 ngày hoặc 5 lượt Reflection mới).
--
-- Cả ba đều là LỚP DIỄN GIẢI trên STORY, không phải dữ liệu ngang hàng với nó.
-- Nội dung câu chữ nằm ở `reflection_text`; `human_need` giữ nhóm đã sinh ra
-- mảnh đó, để lần sau biết nhóm nào đã có chủ đề mà không sinh trùng.

comment on column public.wr_career_memory_events.behavior is
  'Loại mảnh ký ức. reflection_episode = STORY gốc (1-1 với mỗi lượt Reflection đã khép). career_milestone / career_theme / career_insight = ba lớp diễn giải sinh thêm từ STORY (changelog 24/08/2026 §8.2). Các mã còn lại (practice_step_done, skill_certified, decision…) đến từ luồng Thực hành và Kỹ năng.';

comment on column public.wr_career_memory_events.reflection_text is
  'Nội dung hiển thị trên dòng thời gian. Với STORY là câu Meaning người dùng viết; với ba loại sinh thêm là câu đã ghép sẵn từ template (§8.2 yêu cầu LƯU LẠI thành bản ghi riêng, không suy luận lại lúc hiển thị).';
