// Widget tests — WrSelfCheckScreen, tầng Free vs Paid.
// Spec: Kiến trúc Dữ liệu Hai Lớp v1.2 §II + §IV (khoá cấp tính năng).
// Run: flutter test test/features/wr_self_check_premium_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
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
          GoRoute(path: 'wr/growth', builder: (_, __) => const Scaffold()),
          GoRoute(path: 'wr/journey', builder: (_, __) => const Scaffold()),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
      wrContentRepositoryProvider
          .overrideWithValue(content ?? FakeWrContentRepository()),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,routerConfig: router),
  );
}

/// Bắt đầu và trả lời cả 15 câu bằng nhãn Likert [label].
Future<void> _completeSurvey(
  WidgetTester tester, {
  String label = 'Hoàn toàn không đúng',
}) async {
  await tester.tap(find.text('Bắt đầu →'));
  await tester.pumpAndSettle();

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

/// Cuộn trang kết quả từ trên xuống để tìm [finder] (sliver ngoài màn hình
/// chưa được dựng nên find.text đơn thuần không thấy).
Future<bool> _seenWhileScrolling(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.drag(scrollable, const Offset(0, 4000));
  await tester.pumpAndSettle();
  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.drag(scrollable, const Offset(0, -260));
    await tester.pumpAndSettle();
  }
  return finder.evaluate().isNotEmpty;
}

Future<void> _expectVisible(WidgetTester tester, Finder f, {String? why}) async {
  expect(await _seenWhileScrolling(tester, f), isTrue, reason: why);
}

Future<void> _expectAbsent(WidgetTester tester, Finder f, {String? why}) async {
  expect(await _seenWhileScrolling(tester, f), isFalse, reason: why);
}

/// Mở một mục thu gọn ở trang kết quả bằng cách chạm vào dòng chữ in hoa.
Future<void> _openSection(WidgetTester tester, String title) async {
  final header = find.byKey(Key('self_check_section_$title'));
  expect(await _seenWhileScrolling(tester, header), isTrue,
      reason: 'không thấy mục "$title"');
  await tester.ensureVisible(header);
  await tester.pumpAndSettle();
  await tester.tap(header);
  await tester.pumpAndSettle();
}

WrEntitlementRecord _premium() => WrEntitlementRecord(
      userId: 'u1',
      plan: WrPlan.premium,
      validUntil: DateTime.now().add(const Duration(days: 30)),
    );

