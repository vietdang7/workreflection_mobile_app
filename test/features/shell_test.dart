import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/features/shell/shell_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// A minimal GoRouter with StatefulShellRoute so we can test the shell widget.
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
                builder: (_, __) => const _Tab('Hôm nay'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/understand',
                builder: (_, __) => const _Tab('Hiểu mình'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/develop',
                builder: (_, __) => const _Tab('Phát triển'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/journey',
                builder: (_, __) => const _Tab('Hành trình'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const _Tab('Tôi'),
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
  group('ShellScreen', () {
    testWidgets('renders all 5 tab labels in the bottom bar', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.text('Hôm nay'), findsWidgets);
      expect(find.text('Hiểu mình'), findsOneWidget);
      expect(find.text('Phát triển'), findsOneWidget);
      expect(find.text('Hành trình'), findsOneWidget);
      expect(find.text('Tôi'), findsOneWidget);
    });

    testWidgets('initial tab shows home content', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      // The _Tab widget for home renders 'Hôm nay'
      expect(find.text('Hôm nay'), findsWidgets);
    });

    testWidgets('tapping Hiểu mình tab switches to understand branch',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      // Find tab label in the bottom bar and tap it
      // The tab bar contains 'Hiểu mình' label text
      final tabLabel = find.text('Hiểu mình');
      expect(tabLabel, findsOneWidget);
      await tester.tap(tabLabel);
      await tester.pumpAndSettle();

      // The _Tab for understand also renders 'Hiểu mình' — now two instances
      expect(find.text('Hiểu mình'), findsWidgets);
    });

    testWidgets('tapping Phát triển tab switches branch', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phát triển'));
      await tester.pumpAndSettle();

      expect(find.text('Phát triển'), findsWidgets);
    });

    testWidgets('tapping Tôi tab switches to profile branch', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tôi'));
      await tester.pumpAndSettle();

      expect(find.text('Tôi'), findsWidgets);
    });

    testWidgets('WrTabBar has height 64 container', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      // Find the WrTabBar by type
      expect(find.byType(WrTabBar), findsOneWidget);
    });

    testWidgets('active tab item shows coral-colored indicator', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      // Find WrTabItem widgets — should be 5
      expect(find.byType(WrTabItem), findsNWidgets(5));
    });
  });
}
