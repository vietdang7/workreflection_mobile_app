-- Nhiều cuộc trò chuyện, thay vì một dòng chảy vô tận.
--
-- ---------------------------------------------------------------------------
-- VÌ SAO
--
-- Bản đầu (migration 20260803000000) chỉ có một mạch duy nhất cho mỗi người:
-- mọi lượt đổ vào cùng một danh sách, và ngữ cảnh gửi cho model luôn là 20 lượt
-- gần nhất bất kể chúng thuộc chuyện gì. Hệ quả: kể chuyện xung đột với đồng
-- nghiệp hôm nay, mai hỏi về chuyện thăng tiến, model vẫn kéo phần xung đột hôm
-- qua vào và trả lời lệch.
--
-- Tách thành từng cuộc trò chuyện chữa đúng chỗ đó, và cũng là điều kiện để có
-- nút "cuộc trò chuyện mới" cùng màn lịch sử.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_chat_conversations (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  -- Tiêu đề lấy từ chính câu đầu tiên người dùng gõ, cắt ngắn. Cố ý KHÔNG nhờ
  -- model đặt tên: thêm một lượt gọi, thêm tiền, thêm độ trễ, cho một dòng chữ
  -- mà câu gốc của người ta vốn đã mô tả đúng nhất.
  title           text,
  created_at      timestamptz not null default now(),
  -- Sắp danh sách theo cột này, không theo `created_at`: người ta tìm cuộc trò
  -- chuyện vừa nói dở, không phải cuộc mở sớm nhất.
  last_message_at timestamptz not null default now()
);

comment on table public.wr_chat_conversations is
  'Một cuộc trò chuyện với trợ lý phản chiếu. Chỉ service role được ghi.';

create index if not exists wr_chat_conversations_user_recent_idx
  on public.wr_chat_conversations (user_id, last_message_at desc);

alter table public.wr_chat_conversations enable row level security;

drop policy if exists "wr_chat_conversations_select_own"
  on public.wr_chat_conversations;
drop policy if exists "wr_chat_conversations_delete_own"
  on public.wr_chat_conversations;

create policy "wr_chat_conversations_select_own"
  on public.wr_chat_conversations
  for select using (auth.uid() = user_id);

create policy "wr_chat_conversations_delete_own"
  on public.wr_chat_conversations
  for delete using (auth.uid() = user_id);

grant select, delete on public.wr_chat_conversations to authenticated;

-- ---------------------------------------------------------------------------
-- Nối lượt trò chuyện vào cuộc trò chuyện
-- ---------------------------------------------------------------------------

alter table public.wr_chat_messages
  add column if not exists conversation_id uuid
    references public.wr_chat_conversations(id) on delete cascade;

-- Chuyển dữ liệu cũ: mỗi người đang có lượt trò chuyện được cấp đúng MỘT cuộc,
-- giữ nguyên thứ tự. Gộp hết vào một cuộc là đúng với sự thật của dữ liệu cũ —
-- lúc đó nó thật sự là một mạch liền, và ta không có căn cứ nào để cắt ra.
do $$
declare
  r record;
  new_id uuid;
begin
  for r in
    select user_id,
           min(created_at) as first_at,
           max(created_at) as last_at
    from public.wr_chat_messages
    where conversation_id is null
    group by user_id
  loop
    insert into public.wr_chat_conversations (user_id, title, created_at, last_message_at)
    values (r.user_id, 'Cuộc trò chuyện trước đây', r.first_at, r.last_at)
    returning id into new_id;

    update public.wr_chat_messages
      set conversation_id = new_id
    where user_id = r.user_id and conversation_id is null;
  end loop;
end $$;

-- Đặt NOT NULL SAU khi chuyển xong. Đặt trước thì lệnh chạy trên cơ sở dữ liệu
-- đã có dòng cũ sẽ hỏng ngay tại đây.
alter table public.wr_chat_messages
  alter column conversation_id set not null;

create index if not exists wr_chat_messages_conversation_idx
  on public.wr_chat_messages (conversation_id, created_at);

-- Index cũ theo (user_id, created_at) GIỮ NGUYÊN: hàm đếm hạn mức
-- `wr_chat_used_today` vẫn hỏi theo người dùng và theo ngày, không theo cuộc
-- trò chuyện. Hạn mức là của một người trong một ngày, mở bao nhiêu cuộc cũng
-- không đẻ thêm lượt.
