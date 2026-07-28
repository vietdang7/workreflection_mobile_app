-- Nới sca_dimension của wr_reflection_episodes để nhận hai nhóm tích cực.
-- Kiến trúc Dữ liệu Hai Lớp v1.6 §2.2.
--
-- Tìm ra khi rà lại sau lỗi 400 của wr_reflection_insights: migration
-- 20260728000000 nới constraint cho bốn bảng, 20260728000005 vá thêm bảng
-- insights, nhưng CHÍNH bảng Episode thì vẫn hẹp.
--
-- Đây là chỗ sẽ vỡ ngay ở lần thử tiếp theo: Episode ghi sca_dimension của
-- tình huống vừa chọn ở MỌI vòng phản tư. Người dùng check-in "đang vui" hoặc
-- "khá ổn" sẽ được gợi ý tình huống P-ACHIEVE / P-STEADY (§III), và lưu Episode
-- là 400 — chưa ai đi qua nhánh này bao giờ nên nó chưa từng lộ.
--
-- Đã soát nốt các constraint còn lại của bảng này, tất cả đều khớp enum Dart:
--   human_moment (6 archetype) · state (9 Experience State) ·
--   energy (good/ok/low) · human_need (4 miền).
--
-- wr_practice_themes cũng còn hẹp nhưng KHÔNG nới: app chỉ đọc bảng đó
-- (`fetchPracticeThemes` là select thuần), và Practice Theme vốn nhắm vào chiều
-- vấn đề nên một chủ đề thực hành cho nhóm tích cực không có nghĩa gì.

alter table public.wr_reflection_episodes
  drop constraint if exists wr_reflection_episodes_sca_dimension_check;
alter table public.wr_reflection_episodes
  add constraint wr_reflection_episodes_sca_dimension_check
  check (sca_dimension in (
    'S1','S2','S3','C1','C2','C3','A1','A2','A3','A4',
    'P-ACHIEVE','P-STEADY'
  ));
