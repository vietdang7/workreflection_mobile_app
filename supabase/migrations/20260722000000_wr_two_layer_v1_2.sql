-- WorkReflection: Two-Layer Data Architecture v1.2 (Free Reflection / Paid Intelligence)
-- Applies to project sukpcxevcjnhiuyaoqxi (shared with web app)
-- DO NOT push without Fable approval — dry-run only.

-- ============================================================
-- SECTION 1: CONTENT TABLES (authenticated read-only)
-- ============================================================

-- 1. wr_sca_self_check_questions
create table if not exists public.wr_sca_self_check_questions (
  question_id    text primary key,
  pillar         text not null check (pillar in ('S','C','A')),
  display_order  smallint not null,
  question_text  text not null,
  created_at     timestamptz not null default now()
);

-- 2. wr_practice_themes
create table if not exists public.wr_practice_themes (
  theme_id       text primary key,
  title          text not null,
  sca_dimension  text check (sca_dimension in ('S1','S2','S3','C1','C2','C3','A1','A2','A3','A4')),
  description    text,
  created_at     timestamptz not null default now()
);

-- 3. wr_practice_steps
create table if not exists public.wr_practice_steps (
  step_id        text primary key,
  theme_id       text not null references public.wr_practice_themes(theme_id) on delete cascade,
  step_order     smallint not null,
  title          text not null,
  content        text,
  is_premium     boolean not null default false,
  created_at     timestamptz not null default now()
);

-- ============================================================
-- SECTION 2: USER DATA TABLES (owner-only RLS)
-- ============================================================

-- 4. wr_entitlements
create table if not exists public.wr_entitlements (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  plan         text not null default 'free' check (plan in ('free','premium')),
  valid_until  timestamptz,
  source       text,
  updated_at   timestamptz not null default now()
);

-- 5. wr_human_need_snapshots
create table if not exists public.wr_human_need_snapshots (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  snapshot_date  date not null default current_date,
  ro_rang        smallint not null default 0,
  ket_noi        smallint not null default 0,
  thich_nghi     smallint not null default 0,
  phat_trien     smallint not null default 0,
  created_at     timestamptz not null default now(),
  unique (user_id, snapshot_date)
);

-- 6. wr_reflection_steps
create table if not exists public.wr_reflection_steps (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  memory_event_id  uuid references public.wr_career_memory_events(id) on delete cascade,
  step             text not null check (step in ('notice','meaning','insight','choice','action')),
  content          text,
  created_at       timestamptz not null default now()
);

-- 7. wr_reflection_insights
create table if not exists public.wr_reflection_insights (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  source         text check (source in ('story','self_check','pattern')),
  sca_dimension  text check (sca_dimension in ('S1','S2','S3','C1','C2','C3','A1','A2','A3','A4')),
  human_need     text check (human_need in ('ro_rang','ket_noi','thich_nghi','phat_trien')),
  content        text not null,
  created_at     timestamptz not null default now()
);

-- 8. wr_pattern_counts
create table if not exists public.wr_pattern_counts (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  situation_code   text references public.wr_situations(code),
  sca_dimension    text check (sca_dimension in ('S1','S2','S3','C1','C2','C3','A1','A2','A3','A4')),
  occurrence_count integer not null default 1,
  last_seen_at     timestamptz not null default now(),
  unique (user_id, situation_code)
);

-- 9. wr_pattern_narratives
create table if not exists public.wr_pattern_narratives (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  period_start date,
  period_end   date,
  narrative    text not null,
  created_at   timestamptz not null default now()
);

-- 10. wr_growth_journey_snapshots
create table if not exists public.wr_growth_journey_snapshots (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  period_label  text,
  progress      jsonb not null default '{}'::jsonb,
  direction     text,
  created_at    timestamptz not null default now()
);

-- 11. wr_sca_self_check_responses
create table if not exists public.wr_sca_self_check_responses (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  answers          jsonb not null,
  structure_score  numeric,
  culture_score    numeric,
  activity_score   numeric,
  taken_at         timestamptz not null default now()
);

-- 12. wr_practice_enrollments
create table if not exists public.wr_practice_enrollments (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  theme_id      text references public.wr_practice_themes(theme_id),
  started_at    timestamptz default now(),
  completed_at  timestamptz,
  unique (user_id, theme_id)
);

-- 13. wr_context_documents
create table if not exists public.wr_context_documents (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  doc_type    text check (doc_type in ('jd','cv','other')),
  file_path   text not null,
  uploaded_at timestamptz default now()
);

-- ============================================================
-- SECTION 3: INDEXES
-- ============================================================

