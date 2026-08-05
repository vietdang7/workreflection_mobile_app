-- 20260731000000_wr_practice_themes_by_dimension.sql
--
-- Mười chủ đề thực hành, mỗi chiều SCA một chủ đề (khách chốt 2026-07-31:
-- "nên tạo chủ đề khớp theo tình huống của người dùng").
--
-- Nội dung lấy nguyên từ `PRACTICE_THEMES` trong giao diện mẫu Sprint 2
-- (WorkReflection_Sprint2_Mockup (2).html) — không phải chữ tự nghĩ ra. Khuôn
-- ba bước Nhận diện → Thử nghiệm → Chuyển hóa giữ đúng như mẫu, và bước
-- "Chuyển hóa" là bước khoá premium (mẫu: locked:true, paywall trigger
-- `practice_step` — "Mở khoá bước Chuyển hóa").
--
-- Hai chủ đề cũ `pt-voice` và `pt-rhythm` trùng chiều với `pt-c2` / `pt-a2`.
-- KHÔNG xoá: ai đang ghi danh vẫn phải đi tiếp được chuỗi bước của mình. Chỉ
-- đánh dấu ngưng đề xuất — xem cột `retired_at` bên dưới.

-- ============================================================
-- 1. Cột đánh dấu chủ đề ngưng đề xuất
-- ============================================================

alter table public.wr_practice_themes
  add column if not exists retired_at timestamptz;

comment on column public.wr_practice_themes.retired_at is
  'Khác null = ngưng đề xuất cho người mới. Người đã ghi danh vẫn thấy và đi tiếp bình thường.';

-- ============================================================
-- 2. Mười chủ đề theo chiều SCA
-- ============================================================

-- S1 · Clarity — Rõ ràng về điều được kỳ vọng
insert into public.wr_practice_themes (theme_id, title, sca_dimension, description)
values ('pt-s1', 'Rõ ràng về điều được kỳ vọng', 'S1', null)
on conflict (theme_id) do update set title = excluded.title, sca_dimension = excluded.sca_dimension;

