-- WorkReflection Mobile: wr_* tables, owner-only RLS, seed function
-- Applies to project sukpcxevcjnhiuyaoqxi (shared with the web app)

create table if not exists public.wr_mobile_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  onboarding_situation text,
  reminder_enabled boolean not null default true,
  language text not null default 'vi',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wr_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mood text not null check (mood in ('stressed','tired','okay','happy')),
  checkin_date date not null default (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  created_at timestamptz not null default now(),
  unique (user_id, checkin_date)
);

create table if not exists public.wr_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  source text,
  saved_at timestamptz not null default now()
);

create table if not exists public.wr_recurring_situations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null,
  occurrence_count integer not null default 1,
  updated_at timestamptz not null default now()
);

create table if not exists public.wr_development_themes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  code text not null,
  title text not null,
  subtitle text,
  stage integer not null default 1,
  total_stages integer not null default 4,
  progress numeric not null default 0 check (progress >= 0 and progress <= 1),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.wr_practices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  theme_id uuid references public.wr_development_themes(id) on delete set null,
  title text not null,
  status text not null default 'todo' check (status in ('todo','doing','done')),
  practice_date date not null default (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.wr_timeline_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in ('MILESTONE','STORY','THEME')),
  title text not null,
  description text,
  occurred_at date not null default (now() at time zone 'Asia/Ho_Chi_Minh')::date,
  created_at timestamptz not null default now()
);

create index if not exists wr_checkins_user_date_idx on public.wr_checkins (user_id, checkin_date desc);
create index if not exists wr_insights_user_saved_idx on public.wr_insights (user_id, saved_at desc);
create index if not exists wr_practices_user_date_idx on public.wr_practices (user_id, practice_date desc);
create index if not exists wr_timeline_events_user_idx on public.wr_timeline_events (user_id, occurred_at desc);

-- Owner-only RLS on every wr_ table
do $$
declare t text;
begin
  foreach t in array array['wr_mobile_profiles','wr_checkins','wr_insights','wr_recurring_situations','wr_development_themes','wr_practices','wr_timeline_events']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "%s_owner_select" on public.%I', t, t);
    execute format('drop policy if exists "%s_owner_insert" on public.%I', t, t);
    execute format('drop policy if exists "%s_owner_update" on public.%I', t, t);
    execute format('drop policy if exists "%s_owner_delete" on public.%I', t, t);
    execute format('create policy "%s_owner_select" on public.%I for select using (auth.uid() = user_id)', t, t);
    execute format('create policy "%s_owner_insert" on public.%I for insert with check (auth.uid() = user_id)', t, t);
    execute format('create policy "%s_owner_update" on public.%I for update using (auth.uid() = user_id) with check (auth.uid() = user_id)', t, t);
    execute format('create policy "%s_owner_delete" on public.%I for delete using (auth.uid() = user_id)', t, t);
  end loop;
end $$;

-- wr_mobile_profiles keys on user_id (policies above reference user_id, which is its PK)

-- Idempotent sample-data seeder for the calling user
create or replace function public.seed_wr_sample_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  vtheme uuid;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  if exists (select 1 from wr_development_themes where user_id = uid) then
    return; -- already seeded
  end if;

  insert into wr_development_themes (user_id, code, title, subtitle, stage, total_stages, progress, is_active)
  values (uid, 'VOICE', 'Khả năng lên tiếng & phản biện', 'Khả năng lên tiếng & phản biện', 2, 4, 0.55, true)
  returning id into vtheme;

  insert into wr_practices (user_id, theme_id, title, status, completed_at) values
    (uid, vtheme, 'Quan sát lúc muốn im lặng', 'done', now()),
    (uid, vtheme, 'Đặt một câu hỏi trong họp', 'doing', null),
    (uid, vtheme, 'Chia sẻ một quan điểm', 'todo', null);

  insert into wr_recurring_situations (user_id, label, occurrence_count) values
    (uid, 'Ngại phản biện', 5),
    (uid, 'Tránh đối thoại khó', 4),
    (uid, 'Thiếu phản hồi từ sếp', 2);

  insert into wr_insights (user_id, content, source, saved_at) values
    (uid, 'Tôi thường im lặng không phải vì không có ý kiến, mà vì sợ phán xét.', 'VOICE', now() - interval '4 days'),
    (uid, 'Tôi ngại nói thật vì lo bị đánh giá.', 'VOICE', now() - interval '14 days');

  insert into wr_timeline_events (user_id, event_type, title, description, occurred_at) values
    (uid, 'MILESTONE', 'Insight đầu tiên', '"Tôi ngại nói thật vì lo bị đánh giá."', (now() - interval '14 days')::date),
    (uid, 'STORY', 'Hoàn thành Story #3', 'Khi im lặng trở thành thói quen', (now() - interval '9 days')::date),
    (uid, 'THEME', 'Voice Journey bắt đầu', 'Trọng tâm phát triển được xác định', (now() - interval '4 days')::date);
end;
$$;

revoke all on function public.seed_wr_sample_data() from public;
grant execute on function public.seed_wr_sample_data() to authenticated;
