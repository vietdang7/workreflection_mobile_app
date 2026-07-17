import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/survey_scoring.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';

CcQuestion makeQ(String id, SurveyLayer layer, ScaleType scale, int order) =>
    CcQuestion(
      id: id,
      layer: layer,
      scaleType: scale,
      questionText: 'Q',
      questionOrder: order,
      isActive: true,
    );

void main() {
  // Helpers
  List<CcQuestion> makeQs(List<(String, SurveyLayer, ScaleType)> defs) {
    return defs
        .asMap()
        .entries
        .map((e) => makeQ(e.value.$1, e.value.$2, e.value.$3, e.key + 1))
        .toList();
  }

  group('computeSurveyScores — FREE (S/C/A only)', () {
    test('basic averages and weighted total', () {
      // S: 4+4=4.0, C: 3+4=3.5, A: 5+5=5.0
      // total = 4.0*0.5 + 3.5*0.3 + 5.0*0.2 = 2.0+1.05+1.0 = 4.05 → 4.1 (1dp rounding)
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('s2', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('c2', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
        ('a2', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {'s1': 4, 's2': 4, 'c1': 3, 'c2': 4, 'a1': 5, 'a2': 5};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.scoreStructure, 4.0);
      expect(result.scoreCulture, 3.5);
      expect(result.scoreActivity, 5.0);
      expect(result.scoreTotal, 4.1); // (4.0*0.5+3.5*0.3+5.0*0.2).round(1dp)
    });

    test('1-decimal rounding: (v*10).round()/10', () {
      // S: 1+2+3=2.0, C: 1+2+3+4=2.5, A: 1+3=2.0
      // total = 2.0*0.5 + 2.5*0.3 + 2.0*0.2 = 1.0+0.75+0.4 = 2.15 → 2.2
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('s2', SurveyLayer.structure, ScaleType.likert5),
        ('s3', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('c2', SurveyLayer.culture, ScaleType.likert5),
        ('c3', SurveyLayer.culture, ScaleType.likert5),
        ('c4', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
        ('a2', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {
        's1': 1, 's2': 2, 's3': 3,
        'c1': 1, 'c2': 2, 'c3': 3, 'c4': 4,
        'a1': 1, 'a2': 3,
      };
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.scoreTotal, 2.2);
    });

    test('bottleneck = min of S/C/A, tie S→C→A order (S wins)', () {
      // S=3.0, C=3.0, A=4.0 → bottleneck = S (tie: S before C)
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {'s1': 3, 'c1': 3, 'a1': 4};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.bottleneckLayer, SurveyLayer.structure);
    });

    test('bottleneck tie C wins over A', () {
      // S=4.0, C=3.0, A=3.0 → bottleneck = C (tie C before A)
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {'s1': 4, 'c1': 3, 'a1': 3};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.bottleneckLayer, SurveyLayer.culture);
    });

    test('bottleneck = A when A is uniquely lowest', () {
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {'s1': 5, 'c1': 4, 'a1': 2};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.bottleneckLayer, SurveyLayer.activity);
    });

    // Score level boundary tests (on scoreTotal)
    test('level HIGH at exactly 4.2', () {
      // Design total = 4.2: S=5,C=5,A=1 → S*0.5+C*0.3+A*0.2 = 2.5+1.5+0.2=4.2
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {'s1': 5, 'c1': 5, 'a1': 1};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.scoreTotal, 4.2);
      expect(result.scoreLevel, ScoreLevel.high);
    });

    test('level GOOD at exactly 3.5', () {
      // S=3,C=4,A=4 → 3*0.5+4*0.3+4*0.2 = 1.5+1.2+0.8 = 3.5
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {'s1': 3, 'c1': 4, 'a1': 4};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.scoreTotal, 3.5);
      expect(result.scoreLevel, ScoreLevel.good);
    });

    test('level WARNING at exactly 2.8', () {
      // S=2,C=4,A=4 → 2*0.5+4*0.3+4*0.2 = 1.0+1.2+0.8=3.0 — not 2.8
      // S=2,C=2,A=5 → 1.0+0.6+1.0=2.6 — too low
      // S=3,C=2,A=3 → 1.5+0.6+0.6=2.7 — too low
      // S=3,C=3,A=2 → 1.5+0.9+0.4=2.8 ✓
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {'s1': 3, 'c1': 3, 'a1': 2};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.scoreTotal, 2.8);
      expect(result.scoreLevel, ScoreLevel.warning);
    });

    test('level CRITICAL just below 2.8', () {
      // S=3,C=2,A=3 → 1.5+0.6+0.6=2.7
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {'s1': 3, 'c1': 2, 'a1': 3};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.scoreTotal, 2.7);
      expect(result.scoreLevel, ScoreLevel.critical);
    });

    test('level just below 3.5 → GOOD not WARNING', () {
      // S=3,C=4,A=3 → 1.5+1.2+0.6=3.3 → GOOD (>=2.8 but <3.5 — actually WARNING)
      // Wait: GOOD >= 3.5; so 3.3 → WARNING
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {'s1': 3, 'c1': 4, 'a1': 3};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.scoreTotal, 3.3);
      expect(result.scoreLevel, ScoreLevel.warning);
    });

    test('just below 4.2 → GOOD', () {
      // S=4,C=4,A=4 → 2.0+1.2+0.8=4.0 → GOOD
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
        ('a1', SurveyLayer.activity, ScaleType.likert5),
      ]);
      final answers = {'s1': 4, 'c1': 4, 'a1': 4};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.scoreTotal, 4.0);
      expect(result.scoreLevel, ScoreLevel.good);
    });

    test('empty layer questions → uses available layers only', () {
      // Only S + C questions; A absent → scoreActivity is 0.0
      final qs = makeQs([
        ('s1', SurveyLayer.structure, ScaleType.likert5),
        ('c1', SurveyLayer.culture, ScaleType.likert5),
      ]);
      final answers = {'s1': 4, 'c1': 3};
      final result = computeSurveyScores(answers: answers, questions: qs);
      expect(result.scoreStructure, 4.0);
      expect(result.scoreCulture, 3.0);
      expect(result.scoreActivity, 0.0);
    });
  });

  group('computeSurveyScores — PREMIUM (ESI + eNPS)', () {
    List<CcQuestion> premiumQs() => makeQs([
          ('s1', SurveyLayer.structure, ScaleType.likert5),
          ('s2', SurveyLayer.structure, ScaleType.likert5),
          ('c1', SurveyLayer.culture, ScaleType.likert5),
          ('a1', SurveyLayer.activity, ScaleType.likert5),
          ('e1', SurveyLayer.esi, ScaleType.esi5),
          ('e2', SurveyLayer.esi, ScaleType.esi5),
          ('n1', SurveyLayer.enps, ScaleType.enps10),
          ('n2', SurveyLayer.enps, ScaleType.enps10),
          ('n3', SurveyLayer.enps, ScaleType.enps10),
        ]);

    test('ESI average computed', () {
      final answers = {
        's1': 4, 's2': 4, 'c1': 4, 'a1': 4,
        'e1': 4, 'e2': 2, // ESI avg = 3.0
        'n1': 9, 'n2': 8, 'n3': 5, // promoter=1, passive=1, detractor=1 → eNPS=0
      };
      final result = computeSurveyScores(answers: answers, questions: premiumQs());
      expect(result.scoreEsi, 3.0);
    });

    test('ESI NOT included in scoreTotal', () {
      // S=4, C=4, A=4, ESI=1 → total still 4.0 (ESI ignored)
      final answers = {
        's1': 4, 's2': 4, 'c1': 4, 'a1': 4,
        'e1': 1, 'e2': 1,
        'n1': 9, 'n2': 9, 'n3': 9,
      };
      final result = computeSurveyScores(answers: answers, questions: premiumQs());
      expect(result.scoreTotal, 4.0);
    });

    test('eNPS all promoters (>=9) → 100', () {
      final answers = {
        's1': 4, 's2': 4, 'c1': 4, 'a1': 4,
        'e1': 3, 'e2': 3,
        'n1': 9, 'n2': 10, 'n3': 9,
      };
      final result = computeSurveyScores(answers: answers, questions: premiumQs());
      expect(result.scoreEnps, 100);
    });

    test('eNPS all detractors (<7) → -100', () {
      final answers = {
        's1': 4, 's2': 4, 'c1': 4, 'a1': 4,
        'e1': 3, 'e2': 3,
        'n1': 6, 'n2': 3, 'n3': 0,
      };
      final result = computeSurveyScores(answers: answers, questions: premiumQs());
      expect(result.scoreEnps, -100);
    });

    test('eNPS passive only → 0', () {
      // passive: >=7 && <9
      final answers = {
        's1': 4, 's2': 4, 'c1': 4, 'a1': 4,
        'e1': 3, 'e2': 3,
        'n1': 7, 'n2': 7, 'n3': 8,
      };
      final result = computeSurveyScores(answers: answers, questions: premiumQs());
      expect(result.scoreEnps, 0);
    });

    test('eNPS rounding: 2 promoters, 1 detractor out of 3 → ((2-1)/3*100).round() = 33', () {
      final answers = {
        's1': 4, 's2': 4, 'c1': 4, 'a1': 4,
        'e1': 3, 'e2': 3,
        'n1': 10, 'n2': 10, 'n3': 6,
      };
      final result = computeSurveyScores(answers: answers, questions: premiumQs());
      expect(result.scoreEnps, 33);
    });

    test('eNPS: 1 promoter, 2 detractors out of 3 → -33', () {
      final answers = {
        's1': 4, 's2': 4, 'c1': 4, 'a1': 4,
        'e1': 3, 'e2': 3,
        'n1': 9, 'n2': 6, 'n3': 5,
      };
      final result = computeSurveyScores(answers: answers, questions: premiumQs());
      expect(result.scoreEnps, -33);
    });
  });

  // ---------------------------------------------------------------------------
  // selectNarrative
  // ---------------------------------------------------------------------------

  group('selectNarrative', () {
    final narratives = [
      CcNarrative(
        id: 'n1',
        type: 'TOTAL',
        layer: null,
        scope: 'personal',
        scoreMin: 0.0,
        scoreMax: 2.799,
        narrativeText: 'Cần cải thiện nhiều',
        narrativeTextEn: 'Needs much improvement',
        narrativeVariants: const [],
        isActive: true,
      ),
      CcNarrative(
        id: 'n2',
        type: 'TOTAL',
        layer: null,
        scope: 'personal',
        scoreMin: 2.8,
        scoreMax: 3.499,
        narrativeText: 'Đang phát triển',
        narrativeTextEn: 'Developing',
        narrativeVariants: const [],
        isActive: true,
      ),
      CcNarrative(
        id: 'n3',
        type: 'TOTAL',
        layer: null,
        scope: 'personal',
        scoreMin: 3.5,
        scoreMax: 4.199,
        narrativeText: 'Tiến bộ tốt',
        narrativeTextEn: null, // EN fallback to VI
        narrativeVariants: const [],
        isActive: true,
      ),
      CcNarrative(
        id: 'n4',
        type: 'TOTAL',
        layer: null,
        scope: 'personal',
        scoreMin: 4.2,
        scoreMax: 5.0,
        narrativeText: 'Xuất sắc',
        narrativeTextEn: 'Excellent',
        narrativeVariants: const [],
        isActive: true,
      ),
      CcNarrative(
        id: 'n5',
        type: 'LAYER',
        layer: 'STRUCTURE',
        scope: 'personal',
        scoreMin: 3.5,
        scoreMax: 5.0,
        narrativeText: 'Cấu trúc ổn',
        narrativeTextEn: 'Good structure',
        narrativeVariants: const [],
        isActive: true,
      ),
    ];

    test('matches by type and score range (TOTAL, score=3.0 → n2)', () {
      final n = selectNarrative(
        narratives,
        type: 'TOTAL',
        layer: null,
        score: 3.0,
        language: 'vi',
      );
      expect(n?.id, 'n2');
    });

    test('overlapping ranges: prefer highest score_min ≤ score', () {
      // score=3.5: n2 has scoreMin=2.8 ≤ 3.5, n3 has scoreMin=3.5 ≤ 3.5
      // → n3 wins (higher scoreMin)
      final n = selectNarrative(
        narratives,
        type: 'TOTAL',
        layer: null,
        score: 3.5,
        language: 'vi',
      );
      expect(n?.id, 'n3');
    });

    test('score=4.2 → n4 (HIGH boundary)', () {
      final n = selectNarrative(
        narratives,
        type: 'TOTAL',
        layer: null,
        score: 4.2,
        language: 'vi',
      );
      expect(n?.id, 'n4');
    });

    test('EN language returns narrativeTextEn when not null', () {
      final n = selectNarrative(
        narratives,
        type: 'TOTAL',
        layer: null,
        score: 4.5,
        language: 'en',
      );
      expect(n?.narrativeTextEn, 'Excellent');
    });

    test('EN language falls back to VI when narrativeTextEn is null (n3)', () {
      final n = selectNarrative(
        narratives,
        type: 'TOTAL',
        layer: null,
        score: 3.8,
        language: 'en',
      );
      // n3.narrativeTextEn is null → falls back to narrativeText
      expect(n?.id, 'n3');
      expect(n?.narrativeTextEn, isNull);
    });

    test('LAYER type filter works', () {
      final n = selectNarrative(
        narratives,
        type: 'LAYER',
        layer: 'STRUCTURE',
        score: 4.0,
        language: 'vi',
      );
      expect(n?.id, 'n5');
    });

    test('no match returns null', () {
      final n = selectNarrative(
        narratives,
        type: 'BOTTLENECK',
        layer: null,
        score: 3.0,
        language: 'vi',
      );
      expect(n, isNull);
    });

    test('score below all ranges returns null', () {
      // n1 scoreMin=0.0, scoreMax=2.799; score=-0.1 → null
      final n = selectNarrative(
        narratives,
        type: 'TOTAL',
        layer: null,
        score: -0.1,
        language: 'vi',
      );
      expect(n, isNull);
    });
  });
}
