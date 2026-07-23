// Tests cho WrHomeScreen sau khi restyle theo HTML mockup (Task 2A).
// TDD: cập nhật cho UI 2×2 mood grid (thay 2-bước energy+direction).
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
import 'package:workreflection_mobile/core/widgets/section_divider.dart';
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
          path: '/wr/story',
          builder: (_, __) => const Scaffold(body: Text('StoryScreen')),
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
      final now = DateTime.now();
      final dayStr = now.day.toString().padLeft(2, '0');
      final monthStr = now.month.toString().padLeft(2, '0');
      expect(find.textContaining('$dayStr/$monthStr'), findsOneWidget);
    });

    testWidgets('does NOT show avatar/profile button in header', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.byIcon(Icons.person), findsNothing);
    });
  });

  // ── 2A.2: check-in 2×2 grid ─────────────────────────────────────────────

  group('2A.2 check-in 2×2 mood grid', () {
    testWidgets('(a) renders 4 mood buttons with correct labels', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.textContaining('căng thẳng'), findsOneWidget);
      expect(find.textContaining('mệt mỏi'), findsOneWidget);
      expect(find.textContaining('khá ổn'), findsOneWidget);
      expect(find.textContaining('đang vui'), findsOneWidget);
    });

    testWidgets('NO old energy buttons (Có năng lượng / Bình thường / Mệt mỏi)', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.text('Có năng lượng'), findsNothing);
      expect(find.text('Bình thường'), findsNothing);
      // "Mệt mỏi" alone (without surrounding text) should not appear
      expect(find.text('Mệt mỏi'), findsNothing);
    });

    testWidgets('NO old direction buttons (Tiến lên / Đứng yên / Thụt lùi)', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.text('Tiến lên'), findsNothing);
      expect(find.text('Đứng yên'), findsNothing);
      expect(find.text('Thụt lùi'), findsNothing);
    });

    testWidgets('(b) tap "mệt mỏi" → upsertCheckin energy=low direction=null, button coral, Q2 shown, eyebrow GỢI Ý KHI MỆT MỎI', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();

      // upsertCheckin called with energy=low, direction=null
      expect(wr.upsertCheckinCalls, isNotEmpty);
      final call = wr.upsertCheckinCalls.first;
      expect(call.energy, CheckinEnergy.low);
      expect(call.direction, isNull);

      // Q2 title shown (inline reveal, not old share card)
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsOneWidget);
      // Old share card action link gone
      expect(find.text('Chia sẻ thêm'), findsNothing);

      // Eyebrow changes
      expect(find.textContaining('GỢI Ý KHI MỆT MỎI'), findsOneWidget);
    });

    testWidgets('(b) tap "căng thẳng" → energy=low, Q2 shown', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();

      expect(wr.upsertCheckinCalls.first.energy, CheckinEnergy.low);
      expect(wr.upsertCheckinCalls.first.direction, isNull);
      expect(find.textContaining('Điều gì đang khiến bạn căng thẳng?'), findsOneWidget);
      expect(find.text('Chia sẻ thêm'), findsNothing);
    });

    testWidgets('(c) tap "khá ổn" → energy=ok, NO share card, Q2 shown, eyebrow GỢI Ý HÔM NAY', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();

      expect(wr.upsertCheckinCalls.first.energy, CheckinEnergy.ok);
      expect(wr.upsertCheckinCalls.first.direction, isNull);
      expect(find.text('Chia sẻ thêm'), findsNothing);
      expect(find.textContaining('GỢI Ý HÔM NAY'), findsOneWidget);
    });

    testWidgets('(c) tap "đang vui" → energy=good, NO share card', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();

      expect(wr.upsertCheckinCalls.first.energy, CheckinEnergy.good);
      expect(wr.upsertCheckinCalls.first.direction, isNull);
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsNothing);
    });

    testWidgets('single-select: re-tap another button updates selection', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      // First tap mệt mỏi
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsOneWidget);

      // Then tap khá ổn
      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();
      // Q2 switches to "khá ổn" question
      expect(find.textContaining('Có điều gì bạn muốn nhìn lại hôm nay không?'), findsOneWidget);
      expect(find.text('Chia sẻ thêm'), findsNothing);
      // Second upsert called
      expect(wr.upsertCheckinCalls.length, 2);
    });

    testWidgets('(d) save error → SnackBar + revert selection', (tester) async {
      final wr = FakeWrRepository();
      wr.setUpsertError(Exception('db error'));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();

      // SnackBar shown
      expect(find.textContaining('Không lưu được'), findsWidgets);
      // Share card NOT shown (selection reverted)
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsNothing);
    });

    testWidgets('(e) prepopulate from todayCheckinProvider: energy=ok → "khá ổn" pre-selected', (tester) async {
      final wr = FakeWrRepository();
      final now = DateTime.now();
      wr.seedTodayCheckin(Checkin(
        id: 'c1',
        userId: 'u1',
        mood: Mood.okay,
        energy: CheckinEnergy.ok,
        direction: null,
        checkinDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      ));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      // No share card (ok energy is not low)
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsNothing);
      // All 4 buttons still rendered
      expect(find.textContaining('khá ổn'), findsOneWidget);
    });

    testWidgets('(e) prepopulate from todayCheckinProvider: energy=low → "mệt mỏi" pre-selected, Q2 shown', (tester) async {
      final wr = FakeWrRepository();
      final now = DateTime.now();
      wr.seedTodayCheckin(Checkin(
        id: 'c2',
        userId: 'u1',
        mood: Mood.tired,
        energy: CheckinEnergy.low,
        direction: null,
        checkinDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      ));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      // Q2 shown due to low energy prepopulate (tired → "Bạn mệt vì điều gì?")
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsOneWidget);
      expect(find.text('Chia sẻ thêm'), findsNothing);
    });

    testWidgets('NO CircularProgressIndicator (spinner removed)', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('no explicit Lưu check-in button', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.widgetWithText(ElevatedButton, 'Lưu check-in'), findsNothing);
    });
  });

  // ── 2A.3: divider — exactly 1 WrSectionDivider ──────────────────────────

  group('2A.3 divider', () {
    testWidgets('(f) exactly 1 WrSectionDivider on screen', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.byType(WrSectionDivider), findsOneWidget);
    });

    testWidgets('(f) still exactly 1 WrSectionDivider when pattern card shown', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(count: 3)]);
      final content = FakeWrContentRepository();
      content.seedSituations([_situation()]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel, content: content));
      expect(find.byType(WrSectionDivider), findsOneWidget);
    });

    testWidgets('(f) still exactly 1 WrSectionDivider when insight shown', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedInsights([_insight()]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel));
      expect(find.byType(WrSectionDivider), findsOneWidget);
    });
  });

  // ── 2A.4: card hệ thống nhận ra ─────────────────────────────────────────

  group('2A.4 card hệ thống nhận ra', () {
    testWidgets('hidden when no pattern data', (tester) async {
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
      expect(find.textContaining('Áp lực deadline'), findsWidgets);
    });

    testWidgets('action link navigates to /wr/discover', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(count: 3)]);
      final content = FakeWrContentRepository();
      content.seedSituations([_situation()]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel, content: content));
      await tester.tap(find.textContaining('Tìm hiểu thêm'));
      await tester.pumpAndSettle();
      expect(find.text('DiscoverScreen'), findsOneWidget);
    });
  });

  // ── 2A.5: section gợi ý story ────────────────────────────────────────────

  group('2A.5 section gợi ý story', () {
    testWidgets('shows eyebrow GỢI Ý HÔM NAY by default', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.textContaining('GỢI Ý HÔM NAY'), findsOneWidget);
    });

    testWidgets('shows eyebrow GỢI Ý KHI MỆT MỎI when low energy selected (no chip saved yet)', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GỢI Ý KHI MỆT MỎI'), findsOneWidget);
    });

    testWidgets('story card has icon + CTA link', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.textContaining('Đọc câu chuyện đầu tiên'), findsOneWidget);
    });

    testWidgets('shows story text mentioning câu chuyện', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
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
      expect(find.textContaining('Lưu ngày'), findsOneWidget);
    });
  });

  // ── 2A.7: scaffold background ────────────────────────────────────────────

  group('2A.7 scaffold', () {
    testWidgets('backgroundColor is WrColors.white (#FFFFFF)', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));
    });
  });
}
