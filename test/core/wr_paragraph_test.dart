// Đoạn văn đọc chậm: căn đều và không để chữ cuối câu rớt xuống một mình.
// Khách chỉ ra lỗi này trên ảnh 2026-08-05 ("…chờ đợi trong mơ / hồ.").

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

void main() {
  group('wrKeepSentenceTailTogether', () {
    test('nối hai tiếng cuối câu bằng khoảng trắng không ngắt', () {
      final out = wrKeepSentenceTailTogether('thay vì chờ đợi trong mơ hồ.');
      expect(out, endsWith('mơ${nbsp}hồ.'));
      expect(out, startsWith('thay vì chờ đợi trong '));
    });

    test('xử lý từng câu một trong đoạn nhiều câu', () {
      const input = 'Thay đổi không đáng sợ bằng cảm giác bị bỏ lại phía sau. '
          'Thực hành này giúp bạn chủ động hỏi, thay vì chờ đợi trong mơ hồ.';
      final out = wrKeepSentenceTailTogether(input);

      expect(out, contains('phía${nbsp}sau.'));
      expect(out, contains('mơ${nbsp}hồ.'));
    });

    test('không đụng tới khoảng trắng giữa câu', () {
      const input = 'Một câu dài không có dấu chấm nào ở giữa cả';
      final out = wrKeepSentenceTailTogether(input);
      // Chỉ cụm cuối chuỗi được nối, phần còn lại nguyên vẹn.
      expect(out, 'Một câu dài không có dấu chấm nào ở giữa${nbsp}cả');
    });

    test('giữ nguyên dấu đóng ngoặc/ngoặc kép sau tiếng cuối', () {
      final out = wrKeepSentenceTailTogether('anh ấy nói "đi thôi!"');
      expect(out, contains('đi${nbsp}thôi!"'));
    });

    test('chuỗi một tiếng thì không đổi', () {
      expect(wrKeepSentenceTailTogether('Xong.'), 'Xong.');
      expect(wrKeepSentenceTailTogether(''), '');
    });

    test('không thêm hay bớt chữ nào — chỉ đổi loại khoảng trắng', () {
      const input = 'Thay đổi không đáng sợ. Bạn quen dần với việc hỏi.';
      final out = wrKeepSentenceTailTogether(input);
      expect(out.replaceAll(nbsp, ' '), input);
    });
  });

  group('WrParagraph', () {
    // Màn thật luôn nối cụm; test config tắt cờ này cho các bộ test khác.
    setUp(() => wrParagraphKeepsTail = true);
    tearDown(() => wrParagraphKeepsTail = false);

    testWidgets('căn đều hai bên', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WrParagraph('Thay đổi không đáng sợ.')),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textAlign, TextAlign.justify);
    });

    testWidgets('cho phép đổi sang canh trái khi cần', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WrParagraph('Một đoạn.', textAlign: TextAlign.start),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textAlign, TextAlign.start);
    });

    testWidgets('chữ hiển thị đã được nối cụm cuối', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WrParagraph('chờ đợi trong mơ hồ.')),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, contains('mơ${nbsp}hồ.'));
    });
  });
}
