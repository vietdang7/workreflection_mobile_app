-- Trò chuyện AI — phần "nói chuyện qua nói chuyện lại" khách hoãn ở họp
-- 2026-07-29 ("cái đó chị nghĩ sẽ chờ sau"). Giờ tới lúc làm.
--
-- Nguồn: WorkReflection_AI_Chatbox_System_Prompt v1.0, đi kèm Kiến trúc Dữ liệu
-- Hai Lớp v2.3 mục XV.
--
-- ---------------------------------------------------------------------------
-- Vì sao là bảng MỚI chứ không nới `wr_career_questions`
--
-- Bảng cũ cố ý "một câu hỏi là một dòng", không có role, không có hội thoại
-- (xem migration 20260729000000). Nhồi lượt chat vào đó sẽ phá đúng cái hàng
-- đợi mà người vận hành đang đọc để trả lời qua email: mỗi lượt AI trả lời sẽ
-- thành một dòng "đã trả lời" giả, và câu người ta thật sự chờ email bị lẫn
-- mất. Hai mạch khác nhau thì để ở hai bảng khác nhau.
--
-- `wr_career_questions` GIỮ NGUYÊN, không đụng tới. Màn Hỏi cũ đổi thành khung
-- chat nhưng lịch sử câu hỏi cũ vẫn đọc lại được.
-- ---------------------------------------------------------------------------

create table if not exists public.wr_chat_messages (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       text not null check (role in ('user', 'assistant')),
  content    text not null check (length(btrim(content)) > 0),
  -- Model đã sinh ra câu này. Ghi lại vì system prompt được tinh chỉnh theo
  -- hành vi của một model cụ thể; khi đổi model mà chất lượng đổi theo, phải
  -- tra được lượt nào do model nào sinh ra chứ không ngồi đoán.
  model      text,
  created_at timestamptz not null default now()
);

comment on table public.wr_chat_messages is
  'Lượt trò chuyện với trợ lý phản chiếu (AI Chatbox System Prompt v1.0). '
  'Chỉ service role được ghi — xem chú thích RLS bên dưới.';

create index if not exists wr_chat_messages_user_created_idx
  on public.wr_chat_messages (user_id, created_at desc);

alter table public.wr_chat_messages enable row level security;

drop policy if exists "wr_chat_messages_select_own" on public.wr_chat_messages;
drop policy if exists "wr_chat_messages_delete_own" on public.wr_chat_messages;

create policy "wr_chat_messages_select_own"
  on public.wr_chat_messages
  for select
  using (auth.uid() = user_id);

-- Xoá được cuộc trò chuyện của chính mình. Đây là nhật ký riêng tư về công
-- việc, người ta phải có quyền dọn đi mà không cần nhờ ai.
create policy "wr_chat_messages_delete_own"
  on public.wr_chat_messages
  for delete
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- CỐ Ý KHÔNG CÓ policy insert/update cho `authenticated`.
--
-- Toàn bộ việc ghi đi qua Edge Function `wr-chat` bằng service role. Nếu app
-- được phép insert thẳng thì hai thứ vỡ cùng lúc:
--
--   1. Hạn mức của gói miễn phí đếm theo số dòng role='user' trong ngày. Cho
--      client ghi tức là cho client tự quyết mình đã hỏi bao nhiêu câu.
--   2. Client có thể bịa dòng role='assistant'. Lượt bịa đó sẽ được nạp lại
--      làm lịch sử ở lần gọi sau, tức là một đường tiêm chữ thẳng vào ngữ cảnh
--      của model, vượt qua mọi ranh giới ở mục 6 và mục 7 của system prompt.
--
-- Service role bỏ qua RLS nên không cần policy riêng cho nó.
-- ---------------------------------------------------------------------------

grant select, delete on public.wr_chat_messages to authenticated;

-- ---------------------------------------------------------------------------
-- Đếm lượt đã dùng trong ngày, phục vụ hạn mức gói miễn phí.
--
-- Đặt ở database chứ không đếm trong Edge Function bằng cách tải cả lịch sử về:
-- hàm này chỉ trả một con số, không kéo nội dung trò chuyện ra khỏi bảng.
--
-- Mốc ngày theo giờ Việt Nam (UTC+7), không theo UTC: người dùng ở VN, "hôm
-- nay" của họ phải trùng với "hôm nay" của hạn mức. Lấy mốc UTC thì hạn mức
-- reset lúc 7 giờ sáng, giữa buổi làm việc, không ai hiểu vì sao.
-- ---------------------------------------------------------------------------

create or replace function public.wr_chat_used_today(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.wr_chat_messages
  where user_id = p_user_id
    and role = 'user'
    and (created_at at time zone 'Asia/Ho_Chi_Minh')::date
        = (now() at time zone 'Asia/Ho_Chi_Minh')::date;
$$;

comment on function public.wr_chat_used_today(uuid) is
  'Số lượt người dùng đã hỏi trong ngày (giờ VN). Dùng cho hạn mức gói miễn phí.';

grant execute on function public.wr_chat_used_today(uuid) to authenticated;
