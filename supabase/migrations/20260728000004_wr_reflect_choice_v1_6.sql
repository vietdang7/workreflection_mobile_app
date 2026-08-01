-- Bước Choice của Reflection Cycle được ghi riêng.
-- Kiến trúc Dữ liệu Hai Lớp v1.6 §V · WDA Invariant 9.
--
-- Vấn đề đang chữa: WDA Inv.9 coi Choice là MỘT bước của Reflection Cycle, và
-- §V bảng ánh xạ ghi rõ bước Choice ghi ra trường `reflectChoice`. Nhưng app
-- đang gộp nó vào `tiny_action`: câu người dùng chạm ở bể Lựa chọn bị lưu như
-- thể đó là Action, nên bảng `wr_reflection_steps` chưa bao giờ có dòng
-- 'choice' — dù check constraint đã cho phép giá trị đó từ v1.2.
--
-- Vì sao phải là một cột trên Episode, không phải biến trong màn hình: Episode
-- ngủ được giữa bước Lựa chọn và bước Đóng (WXS §4.5). Giữ ở state màn hình thì
-- người dùng tạm dừng rồi quay lại là mất, và dòng 'choice' sẽ không bao giờ
-- được ghi.
--
-- Phân biệt hai trường:
--   reflect_choice : câu người dùng CHỌN từ bốn lựa chọn được đưa ra (§VI).
--                    null khi họ bỏ qua bể và tự viết — lúc đó không có lựa
--                    chọn nào được đưa ra để mà chọn.
--   tiny_action    : điều người dùng cam kết sẽ làm. Luôn có khi đã Commit,
--                    dù đến từ bể hay tự viết.

alter table public.wr_reflection_episodes
  add column if not exists reflect_choice text;

comment on column public.wr_reflection_episodes.reflect_choice is
  'Hai Lớp v1.6 §V — câu được chọn từ Bể Lựa chọn ở bước Choice. '
  'null khi người dùng tự viết thay vì chọn.';
