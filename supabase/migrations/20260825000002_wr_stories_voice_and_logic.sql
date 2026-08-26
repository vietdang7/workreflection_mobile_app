-- WorkReflection: đổi ngôi câu hỏi phản chiếu và sửa bốn cặp câu lệch logic.
--
-- Nguồn: WorkReflection_Changelog_20260824.docx §1.3 và §1.4.
--
-- §1.3 — "tôi" → "bạn" cho `reflection_question` và `self_reflection`.
--   Mục tiêu: câu hỏi đọc như app đang hỏi chuyện trực tiếp với người dùng,
--   thay vì người dùng tự độc thoại.
--
--   `story_content` và `aha_message` GIỮ NGUYÊN ngôi "tôi" — changelog ghi rõ
--   đó là giọng kể của "người khác" để tạo sự đồng cảm, không phải câu hỏi đặt
--   ra cho người dùng. Đại từ phản thân "mình" ("công việc của mình") cũng giữ,
--   đúng như ví dụ Trước/Sau trong tài liệu.
--
--   Trong 110 story hiện có chỉ nhóm P-* còn dùng ngôi "tôi"; S/C/A đã ở ngôi
--   "bạn" từ trước.
--
-- §1.4 — bốn cặp mà CÂU CHUYỆN thể hiện sự không chắc chắn nhưng CÂU HỎI lại
--   giả định sẵn một câu trả lời tích cực, dứt khoát (A3-04, A1-03, A1-06,
--   P-04). Câu thay thế lấy nguyên văn từ changelog.
--
-- Vì sao là UPDATE chứ không phải seed lại: khối seed gốc ở
-- 20260721000000_create_wr_reflection_content.sql dùng `on conflict do nothing`,
-- nên chạy lại nó KHÔNG đổi được hàng đã có trên cơ sở dữ liệu thật.
--
-- Nguồn chuẩn vẫn là assets/seed/wr_stories.json. Sửa đổi ở đó áp bằng:
--   python3 tool/apply_changelog_20260824_stories.py

update public.wr_stories set reflection_question = 'Nếu cố tìm, điều gì trong tuần này có thể là một phần ý nghĩa mà bạn chưa kịp nhận ra?'
  where story_id = 'A1-03';

update public.wr_stories set reflection_question = 'Nếu cố tìm, điều gì có thể là một dấu hiệu nhỏ cho thấy bạn đang trưởng thành, dù chưa thật rõ ràng?'
  where story_id = 'A1-06';

update public.wr_stories set reflection_question = 'Nếu cố nhớ lại, điều gì có thể là một thay đổi nhỏ mà bạn đã không để ý?'
  where story_id = 'A3-04';

update public.wr_stories set reflection_question = 'Điều gì đã giúp bạn vượt qua được việc này?', self_reflection = 'Bạn có thường dừng lại để ghi nhận những lúc mình làm tốt không?'
  where story_id = 'P-01';

update public.wr_stories set reflection_question = 'Lời ghi nhận đó chạm vào điều gì ở bạn?', self_reflection = 'Bạn có tin vào điều đó, hay có phần nào trong bạn vẫn nghi ngờ?'
  where story_id = 'P-02';

update public.wr_stories set reflection_question = 'Điều gì khiến bạn sẵn sàng dừng lại để giúp, dù có thể mình cũng đang bận?'
  where story_id = 'P-03';

update public.wr_stories set reflection_question = 'Điều gì trong hành trình vừa qua đã dẫn bạn đến điều này?', self_reflection = 'Bạn có đang cho phép mình thật sự vui với điều này không, hay đã vội nghĩ đến áp lực tiếp theo?'
  where story_id = 'P-04';

update public.wr_stories set reflection_question = 'Việc gì bạn làm mà tưởng là nhỏ, nhưng lại có ý nghĩa với người khác?', self_reflection = 'Bạn có hay đánh giá thấp những đóng góp thầm lặng của chính mình không?'
  where story_id = 'P-05';

update public.wr_stories set reflection_question = 'Những ngày như thế này có thường xảy ra với bạn không?', self_reflection = 'Bạn có coi trọng những ngày ổn định, hay chỉ chú ý khi có chuyện xảy ra?'
  where story_id = 'P-06';

update public.wr_stories set reflection_question = 'Điều gì khác biệt hôm nay so với những ngày bạn cảm thấy bị cuốn đi?', self_reflection = 'Bạn có thể giữ được nhịp độ này trong bao lâu?'
  where story_id = 'P-07';

update public.wr_stories set reflection_question = 'Điều nhỏ này có thể thay đổi cách bạn làm việc về lâu dài không?', self_reflection = 'Bạn có thường bỏ qua những bài học nhỏ vì chúng không đủ lớn để ghi nhớ không?'
  where story_id = 'P-08';

update public.wr_stories set self_reflection = 'Bạn có đang dành đủ thời gian cho những kết nối như vậy không?'
  where story_id = 'P-09';

update public.wr_stories set reflection_question = 'Bạn có công nhận những ngày không có gì đặc biệt này không, hay chỉ nhớ những ngày nhiều biến động?', self_reflection = 'Điều gì đang diễn ra tốt mà bạn ít khi để ý tới?'
  where story_id = 'P-10';