void main() {
  testWidgets('Free: thấy 3 trụ + đọc nhanh, khối diễn giải sâu bị khoá',
      (tester) async {
    final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    await _completeSurvey(tester);

    expect(find.text('Bức tranh của bạn'), findsOneWidget);
    expect(find.text('Sự rõ ràng'), findsWidgets);

    await _expectVisible(tester, find.text('ĐIỀU ĐÁNG CHÚ Ý NHẤT'));
    await _expectVisible(tester, find.text('DIỄN GIẢI SÂU'));
    await _expectVisible(tester, find.text('Premium'));
    await _expectVisible(tester, find.text('Mở diễn giải sâu'));

    // Không lộ nội dung Paid.
    await _expectAbsent(tester, find.text('XU HƯỚNG THEO THỜI GIAN'));
    await _expectAbsent(tester, find.text('MẤT CÂN BẰNG GIỮA CÁC MẶT'));
  });

  testWidgets('Free: nút nâng cấp mở paywall', (tester) async {
    final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    await _completeSurvey(tester);
    await _expectVisible(tester, find.text('Mở diễn giải sâu'));

    // _expectVisible cuộn hết trang rồi trả về đầu, nên nút lại nằm ngoài
    // khung — phải kéo nó vào tầm mắt trước khi chạm.
    await tester.ensureVisible(find.text('Mở diễn giải sâu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở diễn giải sâu'));
    await tester.pumpAndSettle();

    expect(find.text('PAYWALL'), findsOneWidget);
  });

  testWidgets('Paid: thấy diễn giải sâu và khối xu hướng', (tester) async {
    final intel = FakeWrIntelligenceRepository()..seedEntitlement(_premium());
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    await _completeSurvey(tester);

    await _expectVisible(tester, find.text('DIỄN GIẢI SÂU'));
    await _expectAbsent(tester, find.text('Mở diễn giải sâu'));
    await _expectVisible(tester, find.text('XU HƯỚNG THEO THỜI GIAN'));

    // Mục thu gọn sẵn: nội dung chỉ hiện sau khi chạm vào dòng chữ in hoa.
    await _expectAbsent(tester, find.textContaining('lần tự soi đầu tiên'));
    await _openSection(tester, 'XU HƯỚNG THEO THỜI GIAN');
    await _expectVisible(tester, find.textContaining('lần tự soi đầu tiên'));
  });

  testWidgets('Paid: có lịch sử thì hiện so sánh với lần trước',
      (tester) async {
    final now = DateTime.now();
    final intel = FakeWrIntelligenceRepository()
      ..seedEntitlement(_premium())
      ..seedSelfCheckHistory([
        ScaSelfCheckResponse(
          userId: 'u1',
          answers: const {},
          structureScore: 1.0,
          cultureScore: 1.0,
          activityScore: 1.0,
          takenAt: now.subtract(const Duration(days: 1)),
        ),
        ScaSelfCheckResponse(
          userId: 'u1',
          answers: const {},
          structureScore: 1.0,
          cultureScore: 1.0,
          activityScore: 1.0,
          takenAt: now.subtract(const Duration(days: 30)),
        ),
      ]);
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    // Hai lần trước đều rất thấp, lần này trả lời cao nhất → xu hướng đi lên.
    await _completeSurvey(tester, label: 'Hoàn toàn đúng');

    await _openSection(tester, 'XU HƯỚNG THEO THỜI GIAN');
    await _expectVisible(tester, find.textContaining('Đã ghi 3 lần tự soi'));
    await _expectVisible(tester, find.textContaining('cải thiện'));
  });

  testWidgets('Paid: khi ba mặt lệch nhau thì hiện khối mất cân bằng',
      (tester) async {
    final intel = FakeWrIntelligenceRepository()..seedEntitlement(_premium());
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    // Trả lời thấp toàn bộ → cả ba trụ đều dưới 2.8 → allLow.
    await _completeSurvey(tester);

    await _expectVisible(tester, find.text('MẤT CÂN BẰNG GIỮA CÁC MẶT'));
  });

  testWidgets('Paid: mục mất cân bằng thu gọn sẵn, chạm mới mở ra',
      (tester) async {
    final intel = FakeWrIntelligenceRepository()..seedEntitlement(_premium());
    await tester.pumpWidget(_wrap(intel: intel));
    await tester.pumpAndSettle();

    await _completeSurvey(tester);

    // Chỉ dòng chữ in hoa hiện ra, đoạn diễn giải nằm im.
    await _expectVisible(tester, find.text('MẤT CÂN BẰNG GIỮA CÁC MẶT'));
    await _expectAbsent(tester, find.textContaining('Cả ba mặt đều đang ở mức thấp'));

    await _openSection(tester, 'MẤT CÂN BẰNG GIỮA CÁC MẶT');
    await _expectVisible(tester, find.textContaining('Cả ba mặt đều đang ở mức thấp'));

    // Chạm lần nữa thì thu lại.
    await _openSection(tester, 'MẤT CÂN BẰNG GIỮA CÁC MẶT');
    await _expectAbsent(tester, find.textContaining('Cả ba mặt đều đang ở mức thấp'));
  });

  testWidgets('Paid: đối chiếu với pattern lặp lại của cùng một mặt',
      (tester) async {
    final content = FakeWrContentRepository()
      ..seedSituations([
        const WrSituation(
          code: 'C2-sit-01',
          text: 'Không dám lên tiếng',
          scaDimension: ScaDimension.c2,
          humanNeed: HumanNeed.ketNoi,
          wave: 1,
        ),
      ]);
    final intel = FakeWrIntelligenceRepository()
      ..seedEntitlement(_premium())
      ..seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'C2-sit-01',
          scaDimension: ScaDimension.c2,
          occurrenceCount: 5,
          lastSeenAt: DateTime.now(),
        ),
      ]);

    await tester.pumpWidget(_wrap(intel: intel, content: content));
    await tester.pumpAndSettle();

    // Trả lời thấp đều → trụ thấp nhất hoà điểm, ưu tiên "Sự rõ ràng"; pattern
    // thuộc "Mối quan hệ" nên khối đối chiếu chỉ hiện khi khớp trụ.
    await _completeSurvey(tester, label: 'Hoàn toàn đúng');

    await _expectVisible(tester, find.text('DIỄN GIẢI SÂU'));
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Lối thoát. Trước bản này màn chỉ có mũi tên lùi MỘT câu — đang ở câu 12 mà
  // muốn ra thì phải bấm mười hai lần, tức là trên thực tế không có cửa ra.
  // ───────────────────────────────────────────────────────────────────────────
  group('thoát khỏi bộ câu hỏi', () {
    Future<void> openFirstQuestion(WidgetTester tester) async {
      await tester.tap(find.text('Bắt đầu →'));
      await tester.pumpAndSettle();
    }

    testWidgets('chưa trả lời câu nào thì đóng thẳng, không cản đường',
        (tester) async {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(intel: intel));
      await tester.pumpAndSettle();

      await openFirstQuestion(tester);
      expect(find.byKey(const Key('wr_self_check_close')), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_self_check_close')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Thoát khỏi bộ câu hỏi'), findsNothing);
      expect(find.byType(WrSelfCheckScreen), findsNothing);
    });

    testWidgets('đã trả lời rồi thì hỏi lại trước khi bỏ', (tester) async {
      // Bài dở không được lưu ở đâu cả — chạm nhầm "Đóng" là mất sạch.
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(intel: intel));
      await tester.pumpAndSettle();

      await openFirstQuestion(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Đôi khi đúng'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('wr_self_check_close')));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 câu bạn đã trả lời'), findsOneWidget);

      // "Làm tiếp" đưa về đúng chỗ đang dở, không mất gì.
      await tester.tap(find.text('Làm tiếp'));
      await tester.pumpAndSettle();
      expect(find.text('Câu 4 / 15'), findsOneWidget);

      // "Thoát" mới thật sự ra khỏi màn, và không ghi gì xuống.
      await tester.tap(find.byKey(const Key('wr_self_check_close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_self_check_close_confirm')));
      await tester.pumpAndSettle();

      expect(find.byType(WrSelfCheckScreen), findsNothing);
      expect(intel.insertSelfCheckResponseCalls, isEmpty);
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
      String first = 'Đôi khi đúng',
      String second = 'Khá đúng',
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

      await tester.tap(find.text('Bắt đầu →'));
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

      await tester.tap(find.text('Bắt đầu →'));
      await tester.pumpAndSettle();

      for (var i = 0; i < kSelfCheckQuestions.length - 1; i++) {
        await tester.tap(find.text('Đôi khi đúng'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      await answerThenChangeMind(tester);

      expect(find.text('Bức tranh của bạn'), findsOneWidget);
      expect(intel.insertSelfCheckResponseCalls, hasLength(1));
    });

    testWidgets('mức được ghi là mức chọn SAU CÙNG', (tester) async {
      // Vá lỗi bằng cách chặn lượt chạm thứ hai cũng hết nhảy câu, nhưng khi đó
      // người dùng không đổi ý được nữa và mức ghi xuống là mức chạm nhầm.
      // Test này khoá lại: huỷ-rồi-hẹn-lại, không phải chặn.
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(null);
      await tester.pumpWidget(_wrap(intel: intel));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bắt đầu →'));
      await tester.pumpAndSettle();

      for (var i = 0; i < kSelfCheckQuestions.length; i++) {
        await answerThenChangeMind(
          tester,
          first: 'Hoàn toàn không đúng', // 1
          second: 'Hoàn toàn đúng', //     5
        );
      }

      final saved = intel.insertSelfCheckResponseCalls.single;
      expect(saved.answers.values.toSet(), {5});
    });
  });
}
