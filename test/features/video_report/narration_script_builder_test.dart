import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/video_report/logic/narration_script_builder.dart';
import 'package:workreflection_mobile/features/video_report/models/video_report_models.dart';

CcReportFull _report({
  double esi = 0, int? enps, SurveyType type = SurveyType.premium,
}) => CcReportFull(
  id: 'r1', surveyId: 's1', userId: 'u1',
  scoreTotal: 3.4, scoreStructure: 3.2, scoreCulture: 3.6, scoreActivity: 3.1,
  scoreEsi: esi == 0 ? null : esi, scoreEnps: enps,
  bottleneckLayer: SurveyLayer.activity, scoreLevel: ScoreLevel.warning,
  subScores: const {}, selectedNarrativeVariants: null,
  createdAt: DateTime(2026, 7, 20),
);

void main() {
  const builder = NarrationScriptBuilder();

  test('premium with esi+enps produces all 10 scenes in order', () {
    final scenes = builder.build(
      report: _report(esi: 3.5, enps: 20),
      narratives: const [], userName: 'An', locale: 'vi', surveyType: SurveyType.premium,
    );
    expect(scenes.map((s) => s.id).toList(), [
      VideoSceneId.intro, VideoSceneId.overall, VideoSceneId.structure,
      VideoSceneId.culture, VideoSceneId.activity, VideoSceneId.esi,
      VideoSceneId.enps, VideoSceneId.bottleneck, VideoSceneId.recommendations,
      VideoSceneId.closing,
    ]);
  });

  test('premium without esi/enps omits those two scenes', () {
    final scenes = builder.build(
      report: _report(), narratives: const [], userName: 'An', locale: 'vi',
      surveyType: SurveyType.premium,
    );
    expect(scenes.any((s) => s.id == VideoSceneId.esi), isFalse);
    expect(scenes.any((s) => s.id == VideoSceneId.enps), isFalse);
    expect(scenes.length, 8);
  });

  test('free report omits layer-detail scenes', () {
    final scenes = builder.build(
      report: _report(type: SurveyType.free), narratives: const [],
      userName: 'An', locale: 'vi', surveyType: SurveyType.free,
    );
    expect(scenes.map((s) => s.id).toList(), [
      VideoSceneId.intro, VideoSceneId.overall, VideoSceneId.bottleneck,
      VideoSceneId.recommendations, VideoSceneId.closing,
    ]);
  });

  test('every scene has non-empty text', () {
    final scenes = builder.build(
      report: _report(esi: 3.5, enps: 20), narratives: const [],
      userName: 'An', locale: 'vi', surveyType: SurveyType.premium,
    );
    expect(scenes.every((s) => s.text.trim().isNotEmpty), isTrue);
  });
}
