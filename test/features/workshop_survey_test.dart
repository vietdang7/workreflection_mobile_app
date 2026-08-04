// Widget tests for WorkshopSurveyScreen — Task 13.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/data/workshop_repository.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/core/widgets/pill_button.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/features/workshops/presentation/workshop_survey_screen.dart';
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
      appLocaleProvider.overrideWith((ref) => locale),
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
      home: WorkshopSurveyScreen(workshopId: workshopId),
    ),
  );
}

CcQuestion _q({
  String id = 'q-1',
  String questionText = 'Câu hỏi 1',
  String? questionTextEn,
}) =>
    CcQuestion(
      id: id,
      layer: SurveyLayer.structure,
      scaleType: ScaleType.likert5,
      questionText: questionText,
      questionTextEn: questionTextEn,
      questionOrder: 1,
      isActive: true,
    );

WorkshopSurveySet _surveySet({
  String questionSetId = 'qs-1',
  List<CcQuestion>? questions,
}) =>
    WorkshopSurveySet(
      questionSetId: questionSetId,
      questions: questions ?? [_q()],
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WorkshopSurveyScreen', () {
    late FakeWorkshopRepository repo;

    setUp(() {
      repo = FakeWorkshopRepository();
    });

    testWidgets('no survey set shows wsSurveyNone', (tester) async {
      // No survey seeded → getWorkshopSurveySet returns null.
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ws_survey_none')), findsOneWidget);
      expect(find.text('Chưa có khảo sát cho workshop này'), findsOneWidget);
    });

    testWidgets('empty questions list shows wsSurveyNone', (tester) async {
      repo.seedSurveySet(
          WorkshopSurveySet(questionSetId: 'qs-1', questions: []));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ws_survey_none')), findsOneWidget);
    });

    testWidgets('questions render with their texts visible', (tester) async {
      repo.seedSurveySet(_surveySet(questions: [
        _q(id: 'q-1', questionText: 'Câu hỏi một'),
        _q(id: 'q-2', questionText: 'Câu hỏi hai'),
      ]));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Câu hỏi một'), findsOneWidget);
      expect(find.text('Câu hỏi hai'), findsOneWidget);
    });

    testWidgets('submit disabled until all questions answered', (tester) async {
      repo.seedSurveySet(_surveySet(questions: [
        _q(id: 'q-1', questionText: 'Q1'),
        _q(id: 'q-2', questionText: 'Q2'),
      ]));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Submit button is disabled initially (onPressed=null when not all answered).
      // Check that tapping submit does NOT record a call.
      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();
      expect(repo.submitSurveyCalls, isEmpty);

      // Answer only Q1.
      await tester.tap(find.byKey(const Key('chip_q-1_3')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();
      expect(repo.submitSurveyCalls, isEmpty); // still disabled

      // Answer Q2.
      await tester.tap(find.byKey(const Key('chip_q-2_5')));
      await tester.pumpAndSettle();

      // Now submit should be enabled.
      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();
      expect(repo.submitSurveyCalls, isNotEmpty);
    });

    testWidgets('successful submit records answers and shows wsSurveyThanks',
        (tester) async {
      repo.seedSurveySet(_surveySet(questions: [
        _q(id: 'q-1', questionText: 'Q1'),
        _q(id: 'q-2', questionText: 'Q2'),
      ]));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Select answers.
      await tester.tap(find.byKey(const Key('chip_q-1_4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chip_q-2_2')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();

      expect(repo.submitSurveyCalls, hasLength(1));
      expect(repo.submitSurveyCalls.first['workshopId'], 'ws-1');
      expect(repo.submitSurveyCalls.first['questionSetId'], 'qs-1');
      expect(repo.submitSurveyCalls.first['answers'],
          {'q-1': 4, 'q-2': 2});

      expect(find.byKey(const Key('ws_survey_thanks')), findsOneWidget);
      expect(find.text('Cảm ơn bạn đã đánh giá!'), findsOneWidget);
    });

    testWidgets('double-tap guard — submit called exactly once', (tester) async {
      repo.seedSurveySet(_surveySet());

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chip_q-1_3')));
      await tester.pumpAndSettle();

      // Tap submit; the screen transitions to thanks view (submit was called).
      await tester.tap(find.byType(WrPillButton));
      await tester.pumpAndSettle();

      expect(repo.submitSurveyCalls, hasLength(1));

      // Thanks view is shown — pressing it again would be a no-op anyway
      // because _submitted=true guard prevents re-entry.
      expect(find.byKey(const Key('ws_survey_thanks')), findsOneWidget);
      expect(find.byType(WrPillButton), findsNothing);
    });

    testWidgets('repo error shows wsSurveyError snackbar and can retry',
        (tester) async {
      repo.seedSurveySet(_surveySet());

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chip_q-1_5')));
      await tester.pumpAndSettle();

      // Inject error directly onto submitWorkshopSurvey path by setting it
      // just before the tap, so it fires on that call specifically.
      // (nextError fires on the next ANY call; chip tap triggers setState only
      // so the provider is not re-fetched — safe to set here.)
      repo.nextError = Exception('network error');

      await tester.tap(find.byType(WrPillButton));
      await tester.pumpAndSettle();

      // After error: snackbar visible, submit calls empty, button still shown.
      expect(find.text('Gửi đánh giá thất bại. Vui lòng thử lại.'),
          findsOneWidget);
      expect(repo.submitSurveyCalls, isEmpty);

      // Dismiss the snackbar (default 4s) so it doesn't block the button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      // Retry succeeds — button is re-enabled, _submitted still false.
      await tester.tap(find.byKey(const Key('ws_survey_submit')));
      await tester.pumpAndSettle();

      expect(repo.submitSurveyCalls, hasLength(1));
      expect(find.byKey(const Key('ws_survey_thanks')), findsOneWidget);
    });

    testWidgets('VI locale shows questionText', (tester) async {
      repo.seedSurveySet(_surveySet(questions: [
        _q(
          id: 'q-1',
          questionText: 'Tiếng Việt',
          questionTextEn: 'English text',
        ),
      ]));

      await tester.pumpWidget(_wrap(repo, locale: 'vi'));
      await tester.pumpAndSettle();

      expect(find.text('Tiếng Việt'), findsOneWidget);
      expect(find.text('English text'), findsNothing);
    });

    testWidgets('EN locale shows questionTextEn when available', (tester) async {
      repo.seedSurveySet(_surveySet(questions: [
        _q(
          id: 'q-1',
          questionText: 'Tiếng Việt',
          questionTextEn: 'English text',
        ),
      ]));

      await tester.pumpWidget(_wrap(repo, locale: 'en'));
      await tester.pumpAndSettle();

      expect(find.text('English text'), findsOneWidget);
      expect(find.text('Tiếng Việt'), findsNothing);
    });
  });
}
