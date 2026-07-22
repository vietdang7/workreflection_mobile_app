// Tests cho các màn WR: home, story, discover, growth, journey, paywall, self-check.
// Sprint 1: Discover/Growth/Journey updated to ConsumerWidget with real providers.
// Run: flutter test test/features/wr_screens_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_paywall_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_story_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _wrap(
  Widget child, {
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
  String? userId,
  WrEntitlementRecord? entitlement,
}) {
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final contentRepo = content ?? FakeWrContentRepository();
  if (entitlement != null) intelRepo.seedEntitlement(entitlement);

  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => child),
      GoRoute(
        path: '/wr/self-check',
        builder: (_, __) => const Scaffold(body: Text('SelfCheck')),
      ),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const Scaffold(body: Text('Paywall')),
      ),
      GoRoute(
        path: '/wr/growth',
        builder: (_, __) => const Scaffold(body: Text('Growth')),
      ),
      GoRoute(
        path: '/wr/journey',
        builder: (_, __) => const Scaffold(body: Text('Journey')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('Profile')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      currentUserIdProvider.overrideWithValue(userId ?? 'u1'),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
    ),
  );
}

ScaSelfCheckResponse _selfCheckResponse({
  double s = 3.5,
  double c = 4.0,
  double a = 2.8,
}) =>
    ScaSelfCheckResponse(
      id: 'r1',
      userId: 'u1',
      answers: const {},
      structureScore: s,
      cultureScore: c,
      activityScore: a,
      takenAt: DateTime(2026, 7, 22),
    );

PracticeTheme _theme({
  String id = 'pt-voice',
  String title = 'Dám lên tiếng',
}) =>
    PracticeTheme(themeId: id, title: title);

PracticeStep _step({
  String id = 'pt-voice-1',
  String themeId = 'pt-voice',
  int order = 1,
  String title = 'Nhận diện',
  bool isPremium = false,
}) =>
    PracticeStep(
      stepId: id,
      themeId: themeId,
      stepOrder: order,
      title: title,
      isPremium: isPremium,
    );

PracticeEnrollment _enrollment({
  String userId = 'u1',
  String themeId = 'pt-voice',
  List<String> completed = const [],
}) =>
    PracticeEnrollment(
      userId: userId,
      themeId: themeId,
      completedSteps: completed,
    );

CareerMemoryEvent _event({
  String id = 'e1',
  String userId = 'u1',
  String? behavior,
  String? reflectionText,
  DateTime? createdAt,
}) =>
    CareerMemoryEvent(
      id: id,
      userId: userId,
      behavior: behavior,
      reflectionText: reflectionText,
      createdAt: createdAt ?? DateTime(2026, 7, 22),
    );

