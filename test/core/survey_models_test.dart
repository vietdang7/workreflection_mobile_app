import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/survey_repository.dart'
    show buildSubScoresMap;
import 'package:workreflection_mobile/core/models/survey_models.dart';

void main() {
  group('SurveyType', () {
    test('fromJson FREE', () {
      expect(SurveyType.fromJson('FREE'), SurveyType.free);
    });
    test('fromJson PREMIUM', () {
      expect(SurveyType.fromJson('PREMIUM'), SurveyType.premium);
    });
    test('toJson free', () {
      expect(SurveyType.free.toJson(), 'FREE');
    });
    test('toJson premium', () {
      expect(SurveyType.premium.toJson(), 'PREMIUM');
    });
  });

  group('ScaleType', () {
    test('fromJson LIKERT_5', () {
      expect(ScaleType.fromJson('LIKERT_5'), ScaleType.likert5);
    });
    test('fromJson ESI_5', () {
      expect(ScaleType.fromJson('ESI_5'), ScaleType.esi5);
    });
    test('fromJson ENPS_10', () {
      expect(ScaleType.fromJson('ENPS_10'), ScaleType.enps10);
    });
  });

  group('SurveyLayer', () {
    test('fromJson STRUCTURE', () {
      expect(SurveyLayer.fromJson('STRUCTURE'), SurveyLayer.structure);
    });
    test('fromJson CULTURE', () {
      expect(SurveyLayer.fromJson('CULTURE'), SurveyLayer.culture);
    });
    test('fromJson ACTIVITY', () {
      expect(SurveyLayer.fromJson('ACTIVITY'), SurveyLayer.activity);
    });
    test('fromJson ESI', () {
      expect(SurveyLayer.fromJson('ESI'), SurveyLayer.esi);
    });
    test('fromJson ENPS', () {
      expect(SurveyLayer.fromJson('ENPS'), SurveyLayer.enps);
    });
  });

  group('ScoreLevel', () {
    test('fromJson HIGH', () {
      expect(ScoreLevel.fromJson('HIGH'), ScoreLevel.high);
    });
    test('fromJson GOOD', () {
      expect(ScoreLevel.fromJson('GOOD'), ScoreLevel.good);
    });
    test('fromJson WARNING', () {
      expect(ScoreLevel.fromJson('WARNING'), ScoreLevel.warning);
    });
    test('fromJson CRITICAL', () {
      expect(ScoreLevel.fromJson('CRITICAL'), ScoreLevel.critical);
    });
  });

  group('CcQuestion.fromJson', () {
    final json = {
      'id': 'q1',
      'layer': 'STRUCTURE',
      'sub_component': 'clarity',
      'scale_type': 'LIKERT_5',
      'question_text': 'Vai trò rõ ràng?',
      'question_text_en': 'Is your role clear?',
      'question_order': 1,
      'is_active': true,
    };

    test('parses all fields', () {
      final q = CcQuestion.fromJson(json);
      expect(q.id, 'q1');
      expect(q.layer, SurveyLayer.structure);
      expect(q.subComponent, 'clarity');
      expect(q.scaleType, ScaleType.likert5);
      expect(q.questionText, 'Vai trò rõ ràng?');
      expect(q.questionTextEn, 'Is your role clear?');
      expect(q.questionOrder, 1);
      expect(q.isActive, true);
    });

    test('nullable questionTextEn', () {
      final j2 = Map<String, dynamic>.from(json)..['question_text_en'] = null;
      final q = CcQuestion.fromJson(j2);
      expect(q.questionTextEn, isNull);
    });

    test('nullable subComponent', () {
      final j2 = Map<String, dynamic>.from(json)..['sub_component'] = null;
      final q = CcQuestion.fromJson(j2);
      expect(q.subComponent, isNull);
    });
  });

  group('CcLikertOption.fromJson', () {
    test('parses all fields', () {
      final json = {
        'scale_type': 'LIKERT_5',
        'value': 3,
        'label': 'Bình thường',
        'label_en': 'Neutral',
        'display_order': 3,
      };
      final o = CcLikertOption.fromJson(json);
      expect(o.scaleType, ScaleType.likert5);
      expect(o.value, 3);
      expect(o.label, 'Bình thường');
      expect(o.labelEn, 'Neutral');
      expect(o.displayOrder, 3);
    });

    test('nullable labelEn', () {
      final json = {
        'scale_type': 'ESI_5',
        'value': 1,
        'label': 'Không hài lòng',
        'label_en': null,
        'display_order': 1,
      };
      final o = CcLikertOption.fromJson(json);
      expect(o.labelEn, isNull);
    });
  });

  group('CcNarrative.fromJson', () {
    test('parses all fields incl variants jsonb', () {
      final json = {
        'id': 'n1',
        'type': 'TOTAL',
        'layer': null,
        'scope': 'personal',
        'score_min': 3.5,
        'score_max': 4.2,
        'narrative_text': 'Tốt lắm',
        'narrative_text_en': 'Good job',
        'narrative_variants': ['v1', 'v2'],
        'is_active': true,
      };
      final n = CcNarrative.fromJson(json);
      expect(n.id, 'n1');
      expect(n.type, 'TOTAL');
      expect(n.layer, isNull);
      expect(n.scope, 'personal');
      expect(n.scoreMin, 3.5);
      expect(n.scoreMax, 4.2);
      expect(n.narrativeText, 'Tốt lắm');
      expect(n.narrativeTextEn, 'Good job');
      expect(n.narrativeVariants, ['v1', 'v2']);
      expect(n.isActive, true);
    });

    test('null narrativeVariants → empty list', () {
      final json = {
        'id': 'n2',
        'type': 'LAYER',
        'layer': 'STRUCTURE',
        'scope': 'personal',
        'score_min': 0.0,
        'score_max': 2.8,
        'narrative_text': 'Cần cải thiện',
        'narrative_text_en': null,
        'narrative_variants': null,
        'is_active': true,
      };
      final n = CcNarrative.fromJson(json);
      expect(n.narrativeVariants, isEmpty);
      expect(n.narrativeTextEn, isNull);
    });
  });

  group('CcReportFull.fromJson', () {
    test('parses full premium report', () {
      final json = {
        'id': 'r1',
        'survey_id': 's1',
        'user_id': 'u1',
        'score_total': 4.3,
        'score_structure': 4.5,
        'score_culture': 4.1,
        'score_activity': 4.0,
        'score_esi': 3.8,
        'score_enps': 40,
        'bottleneck_layer': 'ACTIVITY',
        'score_level': 'HIGH',
        'sub_scores': null,
        'selected_narrative_variants': null,
        'created_at': '2026-07-17T10:00:00.000Z',
      };
      final r = CcReportFull.fromJson(json);
      expect(r.id, 'r1');
      expect(r.surveyId, 's1');
      expect(r.userId, 'u1');
      expect(r.scoreTotal, 4.3);
      expect(r.scoreStructure, 4.5);
      expect(r.scoreCulture, 4.1);
      expect(r.scoreActivity, 4.0);
      expect(r.scoreEsi, 3.8);
      expect(r.scoreEnps, 40);
      expect(r.bottleneckLayer, SurveyLayer.activity);
      expect(r.scoreLevel, ScoreLevel.high);
      expect(r.createdAt, DateTime.parse('2026-07-17T10:00:00.000Z'));
    });

    test('nullable ESI and eNPS for free report', () {
      final json = {
        'id': 'r2',
        'survey_id': 's2',
        'user_id': 'u1',
        'score_total': 3.2,
        'score_structure': 3.5,
        'score_culture': 3.0,
        'score_activity': 2.9,
        'score_esi': null,
        'score_enps': null,
        'bottleneck_layer': 'CULTURE',
        'score_level': 'WARNING',
        'sub_scores': null,
        'selected_narrative_variants': null,
        'created_at': '2026-07-17T09:00:00.000Z',
      };
      final r = CcReportFull.fromJson(json);
      expect(r.scoreEsi, isNull);
      expect(r.scoreEnps, isNull);
      expect(r.bottleneckLayer, SurveyLayer.culture);
      expect(r.scoreLevel, ScoreLevel.warning);
    });
  });

  group('ActionPlanPhase.fromJson', () {
    test('parses basic fields', () {
      final json = {
        'id': 'ph1',
        'day': 1,
        'title_vi': 'Khởi động',
        'title_en': 'Kickoff',
        'description': 'Mô tả',
        'reflection_question': 'Bạn muốn gì?',
        'survey_type': 'FREE',
        'display_order': 1,
      };
      final p = ActionPlanPhase.fromJson(json);
      expect(p.id, 'ph1');
      expect(p.day, 1);
      expect(p.titleVi, 'Khởi động');
      expect(p.titleEn, 'Kickoff');
      expect(p.surveyType, SurveyType.free);
    });
  });

  group('ActionPlanTask.fromJson', () {
    test('parses task fields', () {
      final json = {
        'id': 't1',
        'phase_id': 'ph1',
        'label': 'Viết nhật ký',
        'display_order': 1,
      };
      final t = ActionPlanTask.fromJson(json);
      expect(t.id, 't1');
      expect(t.phaseId, 'ph1');
      expect(t.label, 'Viết nhật ký');
      expect(t.displayOrder, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // EnpsBreakdown.fromValues — render-time eNPS computation
  // Thresholds mirror web calculateENPS: >=9 promoter, 7-8 passive, <=6 detractor
  // ---------------------------------------------------------------------------

  group('EnpsBreakdown.fromValues', () {
    test('9 → promoter (boundary)', () {
      final b = EnpsBreakdown.fromValues([9]);
      expect(b.promoters, 1);
      expect(b.passives, 0);
      expect(b.detractors, 0);
      expect(b.total, 1);
    });

    test('10 → promoter', () {
      final b = EnpsBreakdown.fromValues([10]);
      expect(b.promoters, 1);
    });

    test('8 → passive (boundary)', () {
      final b = EnpsBreakdown.fromValues([8]);
      expect(b.promoters, 0);
      expect(b.passives, 1);
      expect(b.detractors, 0);
    });

    test('7 → passive (boundary)', () {
      final b = EnpsBreakdown.fromValues([7]);
      expect(b.passives, 1);
      expect(b.promoters, 0);
      expect(b.detractors, 0);
    });

    test('6 → detractor (boundary below passive)', () {
      final b = EnpsBreakdown.fromValues([6]);
      expect(b.detractors, 1);
      expect(b.promoters, 0);
      expect(b.passives, 0);
    });

    test('0 → detractor', () {
      final b = EnpsBreakdown.fromValues([0]);
      expect(b.detractors, 1);
    });

    test('mixed: [9,8,7,6,5] → 1p,2pa,2d', () {
      final b = EnpsBreakdown.fromValues([9, 8, 7, 6, 5]);
      expect(b.promoters, 1);
      expect(b.passives, 2);
      expect(b.detractors, 2);
      expect(b.total, 5);
    });

    test('all promoters', () {
      final b = EnpsBreakdown.fromValues([9, 10, 9]);
      expect(b.promoters, 3);
      expect(b.passives, 0);
      expect(b.detractors, 0);
    });

    test('all detractors', () {
      final b = EnpsBreakdown.fromValues([6, 3, 0]);
      expect(b.promoters, 0);
      expect(b.passives, 0);
      expect(b.detractors, 3);
    });

    test('empty list → all zeros', () {
      final b = EnpsBreakdown.fromValues([]);
      expect(b.promoters, 0);
      expect(b.passives, 0);
      expect(b.detractors, 0);
      expect(b.total, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // buildSubScoresMap — web-canonical sub_scores format
  // ---------------------------------------------------------------------------

  CcQuestion makeQWithSub(String id, SurveyLayer layer, String? sub) =>
      CcQuestion(
        id: id,
        layer: layer,
        subComponent: sub,
        scaleType: ScaleType.likert5,
        questionText: 'Q',
        questionOrder: 1,
        isActive: true,
      );

  group('buildSubScoresMap', () {
    test('single sub-component → correct layer and score', () {
      final questions = [
        makeQWithSub('q1', SurveyLayer.structure, 'role_expect'),
        makeQWithSub('q2', SurveyLayer.structure, 'role_expect'),
      ];
      final answers = {'q1': 4, 'q2': 2}; // avg = 3.0
      final result = buildSubScoresMap(answers, questions);
      expect(result, isNotNull);
      final entry = result!['role_expect'] as Map;
      expect(entry['layer'], 'STRUCTURE');
      expect(entry['score'], 3.0);
    });

    test('multiple sub-components across layers', () {
      final questions = [
        makeQWithSub('q1', SurveyLayer.structure, 'role_expect'),
        makeQWithSub('q2', SurveyLayer.culture, 'trust'),
        makeQWithSub('q3', SurveyLayer.activity, 'goal_alignment'),
      ];
      final answers = {'q1': 4, 'q2': 3, 'q3': 5};
      final result = buildSubScoresMap(answers, questions)!;
      expect((result['role_expect'] as Map)['layer'], 'STRUCTURE');
      expect((result['role_expect'] as Map)['score'], 4.0);
      expect((result['trust'] as Map)['layer'], 'CULTURE');
      expect((result['trust'] as Map)['score'], 3.0);
      expect((result['goal_alignment'] as Map)['layer'], 'ACTIVITY');
      expect((result['goal_alignment'] as Map)['score'], 5.0);
    });

    test('averages multiple answers for same sub-component to 1dp', () {
      final questions = [
        makeQWithSub('q1', SurveyLayer.structure, 'collab_rules'),
        makeQWithSub('q2', SurveyLayer.structure, 'collab_rules'),
        makeQWithSub('q3', SurveyLayer.structure, 'collab_rules'),
      ];
      // avg = (1+2+3)/3 = 2.0
      final answers = {'q1': 1, 'q2': 2, 'q3': 3};
      final result = buildSubScoresMap(answers, questions)!;
      expect((result['collab_rules'] as Map)['score'], 2.0);
    });

    test('questions without sub_component are skipped', () {
      final questions = [
        makeQWithSub('q1', SurveyLayer.structure, null),
        makeQWithSub('q2', SurveyLayer.culture, 'trust'),
      ];
      final answers = {'q1': 5, 'q2': 4};
      final result = buildSubScoresMap(answers, questions)!;
      expect(result.containsKey('trust'), isTrue);
      expect(result.length, 1); // q1 skipped (no sub_component)
    });

    test('unanswered questions are excluded', () {
      final questions = [
        makeQWithSub('q1', SurveyLayer.structure, 'role_expect'),
        makeQWithSub('q2', SurveyLayer.structure, 'role_expect'),
      ];
      // only q1 answered
      final answers = {'q1': 4};
      final result = buildSubScoresMap(answers, questions)!;
      expect((result['role_expect'] as Map)['score'], 4.0);
    });

    test('ESI sub-components included (mirrors web)', () {
      final questions = [
        makeQWithSub('e1', SurveyLayer.esi, 'compensation_income'),
      ];
      final answers = {'e1': 3};
      final result = buildSubScoresMap(answers, questions)!;
      expect((result['compensation_income'] as Map)['layer'], 'ESI');
      expect((result['compensation_income'] as Map)['score'], 3.0);
    });

    test('returns null when no questions have sub_component', () {
      final questions = [
        makeQWithSub('q1', SurveyLayer.enps, null),
      ];
      final answers = {'q1': 9};
      final result = buildSubScoresMap(answers, questions);
      expect(result, isNull);
    });

    test('returns null when no answers match sub_component questions', () {
      final questions = [
        makeQWithSub('q1', SurveyLayer.structure, 'role_expect'),
      ];
      final answers = <String, int>{}; // no answers
      final result = buildSubScoresMap(answers, questions);
      expect(result, isNull);
    });

    test('1dp rounding: avg of (1,2) = 1.5 rounds correctly', () {
      final questions = [
        makeQWithSub('q1', SurveyLayer.structure, 'comm_channels'),
        makeQWithSub('q2', SurveyLayer.structure, 'comm_channels'),
      ];
      final answers = {'q1': 1, 'q2': 2}; // avg = 1.5
      final result = buildSubScoresMap(answers, questions)!;
      expect((result['comm_channels'] as Map)['score'], 1.5);
    });
  });
}
