// Tests cho WrHomeScreen sau khi restyle theo HTML mockup (Task 2A).
// TDD: các test này được viết TRƯỚC khi implement.
// Run: flutter test test/features/wr_home_screen_restyle_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ---------------------------------------------------------------------------
// Router helper
// ---------------------------------------------------------------------------

GoRouter _makeRouter({required Widget home}) => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => home),
        GoRoute(
          path: '/wr/situation',
          builder: (_, __) => const Scaffold(body: Text('SituationScreen')),
        ),
        GoRoute(
          path: '/wr/discover',
          builder: (_, __) => const Scaffold(body: Text('DiscoverScreen')),
        ),
      ],
    );

Widget _wrap(
  Widget home, {
  FakeWrRepository? wr,
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String? userId,
}) {
  final wrRepo = wr ?? FakeWrRepository();
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = _makeRouter(home: home);
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(wrRepo),
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
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

MobileProfile _profile({String name = 'Minh'}) => MobileProfile(
      userId: 'u1',
      displayName: name,
      reminderEnabled: true,
      language: 'vi',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 7, 22),
    );

WrInsight _insight({String content = 'Insight mẫu'}) => WrInsight(
      userId: 'u1',
      content: content,
      createdAt: DateTime(2026, 7, 20),
    );

PatternCount _pattern({
  String code = 'sit-pressure',
  int count = 3,
}) =>
    PatternCount(
      userId: 'u1',
      situationCode: code,
      occurrenceCount: count,
      lastSeenAt: DateTime(2026, 7, 20),
    );

