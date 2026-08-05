-- DO NOT push without Fable approval
-- Sprint 1 migration: self-check question seeds, practice progress column, practice theme seeds
-- Date: 2026-07-22

-- ─────────────────────────────────────────────────────────────────────────────
-- (a) Seed 15 Self-Check questions into wr_sca_self_check_questions
--     question_id: scq-01..scq-15, pillar: S/C/A, display_order, question_text
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.wr_sca_self_check_questions
  (question_id, pillar, display_order, question_text)
values
  -- Pillar S (Sự rõ ràng), gốc SCA_QUESTIONS id: 1, 2, 3, 4, 5
  ('scq-01', 'S', 1,
   'Trước khi bắt đầu một công việc mới, bạn thường được làm rõ về trách nhiệm của mình và người phối hợp cùng.'),
  ('scq-02', 'S', 2,
   'Với các công việc quan trọng, bạn có quy trình và hướng dẫn cụ thể trước khi bắt đầu triển khai.'),
  ('scq-03', 'S', 3,
   'Các nguyên tắc phối hợp trong đội ngũ của bạn được thống nhất rõ ràng và cập nhật đầy đủ đến mọi người liên quan.'),
  ('scq-04', 'S', 4,
   'Bạn biết rõ thông tin nào cần chia sẻ qua kênh nào, không bị lạc trong quá nhiều nhóm chat hay email chồng chéo.'),
  ('scq-05', 'S', 5,
   'Khi có thay đổi trong công việc, nhìn chung bạn không bị bất ngờ hay phải tự tìm hiểu thêm.'),
  -- Pillar C (Mối quan hệ), gốc SCA_QUESTIONS id: 6, 7, 8, 9, 10
  ('scq-06', 'C', 6,
   'Bạn nhận thấy cấp quản lý của mình nhất quán giữa những gì nói và những gì làm trong thực tế công việc.'),
  ('scq-07', 'C', 7,
   'Những người bạn làm việc cùng thể hiện sự nhất quán giữa lời nói và hành động, bạn có thể tin vào cam kết của họ.'),
  ('scq-08', 'C', 8,
   'Bạn cảm thấy thoải mái khi nêu ý kiến khác biệt với số đông, kể cả khi điều đó tạo ra tranh luận.'),
  ('scq-09', 'C', 9,
   'Khi bạn nhận thấy rủi ro hoặc vấn đề tiềm ẩn, bạn sẵn sàng lên tiếng, kể cả khi chưa có giải pháp.'),
  ('scq-10', 'C', 10,
   'Khi có bất đồng quan điểm, cuộc trao đổi của bạn tập trung vào tìm giải pháp thay vì tranh luận về ai đúng.'),
  -- Pillar A (Cách làm việc), gốc SCA_QUESTIONS id: 11, 12, 13, 14, 15
  ('scq-11', 'A', 11,
   'Trong công việc hàng ngày, bạn hiểu rõ công việc của mình kết nối với mục tiêu chung của đội nhóm như thế nào.'),
  ('scq-12', 'A', 12,
   'Khi mục tiêu thay đổi, bạn được thông báo kịp thời và rõ lý do, không phải tự đoán hay phát hiện muộn.'),
  ('scq-13', 'A', 13,
   'Nhịp phối hợp của đội nhóm bạn rõ ràng và ổn định, có check-in đều đặn, không bị lạc nhịp.'),
  ('scq-14', 'A', 14,
   'Sau mỗi giai đoạn hoặc dự án, nhóm của bạn có thời gian chính thức để nhìn lại và đánh giá những gì đã làm.'),
  ('scq-15', 'A', 15,
   'Những điểm cần điều chỉnh sau khi nhìn lại được chuyển thành hành động cụ thể, có người theo dõi.')
on conflict (question_id) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- (b) Add completed_steps column to wr_practice_enrollments
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.wr_practice_enrollments
  add column if not exists completed_steps text[] not null default '{}';

-- ─────────────────────────────────────────────────────────────────────────────
-- (c) Seed 2 practice themes + steps (content mẫu — chờ khách duyệt)
-- ─────────────────────────────────────────────────────────────────────────────

-- Theme 1: Dám lên tiếng (sca_dimension C2)
insert into public.wr_practice_themes
  (theme_id, title, sca_dimension, description)
values
  ('pt-voice', 'Dám lên tiếng', 'C2',
   'Xây dựng thói quen lên tiếng đúng lúc và đúng cách trong môi trường làm việc.')
on conflict (theme_id) do nothing;

insert into public.wr_practice_steps
  (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-voice-1', 'pt-voice', 1, 'Nhận diện',
   'Quan sát 1 cuộc họp trong tuần này. Ghi lại những khoảnh khắc bạn muốn nói nhưng đã im lặng — không phán xét, chỉ quan sát.',
   false),
  ('pt-voice-2', 'pt-voice', 2, 'Thử nghiệm',
   'Đặt đúng 1 câu hỏi trong cuộc họp tuần này. Không cần hoàn hảo — chỉ cần lên tiếng.',
   false),
  ('pt-voice-3', 'pt-voice', 3, 'Duy trì',
   'Chia sẻ 1 quan điểm của bạn mỗi tuần trong 4 tuần liên tiếp. Ghi chú ngắn sau mỗi lần về cảm nhận.',
   true)
on conflict (step_id) do nothing;

-- Theme 2: Nhịp làm việc ổn định (sca_dimension A2)
insert into public.wr_practice_themes
  (theme_id, title, sca_dimension, description)
values
  ('pt-rhythm', 'Nhịp làm việc ổn định', 'A2',
   'Tìm lại và giữ vững nhịp độ làm việc sâu, ổn định giữa môi trường nhiều gián đoạn.')
on conflict (theme_id) do nothing;

insert into public.wr_practice_steps
  (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-rhythm-1', 'pt-rhythm', 1, 'Nhận diện',
   'Theo dõi lịch làm việc của bạn trong 3 ngày. Ghi lại: bạn bị gián đoạn bao nhiêu lần, vào lúc nào, vì lý do gì.',
   false),
  ('pt-rhythm-2', 'pt-rhythm', 2, 'Thử nghiệm',
   'Thử nghiệm 1 khối thời gian làm việc sâu (deep work) trong tuần này — ít nhất 90 phút không gián đoạn. Đánh giá kết quả.',
   false),
  ('pt-rhythm-3', 'pt-rhythm', 3, 'Duy trì',
   'Duy trì ít nhất 2 khối deep work mỗi tuần trong 4 tuần liên tiếp. Ghi ngắn: điều gì giúp bạn giữ được nhịp?',
   true)
on conflict (step_id) do nothing;
