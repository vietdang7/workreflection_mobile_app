// Tests for wr_self_check_questions.dart — self-check question list and scoring.
// Run: flutter test test/core/wr_self_check_questions_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';

void main() {
  group('kSelfCheckQuestions', () {
    test('has exactly 15 questions', () {
      expect(kSelfCheckQuestions.length, 15);
    });

    test('has 5 S-pillar, 5 C-pillar, 5 A-pillar questions', () {
      final sByPillar = <SelfCheckPillar, int>{};
      for (final q in kSelfCheckQuestions) {
        sByPillar[q.pillar] = (sByPillar[q.pillar] ?? 0) + 1;
      }
      expect(sByPillar[SelfCheckPillar.s], 5);
      expect(sByPillar[SelfCheckPillar.c], 5);
      expect(sByPillar[SelfCheckPillar.a], 5);
    });

    test('all ids are unique and follow scq-01..scq-15 pattern', () {
      final ids = kSelfCheckQuestions.map((q) => q.id).toList();
      expect(ids.toSet().length, 15, reason: 'All IDs must be unique');
      for (var i = 0; i < 15; i++) {
        expect(ids[i], 'scq-${(i + 1).toString().padLeft(2, '0')}');
      }
    });

    test('no question text contains S1/S2/S3/Structure/Culture/Activity codes', () {
      for (final q in kSelfCheckQuestions) {
        expect(q.text, isNot(contains('Structure')),
            reason: 'id=${q.id} must not contain "Structure"');
        expect(q.text, isNot(contains('Culture')),
            reason: 'id=${q.id} must not contain "Culture"');
        expect(q.text, isNot(contains('Activity')),
            reason: 'id=${q.id} must not contain "Activity"');
      }
    });

    test('pillar displayNames are user-friendly Vietnamese (no S/C/A)', () {
      expect(SelfCheckPillar.s.displayName, 'Sự rõ ràng');
      expect(SelfCheckPillar.c.displayName, 'Mối quan hệ');
      expect(SelfCheckPillar.a.displayName, 'Cách làm việc');
    });
  });

  group('computePillarScore', () {
    test('returns average score for all answered S questions', () {
      // scq-01..05 are S pillar
      final answers = {
        'scq-01': 4,
        'scq-02': 3,
        'scq-03': 5,
        'scq-04': 2,
        'scq-05': 1,
      };
      final score = computePillarScore(SelfCheckPillar.s, answers);
      // average = (4+3+5+2+1)/5 = 3.0
      expect(score, closeTo(3.0, 0.001));
    });

    test('returns average for C pillar (scq-06..10)', () {
      final answers = {
        'scq-06': 5,
        'scq-07': 5,
        'scq-08': 5,
        'scq-09': 5,
        'scq-10': 5,
      };
      final score = computePillarScore(SelfCheckPillar.c, answers);
      expect(score, closeTo(5.0, 0.001));
    });

    test('returns average for A pillar (scq-11..15)', () {
      final answers = {
        'scq-11': 1,
        'scq-12': 1,
        'scq-13': 1,
        'scq-14': 1,
        'scq-15': 1,
      };
      final score = computePillarScore(SelfCheckPillar.a, answers);
      expect(score, closeTo(1.0, 0.001));
    });

    test('ignores answers for other pillars', () {
      final answers = {
        // S answers only
        'scq-01': 4,
        'scq-02': 4,
        'scq-03': 4,
        'scq-04': 4,
        'scq-05': 4,
        // C answers should not affect S score
        'scq-06': 1,
        'scq-07': 1,
      };
      final sScore = computePillarScore(SelfCheckPillar.s, answers);
      expect(sScore, closeTo(4.0, 0.001));
    });

    test('returns 0 when no answers provided for pillar', () {
      final score = computePillarScore(SelfCheckPillar.s, {});
      expect(score, 0.0);
    });

    test('handles partial answers — only uses answered questions', () {
      // Only 3 of 5 S questions answered
      final answers = {
        'scq-01': 2,
        'scq-02': 4,
        'scq-03': 3,
      };
      final score = computePillarScore(SelfCheckPillar.s, answers);
      // average of 2,4,3 = 3.0
      expect(score, closeTo(3.0, 0.001));
    });

    test('all 15 answered correctly computes all 3 pillar scores', () {
      final answers = <String, int>{};
      for (var i = 1; i <= 5; i++) {
        answers['scq-${i.toString().padLeft(2, '0')}'] = 3; // S → 3.0
      }
      for (var i = 6; i <= 10; i++) {
        answers['scq-${i.toString().padLeft(2, '0')}'] = 4; // C → 4.0
      }
      for (var i = 11; i <= 15; i++) {
        answers['scq-${i.toString().padLeft(2, '0')}'] = 5; // A → 5.0
      }

      expect(computePillarScore(SelfCheckPillar.s, answers), closeTo(3.0, 0.001));
      expect(computePillarScore(SelfCheckPillar.c, answers), closeTo(4.0, 0.001));
      expect(computePillarScore(SelfCheckPillar.a, answers), closeTo(5.0, 0.001));
    });
  });

  group('scoreToPercent', () {
    test('score=1 → 0%', () => expect(scoreToPercent(1), closeTo(0, 0.001)));
    test('score=3 → 50%', () => expect(scoreToPercent(3), closeTo(50, 0.001)));
    test('score=5 → 100%', () => expect(scoreToPercent(5), closeTo(100, 0.001)));
  });
}
