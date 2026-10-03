-- 20261001120000_wr_user_practice_actions.sql
--
-- "Việc bạn tự đặt" trên tab Phát triển (họp khách 01/10/2026, Task D1).
--
-- Người dùng tự gõ một việc muốn thực hành ("Hỏi ý kiến 1 đồng nghiệp mỗi
-- ngày"), mỗi ngày bấm "Hôm nay tôi đã làm" một lần, đủ `target_count` lần thì
-- coi là xong.
--
-- ⚠ BẢNG RIÊNG, KHÔNG dùng `wr_practice_enrollments`:
--   • bảng đó có khoá ngoại sang `wr_practice_themes`, người dùng không có quyền
--     thêm chủ đề vào thư viện;
--   • dùng chung thì việc tự đặt bị tính như chủ đề thư viện: chiếm suất Free 2
--     chủ đề, chặn phần mềm tự thêm chủ đề, và lọt vào khối "Chủ đề thực hành
--     đang theo" của trợ lý trò chuyện (`wr-chat/user_context.ts`).

create table if not exists public.wr_user_practice_actions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  title        text not null check (char_length(btrim(title)) between 1 and 120),
  target_count smallint not null default 5 check (target_count between 1 and 100),
  created_at   timestamptz not null default now(),
  completed_at timestamptz
);

comment on table public.wr_user_practice_actions is
  'Việc người dùng tự đặt để thực hành (tab Phát triển). KHÔNG phải chủ đề '
  'thư viện: không tính quota, không ảnh hưởng tự thêm chủ đề.';

create table if not exists public.wr_user_practice_action_logs (
  action_id uuid not null references public.wr_user_practice_actions(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  done_on   date not null default (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  -- Một lần mỗi ngày, như nút "duy trì" của chủ đề.
  primary key (action_id, done_on)
);

comment on table public.wr_user_practice_action_logs is
  'Mỗi dòng là một ngày người dùng bấm "Hôm nay tôi đã làm" cho một việc tự đặt.';

create index if not exists wr_user_practice_actions_user_created_idx
  on public.wr_user_practice_actions (user_id, created_at desc);

create index if not exists wr_user_practice_action_logs_user_idx
  on public.wr_user_practice_action_logs (user_id);

-- ============================================================
-- RLS: owner-only, 4 policy mỗi bảng (mẫu 20260722000000).
-- ============================================================

alter table public.wr_user_practice_actions enable row level security;

drop policy if exists "wr_user_practice_actions_owner_select" on public.wr_user_practice_actions;
drop policy if exists "wr_user_practice_actions_owner_insert" on public.wr_user_practice_actions;
drop policy if exists "wr_user_practice_actions_owner_update" on public.wr_user_practice_actions;
drop policy if exists "wr_user_practice_actions_owner_delete" on public.wr_user_practice_actions;

create policy "wr_user_practice_actions_owner_select"
  on public.wr_user_practice_actions
  for select
  using (auth.uid() = user_id);

create policy "wr_user_practice_actions_owner_insert"
  on public.wr_user_practice_actions
  for insert
  with check (auth.uid() = user_id);

create policy "wr_user_practice_actions_owner_update"
  on public.wr_user_practice_actions
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_user_practice_actions_owner_delete"
  on public.wr_user_practice_actions
  for delete
  using (auth.uid() = user_id);

alter table public.wr_user_practice_action_logs enable row level security;

drop policy if exists "wr_user_practice_action_logs_owner_select" on public.wr_user_practice_action_logs;
drop policy if exists "wr_user_practice_action_logs_owner_insert" on public.wr_user_practice_action_logs;
drop policy if exists "wr_user_practice_action_logs_owner_update" on public.wr_user_practice_action_logs;
drop policy if exists "wr_user_practice_action_logs_owner_delete" on public.wr_user_practice_action_logs;

create policy "wr_user_practice_action_logs_owner_select"
  on public.wr_user_practice_action_logs
  for select
  using (auth.uid() = user_id);

-- Ghi log chỉ cho việc CỦA CHÍNH MÌNH. Khoá ngoại không đi qua RLS, nên thiếu
-- vế `exists` thì ai biết id việc của người khác cũng chèn được một dòng vào
-- ngày hôm nay của họ, và lượt bấm thật của chủ việc sẽ vấp khoá chính.
create policy "wr_user_practice_action_logs_owner_insert"
  on public.wr_user_practice_action_logs
  for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.wr_user_practice_actions a
       where a.id = action_id and a.user_id = auth.uid()
    )
  );

create policy "wr_user_practice_action_logs_owner_update"
  on public.wr_user_practice_action_logs
  for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.wr_user_practice_actions a
       where a.id = action_id and a.user_id = auth.uid()
    )
  );

create policy "wr_user_practice_action_logs_owner_delete"
  on public.wr_user_practice_action_logs
  for delete
  using (auth.uid() = user_id);