WrSituation _situation({
  String code = 'S1-01',
  String text = 'Vai trò chưa rõ',
}) =>
    WrSituation(
      code: code,
      text: text,
      scaDimension: ScaDimension.s1,
      wave: 1,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {

// ─────────────────────────────────────────────────────────────────────────────
// WrHomeScreen
// ─────────────────────────────────────────────────────────────────────────────

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

  testWidgets('avatar button exists', (tester) async {
    await tester.pumpWidget(_wrap(const WrHomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('tapping energy card selects it (no snackbar in new UI)', (tester) async {
    await tester.pumpWidget(_wrap(const WrHomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Có năng lượng'));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Có năng lượng'), findsOneWidget);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// WrStoryScreen
// ─────────────────────────────────────────────────────────────────────────────

group('WrStoryScreen', () {
  testWidgets('renders story empty-state title', (tester) async {
    await tester.pumpWidget(_wrap(const WrStoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Story của tôi'), findsOneWidget);
  });

  testWidgets('renders Bắt đầu đọc CTA button', (tester) async {
    await tester.pumpWidget(_wrap(const WrStoryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Bắt đầu đọc'), findsOneWidget);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// WrDiscoverScreen — Sprint 1
// ─────────────────────────────────────────────────────────────────────────────

group('WrDiscoverScreen — empty state', () {
  testWidgets('renders empty-state title when no history', (tester) async {
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

  testWidgets('CTA is Làm 15 câu phản chiếu when no history', (tester) async {
    await tester.pumpWidget(_wrap(const WrDiscoverScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Làm 15 câu phản chiếu'), findsOneWidget);
  });
});

group('WrDiscoverScreen — has data (free user)', () {
  testWidgets('shows 3 score bars with pillar names (no S/C/A codes)', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedSelfCheckHistory([_selfCheckResponse()]);

    await tester.pumpWidget(_wrap(const WrDiscoverScreen(), intel: intel));
    await tester.pumpAndSettle();

    // Must show friendly names — NOT technical codes
    expect(find.text('Sự rõ ràng'), findsOneWidget);
    expect(find.text('Mối quan hệ'), findsOneWidget);
    expect(find.text('Cách làm việc'), findsOneWidget);

    // Must NOT show technical codes
    expect(find.text('S'), findsNothing);
    expect(find.text('Structure'), findsNothing);
    expect(find.text('Culture'), findsNothing);
    expect(find.text('Activity'), findsNothing);
  });

  testWidgets('shows Làm lại button when has data', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedSelfCheckHistory([_selfCheckResponse()]);

    await tester.pumpWidget(_wrap(const WrDiscoverScreen(), intel: intel));
    await tester.pumpAndSettle();

    expect(find.text('Làm lại'), findsOneWidget);
  });

  testWidgets('shows 2 locked premium cards for free user', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedSelfCheckHistory([_selfCheckResponse()]);

    await tester.pumpWidget(_wrap(const WrDiscoverScreen(), intel: intel));
    await tester.pumpAndSettle();

    expect(find.text('Diễn giải sâu & xu hướng theo thời gian'), findsOneWidget);
    expect(find.text('Báo cáo chuyên sâu 49 câu'), findsOneWidget);
    expect(find.textContaining('Premium'), findsWidgets);
  });

  testWidgets('shows history list for premium user (no locked cards)', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedSelfCheckHistory([
      _selfCheckResponse(s: 4.0, c: 3.5, a: 4.2),
      _selfCheckResponse(s: 3.0, c: 3.0, a: 3.0),
    ]);
    intel.seedEntitlement(
      WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
    );

    await tester.pumpWidget(_wrap(
      const WrDiscoverScreen(),
      intel: intel,
    ));
    await tester.pumpAndSettle();

    // History section present
    expect(find.text('LỊCH SỬ ĐO'), findsOneWidget);
    // No locked feature cards
    expect(find.text('Báo cáo chuyên sâu 49 câu'), findsNothing);
    expect(find.text('Diễn giải sâu & xu hướng theo thời gian'), findsNothing);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// WrGrowthScreen — Sprint 1
// ─────────────────────────────────────────────────────────────────────────────

group('WrGrowthScreen — empty state', () {
  testWidgets('renders empty-state title when no themes', (tester) async {
    await tester.pumpWidget(_wrap(const WrGrowthScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có chủ đề'), findsOneWidget);
  });

  testWidgets('renders description text', (tester) async {
    await tester.pumpWidget(_wrap(const WrGrowthScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đọc story và nhận Insight'), findsOneWidget);
  });
});

group('WrGrowthScreen — with themes (free user)', () {
  testWidgets('shows theme title and steps', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([_theme()]);
    intel.seedPracticeSteps('pt-voice', [
      _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
      _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
      _step(id: 'pt-voice-3', order: 3, title: 'Duy trì', isPremium: true),
    ]);

    await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
    await tester.pumpAndSettle();

    expect(find.text('Dám lên tiếng'), findsOneWidget);
    expect(find.text('Nhận diện'), findsOneWidget);
    expect(find.text('Thử nghiệm'), findsOneWidget);
    expect(find.text('Duy trì'), findsOneWidget);
  });

  testWidgets('premium step shows ⭐ Premium badge for free user', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([_theme()]);
    intel.seedPracticeSteps('pt-voice', [
      _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
      _step(id: 'pt-voice-3', order: 2, title: 'Duy trì', isPremium: true),
    ]);
    intel.seedEnrollments([_enrollment()]);

    await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
    await tester.pumpAndSettle();

    expect(find.textContaining('Premium'), findsWidgets);
  });

  testWidgets('premium step is accessible for premium user', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([_theme()]);
    intel.seedPracticeSteps('pt-voice', [
      _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
      _step(id: 'pt-voice-3', order: 2, title: 'Duy trì', isPremium: true),
    ]);
    intel.seedEnrollments([_enrollment(completed: ['pt-voice-1'])]);
    intel.seedEntitlement(
      WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
    );

    await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
    await tester.pumpAndSettle();

    // Duy trì step visible but NOT dimmed (premium unlocked)
    expect(find.text('Duy trì'), findsOneWidget);
  });

  testWidgets('shows Bắt đầu chủ đề button when not enrolled', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([_theme()]);
    intel.seedPracticeSteps('pt-voice', [
      _step(id: 'pt-voice-1', order: 1),
    ]);

    await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
    await tester.pumpAndSettle();

    expect(find.text('Bắt đầu chủ đề'), findsOneWidget);
  });

  testWidgets('enrolling when at free quota (3) navigates to paywall', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([_theme(id: 'pt-new', title: 'Chủ đề mới')]);
    intel.seedPracticeSteps('pt-new', [_step(themeId: 'pt-new')]);
    // 3 active enrollments → at free limit
    intel.seedEnrollments([
      _enrollment(themeId: 'pt-a'),
      _enrollment(themeId: 'pt-b'),
      _enrollment(themeId: 'pt-c'),
    ]);

    await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bắt đầu chủ đề'));
    await tester.pumpAndSettle();

    expect(find.text('Paywall'), findsOneWidget);
  });

  testWidgets('marking step done calls updateEnrollmentSteps and inserts memory event', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    final content = FakeWrContentRepository();
    intel.seedPracticeThemes([_theme()]);
    intel.seedPracticeSteps('pt-voice', [
      _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
      _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
    ]);
    intel.seedEnrollments([_enrollment()]);

    await tester.pumpWidget(_wrap(
      const WrGrowthScreen(),
      intel: intel,
      content: content,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();

    // updateEnrollmentSteps called with pt-voice-1
    expect(intel.updateEnrollmentStepsCalls, isNotEmpty);
    expect(
      intel.updateEnrollmentStepsCalls.last.completedSteps,
      contains('pt-voice-1'),
    );
    // Memory event inserted
    expect(content.insertMemoryEventCalls, isNotEmpty);
    expect(
      content.insertMemoryEventCalls.last.behavior,
      'practice_step_done',
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// WrJourneyScreen — Sprint 1
// ─────────────────────────────────────────────────────────────────────────────

group('WrJourneyScreen — empty state', () {
  testWidgets('shows empty memory card when no events', (tester) async {
    await tester.pumpWidget(_wrap(const WrJourneyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Career Memory trống'), findsOneWidget);
  });
});

group('WrJourneyScreen — with events (free user)', () {
  testWidgets('shows up to 10 events and lock banner at limit', (tester) async {
    final content = FakeWrContentRepository();
    content.seedMemoryEvents(List.generate(
      10,
      (i) => _event(
        id: 'e$i',
        reflectionText: 'Event $i',
        createdAt: DateTime(2026, 7, 22 - i),
      ),
    ));

    await tester.pumpWidget(_wrap(const WrJourneyScreen(), content: content));
    await tester.pumpAndSettle();

    // Lock banner in tree (may be off-screen in test viewport — sliver lazy loads)
    expect(find.text('Xem toàn bộ Career Memory', skipOffstage: false), findsOneWidget);
  });

  testWidgets('no lock banner for premium user', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedEntitlement(
      WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
    );
    final content = FakeWrContentRepository();
    content.seedMemoryEvents(List.generate(
      15,
      (i) => _event(
        id: 'e$i',
        userId: 'u1',
        reflectionText: 'Event $i',
        createdAt: DateTime(2026, 7, 22 - i),
      ),
    ));

    await tester.pumpWidget(_wrap(
      const WrJourneyScreen(),
      intel: intel,
      content: content,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Xem toàn bộ Career Memory'), findsNothing);
  });

  testWidgets('shows pattern lock card always', (tester) async {
    await tester.pumpWidget(_wrap(const WrJourneyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Phân tích mô thức chuyên sâu'), findsOneWidget);
  });

  testWidgets('shows profile link', (tester) async {
    await tester.pumpWidget(_wrap(const WrJourneyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ nghề nghiệp'), findsOneWidget);
  });

  testWidgets('shows pattern with occurrence >= 2', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPatternCounts([
      PatternCount(
        userId: 'u1',
        situationCode: 'S1-01',
        occurrenceCount: 3,
        lastSeenAt: DateTime(2026, 7, 1),
      ),
    ]);
    final content = FakeWrContentRepository();
    content.seedSituations([_situation(code: 'S1-01', text: 'Vai trò chưa rõ')]);

    await tester.pumpWidget(_wrap(
      const WrJourneyScreen(),
      intel: intel,
      content: content,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vai trò chưa rõ'), findsOneWidget);
    expect(find.textContaining('3 lần'), findsOneWidget);
  });

  testWidgets('does not show pattern with occurrence < 2', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPatternCounts([
      PatternCount(
        userId: 'u1',
        situationCode: 'S1-01',
        occurrenceCount: 1,
        lastSeenAt: DateTime(2026, 7, 1),
      ),
    ]);
    final content = FakeWrContentRepository();
    content.seedSituations([_situation(code: 'S1-01', text: 'Vai trò chưa rõ')]);

    await tester.pumpWidget(_wrap(
      const WrJourneyScreen(),
      intel: intel,
      content: content,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vai trò chưa rõ'), findsNothing);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// WrPaywallScreen
// ─────────────────────────────────────────────────────────────────────────────

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

    await tester.scrollUntilVisible(
      find.text('Bắt đầu Premium →'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bắt đầu Premium →'));
    await tester.pump();

    expect(find.text('Thanh toán sẽ sớm ra mắt'), findsOneWidget);
  });
});

} // end main
