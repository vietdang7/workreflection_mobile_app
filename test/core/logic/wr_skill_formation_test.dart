// Kỹ năng đã hình thành — spec "Kỹ năng đã hình thành (Skill Formation)".
//
// Thay cho wr_skill_certification_test.dart. Luật đổi ở đúng một chỗ nhưng là
// chỗ quan trọng nhất: đi hết ba bước KHÔNG còn tự động thành kỹ năng.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_formation.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

const _theme = PracticeTheme(themeId: 'pt-voice', title: 'Dám lên tiếng');
const _other = PracticeTheme(themeId: 'pt-focus', title: 'Giữ tập trung');
const _threshold = 5;

CareerMemoryEvent _step(String title, {int i = 1, DateTime? at}) =>
    CareerMemoryEvent(
      id: 'e$i',
      userId: 'u1',
      behavior: kPracticeStepBehavior,
      reflectionText: '$title · Bước $i',
      createdAt: at,
    );

CareerMemoryEvent _maintained(String title, {int i = 1, DateTime? at}) =>
    CareerMemoryEvent(
      id: 'm$i',
      userId: 'u1',
      behavior: kPracticeMaintainedBehavior,
      reflectionText: '$title · Duy trì',
      createdAt: at,
    );

List<CareerMemoryEvent> _steps(String title, int n) =>
    [for (var i = 1; i <= n; i++) _step(title, i: i)];

PracticeEnrollment _enrollment({DateTime? completedAt}) => PracticeEnrollment(
      userId: 'u1',
      themeId: 'pt-voice',
      completedAt: completedAt,
    );

SkillFormation? _formation({
  PracticeEnrollment? enrollment,
  required List<CareerMemoryEvent> events,
}) =>
    skillFormationFor(
      theme: _theme,
      enrollment: enrollment ?? _enrollment(),
      events: events,
      threshold: _threshold,
    );

