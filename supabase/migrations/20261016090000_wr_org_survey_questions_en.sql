-- Bản tiếng Anh cho 12 câu Khảo sát tổ chức (ESI).
--
-- Bật tiếng Anh mà màn khảo sát vẫn hiện câu hỏi tiếng Việt (máy thật
-- 16/10): bảng chỉ có cột `text`. App đọc `text_en` qua `trDb` — cột trống thì
-- rơi về tiếng Việt, nên app cũ lẫn app mới đều chạy được dù migration này đi
-- trước hay sau bản build.
--
-- Chỉ ghi khi `text` còn đúng câu đang có, để lỡ đội nội dung đã sửa câu tiếng
-- Việt thì bản dịch cũ không bị gắn vào câu mới.

alter table public.wr_org_survey_questions
  add column if not exists text_en text;

update public.wr_org_survey_questions as q set text_en = v.text_en
from (values
  ('OS-01', 'Mức độ hài lòng của bạn với thu nhập hiện tại, so với khối lượng và tính chất công việc bạn đang làm.',
            'How satisfied you are with your current income, given the amount and kind of work you do.'),
  ('OS-02', 'Mức độ hài lòng của bạn với các phúc lợi hiện có, như bảo hiểm, thưởng, nghỉ phép.',
            'How satisfied you are with your current benefits, such as insurance, bonuses and leave.'),
  ('OS-03', 'Mức độ hài lòng của bạn khi so sánh đãi ngộ hiện tại với mặt bằng chung ngành.',
            'How satisfied you are with your current pay and benefits compared with the norm in your industry.'),
  ('OS-04', 'Mức độ hài lòng của bạn với cơ hội học hỏi kỹ năng mới trong công việc hiện tại.',
            'How satisfied you are with the chances to learn new skills in your current job.'),
  ('OS-05', 'Mức độ hài lòng của bạn với lộ trình hoặc định hướng phát triển cho vị trí hiện tại.',
            'How satisfied you are with the path or direction for growth in your current role.'),
  ('OS-06', 'Mức độ hài lòng của bạn với mức đầu tư thời gian và ngân sách của tổ chức cho việc phát triển năng lực của bạn.',
            'How satisfied you are with the time and budget your organisation invests in developing your abilities.'),
  ('OS-07', 'Mức độ hài lòng của bạn với cách các quyết định thăng tiến, khen thưởng được đưa ra trong đội.',
            'How satisfied you are with how promotion and reward decisions are made in your team.'),
  ('OS-08', 'Mức độ hài lòng của bạn với sự công bằng trong cách bạn được đối xử so với đồng nghiệp cùng vị trí.',
            'How satisfied you are with how fairly you are treated compared with colleagues in the same role.'),
  ('OS-09', 'Mức độ hài lòng của bạn với cách các vấn đề hoặc khiếu nại được xử lý.',
            'How satisfied you are with how problems or complaints are handled.'),
  ('OS-10', 'Mức độ hài lòng của bạn với sự hỗ trợ nhận được khi gặp khó khăn trong công việc.',
            'How satisfied you are with the support you get when you run into difficulties at work.'),
  ('OS-11', 'Mức độ hài lòng của bạn với sự quan tâm của cấp quản lý trực tiếp đến khối lượng và sức khỏe tinh thần của bạn.',
            'How satisfied you are with how much your direct manager cares about your workload and mental wellbeing.'),
  ('OS-12', 'Mức độ hài lòng của bạn với công cụ và nguồn lực được cung cấp để hoàn thành công việc.',
            'How satisfied you are with the tools and resources you are given to get your work done.')
) as v(id, text_vi, text_en)
where q.id = v.id
  and q.text = v.text_vi;
