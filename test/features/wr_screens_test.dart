// Tests cho các màn WR: home, story, discover, growth, journey, paywall, self-check.
// Sprint 1: Discover/Growth/Journey updated to ConsumerWidget with real providers.
// Run: flutter test test/features/wr_screens_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_paywall_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_practice_theme_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_story_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_pricing.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _wrap(
  Widget child, {
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
  FakeWrRepository? repo,
  String? userId,
  WrEntitlementRecord? entitlement,
}) {
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final contentRepo = content ?? FakeWrContentRepository();
  // Paywall đọc giá qua wrPremiumPricingProvider → wrRepositoryProvider. Không
  // override thì nó chạm Supabase thật và im lặng rơi về giá mặc định, tức test
  // không còn kiểm được giá lấy từ `cc_products`.
  final wrRepo = repo ?? FakeWrRepository();
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
      // Màn thanh toán thật chạm Supabase ngay khi mở (tạo đơn), nên ở đây chỉ
      // cần chứng minh nút Paywall điều hướng đúng chỗ.
      GoRoute(
        path: '/wr/payment',
        builder: (_, __) => const Scaffold(body: Text('Màn thanh toán')),
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
      wrRepositoryProvider.overrideWithValue(wrRepo),
      currentUserIdProvider.overrideWithValue(userId ?? 'u1'),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
    ),
  );
}


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


