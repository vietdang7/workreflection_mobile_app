// Tái hiện lỗi khách báo: câu hỏi check-in ở Home rớt đúng một chữ "nào?"
// xuống dòng cuối. Dựng đúng style của `_CheckinQuestion` (17px, w700, 1.35)
// và đo bằng TextPainter.
//
// Lưu ý về độ rộng: flutter_test dùng font thử (Ahem), chữ rộng hơn font thật
// nên khoảng độ rộng gây lỗi ở đây là 255-271px, không phải 291-306px như trên
// máy thật. Cơ chế giống nhau: chữ cuối vừa không lọt dòng trước.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/widgets/wr_title_text.dart';

const _question = 'Ngày hôm nay của bạn như thế nào?';

List<String> _lines(String text, double width) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  final lines = <String>[];
  for (final m in painter.computeLineMetrics()) {
    final pos = painter.getPositionForOffset(
      Offset(1, m.baseline - m.ascent / 2),
    );
    final b = painter.getLineBoundary(pos);
    lines.add(text.substring(b.start, b.end).trim());
  }
  painter.dispose();
  return lines;
}

void main() {
  test('chuỗi thô rớt đúng "nào?" xuống dòng cuối; helper thì không', () {
    for (var w = 255.0; w <= 271.0; w += 4) {
      final raw = _lines(_question, w);
      final kept = _lines(wrKeepTitleTail(_question), w);
      expect(raw.last, 'nào?', reason: 'lỗi phải tái hiện được ở w=$w: $raw');
      expect(kept.last, isNot('nào?'), reason: 'w=$w: $kept');
      expect(kept.last, 'thế\u00A0nào?', reason: 'w=$w: $kept');
    }
  });
}
