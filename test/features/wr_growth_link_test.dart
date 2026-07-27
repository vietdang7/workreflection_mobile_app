// Tests phủ Task A–E cho Growth/Discover integration:
// A: Discover tests hiện có vẫn xanh (helper mới thay hàm private)
// B: Card gợi ý từ Hiểu mình khi không có active enrollment
// C: Card "BƯỚC ĐANG CHỜ BẠN" khi có active theme
// D: Section "THỰC HÀNH KHÁC" + enroll + quota
// E: Tag bước NHẬN DIỆN/THỬ NGHIỆM/CHUYỂN HÓA + link Discover → Growth
// Run: flutter test test/features/wr_growth_link_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_dominant_need.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_themes_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

GoRouter _makeRouter({required Widget home}) => GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(path: '/test', builder: (_, __) => home),
        GoRoute(
          path: '/wr/growth',
          builder: (_, __) => const Scaffold(body: Text('GrowthScreen')),
        ),
        GoRoute(
          path: '/wr/discover',
          builder: (_, __) => const Scaffold(body: Text('DiscoverScreen')),
        ),
        GoRoute(
          path: '/wr/paywall',
          builder: (_, __) => const Scaffold(body: Text('PaywallScreen')),
        ),
        GoRoute(
          path: '/wr/self-check',
          builder: (_, __) => const Scaffold(body: Text('SelfCheckScreen')),
        ),
        GoRoute(
          path: '/wr/story',
          builder: (_, __) => const Scaffold(body: Text('StoryScreen')),
        ),
        GoRoute(
          path: '/wr/journey',
          builder: (_, __) => const Scaffold(body: Text('JourneyScreen')),
        ),
      ],
    );

