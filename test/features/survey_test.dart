import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
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
}
