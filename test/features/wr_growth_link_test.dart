// Tests phủ Task A–E cho Growth/Discover integration:
// A: Discover tests hiện có vẫn xanh (helper mới thay hàm private)
// B: Phần mềm tự thêm chủ đề khi người dùng đã tích đủ dữ liệu
// C: (đã bỏ — thẻ "BƯỚC ĐANG CHỜ BẠN" gỡ khỏi màn Phát triển 2026-08-04)
// D: Section "THỰC HÀNH KHÁC" + enroll + quota
// E: Tag bước NHẬN DIỆN/THỬ NGHIỆM/CHUYỂN HÓA + link Discover → Growth
// Run: flutter test test/features/wr_growth_link_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_dominant_need.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_themes_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_practice_theme_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
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
  FakeWrEpisodeRepository? episodes,
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
      wrEpisodeRepositoryProvider.overrideWithValue(
        episodes ?? FakeWrEpisodeRepository(),
      ),
      currentUserIdProvider.overrideWithValue(userId),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,routerConfig: router),
  );
}

/// [count] lượt nhìn lại cùng chọn tình huống [code].
///
/// Gieo EPISODE chứ không gieo `wr_pattern_counts`: từ 2026-07-31 gợi ý chủ đề
/// đọc recentSituationIds (Kiến trúc v2.0 §4.3 — "chiều hoạt động nhiều nhất
/// cho gợi ý Practice Theme").
FakeWrEpisodeRepository _episodesFor(String code, int count) =>
    FakeWrEpisodeRepository()..seed([
      for (var i = 0; i < count; i++)
        ReflectionEpisode(
          id: '\$code-\$i',
          userId: 'u1',
          humanMoment: HumanMoment.confusion,
          state: ExperienceState.integrated,
          situationCode: code,
          openedAt: DateTime(2026, 7, 20).add(Duration(hours: i)),
        ),
    ]);

/// Màn "Thực hành khác" — sau Sprint D3 danh sách chủ đề chưa bắt đầu nằm ở
/// màn riêng, không còn xổ trong tab Phát triển.
/// Màn một chủ đề — từ giao diện mẫu Sprint 2, chuỗi bước nằm ở đây chứ không
/// còn xổ ngay trên tab Phát triển.
Widget _wrapPracticeTheme(
  String themeId, {
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String userId = 'u1',
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = _makeRouter(home: WrPracticeThemeScreen(themeId: themeId));
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue(userId),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,routerConfig: router),
  );
}

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
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,routerConfig: router),
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


PracticeTheme _theme(
  String id,
  String title, {
  ScaDimension? dim,
  String? desc,
}) => PracticeTheme(
  themeId: id,
  title: title,
  scaDimension: dim,
  description: desc ?? 'Mô tả $title',
);

PracticeStep _step(
  String id,
  String themeId,
  int order,
  String title, {
  bool isPremium = false,
}) => PracticeStep(
  stepId: id,
  themeId: themeId,
  stepOrder: order,
  title: title,
  isPremium: isPremium,
);