void main() {
  group('practiceCountForTheme', () {
    test('đếm cả hoàn thành bước lẫn ghi nhận duy trì', () {
      final events = [
        ..._steps('Dám lên tiếng', 3),
        _maintained('Dám lên tiếng', i: 1),
        _maintained('Dám lên tiếng', i: 2),
      ];
      expect(practiceCountForTheme(_theme, events), 5);
    });

    test('chỉ đếm sự kiện của đúng chủ đề', () {
      final events = [
        ..._steps('Dám lên tiếng', 3),
        ..._steps('Giữ tập trung', 4),
      ];
      expect(practiceCountForTheme(_theme, events), 3);
      expect(practiceCountForTheme(_other, events), 4);
    });

    test('bỏ qua sự kiện không phải thực hành', () {
      final events = [
        const CareerMemoryEvent(
          id: 'x',
          userId: 'u1',
          behavior: 'reflection_episode',
          reflectionText: 'Dám lên tiếng — không phải thực hành',
        ),
        ..._steps('Dám lên tiếng', 2),
      ];
      expect(practiceCountForTheme(_theme, events), 2);
    });

    test('tên chủ đề này không nuốt sự kiện của chủ đề tên dài hơn', () {
      const short = PracticeTheme(themeId: 'pt-a', title: 'Lắng nghe');
      const long =
          PracticeTheme(themeId: 'pt-b', title: 'Lắng nghe chủ động');
      final events = _steps('Lắng nghe chủ động', 4);
      expect(practiceCountForTheme(short, events), 0);
      expect(practiceCountForTheme(long, events), 4);
    });
  });

  group('ngưỡng hình thành', () {
    test('chưa ghi danh thì không có trạng thái nào', () {
      expect(
        skillFormationFor(
          theme: _theme,
          enrollment: null,
          events: _steps('Dám lên tiếng', 9),
          threshold: _threshold,
        ),
        isNull,
      );
    });

    test('đi hết ba bước vẫn CHƯA thành kỹ năng — mới xong giai đoạn làm quen',
        () {
      final f = _formation(
        enrollment: _enrollment(completedAt: DateTime(2026, 8, 1)),
        events: _steps('Dám lên tiếng', 3),
      )!;
      expect(f.skillFormed, isFalse);
      expect(f.stage, SkillStage.maintaining);
      expect(f.remaining, 2);
      expect(f.canMaintain, isTrue);
    });

    test('chưa xong ba bước thì chưa mở được giai đoạn duy trì', () {
      final f = _formation(events: _steps('Dám lên tiếng', 2))!;
      expect(f.stage, SkillStage.onboarding);
      expect(f.canMaintain, isFalse);
    });

    test('ba bước cộng hai lần duy trì là chạm ngưỡng', () {
      final f = _formation(
        enrollment: _enrollment(completedAt: DateTime(2026, 8, 1)),
        events: [
          ..._steps('Dám lên tiếng', 3),
          _maintained('Dám lên tiếng', i: 1),
          _maintained('Dám lên tiếng', i: 2),
        ],
      )!;
      expect(f.practiceCount, 5);
      expect(f.skillFormed, isTrue);
      expect(f.stage, SkillStage.formed);
      expect(f.remaining, 0);
      expect(f.progress, 1);
    });

    test('ngưỡng truyền vào được, không dính cứng số 5', () {
      final f = skillFormationFor(
        theme: _theme,
        enrollment: _enrollment(),
        events: _steps('Dám lên tiếng', 3),
        threshold: 3,
      )!;
      expect(f.skillFormed, isTrue);
    });
  });

  group('skillFormedDate', () {
    test('lấy ngày của mảnh ký ức dấu mốc khi đã có', () {
      final events = [
        ..._steps('Dám lên tiếng', 5),
        CareerMemoryEvent(
          id: 'milestone',
          userId: 'u1',
          behavior: kSkillFormedBehavior,
          reflectionText: 'Dám lên tiếng',
          createdAt: DateTime(2026, 8, 4),
        ),
      ];
      expect(
        skillFormedDateFor(_theme, events, threshold: _threshold),
        DateTime(2026, 8, 4),
      );
    });

    test('chưa có dấu mốc thì lấy ngày của lần thực hành thứ N', () {
      final events = [
        for (var i = 1; i <= 5; i++)
          _step('Dám lên tiếng', i: i, at: DateTime(2026, 8, i)),
      ];
      expect(
        skillFormedDateFor(_theme, events, threshold: _threshold),
        DateTime(2026, 8, 5),
      );
    });

    test('chưa đủ ngưỡng thì không có ngày', () {
      final events = [
        for (var i = 1; i <= 3; i++)
          _step('Dám lên tiếng', i: i, at: DateTime(2026, 8, i)),
      ];
      expect(
        skillFormedDateFor(_theme, events, threshold: _threshold),
        isNull,
      );
    });
  });

  group('maintainedToday', () {
    final now = DateTime(2026, 8, 4, 10);

    test('đã ghi nhận duy trì trong ngày', () {
      final events = [
        _maintained('Dám lên tiếng', at: DateTime(2026, 8, 4, 7)),
      ];
      expect(maintainedToday(_theme, events, now), isTrue);
    });

    test('ghi nhận hôm qua thì hôm nay bấm lại được', () {
      final events = [
        _maintained('Dám lên tiếng', at: DateTime(2026, 8, 3, 23)),
      ];
      expect(maintainedToday(_theme, events, now), isFalse);
    });

    test('hoàn thành bước hôm nay không chặn nút duy trì', () {
      final events = [_step('Dám lên tiếng', at: DateTime(2026, 8, 4, 8))];
      expect(maintainedToday(_theme, events, now), isFalse);
    });
  });

  group('skillFormations / formedSkills / formingSkills', () {
    test('trả về cả chủ đề đã đạt lẫn chủ đề đang trên đường', () {
      final events = [
        ..._steps('Dám lên tiếng', 6),
        ..._steps('Giữ tập trung', 2),
      ];
      final all = skillFormations(
        themes: const [_theme, _other],
        enrollments: [
          _enrollment(),
          const PracticeEnrollment(userId: 'u1', themeId: 'pt-focus'),
        ],
        events: events,
        threshold: _threshold,
      );

      expect(all, hasLength(2));
      expect(formedSkills(all).single.themeId, 'pt-voice');
      expect(formedSkills(all).single.practiceCount, 6);
      expect(formingSkills(all).single.themeId, 'pt-focus');
      expect(formingSkills(all).single.remaining, 3);
    });

    test('không ghi danh chủ đề nào thì danh sách rỗng', () {
      expect(
        skillFormations(
          themes: const [_theme],
          enrollments: const [],
          events: _steps('Dám lên tiếng', 10),
          threshold: _threshold,
        ),
        isEmpty,
      );
    });
  });

  group('newlyFormed', () {
    test('loại những kỹ năng đã từng được ghi dấu mốc', () {
      final formations = skillFormations(
        themes: const [_theme],
        enrollments: [_enrollment()],
        events: _steps('Dám lên tiếng', 5),
        threshold: _threshold,
      );

      final withMilestone = [
        ..._steps('Dám lên tiếng', 5),
        const CareerMemoryEvent(
          id: 'm1',
          userId: 'u1',
          behavior: kSkillFormedBehavior,
          reflectionText: 'Dám lên tiếng',
        ),
      ];

      expect(
        newlyFormed(formations: formations, events: withMilestone),
        isEmpty,
      );
      expect(
        newlyFormed(formations: formations, events: _steps('Dám lên tiếng', 5)),
        hasLength(1),
      );
    });

    test('chưa chạm ngưỡng thì không có gì để ăn mừng', () {
      final formations = skillFormations(
        themes: const [_theme],
        enrollments: [_enrollment()],
        events: _steps('Dám lên tiếng', 4),
        threshold: _threshold,
      );
      expect(newlyFormed(formations: formations, events: const []), isEmpty);
    });
  });
}