WrSituation _situation({String code = 'sit-pressure', String text = 'Áp lực deadline'}) =>
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
  // ── 2A.1: top-area ─────────────────────────────────────────────────────────

  group('2A.1 top-area', () {
    testWidgets('shows greeting "Chào {displayName}"', (tester) async {
      final wr = FakeWrRepository()..seedProfile(_profile(name: 'Linh'));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      expect(find.textContaining('Chào Linh'), findsOneWidget);
    });

    testWidgets('shows date-title with weekday and date (Thứ X, dd/MM)', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      // Date title must contain a Vietnamese weekday and a dd/MM pattern
      final now = DateTime.now();
      final dayStr = now.day.toString().padLeft(2, '0');
      final monthStr = now.month.toString().padLeft(2, '0');
      expect(find.textContaining('$dayStr/$monthStr'), findsOneWidget);
    });

    testWidgets('does NOT show avatar/profile button in header', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      // The old design had a CircleAvatar/IconButton for profile in the header.
      // After restyle, profile is tab 5 — no inline profile button.
      // Check: no /profile navigation button in top-area.
      // We verify by checking that the person icon is absent (or the GestureDetector
      // that navigates to /profile in the header area).
      // Implementation uses a Column without a Row with avatar.
      // Simple check: no Icons.person in the widget tree from the header.
      expect(find.byIcon(Icons.person), findsNothing);
    });
  });

  // ── 2A.2: check-in grid ──────────────────────────────────────────────────

  group('2A.2 check-in grid', () {
    testWidgets('renders energy row with 3 buttons', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.text('Có năng lượng'), findsOneWidget);
      expect(find.text('Bình thường'), findsOneWidget);
      expect(find.text('Mệt mỏi'), findsOneWidget);
    });

    testWidgets('direction row hidden before energy selected', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      // Direction options should not be visible until energy is chosen
      expect(find.text('Tiến lên'), findsNothing);
      expect(find.text('Đứng yên'), findsNothing);
      expect(find.text('Thụt lùi'), findsNothing);
    });

    testWidgets('direction row revealed after energy selected', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await tester.tap(find.text('Có năng lượng'));
      await tester.pumpAndSettle();
      expect(find.text('Tiến lên'), findsOneWidget);
      expect(find.text('Đứng yên'), findsOneWidget);
      expect(find.text('Thụt lùi'), findsOneWidget);
    });

    testWidgets('auto-saves when both energy and direction selected (no manual Save button)', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      // Select energy
      await tester.tap(find.text('Có năng lượng'));
      await tester.pumpAndSettle();
      // Select direction
      await tester.tap(find.text('Tiến lên'));
      await tester.pumpAndSettle();
      // Should auto-save WITHOUT requiring manual button tap
      expect(wr.upsertCheckinCalls, isNotEmpty);
      expect(wr.upsertCheckinCalls, contains(Mood.happy));
    });

    testWidgets('shows saved badge after auto-save', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Bình thường'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đứng yên'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã lưu'), findsOneWidget);
    });

    testWidgets('no explicit Save button in the new layout', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      // There should be no "Lưu check-in" button
      expect(find.widgetWithText(ElevatedButton, 'Lưu check-in'), findsNothing);
    });

    testWidgets('energy=low shows share card (card-minimal style)', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Mệt mỏi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thụt lùi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsOneWidget);
    });

    testWidgets('pre-populates saved state when today checkin exists', (tester) async {
      final wr = FakeWrRepository();
      final now = DateTime.now();
      wr.seedTodayCheckin(Checkin(
        id: 'c1',
        userId: 'u1',
        mood: Mood.okay,
        energy: CheckinEnergy.ok,
        direction: CheckinDirection.steady,
        checkinDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      ));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      expect(find.textContaining('Đã lưu'), findsOneWidget);
    });
  });

  // ── 2A.3: divider ───────────────────────────────────────────────────────

  group('2A.3 divider', () {
    testWidgets('renders WrSectionDivider between sections', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      // At least one Divider widget should be present
      expect(find.byType(Divider), findsWidgets);
    });
  });

  // ── 2A.4: card hệ thống nhận ra ─────────────────────────────────────────

  group('2A.4 card hệ thống nhận ra', () {
    testWidgets('hidden when no pattern data', (tester) async {
      // No patterns seeded
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.textContaining('HỆ THỐNG NHẬN RA'), findsNothing);
    });

    testWidgets('hidden when top pattern count < 2', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(count: 1)]);
      final content = FakeWrContentRepository();
      content.seedSituations([_situation()]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel, content: content));
      expect(find.textContaining('HỆ THỐNG NHẬN RA'), findsNothing);
    });

    testWidgets('shown when top pattern count >= 2', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(count: 2)]);
      final content = FakeWrContentRepository();
      content.seedSituations([_situation()]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel, content: content));
      expect(find.textContaining('HỆ THỐNG NHẬN RA'), findsOneWidget);
    });

    testWidgets('shows pattern text and count when visible', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(count: 3)]);
      final content = FakeWrContentRepository();
      content.seedSituations([_situation(text: 'Áp lực deadline')]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel, content: content));
      // Should contain a mention of the situation or occurrence
      expect(find.textContaining('Áp lực deadline'), findsWidgets);
    });

    testWidgets('action link navigates to /wr/discover', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(count: 3)]);
      final content = FakeWrContentRepository();
      content.seedSituations([_situation()]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel, content: content));
      // Tap "Tìm hiểu thêm" link
      await tester.tap(find.textContaining('Tìm hiểu thêm'));
      await tester.pumpAndSettle();
      expect(find.text('DiscoverScreen'), findsOneWidget);
    });
  });

  // ── 2A.5: section gợi ý story ────────────────────────────────────────────

  group('2A.5 section gợi ý story', () {
    testWidgets('shows eyebrow GỢI Ý HÔM NAY by default (no low energy)', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.textContaining('GỢI Ý HÔM NAY'), findsOneWidget);
    });

    testWidgets('shows eyebrow GỢI Ý KHI MỆT MỎI when energy=low saved', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Mệt mỏi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thụt lùi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GỢI Ý KHI MỆT MỎI'), findsOneWidget);
    });

    testWidgets('shows CTA to read first story when no story data', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      // Story card has multiple widgets containing "câu chuyện"
      expect(find.textContaining('câu chuyện'), findsWidgets);
    });
  });

  // ── 2A.6: section insight ────────────────────────────────────────────────

  group('2A.6 section insight', () {
    testWidgets('hidden when no insight', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.textContaining('INSIGHT GẦN NHẤT'), findsNothing);
    });

    testWidgets('shown with insight content when data available', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedInsights([_insight(content: 'Tôi nhận ra mình thường mệt vì deadline.')]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel));
      expect(find.textContaining('INSIGHT GẦN NHẤT'), findsOneWidget);
      expect(find.textContaining('Tôi nhận ra mình thường mệt vì deadline.'), findsOneWidget);
    });

    testWidgets('shows save date when insight has createdAt', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedInsights([_insight(content: 'Test insight')]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel));
      // Should show "Lưu ngày dd/MM"
      expect(find.textContaining('Lưu ngày'), findsOneWidget);
    });
  });
}
