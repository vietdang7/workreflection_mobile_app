-- 20261001130000_wr_owned_skills.sql
--
-- "Chứng chỉ, khoá học, kỹ năng đã có" ở màn Thông tin công việc (họp khách
-- 01/10/2026, Task D2).
--
-- Người dùng tự khai những gì họ ĐÃ có, để app không đề xuất lại đúng thứ đó:
--   • gợi ý chủ đề thực hành (và phần mềm tự thêm chủ đề) bỏ qua `theme_ids`;
--   • đối chiếu kỹ năng với JD không coi `theme_ids` là khoảng trống;
--   • trợ lý trò chuyện được dặn đừng gợi ý lại.
--
-- `theme_ids` là chủ đề thư viện mà mục này tương ứng. Máy chỉ ĐỀ XUẤT, người
-- dùng xác nhận bằng ô tích trước khi lưu.
--
-- `file_path` (không bắt buộc) trỏ vào bucket `context-docs`, đường
-- `{uid}/cert-{ms}.{ext}`. Bucket đó đã có policy theo thư mục `{uid}/`
-- (20260725000002). Tệp ở đây KHÔNG phải một dòng `wr_context_documents`, nên
-- không chiếm suất tài liệu JD/CV của gói Free.

create table if not exists public.wr_owned_skills (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  kind         text not null check (kind in ('certificate','course','skill')),
  title        text not null check (char_length(btrim(title)) between 1 and 160),
  issuer       text check (issuer is null or char_length(issuer) <= 160),
  completed_on date,
  file_path    text,
  theme_ids    text[] not null default '{}',
  created_at   timestamptz not null default now()
);

comment on table public.wr_owned_skills is
  'Chứng chỉ / khoá học / kỹ năng người dùng tự khai đã có. theme_ids do người '
  'dùng xác nhận; app không đề xuất lại các chủ đề này.';

create index if not exists wr_owned_skills_user_created_idx
  on public.wr_owned_skills (user_id, created_at desc);

-- ============================================================
-- RLS: owner-only, 4 policy (mẫu 20260722000000).
-- ============================================================

alter table public.wr_owned_skills enable row level security;

drop policy if exists "wr_owned_skills_owner_select" on public.wr_owned_skills;
drop policy if exists "wr_owned_skills_owner_insert" on public.wr_owned_skills;
drop policy if exists "wr_owned_skills_owner_update" on public.wr_owned_skills;
drop policy if exists "wr_owned_skills_owner_delete" on public.wr_owned_skills;

create policy "wr_owned_skills_owner_select"
  on public.wr_owned_skills
  for select
  using (auth.uid() = user_id);

create policy "wr_owned_skills_owner_insert"
  on public.wr_owned_skills
  for insert
  with check (auth.uid() = user_id);

create policy "wr_owned_skills_owner_update"
  on public.wr_owned_skills
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_owned_skills_owner_delete"
  on public.wr_owned_skills
  for delete
  using (auth.uid() = user_id);
