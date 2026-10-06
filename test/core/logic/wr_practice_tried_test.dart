// Câu "đã thử rồi mà không có kết quả" của form tự thêm chủ đề (họp khách
// 05/10): không được gợi ý lại đúng hướng người dùng đã thử.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_practice_v47.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

List<String> _ids(List<PracticeMentorOption> o) => [for (final x in o) x.id];

void main() {
  group('buildUserThemeMentorOptions', () {
    test('không có câu đã thử → giữ nguyên ba cách của mockup', () {
      expect(_ids(buildUserThemeMentorOptions('Nói rõ hơn')), [
        'small',
        'reframe',
        'observe',
      ]);
      expect(_ids(buildUserThemeMentorOptions('Nói rõ hơn', tried: '   ')), [
        'small',
        'reframe',
        'observe',
      ]);
    });

    test('đã thử quan sát → bỏ "Quan sát thêm một lần"', () {
      final o = buildUserThemeMentorOptions(
        'Nói rõ hơn',
        tried: 'Ngồi im quan sát xem mọi người phản ứng',
      );
      expect(_ids(o), ['reframe', 'small', 'talk']);
      expect(
        o.first.fit,
        contains('"Ngồi im quan sát xem mọi người phản ứng"'),
      );
    });

    test('đã thử trao đổi → không mời "Đưa người khác vào cuộc"', () {
      expect(
        _ids(
          buildUserThemeMentorOptions(
            'Bớt quá tải',
            tried: 'Đã trao đổi với quản lý.',
          ),
        ),
        ['reframe', 'small', 'observe'],
      );
    });

    test('đã thử từng bước nhỏ → bỏ "Thử cách nhỏ nhất"', () {
      expect(
        _ids(
          buildUserThemeMentorOptions('Tự tin hơn', tried: 'Thử từng bước nhỏ'),
        ),
        ['reframe', 'observe', 'talk'],
      );
    });

    test('khớp nguyên từ, không khớp nửa chữ', () {
      expect(triedMatchesOption('chờn vờn mãi', 'observe'), isFalse);
      expect(triedMatchesOption('Chờ thêm một tuần', 'observe'), isTrue);
      expect(triedMatchesOption('I asked my lead', 'talk'), isTrue);
      expect(triedMatchesOption('Tasked a colleague', 'talk'), isFalse);
      expect(triedMatchesOption('Ask my lead', 'talk'), isTrue);
    });

    test('chạm cả ba hướng vẫn đủ ba thẻ', () {
      final o = buildUserThemeMentorOptions(
        'x',
        tried: 'Từ từ quan sát rồi nói chuyện',
      );
      expect(o, hasLength(3));
      expect(o.first.id, 'reframe');
    });

    test('câu đã thử quá dài được cắt gọn', () {
      final o = buildUserThemeMentorOptions('x', tried: 'a' * 200);
      expect(o.first.fit, contains('…"'));
    });
  });

  group('buildUserPracticeSteps', () {
    test('có câu đã thử → bước "Chọn một cách" dặn đừng lặp lại', () {
      final steps = buildUserPracticeSteps(
        themeId: 'u-1',
        intake: const PracticeIntake(
          situation: 's',
          goal: 'Nói rõ hơn',
          tried: 'Góp ý ngay trong họp.',
        ),
      );
      expect(
        steps[2].content,
        endsWith(
          'Lần này đừng lặp lại điều bạn đã thử: "Góp ý ngay trong họp".',
        ),
      );
      expect(steps[2].contentEn, contains('do not repeat'));
      for (final i in [0, 1, 3]) {
        expect(steps[i].content, isNot(contains('đã thử:')));
      }
    });

    test('không có câu đã thử → chữ bước như cũ', () {
      final steps = buildUserPracticeSteps(
        themeId: 'u-1',
        intake: const PracticeIntake(situation: 's', goal: 'Nói rõ hơn'),
      );
      expect(
        steps[2].content,
        'Chọn một trong các cách ở trên và thử trong một tình huống thật, liên '
        'quan tới nói rõ hơn.',
      );
    });
  });
}
