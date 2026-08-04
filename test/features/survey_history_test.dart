// Widget tests for SurveyHistoryScreen — Phase 4 Task 3.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/survey/presentation/survey_history_screen.dart';
import 'package:workreflection_mobile/features/survey/survey_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_survey_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(FakeSurveyRepository repo) {
  return ProviderScope(
    overrides: [
      surveyRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      builder: wrTextScaleBuilder,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('vi')],
      home: SurveyHistoryScreen(),
    ),
  );
}

CcReportSummary _summary({
  String id = 'r1',
  String surveyId = 's1',
  double total = 3.8,
  ScoreLevel level = ScoreLevel.good,
  bool isPremium = false,
  DateTime? createdAt,
}) =>
    CcReportSummary(
      id: id,
      surveyId: surveyId,
      createdAt: createdAt ?? DateTime(2026, 7, 1),
      scoreTotal: total,
      scoreLevel: level,
      scoreEsi: isPremium ? 3.5 : null,
      scoreEnps: isPremium ? 20 : null,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SurveyHistoryScreen', () {
    late FakeSurveyRepository repo;

    setUp(() {
      repo = FakeSurveyRepository();
    });

    testWidgets('renders list rows from fake data', (tester) async {
      repo.seedReportSummaries([
        _summary(id: 'r1', total: 4.2, level: ScoreLevel.high),
        _summary(id: 'r2', total: 3.0, level: ScoreLevel.warning),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('survey_history_row_r1')), findsOneWidget);
      expect(find.byKey(const Key('survey_history_row_r2')), findsOneWidget);
      // Scores shown
      expect(find.text('4.2'), findsOneWidget);
      expect(find.text('3.0'), findsOneWidget);
    });

    testWidgets('free chip shown for non-premium report', (tester) async {
      repo.seedReportSummaries([_summary(isPremium: false)]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Free'), findsOneWidget);
    });

    testWidgets('premium chip shown for premium report', (tester) async {
      repo.seedReportSummaries([_summary(isPremium: true)]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Premium'), findsOneWidget);
    });

    testWidgets('shows empty state when no reports', (tester) async {
      // repo.seedReportSummaries is not called — defaults to empty

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có khảo sát nào'), findsOneWidget);
      expect(find.text('Bắt đầu khảo sát'), findsOneWidget);
    });

    testWidgets('shows error state and retry button on failure', (tester) async {
      repo.setMyReportsError(Exception('network error'));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Seed data so retry succeeds
      repo.setMyReportsError(null);
      repo.seedReportSummaries([_summary()]);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('survey_history_row_r1')), findsOneWidget);
    });

    testWidgets('tap row key exists and row is GestureDetector',
        (tester) async {
      repo.seedReportSummaries([_summary(id: 'r42')]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Row is rendered with the correct key.
      final row = find.byKey(const Key('survey_history_row_r42'));
      expect(row, findsOneWidget);

      // The row widget is a GestureDetector (tappable).
      expect(
        tester.widget(row),
        isA<GestureDetector>(),
      );
    });

    testWidgets('date formats correctly as dd/MM/yyyy', (tester) async {
      repo.seedReportSummaries([
        _summary(createdAt: DateTime(2026, 3, 5)),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('05/03/2026'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Provider unit test
  // ---------------------------------------------------------------------------

  group('myReportsProvider', () {
    test('returns list from repository', () async {
      final repo = FakeSurveyRepository();
      repo.seedReportSummaries([
        _summary(id: 'r1'),
        _summary(id: 'r2'),
      ]);

      final container = ProviderContainer(
        overrides: [surveyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container.read(myReportsProvider.future);
      expect(result.length, 2);
      expect(result.first.id, 'r1');
    });

    test('propagates repository error', () async {
      final repo = FakeSurveyRepository();
      repo.setMyReportsError(Exception('boom'));

      final container = ProviderContainer(
        overrides: [surveyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(myReportsProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });
}