Widget _wrapGrowth({
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String userId = 'u1',
  WrEntitlementRecord? entitlement,
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  if (entitlement != null) intelRepo.seedEntitlement(entitlement);
  final router = _makeRouter(home: const WrGrowthScreen());
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue(userId),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Màn "Thực hành khác" — sau Sprint D3 danh sách chủ đề chưa bắt đầu nằm ở
/// màn riêng, không còn xổ trong tab Phát triển.
Widget _wrapThemes({
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String userId = 'u1',
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = _makeRouter(home: const WrGrowthThemesScreen());
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue(userId),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}


Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

// Fake data helpers
WrSituation _sit(String code, HumanNeed need) => WrSituation(
      code: code,
      text: 'Situation $code',
      humanNeed: need,
      scaDimension: ScaDimension.c1,
      wave: 1,
    );

PatternCount _pattern(String code, int count) => PatternCount(
      userId: 'u1',
      situationCode: code,
      occurrenceCount: count,
      lastSeenAt: DateTime(2026, 7, 1),
    );

PracticeTheme _theme(String id, String title,
        {ScaDimension? dim, String? desc}) =>
    PracticeTheme(
      themeId: id,
      title: title,
      scaDimension: dim,
      description: desc ?? 'Mô tả $title',
    );

PracticeStep _step(String id, String themeId, int order, String title,
        {bool isPremium = false}) =>
    PracticeStep(
      stepId: id,
      themeId: themeId,
      stepOrder: order,
      title: title,
      isPremium: isPremium,
    );

PracticeEnrollment _enrollment(String themeId,
        {List<String> completedSteps = const [], DateTime? completedAt}) =>
    PracticeEnrollment(
      userId: 'u1',
      themeId: themeId,
      completedSteps: completedSteps,
      completedAt: completedAt,
    );

void main() {
// ─────────────────────────────────────────────────────────────────────────────
// Task A — helper unit tests (không cần widget pump)
// ─────────────────────────────────────────────────────────────────────────────

group('Task A — dominantNeedFromBehaviour helper', () {
  test('trả về null khi patterns rỗng', () {
    expect(dominantNeedFromBehaviour([], []), isNull);
  });

  test('tính đúng nhu cầu ketNoi từ patterns', () {
    final situations = [
      _sit('s-connect', HumanNeed.ketNoi),
      _sit('s-clear', HumanNeed.roRang),
    ];
    final patterns = [
      _pattern('s-connect', 5),
      _pattern('s-clear', 2),
    ];
    expect(
      dominantNeedFromBehaviour(patterns, situations),
      HumanNeed.ketNoi,
    );
  });

  test('trả về null khi không có situation có humanNeed', () {
    final situations = <WrSituation>[
      WrSituation(
        code: 's1',
        text: 'S1',
        humanNeed: null,
        scaDimension: ScaDimension.s1,
        wave: 1,
      ),
    ];
    final patterns = [_pattern('s1', 3)];
    expect(dominantNeedFromBehaviour(patterns, situations), isNull);
  });
});

group('Task A — dominantNeedFromSelfCheck helper', () {
  test('C thấp nhất → ketNoi', () {
    final r = ScaSelfCheckResponse(
      userId: 'u1',
      answers: {},
      takenAt: DateTime(2026, 7, 1),
      structureScore: 4.0,
      cultureScore: 2.0,
      activityScore: 3.5,
    );
    expect(dominantNeedFromSelfCheck(r), HumanNeed.ketNoi);
  });

  test('S thấp nhất → roRang', () {
    final r = ScaSelfCheckResponse(
      userId: 'u1',
      answers: {},
      takenAt: DateTime(2026, 7, 1),
      structureScore: 1.5,
      cultureScore: 3.0,
      activityScore: 2.5,
    );
    expect(dominantNeedFromSelfCheck(r), HumanNeed.roRang);
  });

  test('A thấp nhất → phatTrien', () {
    final r = ScaSelfCheckResponse(
      userId: 'u1',
      answers: {},
      takenAt: DateTime(2026, 7, 1),
      structureScore: 4.0,
      cultureScore: 3.5,
      activityScore: 1.0,
    );
    expect(dominantNeedFromSelfCheck(r), HumanNeed.phatTrien);
  });

  test('tie C==S → C wins → ketNoi', () {
    final r = ScaSelfCheckResponse(
      userId: 'u1',
      answers: {},
      takenAt: DateTime(2026, 7, 1),
      structureScore: 2.0,
      cultureScore: 2.0,
      activityScore: 3.0,
    );
    expect(dominantNeedFromSelfCheck(r), HumanNeed.ketNoi);
  });
});

group('Task A — needPillarLetter + needSeekingLabel', () {
  test('needPillarLetter đúng cho 4 nhu cầu', () {
    expect(needPillarLetter(HumanNeed.roRang), 'S');
    expect(needPillarLetter(HumanNeed.ketNoi), 'C');
    expect(needPillarLetter(HumanNeed.thichNghi), 'A');
    expect(needPillarLetter(HumanNeed.phatTrien), 'A');
  });

  test('needSeekingLabel đúng cho 4 nhu cầu', () {
    expect(needSeekingLabel(HumanNeed.roRang), 'sự rõ ràng');
    expect(needSeekingLabel(HumanNeed.ketNoi), 'sự kết nối');
    expect(needSeekingLabel(HumanNeed.thichNghi), 'sự thích nghi');
    expect(needSeekingLabel(HumanNeed.phatTrien), 'sự phát triển');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Task B — Card gợi ý từ Hiểu mình
// ─────────────────────────────────────────────────────────────────────────────

group('Task B — Card gợi ý từ Hiểu mình', () {
  testWidgets(
      'patterns → ketNoi + theme scaDimension C → hiện card gợi ý + dòng lý do',
      (tester) async {
    final content = FakeWrContentRepository();
    content.seedSituations([_sit('s-connect', HumanNeed.ketNoi)]);

    final intel = FakeWrIntelligenceRepository();
    intel.seedPatternCounts([_pattern('s-connect', 3)]);
    intel.seedPracticeThemes([
      _theme('t-culture', 'Thực hành kết nối', dim: ScaDimension.c1),
    ]);
    intel.seedEnrollments([]);

    await _pumpLarge(tester, _wrapGrowth(content: content, intel: intel));

    expect(find.text('GỢI Ý TỪ HIỂU MÌNH'), findsOneWidget);
    expect(find.text('Thực hành kết nối'), findsAtLeastNWidgets(1));
    expect(
      find.text('Vì bạn đang tìm kiếm sự kết nối.'),
      findsOneWidget,
    );
    expect(find.text('Bắt đầu thực hành'), findsAtLeastNWidgets(1));
    expect(find.text('Xem trong Hiểu mình'), findsOneWidget);
  });

  testWidgets(
      'không có pattern + không có self-check → card trống cũ (dù có theme chưa enroll)',
      (tester) async {
    final intel = FakeWrIntelligenceRepository();
    // Seed CÓ theme chưa enroll — nhưng KHÔNG có pattern và KHÔNG có self-check
    // → dominantNeed == null → suggestedTheme phải giữ null → card trống
    intel.seedPracticeThemes([
      _theme('t-unused', 'Chủ đề chưa dùng', dim: ScaDimension.c1),
    ]);
    intel.seedEnrollments([]);

    await _pumpLarge(tester, _wrapGrowth(intel: intel));

    expect(find.text('Chưa có chủ đề nào đang thực hành'), findsOneWidget);
    expect(find.text('GỢI Ý TỪ HIỂU MÌNH'), findsNothing);
    // Nút 'Bắt đầu thực hành' không xuất hiện trong card gợi ý
    expect(find.text('Bắt đầu thực hành'), findsNothing);
    // Danh sách chủ đề khác không còn xổ tại chỗ — chỉ còn một dòng dẫn đi.
    expect(find.text('THỰC HÀNH KHÁC'), findsNothing);
    expect(find.byKey(const Key('wr_growth_other_themes_row')), findsOneWidget);
  });

  testWidgets('tap Bắt đầu thực hành → enrollThemeCalls có đúng themeId',
      (tester) async {
    final content = FakeWrContentRepository();
    content.seedSituations([_sit('s-connect', HumanNeed.ketNoi)]);

    final intel = FakeWrIntelligenceRepository();
    intel.seedPatternCounts([_pattern('s-connect', 3)]);
    intel.seedPracticeThemes([
      _theme('t-culture', 'Thực hành kết nối', dim: ScaDimension.c2),
    ]);
    intel.seedEnrollments([]);

    await _pumpLarge(tester, _wrapGrowth(content: content, intel: intel));

    await tester.tap(find.text('Bắt đầu thực hành'));
    await tester.pumpAndSettle();

    expect(intel.enrollThemeCalls, hasLength(1));
    expect(intel.enrollThemeCalls.first.themeId, 't-culture');
  });

  testWidgets(
      'không match trụ → fallback theme chưa-enroll đầu tiên, không có dòng lý do',
      (tester) async {
    final content = FakeWrContentRepository();
    content.seedSituations([_sit('s-connect', HumanNeed.ketNoi)]);

    final intel = FakeWrIntelligenceRepository();
    intel.seedPatternCounts([_pattern('s-connect', 3)]);
    // Theme có scaDimension S (không phải C)
    intel.seedPracticeThemes([
      _theme('t-struct', 'Thực hành cấu trúc', dim: ScaDimension.s1),
    ]);
    intel.seedEnrollments([]);

    await _pumpLarge(tester, _wrapGrowth(content: content, intel: intel));

    expect(find.text('GỢI Ý TỪ HIỂU MÌNH'), findsOneWidget);
    expect(find.text('Thực hành cấu trúc'), findsAtLeastNWidgets(1));
    // Không có dòng lý do vì không match trụ
    expect(
        find.textContaining('Vì bạn đang tìm kiếm'), findsNothing);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Task C — Card "BƯỚC ĐANG CHỜ BẠN"
// ─────────────────────────────────────────────────────────────────────────────

group('Task C — Card BƯỚC ĐANG CHỜ BẠN', () {
  testWidgets(
      'active enrollment 1/3 bước xong → card hiện tên bước 2',
      (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([
      _theme('t1', 'Chủ đề A'),
    ]);
    intel.seedPracticeSteps('t1', [
      _step('s1', 't1', 1, 'Nhận diện vấn đề'),
      _step('s2', 't1', 2, 'Thử nghiệm giải pháp'),
      _step('s3', 't1', 3, 'Chuyển hóa thói quen'),
    ]);
    intel.seedEnrollments([
      _enrollment('t1', completedSteps: ['s1']),
    ]);

    await _pumpLarge(tester, _wrapGrowth(intel: intel));

    expect(find.text('BƯỚC ĐANG CHỜ BẠN'), findsOneWidget);
    // Text xuất hiện cả trong card header lẫn practices list
    expect(
      find.textContaining('Thử nghiệm giải pháp'),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('xong hết bước → ẩn card BƯỚC ĐANG CHỜ BẠN', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([
      _theme('t1', 'Chủ đề A'),
    ]);
    intel.seedPracticeSteps('t1', [
      _step('s1', 't1', 1, 'Bước 1'),
      _step('s2', 't1', 2, 'Bước 2'),
    ]);
    intel.seedEnrollments([
      _enrollment('t1', completedSteps: ['s1', 's2']),
    ]);

    await _pumpLarge(tester, _wrapGrowth(intel: intel));

    expect(find.text('BƯỚC ĐANG CHỜ BẠN'), findsNothing);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Task D — Section "THỰC HÀNH KHÁC" + enroll + quota
// ─────────────────────────────────────────────────────────────────────────────

group('Task D — Màn Thực hành khác', () {
  testWidgets('chỉ liệt kê theme chưa enroll', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([
      _theme('t1', 'Chủ đề đang làm'),
      _theme('t2', 'Chủ đề chưa làm'),
    ]);
    intel.seedEnrollments([_enrollment('t1')]);

    await _pumpLarge(tester, _wrapThemes(intel: intel));

    expect(find.text('THỰC HÀNH KHÁC'), findsOneWidget);
    expect(find.text('Chủ đề chưa làm'), findsOneWidget);
    expect(find.text('Chủ đề đang làm'), findsNothing);
  });

  testWidgets('tap Bắt đầu → enrollTheme gọi đúng themeId', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([
      _theme('t1', 'Chủ đề chưa làm', desc: 'Mô tả ngắn'),
    ]);
    intel.seedEnrollments([]);

    await _pumpLarge(tester, _wrapThemes(intel: intel));

    expect(find.text('Bắt đầu'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();

    expect(intel.enrollThemeCalls, hasLength(1));
    expect(intel.enrollThemeCalls.first.themeId, 't1');
    expect(intel.enrollThemeCalls.first.userId, 'u1');
    expect(intel.enrollThemeCalls.first.completedSteps, isEmpty);
    expect(intel.enrollThemeCalls.first.completedAt, isNull);
  });

  testWidgets('đủ quota free (2 active) → hiện ⭐ Premium thay nút Bắt đầu',
      (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([
      _theme('t1', 'Active 1'),
      _theme('t2', 'Active 2'),
      _theme('t3', 'Chưa enroll'),
    ]);
    intel.seedEnrollments([_enrollment('t1'), _enrollment('t2')]);

    await _pumpLarge(tester, _wrapThemes(intel: intel));

    expect(find.byKey(const Key('wr_growth_themes_quota')), findsOneWidget);
    expect(find.text('⭐ Premium'), findsWidgets);
    expect(find.text('Bắt đầu'), findsNothing);
  });

  testWidgets('tap ⭐ Premium → navigate to paywall', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([
      _theme('t1', 'Active 1'),
      _theme('t2', 'Active 2'),
      _theme('t3', 'Chưa enroll'),
    ]);
    intel.seedEnrollments([_enrollment('t1'), _enrollment('t2')]);

    await _pumpLarge(tester, _wrapThemes(intel: intel));

    await tester.tap(find.text('⭐ Premium').first);
    await tester.pumpAndSettle();

    expect(find.text('PaywallScreen'), findsOneWidget);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Task E — Tags bước + link Discover → Growth
// ─────────────────────────────────────────────────────────────────────────────

group('Task E — Tags bước theo stepOrder', () {
  testWidgets(
      'step order 1→NHẬN DIỆN, 2→THỬ NGHIỆM, 3→CHUYỂN HÓA hiện đúng',
      (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([_theme('t1', 'Chủ đề test')]);
    intel.seedPracticeSteps('t1', [
      _step('s1', 't1', 1, 'Bước nhận diện'),
      _step('s2', 't1', 2, 'Bước thử nghiệm'),
      _step('s3', 't1', 3, 'Bước chuyển hóa'),
    ]);
    intel.seedEnrollments([_enrollment('t1')]);

    await _pumpLarge(tester, _wrapGrowth(intel: intel));

    expect(find.text('NHẬN DIỆN'), findsOneWidget);
    expect(find.text('THỬ NGHIỆM'), findsOneWidget);
    expect(find.text('CHUYỂN HÓA'), findsOneWidget);
  });

  testWidgets('step order 4 → không có tag', (tester) async {
    final intel = FakeWrIntelligenceRepository();
    intel.seedPracticeThemes([_theme('t1', 'Chủ đề 4 bước')]);
    intel.seedPracticeSteps('t1', [
      _step('s1', 't1', 1, 'Bước 1'),
      _step('s2', 't1', 2, 'Bước 2'),
      _step('s3', 't1', 3, 'Bước 3'),
      _step('s4', 't1', 4, 'Bước 4 không tag'),
    ]);
    intel.seedEnrollments([_enrollment('t1')]);

    await _pumpLarge(tester, _wrapGrowth(intel: intel));

    // Chỉ 3 tags cho order 1-3
    expect(find.text('NHẬN DIỆN'), findsOneWidget);
    expect(find.text('THỬ NGHIỆM'), findsOneWidget);
    expect(find.text('CHUYỂN HÓA'), findsOneWidget);
  });

});

// Các test cũ về liên kết chéo từ Hiểu mình sang Phát triển đã bỏ: sau khi tối
// giản, Hiểu mình chỉ liệt kê ghi nhận và mở màn chi tiết, không còn nút gợi ý
// thực hành. Phần hai tầng free/premium xem wr_discover_two_tier_test.dart.
} // end main
