-- Chỗ chứa bản tiếng Anh cho nội dung nằm trong database.
--
-- ---------------------------------------------------------------------------
-- VÌ SAO CẦN
--
-- Đợt 10/09 đã dịch xong toàn bộ chữ nằm trong mã Dart và trong .arb. Nhưng
-- chữ người dùng đọc nhiều nhất KHÔNG nằm trong mã: 443 dòng nội dung nằm
-- trong database, mỗi bảng đúng một cột tiếng Việt. Bật tiếng Anh lên thì
-- khung màn hình đổi còn ruột vẫn tiếng Việt — trong đó `wr_situations` là
-- các chip ở bước 0 của Reflect, tức thứ người dùng chạm vào đầu tiên.
--
-- Migration này chỉ mở CHỖ TRỐNG. Không có dòng dịch nào ở đây: câu chữ là
-- phần khách duyệt, và một bản dịch máy đưa thẳng vào bảng sẽ đi ra màn hình
-- mà không ai đọc lại.
--
-- ---------------------------------------------------------------------------
-- NULL LÀ "CHƯA DỊCH", KHÔNG PHẢI "RỖNG"
--
-- Mọi cột đều để NULL, không đặt DEFAULT ''. Tầng Dart (`trDb`) coi cả NULL
-- lẫn chuỗi trắng là chưa có bản dịch và rơi về tiếng Việt, nên dịch được tới
-- đâu dùng tới đó — không bao giờ có màn hình trắng chữ vì mới dịch nửa bảng.
--
-- ---------------------------------------------------------------------------
-- BA CHỖ CỐ Ý KHÔNG THÊM CỘT
--
-- • `wr_practices` — bảng của NGƯỜI DÙNG (`user_id`), `title` là bản chụp lại
--   lúc tạo. Dịch ngược nó là viết lại lịch sử của chính họ.
-- • `wr_situations.expected_outcome` · `sca_perspective` và
--   `wr_stories.situation` · `emotion_tags` · `behavior_tags` — có trong bảng
--   và có trong model Dart, nhưng KHÔNG chỗ nào đưa lên màn hình.
-- • `wr_stories.career_stages` — dùng để xếp thứ tự, là dữ liệu đem SO KHỚP
--   chứ không phải chữ đọc. Dịch là làm hỏng phép so khớp.

-- Chip tình huống — bước 0 của Reflect, và nhãn tra ngược ở Hiểu mình.
alter table public.wr_situations
  add column if not exists text_en text;

-- Career Situation Library. Sáu cột này là sáu chỗ hiện lên trong luồng đọc
-- truyện: tiêu đề, thân truyện, câu hỏi phản chiếu, câu tự soi, câu "aha",
-- và hành động thực hành đề xuất ở cuối.
alter table public.wr_stories
  add column if not exists title_en text,
  add column if not exists story_content_en text,
  add column if not exists reflection_question_en text,
  add column if not exists self_reflection_en text,
  add column if not exists aha_message_en text,
  add column if not exists practice_action_en text;

-- Câu hỏi Career Health Check.
--
-- ⚠ Model `CcQuestion` ĐÃ đọc `question_text_en` và màn khảo sát ĐÃ có nhánh
-- `localeCode == 'en'` từ trước. Nhưng cột chỉ tồn tại ở `cc_reflection_questions`
-- (bảng của bản web, app mobile không đọc), nên nhánh đó luôn nhận null và im
-- lặng rơi về tiếng Việt. Nhìn mã tưởng đã xong song ngữ — chưa.
alter table public.cc_questions
  add column if not exists question_text_en text;

-- Chủ đề thực hành: tên, mô tả mở đầu, và câu ở màn ăn mừng khi chạm ngưỡng.
alter table public.wr_practice_themes
  add column if not exists title_en text,
  add column if not exists description_en text,
  add column if not exists formed_line_en text;

-- Ba bước của mỗi chủ đề.
alter table public.wr_practice_steps
  add column if not exists title_en text,
  add column if not exists content_en text;

-- Các lựa chọn "bạn muốn làm gì tiếp" ở cuối luồng.
alter table public.wr_choice_pool
  add column if not exists text_en text;

-- ---------------------------------------------------------------------------
-- ĐO TIẾN ĐỘ DỊCH
--
-- Đếm theo từng bảng để biết còn bao nhiêu dòng chưa có bản tiếng Anh. Trả về
-- cả dòng đã dịch lẫn tổng, vì "còn 12 dòng" không nói lên điều gì nếu không
-- biết tổng là 15 hay 170.
create or replace function public.wr_translation_progress()
returns table (source text, translated bigint, total bigint)
language sql
stable
security definer
set search_path = public
as $$
  select 'wr_situations', count(nullif(btrim(coalesce(text_en, '')), '')), count(*)
    from wr_situations where retired_at is null
  union all
  select 'wr_stories.title', count(nullif(btrim(coalesce(title_en, '')), '')), count(*)
    from wr_stories
  union all
  select 'wr_stories.story_content', count(nullif(btrim(coalesce(story_content_en, '')), '')), count(*)
    from wr_stories
  union all
  select 'cc_questions', count(nullif(btrim(coalesce(question_text_en, '')), '')), count(*)
    from cc_questions where is_active
  union all
  select 'wr_practice_themes', count(nullif(btrim(coalesce(title_en, '')), '')), count(*)
    from wr_practice_themes where retired_at is null
  union all
  select 'wr_practice_steps', count(nullif(btrim(coalesce(title_en, '')), '')), count(*)
    from wr_practice_steps
  union all
  select 'wr_choice_pool', count(nullif(btrim(coalesce(text_en, '')), '')), count(*)
    from wr_choice_pool where active;
$$;

comment on function public.wr_translation_progress() is
  'Còn bao nhiêu dòng nội dung chưa có bản tiếng Anh, theo từng bảng.';

revoke all on function public.wr_translation_progress() from public;
grant execute on function public.wr_translation_progress() to service_role;
