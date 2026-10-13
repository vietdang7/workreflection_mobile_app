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
    test('mô tả bước 3 theo script, không nhắc lại điều đã thử', () {
      final steps = buildUserPracticeSteps(
        themeId: 'u-1',
        intake: const PracticeIntake(
          situation: 's',
          goal: 'Nói rõ hơn',
          tried: 'Góp ý ngay trong họp.',
        ),
      );
      // Ba cách gợi ý (`buildUserThemeMentorOptions`) đã tránh điều đã thử.
      expect(
        steps[2].content,
        'Mở phần gợi ý, chọn một cách, rồi thử trong một tình huống thật liên '
        'quan tới nói rõ hơn.',
      );
      expect(steps[2].contentEn, isNot(contains('do not repeat')));
    });

    test('bước 4 là "Câu hỏi cho lần sau", Premium', () {
      final steps = buildUserPracticeSteps(
        themeId: 'u-1',
        intake: const PracticeIntake(situation: 's', goal: 'Nói rõ hơn'),
      );
      expect(steps[3].title, 'Câu hỏi cho lần sau: Điều bạn muốn hỏi lần tới');
      expect(
        steps[3].content,
        'Sau khi thử, bạn muốn mang theo câu hỏi nào cho lần sau?',
      );
      expect(steps[3].isPremium, isTrue);
      expect(steps[0].title, 'Nhận diện: Quan sát một tình huống thật');
      expect(steps[1].title, 'Phần của tôi: Tách phần mình và phần bối cảnh');
      expect(steps[2].title, 'Chọn một cách: Chọn một cách rồi thử');
    });
  });
}
