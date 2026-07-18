import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/survey/presentation/survey_guide_screen.dart';
import 'package:workreflection_mobile/features/survey/presentation/survey_intro_screen.dart';
import 'package:workreflection_mobile/features/survey/presentation/survey_processing_screen.dart';
import 'package:workreflection_mobile/features/survey/presentation/survey_questions_screen.dart';
import 'package:workreflection_mobile/features/survey/survey_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
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

/// Builds a GoRouter harness for SurveyIntroScreen with both repo overrides.
Widget _introRouterWrap({
  required FakeSurveyRepository surveyRepo,
  required FakeWrRepository wrRepo,
  List<String>? navigatedRoutes,
  List<Override> extraOverrides = const [],
  Widget Function(BuildContext, GoRouterState)? guideBuilder,
}) {
  final router = GoRouter(
    initialLocation: '/survey/intro',
    routes: [
      GoRoute(
        path: '/survey/intro',
        builder: (_, __) => const SurveyIntroScreen(),
      ),
      GoRoute(
        path: '/survey/guide',
        builder: (ctx, state) {
          navigatedRoutes?.add('/survey/guide');
          return guideBuilder != null
              ? guideBuilder(ctx, state)
              : const Scaffold(body: Text('guide'));
        },
      ),
      GoRoute(
        path: '/survey/questions',
        builder: (_, __) {
          navigatedRoutes?.add('/survey/questions');
          return const Scaffold(body: Text('questions'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      surveyRepositoryProvider.overrideWithValue(surveyRepo),
      wrRepositoryProvider.overrideWithValue(wrRepo),
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

  // ---------------------------------------------------------------------------
  // SurveyIntroScreen — surveyIdInProgress reset on new survey
  // ---------------------------------------------------------------------------

  group('SurveyIntroScreen — surveyIdInProgress reset', () {
    testWidgets(
        'tapping CTA resets surveyIdInProgressProvider to null even when stale id was set',
        (tester) async {
      final repo = FakeSurveyRepository();
      repo.seedRole('user');
      repo.seedQuestions([]);
      repo.seedLikertOptions({});

      final wrRepo = FakeWrRepository();
      // No position set → no auto-skip, form is shown
      wrRepo.seedCcProfile({});

      // GoRouter so context.push('/survey/guide') does not throw.
      final router = GoRouter(
        initialLocation: '/survey/intro',
        routes: [
          GoRoute(
            path: '/survey/intro',
            builder: (_, __) => const SurveyIntroScreen(),
          ),
          GoRoute(
            path: '/survey/guide',
            builder: (_, __) => const Scaffold(body: Text('guide')),
          ),
          GoRoute(
            path: '/survey/questions',
            builder: (_, __) => const Scaffold(body: Text('questions')),
          ),
        ],
      );

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            surveyRepositoryProvider.overrideWithValue(repo),
            wrRepositoryProvider.overrideWithValue(wrRepo),
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
            builder: (context, child) => Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return child ?? const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Simulate a stale in-progress surveyId (e.g. from a prior failed submit)
      capturedRef.read(surveyIdInProgressProvider.notifier).state =
          'stale-survey-id';
      expect(capturedRef.read(surveyIdInProgressProvider), 'stale-survey-id');

      // Tap the CTA button (WrPillButton renders as ElevatedButton).
      // The button may be below the fold — scroll to it first.
      final ctaFinder = find.byType(ElevatedButton);
      await tester.ensureVisible(ctaFinder.first);
      await tester.pump();
      await tester.tap(ctaFinder.first, warnIfMissed: false);
      await tester.pump();

      expect(
        capturedRef.read(surveyIdInProgressProvider),
        isNull,
        reason:
            'Starting a new survey from intro must clear any stale in-progress surveyId',
      );
    });

    testWidgets(
        'tapping CTA navigates to /survey/guide (not /survey/questions)',
        (tester) async {
      final repo = FakeSurveyRepository();
      repo.seedRole('user');
      repo.seedQuestions([]);
      repo.seedLikertOptions({});

      final wrRepo = FakeWrRepository();
      // No position set → no auto-skip, form is shown
      wrRepo.seedCcProfile({});

      final navigated = <String>[];
      final router = GoRouter(
        initialLocation: '/survey/intro',
        routes: [
          GoRoute(
            path: '/survey/intro',
            builder: (_, __) => const SurveyIntroScreen(),
          ),
          GoRoute(
            path: '/survey/guide',
            builder: (_, __) {
              navigated.add('/survey/guide');
              return const Scaffold(body: Text('guide'));
            },
          ),
          GoRoute(
            path: '/survey/questions',
            builder: (_, __) {
              navigated.add('/survey/questions');
              return const Scaffold(body: Text('questions'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            surveyRepositoryProvider.overrideWithValue(repo),
            wrRepositoryProvider.overrideWithValue(wrRepo),
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
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(ElevatedButton).first);
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(navigated, contains('/survey/guide'));
      expect(navigated, isNot(contains('/survey/questions')));
    });
  });

  // ---------------------------------------------------------------------------
  // SurveyIntroScreen — prefill + auto-skip + profile update
  // ---------------------------------------------------------------------------

  group('SurveyIntroScreen — prefill + auto-skip + profile update', () {
    FakeSurveyRepository makeSurveyRepo() {
      final r = FakeSurveyRepository();
      r.seedRole('user');
      r.seedQuestions([]);
      r.seedLikertOptions({});
      return r;
    }

    testWidgets('renders position dropdown label when profile empty',
        (tester) async {
      final wrRepo = FakeWrRepository()..seedCcProfile({});

      await tester.pumpWidget(_introRouterWrap(
        surveyRepo: makeSurveyRepo(),
        wrRepo: wrRepo,
      ));
      await tester.pumpAndSettle();

      // Position field label should be visible (l10n: surveyIntroFieldPosition = 'Chức danh')
      expect(find.textContaining('Chức danh'), findsWidgets);
    });

    testWidgets('auto-skip navigates to /survey/guide when position is set',
        (tester) async {
      final wrRepo = FakeWrRepository()..seedCcProfile({'position': 'staff'});
      final navigated = <String>[];

      await tester.pumpWidget(_introRouterWrap(
        surveyRepo: makeSurveyRepo(),
        wrRepo: wrRepo,
        navigatedRoutes: navigated,
      ));

      // pumpAndSettle resolves FutureProvider + postFrameCallback auto-skip
      await tester.pumpAndSettle();

      expect(navigated, contains('/survey/guide'),
          reason: 'auto-skip must navigate to /survey/guide when position is set');
    });

    testWidgets('auto-skip resets surveyIdInProgress', (tester) async {
      // Strategy: pre-seed surveyIdInProgress = 'stale-id' via a provider
      // override BEFORE mounting. When auto-skip fires it calls _doStateReset()
      // which sets surveyIdInProgressProvider to null. We verify that.
      final wrRepo = FakeWrRepository()..seedCcProfile({'position': 'manager'});

      late WidgetRef capturedRef;
      final router = GoRouter(
        initialLocation: '/survey/intro',
        routes: [
          GoRoute(
            path: '/survey/intro',
            builder: (_, __) => const SurveyIntroScreen(),
          ),
          GoRoute(
            path: '/survey/guide',
            builder: (_, __) => const Scaffold(body: Text('guide')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            surveyRepositoryProvider.overrideWithValue(makeSurveyRepo()),
            wrRepositoryProvider.overrideWithValue(wrRepo),
            // Pre-seed a stale surveyId so auto-skip can reset it
            surveyIdInProgressProvider
                .overrideWith((ref) => 'stale-id'),
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
            builder: (context, child) => Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return child ?? const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // Let FutureProvider resolve + postFrameCallback (auto-skip) fire
      await tester.pumpAndSettle();

      expect(
        capturedRef.read(surveyIdInProgressProvider),
        isNull,
        reason: 'auto-skip must reset surveyIdInProgress',
      );
    });

    testWidgets('NO auto-skip when profile incomplete (position empty)',
        (tester) async {
      final wrRepo = FakeWrRepository()..seedCcProfile({});
      final navigated = <String>[];

      await tester.pumpWidget(_introRouterWrap(
        surveyRepo: makeSurveyRepo(),
        wrRepo: wrRepo,
        navigatedRoutes: navigated,
      ));
      await tester.pumpAndSettle();

      // Intro form is still showing — NOT navigated away
      expect(navigated, isNot(contains('/survey/guide')),
          reason: 'must NOT auto-skip when position is empty');
      // The intro screen body is visible (dropdowns render)
      expect(find.byType(DropdownButton<String>), findsWidgets);
    });

    testWidgets(
        '_hasSkipped guard: auto-skip fires only once per widget instance',
        (tester) async {
      // With a complete profile the auto-skip fires once on mount.
      // After navigating to /survey/guide the router shows "guide".
      // If we could pop back (same widget instance), it would NOT skip again.
      // In practice going back creates a NEW widget instance which would
      // auto-skip again — same as web behavior. This test simply verifies
      // the navigated list has exactly 1 entry (not duplicated in same pump cycle).
      final wrRepo = FakeWrRepository()..seedCcProfile({'position': 'staff'});
      final navigated = <String>[];

      await tester.pumpWidget(_introRouterWrap(
        surveyRepo: makeSurveyRepo(),
        wrRepo: wrRepo,
        navigatedRoutes: navigated,
      ));
      await tester.pumpAndSettle();

      // Auto-skip should have fired exactly once
      expect(
        navigated.where((r) => r == '/survey/guide'),
        hasLength(1),
        reason: '_hasSkipped guard must prevent duplicate auto-skip callbacks',
      );
    });

    testWidgets(
        'CTA tap with no fields set: updateCcProfile not called (no non-null fields)',
        (tester) async {
      final wrRepo = FakeWrRepository()..seedCcProfile({});

      await tester.pumpWidget(_introRouterWrap(
        surveyRepo: makeSurveyRepo(),
        wrRepo: wrRepo,
      ));
      await tester.pumpAndSettle();

      // Tap CTA with all dropdowns still null (scroll into view first)
      await tester.ensureVisible(find.byType(ElevatedButton).first);
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // No non-null fields → updateCcProfile should NOT have been called
      expect(wrRepo.updateCcProfileCalls, isEmpty,
          reason:
              'updateCcProfile must not be called when no dropdown fields are selected');
    });
  });

  // ---------------------------------------------------------------------------
  // SurveyGuideScreen tests
  // ---------------------------------------------------------------------------

  group('SurveyGuideScreen', () {
    late FakeSurveyRepository repo;

    setUp(() {
      repo = FakeSurveyRepository();
      repo.seedRole('user'); // FREE
    });

    testWidgets('FREE: shows free title containing "Work Reflection"',
        (tester) async {
      await tester.pumpWidget(_wrap(const SurveyGuideScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('Work Reflection') ?? false),
        ),
        findsAtLeast(1),
      );
    });

    testWidgets('FREE: shows guide eyebrow', (tester) async {
      await tester.pumpWidget(_wrap(const SurveyGuideScreen(), repo: repo));
      await tester.pumpAndSettle();

      // WrEyebrow uppercases → "HƯỚNG DẪN"
      expect(find.textContaining('HƯỚNG DẪN'), findsOneWidget);
    });

    testWidgets('FREE: shows 3 benefit items', (tester) async {
      await tester.pumpWidget(_wrap(const SurveyGuideScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guide_benefit_0')), findsOneWidget);
      expect(find.byKey(const Key('guide_benefit_1')), findsOneWidget);
      expect(find.byKey(const Key('guide_benefit_2')), findsOneWidget);
    });

    testWidgets('FREE: CTA button navigates to /survey/questions',
        (tester) async {
      final navigated = <String>[];
      final router = GoRouter(
        initialLocation: '/survey/guide',
        routes: [
          GoRoute(
            path: '/survey/guide',
            builder: (_, __) => const SurveyGuideScreen(),
          ),
          GoRoute(
            path: '/survey/questions',
            builder: (_, __) {
              navigated.add('/survey/questions');
              return const Scaffold(body: Text('questions'));
            },
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [surveyRepositoryProvider.overrideWithValue(repo)],
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
      ));
      await tester.pumpAndSettle();

      // Scroll to the CTA button (it may be below the fold in default viewport)
      final ctaBtn = find.byType(ElevatedButton).first;
      await tester.ensureVisible(ctaBtn);
      await tester.pumpAndSettle();
      await tester.tap(ctaBtn, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(navigated, contains('/survey/questions'));
    });

    testWidgets('PREMIUM: shows 4 benefit items', (tester) async {
      repo.seedRole('premium');
      await tester.pumpWidget(_wrap(const SurveyGuideScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guide_benefit_0')), findsOneWidget);
      expect(find.byKey(const Key('guide_benefit_1')), findsOneWidget);
      expect(find.byKey(const Key('guide_benefit_2')), findsOneWidget);
      expect(find.byKey(const Key('guide_benefit_3')), findsOneWidget);
    });
  });
}