create index if not exists wr_human_need_snapshots_user_idx        on public.wr_human_need_snapshots (user_id, created_at desc);
create index if not exists wr_reflection_steps_user_idx            on public.wr_reflection_steps (user_id, created_at desc);
create index if not exists wr_reflection_insights_user_idx                    on public.wr_reflection_insights (user_id, created_at desc);
create index if not exists wr_pattern_counts_user_idx              on public.wr_pattern_counts (user_id);
create index if not exists wr_pattern_narratives_user_idx          on public.wr_pattern_narratives (user_id, created_at desc);
create index if not exists wr_growth_journey_user_idx              on public.wr_growth_journey_snapshots (user_id, created_at desc);
create index if not exists wr_sca_self_check_responses_user_idx    on public.wr_sca_self_check_responses (user_id, taken_at desc);
create index if not exists wr_practice_enrollments_user_idx        on public.wr_practice_enrollments (user_id);
create index if not exists wr_context_documents_user_idx           on public.wr_context_documents (user_id, uploaded_at desc);

-- ============================================================
-- SECTION 4: RLS — CONTENT TABLES (authenticated read-only)
-- ============================================================

-- wr_sca_self_check_questions
alter table public.wr_sca_self_check_questions enable row level security;

drop policy if exists "wr_sca_self_check_questions_public_read" on public.wr_sca_self_check_questions;

create policy "wr_sca_self_check_questions_public_read"
  on public.wr_sca_self_check_questions
  for select
  using (auth.role() = 'authenticated');

-- wr_practice_themes
alter table public.wr_practice_themes enable row level security;

drop policy if exists "wr_practice_themes_public_read" on public.wr_practice_themes;

create policy "wr_practice_themes_public_read"
  on public.wr_practice_themes
  for select
  using (auth.role() = 'authenticated');

-- wr_practice_steps
alter table public.wr_practice_steps enable row level security;

drop policy if exists "wr_practice_steps_public_read" on public.wr_practice_steps;

create policy "wr_practice_steps_public_read"
  on public.wr_practice_steps
  for select
  using (auth.role() = 'authenticated');

-- ============================================================
-- SECTION 5: RLS — USER DATA TABLES
-- ============================================================

-- wr_entitlements (SELECT only — ghi bởi backend/webhook thanh toán)
alter table public.wr_entitlements enable row level security;

drop policy if exists "wr_entitlements_owner_select" on public.wr_entitlements;

create policy "wr_entitlements_owner_select"
  on public.wr_entitlements
  for select
  using (auth.uid() = user_id);

-- wr_human_need_snapshots (owner-only 4 policies)
alter table public.wr_human_need_snapshots enable row level security;

drop policy if exists "wr_human_need_snapshots_owner_select" on public.wr_human_need_snapshots;
drop policy if exists "wr_human_need_snapshots_owner_insert" on public.wr_human_need_snapshots;
drop policy if exists "wr_human_need_snapshots_owner_update" on public.wr_human_need_snapshots;
drop policy if exists "wr_human_need_snapshots_owner_delete" on public.wr_human_need_snapshots;

create policy "wr_human_need_snapshots_owner_select"
  on public.wr_human_need_snapshots
  for select
  using (auth.uid() = user_id);

create policy "wr_human_need_snapshots_owner_insert"
  on public.wr_human_need_snapshots
  for insert
  with check (auth.uid() = user_id);

create policy "wr_human_need_snapshots_owner_update"
  on public.wr_human_need_snapshots
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_human_need_snapshots_owner_delete"
  on public.wr_human_need_snapshots
  for delete
  using (auth.uid() = user_id);

-- wr_reflection_steps (owner-only 4 policies)
alter table public.wr_reflection_steps enable row level security;

drop policy if exists "wr_reflection_steps_owner_select" on public.wr_reflection_steps;
drop policy if exists "wr_reflection_steps_owner_insert" on public.wr_reflection_steps;
drop policy if exists "wr_reflection_steps_owner_update" on public.wr_reflection_steps;
drop policy if exists "wr_reflection_steps_owner_delete" on public.wr_reflection_steps;

create policy "wr_reflection_steps_owner_select"
  on public.wr_reflection_steps
  for select
  using (auth.uid() = user_id);

create policy "wr_reflection_steps_owner_insert"
  on public.wr_reflection_steps
  for insert
  with check (auth.uid() = user_id);

create policy "wr_reflection_steps_owner_update"
  on public.wr_reflection_steps
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_reflection_steps_owner_delete"
  on public.wr_reflection_steps
  for delete
  using (auth.uid() = user_id);

-- wr_reflection_insights (owner-only 4 policies)
alter table public.wr_reflection_insights enable row level security;

drop policy if exists "wr_reflection_insights_owner_select" on public.wr_reflection_insights;
drop policy if exists "wr_reflection_insights_owner_insert" on public.wr_reflection_insights;
drop policy if exists "wr_reflection_insights_owner_update" on public.wr_reflection_insights;
drop policy if exists "wr_reflection_insights_owner_delete" on public.wr_reflection_insights;

create policy "wr_reflection_insights_owner_select"
  on public.wr_reflection_insights
  for select
  using (auth.uid() = user_id);

create policy "wr_reflection_insights_owner_insert"
  on public.wr_reflection_insights
  for insert
  with check (auth.uid() = user_id);

