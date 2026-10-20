-- Sổ lượt gọi AI gợi ý thực hành — Edge Function `wr-practice-suggest`.
--
-- Chỉ để ĐẾM hạn ngạch (người dùng chốt 20/10/2026): gói Free được 2 lần có AI
-- trọn đời (đếm `ok = true`), mọi gói có trần chống lạm dụng mỗi 24 giờ (đếm
-- mọi hàng). KHÔNG lưu nội dung người dùng gõ hay chữ AI trả về: chủ đề tạo ra
-- đã nằm ở bảng chủ đề, giữ thêm một bản ở đây chỉ thêm chỗ rò.
--
-- Chỉ Edge Function ghi (service role). Người dùng đọc được hàng của mình.

create table if not exists public.wr_practice_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  ok boolean not null default false,
  locale text not null default 'vi' check (locale in ('vi', 'en')),
  model text,
  created_at timestamptz not null default now()
);

create index if not exists wr_practice_suggestions_user_idx
  on public.wr_practice_suggestions (user_id, created_at desc);

alter table public.wr_practice_suggestions enable row level security;

drop policy if exists "wr_practice_suggestions_owner_select"
  on public.wr_practice_suggestions;

create policy "wr_practice_suggestions_owner_select"
  on public.wr_practice_suggestions for select
  using (auth.uid() = user_id);
