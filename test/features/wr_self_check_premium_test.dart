// Widget tests — WrSelfCheckScreen theo script Sprint 2 (`scaQuestionScreen`,
// `scaResultScreen`): vào thẳng câu 1, năm mức LIKERT, màn kết quả ba trụ +
// thẻ khoá Premium.
// Run: flutter test test/features/wr_self_check_premium_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/widgets/wr_title_text.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_self_check_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

Widget _wrap({
  required FakeWrIntelligenceRepository intel,
  FakeWrContentRepository? content,
}) {
  // Bộ câu hỏi là route CON của '/', không phải route gốc: có vậy ngăn xếp mới
  // có chỗ để lùi về khi người dùng bấm "Đóng". Dựng nó làm route gốc thì
  // `context.pop()` không có gì để pop và test không kiểm được lối thoát.
  final router = GoRouter(
    initialLocation: '/wr/self-check',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('HOME')),
        routes: [
          GoRoute(
            path: 'wr/self-check',
            builder: (_, __) => const WrSelfCheckScreen(),
          ),
          GoRoute(
            path: 'wr/paywall',
            builder: (_, __) => const Scaffold(body: Text('PAYWALL')),
          ),
          GoRoute(
            path: 'wr/sca-deep-dive',
            builder: (_, __) => const Scaffold(body: Text('DEEP DIVE')),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
      wrContentRepositoryProvider.overrideWithValue(
        content ?? FakeWrContentRepository(),
      ),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: router,
    ),
  );
}

/// Trả lời cả 15 câu bằng nhãn LIKERT [label]. Màn mở thẳng vào câu 1.
Future<void> _completeSurvey(
  WidgetTester tester, {
  String label = 'Không bao giờ',
}) async {
  for (var i = 0; i < kSelfCheckQuestions.length; i++) {
    // Ô chọn cuối nằm dưới mép màn trên viewport thấp của test — cuộn tới đã
    // rồi mới chạm, đúng như người dùng phải làm.
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }
}

WrEntitlementRecord _premium() => WrEntitlementRecord(
  userId: 'u1',
  plan: WrPlan.premium,
  validUntil: DateTime.now().add(const Duration(days: 30)),
);