create policy "wr_reflection_insights_owner_update"
  on public.wr_reflection_insights
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_reflection_insights_owner_delete"
  on public.wr_reflection_insights
  for delete
  using (auth.uid() = user_id);

-- wr_pattern_counts (owner-only 4 policies)
alter table public.wr_pattern_counts enable row level security;

drop policy if exists "wr_pattern_counts_owner_select" on public.wr_pattern_counts;
drop policy if exists "wr_pattern_counts_owner_insert" on public.wr_pattern_counts;
drop policy if exists "wr_pattern_counts_owner_update" on public.wr_pattern_counts;
drop policy if exists "wr_pattern_counts_owner_delete" on public.wr_pattern_counts;

create policy "wr_pattern_counts_owner_select"
  on public.wr_pattern_counts
  for select
  using (auth.uid() = user_id);

create policy "wr_pattern_counts_owner_insert"
  on public.wr_pattern_counts
  for insert
  with check (auth.uid() = user_id);

create policy "wr_pattern_counts_owner_update"
  on public.wr_pattern_counts
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_pattern_counts_owner_delete"
  on public.wr_pattern_counts
  for delete
  using (auth.uid() = user_id);

-- wr_pattern_narratives (SELECT only — AI backend ghi)
alter table public.wr_pattern_narratives enable row level security;

drop policy if exists "wr_pattern_narratives_owner_select" on public.wr_pattern_narratives;

create policy "wr_pattern_narratives_owner_select"
  on public.wr_pattern_narratives
  for select
  using (auth.uid() = user_id);

-- wr_growth_journey_snapshots (SELECT only — AI backend ghi)
alter table public.wr_growth_journey_snapshots enable row level security;

drop policy if exists "wr_growth_journey_snapshots_owner_select" on public.wr_growth_journey_snapshots;

create policy "wr_growth_journey_snapshots_owner_select"
  on public.wr_growth_journey_snapshots
  for select
  using (auth.uid() = user_id);

-- wr_sca_self_check_responses (owner-only 4 policies)
alter table public.wr_sca_self_check_responses enable row level security;

drop policy if exists "wr_sca_self_check_responses_owner_select" on public.wr_sca_self_check_responses;
drop policy if exists "wr_sca_self_check_responses_owner_insert" on public.wr_sca_self_check_responses;
drop policy if exists "wr_sca_self_check_responses_owner_update" on public.wr_sca_self_check_responses;
drop policy if exists "wr_sca_self_check_responses_owner_delete" on public.wr_sca_self_check_responses;

create policy "wr_sca_self_check_responses_owner_select"
  on public.wr_sca_self_check_responses
  for select
  using (auth.uid() = user_id);

create policy "wr_sca_self_check_responses_owner_insert"
  on public.wr_sca_self_check_responses
  for insert
  with check (auth.uid() = user_id);

create policy "wr_sca_self_check_responses_owner_update"
  on public.wr_sca_self_check_responses
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_sca_self_check_responses_owner_delete"
  on public.wr_sca_self_check_responses
  for delete
  using (auth.uid() = user_id);

-- wr_practice_enrollments (owner-only 4 policies)
alter table public.wr_practice_enrollments enable row level security;

drop policy if exists "wr_practice_enrollments_owner_select" on public.wr_practice_enrollments;
drop policy if exists "wr_practice_enrollments_owner_insert" on public.wr_practice_enrollments;
drop policy if exists "wr_practice_enrollments_owner_update" on public.wr_practice_enrollments;
drop policy if exists "wr_practice_enrollments_owner_delete" on public.wr_practice_enrollments;

create policy "wr_practice_enrollments_owner_select"
  on public.wr_practice_enrollments
  for select
  using (auth.uid() = user_id);

create policy "wr_practice_enrollments_owner_insert"
  on public.wr_practice_enrollments
  for insert
  with check (auth.uid() = user_id);

create policy "wr_practice_enrollments_owner_update"
  on public.wr_practice_enrollments
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_practice_enrollments_owner_delete"
  on public.wr_practice_enrollments
  for delete
  using (auth.uid() = user_id);

-- wr_context_documents (owner-only 4 policies)
alter table public.wr_context_documents enable row level security;

drop policy if exists "wr_context_documents_owner_select" on public.wr_context_documents;
drop policy if exists "wr_context_documents_owner_insert" on public.wr_context_documents;
drop policy if exists "wr_context_documents_owner_update" on public.wr_context_documents;
drop policy if exists "wr_context_documents_owner_delete" on public.wr_context_documents;

create policy "wr_context_documents_owner_select"
  on public.wr_context_documents
  for select
  using (auth.uid() = user_id);

create policy "wr_context_documents_owner_insert"
  on public.wr_context_documents
  for insert
  with check (auth.uid() = user_id);

create policy "wr_context_documents_owner_update"
  on public.wr_context_documents
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_context_documents_owner_delete"
  on public.wr_context_documents
  for delete
  using (auth.uid() = user_id);
