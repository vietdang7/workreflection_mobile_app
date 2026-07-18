import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/survey/presentation/esi_analysis_screen.dart';
import 'package:workreflection_mobile/features/survey/presentation/layer_detail_screen.dart';
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
  String surveyId = 's1',
  double total = 4.0,
  double s = 4.2,
  double c = 3.5,
  double a = 4.1,
  double? esi,
  int? enps,
  SurveyLayer bottleneck = SurveyLayer.culture,
  ScoreLevel level = ScoreLevel.good,
  Map<String, dynamic>? subScores,
}) =>
    CcReportFull(
      id: id,
      surveyId: surveyId,
      userId: 'u1',
      scoreTotal: total,
      scoreStructure: s,
      scoreCulture: c,
      scoreActivity: a,
      scoreEsi: esi,
      scoreEnps: enps,
      bottleneckLayer: bottleneck,
      scoreLevel: level,
      subScores: subScores,
      createdAt: DateTime(2026, 7, 18),
    );

SubComponentScore _sc(String key, double score, {int count = 10}) =>
    SubComponentScore(
      subComponent: key,
      label: key,
      score: score,
      count: count,
    );

// ---------------------------------------------------------------------------
// Minimal wrapper to render ReportScreen without GoRouter
// ---------------------------------------------------------------------------

