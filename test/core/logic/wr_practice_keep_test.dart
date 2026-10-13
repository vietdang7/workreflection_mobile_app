// Script Sprint 2 — phần duy trì, ba cách ở bước 3, câu hỏi từng bước, câu
// tâm thế. Logic thuần trong `wr_practice_v47.dart`.
//
// Run: flutter test test/core/logic/wr_practice_keep_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_practice_v47.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_formation.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';

CareerMemoryEvent _ev(
  String themeId,
  DateTime at, {
  String behavior = kPracticeMaintainedBehavior,
}) => CareerMemoryEvent(
  id: '$themeId-${at.millisecondsSinceEpoch}-$behavior',
  userId: 'u1',
  behavior: behavior,
  themeId: themeId,
  createdAt: at,
);

PracticeNote _n(String text, DateTime at) => (text, at);

typedef PracticeNote = (String, DateTime);

List<PracticeStepNote> _notes(List<PracticeNote> raw) => [
  for (var i = 0; i < raw.length; i++)
    PracticeStepNote(
      userId: 'u1',
      stepId: 's$i',
      note: raw[i].$1,
      createdAt: raw[i].$2,
    ),
];

void main() {
  final now = DateTime(2026, 10, 13, 10);

  group('buildKeepingThemes', () {
    const voice = PracticeTheme(themeId: 'pt-c2', title: 'Dám lên tiếng');
    const trust = PracticeTheme(themeId: 'pt-c1', title: 'Tin và được tin');
    const doing = PracticeTheme(themeId: 'pt-s1', title: 'Rõ ràng');

    test('chỉ chủ đề đã đưa vào duy trì, không có dữ liệu mẫu', () {
      final list = buildKeepingThemes(
        themes: const [voice, trust, doing],
        enrollments: [
          PracticeEnrollment(
            userId: 'u1',
            themeId: 'pt-c2',
            completedAt: DateTime(2026, 10, 1),
          ),
          const PracticeEnrollment(userId: 'u1', themeId: 'pt-s1'),
        ],
        events: const [],
        now: now,
      );
      expect(list.map((k) => k.theme.themeId), ['pt-c2']);
      // Lần đưa vào duy trì là lần thứ nhất (script `moveToKeep`).
      expect(list.single.count, 1);
      expect(list.single.lastAt, DateTime(2026, 10, 1));
      expect(list.single.markedToday, isFalse);
    });

    test('mỗi lần Ghi nhận cộng một, gần nhất là lần ghi mới nhất', () {
      final list = buildKeepingThemes(
        themes: const [voice, trust],
        enrollments: [
          PracticeEnrollment(
            userId: 'u1',
            themeId: 'pt-c2',
            completedAt: DateTime(2026, 9, 1),
          ),
          PracticeEnrollment(
            userId: 'u1',
            themeId: 'pt-c1',
            completedAt: DateTime(2026, 10, 2),
          ),
        ],
        events: [
          _ev('pt-c2', DateTime(2026, 10, 10)),
          _ev('pt-c2', DateTime(2026, 10, 13, 8)),
          // Bước thực hành không phải một lần duy trì.
          _ev('pt-c2', DateTime(2026, 10, 12), behavior: kPracticeStepBehavior),
        ],
        now: now,
      );
      // Mới đưa vào duy trì trước.
      expect(list.map((k) => k.theme.themeId), ['pt-c1', 'pt-c2']);
      final c2 = list.last;
      expect(c2.count, 3);
      expect(c2.lastAt, DateTime(2026, 10, 13, 8));
      expect(c2.markedToday, isTrue);
      expect(list.first.markedToday, isFalse);
    });
  });

  test('keepLastLabel theo cách script viết', () {
    expect(keepLastLabel(DateTime(2026, 10, 13, 1), now), 'hôm nay');
    expect(keepLastLabel(DateTime(2026, 10, 12, 23), now), 'hôm qua');
    expect(keepLastLabel(DateTime(2026, 10, 10), now), '3 ngày trước');
    expect(keepLastLabel(DateTime(2026, 10, 4), now), 'tuần trước');
    expect(keepLastLabel(DateTime(2026, 9, 20), now), '3 tuần trước');
    expect(keepLastLabel(DateTime(2026, 6, 1), now), '4 tháng trước');
  });

  group('ba cách ở bước 3 (STEP3_OPTIONS)', () {
    test('thư viện: Dám lên tiếng dùng bộ t1, không có Đánh đổi', () {
      final opts = step3OptionsFor(
        const PracticeTheme(themeId: 'pt-c2', title: 'Dám lên tiếng'),
      );
      expect(opts.map((o) => o.title), [
        'Đặt một câu hỏi nhỏ trước',
        'Quan sát thêm một lần',
        'Nói trước với một người',
      ]);
      expect(opts.every((o) => o.tradeoff.isEmpty), isTrue);
    });

    test('thư viện: chủ đề phản hồi dùng bộ t2, còn lại bộ chung', () {
      expect(
        step3OptionsFor(
          const PracticeTheme(themeId: 'pt-c3', title: 'Phản hồi'),
        ).map((o) => o.id),
        ['ask', 'watch', 'time'],
      );
      expect(
        step3OptionsFor(
          const PracticeTheme(themeId: 'pt-a1', title: 'Khác'),
        ).first.title,
        'Thử một thay đổi nhỏ nhất',
      );
    });

    test('chủ đề tự thêm giữ ba cách dựng từ lời người dùng', () {
      final mine = buildUserThemeMentorOptions('Nói rõ hơn');
      final opts = step3OptionsFor(
        PracticeTheme(
          themeId: 'u-1',
          title: 'Của tôi',
          source: PracticeThemeSource.user,
          ownerId: 'u1',
          mentorOptions: mine,
        ),
      );
      expect(opts.map((o) => o.id), mine.map((o) => o.id));
    });

    test('nhận ra cách đã lưu bằng id, tên tiếng Việt hoặc tiếng Anh', () {
      expect(findPracticeOption(kStep3OptionsVoice, 'ally')?.id, 'ally');
      expect(
        findPracticeOption(kStep3OptionsVoice, 'Nói trước với một người')?.id,
        'ally',
      );
      expect(
        findPracticeOption(kStep3OptionsVoice, 'Tell one person first')?.id,
        'ally',
      );
      expect(findPracticeOption(kStep3OptionsVoice, 'khác'), isNull);
      expect(findPracticeOption(kStep3OptionsVoice, null), isNull);
    });
  });

  test('mỗi bước một câu hỏi riêng (STEP_PROMPTS)', () {
    expect(practiceStepPrompt(1).q, 'Bạn để ý thấy gì?');
    expect(practiceStepPrompt(2).q, 'Điều gì thuộc quyền quyết định của bạn?');
    expect(practiceStepPrompt(3).q, 'Bạn đã thử như thế nào?');
    expect(practiceStepPrompt(4).q, 'Câu hỏi bạn muốn mang theo cho lần sau?');
    expect(practiceStepPrompt(4).ph, startsWith('Ví dụ: Lần tới mình'));
  });

  group('câu tâm thế', () {
    final twoThemesThree = [
      _ev('pt-c2', DateTime(2026, 10, 1), behavior: kPracticeStepBehavior),
      _ev('pt-c2', DateTime(2026, 10, 2), behavior: kPracticeStepBehavior),
      _ev('pt-c1', DateTime(2026, 10, 3)),
    ];

    test('dưới 3 lần hoặc chỉ một chủ đề thì chưa đủ dữ liệu', () {
      expect(stanceHasEnoughData(twoThemesThree.take(2).toList()), isFalse);
      expect(
        stanceHasEnoughData([
          for (var i = 1; i <= 5; i++)
            _ev(
              'pt-c2',
              DateTime(2026, 10, i),
              behavior: kPracticeStepBehavior,
            ),
        ]),
        isFalse,
      );
      expect(stanceHasEnoughData(twoThemesThree), isTrue);
    });

    test('đủ dữ liệu: lấy lại đúng chữ ghi chú đầu và gần nhất', () {
      final text = buildStanceObservation(
        events: twoThemesThree,
        notes: _notes([
          _n('Mình gần như không nói gì.', DateTime(2026, 10, 1)),
          _n('Hôm nay mình hỏi lại một câu.', DateTime(2026, 10, 3)),
        ]),
      );
      expect(text, isNotNull);
      expect(text, contains('“Mình gần như không nói gì”'));
      expect(text, contains('“Hôm nay mình hỏi lại một câu”'));
      // Nhịp tích luỹ là nhịp không được bỏ.
      expect(text, contains('nhiều hơn trước'));
      // Không số lần, không tự xưng.
      expect(text, isNot(contains('tôi thấy')));
      expect(text, isNot(matches(RegExp(r'\d'))));
      expect(text, isNot(contains('—')));
    });

    test('đủ số lần nhưng chưa có hai ghi chú khác nhau thì để trống', () {
      expect(
        buildStanceObservation(events: twoThemesThree, notes: const []),
        isNull,
      );
      expect(
        buildStanceObservation(
          events: twoThemesThree,
          notes: _notes([
            _n('Giống nhau.', DateTime(2026, 10, 1)),
            _n('Giống nhau', DateTime(2026, 10, 2)),
          ]),
        ),
        isNull,
      );
    });

    test('chưa đủ số lần thì không sinh câu dù có ghi chú', () {
      expect(
        buildStanceObservation(
          events: twoThemesThree.take(1).toList(),
          notes: _notes([
            _n('Một.', DateTime(2026, 10, 1)),
            _n('Hai.', DateTime(2026, 10, 2)),
          ]),
        ),
        isNull,
      );
    });
  });
}
