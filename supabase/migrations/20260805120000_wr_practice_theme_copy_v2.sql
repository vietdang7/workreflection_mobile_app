-- 20260805120000_wr_practice_theme_copy_v2.sql
--
-- "Thói quen và Ma trận Cấp bậc v1.0", Phần A mục 2 — mười mô tả đầy đủ.
--
-- Hai việc:
--   1. Thêm cột `formed_line`: câu hiện ở màn ăn mừng khi chủ đề chạm ngưỡng.
--      Trước đây màn ăn mừng chỉ có đúng một câu chung cho cả thư viện ("Bạn đã
--      thực hành điều này N lần"), nên khoảnh khắc đáng nhớ nhất của tính năng
--      lại là chỗ duy nhất không nói gì riêng về chính điều người dùng vừa làm
--      được.
--   2. Viết lại `description` của bộ 10 theo đúng bảng A.2. Bản 04/08 mô tả
--      chủ đề theo kiểu định nghĩa ("Biết rõ người khác đang mong đợi gì...");
--      bản này mở bằng một quan sát chung dễ nhận ra bản thân trong đó, rồi mới
--      nối sang cơ chế thực hành. Giọng là thứ đổi, không phải nội dung.
--
-- Ba chủ đề đời đầu (`pt-voice`, `pt-rhythm`, `pt-feedback`) KHÔNG đụng tới:
-- chúng đã ngưng đề xuất, chỉ còn người ghi danh từ trước đang đi tiếp, và tài
-- liệu chỉ viết cho bộ 10.

alter table public.wr_practice_themes
  add column if not exists formed_line text;

comment on column public.wr_practice_themes.formed_line is
  'Câu hiện ở màn ăn mừng khi chủ đề chạm ngưỡng thực hành. Thì hiện tại, '
  'ngắn, không lặp chữ "kỹ năng" hay "ngưỡng" — chỉ nói điều đã đổi (bảng A.2).';

-- ============================================================
-- Bộ 10: mô tả mở đầu + câu khi đạt ngưỡng
-- ============================================================

update public.wr_practice_themes set
  description =
    'Nhiều căng thẳng không đến từ việc khó, mà từ việc không chắc mình đang '
    'được kỳ vọng điều gì. Thực hành này giúp bạn tập thói quen hỏi rõ trước '
    'khi bắt đầu, thay vì đoán và lo.',
  formed_line = 'Bạn không còn phải đoán, bạn hỏi.'
 where theme_id = 'pt-s1';

update public.wr_practice_themes set
  description =
    'Ôm quá nhiều việc không thuộc về mình là cách nhanh nhất để đánh mất năng '
    'lượng cho điều thực sự quan trọng. Từng bước nhỏ ở đây giúp bạn nhận ra '
    'ranh giới của mình rõ hơn.',
  formed_line = 'Bạn biết việc nào là của mình, và việc nào không.'
 where theme_id = 'pt-s2';

update public.wr_practice_themes set
  description =
    'Thay đổi không đáng sợ bằng cảm giác bị bỏ lại phía sau, không biết chuyện '
    'gì đang xảy ra. Thực hành này giúp bạn quen với việc chủ động hỏi, thay vì '
    'chờ đợi trong mơ hồ.',
  formed_line = 'Thay đổi không còn khiến bạn hụt hẫng như trước.'
 where theme_id = 'pt-s3';

update public.wr_practice_themes set
  description =
    'Niềm tin được xây từ việc dám buông, không phải từ việc kiểm soát chặt '
    'hơn. Mỗi lần thực hành, bạn đang tập một phản xạ mới thay cho thói quen '
    'kiểm tra lại.',
  formed_line = 'Bạn tin, và để người khác tự chứng minh mình xứng đáng.'
 where theme_id = 'pt-c1';

update public.wr_practice_themes set
  description =
    'Có bao nhiêu lần bạn có ý kiến, nhưng chọn im lặng vì ngại? Thực hành này '
    'không đòi bạn phải mạnh dạn ngay, chỉ cần bắt đầu từ những lần nhỏ.',
  formed_line = 'Im lặng không còn là lựa chọn mặc định của bạn nữa.'
 where theme_id = 'pt-c2';

update public.wr_practice_themes set
  description =
    'Sự lịch sự đôi khi là cách né tránh những điều cần được nói ra. Lặp lại '
    'việc phản hồi thẳng thắn, dù nhỏ, sẽ dần khiến nó bớt đáng sợ hơn.',
  formed_line = 'Bạn chọn nói thật, thay vì chỉ nói cho lịch sự.'
 where theme_id = 'pt-c3';

update public.wr_practice_themes set
  description =
    'Bận rộn không đồng nghĩa với việc đang đi đúng hướng. Thực hành này giúp '
    'bạn tập thói quen dừng lại và tự hỏi, thay vì chỉ cắm đầu làm tiếp.',
  formed_line = 'Bạn luôn biết mình đang đi về đâu, ngay cả khi bận rộn.'
 where theme_id = 'pt-a1';

update public.wr_practice_themes set
  description =
    'Làm việc bền không phải là cố hết sức mỗi ngày, mà là biết khi nào cần '
    'dừng lại. Mỗi lần thực hành là một lần bạn tập lắng nghe giới hạn của '
    'chính mình.',
  formed_line = 'Bạn biết dừng lại trước khi kiệt sức, không phải sau đó.'
 where theme_id = 'pt-a2';

update public.wr_practice_themes set
  description =
    'Đôi khi phản ứng của mình lớn hơn nhiều so với chuyện vừa xảy ra. Thực '
    'hành này giúp bạn tạo một khoảng dừng nhỏ, trước khi phản ứng đó kịp bùng '
    'lên.',
  formed_line = 'Bạn có một khoảng dừng, trước khi phản ứng kịp bùng lên.'
 where theme_id = 'pt-a3';

update public.wr_practice_themes set
  description =
    'Sai một lần là bài học. Sai lại vì cùng lý do, là một mẫu hình đáng nhìn '
    'kỹ hơn. Thực hành này giúp bạn xây thói quen nhìn lại, để bài học thật sự '
    'được giữ lại.',
  formed_line = 'Bài học giờ đã thật sự ở lại với bạn.'
 where theme_id = 'pt-a4';
