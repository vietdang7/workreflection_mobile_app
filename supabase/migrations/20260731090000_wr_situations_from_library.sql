-- Gộp Situation về MỘT thực thể — Kiến trúc Dữ liệu v2.0 §2.2.
--
-- Vấn đề đang chữa: chip tình huống và nội dung Story nằm ở hai không gian mã
-- TÁCH RỜI (`<DIM>-sit-NN` với `<DIM>-NN`), nối nhau bằng một phép băm trong
-- `resolveStoryFor`:
--
--     index = situation.code.hashCode.abs() % sameDimension.length
--
-- Nên câu chuyện người dùng đọc ở bước Meaning và câu Aha ở bước Insight
-- THƯỜNG KHÔNG nói về tình huống họ vừa chạm. Chạm "Không dám lên tiếng"
-- (C2-sit-01) có thể đọc phải "Bạn luôn là người cuối cùng phát biểu" (C2-09).
-- Chỉ 10 tình huống tích cực P-01..P-10 là trùng mã nên khớp đúng.
--
-- Thêm nữa: thư viện có 100 nội dung (10 mỗi chiều) nhưng chỉ 60 chip, nên 40
-- nội dung không bao giờ có đường tới người dùng.
--
-- Cách chữa: dùng chính 100 mục của Career Situation Library LÀM chip, mã trùng
-- với `wr_stories.story_id`. Từ đây nhánh khớp-mã-tuyệt-đối của
-- `resolveStoryFor` luôn trúng, và mỗi chip có Story/Reflection/Aha/Practice
-- của riêng nó.
--
-- 60 chip cũ `<DIM>-sit-NN` KHÔNG bị xoá — chúng vẫn được `wr_reflection_episodes`,
-- `wr_pattern_counts` và `wr_career_memory_events` tham chiếu, xoá là làm hỏng
-- nhãn của toàn bộ lịch sử người dùng đã có. Chúng chỉ bị đánh dấu ngưng đề
-- xuất bằng `retired_at`, đúng quy ước đã dùng cho `wr_practice_themes`.
--
-- Nhãn chip lấy nguyên tiêu đề thư viện, đổi sang ngôi thứ nhất "tôi" theo §9.2
-- (chín tiêu đề C2 trong nguồn gốc viết "bạn").
--
-- Additive & idempotent.

alter table public.wr_situations
  add column if not exists retired_at timestamptz;

comment on column public.wr_situations.retired_at is
  'Khác null = ngưng đề xuất cho phiên mới. KHÔNG xoá dòng: lịch sử Episode và '
  'Career Memory còn tham chiếu mã này để dựng nhãn.';

insert into public.wr_situations
  (code, text, sca_dimension, human_need, wave)
