-- WorkReflection: Bể Lựa chọn + Ghi chú hoàn thành Thực hành.
-- Kiến trúc Dữ liệu Hai Lớp v1.6 §VI, §VII, §X.

-- ---------------------------------------------------------------------------
-- 1. wr_choice_pool — §VI: bảng tĩnh 8 dòng.
--
-- Dùng chung cho MỌI tình huống ở bước Lựa chọn. Mỗi lần vào bước này hiện
-- ngẫu nhiên 3 câu, cộng Practice riêng của tình huống làm lựa chọn đầu tiên
-- (gắn nhãn "Gợi ý"). Với "Điều khác" không có Practice riêng nên lấy 4 câu.
--
-- §4.2: không cần theo dõi lịch sử cho Choice — bể chỉ có 8 câu, tần suất lặp
-- lại chấp nhận được ở quy mô này.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_choice_pool (
  id         smallint primary key,
  text       text not null unique,
  -- Cho phép rút một câu khỏi bể mà không xoá dòng, vì reflect_choice của các
  -- Episode cũ vẫn đang trỏ tới nội dung này.
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.wr_choice_pool (id, text) values
  (1, 'Thử một cách tiếp cận khác vào lần tới'),
  (2, 'Giữ nguyên cách làm hiện tại, quan sát thêm'),
  (3, 'Chưa biết, cần thêm thời gian'),
  (4, 'Nói chuyện với ai đó về điều này'),
  (5, 'Ghi nhớ điều này để xem lại sau'),
  (6, 'Đặt lời nhắc để quay lại tình huống này sau một tuần'),
  (7, 'Chia sẻ điều này với người liên quan trực tiếp'),
  (8, 'Không cần hành động gì, chỉ cần ghi nhận là đủ')
on conflict (id) do nothing;

alter table public.wr_choice_pool enable row level security;

drop policy if exists "wr_choice_pool_public_read" on public.wr_choice_pool;

create policy "wr_choice_pool_public_read"
  on public.wr_choice_pool
  for select
  using (auth.role() = 'authenticated');

-- ---------------------------------------------------------------------------
-- 2. wr_practice_step_notes — §VII.
--
-- Khi đánh dấu hoàn thành một bước Practice, hệ thống mở ô nhập TÙY CHỌN:
-- "Bạn đã làm gì? Chia sẻ một câu để ghi nhận thêm vào Career Memory, không
-- bắt buộc."
--
-- Nguyên tắc §VII: chia sẻ là phần thưởng ghi nhận thêm, KHÔNG phải điều kiện
-- để hoàn thành. Vì vậy bảng này chỉ có dòng khi người dùng thực sự viết gì đó;
-- chọn "Bỏ qua, chỉ đánh dấu xong" thì không tạo dòng nào.
--
-- Việc đánh dấu xong vẫn nằm ở wr_practice_enrollments.completed_steps — bảng
-- này không thay thế nó, chỉ đính kèm nội dung người dùng viết.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_practice_step_notes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  step_id    text not null references public.wr_practice_steps(step_id)
               on delete cascade,
  note       text not null check (length(btrim(note)) > 0),
  -- Truy vết ngược tới mục Career Memory đã sinh ra từ ghi chú này, để sửa hoặc
  -- gỡ về sau mà không phải dò theo nội dung chuỗi.
  memory_event_id uuid references public.wr_career_memory_events(id)
                    on delete set null,
  created_at timestamptz not null default now(),
  -- Một bước chỉ ghi nhận một lần; làm lại thì cập nhật chính dòng đó.
  unique (user_id, step_id)
);

create index if not exists wr_practice_step_notes_user_idx
  on public.wr_practice_step_notes (user_id, created_at desc);

alter table public.wr_practice_step_notes enable row level security;

drop policy if exists "wr_practice_step_notes_owner_select"
  on public.wr_practice_step_notes;
drop policy if exists "wr_practice_step_notes_owner_insert"
  on public.wr_practice_step_notes;
drop policy if exists "wr_practice_step_notes_owner_update"
  on public.wr_practice_step_notes;
drop policy if exists "wr_practice_step_notes_owner_delete"
  on public.wr_practice_step_notes;

create policy "wr_practice_step_notes_owner_select"
  on public.wr_practice_step_notes
  for select
  using (auth.uid() = user_id);

create policy "wr_practice_step_notes_owner_insert"
  on public.wr_practice_step_notes
  for insert
  with check (auth.uid() = user_id);

create policy "wr_practice_step_notes_owner_update"
  on public.wr_practice_step_notes
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "wr_practice_step_notes_owner_delete"
  on public.wr_practice_step_notes
  for delete
  using (auth.uid() = user_id);
