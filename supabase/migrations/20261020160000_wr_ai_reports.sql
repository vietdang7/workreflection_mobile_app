-- Báo cáo câu trả lời AI — nút "Báo cáo" dưới mỗi bong bóng của trợ lý.
--
-- Chính sách Nội dung do AI tạo của Google Play: app có AI tạo nội dung phải
-- cho người dùng báo cáo nội dung xúc phạm ngay trong app, không bắt rời app.
--
-- Lưu BẢN CHỤP câu trả lời (`content`) chứ không chỉ trỏ tới wr_chat_messages:
-- người dùng xoá cuộc trò chuyện thì tin nhắn mất theo, mà báo cáo vẫn phải đọc
-- được. `message_id` và `conversation_id` để trống được vì lượt vừa trả lời
-- chưa có id phía app.
--
-- Người dùng chỉ ghi và đọc hàng của mình; admin đọc tất cả để xem lại.

create table if not exists public.wr_ai_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  surface text not null default 'chat' check (surface in ('chat')),
  reason text not null
    check (reason in ('offensive', 'harmful', 'sexual', 'misleading', 'other')),
  note text check (note is null or char_length(note) <= 1000),
  content text not null check (char_length(content) <= 20000),
  conversation_id uuid,
  message_id uuid,
  locale text not null default 'vi' check (locale in ('vi', 'en')),
  created_at timestamptz not null default now()
);

comment on table public.wr_ai_reports is
  'Báo cáo câu trả lời AI không phù hợp từ app (chính sách AI-Generated Content của Google Play).';

create index if not exists wr_ai_reports_created_idx
  on public.wr_ai_reports (created_at desc);

alter table public.wr_ai_reports enable row level security;

drop policy if exists "wr_ai_reports_owner_insert" on public.wr_ai_reports;
create policy "wr_ai_reports_owner_insert"
  on public.wr_ai_reports for insert
  with check (auth.uid() = user_id);

drop policy if exists "wr_ai_reports_owner_select" on public.wr_ai_reports;
create policy "wr_ai_reports_owner_select"
  on public.wr_ai_reports for select
  using (auth.uid() = user_id);

drop policy if exists "wr_ai_reports_admin_select" on public.wr_ai_reports;
create policy "wr_ai_reports_admin_select"
  on public.wr_ai_reports for select
  using (public.has_role(auth.uid(), 'admin'));
