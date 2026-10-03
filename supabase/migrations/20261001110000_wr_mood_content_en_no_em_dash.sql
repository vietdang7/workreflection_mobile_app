-- Bỏ gạch dài (—, –) khỏi bản tiếng Anh của Thư viện Nội dung Cảm xúc.
--
-- Task B3 (khách 01/10): gạch dài nối hai vế câu là dấu hiệu "chữ do AI viết".
-- Bản dịch EN trong 20260910200000 có 23 bài chứa nó. Chỉ có MỘT cột bị: mig
-- đó ghi `title_en` và `body_en` của `wr_mood_content`, và chỉ `body_en` chứa
-- gạch dài (`title_en` sạch). Cột tiếng Việt không đụng tới.
--
-- LUẬT: cùng luật với bộ lọc `stripMarkdown` (Deno + Dart): gạch có khoảng
-- trắng hai bên, GIỮA HAI CHỮ, thành ", ". Gạch giữa hai số ("5 – 3") và gạch
-- không có khoảng trắng không bị đụng. Chỉ thay trong cùng một dòng (không ăn
-- qua dòng trống giữa các đoạn nên số đoạn `paragraphs` không đổi).
--
-- Chạy lại nhiều lần vẫn an toàn: điều kiện `where` chỉ chọn hàng còn gạch.

update public.wr_mood_content
set body_en = regexp_replace(
  body_en,
  '(?<=[[:alpha:]])[ \t]+[—–][ \t]+(?=[[:alpha:]])',
  ', ',
  'g'
)
where body_en ~ '[—–]';
