// Career Snapshot / personalisation logic.
// Spec: giao-dien-ho-tro.jsx — CareerSetupScreen, ROLE_TO_DIMS, ROLE_TO_STAGES.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_career_profile.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

WrStory _story(
  String id,
  ScaDimension dim, {
  List<String> stages = const [],
}) =>
    WrStory(
      storyId: id,
      title: id,
      scaDimension: dim,
      storyContent: '...',
      emotionTags: const [],
      behaviorTags: const [],
      careerStages: stages,
    );

void main() {
  group('option lists', () {
    test('exactly the 6 roles / goals / challenges from the mockup', () {
      expect(kCareerRoleOptions, [
        'Chuyên viên',
        'Senior Specialist',
        'Team Leader',
        'Manager',
        'Director',
        'Founder / Business Owner',
      ]);
      expect(kCareerGoalOptions.length, 6);
      expect(kCareerChallengeOptions.length, 6);
    });
  });

  group('roleToDimensions', () {
    test('maps every role to its 3 priority dimensions', () {
      expect(roleToDimensions('Chuyên viên'),
          [ScaDimension.c2, ScaDimension.a1, ScaDimension.s1]);
      expect(roleToDimensions('Senior Specialist'),
          [ScaDimension.a1, ScaDimension.a3, ScaDimension.s1]);
      expect(roleToDimensions('Team Leader'),
          [ScaDimension.c1, ScaDimension.c2, ScaDimension.c3]);
      expect(roleToDimensions('Manager'),
          [ScaDimension.c1, ScaDimension.s2, ScaDimension.a4]);
      expect(roleToDimensions('Director'),
          [ScaDimension.c3, ScaDimension.s3, ScaDimension.a1]);
      expect(roleToDimensions('Founder / Business Owner'),
          [ScaDimension.a1, ScaDimension.c1, ScaDimension.a3]);
    });

    test('unknown or null role falls back to the Wave 1 dimensions', () {
      // DataSpec v3 Tầng 4, Đợt 1: C2, A1, A3, C1.
      expect(roleToDimensions(null), kWave1Dimensions);
      expect(roleToDimensions('Không có trong danh sách'), kWave1Dimensions);
    });
  });

  group('roleToCareerStages', () {
    test('maps roles to career stages', () {
      expect(roleToCareerStages('Chuyên viên'), ['Early Career', 'Growth']);
      expect(roleToCareerStages('Director'), ['Leadership']);
      expect(roleToCareerStages('Founder / Business Owner'),
          ['Leadership', 'Career Transition']);
    });

    test('unknown role yields an empty (non-filtering) list', () {
      expect(roleToCareerStages(null), isEmpty);
    });
  });

  group('CareerSnapshot', () {
    test('isComplete only when all three answers exist', () {
      expect(const CareerSnapshot().isComplete, isFalse);
      expect(
        const CareerSnapshot(currentRole: 'Manager').isComplete,
        isFalse,
      );
      expect(
        const CareerSnapshot(
          currentRole: 'Manager',
          careerGoal: 'Thăng tiến',
          currentChallenge: 'Áp lực công việc',
        ).isComplete,
        isTrue,
      );
    });

    test('isEmpty when nothing has been answered', () {
      expect(const CareerSnapshot().isEmpty, isTrue);
      expect(const CareerSnapshot(careerGoal: 'Thăng tiến').isEmpty, isFalse);
    });

    test('blank strings are treated as unanswered', () {
      const s = CareerSnapshot(currentRole: '   ');
      expect(s.isEmpty, isTrue);
      expect(s.currentRole, isNull);
    });

    test('toUpdate emits only the profile columns', () {
      const s = CareerSnapshot(
        currentRole: 'Manager',
        careerGoal: 'Thăng tiến',
        currentChallenge: 'Áp lực công việc',
      );
      expect(s.toUpdate(), {
        'current_role': 'Manager',
        'career_goal': 'Thăng tiến',
        'current_challenge': 'Áp lực công việc',
      });
    });

    test('toUpdate sends null for skipped steps', () {
      expect(const CareerSnapshot(currentRole: 'Director').toUpdate(), {
        'current_role': 'Director',
        'career_goal': null,
        'current_challenge': null,
      });
    });
  });

  group('rankStoriesForProfile', () {
    final stories = [
      _story('S3-01', ScaDimension.s3),
      _story('C1-01', ScaDimension.c1, stages: ['Leadership']),
      _story('C1-02', ScaDimension.c1, stages: ['Early Career']),
      _story('C2-01', ScaDimension.c2, stages: ['Leadership']),
      _story('A2-01', ScaDimension.a2),
    ];

    test('role dimensions come first, in the role priority order', () {
      // Team Leader → C1, C2, C3
      final ranked = rankStoriesForProfile(
        stories,
        const CareerSnapshot(currentRole: 'Team Leader'),
      );
      expect(ranked.first.scaDimension, ScaDimension.c1);
      expect(
        ranked.map((s) => s.storyId).take(3),
        containsAll(['C1-01', 'C1-02', 'C2-01']),
      );
    });

    test('within the same dimension, matching career stage wins', () {
      final ranked = rankStoriesForProfile(
        stories,
        const CareerSnapshot(currentRole: 'Team Leader'),
      );
      // Team Leader → Mid Career / Leadership, so C1-01 outranks C1-02.
      expect(ranked.indexWhere((s) => s.storyId == 'C1-01'),
          lessThan(ranked.indexWhere((s) => s.storyId == 'C1-02')));
    });

    test('never drops a story — ranking only reorders', () {
      final ranked = rankStoriesForProfile(
        stories,
        const CareerSnapshot(currentRole: 'Director'),
      );
      expect(ranked.length, stories.length);
      expect(ranked.map((s) => s.storyId).toSet(),
          stories.map((s) => s.storyId).toSet());
    });

    test('empty snapshot keeps the Wave 1 priority order', () {
      final ranked = rankStoriesForProfile(stories, const CareerSnapshot());
      // Wave 1 = C2, A1, A3, C1 → C2 story first, then C1 stories.
      expect(ranked.first.storyId, 'C2-01');
    });

    test('is stable for stories outside the priority set', () {
      final ranked = rankStoriesForProfile(
        stories,
        const CareerSnapshot(currentRole: 'Team Leader'),
      );
      final tail = ranked
          .where((s) =>
              s.scaDimension == ScaDimension.s3 ||
              s.scaDimension == ScaDimension.a2)
          .map((s) => s.storyId)
          .toList();
      expect(tail, ['S3-01', 'A2-01']);
    });

    test('does not mutate the input list', () {
      final input = [...stories];
      rankStoriesForProfile(input, const CareerSnapshot(currentRole: 'Manager'));
      expect(input.map((s) => s.storyId).toList(),
          stories.map((s) => s.storyId).toList());
    });
  });
}
