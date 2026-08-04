// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workreflection_mobile/core/data/survey_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/recurring_situation.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/home/presentation/home_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_survey_repository.dart';

Widget _wrap(Widget child, WrRepository repo,
    {SurveyRepository? surveyRepo}) {
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(repo),
      if (surveyRepo != null)
        surveyRepositoryProvider.overrideWithValue(surveyRepo),
    ],
    child: MaterialApp(
      builder: wrTextScaleBuilder,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: child,
    ),
  );
}

/// Set viewport to a large height so all content is visible in tests.
Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

MobileProfile _profile({String? displayName}) => MobileProfile(
      userId: 'u1',
      displayName: displayName,
      reminderEnabled: true,
      language: 'vi',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
  });

  group('HomeScreen widget', () {
    testWidgets('shows profile displayName from mobileProfileProvider', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile(displayName: 'Yumi'));
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      expect(find.textContaining('Chào Yumi'), findsOneWidget);
    });

    testWidgets('falls back to "bạn" when profile has no displayName', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile(displayName: null));
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      expect(find.textContaining('Chào bạn'), findsOneWidget);
    });

    testWidgets('renders date title key', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      final dateFinder = find.byKey(const Key('home_date_title'));
      expect(dateFinder, findsOneWidget);
    });

    testWidgets('renders check-in question', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      expect(find.textContaining('Bạn đang trải qua điều gì?'), findsOneWidget);
    });

    testWidgets('renders 4 mood buttons', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      expect(find.textContaining('căng thẳng'), findsOneWidget);
      expect(find.textContaining('mệt mỏi'), findsOneWidget);
      expect(find.textContaining('khá ổn'), findsOneWidget);
      expect(find.textContaining('đang vui'), findsOneWidget);
    });

    testWidgets('tapping mood button calls upsertCheckin', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      await tester.tap(find.textContaining('khá ổn').first);
      await tester.pumpAndSettle();

      expect(repo.upsertCheckinCalls.map((c) => c.mood), contains(Mood.okay));
    });

    testWidgets('selected mood key changes after tap', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      expect(find.byKey(const Key('mood_btn_happy_selected')), findsNothing);

      await tester.tap(find.textContaining('đang vui').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mood_btn_happy_selected')), findsOneWidget);
    });

    testWidgets('shows INSIGHT eyebrow and content when insight available', (tester) async {
      final repo = FakeWrRepository();
      repo.seedInsights([
        Insight(
          id: 'ins1',
          userId: 'u1',
          content: 'Tôi thường im lặng không phải vì không có ý kiến.',
          source: 'VOICE',
          savedAt: DateTime(2026, 6, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      // WrEyebrow uppercases text: "INSIGHT GẦN NHẤT"
      expect(find.textContaining('INSIGHT'), findsWidgets);
      expect(find.textContaining('im lặng'), findsWidgets);
    });

    testWidgets('shows empty state when no insight', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      expect(find.byKey(const Key('home_insight_empty')), findsOneWidget);
    });

    testWidgets('shows system card eyebrow when situation available', (tester) async {
      final repo = FakeWrRepository();
      repo.seedSituations([
        RecurringSituation(
          id: 's1',
          userId: 'u1',
          label: 'Ngại phản biện',
          occurrenceCount: 5,
          updatedAt: DateTime(2026, 6, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      // WrEyebrow uppercases: "HỆ THỐNG NHẬN RA"
      expect(find.textContaining('HỆ THỐNG'), findsOneWidget);
      expect(find.textContaining('Ngại phản biện'), findsOneWidget);
    });

    testWidgets('shows suggestion card eyebrow', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      // WrEyebrow uppercases: "GỢI Ý KHI MỆT MỎI"
      expect(find.textContaining('GỢI Ý'), findsOneWidget);
    });

    testWidgets('system notice card has a learn-more link with key', (tester) async {
      final repo = FakeWrRepository();
      repo.seedSituations([
        RecurringSituation(
          id: 's1',
          userId: 'u1',
          label: 'Ngại phản biện',
          occurrenceCount: 3,
          updatedAt: DateTime(2026, 7, 1),
        ),
      ]);
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      expect(find.byKey(const Key('home_system_notice_learn_more')), findsOneWidget);
    });

    testWidgets('learn-more link label is "Tìm hiểu thêm"', (tester) async {
      final repo = FakeWrRepository();
      repo.seedSituations([
        RecurringSituation(
          id: 's1',
          userId: 'u1',
          label: 'Tình huống X',
          occurrenceCount: 2,
          updatedAt: DateTime(2026, 7, 1),
        ),
      ]);
      await _pumpLarge(tester, _wrap(const HomeScreen(), repo));

      expect(find.textContaining('Tìm hiểu thêm'), findsOneWidget);
    });

    group('Survey CTA card', () {
      CcReportSummary makeSummary({String id = 'r1'}) => CcReportSummary(
            id: id,
            surveyId: 'sv1',
            createdAt: DateTime(2026, 7, 18),
            scoreTotal: 3.8,
            scoreLevel: ScoreLevel.good,
          );

      CcReportFull makeFullReport({String id = 'r1'}) => CcReportFull(
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

      testWidgets('shows big CTA card when user has no reports', (tester) async {
        final wr = FakeWrRepository();
        final survey = FakeSurveyRepository();
        survey.seedRole('user');
        survey.seedReportSummaries([]);

        await _pumpLarge(
            tester, _wrap(const HomeScreen(), wr, surveyRepo: survey));

        expect(
            find.byKey(const Key('home_survey_cta_no_report')), findsOneWidget);
        expect(
            find.byKey(const Key('home_survey_cta_has_report')), findsNothing);
      });

      testWidgets('shows view-latest card when user has reports',
          (tester) async {
        final wr = FakeWrRepository();
        final survey = FakeSurveyRepository();
        survey.seedRole('user');
        survey.seedReportSummaries([makeSummary(id: 'r1')]);
        survey.seedLatestReport(makeFullReport(id: 'r1'));

        await _pumpLarge(
            tester, _wrap(const HomeScreen(), wr, surveyRepo: survey));

        expect(find.byKey(const Key('home_survey_cta_has_report')),
            findsOneWidget);
        expect(
            find.byKey(const Key('home_survey_cta_no_report')), findsNothing);
      });

      testWidgets('CTA card hidden on error (no crash)', (tester) async {
        final wr = FakeWrRepository();
        final survey = FakeSurveyRepository();
        survey.seedRole('user');
        survey.setMyReportsError(Exception('network error'));

        await _pumpLarge(
            tester, _wrap(const HomeScreen(), wr, surveyRepo: survey));

        expect(
            find.byKey(const Key('home_survey_cta_no_report')), findsNothing);
        expect(
            find.byKey(const Key('home_survey_cta_has_report')), findsNothing);
      });

      testWidgets('start button key present in no-report state', (tester) async {
        final wr = FakeWrRepository();
        final survey = FakeSurveyRepository();
        survey.seedRole('user');
        survey.seedReportSummaries([]);

        await _pumpLarge(
            tester, _wrap(const HomeScreen(), wr, surveyRepo: survey));

        expect(find.byKey(const Key('home_survey_cta_start_btn')),
            findsOneWidget);
      });

      testWidgets('retake link present when user has reports', (tester) async {
        final wr = FakeWrRepository();
        final survey = FakeSurveyRepository();
        survey.seedRole('user');
        survey.seedReportSummaries([makeSummary(id: 'r1')]);
        survey.seedLatestReport(makeFullReport(id: 'r1'));

        await _pumpLarge(
            tester, _wrap(const HomeScreen(), wr, surveyRepo: survey));

        expect(find.byKey(const Key('home_survey_cta_retake_link')),
            findsOneWidget);
      });
    });
  });
}
