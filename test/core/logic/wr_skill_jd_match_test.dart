// Đối chiếu kỹ năng đã hình thành với mô tả công việc (Premium).

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_formation.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_jd_match.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

const _voice = PracticeTheme(
  themeId: 'pt-voice',
  title: 'Dám lên tiếng',
  scaDimension: ScaDimension.c2,
);
const _boundary = PracticeTheme(
  themeId: 'pt-boundary',
  title: 'Giữ ranh giới',
  scaDimension: ScaDimension.a2,
);
const _clarity = PracticeTheme(
  themeId: 'pt-clarity',
  title: 'Nói rõ kỳ vọng',
  scaDimension: ScaDimension.s1,
);

SkillFormation _formed(PracticeTheme t) => SkillFormation(
      themeId: t.themeId,
      title: t.title,
      scaDimension: t.scaDimension,
      practiceCount: 5,
      threshold: 5,
      onboardingDone: true,
      skillFormedDate: DateTime(2026, 8, 1),
    );

SkillFormation _forming(PracticeTheme t) => SkillFormation(
      themeId: t.themeId,
      title: t.title,
      scaDimension: t.scaDimension,
      practiceCount: 2,
      threshold: 5,
      onboardingDone: false,
      skillFormedDate: null,
    );

void main() {
  test('không có mô tả công việc thì im lặng', () {
    expect(
      matchSkillsToContext(
        contextText: null,
        formations: [_formed(_voice)],
        allThemes: const [_voice],
      ),
      isNull,
    );
    expect(
      matchSkillsToContext(
        contextText: '   ',
        formations: [_formed(_voice)],
        allThemes: const [_voice],
      ),
      isNull,
    );
  });

  test('mô tả không bắt được từ khoá nào thì im lặng, không bịa', () {
    expect(
      matchSkillsToContext(
        contextText: 'abc xyz',
        formations: [_formed(_voice)],
        allThemes: const [_voice],
      ),
      isNull,
    );
  });

  test('kỹ năng đã hình thành thuộc trụ công việc cần thì được nêu là đã có',
      () {
    final m = matchSkillsToContext(
      contextText: 'Giao tiếp với khách hàng, phối hợp đội nhóm hằng ngày.',
      formations: [_formed(_voice), _formed(_clarity)],
      allThemes: const [_voice, _clarity, _boundary],
    )!;

    expect(m.matchedPillars, contains('C'));
    expect(m.matchedSkills.map((s) => s.themeId), ['pt-voice']);
    expect(m.matchedDimensions, containsAll(['C1', 'C2', 'C3']));
    expect(m.basedOnKeywords, isNotEmpty);
  });

  test('chủ đề công việc cần nhưng chưa hình thành là khoảng trống', () {
    final m = matchSkillsToContext(
      contextText: 'Công việc cần chủ động, linh hoạt, chịu áp lực deadline.',
      formations: [_forming(_boundary)],
      allThemes: const [_voice, _boundary],
    )!;

    expect(m.matchedPillars, ['A']);
    expect(m.matchedSkills, isEmpty);
    expect(m.gapThemes.map((t) => t.themeId), ['pt-boundary']);
  });

  test('đã hình thành rồi thì không còn là khoảng trống', () {
    final m = matchSkillsToContext(
      contextText: 'Chủ động sắp xếp công việc, thích nghi nhanh.',
      formations: [_formed(_boundary)],
      allThemes: const [_boundary],
    )!;

    expect(m.gapThemes, isEmpty);
    expect(m.matchedSkills.single.themeId, 'pt-boundary');
  });

  test('chủ đề đã ngưng đề xuất không bị đưa vào khoảng trống', () {
    final retired = PracticeTheme(
      themeId: 'pt-old',
      title: 'Chủ đề cũ',
      scaDimension: ScaDimension.a1,
      retiredAt: DateTime(2026, 1, 1),
    );
    final m = matchSkillsToContext(
      contextText: 'Chủ động, linh hoạt, quản lý thời gian.',
      formations: const [],
      allThemes: [retired],
    )!;
    expect(m.gapThemes, isEmpty);
  });
}
