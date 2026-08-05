-- Họp khách 2026-07-29 — hai bổ sung độc lập, gộp một migration vì cả hai đều
-- nhỏ và cùng một vòng phản hồi.
--
--   1. wr_career_questions : ô hỏi tự do về hành trình nghề nghiệp
--   2. wr_mood_content.audio_url : bản thu đã dựng cho HEALING AUDIO
--
-- ---------------------------------------------------------------------------
-- 1 · Câu hỏi nghề nghiệp
--
-- "Bạn muốn hỏi thêm gì về bạn ở trong hệ thống… thì hệ thống nó sẽ trả lời cho
-- bạn nữa. Còn không trả lời được thì nó sẽ nói là hệ thống ghi nhận câu hỏi
-- của bạn và chúng tôi sẽ gửi chi tiết cái gợi ý cho bạn vào email."
--
-- Vì sao `answer` nullable và không có giá trị mặc định: giai đoạn này CHƯA có
-- AI trả lời. Người vận hành đọc bảng này rồi trả lời qua email, sau đó mới ghi
-- ngược `answer` vào. Bắt buộc có câu trả lời ngay từ lúc insert là biến ô hỏi
-- thành thứ không dùng được cho tới khi AI xong.
--
-- Không có cột `conversation_id` hay `role`: đây KHÔNG phải hộp chat qua lại
-- ("cái nói chuyện qua nói chuyện lại chị nghĩ cái đó nó sẽ chờ sau"). Một câu
-- hỏi là một dòng.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_career_questions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  question    text not null check (length(btrim(question)) > 0),
  answer      text,
  answered_at timestamptz,
  created_at  timestamptz not null default now()
);

comment on table public.wr_career_questions is
  'Câu hỏi nghề nghiệp người dùng gửi từ ô hỏi tự do (họp khách 2026-07-29). '
  'answer null = đang chờ người vận hành trả lời qua email.';

create index if not exists wr_career_questions_user_created_idx
  on public.wr_career_questions (user_id, created_at desc);

-- Chỉ dòng chưa trả lời mới cần người vận hành xử lý — index riêng để hàng đợi
-- không phải quét cả bảng khi lượng câu hỏi lớn dần.
create index if not exists wr_career_questions_pending_idx
  on public.wr_career_questions (created_at)
  where answer is null;

alter table public.wr_career_questions enable row level security;

drop policy if exists "wr_career_questions_select_own"
  on public.wr_career_questions;
drop policy if exists "wr_career_questions_insert_own"
  on public.wr_career_questions;

create policy "wr_career_questions_select_own"
  on public.wr_career_questions
  for select
  using (auth.uid() = user_id);

create policy "wr_career_questions_insert_own"
  on public.wr_career_questions
  for insert
  with check (auth.uid() = user_id);

-- Cố tình KHÔNG có policy update/delete cho người dùng: câu trả lời do người
-- vận hành ghi (service role), và một câu hỏi đã gửi thì không sửa được nữa —
-- nếu không, hàng đợi trả lời sẽ đọc một câu khác với câu người ta thật sự hỏi.

grant select, insert on public.wr_career_questions to authenticated;

-- ---------------------------------------------------------------------------
-- 2 · Bản thu cho HEALING AUDIO
--
-- Khách chốt dùng giọng đọc AI trước (AusyncLab), tự đọc để sau. App phát từ
-- `audio_url`; cột rỗng nghĩa là chưa dựng bản thu và màn đọc nói thẳng điều đó
-- thay vì hiện một nút play không kêu.
--
-- Cột nằm ở bảng chứ không phải sinh tại chỗ mỗi lần mở màn: gọi TTS cho cùng
-- một bài mỗi lần có người mở là đốt credit và làm người dùng chờ vô ích.
-- ---------------------------------------------------------------------------

alter table public.wr_mood_content
  add column if not exists audio_url text;

comment on column public.wr_mood_content.audio_url is
  'Bản thu đã dựng cho mục HEALING AUDIO. null = chưa có bản thu.';

-- View public phải dựng lại để lộ cột mới. Vẫn KHÔNG có `script`
-- (Hai Lớp v1.6 §XII.3) — thêm audio_url không được phép nới lỏng ranh giới đó.
--
-- `audio_url` phải đứng CUỐI danh sách. `create or replace view` chỉ cho THÊM
-- cột vào cuối, không cho đổi tên cột đang có: chèn audio_url vào giữa thì
-- Postgres đọc ra thành "đổi tên cột placeholder thành audio_url" và từ chối
-- (42P16). Thứ tự cột không ảnh hưởng app — Supabase trả JSON theo tên cột.
create or replace view public.wr_mood_content_public
with (security_invoker = true) as
  select id, mood, sort_order, title, kind, duration, type, body,
         placeholder, created_at, updated_at, audio_url
  from public.wr_mood_content;

comment on view public.wr_mood_content_public is
  'Thư viện Nội dung Cảm xúc cho app. Cố tình KHÔNG có cột script '
  '(Hai Lớp v1.6 §XII.3 — kịch bản lồng tiếng chỉ dùng nội bộ).';

grant select on public.wr_mood_content_public to authenticated;
