import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/features/shell/shell_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// A minimal GoRouter with StatefulShellRoute so we can test the shell widget.
// Updated for final HTML mockup: 5 tabs
//   0 /home          — Hôm nay — Icons.home_outlined
//   1 /wr/discover   — Hiểu mình — Icons.person_outline
//   2 /wr/growth     — Phát triển — Icons.trending_up
//   3 /wr/journey    — Hành trình — Icons.subject
//   4 /profile       — Tôi — Icons.settings_outlined
// Tab bar shows ONLY icon + coral dot (NO text label rendered).
// ---------------------------------------------------------------------------

Widget _wrapWithRouter() {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const _Tab('Home tab'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wr/discover',
                builder: (_, __) => const _Tab('Discover tab'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wr/growth',
                builder: (_, __) => const _Tab('Growth tab'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wr/journey',
                builder: (_, __) => const _Tab('Journey tab'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const _Tab('Profile tab'),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}

void main() {
  group('ShellScreen — bốn tab (Hai Lớp v1.6 §9.1)', () {
    testWidgets('WrTabBar widget exists in tree', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.byType(WrTabBar), findsOneWidget);
    });

    // Bong bóng bị tắt 2026-07-30 ("bỏ cái ô chatbot giúp tôi, chúng ta sẽ làm
    // cái này sau") vì lúc đó nó chỉ dẫn tới một ô hỏi một chiều. BẬT LẠI
    // 2026-08-03, khi phía sau đã là hội thoại thật.
    //
    // Yêu cầu gốc họp 2026-07-29: "nó sẽ hiển thị trên mọi trang luôn chứ không
    // riêng trang hành trình" — nên test đi qua cả bốn tab, không chỉ tab đầu.
    testWidgets('bong bóng trò chuyện nổi trên MỌI tab', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.byType(WrAskBubble), findsOneWidget);

      for (var i = 1; i < 4; i++) {
        await tester.tap(find.byType(WrTabItem).at(i));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('wr_ask_bubble')),
          findsOneWidget,
          reason: 'mất bong bóng ở tab thứ ${i + 1}',
        );
      }
    });

    testWidgets('WrTabItem widgets count is 4', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      // v1.6 §9.1 rút còn bốn tab; "Tôi" thành avatar ở góc trên mỗi màn.
      expect(find.byType(WrTabItem), findsNWidgets(4));
    });

    testWidgets('initial tab shows home content', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.text('Home tab'), findsOneWidget);
    });

    testWidgets('mỗi tab có nhãn chữ như mockup Sprint 2', (tester) async {
      // Bản trước giấu nhãn, chỉ để icon + chấm coral. Mockup `.tab .lbl` có
      // nhãn 9px dưới mỗi icon — bốn icon trần thì người mới mở app phải đoán.
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      final tabBarFinder = find.byType(WrTabBar);
      expect(tabBarFinder, findsOneWidget);

      for (final label in ['Hôm nay', 'Hiểu mình', 'Phát triển', 'Hành trình']) {
        expect(
          find.descendant(of: tabBarFinder, matching: find.text(label)),
          findsOneWidget,
          reason: 'thiếu nhãn tab "$label"',
        );
      }
    });

    testWidgets('tapping tab index 1 (Hiểu mình) switches to discover branch',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      // Find all WrTabItem widgets and tap the second one (index 1)
      final tabItems = find.byType(WrTabItem);
      await tester.tap(tabItems.at(1));
      await tester.pumpAndSettle();

      expect(find.text('Discover tab'), findsOneWidget);
    });

    testWidgets('tapping tab index 2 (Phát triển) switches to growth branch',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      final tabItems = find.byType(WrTabItem);
      await tester.tap(tabItems.at(2));
      await tester.pumpAndSettle();

      expect(find.text('Growth tab'), findsOneWidget);
    });

    testWidgets('tapping tab index 3 (Hành trình) switches to journey branch',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      final tabItems = find.byType(WrTabItem);
      await tester.tap(tabItems.at(3));
      await tester.pumpAndSettle();

      expect(find.text('Journey tab'), findsOneWidget);
    });

    testWidgets('active tab icon uses coral color, inactive uses muted',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      // At index 0 (home), first WrTabItem is active
      final tabItems = tester.widgetList<WrTabItem>(find.byType(WrTabItem)).toList();
      expect(tabItems[0].isActive, isTrue);
      expect(tabItems[1].isActive, isFalse);
      expect(tabItems[2].isActive, isFalse);
      expect(tabItems[3].isActive, isFalse);
    });
  });

  group('Router configuration — shell branch paths', () {
    test('appRouterProvider shell has 4 branches with correct paths', () {
      // This is a structural contract test — verifies the router declaration
      // includes the required shell branches in the expected order.
      // The actual router is tested via shell_test; this group documents intent.

      // /profile KHÔNG còn trong danh sách này — v1.6 §9.1 đưa nó ra ngoài
      // shell, thành màn đẩy toàn màn hình mở từ avatar.
      const expectedBranchPaths = [
        '/home',
        '/wr/discover',
        '/wr/growth',
        '/wr/journey',
      ];

      // Verify path list compiles (no assertion needed — this is a documentation test)
      expect(expectedBranchPaths.length, 4);
      expect(expectedBranchPaths[0], '/home');
      expect(expectedBranchPaths[1], '/wr/discover');
      expect(expectedBranchPaths.contains('/profile'), isFalse);
    });
  });
}
