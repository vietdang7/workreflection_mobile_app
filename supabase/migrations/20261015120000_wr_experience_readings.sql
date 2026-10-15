-- Bản đọc "Bạn đang khó ở chỗ nào" do Edge Function `wr-experience-read` viết.
--
-- Nguồn: "Logic đọc hiểu mình.docx" §2 (Cloud & Coral, 15/10/2026): "Sinh một
-- lần, lưu cùng bản đọc, không sinh lại ở mỗi màn."
--
-- Một hàng cho mỗi bộ nguyên liệu (danh sách chuyện đang quay lại + dòng tự
-- viết + ngôn ngữ). Cùng nguyên liệu thì hàm trả lại hàng cũ, không gọi model.
-- `result` có dạng {"s": {"shape","detail","hard_part"}, ...}; nhóm trượt phép
-- thử thì vắng mặt, kể cả khi cả object rỗng.
--
-- Chỉ Edge Function ghi (service role). Người dùng đọc được hàng của mình.

create table if not exists public.wr_experience_readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fingerprint text not null,
  locale text not null default 'vi' check (locale in ('vi', 'en')),
  result jsonb not null default '{}'::jsonb,
  model text,
  created_at timestamptz not null default now(),
  unique (user_id, fingerprint, locale)
);

create index if not exists wr_experience_readings_user_idx
  on public.wr_experience_readings (user_id, created_at desc);

alter table public.wr_experience_readings enable row level security;

drop policy if exists "wr_experience_readings_owner_select"
  on public.wr_experience_readings;

create policy "wr_experience_readings_owner_select"
  on public.wr_experience_readings for select
  using (auth.uid() = user_id);
