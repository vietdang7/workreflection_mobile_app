-- 20260805110000_wr_career_memory_theme_id.sql
--
-- "Thói quen và Ma trận Cấp bậc v1.0", Phần C mục 1 — sửa lỗi bộ đếm nhận theo
-- TÊN chủ đề.
--
-- Vì sao lỗi này tồn tại: Career Memory không lưu `theme_id`, nên bộ đếm thực
-- hành phải đoán chủ đề bằng cách so tiền tố của `reflection_text` với tên hiển
-- thị. Thư viện lại có những chủ đề trùng tên hoặc trùng chiều (`pt-voice` với
-- `pt-c2`, `pt-rhythm` với `pt-a2`, `pt-feedback` với `pt-c3`), nên hai chủ đề
-- khác nhau có thể cộng chung một bộ đếm — và người dùng thấy một con số không
-- có thật.
--
-- Cách sửa: lưu thẳng `theme_id` vào mảnh ký ức. Cột nullable, KHÔNG backfill:
-- những sự kiện đã ghi trước hôm nay vĩnh viễn không biết chúng thuộc theme_id
-- nào (chỉ có cái tên, và cái tên chính là chỗ nhập nhằng). App vẫn so theo tên
-- cho đúng những hàng cũ đó để không ai mất tiến độ đã có; mọi hàng mới thì so
-- theo `theme_id` và không bao giờ nhập nhằng nữa.
--
-- Không đặt khoá ngoại tới `wr_practice_themes`: mảnh ký ức là dấu vết lịch sử,
-- nó phải sống sót kể cả khi một chủ đề bị gỡ khỏi thư viện.

alter table public.wr_career_memory_events
  add column if not exists theme_id text;

comment on column public.wr_career_memory_events.theme_id is
  'Chủ đề thực hành sinh ra mảnh ký ức này (practice_step_done, '
  'practice_maintained, skill_certified). Null với dữ liệu ghi trước '
  '05/08/2026 — những hàng đó app vẫn nhận theo tên chủ đề.';

-- Bộ đếm luôn lọc theo (user_id, theme_id).
create index if not exists wr_career_memory_theme_idx
  on public.wr_career_memory_events (user_id, theme_id)
  where theme_id is not null;
