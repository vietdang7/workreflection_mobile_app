// Tab Phát triển sau khi dựng lại theo giao diện mẫu Sprint 2:
// màn chính liệt kê CHỦ ĐỀ, chuỗi bước nằm ở màn chủ đề riêng.
//
// Run: flutter test test/features/wr_practice_theme_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_practice_theme_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Router thật cho hai màn: bấm thẻ chủ đề phải mở đúng màn chủ đề, nên không
/// thay `/wr/growth/theme/:id` bằng màn giả.
Widget _wrap(
  Widget home, {
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
}) {
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final contentRepo = content ?? FakeWrContentRepository();

  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => home),
      GoRoute(
        path: '/wr/growth/theme/:id',
        builder: (_, state) =>
            WrPracticeThemeScreen(themeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, state) => Scaffold(
          body: Text('Paywall ${state.uri.queryParameters['trigger'] ?? '-'}'),
        ),
      ),
      GoRoute(
        path: '/wr/growth/themes',
        builder: (_, __) => const Scaffold(body: Text('Themes')),
      ),
      GoRoute(
        path: '/wr/growth/skills',
        builder: (_, __) => const Scaffold(body: Text('Skills')),
      ),
      GoRoute(
        path: '/wr/growth/journey',
        builder: (_, __) => const Scaffold(body: Text('GrowthJourney')),
      ),
      GoRoute(
        path: '/wr/story',
        builder: (_, __) => const Scaffold(body: Text('Story')),
      ),
      GoRoute(
        path: '/wr/discover',
        builder: (_, __) => const Scaffold(body: Text('Discover')),
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
      currentUserIdProvider.overrideWithValue('u1'),
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

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

PracticeTheme _theme(String id, String title) =>
    PracticeTheme(themeId: id, title: title);

PracticeStep _step(String id, String themeId, int order, String title,
        {bool premium = false, String? content}) =>
    PracticeStep(
      stepId: id,
      themeId: themeId,
      stepOrder: order,
      title: title,
      isPremium: premium,
      content: content,
    );

PracticeEnrollment _enroll(String themeId,
        {List<String> done = const [],
        DateTime? completedAt,
        DateTime? startedAt}) =>
    PracticeEnrollment(
      userId: 'u1',
      themeId: themeId,
      completedSteps: done,
      completedAt: completedAt,
      startedAt: startedAt,
    );

/// Hai chủ đề, mỗi chủ đề ba bước, bước cuối Premium — đúng dữ liệu đang gieo
/// trong migration 20260722000002.
FakeWrIntelligenceRepository _twoThemes() {
  final intel = FakeWrIntelligenceRepository();
  intel.seedPracticeThemes([
    _theme('pt-voice', 'Dám lên tiếng'),
    _theme('pt-rhythm', 'Nhịp làm việc ổn định'),
  ]);
  for (final t in ['pt-voice', 'pt-rhythm']) {
    intel.seedPracticeSteps(t, [
      _step('$t-1', t, 1, 'Nhận diện', content: 'Quan sát một tuần.'),
      _step('$t-2', t, 2, 'Thử nghiệm', content: 'Thử đúng một lần.'),
      _step('$t-3', t, 3, 'Duy trì', premium: true, content: 'Giữ bốn tuần.'),
    ]);
  }
  return intel;
}

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // Tab Phát triển — danh sách chủ đề
  // ───────────────────────────────────────────────────────────────────────────

  group('Tab Phát triển — danh sách chủ đề', () {
    testWidgets('hiện đủ MỌI chủ đề đang thực hành, không riêng chủ đề đầu', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll('pt-voice', done: ['pt-voice-1']),
        _enroll('pt-rhythm'),
      ]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(
        find.byKey(const Key('wr_growth_theme_card_pt-voice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wr_growth_theme_card_pt-rhythm')),
        findsOneWidget,
      );
      expect(find.text('1/3 bước hoàn thành'), findsOneWidget);
      expect(find.text('0/3 bước hoàn thành'), findsOneWidget);
    });

    testWidgets('chủ đề đã hoàn thành xếp sau và mang nhãn riêng', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll(
          'pt-voice',
          done: ['pt-voice-1', 'pt-voice-2', 'pt-voice-3'],
          completedAt: DateTime(2026, 7, 1),
        ),
        _enroll('pt-rhythm'),
      ]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.text('Đã hoàn thành'), findsOneWidget);
      expect(find.text('Trọn chuỗi'), findsOneWidget);
      expect(find.text('Đang thực hành'), findsOneWidget);

      // Đang thực hành phải nằm TRÊN đã hoàn thành: việc còn dở mới là việc
      // cần nhìn thấy trước.
      final active = tester
          .getTopLeft(find.byKey(const Key('wr_growth_theme_card_pt-rhythm')));
      final done = tester
          .getTopLeft(find.byKey(const Key('wr_growth_theme_card_pt-voice')));
      expect(active.dy, lessThan(done.dy));
    });

    // Yêu cầu khách 2026-08-04: hiện HẾT chủ đề, dài quá thì bỏ vào "Xem thêm",
    // chủ đề mới nhất nằm ở đầu.
    testWidgets('chủ đề mới nhất nằm trên cùng', (tester) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll('pt-voice', startedAt: DateTime(2026, 7, 1)),
        _enroll('pt-rhythm', startedAt: DateTime(2026, 8, 1)),
      ]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      final moiNhat = tester
          .getTopLeft(find.byKey(const Key('wr_growth_theme_card_pt-rhythm')));
      final cuHon = tester
          .getTopLeft(find.byKey(const Key('wr_growth_theme_card_pt-voice')));
      expect(moiNhat.dy, lessThan(cuHon.dy));
    });

    testWidgets('quá $kGrowthThemesPreview chủ đề thì phần dôi nằm sau Xem thêm',
        (tester) async {
      final intel = FakeWrIntelligenceRepository();
      final ids = ['pt-1', 'pt-2', 'pt-3', 'pt-4', 'pt-5'];
      intel.seedPracticeThemes([
        for (final id in ids) _theme(id, 'Chủ đề $id'),
      ]);
      for (final id in ids) {
        intel.seedPracticeSteps(id, [_step('$id-1', id, 1, 'Nhận diện')]);
      }
      // pt-5 mới nhất, pt-1 cũ nhất.
      intel.seedEnrollments([
        for (var i = 0; i < ids.length; i++)
          _enroll(ids[i], startedAt: DateTime(2026, 7, i + 1)),
      ]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      // Ba thẻ mới nhất hiện sẵn, hai thẻ cũ nhất nằm sau nút.
      expect(find.byKey(const Key('wr_growth_theme_card_pt-5')), findsOneWidget);
      expect(find.byKey(const Key('wr_growth_theme_card_pt-3')), findsOneWidget);
      expect(find.byKey(const Key('wr_growth_theme_card_pt-2')), findsNothing);
      expect(find.byKey(const Key('wr_growth_theme_card_pt-1')), findsNothing);
      expect(find.text('Xem thêm 2 chủ đề'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_growth_themes_more')));
      await tester.pumpAndSettle();

      // Không có chủ đề nào bị cắt mất — bấm là ra đủ cả năm.
      for (final id in ids) {
        expect(
          find.byKey(Key('wr_growth_theme_card_$id')),
          findsOneWidget,
          reason: '$id phải hiện sau khi xổ',
        );
      }
      expect(find.text('Thu gọn'), findsOneWidget);
    });

    testWidgets('đúng $kGrowthThemesPreview chủ đề thì không có nút Xem thêm',
        (tester) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice'), _enroll('pt-rhythm')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.byKey(const Key('wr_growth_themes_more')), findsNothing);
    });

    testWidgets('bấm thẻ chủ đề mở màn chủ đề đó', (tester) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-rhythm')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      await tester.tap(find.byKey(const Key('wr_growth_theme_card_pt-rhythm')));
      await tester.pumpAndSettle();

      expect(find.text('Nhịp làm việc ổn định'), findsOneWidget);
      expect(find.text('Nhận diện'), findsOneWidget);
      expect(find.text('Thử nghiệm'), findsOneWidget);
      expect(find.text('Duy trì'), findsOneWidget);
    });

    testWidgets('thẻ quota chỉ hiện với bản miễn phí và dẫn sang paywall', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice'), _enroll('pt-rhythm')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.byKey(const Key('wr_growth_quota_card')), findsOneWidget);
      expect(find.textContaining('đang mở 2/2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_growth_quota_card')));
      await tester.pumpAndSettle();
      expect(find.text('Paywall practice_limit'), findsOneWidget);
    });

    testWidgets('Premium không thấy thẻ quota — không có trần thì không nói', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice')]);
      intel.seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.byKey(const Key('wr_growth_quota_card')), findsNothing);
    });

    // Đã theo chủ đề rồi thì màn này không mời thêm chủ đề, kể cả premium:
    // chủ đề mới do phần mềm tự thêm khi đã tổng hợp đủ dữ liệu (khách
    // 2026-08-04). Premium chỉ khác free ở chỗ không bị thẻ quota chặn.
    testWidgets('Premium không thấy khối mời thêm chủ đề', (tester) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice'), _enroll('pt-rhythm')]);
      intel.seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(
        find.byKey(const Key('wr_growth_suggestion_empty')),
        findsNothing,
      );
      expect(find.byKey(const Key('wr_growth_add_theme_row')), findsNothing);
    });

    testWidgets('Free còn chỗ cũng không thấy khối mời thêm', (tester) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(
        find.byKey(const Key('wr_growth_suggestion_empty')),
        findsNothing,
      );
      expect(find.byKey(const Key('wr_growth_add_theme_row')), findsNothing);
    });

    testWidgets('Free hết 2/2 chỗ thì nhường cho thẻ quota', (tester) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice'), _enroll('pt-rhythm')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(
        find.byKey(const Key('wr_growth_suggestion_empty')),
        findsNothing,
      );
      expect(find.byKey(const Key('wr_growth_quota_card')), findsOneWidget);
    });

    testWidgets('chưa ghi danh chủ đề nào thì không dựng danh sách rỗng', (
      tester,
    ) async {
      final intel = _twoThemes();

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.textContaining('CHỦ ĐỀ CỦA BẠN'), findsNothing);
      expect(find.byKey(const Key('wr_growth_quota_card')), findsNothing);
    });

    testWidgets('ghi danh trỏ tới chủ đề không còn trong thư viện thì bỏ qua', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-da-xoa')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      // Không thẻ rỗng, không văng lỗi.
      expect(find.textContaining('CHỦ ĐỀ CỦA BẠN'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Màn chủ đề
  // ───────────────────────────────────────────────────────────────────────────

  group('Màn chủ đề', () {
    testWidgets('bước Premium hiện nội dung kèm nút mở khoá cho bản miễn phí', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll('pt-voice', done: ['pt-voice-1', 'pt-voice-2']),
      ]);

      await _pumpLarge(
        tester,
        _wrap(const WrPracticeThemeScreen(themeId: 'pt-voice'), intel: intel),
      );

      // §IV khoá cấp nội dung: vẫn thấy mình đang bỏ lỡ gì.
      expect(find.text('Duy trì'), findsOneWidget);
      expect(find.text('Giữ bốn tuần.'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_practice_step_unlock_pt-voice-3')),
        findsOneWidget,
      );
      // Và không có đường vòng để tự đánh dấu xong.
      expect(
        find.byKey(const Key('wr_practice_step_done_pt-voice-3')),
        findsNothing,
      );

      await tester
          .tap(find.byKey(const Key('wr_practice_step_unlock_pt-voice-3')));
      await tester.pumpAndSettle();
      expect(find.text('Paywall practice_step'), findsOneWidget);
    });

    testWidgets('chủ đề đã khép không còn bấm hoàn thành được nữa', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll(
          'pt-voice',
          done: ['pt-voice-1'],
          completedAt: DateTime(2026, 7, 1),
        ),
      ]);

      await _pumpLarge(
        tester,
        _wrap(const WrPracticeThemeScreen(themeId: 'pt-voice'), intel: intel),
      );

      // Xong ba bước = xong giai đoạn làm quen, chủ đề chuyển sang duy trì —
      // không phải "đã hoàn thành" rồi thôi (spec Skill Formation).
      expect(find.text('ĐANG DUY TRÌ'), findsOneWidget);
      expect(find.text('Đánh dấu hoàn thành'), findsNothing);
      expect(find.byKey(const Key('wr_practice_maintain_block')),
          findsOneWidget);
      expect(
        find.byKey(const Key('wr_practice_maintain_pt-voice')),
        findsOneWidget,
      );
    });

    testWidgets('chưa ghi danh thì đọc được nội dung nhưng chưa bấm được', (
      tester,
    ) async {
      final intel = _twoThemes();

      await _pumpLarge(
        tester,
        _wrap(const WrPracticeThemeScreen(themeId: 'pt-voice'), intel: intel),
      );

      expect(find.text('CHƯA BẮT ĐẦU'), findsOneWidget);
      expect(find.text('Quan sát một tuần.'), findsOneWidget);
      expect(find.text('Đánh dấu hoàn thành'), findsNothing);
    });

    testWidgets('chủ đề không tồn tại thì báo rõ, không màn trắng', (
      tester,
    ) async {
      final intel = _twoThemes();

      await _pumpLarge(
        tester,
        _wrap(const WrPracticeThemeScreen(themeId: 'khong-co'), intel: intel),
      );

      expect(find.byKey(const Key('wr_practice_theme_gone')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'hoàn thành bước cuối khép chủ đề và ghi mảnh ký ức tương ứng',
      (tester) async {
        final intel = _twoThemes();
        final content = FakeWrContentRepository();
        // Chủ đề hai bước để bước cuối không phải bước Premium.
        intel.seedPracticeThemes([_theme('pt-mini', 'Chủ đề hai bước')]);
        intel.seedPracticeSteps('pt-mini', [
          _step('pt-mini-1', 'pt-mini', 1, 'Bước một'),
          _step('pt-mini-2', 'pt-mini', 2, 'Bước hai'),
        ]);
        intel.seedEnrollments([_enroll('pt-mini', done: ['pt-mini-1'])]);

        await _pumpLarge(
          tester,
          _wrap(
            const WrPracticeThemeScreen(themeId: 'pt-mini'),
            intel: intel,
            content: content,
          ),
        );

        await tester
            .tap(find.byKey(const Key('wr_practice_step_done_pt-mini-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('wr_practice_note_skip')));
        await tester.pumpAndSettle();

        expect(intel.completeThemeCalls, isNotEmpty);
        expect(
          content.insertMemoryEventCalls.map((e) => e.behavior),
          contains('practice_theme_done'),
        );
      },
    );
  });
}
