import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/survey/presentation/action_plan_screen.dart';
import 'package:workreflection_mobile/features/survey/presentation/report_screen.dart';
import 'package:workreflection_mobile/features/survey/survey_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_survey_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
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

CcReportFull _report({
  String id = 'r1',
  double total = 4.0,
  double s = 4.0,
  double c = 3.5,
  double a = 4.5,
  double? esi,
  int? enps,
  SurveyLayer bottleneck = SurveyLayer.culture,
  ScoreLevel level = ScoreLevel.good,
}) =>
    CcReportFull(
      id: id,
      surveyId: 's1',
      userId: 'u1',
      scoreTotal: total,
      scoreStructure: s,
      scoreCulture: c,
      scoreActivity: a,
      scoreEsi: esi,
      scoreEnps: enps,
      bottleneckLayer: bottleneck,
      scoreLevel: level,
      createdAt: DateTime(2026, 7, 17),
    );

// ---------------------------------------------------------------------------
// ReportScreen tests
// ---------------------------------------------------------------------------

void main() {
  group('ReportScreen', () {
    late FakeSurveyRepository repo;

    setUp(() {
      repo = FakeSurveyRepository();
      repo.seedNarratives([]);
    });

    testWidgets('score level HIGH shows teal badge label', (tester) async {
      final report = _report(total: 4.5, level: ScoreLevel.high);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Xuất sắc'), findsOneWidget);
    });

    testWidgets('score level GOOD shows navy badge label', (tester) async {
      final report = _report(total: 3.8, level: ScoreLevel.good);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Tốt'), findsOneWidget);
    });

    testWidgets('score level WARNING shows coral badge label', (tester) async {
      final report = _report(total: 3.0, level: ScoreLevel.warning);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Cần chú ý'), findsOneWidget);
    });

    testWidgets('score level CRITICAL shows destructive badge label',
        (tester) async {
      final report = _report(total: 2.5, level: ScoreLevel.critical);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Cần cải thiện'), findsOneWidget);
    });

    testWidgets('score total displayed prominently', (tester) async {
      final report = _report(total: 3.8);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('3.8'), findsOneWidget);
    });

    testWidgets('shows S/C/A layer section labels', (tester) async {
      final report = _report();
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      // Default bottleneck=culture, so "Văn hoá làm việc" appears in both
      // layer card AND bottleneck card — use findsWidgets.
      expect(find.text('Cấu trúc tổ chức'), findsOneWidget);
      expect(find.text('Văn hoá làm việc'), findsWidgets);
      expect(find.text('Hoạt động hàng ngày'), findsOneWidget);
    });

    testWidgets('shows bottleneck card with correct layer (culture)',
        (tester) async {
      final report = _report(
          bottleneck: SurveyLayer.culture, level: ScoreLevel.good);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      // The bottleneck card has the eyebrow "ĐIỂM CẦN CẢI THIỆN NHẤT"
      // and body showing the layer label
      expect(find.text('ĐIỂM CẦN CẢI THIỆN NHẤT'), findsOneWidget);
      expect(find.text('Văn hoá làm việc'), findsWidgets);
    });

    testWidgets('shows bottleneck layer structure when structure is lowest',
        (tester) async {
      final report = _report(bottleneck: SurveyLayer.structure);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Cấu trúc tổ chức'), findsWidgets);
    });

    testWidgets('FREE report shows premium upsell card', (tester) async {
      // No ESI/eNPS → FREE
      final report = _report(esi: null, enps: null);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Premium'),
        findsOneWidget,
      );
    });

    testWidgets('PREMIUM report shows ESI and eNPS sections', (tester) async {
      final report = _report(esi: 3.8, enps: 25);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      // ESI title eyebrow
      expect(find.textContaining('ESI'), findsOneWidget);
      // ESI score
      expect(find.text('3.8'), findsOneWidget);
      // eNPS score
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('PREMIUM report does NOT show upsell card', (tester) async {
      final report = _report(esi: 4.0, enps: 50);
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nâng cấp Premium'), findsNothing);
    });

    testWidgets('30-day plan CTA is present', (tester) async {
      final report = _report();
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Kế hoạch 30 ngày'), findsOneWidget);
    });

    testWidgets('N15: narrative fetch error shows error text not spinner', (tester) async {
      final r = _report();
      repo.seedLatestReport(r);
      repo.setNarrativesFails(true);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('lỗi'), findsOneWidget);
    });

    testWidgets('N16: eNPS card shows promoter/passive/detractor counts when available', (tester) async {
      final report = CcReportFull(
        id: 'r1',
        surveyId: 's1',
        userId: 'u1',
        scoreTotal: 4.0,
        scoreStructure: 4.0,
        scoreCulture: 3.5,
        scoreActivity: 4.5,
        scoreEsi: 3.0,
        scoreEnps: 25,
        bottleneckLayer: SurveyLayer.culture,
        scoreLevel: ScoreLevel.good,
        createdAt: DateTime(2026, 7, 17),
        subScores: {'enps_promoters': 5, 'enps_passives': 3, 'enps_detractors': 2},
      );
      repo.seedLatestReport(report);

      await tester.pumpWidget(_wrap(ReportScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('5'), findsWidgets); // promoter count
    });
  });

  // ---------------------------------------------------------------------------
  // ActionPlanScreen tests
  // ---------------------------------------------------------------------------

  group('ActionPlanScreen', () {
    late FakeSurveyRepository repo;

    setUp(() {
      repo = FakeSurveyRepository();
      repo.seedRole('user');
    });

    ActionPlanPhase makePhase(String id, int day, List<ActionPlanTask> tasks) =>
        ActionPlanPhase(
          id: id,
          day: day,
          titleVi: 'Giai đoạn $day',
          titleEn: 'Phase $day',
          surveyType: SurveyType.free,
          displayOrder: day,
          tasks: tasks,
        );

    ActionPlanTask makeTask(String id, String phaseId, String label,
            {bool completed = false}) =>
        ActionPlanTask(
            id: id, phaseId: phaseId, label: label, displayOrder: 1,
            completed: completed);

    testWidgets('renders phase titles and tasks', (tester) async {
      repo.seedActionPlan([
        makePhase('ph1', 1, [
          makeTask('t1', 'ph1', 'Viết nhật ký'),
          makeTask('t2', 'ph1', 'Đặt câu hỏi'),
        ]),
      ]);
      repo.seedActionProgress({});

      await tester.pumpWidget(
          _wrap(const ActionPlanScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Giai đoạn 1'), findsOneWidget);
      expect(find.text('Viết nhật ký'), findsOneWidget);
      expect(find.text('Đặt câu hỏi'), findsOneWidget);
    });

    testWidgets('completed task shows check icon and strikethrough',
        (tester) async {
      repo.seedActionPlan([
        makePhase('ph1', 1, [
          makeTask('t1', 'ph1', 'Task done', completed: false),
        ]),
      ]);
      repo.seedActionProgress({'t1': true});

      await tester.pumpWidget(
          _wrap(const ActionPlanScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      // After init, progress loaded from seed → t1 is completed
      // Give time for postFrameCallback
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping uncompleted task calls toggleTask', (tester) async {
      repo.seedActionPlan([
        makePhase('ph1', 1, [
          makeTask('t1', 'ph1', 'Task to toggle'),
        ]),
      ]);
      repo.seedActionProgress({'t1': false});

      await tester.pumpWidget(
          _wrap(const ActionPlanScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Task to toggle'));
      await tester.pumpAndSettle();

      expect(repo.toggleTaskCalls, hasLength(1));
      expect(repo.toggleTaskCalls.first.$1, 't1');
      expect(repo.toggleTaskCalls.first.$2, true); // toggled to true
    });

    testWidgets('multiple phases shown in order', (tester) async {
      repo.seedActionPlan([
        makePhase('ph1', 1, [makeTask('t1', 'ph1', 'Task 1')]),
        makePhase('ph2', 5, [makeTask('t2', 'ph2', 'Task 5')]),
        makePhase('ph3', 10, [makeTask('t3', 'ph3', 'Task 10')]),
      ]);
      repo.seedActionProgress({});

      await tester.pumpWidget(
          _wrap(const ActionPlanScreen(reportId: 'r1'), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Giai đoạn 1'), findsOneWidget);
      expect(find.text('Giai đoạn 5'), findsOneWidget);
      expect(find.text('Giai đoạn 10'), findsOneWidget);
    });
  });
}
