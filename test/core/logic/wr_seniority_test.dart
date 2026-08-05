// Ma trận cấp bậc — "Thói quen và Ma trận Cấp bậc v1.0", Phần B.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_seniority.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_formation.dart';
import 'package:workreflection_mobile/core/logic/wr_skill_jd_match.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

PracticeStep _step(int order, String content) => PracticeStep(
      stepId: 'pt-c1-$order',
      themeId: 'pt-c1',
      stepOrder: order,
      title: 'Bước $order',
      content: content,
      isPremium: order == 3,
    );

PracticeTheme _theme(String id, ScaDimension dim) =>
    PracticeTheme(themeId: id, title: 'Chủ đề $id', scaDimension: dim);

SkillFormation _forming(PracticeTheme t) => SkillFormation(
      themeId: t.themeId,
      title: t.title,
      scaDimension: t.scaDimension,
      practiceCount: 1,
      threshold: 5,
      onboardingDone: false,
      skillFormedDate: null,
    );

void main() {
  group('seniorityFromPosition', () {
    test('tám mã vị trí của web gộp về ba cột của bảng', () {
      expect(seniorityFromPosition('staff'), SeniorityTier.individual);
      expect(seniorityFromPosition('intern'), SeniorityTier.individual);
      expect(seniorityFromPosition('freelancer'), SeniorityTier.individual);
      expect(seniorityFromPosition('team_lead'), SeniorityTier.leadTeam);
      expect(seniorityFromPosition('manager'), SeniorityTier.leadOrg);
      expect(seniorityFromPosition('director'), SeniorityTier.leadOrg);
      expect(seniorityFromPosition('c_level'), SeniorityTier.leadOrg);
    });

    test('chưa khai, mã "other" hay mã lạ đều là CHƯA BIẾT, không mặc định', () {
      // Chưa biết và biết-là-nhân-viên là hai chuyện khác nhau: mặc định về
      // `individual` sẽ đảo thứ tự khoảng trống của người chưa khai gì.
      expect(seniorityFromPosition(null), isNull);
      expect(seniorityFromPosition(''), isNull);
      expect(seniorityFromPosition('   '), isNull);
      expect(seniorityFromPosition('other'), isNull);
      expect(seniorityFromPosition('ceo-of-everything'), isNull);
    });

    test('chỉ cấp quản lý mới bật Nguyên tắc 3', () {
      expect(SeniorityTier.individual.isManaging, isFalse);
      expect(SeniorityTier.leadTeam.isManaging, isTrue);
      expect(SeniorityTier.leadOrg.isManaging, isTrue);
    });
  });

  group('B.2 — bảng mức độ liên quan', () {
    test('đủ mười chiều, mỗi chiều đủ ba cấp bậc', () {
      expect(kSeniorityMatrix.length, 10);
      for (final entry in kSeniorityMatrix.entries) {
        expect(entry.key.isSca, isTrue, reason: entry.key.dbValue);
        expect(entry.value.length, 3, reason: entry.key.dbValue);
      }
    });

    test('C1 nhảy từ "nên có" lên "cần, ưu tiên cao" khi lên quản lý', () {
      expect(
        relevanceOf(ScaDimension.c1, SeniorityTier.individual),
        SkillRelevance.nice,
      );
      expect(
        relevanceOf(ScaDimension.c1, SeniorityTier.leadTeam),
        SkillRelevance.critical,
      );
    });

    test('A1 tụt xuống "nên có" ở quản lý nhóm nhỏ rồi lên lại "cần"', () {
      // Đúng nguyên văn bảng B.2 — không làm mượt cho đẹp mắt.
      expect(
        relevanceOf(ScaDimension.a1, SeniorityTier.individual),
        SkillRelevance.needed,
      );
      expect(
        relevanceOf(ScaDimension.a1, SeniorityTier.leadTeam),
        SkillRelevance.nice,
      );
      expect(
        relevanceOf(ScaDimension.a1, SeniorityTier.leadOrg),
        SkillRelevance.needed,
      );
    });

    test('chưa biết cấp bậc thì không xếp hạng gì cả', () {
      expect(relevanceOf(ScaDimension.c1, null), isNull);
      expect(relevanceOf(null, SeniorityTier.leadOrg), isNull);
      // Hai nhóm tình huống tích cực nằm ngoài bộ 10.
      expect(relevanceOf(ScaDimension.pAchieve, SeniorityTier.leadOrg), isNull);
    });

    test('Nguyên tắc 3 chỉ nâng nhóm Kết nối, chỉ cho cấp quản lý', () {
      expect(isAutoRaised(ScaDimension.c2, SeniorityTier.leadTeam), isTrue);
      expect(isAutoRaised(ScaDimension.c2, SeniorityTier.individual), isFalse);
      expect(isAutoRaised(ScaDimension.s1, SeniorityTier.leadOrg), isFalse);
      expect(isAutoRaised(ScaDimension.c2, null), isFalse);
    });
  });

  group('B.3 — bước Chuyển hoá theo cấp bậc', () {
    test('đủ mười chủ đề của bộ chuẩn, mỗi chủ đề đủ ba cấp bậc', () {
      expect(kTransformByTier.length, 10);
      for (final e in kTransformByTier.entries) {
        expect(e.value.length, 3, reason: e.key);
      }
    });

    test('chỉ bước thứ ba bị viết lại, hai bước đầu giữ nguyên', () {
      final steps = [_step(1, 'gốc 1'), _step(2, 'gốc 2'), _step(3, 'gốc 3')];
      final out = personalizePracticeSteps(
        themeId: 'pt-c1',
        steps: steps,
        tier: SeniorityTier.leadTeam,
      );

      expect(out[0].content, 'gốc 1');
      expect(out[1].content, 'gốc 2');
      expect(out[2].content, contains('giao việc và thật sự buông'));
      // Giữ nguyên chiều, vị trí bước và cờ Premium — B.3 chỉ cho đổi chữ.
      expect(out[2].stepId, 'pt-c1-3');
      expect(out[2].stepOrder, 3);
      expect(out[2].title, 'Bước 3');
      expect(out[2].isPremium, isTrue);
      expect(out.length, 3);
    });

    test('chưa biết cấp bậc thì giữ nguyên bản mặc định', () {
      final steps = [_step(3, 'gốc 3')];
      expect(
        personalizePracticeSteps(themeId: 'pt-c1', steps: steps, tier: null)
            .single
            .content,
        'gốc 3',
      );
    });

    test('chủ đề ngoài bộ 10 giữ nguyên bản mặc định', () {
      final steps = [_step(3, 'gốc 3')];
      expect(
        personalizePracticeSteps(
          themeId: 'pt-voice',
          steps: steps,
          tier: SeniorityTier.leadOrg,
        ).single.content,
        'gốc 3',
      );
    });
  });

  group('B.1/B.2 áp vào đối chiếu JD', () {
    const jd = 'Cần lập kế hoạch, báo cáo và phân tích số liệu rõ ràng.';

    test('JD không nhắc Kết nối: người tự làm việc của mình thì không có C', () {
      final match = matchSkillsToContext(
        contextText: jd,
        formations: const [],
        allThemes: [
          _theme('pt-s1', ScaDimension.s1),
          _theme('pt-c1', ScaDimension.c1),
        ],
        tier: SeniorityTier.individual,
      );

      expect(match!.matchedPillars, isNot(contains('C')));
      expect(match.autoRaisedDimensions, isEmpty);
      expect(match.gapThemes.map((t) => t.themeId), ['pt-s1']);
    });

    test('cùng JD đó, người quản lý vẫn được kéo nhóm Kết nối vào', () {
      final match = matchSkillsToContext(
        contextText: jd,
        formations: const [],
        allThemes: [
          _theme('pt-s1', ScaDimension.s1),
          _theme('pt-c1', ScaDimension.c1),
        ],
        tier: SeniorityTier.leadTeam,
      );

      expect(match!.matchedPillars, contains('C'));
      expect(match.autoRaisedDimensions, ['C1', 'C2', 'C3']);
      expect(match.gapThemes.map((t) => t.themeId), contains('pt-c1'));
      // Trụ JD thật sự xoay quanh vẫn đứng trước trụ được kéo vào.
      expect(match.matchedPillars.first, 'S');
    });

    test('khoảng trống xếp theo mức độ liên quan của cấp bậc', () {
      final themes = [
        _theme('pt-a4', ScaDimension.a4), // leadTeam: nên có
        _theme('pt-c1', ScaDimension.c1), // leadTeam: cần, ưu tiên cao
        _theme('pt-a2', ScaDimension.a2), // leadTeam: cần
      ];
      final match = matchSkillsToContext(
        contextText: 'Quản lý đội nhóm, phối hợp và sắp xếp công việc.',
        formations: const [],
        allThemes: themes,
        tier: SeniorityTier.leadTeam,
      );

      expect(match!.gapThemes.map((t) => t.themeId), ['pt-c1', 'pt-a2', 'pt-a4']);
      expect(match.gapRelevance['pt-c1'], SkillRelevance.critical);
      expect(match.gapRelevance['pt-a2'], SkillRelevance.needed);
      expect(match.gapRelevance['pt-a4'], SkillRelevance.nice);
    });

    test('chưa biết cấp bậc thì thứ tự cũ giữ nguyên, không xếp hạng', () {
      final themes = [
        _theme('pt-a4', ScaDimension.a4),
        _theme('pt-a2', ScaDimension.a2),
      ];
      final match = matchSkillsToContext(
        contextText: 'Sắp xếp công việc, quản lý thời gian.',
        formations: [_forming(themes.first)],
        allThemes: themes,
      );

      expect(match!.tier, isNull);
      expect(match.gapRelevance, isEmpty);
      expect(match.autoRaisedDimensions, isEmpty);
      expect(match.gapThemes.map((t) => t.themeId), ['pt-a4', 'pt-a2']);
    });
  });
}
