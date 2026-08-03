-- Vá thứ tự lượt trò chuyện đã ghi trước 2026-08-03.
--
-- ---------------------------------------------------------------------------
-- LỖI
--
-- Edge Function `wr-chat` ghi câu hỏi và câu trả lời bằng MỘT lệnh insert, để
-- không có khoảnh khắc nào lịch sử chỉ có câu hỏi mà thiếu câu đáp. Nhưng
-- `created_at` để `default now()`, mà `now()` trong Postgres tính một lần cho
-- cả câu lệnh, nên hai dòng nhận đúng một mốc thời gian tới từng micro giây.
--
-- Sắp xếp theo cột đó thành ra không xác định. Test đầu-cuối đọc lại thấy lượt
-- `assistant` đứng TRƯỚC lượt `user` của chính cặp đó.
--
-- Hỏng hai chỗ cùng lúc:
--   • Người dùng mở lại cuộc cũ, thấy câu trả lời nằm trên câu mình vừa hỏi.
--   • Edge Function nạp lịch sử theo đúng thứ tự lộn ấy làm ngữ cảnh, tức là
--     model đọc cuộc trò chuyện ngược rồi trả lời dựa trên đó.
--
-- Hàm đã được sửa để tự đặt `created_at` lệch nhau một phần nghìn giây. File
-- này lo phần dữ liệu ĐÃ ghi, vốn không tự sửa được.
-- ---------------------------------------------------------------------------

-- Đẩy lượt trợ lý muộn hơn một phần nghìn giây so với câu hỏi trùng mốc của
-- cùng cuộc trò chuyện.
--
-- Chỉ chạm đúng những dòng đang trùng: `exists` bên dưới lọc ra các lượt
-- `assistant` có một lượt `user` cùng cuộc và cùng y hệt mốc thời gian. Dòng
-- nào vốn đã có thứ tự rõ ràng thì không bị đụng tới.
update public.wr_chat_messages a
set created_at = a.created_at + interval '1 millisecond'
where a.role = 'assistant'
  and exists (
    select 1
    from public.wr_chat_messages u
    where u.conversation_id = a.conversation_id
      and u.role = 'user'
      and u.created_at = a.created_at
  );

-- Chỉ mục theo đúng thứ tự đọc của màn lịch sử.
--
-- `fetchHistory` sắp giảm dần rồi cắt 20 dòng gần nhất, nên chỉ mục phải gồm cả
-- chiều sắp xếp. Thiếu nó thì mỗi lần mở một cuộc là một lần quét toàn bảng của
-- người đó, và bảng này chỉ có lớn dần.
create index if not exists wr_chat_messages_conversation_time_idx
  on public.wr_chat_messages (conversation_id, created_at desc);