void main() {
  testWidgets('không còn màn giới thiệu: mở ra là câu 1', (tester) async {
    final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    expect(find.text('Bắt đầu →'), findsNothing);
    expect(find.text('Câu 1 / ${kSelfCheckQuestions.length}'), findsOneWidget);
  });

  testWidgets('năm mức trả lời đúng nguyên văn LIKERT của script', (
    tester,
  ) async {
    final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    for (final l in const [
      'Không bao giờ',
      'Hiếm khi',
      'Đôi khi',
      'Thường xuyên',
      'Gần như luôn luôn',
    ]) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
  });

  testWidgets('giá trị lưu vẫn là thang 1–5: "Thường xuyên" là 4', (
    tester,
  ) async {
    final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    await _completeSurvey(tester, label: 'Thường xuyên');

    final saved = intel.insertSelfCheckResponseCalls.single;
    expect(saved.answers.values.toSet(), {4});
    expect(saved.structureScore, 4.0);
  });

  testWidgets('Free: màn kết quả đúng script, thẻ khoá mở paywall', (
    tester,
  ) async {
    final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    await _completeSurvey(tester);

    expect(find.text('KẾT QUẢ KHẢO SÁT'), findsOneWidget);
    expect(
      find.text(wrKeepTitleTail('Điều kiện xung quanh bạn')),
      findsOneWidget,
    );
    expect(find.text('Sự rõ ràng trong công việc'), findsOneWidget);
    expect(find.text('Niềm tin & an toàn để lên tiếng'), findsOneWidget);
    expect(find.text('Nhịp thực thi & nhìn lại'), findsOneWidget);
    // "Không bao giờ" đều cả ba trụ = 1.0 → "Đang cản trở".
    expect(find.text('Đang cản trở'), findsNWidgets(3));

    // Phần app tự thêm mà script không có đã đi.
    expect(find.text('ĐIỀU ĐÁNG CHÚ Ý NHẤT'), findsNothing);
    expect(find.text('Vào Thực hành'), findsNothing);
    expect(find.text('Xem Hành trình'), findsNothing);

    final cta = find.byKey(const Key('wr_self_check_result_cta'));
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    expect(find.text('Xem diễn giải đầy đủ'), findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('PAYWALL'), findsOneWidget);
  });

  testWidgets('Paid: nút của thẻ khoá vào thẳng màn Diễn giải sâu', (
    tester,
  ) async {
    final intel = FakeWrIntelligenceRepository()..seedEntitlement(_premium());
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    await _completeSurvey(tester, label: 'Gần như luôn luôn');
    expect(find.text('Đang hỗ trợ tốt'), findsNWidgets(3));

    final cta = find.byKey(const Key('wr_self_check_result_cta'));
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    expect(find.text('Xem diễn giải sâu'), findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('DEEP DIVE'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Lối thoát. Script đóng thẳng, không hỏi lại; câu 1 lùi nữa là rời màn.
  // ───────────────────────────────────────────────────────────────────────────
  group('thoát khỏi bộ câu hỏi', () {
    testWidgets('"Đóng" rời màn ngay, kể cả khi đã trả lời vài câu', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(intel: intel));
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Đôi khi'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }
      expect(find.text('Câu 4 / 15'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_self_check_close')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(WrSelfCheckScreen), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
      // Bài dở không được ghi xuống.
      expect(intel.insertSelfCheckResponseCalls, isEmpty);
    });

    testWidgets('lùi ở câu 1 là rời màn', (tester) async {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(intel: intel));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Câu trước'));
      await tester.pumpAndSettle();

      expect(find.byType(WrSelfCheckScreen), findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Đổi ý giữa hai lựa chọn — hồi quy cho lỗi đã ăn mất dữ liệu thật.
  //
  // Trước bản vá, mỗi lượt chạm hẹn thêm một lần tự nhảy câu sau 260ms. Chọn
  // một mức rồi đổi sang mức khác là hai lần hẹn cùng nổ: một câu bị bỏ qua,
  // và ở câu cuối thì `_finishSurvey` chạy hai lượt, ghi hai bản ghi.
  //
  // Trên DB thật (tài khoản e9588fae…) đã có đúng ba cặp bản ghi trùng
  // 23/7 · 29/7 · 30/7, và bản 30/7 chỉ còn 12/15 câu — thiếu scq-04, scq-05,
  // scq-07.
  // ───────────────────────────────────────────────────────────────────────────
  group('đổi ý giữa chừng không được ăn mất câu', () {
    /// Chạm [first] rồi đổi sang [second] TRƯỚC khi màn kịp tự nhảy câu.
    Future<void> answerThenChangeMind(
      WidgetTester tester, {
      String first = 'Đôi khi',
      String second = 'Thường xuyên',
    }) async {
      // Kéo cả hai ô vào tầm mắt TRƯỚC khi chạm: giữa hai lượt chạm chỉ được
      // phép trôi qua dưới 260ms, không còn chỗ cho thao tác cuộn.
      await tester.ensureVisible(find.text(second));
      await tester.pumpAndSettle();
      await tester.tap(find.text(first));
      await tester.pump(const Duration(milliseconds: 100)); // < 260ms
      await tester.tap(find.text(second));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    testWidgets('trả lời đủ 15 câu, không câu nào bị nhảy qua', (tester) async {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(intel: intel));
      await tester.pumpAndSettle();

      for (var i = 0; i < kSelfCheckQuestions.length; i++) {
        // Số câu hiện trên đầu màn phải tăng đúng một bậc mỗi vòng.
        expect(
          find.text('Câu ${i + 1} / ${kSelfCheckQuestions.length}'),
          findsOneWidget,
          reason: 'đã nhảy quá câu ${i + 1}',
        );
        await answerThenChangeMind(tester);
      }

      expect(intel.insertSelfCheckResponseCalls, hasLength(1));
      expect(
        intel.insertSelfCheckResponseCalls.single.answers,
        hasLength(kSelfCheckQuestions.length),
      );
    });

    testWidgets('đổi ý ở câu cuối chỉ ghi xuống một bản ghi', (tester) async {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(intel: intel));
      await tester.pumpAndSettle();

      for (var i = 0; i < kSelfCheckQuestions.length - 1; i++) {
        await tester.tap(find.text('Đôi khi'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      await answerThenChangeMind(tester);

      expect(find.byKey(const Key('wr_self_check_result')), findsOneWidget);
      expect(intel.insertSelfCheckResponseCalls, hasLength(1));
    });

    testWidgets('mức được ghi là mức chọn SAU CÙNG', (tester) async {
      // Vá lỗi bằng cách chặn lượt chạm thứ hai cũng hết nhảy câu, nhưng khi đó
      // người dùng không đổi ý được nữa và mức ghi xuống là mức chạm nhầm.
      // Test này khoá lại: huỷ-rồi-hẹn-lại, không phải chặn.
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(intel: intel));
      await tester.pumpAndSettle();

      for (var i = 0; i < kSelfCheckQuestions.length; i++) {
        await answerThenChangeMind(
          tester,
          first: 'Không bao giờ', //      1
          second: 'Gần như luôn luôn', // 5
        );
      }

      final saved = intel.insertSelfCheckResponseCalls.single;
      expect(saved.answers.values.toSet(), {5});
    });
  });
}
