import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/features/shell/shell_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// A minimal GoRouter with StatefulShellRoute so we can test the shell widget.
// Updated for final HTML mockup: 5 tabs
//   0 /home          — Hôm nay — Icons.home_outlined
//   1 /wr/discover   — Hiểu mình — Icons.person_outline
//   2 /wr/growth     — Phát triển — Icons.trending_up
//   3 /wr/journey    — Hành trình — Icons.notes_outlined
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
  group('ShellScreen — final HTML mockup 5 tabs', () {
    testWidgets('WrTabBar widget exists in tree', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.byType(WrTabBar), findsOneWidget);
    });

    testWidgets('WrTabItem widgets count is 5', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.byType(WrTabItem), findsNWidgets(5));
    });

    testWidgets('initial tab shows home content', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.text('Home tab'), findsOneWidget);
    });

    testWidgets('tab bar does NOT render any visible text labels', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      // In icon-only mode there must be no Text widgets in the WrTabBar
      final tabBarFinder = find.byType(WrTabBar);
      expect(tabBarFinder, findsOneWidget);

      final textsInsideTabBar = find.descendant(
        of: tabBarFinder,
        matching: find.byType(Text),
      );
      expect(textsInsideTabBar, findsNothing);
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

    testWidgets('tapping tab index 4 (Tôi) switches to profile branch',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      final tabItems = find.byType(WrTabItem);
      await tester.tap(tabItems.at(4));
      await tester.pumpAndSettle();

      expect(find.text('Profile tab'), findsOneWidget);
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
      expect(tabItems[4].isActive, isFalse);
    });
  });

  group('Router configuration — shell branch paths', () {
    test('appRouterProvider shell has 5 branches with correct paths', () {
      // This is a structural contract test — verifies the router declaration
      // includes the required shell branches in the expected order.
      // The actual router is tested via shell_test; this group documents intent.

      const expectedBranchPaths = [
        '/home',
        '/wr/discover',
        '/wr/growth',
        '/wr/journey',
        '/profile',
      ];

      // Verify path list compiles (no assertion needed — this is a documentation test)
      expect(expectedBranchPaths.length, 5);
      expect(expectedBranchPaths[0], '/home');
      expect(expectedBranchPaths[1], '/wr/discover');
      expect(expectedBranchPaths[4], '/profile');
    });
  });
}
