-- 20260804170000_wr_practice_theme_copy.sql
--
-- Hai việc dọn nội dung chủ đề thực hành, sau khi xuất toàn bộ thư viện ra soát
-- (04/08/2026):
--
--   1. Ngưng đề xuất `pt-feedback`. Nó cùng chiều C3 với `pt-c3` và cùng một
--      hướng nội dung, nhưng khác TÊN nên phần mềm không gộp được — mà nó lại
--      chưa bị đánh `retired_at` như hai chủ đề đời đầu kia, nên cả hai vẫn
--      được mời cho người mới. Đây là chỗ bị bỏ sót ở migration 31/07, không
--      phải chủ ý.
--
--      Giữ `pt-c3` chứ không giữ `pt-feedback`: `pt-c3` thuộc bộ 10 chuẩn theo
--      chiều SCA, và tên bước của nó nói rõ phải làm gì ("Nhận diện — Chú ý một
--      lần giữ im lặng thay vì góp ý") thay vì trống trơn ("Nhận diện").
--
--      KHÔNG xoá hàng, KHÔNG dời ghi danh: ai đang theo vẫn đi tiếp bình
--      thường. Dời ghi danh sang `pt-c3` sẽ làm mất tiến độ, vì bộ đếm thực
--      hành nhận sự kiện theo TÊN chủ đề — đổi tên là mất luôn số lần đã đếm.
--
--   2. Thêm mô tả cho 10 chủ đề bộ chuẩn. Cả 10 đang để trống `description`,
--      nên màn chủ đề mở ra là vào thẳng ba bước, không có một câu nói chủ đề
--      này giúp gì. Ba chủ đề đời cũ thì lại có. Mỗi câu dưới đây viết theo
--      đúng giọng của bộ 10: nói cái người dùng sẽ làm được, không hứa hẹn kết
--      quả, không dùng chữ chuyên môn.

-- ============================================================
-- 1. Ngưng đề xuất chủ đề trùng chiều C3
-- ============================================================

update public.wr_practice_themes
   set retired_at = now()
 where theme_id = 'pt-feedback'
   and retired_at is null;

-- ============================================================
-- 2. Mô tả cho bộ 10 chủ đề
-- ============================================================

update public.wr_practice_themes set description =
  'Biết rõ người khác đang mong đợi gì ở mình, bằng cách hỏi trước khi bắt tay vào việc thay vì đoán rồi làm lại.'
 where theme_id = 'pt-s1';

update public.wr_practice_themes set description =
  'Nhận ra việc nào thực sự thuộc về mình, để thôi ôm những việc lẽ ra không cần mình quyết định.'
 where theme_id = 'pt-s2';

update public.wr_practice_themes set description =
  'Giữ được sự vững vàng khi kế hoạch đổi giữa chừng, bằng cách hỏi cho rõ lý do thay vì tự suy diễn.'
 where theme_id = 'pt-s3';

update public.wr_practice_themes set description =
  'Trao niềm tin trọn vẹn cho người mình đã giao việc, và nhận lại được điều tương tự.'
 where theme_id = 'pt-c1';

update public.wr_practice_themes set description =
  'Nói ra điều mình nghĩ đúng lúc, bắt đầu từ những câu nhỏ nhất, cho tới khi lên tiếng thành chuyện bình thường.'
 where theme_id = 'pt-c2';

update public.wr_practice_themes set description =
  'Nói thật điều mình nghĩ theo cách người nghe nhận được, thay vì gật đầu cho xong rồi giữ trong lòng.'
 where theme_id = 'pt-c3';

update public.wr_practice_themes set description =
  'Nhìn rõ công việc hằng ngày đang dẫn mình tới đâu, để không làm theo quán tính.'
 where theme_id = 'pt-a1';

update public.wr_practice_themes set description =
  'Giữ sức cho chặng dài: nghỉ theo nhịp đã định, không đợi tới lúc cạn kiệt mới dừng.'
 where theme_id = 'pt-a2';

update public.wr_practice_themes set description =
  'Nhận ra sớm lúc mình sắp phản ứng mạnh hơn cần thiết, và cho mình một nhịp trước khi lên tiếng.'
 where theme_id = 'pt-a3';

update public.wr_practice_themes set description =
  'Biến sai lầm thành bài học có ghi lại, để lần sau không vấp đúng chỗ cũ.'
 where theme_id = 'pt-a4';
