// `insightGist` — ý chính của câu Insight đã giữ, dùng để nhắc lại ở Home và
// thẻ "Điều bạn từng viết" (chạy thử bản web 06/10: chép nguyên câu mẫu hai
// đoạn vào giữa câu "bạn nhận ra: …" đọc lủng củng).
//
// Run: flutter test test/core/logic/wr_insight_gist_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_reflect_v47.dart';

void main() {
  tearDown(() => wrEnglish = false);

  test('câu mẫu của app: chỉ giữ phần aha', () {
    final full = reflectionAhaFor(
      code: 'C2-06',
      title: 'Tôi nhận lỗi thay vì giải thích',
      situationAha:
          'Khi con người sợ bị phán xét, họ thường chọn bảo vệ '
          'hình ảnh hơn là chia sẻ sự thật.',
    );
    expect(full, contains('\n\n'));
    expect(
      insightGist(full),
      'Khi con người sợ bị phán xét, họ thường chọn bảo vệ hình ảnh hơn là '
      'chia sẻ sự thật.',
    );
  });

  test('bản tiếng Anh của câu mẫu cũng tách được', () {
    wrEnglish = true;
    final full = reflectionAhaFor(
      code: 'C2-06',
      title: 'I took the blame instead of explaining',
      situationAha: 'When people fear judgement, they protect the image.',
    );
    expect(
      insightGist(full),
      'When people fear judgement, they protect the image.',
    );
  });

  test('câu người dùng tự viết giữ nguyên, chỉ gộp xuống dòng', () {
    expect(
      insightGist('  Với tôi, điều này xảy ra\nvì tôi ngại nói.  '),
      'Với tôi, điều này xảy ra vì tôi ngại nói.',
    );
  });
}
