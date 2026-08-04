// Tests cho WrTabBackLink widget.
// Run: flutter test test/core/widgets/tab_back_link_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/widgets/tab_back_link.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

GoRouter _makeRouter({required String initialLocation}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/wr/discover',
          builder: (_, __) => Scaffold(
            body: Column(
              children: const [
                WrTabBackLink(currentTab: WrTab.discover),
                Text('DISCOVER_PAGE'),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/wr/journey',
          builder: (_, __) => const Scaffold(body: Text('JOURNEY_PAGE')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME_PAGE')),
        ),
        GoRoute(
          path: '/wr/growth',
          builder: (_, __) => const Scaffold(body: Text('GROWTH_PAGE')),
        ),
      ],
    );

Widget _wrapWithRouter(String initialLocation) =>
    MaterialApp.router(
      builder: wrTextScaleBuilder,routerConfig: _makeRouter(initialLocation: initialLocation));

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('WrTabBackLink', () {
    testWidgets(
        '1. ?from=journey → hiện "Quay lại"',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter('/wr/discover?from=journey'));
      await tester.pumpAndSettle();

      expect(find.text('Quay lại'), findsOneWidget);
    });

    testWidgets(
        '2. không có from → không hiện "Quay lại"',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter('/wr/discover'));
      await tester.pumpAndSettle();

      expect(find.text('Quay lại'), findsNothing);
    });

    testWidgets(
        '3. ?from=abc (key rác) → không hiện "Quay lại"',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter('/wr/discover?from=abc'));
      await tester.pumpAndSettle();

      expect(find.text('Quay lại'), findsNothing);
    });

    testWidgets(
        '4. ?from=discover (trùng tab hiện tại) → không hiện "Quay lại"',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter('/wr/discover?from=discover'));
      await tester.pumpAndSettle();

      expect(find.text('Quay lại'), findsNothing);
    });

    testWidgets(
        '5. tap "Quay lại" → điều hướng đến JOURNEY_PAGE',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter('/wr/discover?from=journey'));
      await tester.pumpAndSettle();

      expect(find.text('Quay lại'), findsOneWidget);
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();

      expect(find.text('JOURNEY_PAGE'), findsOneWidget);
    });

    testWidgets(
        '6. widget ngoài GoRouter → không crash, không hiện "Quay lại"',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: wrTextScaleBuilder,
          home: Scaffold(
            body: WrTabBackLink(currentTab: WrTab.discover),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quay lại'), findsNothing);
    });
  });
}
