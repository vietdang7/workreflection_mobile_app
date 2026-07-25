-- Self-Check tiến dần: mỗi ngày một câu nhỏ theo tình huống người dùng vừa
-- ghi nhận. Đủ 15 câu, mobile tạo một wr_sca_self_check_responses chuẩn.

create table if not exists public.wr_sca_self_check_drafts (
  user_id          uuid primary key references auth.users(id) on delete cascade,
  answers          jsonb not null default '{}'::jsonb,
  last_prompted_at timestamptz,
  completed_at     timestamptz,
  updated_at       timestamptz not null default now(),
  constraint wr_sca_self_check_drafts_answers_object
    check (jsonb_typeof(answers) = 'object')
);

alter table public.wr_sca_self_check_drafts enable row level security;

drop policy if exists "wr_sca_self_check_drafts_owner_select"
  on public.wr_sca_self_check_drafts;
drop policy if exists "wr_sca_self_check_drafts_owner_insert"
  on public.wr_sca_self_check_drafts;
drop policy if exists "wr_sca_self_check_drafts_owner_update"
  on public.wr_sca_self_check_drafts;
drop policy if exists "wr_sca_self_check_drafts_owner_delete"
  on public.wr_sca_self_check_drafts;

create policy "wr_sca_self_check_drafts_owner_select"
  on public.wr_sca_self_check_drafts
  for select using (auth.uid() = user_id);

create policy "wr_sca_self_check_drafts_owner_insert"
  on public.wr_sca_self_check_drafts
  for insert with check (auth.uid() = user_id);

create policy "wr_sca_self_check_drafts_owner_update"
  on public.wr_sca_self_check_drafts
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_sca_self_check_drafts_owner_delete"
  on public.wr_sca_self_check_drafts
  for delete using (auth.uid() = user_id);
