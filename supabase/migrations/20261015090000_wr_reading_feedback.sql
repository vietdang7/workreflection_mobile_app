-- "Khớp với tôi" / "Chưa đúng lắm" cho bản đọc của hệ thống.
--
-- Nguồn: "Logic đọc hiểu mình.docx" §7 (Cloud & Coral, 15/10/2026).
--
-- Mỗi lần bấm ghi readingId, verdict, timestamp. Sau "Chưa đúng lắm" hệ thống
-- hoãn đọc lại cho tới khi có thêm 3 lần nhìn lại, và trong lúc chờ vẫn giữ
-- nguyên bản đọc cũ kèm ghi nhận của người dùng — nên phải lưu đủ đầu vào của
-- bản đọc (`reading`) để dựng lại đúng bản họ đã xem.
--
-- Nhật ký sự kiện như `wr_insight_feedback`: một hàng mỗi lần bấm, không có
-- update/delete. Người dùng đổi ý thì ghi hàng mới.

create table if not exists public.wr_reading_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,

  -- Loại bản đọc. Hiện chỉ có 'overview' (Tổng quan).
  reading_kind text not null default 'overview',

  -- Khoá nhận diện bản đọc, ví dụ 'diverged:c:a'.
  reading_key text not null,

  -- Đầu vào của bản đọc lúc người dùng phản hồi.
  reading jsonb not null default '{}'::jsonb,

  verdict text not null check (verdict in ('match', 'off')),

  created_at timestamptz not null default now()
);

create index if not exists wr_reading_feedback_user_idx
  on public.wr_reading_feedback (user_id, reading_kind, created_at desc);

alter table public.wr_reading_feedback enable row level security;

drop policy if exists "wr_reading_feedback_owner_select" on public.wr_reading_feedback;
drop policy if exists "wr_reading_feedback_owner_insert" on public.wr_reading_feedback;

create policy "wr_reading_feedback_owner_select"
  on public.wr_reading_feedback for select
  using (auth.uid() = user_id);

create policy "wr_reading_feedback_owner_insert"
  on public.wr_reading_feedback for insert
  with check (auth.uid() = user_id);
