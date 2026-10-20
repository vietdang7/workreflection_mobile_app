// Mô hình Hybrid cho chủ đề tự thêm: gợi ý AI (lớp 3) đi qua đối soát "đã thử"
// rồi mới vào chủ đề; thiếu hay hỏng thì bộ luật (lớp 2) lấp chỗ.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_practice_v47.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

PracticeMentorOption _opt(String title) => PracticeMentorOption(
  id: title,
  title: title,
  fit: 'Phù hợp khi bạn hay im lặng chờ người khác hỏi.',
  tradeoff: 'Tốn thêm chút thời gian.',
);

void main() {
  group('PracticeAiSuggestion.fromJson', () {
    test('generated false hoặc sai dạng → none', () {
      expect(PracticeAiSuggestion.fromJson({'generated': false}).isEmpty, true);
      expect(PracticeAiSuggestion.fromJson({}).isEmpty, true);
      expect(
        PracticeAiSuggestion.fromJson({
          'generated': true,
          'options': 'x',
        }).isEmpty,
        true,
      );
    });

    test('bản tiếng Việt: id ai-1..3, ô tiếng Anh để trống', () {
      final s = PracticeAiSuggestion.fromJson({
        'generated': true,
        'locale': 'vi',
        'options': [
          {'title': 'A', 'fit': 'f', 'tradeoff': 't'},
          {'title': '', 'fit': 'f', 'tradeoff': 't'},
          {'title': 'B', 'fit': 'f', 'tradeoff': 't'},
        ],
        'question': '  ',
      });
      expect(s.options.map((o) => o.id), ['ai-1', 'ai-2']);
      expect(s.options.first.titleEn, isNull);
      expect(s.question, isNull);
    });

    test('bản tiếng Anh ghi vào cả hai ô', () {
      final s = PracticeAiSuggestion.fromJson({
        'generated': true,
        'locale': 'en',
        'options': [
          {'title': 'Ask first', 'fit': 'f', 'tradeoff': 't'},
        ],
        'question': 'What helped?',
      });
      expect(s.options.single.titleVi, 'Ask first');
      expect(s.options.single.titleEn, 'Ask first');
      expect(s.question, 'What helped?');
    });
  });

  group('mergeAiMentorOptions', () {
    test('AI rỗng → nguyên bộ luật', () {
      final r = mergeAiMentorOptions(ai: const [], goal: 'Nói rõ hơn');
      expect(
        r.map((o) => o.id),
        buildUserThemeMentorOptions('Nói rõ hơn').map((o) => o.id),
      );
    });

    test('đủ ba cách AI hợp lệ → dùng cả ba', () {
      final ai = [
        _opt('Nói ý chính trước'),
        _opt('Xin hai phút'),
        _opt('Gửi ghi chú'),
      ];
      final r = mergeAiMentorOptions(
        ai: ai,
        goal: 'Nói rõ hơn',
        tried: 'Nói thẳng trong họp',
      );
      expect(r.map((o) => o.titleVi), [
        'Nói ý chính trước',
        'Xin hai phút',
        'Gửi ghi chú',
      ]);
    });

    test('cách lặp lại điều đã thử bị loại, bộ luật bù chỗ trống', () {
      final ai = [
        _opt('Im lặng chờ thêm một lần nữa'),
        _opt('Xin hai phút cuối buổi'),
        _opt('Gửi ghi chú trước'),
      ];
      final r = mergeAiMentorOptions(
        ai: ai,
        goal: 'Nói rõ hơn',
        tried: 'Im lặng chờ',
      );
      expect(r, hasLength(3));
      expect(r.any((o) => o.titleVi.startsWith('Im lặng')), false);
      expect(r.take(2).map((o) => o.titleVi), [
        'Xin hai phút cuối buổi',
        'Gửi ghi chú trước',
      ]);
      // Chỗ trống lấy từ lớp 2, và lớp 2 cũng đã tránh điều đã thử.
      expect(r.last.id.startsWith('ai-'), false);
    });

    test('phần "Phù hợp khi" kể lại tình huống không làm loại nhầm', () {
      // _opt có fit chứa nguyên "im lặng chờ người khác hỏi".
      final ai = [_opt('Nói trước một ý'), _opt('B b'), _opt('C c')];
      final r = mergeAiMentorOptions(
        ai: ai,
        goal: 'x',
        tried: 'Im lặng chờ người khác hỏi',
      );
      expect(r.map((o) => o.titleVi), ['Nói trước một ý', 'B b', 'C c']);
    });
  });

  group('buildUserPracticeSteps với câu hỏi AI', () {
    const intake = PracticeIntake(situation: 's', goal: 'Nói rõ hơn');

    test('có câu hỏi → bước 4 kèm gợi ý; ba bước đầu không đổi', () {
      final plain = buildUserPracticeSteps(themeId: 't', intake: intake);
      final ai = buildUserPracticeSteps(
        themeId: 't',
        intake: intake,
        aiQuestion: 'Điều gì giúp bạn nói trọn ý?',
      );
      for (var i = 0; i < 3; i++) {
        expect(ai[i].content, plain[i].content);
      }
      expect(ai[3].content, contains('Gợi ý: "Điều gì giúp bạn nói trọn ý?"'));
      expect(ai[3].isPremium, true);
    });

    test('câu hỏi rỗng → giữ câu mặc định', () {
      final plain = buildUserPracticeSteps(themeId: 't', intake: intake);
      final blank = buildUserPracticeSteps(
        themeId: 't',
        intake: intake,
        aiQuestion: '   ',
      );
      expect(blank[3].content, plain[3].content);
    });
  });
}
