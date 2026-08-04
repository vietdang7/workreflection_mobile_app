// Widget tests for WorkshopSurveyResultsScreen — Phase 5 Task 7.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/data/workshop_repository.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';
import 'package:workreflection_mobile/features/workshops/presentation/workshop_survey_results_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_workshop_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(
  FakeWorkshopRepository repo, {
  String locale = 'vi',
  String workshopId = 'ws-1',
}) {
  return ProviderScope(
    overrides: [
      workshopRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      builder: wrTextScaleBuilder,
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi'), Locale('en')],
      home: WorkshopSurveyResultsScreen(workshopId: workshopId),
    ),
  );
}

WorkshopSurveyResults _results({
  Map<String, double>? layerScores,
  double total = 3.8,
  int responseCount = 10,
}) =>
    WorkshopSurveyResults(
      layerScores: layerScores ??
          {
            'STRUCTURE': 4.0,
            'CULTURE': 3.5,
            'ACTIVITY': 3.8,
          },
      total: total,
      responseCount: responseCount,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WorkshopSurveyResultsScreen', () {
    late FakeWorkshopRepository repo;

    setUp(() {
      repo = FakeWorkshopRepository();
    });

    testWidgets('shows not-found when no completed survey exists',
        (tester) async {
      // No submitted survey → getCompletedSurveyId returns null.
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ws_results_not_found')), findsOneWidget);
    });

    testWidgets('shows not-found when getSurveyResults returns null',
        (tester) async {
      repo.seedSubmittedSurvey('ws-1');
      // _surveyResults not seeded → getSurveyResults returns null.
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ws_results_not_found')), findsOneWidget);
    });

    testWidgets('renders total score when results available', (tester) async {
      repo.seedSubmittedSurvey('ws-1');
      repo.seedSurveyResults(_results(total: 4.1));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ws_results_total')), findsOneWidget);
      expect(find.text('4.1'), findsOneWidget);
    });

    testWidgets('renders response count', (tester) async {
      repo.seedSubmittedSurvey('ws-1');
      repo.seedSurveyResults(_results(responseCount: 15));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // VI locale: "15 câu trả lời"
      expect(find.text('15 câu trả lời'), findsOneWidget);
    });

    testWidgets('renders response count in EN locale', (tester) async {
      repo.seedSubmittedSurvey('ws-1');
      repo.seedSurveyResults(_results(responseCount: 8));

      await tester.pumpWidget(_wrap(repo, locale: 'en'));
      await tester.pumpAndSettle();

      expect(find.text('8 responses'), findsOneWidget);
    });

    testWidgets('renders layer names in layer score rows', (tester) async {
      repo.seedSubmittedSurvey('ws-1');
      repo.seedSurveyResults(_results(
        layerScores: {
          'STRUCTURE': 4.2,
          'CULTURE': 3.1,
          'ACTIVITY': 3.8,
        },
        total: 3.9,
      ));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('STRUCTURE'), findsOneWidget);
      expect(find.text('CULTURE'), findsOneWidget);
      expect(find.text('ACTIVITY'), findsOneWidget);
    });

    testWidgets('renders engagement bar', (tester) async {
      repo.seedSubmittedSurvey('ws-1');
      repo.seedSurveyResults(_results(total: 4.0)); // 4.0/5.0 = 80%

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('ws_results_engagement_bar')), findsOneWidget);
      // 80% engagement text should appear
      expect(find.textContaining('80%'), findsOneWidget);
    });

    testWidgets('error from repo shows not-found widget', (tester) async {
      repo.seedSubmittedSurvey('ws-1');
      repo.nextError = Exception('network error');

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ws_results_not_found')), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Unit tests for WorkshopSurveyResults scoring logic
  // -------------------------------------------------------------------------

  group('WorkshopSurveyResults model', () {
    test('holds layerScores, total and responseCount', () {
      const r = WorkshopSurveyResults(
        layerScores: {'STRUCTURE': 4.0, 'CULTURE': 3.5, 'ACTIVITY': 3.0},
        total: 3.7,
        responseCount: 12,
      );
      expect(r.layerScores['STRUCTURE'], 4.0);
      expect(r.total, 3.7);
      expect(r.responseCount, 12);
    });
  });

  // -------------------------------------------------------------------------
  // Unit tests for FakeWorkshopRepository cancel + results
  // -------------------------------------------------------------------------

  group('FakeWorkshopRepository — new methods', () {
    late FakeWorkshopRepository repo;

    setUp(() => repo = FakeWorkshopRepository());

    test('getCompletedSurveyId returns null when no submitted survey', () async {
      final id = await repo.getCompletedSurveyId('ws-1');
      expect(id, isNull);
    });

    test('getCompletedSurveyId returns id after seedSubmittedSurvey', () async {
      repo.seedSubmittedSurvey('ws-1');
      final id = await repo.getCompletedSurveyId('ws-1');
      expect(id, isNotNull);
      expect(id, contains('ws-1'));
    });

    test('getSurveyResults returns null when not seeded', () async {
      final r = await repo.getSurveyResults('any-id');
      expect(r, isNull);
    });

    test('getSurveyResults returns seeded results', () async {
      final results = _results(total: 3.5, responseCount: 5);
      repo.seedSurveyResults(results);
      final r = await repo.getSurveyResults('any-id');
      expect(r, isNotNull);
      expect(r!.total, 3.5);
      expect(r.responseCount, 5);
    });

    test('cancelRegistration records call and sets status to cancelled',
        () async {
      repo.seedWorkshops([]);
      repo.seedRegistration(WorkshopRegistration(
        id: 'reg-1',
        workshopId: 'ws-1',
        userId: 'u-1',
        status: 'registered',
        attended: false,
      ));

      await repo.cancelRegistration('reg-1', 'ws-1');

      expect(repo.cancelRegistrationCalls, hasLength(1));
      expect(repo.cancelRegistrationCalls.first, ('reg-1', 'ws-1'));

      // Registration should now be cancelled.
      final reg = await repo.getMyRegistration('ws-1'); // filters cancelled
      expect(reg, isNull);
    });
  });
}