insert into public.wr_practice_steps (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-s1-1', 'pt-s1', 1, 'Nhận diện — Ghi lại một lần chưa rõ kỳ vọng', 'Chú ý một tình huống tuần này bạn không chắc điều gì được mong đợi ở mình.', false),
  ('pt-s1-2', 'pt-s1', 2, 'Thử nghiệm — Hỏi thẳng một câu làm rõ', 'Trước khi bắt tay vào việc tiếp theo, hỏi người giao việc một câu để chắc chắn về kết quả mong muốn.', false),
  ('pt-s1-3', 'pt-s1', 3, 'Chuyển hóa — Biến việc hỏi rõ thành thói quen', 'Với mọi việc mới, luôn làm rõ kết quả tốt trông như thế nào trước khi bắt đầu.', true)
on conflict (step_id) do update set
  title = excluded.title, content = excluded.content, is_premium = excluded.is_premium;

-- S2 · Clarity — Ưu tiên đúng việc của mình
insert into public.wr_practice_themes (theme_id, title, sca_dimension, description)
values ('pt-s2', 'Ưu tiên đúng việc của mình', 'S2', null)
on conflict (theme_id) do update set title = excluded.title, sca_dimension = excluded.sca_dimension;

insert into public.wr_practice_steps (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-s2-1', 'pt-s2', 1, 'Nhận diện — Ghi lại việc không thuộc về mình', 'Chú ý một việc gần đây bạn ôm vào dù không thực sự cần bạn quyết định.', false),
  ('pt-s2-2', 'pt-s2', 2, 'Thử nghiệm — Từ chối hoặc chuyển giao một việc', 'Chọn một việc không thuộc phạm vi của bạn để từ chối hoặc giao lại.', false),
  ('pt-s2-3', 'pt-s2', 3, 'Chuyển hóa — Giữ một cách ưu tiên rõ ràng', 'Xây một cách phân loại việc theo mức độ bạn thực sự cần quyết định, dùng lại mỗi tuần.', true)
on conflict (step_id) do update set
  title = excluded.title, content = excluded.content, is_premium = excluded.is_premium;

-- S3 · Clarity — Vững vàng khi mọi thứ thay đổi
insert into public.wr_practice_themes (theme_id, title, sca_dimension, description)
values ('pt-s3', 'Vững vàng khi mọi thứ thay đổi', 'S3', null)
on conflict (theme_id) do update set title = excluded.title, sca_dimension = excluded.sca_dimension;

insert into public.wr_practice_steps (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-s3-1', 'pt-s3', 1, 'Nhận diện — Ghi lại một thay đổi gây hụt hẫng', 'Chú ý một lần bạn bất ngờ vì không được báo trước một thay đổi.', false),
  ('pt-s3-2', 'pt-s3', 2, 'Thử nghiệm — Chủ động hỏi lý do thay đổi', 'Hỏi trực tiếp về lý do đằng sau một quyết định thay đổi, thay vì tự đoán.', false),
  ('pt-s3-3', 'pt-s3', 3, 'Chuyển hóa — Xác nhận thay vì giả định', 'Xây thói quen xác nhận lại thông tin quan trọng trước khi hành động theo đó.', true)
on conflict (step_id) do update set
  title = excluded.title, content = excluded.content, is_premium = excluded.is_premium;

-- C1 · Connection — Tin và được tin
insert into public.wr_practice_themes (theme_id, title, sca_dimension, description)
values ('pt-c1', 'Tin và được tin', 'C1', null)
on conflict (theme_id) do update set title = excluded.title, sca_dimension = excluded.sca_dimension;

insert into public.wr_practice_steps (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-c1-1', 'pt-c1', 1, 'Nhận diện — Ghi lại một lần kiểm tra lại dù đã tin', 'Chú ý một lần bạn kiểm tra lại việc đã giao, dù đã tin tưởng người đó.', false),
  ('pt-c1-2', 'pt-c1', 2, 'Thử nghiệm — Giao trọn một việc, không kiểm tra giữa chừng', 'Chọn một việc, giao đi và không hỏi han cho đến hạn chót.', false),
  ('pt-c1-3', 'pt-c1', 3, 'Chuyển hóa — Duy trì niềm tin đã trao', 'Giữ việc giao trọn vẹn, không kiểm soát chi tiết, như một thói quen chứ không phải ngoại lệ.', true)
on conflict (step_id) do update set
  title = excluded.title, content = excluded.content, is_premium = excluded.is_premium;

-- C2 · Connection — Dám lên tiếng
insert into public.wr_practice_themes (theme_id, title, sca_dimension, description)
values ('pt-c2', 'Dám lên tiếng', 'C2', null)
on conflict (theme_id) do update set title = excluded.title, sca_dimension = excluded.sca_dimension;

insert into public.wr_practice_steps (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-c2-1', 'pt-c2', 1, 'Nhận diện — Quan sát lúc muốn im lặng', 'Chú ý những khoảnh khắc bạn có ý kiến nhưng chọn không nói.', false),
  ('pt-c2-2', 'pt-c2', 2, 'Thử nghiệm — Đặt một câu hỏi trong họp', 'Trong cuộc họp tiếp theo, đặt ít nhất một câu hỏi, dù nhỏ.', false),
  ('pt-c2-3', 'pt-c2', 3, 'Chuyển hóa — Chia sẻ một quan điểm', 'Chủ động chia sẻ một góc nhìn của riêng bạn, không chỉ trả lời khi được hỏi.', true)
on conflict (step_id) do update set
  title = excluded.title, content = excluded.content, is_premium = excluded.is_premium;

-- C3 · Connection — Phản hồi thật, không chỉ lịch sự
insert into public.wr_practice_themes (theme_id, title, sca_dimension, description)
values ('pt-c3', 'Phản hồi thật, không chỉ lịch sự', 'C3', null)
on conflict (theme_id) do update set title = excluded.title, sca_dimension = excluded.sca_dimension;

insert into public.wr_practice_steps (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-c3-1', 'pt-c3', 1, 'Nhận diện — Chú ý một lần giữ im lặng thay vì góp ý', 'Nhận ra một lần gần đây bạn đồng ý ngoài mặt nhưng không thực sự đồng ý.', false),
  ('pt-c3-2', 'pt-c3', 2, 'Thử nghiệm — Chia sẻ 1 phản hồi thẳng thắn', 'Chia sẻ một phản hồi thẳng thắn, có chuẩn bị, với một người bạn tin tưởng.', false),
  ('pt-c3-3', 'pt-c3', 3, 'Chuyển hóa — Xây thói quen phản hồi', 'Đưa phản hồi trở thành nhịp thường xuyên trong đội, không chỉ khi có vấn đề.', true)
on conflict (step_id) do update set
  title = excluded.title, content = excluded.content, is_premium = excluded.is_premium;

-- A1 · Adaptability — Nhìn rõ mình đang đi đâu
insert into public.wr_practice_themes (theme_id, title, sca_dimension, description)
values ('pt-a1', 'Nhìn rõ mình đang đi đâu', 'A1', null)
on conflict (theme_id) do update set title = excluded.title, sca_dimension = excluded.sca_dimension;

insert into public.wr_practice_steps (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-a1-1', 'pt-a1', 1, 'Nhận diện — Viết một câu trả lời cho câu hỏi lớn', 'Viết một câu ngắn trả lời: công việc này đang dẫn mình tới đâu.', false),
  ('pt-a1-2', 'pt-a1', 2, 'Thử nghiệm — Kết nối việc đang làm với mục tiêu lớn hơn', 'Chọn một việc đang làm, viết ra nó phục vụ mục tiêu lớn hơn nào của bạn.', false),
  ('pt-a1-3', 'pt-a1', 3, 'Chuyển hóa — Tự hỏi lại mục tiêu định kỳ', 'Đặt một nhịp định kỳ để tự hỏi lại mục tiêu, thay vì làm theo quán tính.', true)
on conflict (step_id) do update set
  title = excluded.title, content = excluded.content, is_premium = excluded.is_premium;

-- A2 · Adaptability — Giữ năng lượng đường dài
insert into public.wr_practice_themes (theme_id, title, sca_dimension, description)
values ('pt-a2', 'Giữ năng lượng đường dài', 'A2', null)
on conflict (theme_id) do update set title = excluded.title, sca_dimension = excluded.sca_dimension;

insert into public.wr_practice_steps (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-a2-1', 'pt-a2', 1, 'Nhận diện — Ghi lại thời điểm cạn năng lượng nhất', 'Chú ý thời điểm trong tuần bạn thấy cạn năng lượng nhất, và điều gì dẫn tới đó.', false),
  ('pt-a2-2', 'pt-a2', 2, 'Thử nghiệm — Bỏ hoặc dời một việc không cấp thiết', 'Chọn một việc không thực sự cấp thiết, thử bỏ hoặc dời lại.', false),
  ('pt-a2-3', 'pt-a2', 3, 'Chuyển hóa — Xây nhịp nghỉ cố định', 'Đặt một nhịp nghỉ cố định, không đợi đến khi kiệt sức mới nghỉ.', true)
on conflict (step_id) do update set
  title = excluded.title, content = excluded.content, is_premium = excluded.is_premium;

-- A3 · Adaptability — Thoát khỏi vòng lặp phản ứng
insert into public.wr_practice_themes (theme_id, title, sca_dimension, description)
values ('pt-a3', 'Thoát khỏi vòng lặp phản ứng', 'A3', null)
on conflict (theme_id) do update set title = excluded.title, sca_dimension = excluded.sca_dimension;

insert into public.wr_practice_steps (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-a3-1', 'pt-a3', 1, 'Nhận diện — Ghi lại một lần phản ứng mạnh hơn cần thiết', 'Chú ý một tình huống bạn phản ứng mạnh hơn mức cần thiết.', false),
  ('pt-a3-2', 'pt-a3', 2, 'Thử nghiệm — Dừng lại một nhịp trước khi phản hồi', 'Trước khi phản hồi, cho mình một nhịp thở hoặc đếm đến 10.', false),
  ('pt-a3-3', 'pt-a3', 3, 'Chuyển hóa — Nhận ra sớm dấu hiệu phản ứng', 'Học cách nhận ra sớm dấu hiệu của phản ứng, trước khi đã lỡ nói ra.', true)
on conflict (step_id) do update set
  title = excluded.title, content = excluded.content, is_premium = excluded.is_premium;

-- A4 · Adaptability — Không lặp lại cùng một bài học
insert into public.wr_practice_themes (theme_id, title, sca_dimension, description)
values ('pt-a4', 'Không lặp lại cùng một bài học', 'A4', null)
on conflict (theme_id) do update set title = excluded.title, sca_dimension = excluded.sca_dimension;

insert into public.wr_practice_steps (step_id, theme_id, step_order, title, content, is_premium)
values
  ('pt-a4-1', 'pt-a4', 1, 'Nhận diện — Ghi lại một sai lầm lặp lại', 'Viết ra một sai lầm cũ, và một sai lầm gần đây khá giống vậy.', false),
  ('pt-a4-2', 'pt-a4', 2, 'Thử nghiệm — Ghi chú điều sẽ làm khác đi ngay sau sai lầm', 'Ngay sau một sai lầm, ghi chú cụ thể điều sẽ làm khác đi lần sau.', false),
  ('pt-a4-3', 'pt-a4', 3, 'Chuyển hóa — Xây nhịp nhìn lại định kỳ', 'Đặt một nhịp nhìn lại định kỳ (retro cá nhân), để việc học không chỉ là tình cờ.', true)
on conflict (step_id) do update set
  title = excluded.title, content = excluded.content, is_premium = excluded.is_premium;

-- ============================================================
-- 3. Ngưng đề xuất hai chủ đề cũ
-- ============================================================

update public.wr_practice_themes
   set retired_at = now()
 where theme_id in ('pt-voice', 'pt-rhythm')
   and retired_at is null;
