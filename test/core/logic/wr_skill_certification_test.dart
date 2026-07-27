// Test chứng nhận kỹ năng — yêu cầu khách 2026-07-27.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_certification.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

const _theme = PracticeTheme(themeId: 'pt-voice', title: 'Dám lên tiếng');
const _other = PracticeTheme(themeId: 'pt-focus', title: 'Giữ tập trung');

CareerMemoryEvent _practice(String themeTitle, {int i = 1}) =>
    CareerMemoryEvent(
      id: 'e$i',
      userId: 'u1',
      behavior: kPracticeStepBehavior,
      reflectionText: '$themeTitle — Bước $i',
    );

List<CareerMemoryEvent> _practices(String themeTitle, int n) =>
    [for (var i = 1; i <= n; i++) _practice(themeTitle, i: i)];

PracticeEnrollment _enrollment({DateTime? completedAt}) => PracticeEnrollment(
      userId: 'u1',
      themeId: 'pt-voice',
      completedAt: completedAt,
    );

void main() {
  group('practiceCountForTheme', () {
    test('chỉ đếm sự kiện của đúng chủ đề', () {
      final events = [..._practices('Dám lên tiếng', 3), ..._practices('Giữ tập trung', 4)];
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
        ..._practices('Dám lên tiếng', 2),
      ];
      expect(practiceCountForTheme(_theme, events), 2);
    });
  });

  group('isSkillCertified', () {
    test('chưa ghi danh thì không bao giờ được chứng nhận', () {
      expect(
        isSkillCertified(
          theme: _theme,
          enrollment: null,
          events: _practices('Dám lên tiếng', 9),
        ),
        isFalse,
      );
    });

    test('lặp lại dưới ngưỡng thì chưa được chứng nhận', () {
      expect(
        isSkillCertified(
          theme: _theme,
          enrollment: _enrollment(),
          events: _practices('Dám lên tiếng', kSkillPracticeThreshold - 1),
        ),
        isFalse,
      );
    });

    test('lặp lại đủ ngưỡng thì được chứng nhận', () {
      expect(
        isSkillCertified(
          theme: _theme,
          enrollment: _enrollment(),
          events: _practices('Dám lên tiếng', kSkillPracticeThreshold),
        ),
        isTrue,
      );
    });

    test('đi hết chuỗi bước thì được chứng nhận dù ít lần lặp', () {
      expect(
        isSkillCertified(
          theme: _theme,
          enrollment: _enrollment(completedAt: DateTime(2026, 7, 26)),
          events: _practices('Dám lên tiếng', 1),
        ),
        isTrue,
      );
    });
  });

  group('certifiedSkills', () {
    test('chỉ trả về chủ đề đã đạt, kèm số lần thực hành', () {
      final events = [
        ..._practices('Dám lên tiếng', 6),
        ..._practices('Giữ tập trung', 2),
      ];
      final skills = certifiedSkills(
        themes: const [_theme, _other],
        enrollments: [
          _enrollment(),
          const PracticeEnrollment(userId: 'u1', themeId: 'pt-focus'),
        ],
        events: events,
      );

      expect(skills, hasLength(1));
      expect(skills.single.themeId, 'pt-voice');
      expect(skills.single.practiceCount, 6);
      expect(skills.single.completed, isFalse);
    });

    test('không có ghi danh nào thì danh sách rỗng', () {
      expect(
        certifiedSkills(
          themes: const [_theme],
          enrollments: const [],
          events: _practices('Dám lên tiếng', 10),
        ),
        isEmpty,
      );
    });
  });

  group('practicesUntilSkill', () {
    test('đếm ngược đúng số lần còn lại', () {
      expect(
        practicesUntilSkill(
          theme: _theme,
          events: _practices('Dám lên tiếng', 2),
        ),
        kSkillPracticeThreshold - 2,
      );
    });

    test('không trả về số âm khi đã vượt ngưỡng', () {
      expect(
        practicesUntilSkill(
          theme: _theme,
          events: _practices('Dám lên tiếng', kSkillPracticeThreshold + 3),
        ),
        0,
      );
    });
  });

  group('newlyCertified', () {
    test('loại những kỹ năng đã từng được ghi dấu mốc', () {
      const skill = CertifiedSkill(
        themeId: 'pt-voice',
        title: 'Dám lên tiếng',
        practiceCount: 5,
        completed: false,
      );
      final events = [
        const CareerMemoryEvent(
          id: 'm1',
          userId: 'u1',
          behavior: kSkillCertifiedBehavior,
          reflectionText: 'Dám lên tiếng',
        ),
      ];
      expect(newlyCertified(certified: const [skill], events: events), isEmpty);
      expect(
        newlyCertified(certified: const [skill], events: const []),
        hasLength(1),
      );
    });
  });
}
