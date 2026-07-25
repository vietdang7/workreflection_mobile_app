-- Align the final practice stage with the approved mobile prototype:
-- Recognition → Experiment → Transformation.
update public.wr_practice_steps
set title = 'Chuyển hóa'
where step_order = 3
  and title = 'Duy trì';

-- The Free plan promises three practice themes. The approved prototype includes
-- "Phản hồi hiệu quả", which was missing from the original two-theme seed.
insert into public.wr_practice_themes
  (theme_id, title, sca_dimension, description)
values
  (
    'pt-feedback',
    'Phản hồi hiệu quả',
    'C3',
    'Biến việc nhìn lại và chia sẻ bài học thành một nhịp phản hồi an toàn, '
      'cụ thể và đều đặn.'
  )
on conflict (theme_id) do update
set title = excluded.title,
    sca_dimension = excluded.sca_dimension,
    description = excluded.description;

insert into public.wr_practice_steps
  (step_id, theme_id, step_order, title, content, is_premium)
values
  (
    'pt-feedback-1',
    'pt-feedback',
    1,
    'Nhận diện',
    'Dành 5 phút cuối ngày để ghi lại 1 điều đã làm tốt và 1 điều bạn muốn '
      'cải thiện. Chỉ quan sát, chưa cần phán xét hay sửa ngay.',
    false
  ),
  (
    'pt-feedback-2',
    'pt-feedback',
    2,
    'Thử nghiệm',
    'Chia sẻ 1 bài học cụ thể trong cuộc họp hoặc buổi 1-1 tuần này, rồi hỏi '
      'người nghe xem điều gì hữu ích với họ.',
    false
  ),
  (
    'pt-feedback-3',
    'pt-feedback',
    3,
    'Chuyển hóa',
    'Duy trì một cuộc nhìn lại ngắn mỗi tuần trong 4 tuần: điều gì nên giữ, '
      'điều gì nên đổi và bước nhỏ tiếp theo là gì.',
    true
  )
on conflict (step_id) do update
set theme_id = excluded.theme_id,
    step_order = excluded.step_order,
    title = excluded.title,
    content = excluded.content,
    is_premium = excluded.is_premium;
