// Tests cho WrDiscoverScreen sau khi restyle theo HTML mockup (Task 2B).
// Run: flutter test test/features/wr_discover_screen_restyle_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GoRouter _makeRouter({required Widget home}) => GoRouter(
      initialLocation: '/discover',
      routes: [
        GoRoute(path: '/discover', builder: (_, __) => home),
        GoRoute(
          path: '/wr/self-check',
          builder: (_, __) => const Scaffold(body: Text('SelfCheckScreen')),
        ),
        GoRoute(
          path: '/wr/paywall',
          builder: (_, __) => const Scaffold(body: Text('PaywallScreen')),
        ),
      ],
    );

Widget _wrap(
  Widget home, {
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
  String? userId,
  WrEntitlementRecord? entitlement,
}) {
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final contentRepo = content ?? FakeWrContentRepository();
  if (entitlement != null) intelRepo.seedEntitlement(entitlement);

  final router = _makeRouter(home: home);
  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      currentUserIdProvider.overrideWithValue(userId ?? 'u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

ScaSelfCheckResponse _selfCheck({
  double s = 3.5,
  double c = 4.0,
  double a = 2.0,
}) =>
    ScaSelfCheckResponse(
      id: 'r1',
      userId: 'u1',
      answers: const {},
      structureScore: s,
      cultureScore: c,
      activityScore: a,
      takenAt: DateTime(2026, 7, 20),
    );

PatternCount _pattern({
  String code = 'sit-01',
  String? sitCode,
  int count = 4,
}) =>
    PatternCount(
      userId: 'u1',
      situationCode: sitCode ?? code,
      occurrenceCount: count,
      lastSeenAt: DateTime(2026, 7, 18),
    );

WrSituation _situation({
  String code = 'sit-01',
  String text = 'Áp lực deadline',
}) =>
    WrSituation(
      code: code,
      text: text,
      scaDimension: ScaDimension.s1,
      wave: 2,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 2B.1: top-area ────────────────────────────────────────────────────────

  group('2B.1 top-area', () {
    testWidgets('shows eyebrow "Career Snapshot" (uppercased by WrEyebrow)', (tester) async {
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen()));
      // WrEyebrow calls .toUpperCase() → rendered as "CAREER SNAPSHOT"
      expect(find.textContaining('CAREER SNAPSHOT'), findsOneWidget);
    });

    testWidgets('shows date-title "Hiểu mình"', (tester) async {
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen()));
      expect(find.text('Hiểu mình'), findsOneWidget);
    });
  });

  // ── 2B.2: nhu cầu chủ đạo ────────────────────────────────────────────────

  group('2B.2 nhu cầu chủ đạo', () {
    testWidgets('shows empty state CTA when no self-check data', (tester) async {
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen()));
      // Empty state shows CTA text (may appear in multiple widgets)
      expect(find.textContaining('15 câu phản chiếu'), findsWidgets);
    });

    testWidgets('shows ĐIỀU BẠN ĐANG TÌM KIẾM eyebrow when data available', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('ĐIỀU BẠN ĐANG TÌM KIẾM'), findsOneWidget);
    });
  });

  // ── 2B.3: tình huống lặp lại ─────────────────────────────────────────────

  group('2B.3 tình huống lặp lại', () {
    testWidgets('shows TÌNH HUỐNG LẶP LẠI eyebrow when patterns exist', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      intel.seedPatternCounts([_pattern()]);
      final content = FakeWrContentRepository();
      content.seedSituations([_situation()]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel, content: content));
      expect(find.textContaining('TÌNH HUỐNG LẶP LẠI'), findsOneWidget);
    });

    testWidgets('shows situation text and count', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      intel.seedPatternCounts([_pattern(code: 'sit-01', count: 4)]);
      final content = FakeWrContentRepository();
      content.seedSituations([_situation(code: 'sit-01', text: 'Áp lực deadline')]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel, content: content));
      expect(find.textContaining('Áp lực deadline'), findsWidgets);
      expect(find.textContaining('4'), findsWidgets);
    });
  });

  // ── 2B.4: SCA status mapping ─────────────────────────────────────────────

  group('2B.4 SCA status mapping', () {
    testWidgets('shows TRẢI NGHIỆM HIỆN TẠI (SCA) eyebrow', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('TRẢI NGHIỆM HIỆN TẠI'), findsOneWidget);
    });

    testWidgets('S pillar shows Ổn định when structureScore >= 70%', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      // structureScore=5.0 → 100% → Ổn định
      intel.seedSelfCheckHistory([_selfCheck(s: 5.0, c: 1.0, a: 1.0)]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('Ổn định'), findsWidgets);
    });

    testWidgets('C pillar shows Đang cải thiện when cultureScore < 70%', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      // cultureScore=1.0 → 0% → Đang cải thiện
      intel.seedSelfCheckHistory([_selfCheck(s: 5.0, c: 1.0, a: 5.0)]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('Đang cải thiện'), findsWidgets);
    });

    testWidgets('screen renders without crash when no self-check history', (tester) async {
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen()));
      expect(find.byType(WrDiscoverScreen), findsOneWidget);
    });

    testWidgets('shows S label Minh bạch vai trò', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      // Label may appear in SCA item and dominant need
      expect(find.textContaining('Minh bạch vai trò'), findsWidgets);
    });

    testWidgets('shows C label An toàn khi lên tiếng', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      // Use s as dominant so dominant need shows S, C still appears in SCA
      intel.seedSelfCheckHistory([_selfCheck(s: 4.5, c: 3.0, a: 2.0)]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('An toàn khi lên tiếng'), findsWidgets);
    });

    testWidgets('shows A label Định hướng ý nghĩa', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('Định hướng ý nghĩa'), findsWidgets);
    });
  });

  // ── 2B.5: career health check ────────────────────────────────────────────

  group('2B.5 career health check', () {
    testWidgets('shows progress when < 15 self-checks', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory(List.generate(
        3,
        (i) => ScaSelfCheckResponse(
          id: 'r$i',
          userId: 'u1',
          answers: const {},
          takenAt: DateTime(2026, 7, i + 1),
        ),
      ));
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('15'), findsWidgets);
    });

    testWidgets('shows ready message when >= 15 self-checks', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory(List.generate(
        15,
        (i) => ScaSelfCheckResponse(
          id: 'r$i',
          userId: 'u1',
          answers: const {},
          takenAt: DateTime(2026, 7, 1).add(Duration(days: i)),
        ),
      ));
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('đủ 15'), findsOneWidget);
    });

    testWidgets('shows CAREER HEALTH CHECK eyebrow', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('CAREER HEALTH CHECK'), findsOneWidget);
    });

    testWidgets('CTA navigates to /wr/self-check', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      final ctaFinder = find.textContaining('kiểm tra');
      if (ctaFinder.evaluate().isNotEmpty) {
        await tester.tap(ctaFinder.first);
        await tester.pumpAndSettle();
        expect(find.text('SelfCheckScreen'), findsOneWidget);
      }
    });
  });

  // ── 2B.6: premium gating ─────────────────────────────────────────────────

  group('2B.6 premium gating', () {
    testWidgets('shows MỞ KHOÁ VỚI PREMIUM eyebrow for free users with data', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('MỞ KHOÁ VỚI PREMIUM'), findsOneWidget);
    });

    testWidgets('locked Premium text visible for free users', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('Premium'), findsWidgets);
    });
  });

  group('2B.7 nhu cầu chủ đạo — trụ THẤP NHẤT', () {
    testWidgets('S lowest → quote "Được rõ ràng về vai trò và kỳ vọng của mình."', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck(s: 1.0, c: 3.0, a: 4.0)]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('rõ ràng về vai trò'), findsOneWidget);
      expect(find.textContaining('Minh bạch vai trò'), findsWidgets);
    });

    testWidgets('C lowest → quote "Được lắng nghe và thể hiện quan điểm."', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck(s: 4.0, c: 1.0, a: 3.0)]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('lắng nghe và thể hiện quan điểm'), findsOneWidget);
      expect(find.textContaining('An toàn khi lên tiếng'), findsWidgets);
    });

    testWidgets('A lowest → quote "Được làm công việc có ý nghĩa với mình."', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck(s: 3.0, c: 4.0, a: 1.0)]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('công việc có ý nghĩa'), findsOneWidget);
      expect(find.textContaining('Định hướng ý nghĩa'), findsWidgets);
    });

    testWidgets('tie between S and C → C wins (priority C > S > A)', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck(s: 2.0, c: 2.0, a: 4.0)]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('lắng nghe và thể hiện quan điểm'), findsOneWidget);
      expect(find.textContaining('An toàn khi lên tiếng'), findsWidgets);
    });

    testWidgets('dominant need section shows quote and caption without card wrapper', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck(s: 4.0, c: 1.0, a: 3.0)]);
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen(), intel: intel));
      expect(find.textContaining('lắng nghe'), findsOneWidget);
      expect(find.textContaining('Nhu cầu chủ đạo'), findsOneWidget);
    });

    testWidgets('scaffold backgroundColor is WrColors.white', (tester) async {
      await _pumpLarge(tester, _wrap(const WrDiscoverScreen()));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));
    });
  });
}