/// Mở mốc đầu tiên trên dòng thời gian Hành trình.
///
/// Từ 2026-08-03 mỗi mốc thu gọn sẵn: mặc định chỉ hiện LOẠI mốc, nội dung nằm
/// sau một cú chạm.
Future<void> _expandFirstJourneyEntry(WidgetTester tester) async {
  final arrow = find.byIcon(Icons.keyboard_arrow_down_rounded).first;
  await tester.ensureVisible(arrow);
  await tester.pumpAndSettle();
  await tester.tap(arrow);
  await tester.pumpAndSettle();
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────────
  // WrHomeScreen
  // ─────────────────────────────────────────────────────────────────────────────

  // Home sau khi tái cấu trúc chỉ còn lời mời — chi tiết luồng nằm ở
  // test/features/wr_reflection_flow_test.dart.
  group('WrHomeScreen', () {
    testWidgets('hỏi luôn năng lượng, không xổ nội dung khác', (tester) async {
      await tester.pumpWidget(_wrap(const WrHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ngày hôm nay của bạn như thế nào?'), findsOneWidget);
      expect(find.byKey(const Key('wr_home_checkin_tired')), findsOneWidget);
      // Không còn nút trung gian, cũng không còn bước "hướng đi".
      expect(find.byKey(const Key('wr_home_start_reflection')), findsNothing);
      expect(find.text('Tiến lên'), findsNothing);
    });

    testWidgets('avatar button opens profile from header', (tester) async {
      await tester.pumpWidget(_wrap(const WrHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_home_profile_button')), findsOneWidget);
    });
  });

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

  // Hiểu mình sau tái cấu trúc: chỉ liệt kê dòng ghi nhận, phần diễn giải nằm
  // ở màn chi tiết. Chi tiết hai tầng free/premium xem
  // test/features/wr_discover_two_tier_test.dart.
  group('WrDiscoverScreen — empty state', () {
    testWidgets('mời phản tư khi chưa có dữ liệu', (tester) async {
      await tester.pumpWidget(_wrap(const WrDiscoverScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Hiểu mình'), findsOneWidget);
      // Chưa nhìn lại lần nào thì thẻ Career Health không dựng (một thanh 0/15
      // trên màn mời bắt đầu là báo cáo một con số bằng không), và mục "Hành
      // trình đã đi" đã bỏ hẳn — lời mời còn lại là bộ 15 câu.
      expect(
        find.byKey(const Key('wr_discover_career_health')),
        findsNothing,
      );
      expect(find.text('Bắt đầu Self-Check'), findsOneWidget);
    });

    testWidgets('không diễn giải gì khi chưa có dữ liệu', (tester) async {
      await tester.pumpWidget(_wrap(const WrDiscoverScreen()));
      await tester.pumpAndSettle();

      // Phần diễn giải (nhu cầu chủ đạo) không còn ở tầng miễn phí.
      expect(find.textContaining('ĐIỀU BẠN ĐANG TÌM KIẾM'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // WrGrowthScreen — Sprint 1
  // ─────────────────────────────────────────────────────────────────────────────

  group('WrGrowthScreen — empty state', () {
    testWidgets('renders top-area eyebrow Phát triển + title Thực hành', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WrGrowthScreen()));
      await tester.pumpAndSettle();

      // Giao diện mẫu Sprint 2: eyebrow "Phát triển", tiêu đề "Thực hành".
      expect(find.text('Phát triển'), findsOneWidget);
      expect(find.text('Thực hành'), findsOneWidget);
    });

    testWidgets(
      'chưa có chủ đề nào trong thư viện thì nói WorkReflection sẽ đề xuất',
      (tester) async {
        await tester.pumpWidget(_wrap(const WrGrowthScreen()));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Chưa có chủ đề nào đang thực hành'),
          findsOneWidget,
        );
        // Chủ đề là thứ phần mềm chuẩn bị từ những gì người dùng đã nhìn lại
        // (khách 2026-08-04) — không đẩy họ sang màn khác để tự tìm.
        expect(
          find.textContaining('WorkReflection sẽ đề xuất chủ đề'),
          findsOneWidget,
        );
      },
    );

    testWidgets('empty card shows TRỌNG TÂM HIỆN TẠI eyebrow', (tester) async {
      await tester.pumpWidget(_wrap(const WrGrowthScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('TRỌNG TÂM HIỆN TẠI'), findsOneWidget);
    });
  });

  group('WrGrowthScreen — with themes (free user)', () {
    testWidgets('shows theme card with title + progress when enrolled', (
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

      expect(find.textContaining('CHỦ ĐỀ CỦA BẠN'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_growth_theme_card_pt-voice')),
        findsOneWidget,
      );
      expect(find.text('Dám lên tiếng'), findsOneWidget);
      expect(find.text('0/2 bước hoàn thành'), findsOneWidget);
    });

    testWidgets('màn chủ đề liệt kê đủ các bước', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
        _step(id: 'pt-voice-3', order: 3, title: 'Duy trì', isPremium: true),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(_wrap(
        const WrPracticeThemeScreen(themeId: 'pt-voice'),
        intel: intel,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nhận diện'), findsOneWidget);
      expect(find.text('Thử nghiệm'), findsOneWidget);
      expect(find.text('Duy trì'), findsOneWidget);
      expect(find.text('0/3 bước hoàn thành'), findsOneWidget);
    });

    testWidgets('bước đã xong được đánh dấu trong tiến độ chủ đề', (
      tester,
    ) async {
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

      await tester.pumpWidget(_wrap(
        const WrPracticeThemeScreen(themeId: 'pt-voice'),
        intel: intel,
      ));
      await tester.pumpAndSettle();

      expect(find.text('1/2 bước hoàn thành'), findsOneWidget);
      // Bước đã xong không còn nút bấm — không đánh dấu xong được hai lần.
      expect(
        find.byKey(const Key('wr_practice_step_done_pt-voice-1')),
        findsNothing,
      );
    });

    testWidgets('chỉ bước kế tiếp mới có nút đánh dấu hoàn thành', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(_wrap(
        const WrPracticeThemeScreen(themeId: 'pt-voice'),
        intel: intel,
      ));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_practice_step_done_pt-voice-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wr_practice_step_done_pt-voice-2')),
        findsNothing,
      );
    });

    testWidgets('bước chưa tới lượt nói rõ phải xong bước trước', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
        _step(id: 'pt-voice-2', order: 2, title: 'Thử nghiệm'),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(_wrap(
        const WrPracticeThemeScreen(themeId: 'pt-voice'),
        intel: intel,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Xong bước trước rồi mở tiếp'), findsOneWidget);
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

      await tester.pumpWidget(_wrap(
        const WrPracticeThemeScreen(themeId: 'pt-voice'),
        intel: intel,
      ));
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

      await tester.pumpWidget(_wrap(
        const WrPracticeThemeScreen(themeId: 'pt-voice'),
        intel: intel,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Premium'), findsWidgets);
      expect(
        find.byKey(const Key('wr_practice_step_unlock_pt-voice-3')),
        findsOneWidget,
      );
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

      await tester.pumpWidget(_wrap(
        const WrPracticeThemeScreen(themeId: 'pt-voice'),
        intel: intel,
      ));
      await tester.pumpAndSettle();

      // Bước Premium hiện và bấm được, không còn nút mở khoá.
      expect(find.text('Duy trì'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_practice_step_unlock_pt-voice-3')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('wr_practice_step_done_pt-voice-3')),
        findsOneWidget,
      );
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

        // Thư viện rỗng → thẻ nói chưa có chủ đề nào, không dựng danh sách.
        expect(
          find.textContaining('Chưa có chủ đề nào đang thực hành'),
          findsOneWidget,
        );
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
          _wrap(
            const WrPracticeThemeScreen(themeId: 'pt-voice'),
            intel: intel,
            content: content,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Đánh dấu hoàn thành'));
        await tester.pumpAndSettle();

        // §VII: bấm Xong mở tấm ghi chú trước, chưa ghi gì cả.
        expect(intel.updateEnrollmentStepsCalls, isEmpty);
        expect(find.byKey(const Key('wr_practice_note_field')), findsOneWidget);

        await tester.tap(find.byKey(const Key('wr_practice_note_skip')));
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
        // "Bỏ qua" không sinh thêm gì — không ghi chú, không mảnh ký ức thứ hai.
        expect(intel.upsertPracticeStepNoteCalls, isEmpty);
        expect(
          content.insertMemoryEventCalls
              .where((e) => e.behavior == kPracticeStepNoteBehavior),
          isEmpty,
        );
      },
    );

    testWidgets(
      'ghi chú khi hoàn thành bước sinh thêm một mảnh Career Memory (§VII)',
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
          _wrap(
            const WrPracticeThemeScreen(themeId: 'pt-voice'),
            intel: intel,
            content: content,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Đánh dấu hoàn thành'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('wr_practice_note_field')),
          'Mình nói được ý của mình trong buổi họp sáng nay.',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('wr_practice_note_save')));
        await tester.pumpAndSettle();

        expect(intel.upsertPracticeStepNoteCalls, hasLength(1));
        expect(intel.upsertPracticeStepNoteCalls.single.stepId, 'pt-voice-1');

        final noteEvents = content.insertMemoryEventCalls
            .where((e) => e.behavior == kPracticeStepNoteBehavior)
            .toList();
        expect(noteEvents, hasLength(1));
        // §VII: "{tên hành động}: {nội dung}"
        expect(
          noteEvents.single.reflectionText,
          'Nhận diện: Mình nói được ý của mình trong buổi họp sáng nay.',
        );
      },
    );

    testWidgets('đóng tấm ghi chú là huỷ hẳn — bước vẫn chưa xong', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      final content = FakeWrContentRepository();
      intel.seedPracticeThemes([_theme()]);
      intel.seedPracticeSteps('pt-voice', [
        _step(id: 'pt-voice-1', order: 1, title: 'Nhận diện'),
      ]);
      intel.seedEnrollments([_enrollment()]);

      await tester.pumpWidget(
        _wrap(
          const WrPracticeThemeScreen(themeId: 'pt-voice'),
          intel: intel,
          content: content,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đánh dấu hoàn thành'));
      await tester.pumpAndSettle();

      // Chạm ra ngoài tấm = đóng, không phải "xong mà không ghi chú".
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(intel.updateEnrollmentStepsCalls, isEmpty);
      expect(content.insertMemoryEventCalls, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // WrJourneyScreen — Sprint 1
  // ─────────────────────────────────────────────────────────────────────────────

  group('WrJourneyScreen — top-area', () {
    testWidgets('renders Career Memory eyebrow and Hành trình title', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('CAREER MEMORY'), findsOneWidget);
      expect(find.text('Hành trình'), findsOneWidget);
    });

    testWidgets('renders memory count', (tester) async {
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

      expect(find.textContaining('2 mảnh ký ức'), findsOneWidget);
    });
  });

  group('WrJourneyScreen — empty state', () {
    testWidgets('shows invitation when no events', (tester) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Chưa có mảnh ký ức nào'), findsOneWidget);
    });
  });

  // Dòng thời gian chỉ hiện với Premium (khách chốt 2026-07-29), nên nhóm test
  // dựng hình này phải chạy dưới tài khoản Premium.
  group('WrJourneyScreen — timeline', () {
    FakeWrIntelligenceRepository premiumIntel() => FakeWrIntelligenceRepository()
      ..seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );

    testWidgets('gom mục theo tháng khi có dữ liệu', (
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

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), intel: premiumIntel(), content: content));
      await tester.pumpAndSettle();

      expect(find.text('THÁNG 7, 2026'), findsOneWidget);
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

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), intel: premiumIntel(), content: content));
      await tester.pumpAndSettle();
      await _expandFirstJourneyEntry(tester);

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

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), intel: premiumIntel(), content: content));
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

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), intel: premiumIntel(), content: content));
      await tester.pumpAndSettle();

      expect(find.text('QUYẾT ĐỊNH'), findsOneWidget);
    });
  });

  // Quyết định của khách 2026-07-29: Career Memory khoá HOÀN TOÀN với Free.
  // Bản trước cho xem 10 mục gần nhất rồi mới cắt.
  group('WrJourneyScreen — with events (free user)', () {
    testWidgets('free không thấy mảnh ký ức nào, chỉ thấy khối khoá', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents(
        List.generate(
          3,
          (i) => _event(
            id: 'e$i',
            reflectionText: 'Event $i',
            createdAt: DateTime(2026, 7, 22 - i),
          ),
        ),
      );

      await tester.pumpWidget(_wrap(const WrJourneyScreen(), content: content));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_journey_memory_lock'), skipOffstage: false),
        findsOneWidget,
      );
      for (var i = 0; i < 3; i++) {
        expect(find.text('Event $i', skipOffstage: false), findsNothing,
            reason: 'mảnh ký ức $i lọt ra ngoài paywall');
      }
      // Con số tổng vẫn nói ra — đó là việc chính người dùng đã làm.
      expect(
        find.textContaining('3 mảnh ký ức', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('chưa có ký ức nào thì không dựng khối khoá rỗng', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_journey_memory_lock'), skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('premium đọc được từng mảnh ký ức', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          reflectionText: 'Event 1',
          createdAt: DateTime(2026, 7, 22),
        ),
      ]);

      await tester.pumpWidget(
        _wrap(const WrJourneyScreen(), intel: intel, content: content),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_journey_memory_lock'), skipOffstage: false),
        findsNothing,
      );
      await _expandFirstJourneyEntry(tester);
      expect(find.text('Event 1', skipOffstage: false), findsOneWidget);
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

    testWidgets('diễn biến theo thời gian là một dòng dẫn sang màn riêng', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WrJourneyScreen()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_journey_narrative_row'), skipOffstage: false),
        findsOneWidget,
      );
      // Nội dung diễn giải không còn nằm ngay trên tab.
      expect(
        find.text('Mở diễn biến theo thời gian', skipOffstage: false),
        findsNothing,
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

      expect(find.text('Giai đoạn 1/2'), findsOneWidget);
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

      expect(find.text('Giai đoạn 2/2'), findsOneWidget);
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

      // Đếm giai đoạn không được vượt tổng số bước.
      expect(find.textContaining('3/2'), findsNothing);
      expect(find.text('Giai đoạn 2/2'), findsOneWidget);
      expect(find.text('2/2 bước hoàn thành'), findsOneWidget);
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

      await tester.pumpWidget(_wrap(
        const WrPracticeThemeScreen(themeId: 'pt-voice'),
        intel: intel,
      ));
      await tester.pumpAndSettle();

      // Bước order=1 mới là bước kế tiếp, dù được gieo sau.
      expect(
        find.byKey(const Key('wr_practice_step_done_pt-voice-1')),
        findsOneWidget,
      );
      expect(find.text('Xong bước trước rồi mở tiếp'), findsOneWidget);
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

        await tester.pumpWidget(_wrap(
          const WrPracticeThemeScreen(themeId: 'pt-voice'),
          intel: intel,
        ));
        await tester.pumpAndSettle();

        // Đúng một bước được phép bấm, và đó là bước order=2.
        expect(find.text('Đánh dấu hoàn thành'), findsOneWidget);
        expect(
          find.byKey(const Key('wr_practice_step_done_pt-voice-2')),
          findsOneWidget,
        );
        expect(find.text('1/3 bước hoàn thành'), findsOneWidget);
      },
    );
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

    // Hai khoá mới của 2026-07-29 phải nói đúng thứ vừa bị khoá, không rơi về
    // headline chung — nếu không thì bấm "Mở phần đọc vị" lại thấy một câu
    // quảng cáo không liên quan.
    testWidgets('need_reading trigger nói đúng phần vừa khoá', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrPaywallScreen(trigger: PaywallTrigger.needReading)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Điều bạn đang thật sự tìm kiếm'), findsOneWidget);
    });

    testWidgets('career_memory trigger nói đúng phần vừa khoá', (tester) async {
      await tester.pumpWidget(
        _wrap(const WrPaywallScreen(trigger: PaywallTrigger.careerMemory)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Toàn bộ ký ức nghề nghiệp của bạn'), findsOneWidget);
    });

    // Giá lấy từ `cc_products`, dòng `premium_mobile` — gói APP 499.000đ, KHÔNG
    // phải gói web 249.000đ (khách chốt 2026-08-04: hai gói khác nhau, khác
    // giá, cùng cấp role premium).
    testWidgets('shows PREMIUM badge and price', (tester) async {
      await tester.pumpWidget(_wrap(const WrPaywallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('PREMIUM'), findsOneWidget);
      expect(find.text('499.000đ / năm'), findsOneWidget);
    });

    testWidgets('gói app không khuyến mãi: không gạch ngang, không mức giảm',
        (tester) async {
      await tester.pumpWidget(_wrap(const WrPaywallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('499.000đ / năm'), findsOneWidget);
      expect(find.text('249.000đ'), findsNothing);
      // Không có badge giảm giá "−…%". Nhãn "TIẾT KIỆM …%" của bộ chọn gói là
      // chuyện khác — nó so gói năm với gói tháng, không phải khuyến mãi.
      expect(find.textContaining('−'), findsNothing);
    });

    // Cơ chế gạch ngang vẫn còn: quản trị điền `original_price` cho dòng
    // `premium_mobile` là app hiện giá gốc + mức giảm.
    testWidgets('có giá gốc thì gạch ngang bên cạnh giá đang bán',
        (tester) async {
      final repo = FakeWrRepository()
        ..premiumPricing = const WrPremiumPricing(
          currentPrice: 399000,
          originalPrice: 499000,
          productId: 'prod-premium-mobile-test',
        );
      await tester.pumpWidget(_wrap(const WrPaywallScreen(), repo: repo));
      await tester.pumpAndSettle();

      // Một ở header, một ở khối giá trên nút mua.
      expect(find.text('499.000đ'), findsNWidgets(2));
      expect(find.text('399.000đ'), findsOneWidget);
      expect(find.text('−20%'), findsOneWidget);

      final struck = tester.widgetList<Text>(find.text('499.000đ'));
      for (final t in struck) {
        expect(t.style?.decoration, TextDecoration.lineThrough);
      }
    });

    testWidgets('quản trị đổi giá gói app thì app hiện theo, không build lại',
        (tester) async {
      final repo = FakeWrRepository()
        ..premiumPricing = const WrPremiumPricing(
          currentPrice: 199000,
          originalPrice: 599000,
        );
      await tester.pumpWidget(_wrap(const WrPaywallScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('199.000đ / năm'), findsOneWidget);
      expect(find.text('−67%'), findsOneWidget);
    });

    // Khách chốt 2026-08-04: thêm gói tháng 70.000đ để hạ rào cản, gói năm vẫn
    // là gói chọn sẵn.
    group('chọn gói năm / tháng', () {
      testWidgets('hiện cả hai gói, gói năm chọn sẵn', (tester) async {
        await tester.pumpWidget(_wrap(const WrPaywallScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Một năm'), findsOneWidget);
        expect(find.text('Một tháng'), findsOneWidget);
        expect(find.text('70.000đ'), findsOneWidget);
        // Gói năm đang chọn → khối giá và header nói theo gói năm.
        expect(find.text('499.000đ / năm'), findsOneWidget);
        expect(find.text('cho một năm Premium'), findsOneWidget);
      });

      testWidgets('gói năm khoe mức tiết kiệm quy về mỗi tháng', (tester) async {
        await tester.pumpWidget(_wrap(const WrPaywallScreen()));
        await tester.pumpAndSettle();

        // 499.000 / 12 = 41.583đ mỗi tháng, so với 70.000đ → rẻ hơn 41%.
        expect(find.text('TIẾT KIỆM 41%'), findsOneWidget);
        expect(find.text('≈ 41.583đ mỗi tháng'), findsOneWidget);
      });

      testWidgets('gói tháng không tự khoe tiết kiệm so với chính nó',
          (tester) async {
        await tester.pumpWidget(_wrap(const WrPaywallScreen()));
        await tester.pumpAndSettle();

        expect(find.textContaining('TIẾT KIỆM'), findsOneWidget);
      });

      testWidgets('chạm gói tháng thì khối giá và header đổi theo',
          (tester) async {
        await tester.pumpWidget(_wrap(const WrPaywallScreen()));
        await tester.pumpAndSettle();

        // Bộ chọn gói nằm dưới bảng so sánh nên mặc định ngoài khung 800×600.
        final monthly = find.byKey(const Key('wr_paywall_plan_30'));
        await tester.ensureVisible(monthly);
        await tester.pumpAndSettle();
        await tester.tap(monthly);
        await tester.pumpAndSettle();

        expect(find.text('70.000đ / tháng'), findsOneWidget);
        expect(find.text('cho một tháng Premium'), findsOneWidget);
        expect(find.text('499.000đ / năm'), findsNothing);
      });

      testWidgets('chỉ có một gói thì không dựng bộ chọn', (tester) async {
        final repo = FakeWrRepository()
          ..premiumPlans = const [
            WrPremiumPricing(
              currentPrice: 499000,
              productId: 'prod-1',
              durationDays: 365,
            ),
          ];
        await tester.pumpWidget(_wrap(const WrPaywallScreen(), repo: repo));
        await tester.pumpAndSettle();

        expect(find.text('CHỌN GÓI'), findsNothing);
        expect(find.text('499.000đ / năm'), findsOneWidget);
      });

      testWidgets('quản trị thêm gói 6 tháng thì tự hiện, không cần build lại',
          (tester) async {
        final repo = FakeWrRepository()
          ..premiumPlans = const [
            WrPremiumPricing(
              currentPrice: 499000,
              productId: 'prod-1',
              durationDays: 365,
            ),
            WrPremiumPricing(
              currentPrice: 299000,
              productId: 'prod-6m',
              durationDays: 180,
            ),
            WrPremiumPricing(
              currentPrice: 70000,
              productId: 'prod-1m',
              durationDays: 30,
            ),
          ];
        await tester.pumpWidget(_wrap(const WrPaywallScreen(), repo: repo));
        await tester.pumpAndSettle();

        expect(find.text('Một năm'), findsOneWidget);
        expect(find.text('6 tháng'), findsOneWidget);
        expect(find.text('Một tháng'), findsOneWidget);
      });
    });

    testWidgets('shows 3 premium highlights', (tester) async {
      await tester.pumpWidget(_wrap(const WrPaywallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('AI Insight cá nhân hoá'), findsOneWidget);
      expect(find.text('Career Pattern'), findsOneWidget);
      expect(find.text('Không giới hạn'), findsOneWidget);
      // Mục "Báo cáo chuyên sâu 49 câu" đã bỏ khỏi paywall.
      expect(find.textContaining('Báo cáo chuyên sâu'), findsNothing);
    });

    testWidgets('shows free vs premium comparison table with 9 rows', (
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
      expect(find.text('Career Pattern Analysis'), findsOneWidget);
      expect(find.text('Career Benchmark'), findsOneWidget);
      expect(find.text('Không giới hạn Thực hành'), findsOneWidget);
    });

    testWidgets('CTA button mở màn thanh toán', (
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
      await tester.pumpAndSettle();

      expect(find.text('Màn thanh toán'), findsOneWidget);
    });
  });
} // end main
