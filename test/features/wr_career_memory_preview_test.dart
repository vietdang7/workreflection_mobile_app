// Tab Hành trình chỉ hiện vài mảnh Career Memory gần nhất; phần còn lại nằm ở
// màn riêng /wr/career-memory.
//
// Yêu cầu khách 2026-08-01: "mục bảng Career memory nó dài quá, thêm nút ẩn bớt
// lại, cần thì ấn vào chuyển sang trang để hiển thị hết ra".
//
// Run: flutter test test/features/wr_career_memory_preview_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// [n] mảnh ký ức, mỗi mảnh một ngày khác nhau để tiêu đề dễ phân biệt.
List<CareerMemoryEvent> _events(int n) => [
      for (var i = 1; i <= n; i++)
        CareerMemoryEvent(
          id: 'e$i',
          userId: 'u1',
          behavior: 'insight',
          reflectionText: 'Mảnh ký ức số $i',
          createdAt: DateTime(2026, 7, 1).add(Duration(days: i)),
        ),
    ];

Widget _wrap({
  required Widget home,
  required List<CareerMemoryEvent> events,
  bool premium = true,
}) {
  final content = FakeWrContentRepository()..seedMemoryEvents(events);
  final intel = FakeWrIntelligenceRepository();
  if (premium) {
    intel.seedEntitlement(
      WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
    );
  }

  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => home),
      GoRoute(
        path: '/wr/career-memory',
        builder: (_, __) => const WrCareerMemoryScreen(),
      ),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const Scaffold(body: Text('PaywallScreen')),
      ),
      GoRoute(
        path: '/wr/journey/narrative',
        builder: (_, __) => const Scaffold(body: Text('Narrative')),
      ),
      GoRoute(
        path: '/wr/discover',
        builder: (_, __) => const Scaffold(body: Text('DiscoverScreen')),
      ),
      GoRoute(
        path: '/wr/ask',
        builder: (_, __) => const Scaffold(body: Text('AskScreen')),
      ),
      GoRoute(
        path: '/wr/work-info',
        builder: (_, __) => const Scaffold(body: Text('WorkInfo')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('Profile')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(content),
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpTall(WidgetTester tester, Widget widget) async {
  // Màn cao để mọi thứ nằm trong cây widget — bài test này đếm số dòng, không
  // kiểm cuộn.
  tester.view.physicalSize = const Size(1080, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

int _visibleEntries(WidgetTester tester, int total) {
  var found = 0;
  for (var i = 1; i <= total; i++) {
    if (find.text('Mảnh ký ức số $i').evaluate().isNotEmpty) found++;
  }
  return found;
}

void main() {
  group('Tab Hành trình — Career Memory rút gọn', () {
    testWidgets('nhiều hơn ngưỡng thì chỉ hiện $kJourneyPreviewCount mảnh',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrJourneyScreen(), events: _events(38)),
      );

      expect(_visibleEntries(tester, 38), kJourneyPreviewCount);
    });

    testWidgets('hiện nút xem tất cả kèm tổng số và số còn lại', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrJourneyScreen(), events: _events(38)),
      );

      expect(find.byKey(const Key('wr_journey_memory_see_all')), findsOneWidget);
      expect(find.text('Xem tất cả 38 mảnh ký ức'), findsOneWidget);
      expect(find.text('Còn 33 mảnh nữa'), findsOneWidget);
    });

    testWidgets('vừa đúng ngưỡng thì không có nút — không giấu gì cả',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(
          home: const WrJourneyScreen(),
          events: _events(kJourneyPreviewCount),
        ),
      );

      expect(_visibleEntries(tester, kJourneyPreviewCount), kJourneyPreviewCount);
      expect(find.byKey(const Key('wr_journey_memory_see_all')), findsNothing);
    });

    testWidgets('bản miễn phí vẫn bị khoá, không lòi nút xem tất cả',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(
          home: const WrJourneyScreen(),
          events: _events(38),
          premium: false,
        ),
      );

      expect(find.byKey(const Key('wr_journey_memory_lock')), findsOneWidget);
      expect(find.byKey(const Key('wr_journey_memory_see_all')), findsNothing);
      expect(_visibleEntries(tester, 38), 0);
    });

    testWidgets('bấm nút thì sang màn Career Memory đầy đủ', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrJourneyScreen(), events: _events(38)),
      );

      await tester.tap(find.byKey(const Key('wr_journey_memory_see_all')));
      await tester.pumpAndSettle();

      expect(find.text('Tất cả 38 mảnh ký ức'), findsOneWidget);
    });
  });

  group('WrCareerMemoryScreen', () {
    testWidgets('liệt kê đủ mọi mảnh, không cắt bớt', (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: _events(38)),
      );

      expect(_visibleEntries(tester, 38), 38);
    });

    testWidgets('bản miễn phí bị khoá — mở thẳng đường dẫn không đi vòng được',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(
          home: const WrCareerMemoryScreen(),
          events: _events(38),
          premium: false,
        ),
      );

      expect(find.byKey(const Key('wr_career_memory_lock')), findsOneWidget);
      expect(_visibleEntries(tester, 38), 0);
    });

    testWidgets('chưa có mảnh nào thì nói rõ, không để trang trắng',
        (tester) async {
      await _pumpTall(
        tester,
        _wrap(home: const WrCareerMemoryScreen(), events: const []),
      );

      expect(find.byKey(const Key('wr_career_memory_empty')), findsOneWidget);
    });
  });
}
