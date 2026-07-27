-- WorkReflection: Reflection Episode — WXS v1.0 Chương 4 (Experience State Machine)
-- Applies to project sukpcxevcjnhiuyaoqxi (shared with web app)
-- DO NOT push without Fable approval — dry-run only.
--
-- Một Reflection Episode là đơn vị ý nghĩa cơ bản (WXS §1.6): bắt đầu khi một
-- Human Moment được đưa vào hệ thống, kết thúc khi Meaning được lưu vào
-- Career Memory. State phải persist độc lập với UI session (WXS §4.5, §6.4)
-- để người dùng đóng app rồi quay lại vẫn tiếp tục đúng điểm dừng.

-- ============================================================
-- SECTION 1: TABLE
-- ============================================================

create table if not exists public.wr_reflection_episodes (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,

  -- HXA §2.5 — sáu Human Moment Archetypes
  human_moment         text not null check (human_moment in
                         ('arrival','confusion','decision','growth','recovery','celebration')),

  -- WXS §4.2 — chín Experience State
  state                text not null default 'captured' check (state in
                         ('emerging','captured','exploring','meaning_forming',
                          'meaning_confirmed','committed','integrated','dormant','reactivated')),

  -- Ngữ cảnh bắt được ở bước Capture
  energy               text check (energy in ('good','ok','low')),
  situation_code       text,
  sca_dimension        text check (sca_dimension in ('S1','S2','S3','C1','C2','C3','A1','A2','A3','A4')),
  human_need           text check (human_need in ('ro_rang','ket_noi','thich_nghi','phat_trien')),

  -- WXS §1.4 — Reflection Intention, lưu làm ngữ cảnh cho toàn Episode
  intention            text,

  -- HXA §3.5 — các Reflection Pattern đã đi qua, theo thứ tự
  -- ('notice','name','explore','reframe','commit','preserve')
  patterns_done        text[] not null default '{}'::text[],

  -- Nội dung người dùng tự viết ở bước Exploring (một bản ghi cho mỗi pattern)
  notes                jsonb not null default '{}'::jsonb,

  -- WXS §4.2 State 4 — Draft Meaning, CHƯA vào Career Memory
  draft_meaning        text,
  -- WXS Inv.3 — chỉ set khi chính người dùng xác nhận
  confirmed_insight_id uuid references public.wr_reflection_insights(id) on delete set null,
  -- HXA §3.5 Pattern Commit — Tiny Next Step
  tiny_action          text,
  -- Development Theme mà Episode này thuộc về (WXS §2.7)
  theme_id             text,
  -- Career Memory Event sinh ra khi Episode đạt Integrated
  memory_event_id      uuid references public.wr_career_memory_events(id) on delete set null,

  opened_at            timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  closed_at            timestamptz
);

-- ============================================================
-- SECTION 2: INDEXES
-- ============================================================

-- Truy vấn nóng nhất: tìm Episode đang mở của người dùng để resume.
create index if not exists wr_reflection_episodes_user_state_idx
  on public.wr_reflection_episodes (user_id, state, updated_at desc);

create index if not exists wr_reflection_episodes_user_opened_idx
  on public.wr_reflection_episodes (user_id, opened_at desc);

-- ============================================================
-- SECTION 3: RLS (owner-only)
-- ============================================================

alter table public.wr_reflection_episodes enable row level security;

drop policy if exists "wr_reflection_episodes_owner_select" on public.wr_reflection_episodes;
drop policy if exists "wr_reflection_episodes_owner_insert" on public.wr_reflection_episodes;
drop policy if exists "wr_reflection_episodes_owner_update" on public.wr_reflection_episodes;
drop policy if exists "wr_reflection_episodes_owner_delete" on public.wr_reflection_episodes;

create policy "wr_reflection_episodes_owner_select"
  on public.wr_reflection_episodes
  for select
  using (auth.uid() = user_id);

create policy "wr_reflection_episodes_owner_insert"
  on public.wr_reflection_episodes
  for insert
  with check (auth.uid() = user_id);

create policy "wr_reflection_episodes_owner_update"
  on public.wr_reflection_episodes
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_reflection_episodes_owner_delete"
  on public.wr_reflection_episodes
  for delete
  using (auth.uid() = user_id);
