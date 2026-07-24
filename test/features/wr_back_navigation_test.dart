// Tests phủ Task 2: WrTabBackLink gắn vào 4 tab WR.
// Mỗi tab × {?from=<tab khác> → thấy 'Quay lại'; không query → không thấy}
// Run: flutter test test/features/wr_back_navigation_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Widget _wrapDiscover(String initialLocation) {
  final contentRepo = FakeWrContentRepository();
  final intelRepo = FakeWrIntelligenceRepository();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/wr/discover',
        builder: (_, __) => const WrDiscoverScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME_STUB'))),
      GoRoute(path: '/wr/journey', builder: (_, __) => const Scaffold(body: Text('JOURNEY_STUB'))),
      GoRoute(path: '/wr/growth', builder: (_, __) => const Scaffold(body: Text('GROWTH_STUB'))),
      GoRoute(path: '/wr/self-check', builder: (_, __) => const Scaffold(body: Text('SELFCHECK'))),
      GoRoute(path: '/wr/paywall', builder: (_, __) => const Scaffold(body: Text('PAYWALL'))),
    ],
  );
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _wrapGrowth(String initialLocation) {
  final contentRepo = FakeWrContentRepository();
  final intelRepo = FakeWrIntelligenceRepository();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/wr/growth',
        builder: (_, __) => const WrGrowthScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME_STUB'))),
      GoRoute(path: '/wr/discover', builder: (_, __) => const Scaffold(body: Text('DISCOVER_STUB'))),
      GoRoute(path: '/wr/journey', builder: (_, __) => const Scaffold(body: Text('JOURNEY_STUB'))),
      GoRoute(path: '/wr/self-check', builder: (_, __) => const Scaffold(body: Text('SELFCHECK'))),
      GoRoute(path: '/wr/paywall', builder: (_, __) => const Scaffold(body: Text('PAYWALL'))),
      GoRoute(path: '/wr/story', builder: (_, __) => const Scaffold(body: Text('STORY'))),
    ],
  );
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _wrapJourney(String initialLocation) {
  final contentRepo = FakeWrContentRepository();
  final intelRepo = FakeWrIntelligenceRepository();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/wr/journey',
        builder: (_, __) => const WrJourneyScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME_STUB'))),
      GoRoute(path: '/wr/discover', builder: (_, __) => const Scaffold(body: Text('DISCOVER_STUB'))),
      GoRoute(path: '/wr/growth', builder: (_, __) => const Scaffold(body: Text('GROWTH_STUB'))),
      GoRoute(path: '/wr/self-check', builder: (_, __) => const Scaffold(body: Text('SELFCHECK'))),
      GoRoute(path: '/wr/paywall', builder: (_, __) => const Scaffold(body: Text('PAYWALL'))),
      GoRoute(path: '/wr/story', builder: (_, __) => const Scaffold(body: Text('STORY'))),
    ],
  );
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _wrapHome(String initialLocation) {
  final wrRepo = FakeWrRepository();
  final contentRepo = FakeWrContentRepository();
  final intelRepo = FakeWrIntelligenceRepository();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => const WrHomeScreen(),
      ),
      GoRoute(path: '/wr/discover', builder: (_, __) => const Scaffold(body: Text('DISCOVER_STUB'))),
      GoRoute(path: '/wr/growth', builder: (_, __) => const Scaffold(body: Text('GROWTH_STUB'))),
      GoRoute(path: '/wr/journey', builder: (_, __) => const Scaffold(body: Text('JOURNEY_STUB'))),
      GoRoute(path: '/wr/situation', builder: (_, __) => const Scaffold(body: Text('SITUATION'))),
      GoRoute(path: '/wr/story', builder: (_, __) => const Scaffold(body: Text('STORY'))),
      GoRoute(path: '/wr/paywall', builder: (_, __) => const Scaffold(body: Text('PAYWALL'))),
      GoRoute(path: '/wr/self-check', builder: (_, __) => const Scaffold(body: Text('SELFCHECK'))),
    ],
  );
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(wrRepo),
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Discover tab ────────────────────────────────────────────────────────────
  group('Discover tab — WrTabBackLink', () {
    testWidgets(
      '?from=journey → thấy "Quay lại"',
      (tester) async {
        await _pumpLarge(tester, _wrapDiscover('/wr/discover?from=journey'));
        expect(find.text('Quay lại'), findsOneWidget);
      },
    );

    testWidgets(
      'không ?from → không thấy "Quay lại"',
      (tester) async {
        await _pumpLarge(tester, _wrapDiscover('/wr/discover'));
        expect(find.text('Quay lại'), findsNothing);
      },
    );
  });

  // ── Growth tab ──────────────────────────────────────────────────────────────
  group('Growth tab — WrTabBackLink', () {
    testWidgets(
      '?from=discover → thấy "Quay lại"',
      (tester) async {
        await _pumpLarge(tester, _wrapGrowth('/wr/growth?from=discover'));
        expect(find.text('Quay lại'), findsOneWidget);
      },
    );

    testWidgets(
      'không ?from → không thấy "Quay lại"',
      (tester) async {
        await _pumpLarge(tester, _wrapGrowth('/wr/growth'));
        expect(find.text('Quay lại'), findsNothing);
      },
    );
  });

  // ── Journey tab ─────────────────────────────────────────────────────────────
  group('Journey tab — WrTabBackLink', () {
    testWidgets(
      '?from=discover → thấy "Quay lại"',
      (tester) async {
        await _pumpLarge(tester, _wrapJourney('/wr/journey?from=discover'));
        expect(find.text('Quay lại'), findsOneWidget);
      },
    );

    testWidgets(
      'không ?from → không thấy "Quay lại"',
      (tester) async {
        await _pumpLarge(tester, _wrapJourney('/wr/journey'));
        expect(find.text('Quay lại'), findsNothing);
      },
    );
  });

  // ── Home tab ────────────────────────────────────────────────────────────────
  group('Home tab — WrTabBackLink', () {
    testWidgets(
      '?from=journey → thấy "Quay lại"',
      (tester) async {
        await _pumpLarge(tester, _wrapHome('/home?from=journey'));
        expect(find.text('Quay lại'), findsOneWidget);
      },
    );

    testWidgets(
      'không ?from → không thấy "Quay lại"',
      (tester) async {
        await _pumpLarge(tester, _wrapHome('/home'));
        expect(find.text('Quay lại'), findsNothing);
      },
    );
  });
}
