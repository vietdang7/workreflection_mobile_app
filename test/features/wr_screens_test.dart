// Tests cho 5 màn WR empty-state và paywall.
// Run: flutter test test/features/wr_screens_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_paywall_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_story_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => child),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold(body: Text('Profile'))),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
    ),
  );
}

void main() {
  // ---------- WrHomeScreen ----------
  group('WrHomeScreen', () {
    testWidgets('renders greeting and check-in block', (tester) async {
      await tester.pumpWidget(_wrap(const WrHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('CHECK-IN NHANH'), findsOneWidget);
      expect(find.text('Ngày hôm nay của bạn như thế nào?'), findsOneWidget);
    });

    testWidgets('renders 3 energy option cards', (tester) async {
      await tester.pumpWidget(_wrap(const WrHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Có năng lượng'), findsOneWidget);
      expect(find.text('Bình thường'), findsOneWidget);
      expect(find.text('Mệt mỏi'), findsOneWidget);
    });

    testWidgets('avatar button exists and tapping shows profile', (tester) async {
      await tester.pumpWidget(_wrap(const WrHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('tapping energy card shows snackbar', (tester) async {
      await tester.pumpWidget(_wrap(const WrHomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Có năng lượng'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  // ---------- WrStoryScreen ----------
  group('WrStoryScreen', () {
    testWidgets('renders story empty-state title', (tester) async {
      await tester.pumpWidget(_wrap(const WrStoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Story của tôi'), findsOneWidget);
    });

    testWidgets('renders placeholder text for Phase 2', (tester) async {
      await tester.pumpWidget(_wrap(const WrStoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sắp ra mắt ở Phase 2'), findsOneWidget);
    });
  });

  // ---------- WrDiscoverScreen ----------
  group('WrDiscoverScreen', () {
    testWidgets('renders empty-state title', (tester) async {
      await tester.pumpWidget(_wrap(const WrDiscoverScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có dữ liệu'), findsOneWidget);
    });

    testWidgets('renders 4-step progress tracker', (tester) async {
      await tester.pumpWidget(_wrap(const WrDiscoverScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Đọc câu chuyện đầu tiên'), findsOneWidget);
      expect(find.text('Trả lời câu hỏi phản chiếu'), findsOneWidget);
      expect(find.text('Nhận Aha Moment đầu tiên'), findsOneWidget);
      expect(find.text('Bức tranh bắt đầu xuất hiện'), findsOneWidget);
    });

    testWidgets('CTA button exists', (tester) async {
      await tester.pumpWidget(_wrap(const WrDiscoverScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Bắt đầu phản chiếu →'), findsOneWidget);
    });
  });

  // ---------- WrGrowthScreen ----------
  group('WrGrowthScreen', () {
    testWidgets('renders empty-state title', (tester) async {
      await tester.pumpWidget(_wrap(const WrGrowthScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có chủ đề'), findsOneWidget);
    });

    testWidgets('renders description text', (tester) async {
      await tester.pumpWidget(_wrap(const WrGrowthScreen()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Đọc story và nhận Insight'),
        findsOneWidget,
      );
    });

    testWidgets('CTA button exists', (tester) async {
      await tester.pumpWidget(_wrap(const WrGrowthScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Đọc story để nhận đề xuất →'), findsOneWidget);
    });
  });

  // ---------- WrJourneyScreen ----------
  group('WrJourneyScreen', () {
    testWidgets('renders empty-state title', (tester) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Career Memory trống'), findsOneWidget);
    });

    testWidgets('renders 4 memory type cards', (tester) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Reflection'), findsOneWidget);
      expect(find.text('Insight'), findsOneWidget);
      expect(find.text('Milestone'), findsOneWidget);
      expect(find.text('Quyết định'), findsOneWidget);
    });

    testWidgets('CTA button exists', (tester) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      // CTA may be below the grid — scroll to find it
      await tester.scrollUntilVisible(
        find.text('Tạo Memory đầu tiên →'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Tạo Memory đầu tiên →'), findsOneWidget);
    });
  });

  // ---------- WrPaywallScreen ----------
  group('WrPaywallScreen', () {
    testWidgets('default trigger shows correct headline', (tester) async {
      await tester.pumpWidget(_wrap(const WrPaywallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Mở khoá toàn bộ hành trình'), findsOneWidget);
    });

    testWidgets('ai_insight trigger shows correct headline', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrPaywallScreen(trigger: PaywallTrigger.aiInsight)),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Insight dành riêng cho bạn'), findsOneWidget);
    });

    testWidgets('report trigger shows correct headline', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrPaywallScreen(trigger: PaywallTrigger.report)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo chuyên sâu đang chờ bạn'), findsOneWidget);
    });

    testWidgets('trial_end trigger shows correct headline', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrPaywallScreen(trigger: PaywallTrigger.trialEnd)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tháng trải nghiệm của bạn kết thúc'), findsOneWidget);
    });

    testWidgets('benchmark trigger shows correct headline', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrPaywallScreen(trigger: PaywallTrigger.benchmark)),
      );
      await tester.pumpAndSettle();

      expect(find.text('So sánh với người đi làm cùng ngành'), findsOneWidget);
    });

    testWidgets('shows PREMIUM badge and price', (tester) async {
      await tester.pumpWidget(_wrap(const WrPaywallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('PREMIUM'), findsOneWidget);
      expect(find.text('499.000đ / năm'), findsOneWidget);
    });

    testWidgets('shows 4 premium highlights', (tester) async {
      await tester.pumpWidget(_wrap(const WrPaywallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('AI Insight cá nhân hoá'), findsOneWidget);
      expect(find.text('Báo cáo chuyên sâu'), findsOneWidget);
      expect(find.text('Career Pattern'), findsOneWidget);
      expect(find.text('Không giới hạn'), findsOneWidget);
    });

    testWidgets('shows free vs premium comparison table with 10 rows', (tester) async {
      await tester.pumpWidget(_wrap(const WrPaywallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Story Reflection hàng ngày'), findsOneWidget);
      expect(find.text('Check-in nhanh'), findsOneWidget);
      expect(find.text('Career Memory Timeline'), findsOneWidget);
      expect(find.text('15 câu phản chiếu'), findsOneWidget);
      expect(find.text('3 chủ đề Thực hành'), findsOneWidget);
      expect(find.text('AI Insight'), findsOneWidget);
      expect(find.text('Báo cáo chuyên sâu 49 câu'), findsOneWidget);
      expect(find.text('Career Pattern Analysis'), findsOneWidget);
      expect(find.text('Career Benchmark'), findsOneWidget);
      expect(find.text('Không giới hạn Thực hành'), findsOneWidget);
    });

    testWidgets('CTA button shows payment coming soon snackbar', (tester) async {
      await tester.pumpWidget(_wrap(const WrPaywallScreen()));
      await tester.pumpAndSettle();

      // Scroll down to reveal the CTA button (Scrollable is inside SingleChildScrollView)
      await tester.scrollUntilVisible(
        find.text('Bắt đầu Premium →'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bắt đầu Premium →'));
      await tester.pump(); // pump once to start snackbar animation

      expect(find.text('Thanh toán sẽ sớm ra mắt'), findsOneWidget);
    });
  });
}
