// Video Report — orchestration provider tests.
//
// Verifies the cache-hit path (reuse cached audio/srt, never re-generate) and
// the cache-miss path (create + wait once). Scenes are always built
// deterministically from the report, so a canned CcReportFull drives them.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/survey_repository.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/features/survey/survey_providers.dart';
import 'package:workreflection_mobile/features/video_report/data/video_report_repository.dart';
import 'package:workreflection_mobile/features/video_report/video_report_providers.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeVideoReportRepository implements VideoReportRepository {
  _FakeVideoReportRepository({
    required this.completedJob,
    required this.createResult,
  });

  final RawVideoJob? completedJob;
  final RawVideoJob createResult;
  bool createAndWaitCalled = false;

  @override
  Future<RawVideoJob?> findCompletedJob(String reportId) async => completedJob;

  @override
  Future<RawVideoJob> createAndWait({
    required String reportId,
    required String userId,
    required String text,
    required Object narrationScript,
    required String language,
  }) async {
    createAndWaitCalled = true;
    return createResult;
  }

  @override
  String proxiedAudioUrl(String rawAudioUrl) => 'PROXY:$rawAudioUrl';

  @override
  Map<String, String> audioHeaders() => const {};
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

const _twoCueSrt = '''
1
00:00:00,000 --> 00:00:02,500
First cue line.

2
00:00:02,500 --> 00:00:05,000
Second cue line.
''';

ProviderContainer _makeContainer({
  required VideoReportRepository videoRepo,
  required SurveyRepository surveyRepo,
}) {
  return ProviderContainer(
    overrides: [
      videoReportRepositoryProvider.overrideWithValue(videoRepo),
      surveyRepositoryProvider.overrideWithValue(surveyRepo),
      narrativesProvider.overrideWith((ref) => Future.value(<CcNarrative>[])),
      appLocaleProvider.overrideWith((ref) => 'vi'),
      ccProfileProvider.overrideWith(
        (ref) => Future.value(<String, dynamic>{
          'full_name': 'Test User',
          'email': 'test@example.com',
        }),
      ),
    ],
  );
}

void main() {
  test('cache hit → returns assembled data and does NOT call createAndWait',
      () async {
    final videoRepo = _FakeVideoReportRepository(
      completedJob: const RawVideoJob(
        audioUrl: 'a.wav',
        srt: _twoCueSrt,
        durationMs: 5000,
      ),
      createResult:
          const RawVideoJob(audioUrl: 'unused.wav', srt: '', durationMs: 0),
    );
    final container = _makeContainer(
      videoRepo: videoRepo,
      surveyRepo: _FakeSurveyRepository(_premiumReport()),
    );
    addTearDown(container.dispose);

    final result =
        await container.read(videoReportDataProvider('report-1').future);

    expect(result.scenes, isNotEmpty);
    expect(result.scenes.first.startMs, 0);
    expect(result.scenes.last.endMs, 5000);
    expect(result.audioUrl, 'PROXY:a.wav');
    expect(result.audioDurationMs, 5000);
    expect(videoRepo.createAndWaitCalled, isFalse);
  });

  test('cache miss → calls createAndWait once', () async {
    final videoRepo = _FakeVideoReportRepository(
      completedJob: null,
      createResult:
          const RawVideoJob(audioUrl: 'b.wav', srt: '', durationMs: 8000),
    );
    final container = _makeContainer(
      videoRepo: videoRepo,
      surveyRepo: _FakeSurveyRepository(_premiumReport()),
    );
    addTearDown(container.dispose);

    final result =
        await container.read(videoReportDataProvider('report-1').future);

    expect(videoRepo.createAndWaitCalled, isTrue);
    expect(result.audioUrl, 'PROXY:b.wav');
    expect(result.audioDurationMs, 8000);
    expect(result.scenes, isNotEmpty);
    expect(result.scenes.last.endMs, 8000);
  });
}
