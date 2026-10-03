// Bộ 10 chủ đề thực hành đang dùng thật (tên + chiều + mô tả mở đầu), chép từ
// `20260731000000_wr_practice_themes_by_dimension.sql` và
// `20260805120000_wr_practice_theme_copy_v2.sql`.
//
// Dùng cho các test cần thư viện chủ đề giống thật, thay vì mỗi file tự dựng
// vài chủ đề tên "Chủ đề A".

import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

final List<PracticeTheme> kTestThemes = [
  const PracticeTheme(
    themeId: 'pt-s1',
    title: 'Rõ ràng về điều được kỳ vọng',
    scaDimension: ScaDimension.s1,
    description:
        'Nhiều căng thẳng không đến từ việc khó, mà từ việc không chắc mình '
        'đang được kỳ vọng điều gì. Thực hành này giúp bạn tập thói quen hỏi '
        'rõ trước khi bắt đầu, thay vì đoán và lo.',
  ),
  const PracticeTheme(
    themeId: 'pt-s2',
    title: 'Ưu tiên đúng việc của mình',
    scaDimension: ScaDimension.s2,
    description:
        'Ôm quá nhiều việc không thuộc về mình là cách nhanh nhất để đánh mất '
        'năng lượng cho điều thực sự quan trọng. Từng bước nhỏ ở đây giúp bạn '
        'nhận ra ranh giới của mình rõ hơn.',
  ),
  const PracticeTheme(
    themeId: 'pt-s3',
    title: 'Vững vàng khi mọi thứ thay đổi',
    scaDimension: ScaDimension.s3,
    description:
        'Thay đổi không đáng sợ bằng cảm giác bị bỏ lại phía sau, không biết '
        'chuyện gì đang xảy ra. Thực hành này giúp bạn quen với việc chủ động '
        'hỏi, thay vì chờ đợi trong mơ hồ.',
  ),
  const PracticeTheme(
    themeId: 'pt-c1',
    title: 'Tin và được tin',
    scaDimension: ScaDimension.c1,
    description:
        'Niềm tin được xây từ việc dám buông, không phải từ việc kiểm soát chặt '
        'hơn. Mỗi lần thực hành, bạn đang tập một phản xạ mới thay cho thói '
        'quen kiểm tra lại.',
  ),
  const PracticeTheme(
    themeId: 'pt-c2',
    title: 'Dám lên tiếng',
    scaDimension: ScaDimension.c2,
    description:
        'Có bao nhiêu lần bạn có ý kiến, nhưng chọn im lặng vì ngại? Thực hành '
        'này không đòi bạn phải mạnh dạn ngay, chỉ cần bắt đầu từ những lần '
        'nhỏ.',
  ),
  const PracticeTheme(
    themeId: 'pt-c3',
    title: 'Phản hồi thật, không chỉ lịch sự',
    scaDimension: ScaDimension.c3,
    description:
        'Sự lịch sự đôi khi là cách né tránh những điều cần được nói ra. Lặp '
        'lại việc phản hồi thẳng thắn, dù nhỏ, sẽ dần khiến nó bớt đáng sợ hơn.',
  ),
  const PracticeTheme(
    themeId: 'pt-a1',
    title: 'Nhìn rõ mình đang đi đâu',
    scaDimension: ScaDimension.a1,
    description:
        'Bận rộn không đồng nghĩa với việc đang đi đúng hướng. Thực hành này '
        'giúp bạn tập thói quen dừng lại và tự hỏi, thay vì chỉ cắm đầu làm '
        'tiếp.',
  ),
  const PracticeTheme(
    themeId: 'pt-a2',
    title: 'Giữ năng lượng đường dài',
    scaDimension: ScaDimension.a2,
    description:
        'Làm việc bền không phải là cố hết sức mỗi ngày, mà là biết khi nào cần '
        'dừng lại. Mỗi lần thực hành là một lần bạn tập lắng nghe giới hạn của '
        'chính mình.',
  ),
  const PracticeTheme(
    themeId: 'pt-a3',
    title: 'Thoát khỏi vòng lặp phản ứng',
    scaDimension: ScaDimension.a3,
    description:
        'Đôi khi phản ứng của mình lớn hơn nhiều so với chuyện vừa xảy ra. Thực '
        'hành này giúp bạn tạo một khoảng dừng nhỏ, trước khi phản ứng đó kịp '
        'bùng lên.',
  ),
  const PracticeTheme(
    themeId: 'pt-a4',
    title: 'Không lặp lại cùng một bài học',
    scaDimension: ScaDimension.a4,
    description:
        'Sai một lần là bài học. Sai lại vì cùng lý do, là một mẫu hình đáng '
        'nhìn kỹ hơn. Thực hành này giúp bạn xây thói quen nhìn lại, để bài học '
        'thật sự được giữ lại.',
  ),
];
