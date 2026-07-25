// Widget tests — WrSelfCheckScreen, tầng Free vs Paid.
// Spec: Kiến trúc Dữ liệu Hai Lớp v1.2 §II + §IV (khoá cấp tính năng).
// Run: flutter test test/features/wr_self_check_premium_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  final router = GoRouter(
    initialLocation: '/wr/self-check',
    routes: [
      GoRoute(
        path: '/wr/self-check',
        builder: (_, __) => const WrSelfCheckScreen(),
      ),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const Scaffold(body: Text('PAYWALL')),
      ),
      GoRoute(path: '/wr/growth', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/wr/journey', builder: (_, __) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
      wrContentRepositoryProvider
          .overrideWithValue(content ?? FakeWrContentRepository()),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
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
  for (var i = 0; i < 16; i++) {
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
}
