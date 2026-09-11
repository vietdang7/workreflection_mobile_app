-- Bản tiếng Anh cho Thư viện Nội dung Cảm xúc.
--
-- ---------------------------------------------------------------------------
-- VÌ SAO BẢNG NÀY BỊ BỎ SÓT
--
-- Đợt 10/09 phủ `wr_situations`, `wr_stories`, `wr_practice_*`, `cc_*` — tất cả
-- những bảng đi vào luồng Reflect. `wr_mood_content` không nằm trong luồng đó
-- nên trượt khỏi danh sách.
--
-- Nhưng nó là bảng người dùng NHÌN THẤY nhiều nhất: mục đầu tiên của nhóm cảm
-- xúc vừa check-in hiện thẳng trên màn Hôm nay, ngay dưới thẻ "Hệ thống nhận
-- ra". Bật tiếng Anh lên thì cả màn Hôm nay là tiếng Anh trừ đúng thẻ này —
-- tiêu đề bài đọc, nhãn "BÀI ĐỌC", thời lượng, và toàn văn khi mở ra.
--
-- ---------------------------------------------------------------------------
-- CHỈ HAI CỘT, KHÔNG PHẢI BỐN
--
-- `kind` chỉ có duy nhất một giá trị ('BÀI ĐỌC') và `duration` chỉ có ba
-- ('2/3/4 phút đọc'). Đó là NHÃN GIAO DIỆN đội nội dung gõ vào ô văn bản, không
-- phải nội dung. Thêm cột `_en` cho chúng là buộc người biên tập dịch lại cùng
-- một chữ ba mươi lần và tạo ba mươi cơ hội gõ lệch nhau.
--
-- Hai trường đó dịch ở tầng app (`MoodContent.kindLabel` / `durationLabel`),
-- nơi một dòng `tr()` phủ hết cả bảng. Ở đây chỉ thêm cột cho thứ thật sự là
-- nội dung: tiêu đề và toàn văn.
--
-- `script` (kịch bản lồng tiếng) KHÔNG có bản tiếng Anh: nó chưa từng được trả
-- về cho app (view `wr_mood_content_public` cố tình bỏ cột này) và hiện đang
-- rỗng ở cả 30 dòng.

alter table public.wr_mood_content
  add column if not exists title_en text,
  add column if not exists body_en text;

comment on column public.wr_mood_content.title_en is
  'Bản tiếng Anh của title. NULL = chưa dịch, app rơi về tiếng Việt.';
comment on column public.wr_mood_content.body_en is
  'Bản tiếng Anh của body. NULL = chưa dịch, app rơi về tiếng Việt.';

-- View phải mở hai cột mới, nếu không app đọc qua view sẽ không bao giờ thấy
-- chúng — và bản dịch nằm im trong bảng mà không ai đọc được.
--
-- Giữ nguyên việc KHÔNG có `script`: §XII.3 quy định kịch bản lồng tiếng chỉ
-- dùng nội bộ, không trả về client. Thêm cột `_en` không phải lý do để nới chỗ
-- đó ra.
--
-- ⚠ HAI CỘT MỚI PHẢI ĐỨNG CUỐI. `create or replace view` chỉ cho phép THÊM cột
--   vào đuôi — chèn `title_en` ngay sau `title` cho ra lỗi 42P16 "cannot change
--   name of view column". Muốn xếp đẹp thì phải drop rồi tạo lại, mà drop là
--   mất hết grant và policy đang gắn vào view. Không đáng đổi.
--
--   App đọc theo TÊN cột (`json['title_en']`) nên thứ tự không ảnh hưởng gì.
create or replace view public.wr_mood_content_public as
  select
    id,
    mood,
    sort_order,
    title,
    kind,
    duration,
    type,
    body,
    placeholder,
    created_at,
    updated_at,
    audio_url,
    title_en,
    body_en
  from public.wr_mood_content;
