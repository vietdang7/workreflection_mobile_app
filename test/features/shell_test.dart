import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/features/shell/shell_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// A minimal GoRouter with StatefulShellRoute so we can test the shell widget.
// Updated for WR pivot: 5 new tabs (Home/Trải nghiệm/Bức tranh/Thực hành/Hành trình).
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
                path: '/wr/story',
                builder: (_, __) => const _Tab('Story tab'),
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
  group('ShellScreen — WR pivot tabs', () {
    testWidgets('renders all 5 new tab labels in the bottom bar', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Trải nghiệm'), findsOneWidget);
      expect(find.text('Bức tranh'), findsOneWidget);
      expect(find.text('Thực hành'), findsOneWidget);
      expect(find.text('Hành trình'), findsOneWidget);
    });

    testWidgets('initial tab shows home content', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.text('Home tab'), findsOneWidget);
    });

    testWidgets('tapping Trải nghiệm tab switches to story branch', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trải nghiệm'));
      await tester.pumpAndSettle();

      expect(find.text('Story tab'), findsOneWidget);
    });

    testWidgets('tapping Bức tranh tab switches to discover branch', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bức tranh'));
      await tester.pumpAndSettle();

      expect(find.text('Discover tab'), findsOneWidget);
    });

    testWidgets('tapping Thực hành tab switches to growth branch', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thực hành'));
      await tester.pumpAndSettle();

      expect(find.text('Growth tab'), findsOneWidget);
    });

    testWidgets('tapping Hành trình tab switches to journey branch', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hành trình'));
      await tester.pumpAndSettle();

      expect(find.text('Journey tab'), findsOneWidget);
    });

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
  });
}
