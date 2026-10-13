-- Sprint 2 parity: bộ tình huống của luồng Reflect khớp script khách
-- (`SITUATIONS` + `getSituationChoices`, script Sprint 2 dòng 1230-1327).
--
-- 1. P-11 đổi nghĩa: catalog v2 dùng mã này cho "Tôi tìm được thông tin cần
--    trong vài phút"; script dùng cho "Tôi vừa hoàn thành một khoá học hoặc một
--    buổi đào tạo" (cột mốc hoàn thành, được chèn vào danh sách với xác suất
--    0.45). Ghi đè tại chỗ để mã khớp script; lịch sử cũ trỏ P-11 (1 lượt trên
--    remote lúc viết) sẽ hiện nhãn mới.
-- 2. S2-04 quay lại thư viện với nội dung script ("Tôi phát hiện thay đổi khi
--    việc đã xảy ra rồi"); catalog v2 đã cho nghỉ mã này với nhãn cũ "Việc bị
--    đẩy qua đẩy lại" (2 lượt lịch sử trên remote sẽ hiện nhãn mới).
-- 3. Tiêu đề P-01..P-10 lệch câu chữ so với script: sửa cho đúng nguyên văn.
--
-- Cờ cột mốc (P-11 completion, P-08 learning) nằm ở code
-- (`kSituationMilestones`, lib/core/logic/wr_career_memory_rules.dart), không
-- thêm cột. App đọc catalog từ assets/seed/*.json (đã sửa cùng lượt); migration
-- này giữ DB khớp asset.

insert into public.wr_situations
  (code, text, text_en, sca_dimension, human_need, wave, pillar, subgroup, mood, valence)
values
  ('P-11', 'Tôi vừa hoàn thành một khoá học hoặc một buổi đào tạo', 'I just finished a course or a training session', 'P-STEADY', 'phat_trien', 1, 'A', 'Ap', 'ok', 'tich-cuc'),
  ('S2-04', 'Tôi phát hiện thay đổi khi việc đã xảy ra rồi', 'I found out about a change after it had already happened', 'S2', 'ro_rang', 3, 'S', 'S2', 'outofsync', 'thach-thuc')
on conflict (code) do update set
  text          = excluded.text,
  text_en       = excluded.text_en,
  sca_dimension = excluded.sca_dimension,
  human_need    = excluded.human_need,
  wave          = excluded.wave,
  pillar        = excluded.pillar,
  subgroup      = excluded.subgroup,
  mood          = excluded.mood,
  valence       = excluded.valence,
  retired_at    = null;

insert into public.wr_stories
  (story_id, title, sca_dimension, human_need, situation,
   pillar, subgroup, mood, valence,
   emotion_tags, behavior_tags, career_stages, difficulty_level,
   story_content, reflection_question, self_reflection, aha_message, practice_action,
   title_en, story_content_en, reflection_question_en, self_reflection_en,
   aha_message_en, practice_action_en)
values
  ('P-11', 'Tôi vừa hoàn thành một khoá học hoặc một buổi đào tạo', 'P-STEADY', 'phat_trien', 'Tôi vừa hoàn thành một khoá học hoặc một buổi đào tạo', 'A', 'Ap', 'ok', 'tich-cuc', ARRAY[]::text[], ARRAY[]::text[], ARRAY[]::text[], NULL, 'Tôi vừa kết thúc một khoá học hoặc buổi đào tạo. Có thể không phải điều gì quá lớn, nhưng tôi đã thật sự dành thời gian để học và đi đến cuối.', 'Điều gì từ trải nghiệm này đáng được mang theo vào công việc của bạn?', 'Nếu không dừng lại ghi nhận, điều gì từ trải nghiệm này có thể trôi mất?', 'Một điều đã hoàn thành có giá trị khác với một điều mình định làm. Nó là bằng chứng rằng mình đã thật sự đi qua một đoạn đường.', 'Ghi lại một điều cụ thể bạn sẽ giữ lại từ trải nghiệm này.', 'I just finished a course or a training session', 'I just finished a course or a training session. It may not be anything big, but I really did set aside the time to learn and saw it through to the end.', 'What from this experience is worth carrying into your work?', 'If you do not stop to note it, what from this experience might slip away?', 'Something finished is worth something different from something you only plan to do. It is proof that you really did travel a stretch of road.', 'Note one specific thing you will keep from this experience.'),
  ('S2-04', 'Tôi phát hiện thay đổi khi việc đã xảy ra rồi', 'S2', 'ro_rang', 'Tôi phát hiện thay đổi khi việc đã xảy ra rồi', 'S', 'S2', 'outofsync', 'thach-thuc', ARRAY[]::text[], ARRAY[]::text[], ARRAY[]::text[], NULL, 'Một quyết định đã được đưa ra và thực hiện. Tôi chỉ biết khi mọi thứ đã hoàn tất, không kịp góp ý hay chuẩn bị.', 'Bạn cảm thấy thế nào khi biết một thay đổi sau khi nó đã xảy ra?', 'Có ai bạn nghĩ nên là người chủ động thông báo sớm hơn không?', 'Việc biết muộn thường gây tổn thương nhiều hơn bản thân sự thay đổi, vì nó khiến người ta cảm thấy không được xem là một phần của quá trình.', 'Hỏi xem có kênh nào mình nên tham gia để được cập nhật sớm hơn không.', 'I found out about a change after it had already happened', 'A decision was made and carried out. I only found out once everything was done, too late to give input or prepare.', 'How do you feel when you learn about a change after it has already happened?', 'Is there someone you think should have let people know sooner?', 'Finding out late often hurts more than the change itself, because it makes people feel they were not treated as part of the process.', 'Ask whether there is a channel you should join so you hear about things sooner.')
on conflict (story_id) do update set
  title              = excluded.title,
  sca_dimension      = excluded.sca_dimension,
  human_need         = excluded.human_need,
  situation          = excluded.situation,
  pillar             = excluded.pillar,
  subgroup           = excluded.subgroup,
  mood               = excluded.mood,
  valence            = excluded.valence,
  emotion_tags       = excluded.emotion_tags,
  behavior_tags      = excluded.behavior_tags,
  career_stages      = excluded.career_stages,
  difficulty_level   = excluded.difficulty_level,
  story_content      = excluded.story_content,
  reflection_question = excluded.reflection_question,
  self_reflection    = excluded.self_reflection,
  aha_message        = excluded.aha_message,
  practice_action    = excluded.practice_action,
  title_en           = excluded.title_en,
  story_content_en   = excluded.story_content_en,
  reflection_question_en = excluded.reflection_question_en,
  self_reflection_en = excluded.self_reflection_en,
  aha_message_en     = excluded.aha_message_en,
  practice_action_en = excluded.practice_action_en;

-- Tiêu đề lệch script (chỉ những dòng lệch thật).
update public.wr_situations set text = 'Tôi vừa hoàn thành một việc khó hơn mong đợi' where code = 'P-01';
update public.wr_stories set title = 'Tôi vừa hoàn thành một việc khó hơn mong đợi', situation = 'Tôi vừa hoàn thành một việc khó hơn mong đợi' where story_id = 'P-01';
update public.wr_situations set text = 'Tôi được ghi nhận tích cực từ cấp trên' where code = 'P-02';
update public.wr_stories set title = 'Tôi được ghi nhận tích cực từ cấp trên', situation = 'Tôi được ghi nhận tích cực từ cấp trên' where story_id = 'P-02';
update public.wr_situations set text = 'Tôi giúp được đồng nghiệp gỡ một vấn đề khó' where code = 'P-03';
update public.wr_stories set title = 'Tôi giúp được đồng nghiệp gỡ một vấn đề khó', situation = 'Tôi giúp được đồng nghiệp gỡ một vấn đề khó' where story_id = 'P-03';
update public.wr_situations set text = 'Tôi được tăng lương hoặc thăng chức' where code = 'P-04';
update public.wr_stories set title = 'Tôi được tăng lương hoặc thăng chức', situation = 'Tôi được tăng lương hoặc thăng chức' where story_id = 'P-04';
update public.wr_situations set text = 'Công việc hôm nay diễn ra đúng như tôi mong đợi', text_en = 'Today’s work went just as I hoped' where code = 'P-06';
update public.wr_stories set title = 'Công việc hôm nay diễn ra đúng như tôi mong đợi', situation = 'Công việc hôm nay diễn ra đúng như tôi mong đợi', title_en = 'Today’s work went just as I hoped' where story_id = 'P-06';
update public.wr_situations set text = 'Tôi cảm thấy làm chủ được nhịp độ công việc của mình', text_en = 'I feel in control of my own pace at work' where code = 'P-07';
update public.wr_stories set title = 'Tôi cảm thấy làm chủ được nhịp độ công việc của mình', situation = 'Tôi cảm thấy làm chủ được nhịp độ công việc của mình', title_en = 'I feel in control of my own pace at work' where story_id = 'P-07';
update public.wr_situations set text = 'Tôi vừa học được một điều nhỏ nhưng hữu ích', text_en = 'I just learned something small but useful' where code = 'P-08';
update public.wr_stories set title = 'Tôi vừa học được một điều nhỏ nhưng hữu ích', situation = 'Tôi vừa học được một điều nhỏ nhưng hữu ích', title_en = 'I just learned something small but useful' where story_id = 'P-08';
update public.wr_situations set text = 'Tôi có một cuộc trò chuyện tốt với đồng nghiệp', text_en = 'I had a good conversation with a colleague' where code = 'P-09';
update public.wr_stories set title = 'Tôi có một cuộc trò chuyện tốt với đồng nghiệp', situation = 'Tôi có một cuộc trò chuyện tốt với đồng nghiệp', title_en = 'I had a good conversation with a colleague' where story_id = 'P-09';
update public.wr_situations set text = 'Hôm nay không có gì đặc biệt, nhưng tôi thấy ổn', text_en = 'Nothing special happened today, but I feel fine' where code = 'P-10';
update public.wr_stories set title = 'Hôm nay không có gì đặc biệt, nhưng tôi thấy ổn', situation = 'Hôm nay không có gì đặc biệt, nhưng tôi thấy ổn', title_en = 'Nothing special happened today, but I feel fine' where story_id = 'P-10';
