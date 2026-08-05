// Khảo sát tổ chức (ESI + eNPS) — mockup Sprint 2, mở từ màn Hồ sơ.
// Run: flutter test test/features/wr_org_survey_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_org_survey_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_org_survey_scoring.dart';
import 'package:workreflection_mobile/core/models/wr_org_survey.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_org_survey_flow_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_org_survey_intro_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_org_survey_result_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_wr_org_survey_repository.dart';

Widget _wrap(
  FakeWrOrgSurveyRepository repo, {
  String initial = '/wr/org-survey',
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
    overrides: [wrOrgSurveyRepositoryProvider.overrideWithValue(repo)],
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

/// Trả lời hết 5 câu thang + câu eNPS.
Future<void> _answerEverything(WidgetTester tester, int count) async {
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
      expect(find.textContaining('không ảnh hưởng đến Reflection'),
          findsOneWidget);
      expect(find.textContaining('Không bắt buộc'), findsOneWidget);
      expect(find.textContaining('ngừng tham gia'), findsOneWidget);
    });

    testWidgets('số câu đếm từ bảng hỏi, không ghi cứng', (tester) async {
      // Repo giả có 5 câu → 5 + 1 câu eNPS.
      await _pump(tester, _wrap(FakeWrOrgSurveyRepository()));
      expect(find.textContaining('Trả lời 6 câu ngắn'), findsOneWidget);
    });

    testWidgets('đọc hỏng bảng hỏi thì KHÓA nút bắt đầu', (tester) async {
      // Mở luồng khi chưa có câu nào là đẩy người dùng vào một màn trống.
      await _pump(
        tester,
        _wrap(FakeWrOrgSurveyRepository(failQuestions: true)),
      );

      expect(find.byKey(const Key('wr_org_survey_questions_error')),
          findsOneWidget);
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

      await tester.tap(find.byKey(const Key('wr_org_survey_option_3')));
      await tester.pumpAndSettle();
      expect(repo.submittedAnswers, isNull, reason: 'chưa xong mà đã gửi');

      await _answerEverything(tester, 4);

      expect(repo.submittedAnswers?.length, 5);
      expect(repo.submittedEnps, 8);
    });

    testWidgets('câu cuối là eNPS 0..10, không phải thang 5 mức',
        (tester) async {
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('wr_org_survey_option_0')));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(const Key('wr_org_survey_enps_0')), findsOneWidget);
      expect(find.byKey(const Key('wr_org_survey_enps_10')), findsOneWidget);
      expect(find.byKey(const Key('wr_org_survey_option_0')), findsNothing);
    });

    testWidgets('gửi hỏng thì giữ nguyên câu trả lời và cho gửi lại',
        (tester) async {
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

    testWidgets('bấm Đóng giữa chừng thì hỏi lại trước khi mất hết',
        (tester) async {
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));

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

      expect(find.byKey(const Key('wr_org_survey_result_enps')), findsOneWidget);
      expect(find.text('8 / 10'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('Màn kết quả', () {
    testWidgets('CHƯA đủ mẫu thì không vẽ vạch so sánh và nói thẳng vì sao',
        (tester) async {
      // Khác mockup có chủ ý: mockup ghi cứng mặt bằng chung bằng số minh hoạ.
      // Dán nhãn "ẩn danh" lên số bịa là nói một điều không có thật.
      final repo = FakeWrOrgSurveyRepository();
      await _pump(tester, _wrap(repo, initial: '/wr/org-survey/flow'));
      await _answerEverything(tester, 5);

      expect(find.byKey(const Key('wr_org_survey_no_benchmark')), findsOneWidget);
      expect(find.text('Mặt bằng chung (ẩn danh)'), findsNothing);
      expect(find.text('Kết quả của bạn'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_org_survey_standing_compensation')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
                find.byKey(const Key('wr_org_survey_standing_compensation')))
            .data,
        OrgSurveyStanding.noBenchmark.label,
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
                find.byKey(const Key('wr_org_survey_standing_compensation')))
            .data,
        'Cao hơn mặt bằng chung',
      );
      expect(find.textContaining('6.4 / 10'), findsOneWidget);
    });

    testWidgets('chưa từng làm thì nói rõ chứ không hiện bản so sánh rỗng',
        (tester) async {
      await _pump(
        tester,
        _wrap(FakeWrOrgSurveyRepository(),
            initial: '/wr/org-survey/result'),
      );
      expect(
        find.byKey(const Key('wr_org_survey_result_empty')),
        findsOneWidget,
      );
    });

    testWidgets('ngừng tham gia thì xoá thật, không chỉ đổi chữ',
        (tester) async {
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
}
