// Video Report — VideoSceneView widget tests.
// Proves all 10 scenes render without throwing at progress 0.0 / 0.5 / 1.0.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/video_report/models/video_report_models.dart';
import 'package:workreflection_mobile/features/video_report/presentation/scenes/video_scene_view.dart';

CcReportFull _premiumReport() => CcReportFull(
      id: 'r1',
      surveyId: 's1',
      userId: 'u1',
      scoreTotal: 4.2,
      scoreStructure: 4.0,
      scoreCulture: 4.5,
      scoreActivity: 3.8,
      scoreEsi: 3.5,
      scoreEnps: 20,
      bottleneckLayer: SurveyLayer.activity,
      scoreLevel: ScoreLevel.good,
      subScores: <String, dynamic>{
        'role_expectations': {'layer': 'STRUCTURE', 'score': 3.0},
        'collab_rules': {'layer': 'STRUCTURE', 'score': 4.2},
        'comm_channels': {'layer': 'STRUCTURE', 'score': 4.5},
        'trust': {'layer': 'CULTURE', 'score': 4.6},
        'psych_safety': {'layer': 'CULTURE', 'score': 4.4},
        'goal_alignment': {'layer': 'ACTIVITY', 'score': 3.5},
        'execution_rhythm': {'layer': 'ACTIVITY', 'score': 4.0},
      },
      createdAt: DateTime(2026, 7, 20),
    );

void main() {
  group('VideoSceneView renders every scene at progress 0 / 0.5 / 1', () {
    for (final id in VideoSceneId.values) {
      for (final p in <double>[0.0, 0.5, 1.0]) {
        testWidgets('scene ${id.name} @ progress $p does not throw',
            (tester) async {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: VideoSceneView(
                sceneId: id,
                report: _premiumReport(),
                progress: p,
                locale: 'vi',
                userName: 'Duy Thong',
              ),
            ),
          ));
          await tester.pump();

          expect(find.byType(VideoSceneView), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('overall scene @ progress 1.0 shows total score text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VideoSceneView(
          sceneId: VideoSceneId.overall,
          report: _premiumReport(),
          progress: 1.0,
          locale: 'vi',
        ),
      ),
    ));
    await tester.pump();

    // scoreTotal 4.2 → "4.2"
    expect(find.textContaining('4.2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // --- Content assertions (not smoke tests) --------------------------------

  testWidgets(
      'structure scene renders a sub-score row from the canonical '
      '{sub_component: {layer, score}} shape', (tester) async {
    // Locks the sub_scores shape: _subRows reads val["layer"]/val["score"],
    // pretties the key ("role_expect" -> "Role Expect") and emits the score
    // via _LayerBar as value.toStringAsFixed(1) -> "3.7".
    final report = CcReportFull(
      id: 'r-sub',
      surveyId: 's-sub',
      userId: 'u-sub',
      scoreTotal: 3.7,
      scoreStructure: 3.7,
      scoreCulture: 3.7,
      scoreActivity: 3.7,
      scoreEsi: 3.7,
      scoreEnps: 10,
      bottleneckLayer: SurveyLayer.structure,
      scoreLevel: ScoreLevel.good,
      subScores: <String, dynamic>{
        'role_expect': {'layer': 'STRUCTURE', 'score': 3.7},
      },
      createdAt: DateTime(2026, 7, 20),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VideoSceneView(
          sceneId: VideoSceneId.structure,
          report: report,
          progress: 1.0,
          locale: 'vi',
        ),
      ),
    ));
    await tester.pump();

    // Pretty label of the sub-component key.
    expect(find.textContaining('Role Expect'), findsOneWidget);
    // The sub score value (3.7) rendered by the sub _LayerBar.
    expect(find.textContaining('3.7'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottleneck scene renders the Vietnamese CULTURE layer name',
      (tester) async {
    // _layerName("CULTURE") in vi -> "Văn hóa".
    final report = CcReportFull(
      id: 'r-bn',
      surveyId: 's-bn',
      userId: 'u-bn',
      scoreTotal: 3.0,
      scoreStructure: 3.0,
      scoreCulture: 2.0,
      scoreActivity: 3.0,
      scoreEsi: 3.0,
      scoreEnps: 0,
      bottleneckLayer: SurveyLayer.culture,
      scoreLevel: ScoreLevel.warning,
      subScores: null,
      createdAt: DateTime(2026, 7, 20),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VideoSceneView(
          sceneId: VideoSceneId.bottleneck,
          report: report,
          progress: 1.0,
          locale: 'vi',
        ),
      ),
    ));
    await tester.pump();

    expect(find.textContaining('Văn hóa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress drives the bar fill (widthFactor grows 0.0 -> 1.0)',
      (tester) async {
    // _LayerBar fill = (value/5).clamp * progress.clamp, rendered as a
    // FractionallySizedBox.widthFactor. So max widthFactor at progress 1.0
    // must be strictly greater than at progress 0.0 (where it is 0).
    Future<double> maxWidthFactorAt(double progress) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: VideoSceneView(
            sceneId: VideoSceneId.overall,
            report: _premiumReport(),
            progress: progress,
            locale: 'vi',
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final boxes = tester.widgetList<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(boxes, isNotEmpty);
      return boxes
          .map((b) => b.widthFactor ?? 0.0)
          .reduce((a, b) => a > b ? a : b);
    }

    final atZero = await maxWidthFactorAt(0.0);
    final atFull = await maxWidthFactorAt(1.0);

    expect(atZero, 0.0);
    expect(atFull, greaterThan(atZero));
  });

  testWidgets('scenes with null esi/enps render safely', (tester) async {
    final report = CcReportFull(
      id: 'r2',
      surveyId: 's2',
      userId: 'u2',
      scoreTotal: 2.1,
      scoreStructure: 2.0,
      scoreCulture: 2.2,
      scoreActivity: 2.1,
      scoreEsi: null,
      scoreEnps: null,
      bottleneckLayer: SurveyLayer.structure,
      scoreLevel: ScoreLevel.critical,
      subScores: null,
      createdAt: DateTime(2026, 7, 20),
    );

    for (final id in <VideoSceneId>[
      VideoSceneId.esi,
      VideoSceneId.enps,
      VideoSceneId.structure,
      VideoSceneId.overall,
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: VideoSceneView(
            sceneId: id,
            report: report,
            progress: 0.0,
            locale: 'en',
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
