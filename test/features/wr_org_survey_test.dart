// Khảo sát tổ chức (ESI + eNPS) — mockup Sprint 2, mở từ màn Hồ sơ.
// Run: flutter test test/features/wr_org_survey_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_org_survey_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/logic/wr_org_survey_scoring.dart';
import 'package:workreflection_mobile/core/models/wr_org_survey.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_org_survey_flow_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_org_survey_intro_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_org_survey_result_screen.dart';
import 'package:workreflection_mobile/features/wr/org_survey_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../support/fake_repository.dart';
import '../support/fake_wr_org_survey_repository.dart';

MobileProfile _profile({String? orgIndustry}) => MobileProfile(
  userId: 'u1',
  displayName: 'Thông',
  reminderEnabled: true,
  language: 'vi',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  orgIndustry: orgIndustry,
);

/// Chọn một mã lĩnh vực ở bước đầu rồi bấm Tiếp tục.
Future<void> _pickIndustry(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('wr_org_survey_industry')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('wr_org_survey_industry_next')));
  await tester.pumpAndSettle();
}

Widget _wrap(
  FakeWrOrgSurveyRepository repo, {
  String initial = '/wr/org-survey',
  FakeWrRepository? wr,
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/wr/org-survey',
        builder: (_, __) => const WrOrgSurveyIntroScreen(),
      ),
      GoRoute(
        path: '/wr/org-survey/flow',
        builder: (_, __) => const WrOrgSurveyFlowScreen(),
      ),
      GoRoute(
        path: '/wr/org-survey/result',
        builder: (_, s) => WrOrgSurveyResultScreen(
          response: s.extra is OrgSurveyResponse
              ? s.extra! as OrgSurveyResponse
              : null,
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      wrOrgSurveyRepositoryProvider.overrideWithValue(repo),
      wrRepositoryProvider.overrideWithValue(wr ?? FakeWrRepository()),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/// Chọn lĩnh vực, trả lời hết 5 câu thang + câu eNPS.
Future<void> _answerEverything(
  WidgetTester tester,
  int count, {
  String industry = 'Tài chính, ngân hàng',
  bool pickIndustry = true,
}) async {
  if (pickIndustry) await _pickIndustry(tester, industry);
  for (var i = 0; i < count; i++) {
    await tester.tap(find.byKey(const Key('wr_org_survey_option_3')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('wr_org_survey_enps_8')));
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  group('Màn giới thiệu', () {
    testWidgets('nói đủ bốn cam kết trước khi hỏi câu nào', (tester) async {
      // Bốn câu này là điều kiện để người dùng đồng ý có hiểu biết. Mất một câu
      // là mất một phần của sự đồng ý đó.
      await _pump(tester, _wrap(FakeWrOrgSurveyRepository()));

      expect(find.textContaining('tổng hợp, ẩn danh'), findsOneWidget);
      expect(
        find.textContaining('không ảnh hưởng đến Reflection'),
        findsOneWidget,
      );
      expect(find.textContaining('Không bắt buộc'), findsOneWidget);
      expect(find.textContaining('ngừng tham gia'), findsOneWidget);
    });

    testWidgets('số câu đếm từ bảng hỏi, không ghi cứng', (tester) async {
      // Repo giả có 5 câu → 1 câu lĩnh vực + 5 + 1 câu eNPS.
      await _pump(tester, _wrap(FakeWrOrgSurveyRepository()));
      expect(find.textContaining('Trả lời 7 câu ngắn'), findsOneWidget);
    });

    testWidgets('đọc hỏng bảng hỏi thì KHÓA nút bắt đầu', (tester) async {
      // Mở luồng khi chưa có câu nào là đẩy người dùng vào một màn trống.
      await _pump(
        tester,
        _wrap(FakeWrOrgSurveyRepository(failQuestions: true)),
      );

      expect(
        find.byKey(const Key('wr_org_survey_questions_error')),
        findsOneWidget,
      );
      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('wr_org_survey_start')),
      );
      expect(btn.onPressed, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('Luồng trả lời', () {
    testWidgets('trả lời hết rồi mới gửi MỘT lần', (tester) async {
      // Ghi dần từng câu sẽ tạo bản ghi dở dang của người mở ra rồi thoát, và
      // những bản ghi đó chảy thẳng vào mặt bằng chung của mọi người.
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));

      await _pickIndustry(tester, 'Công nghệ');
      await tester.tap(find.byKey(const Key('wr_org_survey_option_3')));
      await tester.pumpAndSettle();
      expect(repo.submittedAnswers, isNull, reason: 'chưa xong mà đã gửi');

      await _answerEverything(tester, 4, pickIndustry: false);

      expect(repo.submittedAnswers?.length, 5);
      expect(repo.submittedEnps, 8);
    });

    testWidgets('bước đầu là Lĩnh vực, chưa chọn thì nút Tiếp tục tắt', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(FakeWrOrgSurveyRepository(), initial: '/wr/org-survey/flow'),
      );
      expect(
        find.text('Bạn đang làm việc trong lĩnh vực nào?'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_org_survey_industry')), findsOneWidget);
      expect(find.byKey(const Key('wr_org_survey_option_0')), findsNothing);
      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('wr_org_survey_industry_next')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets(
      'hồ sơ có org_industry=finance → chọn sẵn Tài chính, ngân hàng',
      (tester) async {
        final wr = FakeWrRepository()
          ..seedProfile(_profile(orgIndustry: 'finance'));
        await _pump(
          tester,
          _wrap(
            FakeWrOrgSurveyRepository(),
            initial: '/wr/org-survey/flow',
            wr: wr,
          ),
        );
        expect(find.text('Tài chính, ngân hàng'), findsOneWidget);
        final btn = tester.widget<ElevatedButton>(
          find.byKey(const Key('wr_org_survey_industry_next')),
        );
        expect(btn.onPressed, isNotNull);
        // Không tự sang câu sau.
        expect(find.byKey(const Key('wr_org_survey_option_0')), findsNothing);
      },
    );

    testWidgets('nộp xong gửi industry=finance', (tester) async {
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));
      await _answerEverything(tester, 5);
      expect(repo.submittedIndustry, 'finance');
    });

    testWidgets('hồ sơ trống → nộp xong ghi org_industry', (tester) async {
      final wr = FakeWrRepository()..seedProfile(_profile());
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow', wr: wr));
      await _answerEverything(tester, 5);
      expect(wr.saveMyInfoCalls, [
        {'org_industry': 'finance'},
      ]);
    });

    testWidgets('hồ sơ đã có → không ghi đè', (tester) async {
      final wr = FakeWrRepository()..seedProfile(_profile(orgIndustry: 'tech'));
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow', wr: wr));
      // Đổi sang finance ngay trong bài: khảo sát nhận finance, hồ sơ giữ tech.
      await tester.tap(find.byKey(const Key('wr_org_survey_industry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tài chính, ngân hàng').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_org_survey_industry_next')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('wr_org_survey_option_3')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('wr_org_survey_enps_8')));
      await tester.pumpAndSettle();

      expect(repo.submittedIndustry, 'finance');
      expect(wr.saveMyInfoCalls, isEmpty);
    });

    testWidgets('câu cuối là eNPS 0..10, không phải thang 5 mức', (
      tester,
    ) async {
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));

      await _pickIndustry(tester, 'Công nghệ');
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('wr_org_survey_option_0')));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(const Key('wr_org_survey_enps_0')), findsOneWidget);
      expect(find.byKey(const Key('wr_org_survey_enps_10')), findsOneWidget);
      expect(find.byKey(const Key('wr_org_survey_option_0')), findsNothing);
    });

    testWidgets('gửi hỏng thì giữ nguyên câu trả lời và cho gửi lại', (
      tester,
    ) async {
      // Mất mạng ở câu cuối mà mất luôn 13 câu vừa trả lời là cách chắc chắn
      // nhất để không ai làm lại lần hai.
      final repo = FakeWrOrgSurveyRepository(failSubmit: true);
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));
      await _answerEverything(tester, 5);

      expect(
        find.byKey(const Key('wr_org_survey_submit_error')),
        findsOneWidget,
      );

      repo.failSubmit = false;
      await tester.tap(find.byKey(const Key('wr_org_survey_retry')));
      await tester.pumpAndSettle();

      expect(repo.submittedAnswers?.length, 5);
      expect(repo.submittedEnps, 8);
    });

    testWidgets('bấm Đóng giữa chừng thì hỏi lại trước khi mất hết', (
      tester,
    ) async {
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));

      await _pickIndustry(tester, 'Công nghệ');
      await tester.tap(find.byKey(const Key('wr_org_survey_option_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_org_survey_close')));
      await tester.pumpAndSettle();

      expect(find.text('Thoát khảo sát?'), findsOneWidget);
      expect(repo.submittedAnswers, isNull);
    });

    testWidgets('trả lời xong thì sang thẳng màn kết quả', (tester) async {
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));
      await _answerEverything(tester, 5);

      expect(
        find.byKey(const Key('wr_org_survey_result_enps')),
        findsOneWidget,
      );
      expect(find.text('8 / 10'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('Màn kết quả', () {
    testWidgets('CHƯA đủ mẫu thì không vẽ vạch so sánh và nói thẳng vì sao', (
      tester,
    ) async {
      // Khác mockup có chủ ý: mockup ghi cứng mặt bằng chung bằng số minh hoạ.
      // Dán nhãn "ẩn danh" lên số bịa là nói một điều không có thật.
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));
      await _answerEverything(tester, 5);

      expect(
        find.byKey(const Key('wr_org_survey_no_benchmark')),
        findsOneWidget,
      );
      expect(find.text('Mặt bằng chung (ẩn danh)'), findsNothing);
      expect(find.text('Kết quả của bạn'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_org_survey_standing_compensation')),
        findsOneWidget,
      );
      // Nhãn từng mảng chỉ còn điểm của người dùng, không lặp câu "chưa đủ".
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('wr_org_survey_standing_compensation')),
            )
            .data,
        '3.0 / $kOrgSurveyMaxScore',
      );
    });

    testWidgets('đủ mẫu thì so sánh và nói cao hay thấp hơn', (tester) async {
      final repo = FakeWrOrgSurveyRepository(
        benchmark: FakeWrOrgSurveyRepository.liveBenchmark,
      );
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));
      // Chọn mức 3 cho mọi câu → 3.0, cao hơn mọi mốc trong liveBenchmark.
      await _answerEverything(tester, 5);

      expect(find.text('Bạn so với mặt bằng chung'), findsOneWidget);
      expect(find.text('Mặt bằng chung (ẩn danh)'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('wr_org_survey_standing_compensation')),
            )
            .data,
        'Cao hơn mặt bằng chung',
      );
      expect(find.textContaining('6.4 / 10'), findsOneWidget);
    });

    testWidgets('chưa từng làm thì nói rõ chứ không hiện bản so sánh rỗng', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(FakeWrOrgSurveyRepository(), initial: '/wr/org-survey/result'),
      );
      expect(
        find.byKey(const Key('wr_org_survey_result_empty')),
        findsOneWidget,
      );
    });

    OrgSurveyResponse resp({String? industry}) => OrgSurveyResponse(
      id: 'r1',
      answers: const {},
      enps: 8,
      areaAverages: {for (final a in OrgSurveyArea.values) a: 3.0},
      industry: industry,
      createdAt: DateTime(2026, 10, 1),
    );

    List<FakeSurveyRow> people(int n, {String? industry}) => [
      for (var u = 0; u < n; u++)
        FakeSurveyRow(
          userId: 'p$u',
          createdAt: DateTime(2026, 10, 1, 9, u),
          industry: industry,
          enps: 7,
          areaAverages: {for (final a in OrgSurveyArea.values) a: 2.0},
        ),
    ];

    testWidgets(
      '9 người → một khối "Hiện đã có 9 người", không còn chữ "Chưa đủ dữ liệu để so sánh"',
      (tester) async {
        final repo = FakeWrOrgSurveyRepository(latest: resp(), rows: people(9));
        await _pump(tester, _wrap(repo, initial: '/wr/org-survey/result'));

        expect(find.textContaining('Hiện đã có 9 người'), findsOneWidget);
        expect(
          find.textContaining('đủ $kOrgSurveyMinSample người tham gia'),
          findsOneWidget,
        );
        expect(find.textContaining('Chưa đủ dữ liệu'), findsNothing);
      },
    );

    testWidgets('benchmark lỗi → "Chưa tải được phần so sánh" + Thử lại', (
      tester,
    ) async {
      final repo = FakeWrOrgSurveyRepository(
        latest: resp(),
        failBenchmark: true,
      );
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/result'));

      expect(find.text('Chưa tải được phần so sánh.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('Hiện đã có'), findsNothing);

      repo.failBenchmark = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa tải được phần so sánh.'), findsNothing);
      expect(find.textContaining('Hiện đã có 0 người'), findsOneWidget);
    });

    testWidgets('10 người cùng ngành → hiện dòng Cùng lĩnh vực', (
      tester,
    ) async {
      final repo = FakeWrOrgSurveyRepository(
        latest: resp(industry: 'tech'),
        rows: people(10, industry: 'tech'),
      );
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/result'));

      expect(find.text('Cùng lĩnh vực'), findsWidgets);
      expect(
        find.byKey(const Key('wr_org_survey_industry_row_compensation')),
        findsOneWidget,
      );
    });

    testWidgets('ngành chưa đủ 10 người → không hiện dòng Cùng lĩnh vực', (
      tester,
    ) async {
      final repo = FakeWrOrgSurveyRepository(
        latest: resp(industry: 'tech'),
        rows: [
          ...people(10),
          ...people(3, industry: 'tech'),
        ],
      );
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/result'));
      expect(find.text('Cùng lĩnh vực'), findsNothing);
    });

    testWidgets('không extra + latest lỗi → không hiện _Empty', (tester) async {
      final repo = _LatestFailsRepo();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/result'));

      expect(find.byKey(const Key('wr_org_survey_result_empty')), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);

      repo.latest = resp();
      repo.failLatest = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('wr_org_survey_result_enps')),
        findsOneWidget,
      );
    });

    testWidgets('ngừng tham gia thì xoá thật, không chỉ đổi chữ', (
      tester,
    ) async {
      // Màn giới thiệu hứa "Có thể ngừng tham gia bất kỳ lúc nào". Một nút chỉ
      // ẩn kết quả đi mà không xoá là lời hứa không giữ.
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));
      await _answerEverything(tester, 5);

      await tester.tap(find.byKey(const Key('wr_org_survey_withdraw')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_org_survey_withdraw_confirm')));
      await tester.pumpAndSettle();

      expect(repo.withdrawCount, 1);
      expect(repo.latest, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('Mặt bằng chung v2 (repo giả chép luật SQL)', () {
    FakeSurveyRow row(
      String user,
      int minute, {
      String? industry,
      int? enps = 8,
      double v = 2,
    }) => FakeSurveyRow(
      userId: user,
      createdAt: DateTime(2026, 10, 1, 9, minute),
      industry: industry,
      enps: enps,
      areaAverages: {for (final a in OrgSurveyArea.values) a: v},
    );

    OrgSurveyBenchmark pick(
      List<OrgSurveyBenchmark> l,
      BenchmarkScope scope,
      OrgSurveyArea? area,
    ) => l.firstWhere((b) => b.scope == scope && b.area == area);

    test('fake: một người nộp 10 lần vẫn chỉ tính 1 mẫu', () async {
      final repo = FakeWrOrgSurveyRepository(
        rows: [for (var i = 0; i < 10; i++) row('u1', i)],
      );
      final res = await repo.fetchBenchmark();
      final enps = pick(res, BenchmarkScope.all, null);
      expect(enps.sampleSize, 1);
      expect(enps.source, BenchmarkSource.none);
      expect(res.every((b) => b.sampleSize == 1), isTrue);
    });

    test('fake: một người đổi lĩnh vực, chỉ phiếu mới nhất được đếm', () async {
      final repo = FakeWrOrgSurveyRepository(
        rows: [
          for (var u = 0; u < 10; u++) row('u$u', 0, industry: 'tech'),
          row('u0', 5, industry: 'retail'),
        ],
      );
      final res = await repo.fetchBenchmark(industry: 'tech');
      // 9 cùng ngành (dưới ngưỡng) → không lộ số đếm thật, trả 0.
      expect(pick(res, BenchmarkScope.industry, null).sampleSize, 0);
      expect(
        pick(res, BenchmarkScope.industry, null).source,
        BenchmarkSource.none,
      );
    });

    test('fake: 10 người khác nhau → live', () async {
      final repo = FakeWrOrgSurveyRepository(
        rows: [for (var u = 0; u < 10; u++) row('u$u', 0, v: 3)],
      );
      final res = await repo.fetchBenchmark();
      final b = pick(res, BenchmarkScope.all, OrgSurveyArea.growth);
      expect(b.sampleSize, 10);
      expect(b.source, BenchmarkSource.live);
      expect(b.value, 3);
    });

    test('fake: dưới ngưỡng thì phạm vi all rơi về tham chiếu', () async {
      final repo = FakeWrOrgSurveyRepository(
        rows: [for (var u = 0; u < 9; u++) row('u$u', 0)],
        reference: {OrgSurveyArea.growth: 2.7},
      );
      final res = await repo.fetchBenchmark();
      final b = pick(res, BenchmarkScope.all, OrgSurveyArea.growth);
      expect(b.source, BenchmarkSource.reference);
      expect(b.value, 2.7);
      expect(b.sampleSize, 9);
    });

    test(
      'industry: chỉ đếm phiếu cùng lĩnh vực, không rơi về tham chiếu',
      () async {
        final repo = FakeWrOrgSurveyRepository(
          rows: [
            for (var u = 0; u < 10; u++) row('t$u', 0, industry: 'tech', v: 3),
            for (var u = 0; u < 10; u++) row('r$u', 0, industry: 'retail'),
          ],
          reference: {OrgSurveyArea.growth: 2.7},
        );
        final tech = await repo.fetchBenchmark(industry: 'tech');
        expect(tech.length, 10);
        final t = pick(tech, BenchmarkScope.industry, OrgSurveyArea.growth);
        expect(t.sampleSize, 10);
        expect(t.source, BenchmarkSource.live);
        expect(
          pick(tech, BenchmarkScope.all, OrgSurveyArea.growth).sampleSize,
          20,
        );

        final retail = await repo.fetchBenchmark(industry: 'retail');
        final r = pick(retail, BenchmarkScope.industry, OrgSurveyArea.growth);
        // retail cũng 10 người, phần bù 10 → live.
        expect(r.sampleSize, 10);
        expect(r.source, BenchmarkSource.live);

        // Ngành nhỏ (4 người) → none, sampleSize 0, không rơi về tham chiếu.
        final small = FakeWrOrgSurveyRepository(
          rows: [
            for (var u = 0; u < 10; u++) row('t$u', 0, industry: 'tech', v: 3),
            for (var u = 0; u < 4; u++) row('r$u', 0, industry: 'retail'),
          ],
          reference: {OrgSurveyArea.growth: 2.7},
        );
        final sr = pick(
          await small.fetchBenchmark(industry: 'retail'),
          BenchmarkScope.industry,
          OrgSurveyArea.growth,
        );
        expect(sr.sampleSize, 0);
        expect(sr.source, BenchmarkSource.none);
        expect(sr.value, isNull);
      },
    );

    test(
      'industry: 10 cùng ngành + 1 ngành khác → dòng Cùng lĩnh vực KHÔNG live (chặn phép trừ)',
      () async {
        final repo = FakeWrOrgSurveyRepository(
          rows: [
            for (var u = 0; u < 10; u++) row('t$u', 0, industry: 'tech', v: 3),
            row('r0', 0, industry: 'retail', v: 1),
          ],
        );
        final res = await repo.fetchBenchmark(industry: 'tech');
        for (final area in [...OrgSurveyArea.values, null]) {
          final b = pick(res, BenchmarkScope.industry, area);
          expect(b.source, BenchmarkSource.none);
          expect(b.value, isNull);
          expect(b.sampleSize, 0);
        }
        // Phạm vi all vẫn live (11 người).
        expect(pick(res, BenchmarkScope.all, null).sampleSize, 11);
        expect(pick(res, BenchmarkScope.all, null).source, BenchmarkSource.live);
      },
    );

    test('industry: 10 cùng ngành + 10 ngành khác → live', () async {
      final repo = FakeWrOrgSurveyRepository(
        rows: [
          for (var u = 0; u < 10; u++) row('t$u', 0, industry: 'tech', v: 3),
          for (var u = 0; u < 10; u++) row('r$u', 0, industry: 'retail'),
        ],
      );
      final res = await repo.fetchBenchmark(industry: 'tech');
      final b = pick(res, BenchmarkScope.industry, OrgSurveyArea.growth);
      expect(b.source, BenchmarkSource.live);
      expect(b.sampleSize, 10);
      expect(b.value, 3);
    });

    test('industry: toàn bộ 10 người cùng ngành → live', () async {
      final repo = FakeWrOrgSurveyRepository(
        rows: [
          for (var u = 0; u < 10; u++) row('t$u', 0, industry: 'tech', v: 3),
        ],
      );
      final res = await repo.fetchBenchmark(industry: 'tech');
      final b = pick(res, BenchmarkScope.industry, null);
      expect(b.source, BenchmarkSource.live);
      expect(b.sampleSize, 10);
    });

    test('làm tròn 1 chữ số thập phân ở cả hai phạm vi', () async {
      // 12 người: 8 điểm 2 + 4 điểm 3 → 2.333 → 2.3; enps 7 x11 + 8 → 7.083 → 7.1
      final repo = FakeWrOrgSurveyRepository(
        rows: [
          for (var u = 0; u < 12; u++)
            row(
              't$u',
              0,
              industry: 'tech',
              v: u < 8 ? 2 : 3,
              enps: u == 0 ? 8 : 7,
            ),
        ],
      );
      final res = await repo.fetchBenchmark(industry: 'tech');
      for (final scope in [BenchmarkScope.all, BenchmarkScope.industry]) {
        expect(pick(res, scope, OrgSurveyArea.growth).value, 2.3);
        expect(pick(res, scope, null).value, 7.1);
      }
    });

    test('không truyền lĩnh vực thì chỉ trả phạm vi all', () async {
      final repo = FakeWrOrgSurveyRepository();
      final res = await repo.fetchBenchmark();
      expect(res.length, 5);
      expect(res.every((b) => b.scope == BenchmarkScope.all), isTrue);
    });

    test('submit gửi industry và chép CHECK 8 mã', () async {
      final repo = FakeWrOrgSurveyRepository();
      final saved = await repo.submit(
        answers: {'OS-01': 3},
        enps: 7,
        industry: 'tech',
      );
      expect(repo.submittedIndustry, 'tech');
      expect(saved.industry, 'tech');
      expect(repo.rows.single.industry, 'tech');

      await expectLater(
        repo.submit(answers: {'OS-01': 3}, industry: 'crypto'),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
        ),
      );
      // Không chọn lĩnh vực vẫn hợp lệ (cột cho phép NULL).
      await repo.submit(answers: {'OS-01': 3});
      expect(repo.submittedIndustry, isNull);
    });

    test(
      'lỗi đọc mặt bằng chung → provider báo lỗi, không trả map rỗng',
      () async {
        final repo = FakeWrOrgSurveyRepository(failBenchmark: true);
        final c = ProviderContainer(
          overrides: [wrOrgSurveyRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(c.dispose);
        await expectLater(
          c.read(wrOrgSurveyBenchmarkProvider(null).future),
          throwsA(isA<StateError>()),
        );
        expect(c.read(wrOrgSurveyBenchmarkProvider(null)).hasError, isTrue);
      },
    );

    test('provider tách hai phạm vi', () async {
      final repo = FakeWrOrgSurveyRepository(
        rows: [for (var u = 0; u < 10; u++) row('u$u', 0, industry: 'tech')],
      );
      final c = ProviderContainer(
        overrides: [wrOrgSurveyRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final b = await c.read(wrOrgSurveyBenchmarkProvider('tech').future);
      expect(b.all.length, 5);
      expect(b.industry.length, 5);
      expect(b.all[null]!.sampleSize, 10);
      final none = await c.read(wrOrgSurveyBenchmarkProvider(null).future);
      expect(none.industry, isEmpty);
    });
  });
}

class _LatestFailsRepo extends FakeWrOrgSurveyRepository {
  bool failLatest = true;

  @override
  Future<OrgSurveyResponse?> fetchLatestResponse() async {
    if (failLatest) throw StateError('boom');
    return latest;
  }
}