PracticeEnrollment _enrollment(
  String themeId, {
  List<String> completedSteps = const [],
  DateTime? completedAt,
}) => PracticeEnrollment(
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
      final recent = [
        ...List.filled(5, 's-connect'),
        ...List.filled(2, 's-clear'),
      ];
      expect(dominantNeedFromBehaviour(recent, situations), HumanNeed.ketNoi);
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
      final recent = List.filled(3, 's1');
      expect(dominantNeedFromBehaviour(recent, situations), isNull);
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

  group('Task B — Phần mềm tự thêm chủ đề', () {
    /// Bộ tự đánh giá đã làm xong, trụ C thấp nhất → nhu cầu Kết nối.
    ScaSelfCheckResponse selfCheck({DateTime? at}) => ScaSelfCheckResponse(
          userId: 'u1',
          answers: const {},
          structureScore: 4.0,
          cultureScore: 2.0,
          activityScore: 4.0,
          takenAt: at ?? DateTime(2026, 8, 1),
        );

    // Hướng 1 — khách chốt 2026-08-04: đủ 15 LẦN nhìn lại là được một chủ đề, và
    // phần mềm TỰ thêm, không chờ ai bấm nút.
    testWidgets(
      'đủ 15 lần nhìn lại → tự thêm chủ đề khớp chiều vào danh sách',
      (tester) async {
        final content = FakeWrContentRepository();
        content.seedSituations([_sit('s-connect', HumanNeed.ketNoi)]);

        final intel = FakeWrIntelligenceRepository();
        intel.seedPracticeThemes([
          _theme('t-culture', 'Thực hành kết nối', dim: ScaDimension.c1),
        ]);
        intel.seedEnrollments([]);

        await _pumpLarge(
          tester,
          _wrapGrowth(
            content: content,
            intel: intel,
            episodes: _episodesFor('s-connect', 15),
          ),
        );

        expect(intel.enrollThemeCalls, hasLength(1));
        expect(intel.enrollThemeCalls.first.themeId, 't-culture');
        // Chủ đề vào thẳng danh sách, không qua thẻ báo tin nào: khách bỏ khối
        // "BẠN VỪA CÓ CHỦ ĐỀ MỚI" ngày 2026-08-04 vì nó chồng lên thẻ chủ đề
        // ngay bên dưới.
        expect(
          find.byKey(const Key('wr_growth_theme_card_t-culture')),
          findsOneWidget,
        );
      },
    );

    testWidgets('14 lần thì chưa thêm gì, và nói còn thiếu bao nhiêu', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit('s-connect', HumanNeed.ketNoi)]);

      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([
        _theme('t-culture', 'Thực hành kết nối', dim: ScaDimension.c1),
      ]);
      intel.seedEnrollments([]);

      await _pumpLarge(
        tester,
        _wrapGrowth(
          content: content,
          intel: intel,
          episodes: _episodesFor('s-connect', 14),
        ),
      );

      expect(intel.enrollThemeCalls, isEmpty);
      expect(find.text('Chưa đủ dữ liệu để có chủ đề'), findsOneWidget);
      expect(find.textContaining('14/15 lần'), findsOneWidget);
    });

    // Hướng 2 — làm xong bộ 15 câu là có chủ đề ngay, không cần lặp lần nào.
    testWidgets('làm xong tự đánh giá → tự thêm ngay dù chưa nhìn lại lần nào', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([
        _theme('t-culture', 'Thực hành kết nối', dim: ScaDimension.c1),
      ]);
      intel.seedEnrollments([]);
      intel.seedSelfCheckHistory([selfCheck()]);

      await _pumpLarge(tester, _wrapGrowth(intel: intel));

      expect(intel.enrollThemeCalls, hasLength(1));
      expect(intel.enrollThemeCalls.first.themeId, 't-culture');
    });

    // Bộ tự đánh giá làm SAU lần nhìn lại gần nhất thì nó là tiếng nói mới nhất.
    // Bản trước hành vi luôn thắng, nên ai đã nhìn lại vài lần rồi mới ngồi trả
    // lời 15 câu thì kết quả bộ đó không đổi được gì.
    testWidgets('tự đánh giá mới hơn hành vi thì thắng hành vi', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit('s-struct', HumanNeed.roRang)]);

      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([
        _theme('t-struct', 'Thực hành cấu trúc', dim: ScaDimension.s1),
        _theme('t-culture', 'Thực hành kết nối', dim: ScaDimension.c1),
      ]);
      intel.seedEnrollments([]);
      // Episode gieo ở 2026-07-20, bộ tự đánh giá làm sau.
      intel.seedSelfCheckHistory([selfCheck(at: DateTime(2026, 8, 1))]);

      await _pumpLarge(
        tester,
        _wrapGrowth(
          content: content,
          intel: intel,
          episodes: _episodesFor('s-struct', 3),
        ),
      );

      // Hành vi nói Rõ ràng (trụ S), bộ tự đánh giá nói Kết nối (trụ C) và mới
      // hơn — chủ đề phải là chủ đề trụ C.
      expect(intel.enrollThemeCalls, hasLength(1));
      expect(intel.enrollThemeCalls.first.themeId, 't-culture');
    });

    testWidgets('không match trụ vẫn thêm, và không giải thích gì', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit('s-connect', HumanNeed.ketNoi)]);

      final intel = FakeWrIntelligenceRepository();
      // Theme có scaDimension S (không phải C)
      intel.seedPracticeThemes([
        _theme('t-struct', 'Thực hành cấu trúc', dim: ScaDimension.s1),
      ]);
      intel.seedEnrollments([]);

      await _pumpLarge(
        tester,
        _wrapGrowth(
          content: content,
          intel: intel,
          episodes: _episodesFor('s-connect', 15),
        ),
      );

      expect(intel.enrollThemeCalls, hasLength(1));
      expect(intel.enrollThemeCalls.first.themeId, 't-struct');
      // Không match được gì thì TUYỆT ĐỐI không giải thích. Nói "vì bạn đang
      // tìm kiếm sự kết nối" cho một chủ đề trụ S là dựng ra mối liên hệ không
      // có thật — người dùng đọc xong sẽ tin hệ thống hiểu mình hơn thực tế.
      expect(find.textContaining('Vì bạn đang tìm kiếm'), findsNothing);
    });

    // Nợ nhiều chủ đề cũng chỉ nhận một chủ đề mỗi lượt xem màn: nghỉ một tháng
    // rồi quay lại mà thấy bốn chủ đề mới đổ ra cùng lúc thì đó là một đống
    // việc, không phải một lời mời.
    testWidgets('nợ ba chủ đề vẫn chỉ thêm một trong một lượt', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit('s-connect', HumanNeed.ketNoi)]);

      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([
        _theme('t-c1', 'Kết nối một', dim: ScaDimension.c1),
        _theme('t-c2', 'Kết nối hai', dim: ScaDimension.c2),
        _theme('t-c3', 'Kết nối ba', dim: ScaDimension.c3),
      ]);
      intel.seedEnrollments([]);
      intel.seedEntitlement(
        const WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );

      await _pumpLarge(
        tester,
        _wrapGrowth(
          content: content,
          intel: intel,
          // 45 lần = được hưởng 3 chủ đề.
          episodes: _episodesFor('s-connect', 45),
        ),
      );

      expect(intel.enrollThemeCalls, hasLength(1));
    });

    // Đã theo chủ đề rồi thì màn này chỉ nói việc đang làm. Không mời thêm chủ
    // đề bằng bất cứ hình thức nào — chủ đề mới là việc phần mềm tự thêm
    // (khách 2026-08-04, sau khi bác cả dòng dẫn sang thư viện lẫn thẻ gợi ý).
    testWidgets('đã theo một chủ đề → không có khối mời thêm chủ đề nào', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit('s-connect', HumanNeed.ketNoi)]);

      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([
        _theme('t-done', 'Chủ đề đang theo', dim: ScaDimension.s1),
        _theme('t-culture', 'Thực hành kết nối', dim: ScaDimension.c1),
      ]);
      intel.seedEnrollments([_enrollment('t-done')]);

      await _pumpLarge(
        tester,
        _wrapGrowth(
          content: content,
          intel: intel,
          episodes: _episodesFor('s-connect', 3),
        ),
      );

      expect(find.text('Chủ đề đang theo'), findsAtLeastNWidgets(1));
      expect(find.text('CHỦ ĐỀ TIẾP THEO CHO BẠN'), findsNothing);
      expect(find.text('Bắt đầu thực hành'), findsNothing);
      expect(find.byKey(const Key('wr_growth_add_theme_row')), findsNothing);
    });

    testWidgets(
      'không có pattern + không có self-check → nói thẳng là chưa đủ dữ liệu',
      (tester) async {
        final intel = FakeWrIntelligenceRepository();
        intel.seedPracticeThemes([
          _theme('t-unused', 'Chủ đề chưa dùng', dim: ScaDimension.c1),
        ]);
        intel.seedEnrollments([]);

        await _pumpLarge(tester, _wrapGrowth(intel: intel));

        expect(intel.enrollThemeCalls, isEmpty);
        expect(find.text('Chưa đủ dữ liệu để có chủ đề'), findsOneWidget);
        expect(
          find.byKey(const Key('wr_growth_suggestion_self_check')),
          findsOneWidget,
        );
        // Danh sách chủ đề khác không xổ tại chỗ (khách 2026-07-30).
        expect(find.text('THỰC HÀNH KHÁC'), findsNothing);
        expect(
          find.byKey(const Key('wr_growth_other_themes_row')),
          findsNothing,
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Task D — Section "THỰC HÀNH KHÁC" + enroll + quota
  // ─────────────────────────────────────────────────────────────────────────────

  /// Xổ hết thư viện chủ đề. Màn này dẫn bằng chủ đề được đề xuất; cả danh sách
  /// nằm sau một dòng xổ, nên test nào cần đọc danh sách phải mở nó ra.
  Future<void> showAllThemes(WidgetTester tester) async {
    // Bấm vào chính chữ: WrActionLink là GestureDetector deferToChild, tâm ô
    // full-width của nó rơi vào khoảng trống bên phải dòng chữ.
    final link = find.descendant(
      of: find.byKey(const Key('wr_growth_themes_show_all')),
      matching: find.byType(Text),
    );
    await tester.tap(link.first);
    await tester.pumpAndSettle();
  }

  group('Task D — Màn Thực hành khác', () {
    testWidgets('chỉ liệt kê theme chưa enroll', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([
        _theme('t1', 'Chủ đề đang làm'),
        _theme('t2', 'Chủ đề chưa làm'),
      ]);
      intel.seedEnrollments([_enrollment('t1')]);

      await _pumpLarge(tester, _wrapThemes(intel: intel));

      // Chưa có dữ liệu để đề xuất thì thư viện nằm sau dòng xổ — màn này không
      // bày danh sách trần nữa (khách 2026-08-04).
      expect(find.text('THỰC HÀNH KHÁC'), findsOneWidget);
      expect(find.text('Chủ đề chưa làm'), findsNothing);
      await showAllThemes(tester);

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
      await showAllThemes(tester);

      expect(find.text('Bắt đầu'), findsOneWidget);
      await tester.tap(find.text('Bắt đầu'));
      await tester.pumpAndSettle();

      expect(intel.enrollThemeCalls, hasLength(1));
      expect(intel.enrollThemeCalls.first.themeId, 't1');
      expect(intel.enrollThemeCalls.first.userId, 'u1');
      expect(intel.enrollThemeCalls.first.completedSteps, isEmpty);
      expect(intel.enrollThemeCalls.first.completedAt, isNull);
    });

    testWidgets('đủ quota free (2 active) → hiện ⭐ Premium thay nút Bắt đầu', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([
        _theme('t1', 'Active 1'),
        _theme('t2', 'Active 2'),
        _theme('t3', 'Chưa enroll'),
      ]);
      intel.seedEnrollments([_enrollment('t1'), _enrollment('t2')]);

      await _pumpLarge(tester, _wrapThemes(intel: intel));

      expect(find.byKey(const Key('wr_growth_themes_quota')), findsOneWidget);
      await showAllThemes(tester);
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
      await showAllThemes(tester);

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

        await _pumpLarge(tester, _wrapPracticeTheme('t1', intel: intel));

        expect(find.text('NHẬN DIỆN'), findsOneWidget);
        expect(find.text('THỬ NGHIỆM'), findsOneWidget);
        expect(find.text('CHUYỂN HOÁ'), findsOneWidget);
      },
    );

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

      await _pumpLarge(tester, _wrapPracticeTheme('t1', intel: intel));

      // Chỉ 3 tag cho order 1-3; bước 4 hiện tên nhưng không có nhãn giai đoạn.
      expect(find.text('NHẬN DIỆN'), findsOneWidget);
      expect(find.text('THỬ NGHIỆM'), findsOneWidget);
      expect(find.text('CHUYỂN HOÁ'), findsOneWidget);
      expect(find.text('Bước 4 không tag'), findsOneWidget);
    });
  });

  // Các test cũ về liên kết chéo từ Hiểu mình sang Phát triển đã bỏ: sau khi tối
  // giản, Hiểu mình chỉ liệt kê ghi nhận và mở màn chi tiết, không còn nút gợi ý
  // thực hành. Phần hai tầng free/premium xem wr_discover_two_tier_test.dart.
} // end main
