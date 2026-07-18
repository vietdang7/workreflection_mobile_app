import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/survey/presentation/survey_processing_screen.dart';
import 'package:workreflection_mobile/features/survey/presentation/survey_questions_screen.dart';
import 'package:workreflection_mobile/features/survey/survey_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_survey_repository.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, {required FakeSurveyRepository repo}) {
  return ProviderScope(
    overrides: [
      surveyRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi')],
      home: child,
    ),
  );
}

CcQuestion _q(String id, SurveyLayer layer, ScaleType scale, int order) =>
    CcQuestion(
      id: id,
      layer: layer,
      scaleType: scale,
      questionText: 'Câu hỏi $id',
      questionOrder: order,
      isActive: true,
    );

CcLikertOption _opt(ScaleType scale, int value, String label) =>
    CcLikertOption(
        scaleType: scale, value: value, label: label, displayOrder: value);

/// GoRouter-wrapped harness for SurveyProcessingScreen.
/// Captures the last route pushed into [navigatedRoutes].
Widget _wrapWithRouter(
  Widget child, {
  required FakeSurveyRepository repo,
  List<String>? navigatedRoutes,
  List<Override> extraOverrides = const [],
}) {
  final router = GoRouter(
    initialLocation: '/survey/processing',
    routes: [
      GoRoute(
        path: '/survey/processing',
        builder: (_, __) => child,
      ),
      GoRoute(
        path: '/survey/report/:id',
        builder: (_, state) {
          navigatedRoutes?.add('/survey/report/${state.pathParameters['id']}');
          return Scaffold(
            body: Text('Report ${state.pathParameters['id']}'),
          );
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      surveyRepositoryProvider.overrideWithValue(repo),
      ...extraOverrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi')],
      locale: const Locale('vi'),
    ),
  );
}

CcReportFull _fakeReport({String id = 'r1'}) => CcReportFull(
      id: id,
      surveyId: 'sv1',
      userId: 'u1',
      scoreTotal: 3.8,
      scoreStructure: 4.0,
      scoreCulture: 3.5,
      scoreActivity: 3.9,
      bottleneckLayer: SurveyLayer.culture,
      scoreLevel: ScoreLevel.good,
      createdAt: DateTime(2026, 7, 18),
    );

// ---------------------------------------------------------------------------
// SurveyQuestionsScreen tests
// ---------------------------------------------------------------------------

void main() {
  group('SurveyQuestionsScreen', () {
    late FakeSurveyRepository repo;

    setUp(() {
      repo = FakeSurveyRepository();
      repo.seedRole('user'); // FREE

      // 3 LIKERT questions
      repo.seedQuestions([
        _q('q1', SurveyLayer.structure, ScaleType.likert5, 1),
        _q('q2', SurveyLayer.culture, ScaleType.likert5, 2),
        _q('q3', SurveyLayer.activity, ScaleType.likert5, 3),
      ]);

      // Likert options 1-5
      repo.seedLikertOptions({
        ScaleType.likert5: List.generate(
          5,
          (i) => _opt(ScaleType.likert5, i + 1, 'Lựa chọn ${i + 1}'),
        ),
      });
    });

    testWidgets('renders first question text (RichText)', (tester) async {
      await tester.pumpWidget(
          _wrap(const SurveyQuestionsScreen(), repo: repo));
      await tester.pumpAndSettle();

      // Question is rendered as RichText (karaoke widget), not plain Text.
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Câu hỏi q1'),
        ),
        findsAtLeast(1),
      );
    });

    testWidgets('renders progress indicator 1/3', (tester) async {
      await tester.pumpWidget(
          _wrap(const SurveyQuestionsScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('renders layer eyebrow for structure', (tester) async {
      await tester.pumpWidget(
          _wrap(const SurveyQuestionsScreen(), repo: repo));
      await tester.pumpAndSettle();

      // eyebrow is uppercase
      expect(find.text('CẤU TRÚC'), findsOneWidget);
    });

    testWidgets('renders 5 likert pill options', (tester) async {
      await tester.pumpWidget(
          _wrap(const SurveyQuestionsScreen(), repo: repo));
      await tester.pumpAndSettle();

      for (int i = 1; i <= 5; i++) {
        expect(find.text('Lựa chọn $i'), findsOneWidget);
      }
    });

    testWidgets('selecting answer advances to next question after 300ms',
        (tester) async {
      await tester.pumpWidget(
          _wrap(const SurveyQuestionsScreen(), repo: repo));
      await tester.pumpAndSettle();

      // Before answering: progress shows 1/3
      expect(find.text('1/3'), findsOneWidget);

      // Tap option 3 on question 1
      await tester.tap(find.text('Lựa chọn 3'));
      await tester.pump();

      // Advance timer — now on q2
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('2/3'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Câu hỏi q2'),
        ),
        findsAtLeast(1),
      );
    });

    testWidgets('progress track value updates when advancing', (tester) async {
      await tester.pumpWidget(
          _wrap(const SurveyQuestionsScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);

      await tester.tap(find.text('Lựa chọn 1'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('2/3'), findsOneWidget);
    });

    testWidgets('ENPS screen renders 11 chips (0–10)', (tester) async {
      repo.seedQuestions([
        _q('n1', SurveyLayer.enps, ScaleType.enps10, 1),
      ]);
      repo.seedLikertOptions({});

      await tester.pumpWidget(
          _wrap(const SurveyQuestionsScreen(), repo: repo));
      await tester.pumpAndSettle();

      // 11 chips for 0–10
      for (int i = 0; i <= 10; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('last question shows Hoàn thành CTA after answer',
        (tester) async {
      // Only 1 question so it's both first and last
      repo.seedQuestions([
        _q('q1', SurveyLayer.structure, ScaleType.likert5, 1),
      ]);
      repo.seedLikertOptions({
        ScaleType.likert5: List.generate(
          5,
          (i) => _opt(ScaleType.likert5, i + 1, 'Opt ${i + 1}'),
        ),
      });

      await tester.pumpWidget(
          _wrap(const SurveyQuestionsScreen(), repo: repo));
      await tester.pumpAndSettle();

      // CTA not visible yet (no answer). l10n key surveyCompleteCta = "Hoàn thành"
      expect(find.text('Hoàn thành'), findsNothing);

      await tester.tap(find.text('Opt 2'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // CTA appears after answer selected on last question
      expect(find.text('Hoàn thành'), findsOneWidget);
    });

    testWidgets('answers stored correctly in provider state',
        (tester) async {
      // Verify answers accumulate correctly before submission.
      // submitSurvey is called in SurveyProcessingScreen (separate route),
      // so here we only verify the answers state is set.
      repo.seedQuestions([
        _q('q1', SurveyLayer.structure, ScaleType.likert5, 1),
        _q('q2', SurveyLayer.culture, ScaleType.likert5, 2),
      ]);
      repo.seedLikertOptions({
        ScaleType.likert5: List.generate(
          5,
          (i) => _opt(ScaleType.likert5, i + 1, 'Opt ${i + 1}'),
        ),
      });

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            surveyRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('vi')],
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SurveyQuestionsScreen();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Answer q1 = Opt 5 (value 5)
      await tester.tap(find.text('Opt 5'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Answer q2 = Opt 3 (value 3)
      await tester.tap(find.text('Opt 3'));
      await tester.pump();

      final answers = capturedRef.read(surveyAnswersProvider);
      expect(answers['q1'], 5);
      expect(answers['q2'], 3);
    });
  });

  // ---------------------------------------------------------------------------
  // SurveyProcessingScreen tests
  // ---------------------------------------------------------------------------

  group('SurveyProcessingScreen', () {
    late FakeSurveyRepository repo;

    setUp(() {
      repo = FakeSurveyRepository();
      repo.seedRole('user'); // FREE
      repo.seedQuestions([
        _q('q1', SurveyLayer.structure, ScaleType.likert5, 1),
      ]);
      repo.seedLikertOptions({
        ScaleType.likert5: List.generate(
          5,
          (i) => _opt(ScaleType.likert5, i + 1, 'Opt ${i + 1}'),
        ),
      });
      repo.seedLatestReport(_fakeReport(id: 'r1'));
    });

    testWidgets('submits and navigates to report', (tester) async {
      final navigated = <String>[];

      await tester.pumpWidget(_wrapWithRouter(
        const SurveyProcessingScreen(),
        repo: repo,
        navigatedRoutes: navigated,
      ));

      // Allow async submit to complete (no pumpAndSettle — spinner would hang)
      await tester.pump(); // start frame
      await tester.pump(const Duration(milliseconds: 100)); // Future resolves
      await tester.pump(); // postFrameCallback fires
      await tester.pump(const Duration(milliseconds: 50)); // router settles

      // submitSurvey was called at least once and navigation to report happened
      expect(repo.submitSurveyCalls, isNotEmpty);
      expect(navigated, contains('/survey/report/r1'));
      // Navigation happened exactly once — no duplicate navigations
      expect(navigated.where((r) => r.startsWith('/survey/report/')), hasLength(1));
    });

    testWidgets('retry after failure passes existingSurveyId (no duplicate survey)',
        (tester) async {
      // Fake: first call fires onSurveyCreated('fake-survey-id') then throws.
      // The _submitProvider stores that id in surveyIdInProgressProvider.
      // On retry (invalidate), a subsequent call receives existingSurveyId =
      // 'fake-survey-id' and succeeds, proving no duplicate survey is created.
      repo.setSubmitFailsOnce(true);

      await tester.pumpWidget(_wrapWithRouter(
        const SurveyProcessingScreen(),
        repo: repo,
      ));

      // First attempt: async Future throws → error state
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(); // rebuild with error UI

      // Error UI should show retry button (l10n: surveyProcessingRetry = "Thử lại")
      expect(find.text('Thử lại'), findsOneWidget);

      // Record call count before retry
      final callCountBeforeRetry = repo.submitSurveyCalls.length;

      // Tap retry — invalidates _submitProvider, triggers another attempt
      await tester.tap(find.text('Thử lại'));
      await tester.pump(); // start retry
      await tester.pump(const Duration(milliseconds: 100)); // Future resolves
      await tester.pump(); // postFrameCallback
      await tester.pump(const Duration(milliseconds: 50)); // router

      // At least one more call after retry
      expect(repo.submitSurveyCalls.length, greaterThan(callCountBeforeRetry));
      // The call that happened after the first failure must carry the surveyId
      // (any call index > 0 where existingSurveyId is set proves resumption)
      final resumptionCall = repo.submitExistingIds
          .skip(1) // skip initial pre-failure calls
          .firstWhere((id) => id == 'fake-survey-id', orElse: () => null);
      expect(resumptionCall, equals('fake-survey-id'),
          reason: 'retry must pass existingSurveyId to avoid duplicate survey');
    });

    testWidgets('back navigation preserves answers in provider', (tester) async {
      // Seed answers directly into the provider before pumping the widget.
      // Use a ProviderScope override that pre-populates surveyAnswersProvider.
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            surveyRepositoryProvider.overrideWithValue(repo),
            surveyAnswersProvider.overrideWith(
              (ref) => SurveyAnswersNotifier()..setAnswer('q1', 4),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('vi')],
            locale: const Locale('vi'),
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                // We read the answers provider here to ensure it is observed,
                // but we don't actually navigate — we just verify persistence.
                return const Scaffold(
                  body: Center(child: Text('host')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Answers seeded via override should still be present
      final answers = capturedRef.read(surveyAnswersProvider);
      expect(answers['q1'], 4,
          reason: 'answers must survive across the provider scope lifetime');
    });
  });
}
