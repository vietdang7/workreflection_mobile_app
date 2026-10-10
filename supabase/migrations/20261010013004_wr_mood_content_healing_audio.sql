-- WorkReflection: HEALING AUDIO trở lại Thư viện Nội dung Cảm xúc (10/10).
--
-- Migration 20260825000001 xoá cả 10 hàng audio vì lúc đó "chỉ sản xuất được
-- nội dung dạng bài đọc, chưa thu âm". Nay khách đã thu xong 10 bản
-- (FileTam/workreflection/Audio_Thu viện cảm xúc): 5 cho Căng thẳng, 5 cho
-- Mệt mỏi. Bốn nhóm còn lại chưa có bản thu nên không có hàng audio nào.
--
-- • Bản thu nằm ở bucket công khai `mood-audio`, tên file ASCII theo
--   `<mood>/<sort_order>-<slug>.mp3`. Tải lên bằng
--   `supabase storage cp <file> ss:///mood-audio/<mood>/ --experimental --linked`
--   — migration chỉ tạo bucket, KHÔNG chứa file.
-- • sort_order 6..10, nằm sau 5 bài đọc. Thứ tự giữ đúng số thứ tự khách
--   đánh trên tên file.
-- • Bốn bản thu trùng tên một bài đọc (Khi áp lực…, Căng thẳng không phải là
--   kẻ thù…, Kiệt sức…, Khi nào nên nghỉ…) là MỤC RIÊNG, không gắn vào bài
--   đọc: bản thu dài chưa tới 2 phút, bài đọc 3–4 phút, nên đây không phải
--   bản đọc to nguyên văn.
-- • duration làm tròn LÊN từ thời lượng thật đo bằng ffprobe, đuôi "phút nghe"
--   để lớp tr() dịch được sang "min listen".
-- • body là một câu giới thiệu ngắn hiện dưới trình phát. Không có kịch bản
--   (`script`) vì lời đọc nằm trong file thu.
--
-- Upsert theo (mood, sort_order) để chạy lại không nhân đôi hàng.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('mood-audio', 'mood-audio', true, 10485760, array['audio/mpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into public.wr_mood_content
  (mood, sort_order, title, title_en, kind, duration, type, body, body_en,
   placeholder, audio_url)
values
  ('stress', 6, 'Ba nhịp thở trước khi phản hồi',
   'Three breaths before you respond',
   'HEALING AUDIO', '1 phút nghe', 'audio',
   'Một bài hướng dẫn hít thở ngắn, giúp bạn lấy lại nhịp trước khi bước vào một cuộc trao đổi căng thẳng.',
   'A short breathing guide to help you find your rhythm again before stepping into a tense conversation.',
   false,
   'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/mood-audio/stress/06-ba-nhip-tho-truoc-khi-phan-hoi.mp3'),
  ('stress', 7, 'Buông việc trong 60 giây',
   'Let go of a task in 60 seconds',
   'HEALING AUDIO', '2 phút nghe', 'audio',
   'Một bài dẫn rất ngắn giúp bạn tạm gác một việc đang chiếm hết tâm trí, để quay lại sau với một cái đầu nhẹ nhõm hơn.',
   'A very short guide to help you set aside a task that has taken over your mind, so you can come back to it later with a lighter head.',
   false,
   'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/mood-audio/stress/07-buong-viec-trong-60-giay.mp3'),
  ('stress', 8, 'Khi áp lực đến từ việc muốn kiểm soát mọi thứ',
   'When the pressure comes from wanting to control everything',
   'HEALING AUDIO', '2 phút nghe', 'audio',
   'Một bài nghe ngắn cho những lúc áp lực đến từ mong muốn nắm chắc mọi thứ trong tay.',
   'A short listen for the times when pressure comes from wanting to hold everything in your hands.',
   false,
   'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/mood-audio/stress/08-ap-luc-tu-viec-muon-kiem-soat.mp3'),
  ('stress', 9, 'Căng thẳng không phải là kẻ thù, chỉ là tín hiệu',
   'Tension is not the enemy, only a signal',
   'HEALING AUDIO', '2 phút nghe', 'audio',
   'Một bài nghe ngắn giúp nhìn căng thẳng như một tín hiệu cần lắng nghe, thay vì một điểm yếu cần giấu đi.',
   'A short listen to see tension as a signal worth hearing, rather than a weakness to hide.',
   false,
   'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/mood-audio/stress/09-cang-thang-chi-la-tin-hieu.mp3'),
  ('stress', 10, 'Ba phút lặng trước một cuộc họp khó',
   'Three quiet minutes before a hard meeting',
   'HEALING AUDIO', '2 phút nghe', 'audio',
   'Một khoảng lặng ngắn để chuẩn bị tâm thế trước khi bước vào một cuộc trao đổi bạn biết sẽ không dễ dàng.',
   'A short quiet moment to settle yourself before walking into a conversation you know will not be easy.',
   false,
   'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/mood-audio/stress/10-ba-phut-lang-truoc-cuoc-hop-kho.mp3'),
  ('tired', 6, 'Một khoảng lặng 5 phút',
   'A five-minute pause',
   'HEALING AUDIO', '2 phút nghe', 'audio',
   'Không cần làm gì thêm trong khoảng lặng này, chỉ cần để cơ thể và tâm trí được nghỉ trước khi tiếp tục.',
   'Nothing more to do in this pause. Just let your body and mind rest before you carry on.',
   false,
   'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/mood-audio/tired/06-mot-khoang-lang-5-phut.mp3'),
  ('tired', 7, 'Kiệt sức không phải là yếu đuối',
   'Running on empty is not weakness',
   'HEALING AUDIO', '2 phút nghe', 'audio',
   'Một bài nghe ngắn nhắc rằng kiệt sức đến từ việc cho đi nhiều hơn nhận lại, không phải từ việc thiếu sức chịu đựng.',
   'A short listen as a reminder that exhaustion comes from giving out more than you take in, not from a lack of endurance.',
   false,
   'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/mood-audio/tired/07-kiet-suc-khong-phai-yeu-duoi.mp3'),
  ('tired', 8, 'Cho phép mình không làm gì, dù chỉ một lát',
   'Letting yourself do nothing, even for a moment',
   'HEALING AUDIO', '2 phút nghe', 'audio',
   'Một bài dẫn ngắn cho phép bạn dừng lại một lát mà không cần lấp khoảng trống đó bằng việc gì khác.',
   'A short guide that lets you stop for a while without filling the space with anything else.',
   false,
   'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/mood-audio/tired/08-cho-phep-minh-khong-lam-gi.mp3'),
  ('tired', 9, 'Khi nào nên nghỉ, khi nào nên tiếp tục',
   'When to stop, when to keep going',
   'HEALING AUDIO', '2 phút nghe', 'audio',
   'Một bài nghe ngắn giúp phân biệt lúc cần nghỉ thật với lúc chỉ cần cố thêm một chút.',
   'A short listen to help tell a moment that needs real rest from one that needs a little more effort.',
   false,
   'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/mood-audio/tired/09-khi-nao-nghi-khi-nao-tiep-tuc.mp3'),
  ('tired', 10, 'Cho phép mình chậm lại hôm nay',
   'Letting yourself slow down today',
   'HEALING AUDIO', '2 phút nghe', 'audio',
   'Một bài dẫn nhẹ nhàng nhắc bạn rằng chậm lại một ngày không làm bạn tụt lại phía sau.',
   'A gentle guide reminding you that slowing down for a day does not leave you behind.',
   false,
   'https://sukpcxevcjnhiuyaoqxi.supabase.co/storage/v1/object/public/mood-audio/tired/10-cho-phep-minh-cham-lai-hom-nay.mp3')
on conflict (mood, sort_order) do update
  set title = excluded.title,
      title_en = excluded.title_en,
      kind = excluded.kind,
      duration = excluded.duration,
      type = excluded.type,
      body = excluded.body,
      body_en = excluded.body_en,
      placeholder = excluded.placeholder,
      audio_url = excluded.audio_url,
      updated_at = now();
