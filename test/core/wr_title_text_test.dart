import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/widgets/wr_title_text.dart';

void main() {
  test('nối đuôi ngắn: chỉ hai tiếng cuối', () {
    expect(wrKeepTitleTail('Ngày hôm nay của bạn như thế nào?'),
        'Ngày hôm nay của bạn như thế nào?');
  });
  test('không nối câu 2 tiếng', () {
    expect(wrKeepTitleTail('Tạm ổn'), 'Tạm ổn');
  });
  test('không nối đuôi dài (bài học feeling goo)', () {
    expect(
        wrKeepTitleTail('I am feeling wonderful'), 'I am feeling wonderful');
  });
  test('nối câu tiếng Anh đuôi ngắn', () {
    expect(wrKeepTitleTail('How was your day today?'),
        'How was your day today?');
  });
  test('idempotent', () {
    final once = wrKeepTitleTail('How was your day today?');
    expect(wrKeepTitleTail(once), once);
  });
  test('câu đã có U+00A0 thì giữ nguyên', () {
    expect(wrKeepTitleTail('a b c d e'), 'a b c d e');
  });
  test('maxTailChars được tôn trọng', () {
    expect(wrKeepTitleTail('aa bb cc', maxTailChars: 4), 'aa bb cc');
    expect(wrKeepTitleTail('aa bb cc', maxTailChars: 5), 'aa bb cc');
  });
  test('khoảng trắng cuối không tạo tiếng cuối giả', () {
    expect(wrKeepTitleTail('a bb ccc  '), 'a bb ccc  ');
  });
  test('nhiều khoảng trắng giữa hai tiếng cuối vẫn nối', () {
    expect(wrKeepTitleTail('a bb   ccc'), 'a bb ccc');
  });
  test('chuỗi rỗng', () {
    expect(wrKeepTitleTail(''), '');
  });
  testWidgets('WrTitleText không dùng justify, giữ tham số', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: WrTitleText('A b c', maxLines: 2, style: TextStyle(fontSize: 17))));
    final w = t.widget<Text>(find.byType(Text));
    expect(w.textAlign, isNot(TextAlign.justify));
    expect(w.textAlign, isNull);
    expect(w.maxLines, 2);
    expect(w.data, 'A b c');
  });
}
