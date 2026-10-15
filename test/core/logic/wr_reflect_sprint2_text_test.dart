// Câu chữ luồng Reflect theo script Sprint 2 (dòng 1308, 1444, 1499-1607).
//
// Run: flutter test test/core/logic/wr_reflect_sprint2_text_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_reflect_v47.dart';

void main() {
  setUp(() => wrEnglish = false);
  tearDown(() => wrEnglish = false);

  test('nhãn bốn bước nguyên văn script', () {
    expect(reflectStepEyebrow(0), 'Bước 1/4 · Tình huống giống bạn');
    expect(reflectStepEyebrow(1), 'Bước 2/4 · Khoảnh khắc cụ thể');
    expect(reflectStepEyebrow(2), 'Bước 3/4 · Nhìn lại sâu hơn');
    expect(reflectStepEyebrow(3), 'Bước 4/4 · Thử lại lần tới');
  });

  test(
    'aha của "Điều khác" theo khuôn chung với title và aha của mục other',
    () {
      expect(
        reflectionAhaFor(detail: 'bất kỳ'),
        'Điều bạn vừa kể có thể không chỉ là “Điều khác, để tôi tự mô tả”.\n\n'
        'Có thể phần đáng nhìn thêm là: Dừng lại để gọi tên một trải nghiệm cụ '
        'thể đã là bước phản chiếu quan trọng nhất, dù tôi chưa chắc chắn về ý '
        'nghĩa của nó.',
      );
      expect(reflectionAhaFor(code: 'other'), reflectionAhaFor());
    },
  );

  test('câu phụ màn hoàn tất nguyên văn script', () {
    expect(
      kDoneSavedNote,
      'Lần nhìn lại này vừa để lại thêm một mảnh cho hành trình của bạn.',
    );
    expect(
      kDoneCompletionNote,
      'Điều bạn vừa hoàn thành / học được đã được lưu như một sự thật đã xảy '
      'ra, không phải một việc cần làm.',
    );
  });
}
