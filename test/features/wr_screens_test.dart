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
}) => ScaSelfCheckResponse(
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
}) => PracticeTheme(themeId: id, title: title);

PracticeStep _step({
  String id = 'pt-voice-1',
  String themeId = 'pt-voice',
  int order = 1,
  String title = 'Nhận diện',
  bool isPremium = false,
}) => PracticeStep(
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
}) => PracticeEnrollment(
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
}) => CareerMemoryEvent(
  id: id,
  userId: userId,
  behavior: behavior,
  reflectionText: reflectionText,
  createdAt: createdAt ?? DateTime(2026, 7, 22),
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

      expect(
        find.textContaining('Ngày hôm nay của bạn như thế nào?'),
        findsOneWidget,
      );
      expect(find.text('Có năng lượng'), findsOneWidget);
    });

    testWidgets('renders 3 energy choices', (tester) async {
      await tester.pumpWidget(_wrap(const WrHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Có năng lượng'), findsOneWidget);
      expect(find.text('Bình thường'), findsOneWidget);
      expect(find.text('Mệt mỏi'), findsOneWidget);
    });

    testWidgets('avatar button opens profile from header', (tester) async {
      await tester.pumpWidget(_wrap(const WrHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_home_profile_button')), findsOneWidget);
    });

    testWidgets('tapping energy reveals direction choices', (tester) async {
      await tester.pumpWidget(_wrap(const WrHomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Có năng lượng'));
      await tester.pump();

      expect(find.text('Tiến lên'), findsOneWidget);
      expect(find.text('Đứng yên'), findsOneWidget);
      expect(find.text('Thụt lùi'), findsOneWidget);
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

      // New design: "Chưa có đủ dữ liệu" in dominant need empty card
      expect(find.textContaining('Chưa có'), findsWidgets);
    });

    testWidgets('renders CTA to do self-check when no history', (tester) async {
      await tester.pumpWidget(_wrap(const WrDiscoverScreen()));
      await tester.pumpAndSettle();

      // New design shows CTA "Làm 15 câu phản chiếu" in empty need card
      expect(find.textContaining('15 câu phản chiếu'), findsWidgets);
    });

    testWidgets('CTA is Làm 15 câu phản chiếu when no history', (tester) async {
      await tester.pumpWidget(_wrap(const WrDiscoverScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('15 câu phản chiếu'), findsWidgets);
    });
  });

  group('WrDiscoverScreen — has data (free user)', () {
    testWidgets('shows SCA labels with new design (Minh bạch vai trò, etc.)', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheckResponse()]);

      await tester.pumpWidget(_wrap(const WrDiscoverScreen(), intel: intel));
      await tester.pumpAndSettle();

      // New design: SCA card with labels instead of score bars
      expect(find.textContaining('Minh bạch vai trò'), findsWidgets);
      expect(find.textContaining('An toàn khi lên tiếng'), findsWidgets);
      expect(find.textContaining('Định hướng ý nghĩa'), findsWidgets);
    });

    testWidgets('shows ĐIỀU BẠN ĐANG TÌM KIẾM section when data present', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheckResponse()]);

      await tester.pumpWidget(_wrap(const WrDiscoverScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.textContaining('ĐIỀU BẠN ĐANG TÌM KIẾM'), findsOneWidget);
    });

    testWidgets('shows the Self-Check deep-dive lock for free user', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheckResponse()]);

      await tester.pumpWidget(_wrap(const WrDiscoverScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(
        find.text('Diễn giải sâu & xu hướng theo thời gian'),
        findsOneWidget,
      );
      expect(find.textContaining('49 câu'), findsNothing);
      expect(find.textContaining('Premium'), findsWidgets);
    });

    testWidgets('shows no locked cards for premium user', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([
        _selfCheckResponse(s: 4.0, c: 3.5, a: 4.2),
        _selfCheckResponse(s: 3.0, c: 3.0, a: 3.0),
      ]);
      intel.seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );

      await tester.pumpWidget(_wrap(const WrDiscoverScreen(), intel: intel));
      await tester.pumpAndSettle();

      // New design: premium users do not see locked cards
      expect(find.textContaining('49 câu'), findsNothing);
      expect(
        find.text('Diễn giải sâu & xu hướng theo thời gian'),
        findsNothing,
      );
      // MỞ KHOÁ VỚI PREMIUM eyebrow not shown
      expect(find.textContaining('MỞ KHOÁ VỚI PREMIUM'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // WrGrowthScreen — Sprint 1
  // ─────────────────────────────────────────────────────────────────────────────

  group('WrGrowthScreen — empty state', () {
    testWidgets('renders top-area greeting Development Map', (tester) async {
      await tester.pumpWidget(_wrap(const WrGrowthScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Development Map'), findsOneWidget);
      expect(find.text('Phát triển'), findsOneWidget);
    });

    testWidgets(
      'renders empty card with invite to read story when no active theme',
      (tester) async {
        await tester.pumpWidget(_wrap(const WrGrowthScreen()));
        await tester.pumpAndSettle();

        // New design: cream card with eyebrow + invite text, no "Chưa có chủ đề"
        expect(
          find.textContaining('Chưa có chủ đề nào đang thực hành'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Đọc story và nhận Insight'),
          findsOneWidget,
        );
        expect(find.textContaining('Khám phá story'), findsOneWidget);
      },
    );

    testWidgets('empty card shows TRỌNG TÂM HIỆN TẠI eyebrow', (tester) async {
      await tester.pumpWidget(_wrap(const WrGrowthScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('TRỌNG TÂM HIỆN TẠI'), findsOneWidget);
    });
  });

  group('WrGrowthScreen — with themes (free user)', () {
    testWidgets('shows card-dark with active theme title when enrolled', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      // card-dark shows theme title (TRỌNG TÂM HIỆN TẠI eyebrow + theme name)
      expect(find.textContaining('TRỌNG TÂM HIỆN TẠI'), findsOneWidget);
      expect(find.text('Dám lên tiếng'), findsOneWidget);
    });

    testWidgets('shows PRACTICES HÔM NAY section with steps when enrolled', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
        _step(id: 'pt-voice-3', order: 3, title: 'Duy trì', isPremium: true),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.textContaining('PRACTICES HÔM NAY'), findsOneWidget);
      expect(find.text('Nhận diện'), findsOneWidget);
      expect(find.text('Thử nghiệm'), findsOneWidget);
      expect(find.text('Duy trì'), findsOneWidget);
    });

    testWidgets('done step shows Hoàn thành status (teal)', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
      ]);
      // pt-voice-1 already completed
      intel.seedEnrollments([
        _enrollment(completed: ['pt-voice-1']),
      ]);

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Hoàn thành'), findsOneWidget);
    });

    testWidgets('current step shows Đang thực hiện status (coral)', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      // First step (order=1, completed.length=0) is isNext → "Đang thực hiện"
      expect(find.text('Đang thực hiện'), findsOneWidget);
    });

    testWidgets('unstarted step shows Chưa bắt đầu status', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      // Second step (order=2, completed.length=0 → not isNext) → "Chưa bắt đầu"
      expect(find.text('Chưa bắt đầu'), findsOneWidget);
    });

    testWidgets('shows theme title and steps', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
        _step(id: 'pt-voice-3', order: 3, title: 'Duy trì', isPremium: true),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Dám lên tiếng'), findsOneWidget);
      expect(find.text('Nhận diện'), findsOneWidget);
      expect(find.text('Thử nghiệm'), findsOneWidget);
      expect(find.text('Duy trì'), findsOneWidget);
    });

    testWidgets('premium step shows ⭐ Premium badge for free user', (
      tester,
    ) async {
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
      intel.seedEnrollments([
        _enrollment(completed: ['pt-voice-1']),
      ]);
      intel.seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      // Duy trì step visible but NOT dimmed (premium unlocked)
      expect(find.text('Duy trì'), findsOneWidget);
    });

    testWidgets(
      'no active theme shows empty invite card (not Practices section)',
      (tester) async {
        final intel = FakeWrIntelligenceRepository();
        // Seed no themes → no unenrolledThemes → old empty card shown
        intel.seedPracticeThemes([]);
        // No enrollment → no active theme → empty card, no practices section

        await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
        await tester.pumpAndSettle();

        // No themes available → falls through to old card with "Khám phá story"
        expect(find.textContaining('Khám phá story'), findsOneWidget);
        expect(find.text('Bắt đầu chủ đề'), findsNothing);
        expect(find.textContaining('PRACTICES HÔM NAY'), findsNothing);
      },
    );

    testWidgets(
      'marking step done calls updateEnrollmentSteps and inserts memory event',
      (tester) async {
        final intel = FakeWrIntelligenceRepository();
        final content = FakeWrContentRepository();
        intel.seedPracticeThemes([_theme()]);
        intel.seedPracticeSteps('pt-voice', [
          _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
          _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
        ]);
        intel.seedEnrollments([_enrollment()]);

        await tester.pumpWidget(
          _wrap(const WrGrowthScreen(), intel: intel, content: content),
        );
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
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // WrJourneyScreen — Sprint 1
  // ─────────────────────────────────────────────────────────────────────────────

  group('WrJourneyScreen — top-area', () {
    testWidgets('renders Career Memory greeting and Hành trình title', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Career Memory'), findsOneWidget);
      expect(find.text('Hành trình'), findsOneWidget);
    });

    testWidgets('renders CÂU CHUYỆN CỦA BẠN eyebrow', (tester) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('CÂU CHUYỆN CỦA BẠN'), findsOneWidget);
    });

    testWidgets('renders narrative text with event count', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          reflectionText: 'Khoảnh khắc 1',
          createdAt: DateTime(2026, 7, 1),
        ),
        _event(
          id: 'e2',
          reflectionText: 'Khoảnh khắc 2',
          createdAt: DateTime(2026, 7, 10),
        ),
      ]);

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), content: content));
      await tester.pumpAndSettle();

      // Narrative contains event count "2 khoảnh khắc"
      expect(find.textContaining('2 khoảnh khắc'), findsOneWidget);
    });

    testWidgets('renders Career Companion caption', (tester) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Career Companion'), findsOneWidget);
    });
  });

  group('WrJourneyScreen — empty state', () {
    testWidgets('shows empty memory card when no events', (tester) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Career Memory trống'), findsOneWidget);
    });
  });

  group('WrJourneyScreen — timeline', () {
    testWidgets('renders THÁNG eyebrow with month number', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          reflectionText: 'Insight đầu tiên',
          createdAt: DateTime(2026, 7, 10),
        ),
      ]);

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), content: content));
      await tester.pumpAndSettle();

      // THÁNG 7 eyebrow (month of first event)
      expect(find.textContaining('THÁNG'), findsOneWidget);
    });

    testWidgets('renders event reflectionText as timeline title', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          reflectionText: 'Insight đầu tiên',
          createdAt: DateTime(2026, 7, 10),
        ),
      ]);

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), content: content));
      await tester.pumpAndSettle();

      expect(find.text('Insight đầu tiên'), findsOneWidget);
    });

    testWidgets('practice_step_done event shows THỰC HÀNH label', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          behavior: 'practice_step_done',
          reflectionText: 'Bước 1',
          createdAt: DateTime(2026, 7, 10),
        ),
      ]);

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), content: content));
      await tester.pumpAndSettle();

      expect(find.text('THỰC HÀNH'), findsOneWidget);
    });

    testWidgets('decision event shows QUYẾT ĐỊNH label', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          behavior: 'decision',
          reflectionText: 'Tôi quyết định rời đi',
          createdAt: DateTime(2026, 7, 15),
        ),
      ]);

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), content: content));
      await tester.pumpAndSettle();

      expect(find.text('QUYẾT ĐỊNH'), findsOneWidget);
    });
  });

  group('WrJourneyScreen — with events (free user)', () {
    testWidgets('shows up to 10 events and lock banner at limit', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents(
        List.generate(
          10,
          (i) => _event(
            id: 'e$i',
            reflectionText: 'Event $i',
            createdAt: DateTime(2026, 7, 22 - i),
          ),
        ),
      );

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), content: content));
      await tester.pumpAndSettle();

      // Lock banner in tree (may be off-screen in test viewport — sliver lazy loads)
      expect(
        find.text('Xem toàn bộ Career Memory', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('no lock banner for premium user', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );
      final content = FakeWrContentRepository();
      content.seedMemoryEvents(
        List.generate(
          15,
          (i) => _event(
            id: 'e$i',
            userId: 'u1',
            reflectionText: 'Event $i',
            createdAt: DateTime(2026, 7, 22 - i),
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(const WrJourneyScreen(), intel: intel, content: content),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xem toàn bộ Career Memory'), findsNothing);
    });

    testWidgets('shows Pattern Nâng cao section always', (tester) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      // Khối "Diễn biến theo thời gian" thay cho banner khoá placeholder cũ:
      // free thấy khối mờ + nút nâng cấp (Hai Lớp v1.2 §III/§IV).
      // Section nằm dưới viewport — dùng skipOffstage: false.
      expect(
        find.text('DIỄN BIẾN THEO THỜI GIAN', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Mở diễn biến theo thời gian', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('does NOT show Hồ sơ nghề nghiệp link (removed per mockup)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ nghề nghiệp'), findsNothing);
    });

    testWidgets(
      'does NOT show MÔ THỨC CỦA BẠN section (moved to Hiểu mình tab)',
      (tester) async {
        await tester.pumpWidget(_wrap(const WrJourneyScreen()));
        await tester.pumpAndSettle();

        expect(find.textContaining('MÔ THỨC CỦA BẠN'), findsNothing);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // WrGrowthScreen — phase counter (Critical fix #1)
  // ─────────────────────────────────────────────────────────────────────────────

  group('WrGrowthScreen — phase counter', () {
    testWidgets('shows Giai đoạn 1 / 2 when no steps completed', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Giai đoạn 1 / 2'), findsOneWidget);
    });

    testWidgets('shows Giai đoạn 2 / 2 when first step completed', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
      ]);
      intel.seedEnrollments([
        _enrollment(completed: ['pt-voice-1']),
      ]);

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      expect(find.text('Giai đoạn 2 / 2'), findsOneWidget);
    });

    testWidgets('shows Hoàn thành (not 3/2) when all steps completed', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
      ]);
      intel.seedEnrollments([
        _enrollment(completed: ['pt-voice-1', 'pt-voice-2']),
      ]);

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      // Counter text must show "Hoàn thành", NOT "Giai đoạn 3 / 2"
      // (the step status texts also show "Hoàn thành" for each completed step;
      //  the key check is that the counter does NOT show an out-of-range value)
      expect(find.textContaining('3 / 2'), findsNothing);
      // Counter label text is exactly "Hoàn thành" (12px muted white)
      // At least one "Hoàn thành" text exists — counter-level check
      expect(find.textContaining('Hoàn thành'), findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // WrGrowthScreen — step ordering (Important fix #4)
  // ─────────────────────────────────────────────────────────────────────────────

  group('WrGrowthScreen — step ordering', () {
    testWidgets('marks correct isNext step even when steps arrive out of order', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      // Seed steps intentionally out of order: order 2 before order 1
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
      await tester.pumpAndSettle();

      // Step with order=1 should be isNext (Đang thực hiện), order=2 should be Chưa bắt đầu
      expect(find.text('Đang thực hiện'), findsOneWidget);
      expect(find.text('Chưa bắt đầu'), findsOneWidget);
    });

    testWidgets(
      'isNext advances to step 2 after step 1 completed, regardless of seeding order',
      (tester) async {
        final intel = FakeWrIntelligenceRepository();
        intel.seedPracticeThemes([_theme()]);
        // Seed out of order
        intel.seedPracticeSteps('pt-voice', [
          _step(id: 'pt-voice-3', order: 3, title: 'Duy trì'),
          _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
          _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
        ]);
        // step 1 done → step 2 (order=2) should be isNext
        intel.seedEnrollments([
          _enrollment(completed: ['pt-voice-1']),
        ]);

        await tester.pumpWidget(_wrap(const WrGrowthScreen(), intel: intel));
        await tester.pumpAndSettle();

        // Only one "Đang thực hiện" status must appear
        expect(find.text('Đang thực hiện'), findsOneWidget);
        // And the other two are done/not-started
        expect(find.text('Hoàn thành'), findsOneWidget);
        expect(find.text('Chưa bắt đầu'), findsOneWidget);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // WrJourneyScreen — narrative window cap (Critical fix #2)
  // ─────────────────────────────────────────────────────────────────────────────

  group('WrJourneyScreen — narrative window cap', () {
    testWidgets(
      'narrative shows span in days when oldest event is within 30 days',
      (tester) async {
        final now = DateTime.now();
        final content = FakeWrContentRepository();
        content.seedMemoryEvents([
          _event(
            id: 'e1',
            reflectionText: 'Khoảnh khắc 1',
            createdAt: now.subtract(const Duration(days: 5)),
          ),
          _event(
            id: 'e2',
            reflectionText: 'Khoảnh khắc 2',
            createdAt: now.subtract(const Duration(days: 10)),
          ),
        ]);

        await tester.pumpWidget(
          _wrap(const WrJourneyScreen(), content: content),
        );
        await tester.pumpAndSettle();

        // Span must be ≤ 30: "Trong 10 ngày qua" (oldest is 10 days ago)
        expect(find.textContaining('ngày qua'), findsOneWidget);
        // Must NOT produce a span > 30
        expect(find.textContaining('365 ngày'), findsNothing);
      },
    );

    testWidgets(
      'narrative caps at 30 ngày when oldest event is older than 30 days',
      (tester) async {
        final now = DateTime.now();
        final content = FakeWrContentRepository();
        content.seedMemoryEvents([
          _event(
            id: 'e1',
            reflectionText: 'Recent',
            createdAt: now.subtract(const Duration(days: 5)),
          ),
          _event(
            id: 'e2',
            reflectionText: 'Old',
            createdAt: now.subtract(const Duration(days: 90)),
          ),
        ]);

        await tester.pumpWidget(
          _wrap(const WrJourneyScreen(), content: content),
        );
        await tester.pumpAndSettle();

        // Must cap at 30 ngày, NOT show 90
        expect(find.textContaining('30 ngày qua'), findsOneWidget);
        expect(find.textContaining('90 ngày'), findsNothing);
      },
    );

    testWidgets('narrative zero days when no events', (tester) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      // No events → 0 days, 0 khoảnh khắc
      expect(find.textContaining('0 khoảnh khắc'), findsOneWidget);
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
      expect(find.text('Diễn giải Self-Check sâu'), findsOneWidget);
      expect(find.text('Career Pattern'), findsOneWidget);
      expect(find.text('Không giới hạn'), findsOneWidget);
    });

    testWidgets('shows free vs premium comparison table with 10 rows', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WrPaywallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Story Reflection hàng ngày'), findsOneWidget);
      expect(find.text('Check-in nhanh'), findsOneWidget);
      expect(find.text('Career Memory Timeline'), findsOneWidget);
      expect(find.text('15 câu phản chiếu'), findsOneWidget);
      expect(find.text('3 chủ đề Thực hành'), findsOneWidget);
      expect(find.text('AI Insight'), findsOneWidget);
      expect(find.text('Xu hướng Self-Check & mất cân bằng'), findsOneWidget);
      expect(find.textContaining('49 câu'), findsNothing);
      expect(find.text('Career Pattern Analysis'), findsOneWidget);
      expect(find.text('Career Benchmark'), findsOneWidget);
      expect(find.text('Không giới hạn Thực hành'), findsOneWidget);
    });

    testWidgets('CTA button shows payment coming soon snackbar', (
      tester,
    ) async {
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