values
  ('A1-01', 'Tôi đang đi rất nhanh, nhưng đi đâu?', 'A1', 'phat_trien', 1),
  ('A1-02', 'Tôi muốn nghỉ việc, nhưng không biết muốn điều gì khác', 'A1', 'phat_trien', 1),
  ('A1-03', 'Tôi làm rất nhiều nhưng không thấy ý nghĩa', 'A1', 'phat_trien', 1),
  ('A1-04', 'Thành công của tôi có còn là điều tôi muốn?', 'A1', 'phat_trien', 1),
  ('A1-05', 'Tôi không biết điều gì thực sự quan trọng với mình', 'A1', 'phat_trien', 1),
  ('A1-06', 'Tôi đang phát triển hay chỉ đang bận?', 'A1', 'phat_trien', 1),
  ('A1-07', 'Tôi không còn thấy mình thuộc về nơi này', 'A1', 'phat_trien', 1),
  ('A1-08', 'Tôi muốn nhiều hơn, nhưng không biết là gì', 'A1', 'phat_trien', 1),
  ('A1-09', 'Tôi đang sống theo định nghĩa thành công của ai?', 'A1', 'phat_trien', 1),
  ('A1-10', 'Nếu tiếp tục như thế này thêm 3 năm nữa thì sao?', 'A1', 'phat_trien', 1),
  ('A2-01', 'Tôi biết phải làm gì nhưng vẫn chưa làm', 'A2', 'thich_nghi', 2),
  ('A2-02', 'Tôi có quá nhiều kế hoạch', 'A2', 'thich_nghi', 2),
  ('A2-03', 'Tôi bắt đầu rất tốt nhưng không duy trì được', 'A2', 'thich_nghi', 2),
  ('A2-04', 'Tôi luôn bận nhưng không hoàn thành điều quan trọng', 'A2', 'thich_nghi', 2),
  ('A2-05', 'Tôi liên tục thay đổi hướng đi', 'A2', 'thich_nghi', 2),
  ('A2-06', 'Tôi chờ đến khi sẵn sàng', 'A2', 'thich_nghi', 2),
  ('A2-07', 'Tôi có quá nhiều việc dang dở', 'A2', 'thich_nghi', 2),
  ('A2-08', 'Tôi không thấy kết quả nên muốn bỏ cuộc', 'A2', 'thich_nghi', 2),
  ('A2-09', 'Tôi liên tục bị kéo khỏi điều quan trọng', 'A2', 'thich_nghi', 2),
  ('A2-10', 'Điều gì giúp tôi thực sự hành động?', 'A2', 'thich_nghi', 2),
  ('A3-01', 'Chuyện này sao lại xảy ra lần nữa?', 'A3', 'thich_nghi', 1),
  ('A3-02', 'Tôi biết mình mệt nhưng không biết vì sao', 'A3', 'thich_nghi', 1),
  ('A3-03', 'Tôi phản ứng mạnh hơn mức cần thiết', 'A3', 'thich_nghi', 1),
  ('A3-04', 'Tôi luôn bận nhưng không thấy tiến bộ', 'A3', 'thich_nghi', 1),
  ('A3-05', 'Tôi cứ ra quyết định theo cảm xúc', 'A3', 'thich_nghi', 1),
  ('A3-06', 'Tôi không còn nhớ mình đã học được gì', 'A3', 'thich_nghi', 1),
  ('A3-07', 'Tôi cảm thấy bị mắc kẹt', 'A3', 'thich_nghi', 1),
  ('A3-08', 'Tôi luôn nghĩ mình phải làm tốt hơn', 'A3', 'thich_nghi', 1),
  ('A3-09', 'Tôi đang tránh nhìn vào điều gì?', 'A3', 'thich_nghi', 1),
  ('A3-10', 'Nếu dừng lại 10 phút để nhìn lại thì sao?', 'A3', 'thich_nghi', 1),
  ('A4-01', 'Tôi cứ mắc lại cùng một lỗi', 'A4', 'phat_trien', 2),
  ('A4-02', 'Tôi đã vượt qua chuyện đó như thế nào?', 'A4', 'phat_trien', 2),
  ('A4-03', 'Tôi học được gì từ thất bại này?', 'A4', 'phat_trien', 2),
  ('A4-04', 'Tôi đang phát triển theo cách nào?', 'A4', 'phat_trien', 2),
  ('A4-05', 'Tôi đã bỏ lỡ tín hiệu nào?', 'A4', 'phat_trien', 2),
  ('A4-06', 'Tôi đang học hay chỉ đang trải nghiệm?', 'A4', 'phat_trien', 2),
  ('A4-07', 'Tôi có đang lặp lại điều hiệu quả?', 'A4', 'phat_trien', 2),
  ('A4-08', 'Điều này đang dạy tôi điều gì về bản thân?', 'A4', 'phat_trien', 2),
  ('A4-09', 'Tôi đã thay đổi quyết định như thế nào?', 'A4', 'phat_trien', 2),
  ('A4-10', 'Nếu nhìn lại năm nay như một chương sách', 'A4', 'phat_trien', 2),
  ('C1-01', 'Tôi lại phải làm thay', 'C1', 'ket_noi', 1),
  ('C1-02', 'Tôi luôn phải kiểm tra lại', 'C1', 'ket_noi', 1),
  ('C1-03', 'Người ta nói một đằng làm một nẻo', 'C1', 'ket_noi', 1),
  ('C1-04', 'Tôi không biết có thể nhờ ai', 'C1', 'ket_noi', 1),
  ('C1-05', 'Tôi giữ lại vì sợ bị thất vọng', 'C1', 'ket_noi', 1),
  ('C1-06', 'Tôi không chắc cấp trên có giữ lời', 'C1', 'ket_noi', 1),
  ('C1-07', 'Tôi ngại nhờ giúp đỡ', 'C1', 'ket_noi', 1),
  ('C1-08', 'Tôi không biết người khác đang nghĩ gì', 'C1', 'ket_noi', 1),
  ('C1-09', 'Tôi từng tin, nhưng giờ không còn nữa', 'C1', 'ket_noi', 1),
  ('C1-10', 'Tôi cảm thấy an tâm khi làm việc cùng họ', 'C1', 'ket_noi', 1),
  ('C2-01', 'Ý tưởng của tôi biến mất trong cuộc họp', 'C2', 'ket_noi', 1),
  ('C2-02', 'Cuộc họp kết thúc nhưng điều quan trọng nhất vẫn chưa được nói ra', 'C2', 'ket_noi', 1),
  ('C2-03', 'Tôi đồng ý dù trong lòng không đồng ý', 'C2', 'ket_noi', 1),
  ('C2-04', 'Tôi bị ngắt lời giữa chừng', 'C2', 'ket_noi', 1),
  ('C2-05', 'Tôi muốn góp ý nhưng sợ làm mất lòng', 'C2', 'ket_noi', 1),
  ('C2-06', 'Tôi nhận lỗi thay vì giải thích', 'C2', 'ket_noi', 1),
  ('C2-07', 'Tôi có câu hỏi nhưng không hỏi', 'C2', 'ket_noi', 1),
  ('C2-08', 'Tôi được mời góp ý nhưng không tin rằng điều đó tạo ra thay đổi', 'C2', 'ket_noi', 1),
  ('C2-09', 'Tôi luôn là người cuối cùng phát biểu', 'C2', 'ket_noi', 1),
  ('C2-10', 'Tôi đã từng rất tích cực, nhưng bây giờ không còn nữa', 'C2', 'ket_noi', 1),
  ('C3-01', 'Tôi biết có vấn đề nhưng không muốn nói', 'C3', 'ket_noi', 3),
  ('C3-02', 'Mỗi lần góp ý đều trở thành tranh cãi', 'C3', 'ket_noi', 3),
  ('C3-03', 'Chúng tôi chỉ nói về công việc, không nói về vấn đề', 'C3', 'ket_noi', 3),
  ('C3-04', 'Tôi không cảm thấy mình được hiểu', 'C3', 'ket_noi', 3),
  ('C3-05', 'Chúng tôi luôn hiểu khác nhau về cùng một việc', 'C3', 'ket_noi', 3),
  ('C3-06', 'Tôi sợ làm người khác khó chịu', 'C3', 'ket_noi', 3),
  ('C3-07', 'Cuộc họp kết thúc nhưng vấn đề vẫn còn', 'C3', 'ket_noi', 3),
  ('C3-08', 'Tôi luôn phải đoán ý người khác', 'C3', 'ket_noi', 3),
  ('C3-09', 'Chúng tôi nói chuyện nhưng không kết nối', 'C3', 'ket_noi', 3),
  ('C3-10', 'Cuộc trò chuyện nào đang cần diễn ra?', 'C3', 'ket_noi', 3),
  ('S1-01', 'Tôi không biết thế nào mới là làm tốt', 'S1', 'ro_rang', 2),
  ('S1-02', 'Việc gì cũng đến tay tôi', 'S1', 'ro_rang', 2),
  ('S1-03', 'Tôi không biết ưu tiên điều gì', 'S1', 'ro_rang', 2),
  ('S1-04', 'Tôi luôn cảm thấy mình chưa đủ tốt', 'S1', 'ro_rang', 2),
  ('S1-05', 'Tôi nhận được những chỉ đạo trái ngược nhau', 'S1', 'ro_rang', 2),
  ('S1-06', 'Tôi không hiểu tại sao mình phải làm việc này', 'S1', 'ro_rang', 2),
  ('S1-07', 'Tôi không biết mình có quyền quyết định đến đâu', 'S1', 'ro_rang', 2),
  ('S1-08', 'Vai trò của tôi đang thay đổi', 'S1', 'ro_rang', 2),
  ('S1-09', 'Tôi không biết điều gì là đủ', 'S1', 'ro_rang', 2),
  ('S1-10', 'Tôi thực sự được thuê để làm gì?', 'S1', 'ro_rang', 2),
  ('S2-01', 'Tôi không biết nên tìm ai để giải quyết việc này', 'S2', 'ro_rang', 3),
  ('S2-02', 'Tôi luôn phải chờ người khác', 'S2', 'ro_rang', 3),
  ('S2-03', 'Chúng tôi làm cùng một việc mà không biết', 'S2', 'ro_rang', 3),
  ('S2-04', 'Việc bị đẩy qua đẩy lại', 'S2', 'ro_rang', 3),
  ('S2-05', 'Chúng tôi hiểu khác nhau về cùng một mục tiêu', 'S2', 'ro_rang', 3),
  ('S2-06', 'Tôi luôn phải nhắc lại nhiều lần', 'S2', 'ro_rang', 3),
  ('S2-07', 'Tôi không hiểu công việc của người khác', 'S2', 'ro_rang', 3),
  ('S2-08', 'Mỗi lần phối hợp đều rất mệt', 'S2', 'ro_rang', 3),
  ('S2-09', 'Chúng tôi phụ thuộc quá nhiều vào một người', 'S2', 'ro_rang', 3),
  ('S2-10', 'Điều gì giúp chúng tôi phối hợp tốt nhất?', 'S2', 'ro_rang', 3),
  ('S3-01', 'Tôi không biết tìm thông tin ở đâu', 'S3', 'ro_rang', 3),
  ('S3-02', 'Tôi phát hiện thông tin quá muộn', 'S3', 'ro_rang', 3),
  ('S3-03', 'Mỗi người nói một kiểu', 'S3', 'ro_rang', 3),
  ('S3-04', 'Tôi không biết thông tin nào là mới nhất', 'S3', 'ro_rang', 3),
  ('S3-05', 'Tôi phải hỏi cùng một câu hỏi nhiều lần', 'S3', 'ro_rang', 3),
  ('S3-06', 'Tôi bị ngập trong quá nhiều thông tin', 'S3', 'ro_rang', 3),
  ('S3-07', 'Có những thứ chỉ một vài người biết', 'S3', 'ro_rang', 3),
  ('S3-08', 'Tôi không hiểu bức tranh toàn cảnh', 'S3', 'ro_rang', 3),
  ('S3-09', 'Tôi không biết điều gì đã thay đổi', 'S3', 'ro_rang', 3),
  ('S3-10', 'Điều gì giúp tôi luôn có đủ thông tin?', 'S3', 'ro_rang', 3)
on conflict (code) do update set
  text          = excluded.text,
  sca_dimension = excluded.sca_dimension,
  human_need    = excluded.human_need,
  wave          = excluded.wave,
  retired_at    = null;

-- Ngưng đề xuất 60 chip Tầng 1. Chúng trùng nghĩa với 60 trong 100 mục trên,
-- chỉ khác cách diễn đạt, nên để cả hai cùng vào bể là bày ra hai phiên bản của
-- cùng một tình huống và làm loãng số đếm "Tình huống lặp lại".
update public.wr_situations
   set retired_at = coalesce(retired_at, now())
 where code like '%-sit-%';