class _ReportScreenWrapper extends StatelessWidget {
  const _ReportScreenWrapper({required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context) => ReportScreen(reportId: reportId);
}

// ---------------------------------------------------------------------------
// LayerDetailScreen tests
// ---------------------------------------------------------------------------

void main() {
  group('LayerDetailScreen', () {
    late FakeSurveyRepository repo;

    setUp(() {
      repo = FakeSurveyRepository();
    });

    testWidgets('shows overall score for STRUCTURE layer', (tester) async {
      repo.seedLatestReport(_report(s: 4.2));
      repo.seedLayerSubScores('STRUCTURE', [
        _sc('role_expect', 4.0),
        _sc('collab_rules', 3.5),
        _sc('comm_channels', 4.5),
      ]);

      await tester.pumpWidget(_wrap(
        const LayerDetailScreen(reportId: 'r1', layer: 'STRUCTURE'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('4.2'), findsOneWidget);
    });

    testWidgets('shows sub-component cards with labels', (tester) async {
      repo.seedLatestReport(_report());
      repo.seedLayerSubScores('STRUCTURE', [
        _sc('role_expect', 4.0),
        _sc('collab_rules', 3.5),
        _sc('comm_channels', 4.5),
      ]);

      await tester.pumpWidget(_wrap(
        const LayerDetailScreen(reportId: 'r1', layer: 'STRUCTURE'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // VI labels from l10n
      expect(find.textContaining('Kỳ vọng vai trò'), findsOneWidget);
      expect(find.textContaining('Quy tắc phối hợp'), findsOneWidget);
      expect(find.textContaining('Kênh giao tiếp'), findsOneWidget);
    });

    testWidgets('shows no-data state when sub-scores empty', (tester) async {
      repo.seedLatestReport(_report());
      repo.seedLayerSubScores('CULTURE', []);

      await tester.pumpWidget(_wrap(
        const LayerDetailScreen(reportId: 'r1', layer: 'CULTURE'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Chưa có dữ liệu'), findsOneWidget);
    });

    testWidgets('score >= 4.0 shows Good status badge', (tester) async {
      repo.seedLatestReport(_report());
      repo.seedLayerSubScores('ACTIVITY', [
        _sc('goal_alignment', 4.5),
      ]);

      await tester.pumpWidget(_wrap(
        const LayerDetailScreen(reportId: 'r1', layer: 'ACTIVITY'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // "Tốt" is the VI translation of layerDetailScoreGood
      expect(find.text('Tốt'), findsWidgets);
    });

    testWidgets('score >= 3.0 and < 4.0 shows Warning badge', (tester) async {
      repo.seedLatestReport(_report(a: 3.2));
      repo.seedLayerSubScores('ACTIVITY', [
        _sc('execution_rhythm', 3.2),
      ]);

      await tester.pumpWidget(_wrap(
        const LayerDetailScreen(reportId: 'r1', layer: 'ACTIVITY'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cần cải thiện'), findsWidgets);
    });

    testWidgets('score < 3.0 shows Critical badge', (tester) async {
      repo.seedLatestReport(_report(c: 2.5));
      repo.seedLayerSubScores('CULTURE', [
        _sc('trust', 2.5),
      ]);

      await tester.pumpWidget(_wrap(
        const LayerDetailScreen(reportId: 'r1', layer: 'CULTURE'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cần hành động'), findsWidgets);
    });

    testWidgets('shows response count for each sub-component', (tester) async {
      repo.seedLatestReport(_report());
      repo.seedLayerSubScores('STRUCTURE', [
        _sc('role_expect', 4.0, count: 7),
      ]);

      await tester.pumpWidget(_wrap(
        const LayerDetailScreen(reportId: 'r1', layer: 'STRUCTURE'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('7'), findsWidgets);
    });

    testWidgets('CULTURE sub-components show correct VI labels', (tester) async {
      repo.seedLatestReport(_report());
      repo.seedLayerSubScores('CULTURE', [
        _sc('trust', 4.0),
        _sc('psych_safety', 3.8),
        _sc('feedback_dialogue', 3.5),
      ]);

      await tester.pumpWidget(_wrap(
        const LayerDetailScreen(reportId: 'r1', layer: 'CULTURE'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sự tin tưởng'), findsOneWidget);
      expect(find.textContaining('An toàn tâm lý'), findsOneWidget);
      expect(find.textContaining('Đối thoại'), findsOneWidget);
    });

    testWidgets('ACTIVITY sub-components show correct VI labels', (tester) async {
      repo.seedLatestReport(_report());
      repo.seedLayerSubScores('ACTIVITY', [
        _sc('goal_alignment', 4.0),
        _sc('execution_rhythm', 3.8),
        _sc('retrospective', 3.5),
        _sc('continuous_improve', 4.2),
      ]);

      await tester.pumpWidget(_wrap(
        const LayerDetailScreen(reportId: 'r1', layer: 'ACTIVITY'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Liên kết mục tiêu'), findsOneWidget);
      expect(find.textContaining('Nhịp thực thi'), findsOneWidget);
      expect(find.textContaining('Thói quen nhìn lại'), findsOneWidget);
      expect(find.textContaining('Cải tiến liên tục'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // EsiAnalysisScreen tests
  // ---------------------------------------------------------------------------

  group('EsiAnalysisScreen', () {
    late FakeSurveyRepository repo;

    setUp(() {
      repo = FakeSurveyRepository();
    });

    testWidgets('shows ESI score from report', (tester) async {
      repo.seedLatestReport(_report(esi: 3.8, enps: 25));
      repo.seedEsiPillarScores({
        'compensation_income': 3.5,
        'compensation_benefits': 3.8,
        'growth_career': 4.0,
        'fairness_evaluation': 3.2,
        'support_management': 4.1,
      });

      await tester.pumpWidget(_wrap(
        const EsiAnalysisScreen(reportId: 'r1'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('3.8'), findsOneWidget);
    });

    testWidgets('shows eNPS score from report', (tester) async {
      repo.seedLatestReport(_report(esi: 3.8, enps: 42));
      repo.seedEsiPillarScores({});

      await tester.pumpWidget(_wrap(
        const EsiAnalysisScreen(reportId: 'r1'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('shows all 5 ESI pillar names', (tester) async {
      repo.seedLatestReport(_report(esi: 3.8, enps: 25));
      repo.seedEsiPillarScores({
        'compensation_income': 3.5,
        'compensation_benefits': 3.8,
        'growth_career': 4.0,
        'fairness_evaluation': 3.2,
        'support_management': 4.1,
        'support_feedback': 3.9,
        'support_collaboration': 4.2,
        'support_leadership': 3.7,
      });

      await tester.pumpWidget(_wrap(
        const EsiAnalysisScreen(reportId: 'r1'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đãi ngộ'), findsOneWidget);
      expect(find.textContaining('Cơ hội phát triển'), findsOneWidget);
      expect(find.textContaining('Minh bạch'), findsOneWidget);
      expect(find.textContaining('Hỗ trợ & ghi nhận'), findsOneWidget);
      expect(find.textContaining('Đồng nghiệp'), findsOneWidget);
    });

    testWidgets('shows no-data when pillar scores empty', (tester) async {
      repo.seedLatestReport(_report(esi: 3.8, enps: 25));
      repo.seedEsiPillarScores({});

      await tester.pumpWidget(_wrap(
        const EsiAnalysisScreen(reportId: 'r1'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // The pillars section header should be present
      expect(find.textContaining('Phân tích ESI theo trụ cột'), findsOneWidget);
    });

    testWidgets('shows premium-only message when scoreEsi is null',
        (tester) async {
      repo.seedLatestReport(_report(esi: null, enps: null));
      repo.seedEsiPillarScores({});

      await tester.pumpWidget(_wrap(
        const EsiAnalysisScreen(reportId: 'r1'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Premium'), findsOneWidget);
    });

    testWidgets('shows eNPS promoter/passive/detractor counts when available',
        (tester) async {
      final report = CcReportFull(
        id: 'r1',
        surveyId: 's1',
        userId: 'u1',
        scoreTotal: 4.0,
        scoreStructure: 4.0,
        scoreCulture: 3.5,
        scoreActivity: 4.1,
        scoreEsi: 3.8,
        scoreEnps: 25,
        bottleneckLayer: SurveyLayer.culture,
        scoreLevel: ScoreLevel.good,
        createdAt: DateTime(2026, 7, 18),
        subScores: {
          'enps_promoters': 6,
          'enps_passives': 3,
          'enps_detractors': 1,
        },
      );
      repo.seedLatestReport(report);
      repo.seedEsiPillarScores({});

      await tester.pumpWidget(_wrap(
        const EsiAnalysisScreen(reportId: 'r1'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('6'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Navigation from ReportScreen: "View details" buttons
  // ---------------------------------------------------------------------------

  group('ReportScreen view-detail buttons', () {
    late FakeSurveyRepository repo;

    setUp(() {
      repo = FakeSurveyRepository();
      repo.seedNarratives([]);
    });

    testWidgets('premium report shows ESI view-details button', (tester) async {
      repo.seedLatestReport(_report(esi: 3.8, enps: 25));

      await tester.pumpWidget(_wrap(
        _ReportScreenWrapper(reportId: 'r1'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // "Xem chi tiết" is the VI translation of layerDetailViewDetail
      // There should be multiple (one per layer card + one ESI card = 4)
      expect(find.text('Xem chi tiết'), findsWidgets);
    });

    testWidgets('free report shows layer view-details buttons but no ESI button',
        (tester) async {
      repo.seedLatestReport(_report(esi: null, enps: null));

      await tester.pumpWidget(_wrap(
        _ReportScreenWrapper(reportId: 'r1'),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      // Layer cards still have "Xem chi tiết" (3 of them)
      expect(find.text('Xem chi tiết'), findsNWidgets(3));
    });
  });
}
