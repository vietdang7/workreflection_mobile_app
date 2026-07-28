-- Nới hai check constraint của wr_reflection_insights.
--
-- Bắt được khi chạy thật trên trình duyệt 2026-07-28:
--   POST /rest/v1/wr_reflection_insights → 400 Bad Request
--
-- Hai nguyên nhân, nguyên nhân đầu nặng hơn nhiều:
--
-- 1. `source` chỉ nhận ('story','self_check','pattern'), nhưng luồng Episode
--    (từ 2026-07-27) ghi source = 'episode'. Nghĩa là MỌI lần người dùng xác
--    nhận Ý nghĩa đều bị từ chối — không phải trường hợp hiếm nào cả. Lỗi im
--    lặng vì `insertInsight` được bọc best-effort, nên Episode vẫn lưu
--    draft_meaning và màn hình vẫn đi tiếp như không có chuyện gì.
--    Hệ quả: khối "Insight gần nhất" ở Home không bao giờ có dữ liệu.
--
-- 2. `sca_dimension` chỉ nhận S1..A4. Migration 20260728000000 đã nới cho
--    wr_situations / wr_stories / wr_career_memory_events / wr_pattern_counts
--    để nhận P-ACHIEVE và P-STEADY (Hai Lớp v1.6 §2.2), nhưng SÓT bảng này.
--    Nên phản tư trên tình huống tích cực còn hỏng thêm một lần nữa.
--
-- Vì sao 1377 test không bắt được: fake repository không có check constraint.
-- Bài học đã ghi vào kế hoạch — ràng buộc ở tầng DB thì chỉ chạy thật mới lộ.

alter table public.wr_reflection_insights
  drop constraint if exists wr_reflection_insights_source_check;
alter table public.wr_reflection_insights
  add constraint wr_reflection_insights_source_check
  check (source in ('story', 'self_check', 'pattern', 'episode'));

alter table public.wr_reflection_insights
  drop constraint if exists wr_reflection_insights_sca_dimension_check;
alter table public.wr_reflection_insights
  add constraint wr_reflection_insights_sca_dimension_check
  check (sca_dimension in (
    'S1','S2','S3','C1','C2','C3','A1','A2','A3','A4',
    'P-ACHIEVE','P-STEADY'
  ));

comment on column public.wr_reflection_insights.source is
  'story = luồng Story cũ · self_check = SCA Self-Check · pattern = suy từ '
  'Pattern · episode = luồng Reflection Episode (mặc định từ 2026-07-27).';
