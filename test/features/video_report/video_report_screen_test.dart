// Video Report — player screen tests.
//
// Uses a FakeVideoAudioController (no real just_audio, so no platform channels)
// to drive the audio position stream. Verifies that:
//   1. the player renders a VideoSceneView + a play/pause control once data is
//      available;
//   2. pushing a position inside the second scene switches the rendered scene;
//   3. the subtitle overlay shows the active cue's text.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/survey_repository.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/features/video_report/data/video_audio_controller.dart';
import 'package:workreflection_mobile/features/video_report/data/video_report_repository.dart';
import 'package:workreflection_mobile/features/video_report/models/video_report_models.dart';
import 'package:workreflection_mobile/features/video_report/presentation/scenes/video_scene_view.dart';
import 'package:workreflection_mobile/features/video_report/presentation/video_report_screen.dart';
import 'package:workreflection_mobile/features/video_report/video_report_providers.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeVideoAudioController implements VideoAudioController {
  final positionController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  bool _playing = false;

  int loadCalls = 0;
  int playCalls = 0;
  final List<Duration> seeks = [];
  bool disposed = false;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  bool get playing => _playing;

  @override
  Future<void> load(String url, Map<String, String> headers) async {
    loadCalls++;
  }

  @override
  Future<void> play() async {
    playCalls++;
    _playing = true;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    positionController.add(position);
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await positionController.close();
    await _playingController.close();
  }
}

class _FakeVideoReportRepository implements VideoReportRepository {
  @override
  Map<String, String> audioHeaders() => const {};

  @override
  String proxiedAudioUrl(String rawAudioUrl) => rawAudioUrl;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeSurveyRepository implements SurveyRepository {
  _FakeSurveyRepository(this._report);

  final CcReportFull _report;

  @override
  Future<CcReportFull?> getReport(String reportId) async => _report;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

CcReportFull _premiumReport() => CcReportFull(
      id: 'report-1',
      surveyId: 'survey-1',
      userId: 'user-1',
      scoreTotal: 3.8,
      scoreStructure: 3.5,
      scoreCulture: 4.0,
      scoreActivity: 3.9,
      scoreEsi: 4.1,
      scoreEnps: 20,
      bottleneckLayer: SurveyLayer.structure,
      scoreLevel: ScoreLevel.good,
      subScores: const {
        'sub_a': {'layer': 'STRUCTURE', 'score': 3.5},
      },
      createdAt: DateTime(2026, 7, 20),
    );

VideoReportData _cannedData() => const VideoReportData(
      scenes: [
        TimedScene(
          id: VideoSceneId.intro,
          text: 'Intro scene text',
          startMs: 0,
          endMs: 2000,
        ),
        TimedScene(
          id: VideoSceneId.overall,
          text: 'Overall scene text',
          startMs: 2000,
          endMs: 5000,
        ),
      ],
      cues: [
        SubtitleCue(text: 'First cue line.', startMs: 0, endMs: 2000),
        SubtitleCue(text: 'Second cue line.', startMs: 2000, endMs: 5000),
      ],
      audioUrl: 'x',
      audioDurationMs: 5000,
    );

Widget _buildApp({
  required FakeVideoAudioController fake,
  required VideoReportData data,
}) {
  return ProviderScope(
    overrides: [
      videoReportDataProvider('report-1').overrideWith((ref) async => data),
      // Drive the fake through the REAL autoDispose lifecycle so its dispose()
      // fires only when the screen's subscription closes (on unmount).
      videoAudioControllerProvider.overrideWith((ref) {
        ref.onDispose(fake.dispose);
        return fake;
      }),
      videoReportRepositoryProvider
          .overrideWithValue(_FakeVideoReportRepository()),
      surveyRepositoryProvider
          .overrideWithValue(_FakeSurveyRepository(_premiumReport())),
      appLocaleProvider.overrideWith((ref) => 'vi'),
      ccProfileProvider.overrideWith(
        (ref) => Future.value(<String, dynamic>{
          'full_name': 'Test User',
          'email': 'test@example.com',
        }),
      ),
    ],
    child: const MaterialApp(
      home: VideoReportScreen(reportId: 'report-1'),
    ),
  );
}

void main() {
  testWidgets('renders VideoSceneView and a play/pause control once data ready',
      (tester) async {
    final fake = FakeVideoAudioController();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildApp(fake: fake, data: _cannedData()));
    await tester.pumpAndSettle();

    expect(find.byType(VideoSceneView), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    // A play/pause icon button is present.
    expect(
      find.byWidgetPredicate((w) =>
          w is IconButton &&
          (w.icon is Icon) &&
          ((w.icon as Icon).icon == Icons.pause ||
              (w.icon as Icon).icon == Icons.play_arrow)),
      findsOneWidget,
    );

    // load + play were each called exactly once.
    expect(fake.loadCalls, 1);
    expect(fake.playCalls, 1);
  });

  testWidgets('position inside second scene renders the overall scene',
      (tester) async {
    final fake = FakeVideoAudioController();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildApp(fake: fake, data: _cannedData()));
    await tester.pumpAndSettle();

    // Initially the intro scene.
    expect(
      tester.widget<VideoSceneView>(find.byType(VideoSceneView)).sceneId,
      VideoSceneId.intro,
    );

    fake.positionController.add(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();

    expect(
      tester.widget<VideoSceneView>(find.byType(VideoSceneView)).sceneId,
      VideoSceneId.overall,
    );
  });

  testWidgets('subtitle overlay shows the active cue text', (tester) async {
    final fake = FakeVideoAudioController();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildApp(fake: fake, data: _cannedData()));
    await tester.pumpAndSettle();

    fake.positionController.add(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();

    expect(find.text('Second cue line.'), findsOneWidget);
  });

  testWidgets(
      'controller lives while screen is mounted and is disposed on unmount',
      (tester) async {
    final fake = FakeVideoAudioController();
    addTearDown(fake.dispose);

    await tester.pumpWidget(_buildApp(fake: fake, data: _cannedData()));
    await tester.pump();

    // The screen holds a manual subscription, so the autoDispose provider (and
    // thus the controller) must stay alive while mounted.
    expect(fake.disposed, isFalse);

    // Unmount the screen by replacing it with an unrelated widget. Closing the
    // last subscription triggers autoDispose → onDispose(fake.dispose).
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(fake.disposed, isTrue);
  });
}
