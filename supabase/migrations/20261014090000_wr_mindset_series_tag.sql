-- Họp khách 14/10: thẻ "Chuỗi series Tâm thế người đi làm" ở tab Phát triển
-- chỉ nạp tài liệu của `cc_workshop_resources` có tag
-- 'Chuỗi series tâm thế người đi làm' (app so khớp bỏ dấu, không phân biệt hoa
-- thường). Gắn tag cho các tập đã đăng trước khi có bộ lọc — nhận ra qua tiêu
-- đề, MỘT LẦN, ở đây; từ nay khách gắn tag ngay lúc đăng bên web.
-- Chạy lại không sao: chỉ thêm tag cho dòng còn thiếu.
update public.cc_workshop_resources
set tags = array_append(coalesce(tags, '{}'::text[]), 'Chuỗi series tâm thế người đi làm'),
    updated_at = now()
where title ilike '%tâm thế người đi làm%'
  and not ('Chuỗi series tâm thế người đi làm' = any(coalesce(tags, '{}'::text[])));
