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
        path: '/wr/growth/stance-keep',
        builder: (_, __) => const Scaffold(body: Text('StanceKeep')),
      ),
      GoRoute(
        path: '/wr/practice-options/:themeId',
        builder: (_, __) => const Scaffold(body: Text('StepOptions')),
      ),
      GoRoute(
        path: '/wr/growth/add-theme',
        builder: (_, __) => const Scaffold(body: Text('AddTheme')),
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

/// Mọi dòng chủ đề trong khối "Đang làm quen" của tab Phát triển (script
/// Sprint 2 `rowLearn`: tên, "Bước n / 4" hoặc "Chưa bắt đầu", bốn vạch).
final Finder _themeRows = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('wr_growth_theme_row_'),
);

Key _row(String id) => Key('wr_growth_theme_row_$id');

/// Mọi nút "Tôi đã thử bước này" trên màn chủ đề.
final Finder _stepDoneButtons = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('wr_practice_step_done_'),
);

PracticeTheme _theme(String id, String title) =>
    PracticeTheme(themeId: id, title: title);

PracticeStep _step(
  String id,
  String themeId,
  int order,
  String title, {
  bool premium = false,
  String? content,
}) => PracticeStep(
  stepId: id,
  themeId: themeId,
  stepOrder: order,
  title: title,
  isPremium: premium,
  content: content,
);

PracticeEnrollment _enroll(
  String themeId, {
  List<String> done = const [],
  DateTime? completedAt,
  DateTime? startedAt,
  String? pendingChoice,
}) => PracticeEnrollment(
  userId: 'u1',
  themeId: themeId,
  completedSteps: done,
  completedAt: completedAt,
  startedAt: startedAt,
  pendingChoice: pendingChoice,
);

/// Hai chủ đề, mỗi chủ đề bốn bước, bước cuối Premium — đúng bộ 4 bước v47
/// (migration 20261006120000) với chữ của script Sprint 2.
FakeWrIntelligenceRepository _twoThemes() {
  final intel = FakeWrIntelligenceRepository();
  intel.seedPracticeThemes([
    _theme('pt-voice', 'Dám lên tiếng'),
    _theme('pt-rhythm', 'Nhịp làm việc ổn định'),
  ]);
  for (final t in ['pt-voice', 'pt-rhythm']) {
    intel.seedPracticeSteps(t, [
      _step(
        '$t-1',
        t,
        1,
        'Nhận diện: Quan sát lúc muốn im lặng',
        content: 'Quan sát một tuần.',
      ),
      _step(
        '$t-2',
        t,
        2,
        'Phần của tôi: Tách phần mình và phần bối cảnh',
        content: 'Điều gì thuộc quyền quyết định của bạn?',
      ),
      _step(
        '$t-3',
        t,
        3,
        'Chọn một cách: Chọn một cách rồi thử',
        content:
            'Mở phần gợi ý, chọn một cách, rồi thử trong một cuộc họp thật.',
      ),
      _step(
        '$t-4',
        t,
        4,
        'Câu hỏi cho lần sau: Điều bạn muốn hỏi lần tới',
        premium: true,
        content: 'Sau khi thử, bạn muốn mang theo câu hỏi nào cho lần sau?',
      ),
    ]);
  }
  return intel;
}

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // Tab Phát triển — danh sách chủ đề
  // ───────────────────────────────────────────────────────────────────────────

  group('Tab Phát triển — danh sách chủ đề', () {
    Finder inRow(String id, String text) =>
        find.descendant(of: find.byKey(_row(id)), matching: find.text(text));

    testWidgets('hiện đủ MỌI chủ đề đang thực hành, không riêng chủ đề đầu', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll('pt-voice', done: ['pt-voice-1']),
        _enroll('pt-rhythm'),
      ]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.text('ĐANG LÀM QUEN'), findsOneWidget);
      expect(find.byKey(_row('pt-voice')), findsOneWidget);
      expect(find.byKey(_row('pt-rhythm')), findsOneWidget);
      // Script `rowLearn`: "Bước ${d+1} / 4" là bước ĐANG LÀM; chưa xong bước
      // nào thì "Chưa bắt đầu".
      expect(inRow('pt-voice', 'Bước 2 / 4'), findsOneWidget);
      expect(inRow('pt-rhythm', 'Chưa bắt đầu'), findsOneWidget);
    });

    testWidgets('hai chủ đề trùng tên chỉ hiện một dòng', (tester) async {
      // Thư viện thật có `pt-voice` (đời đầu) và `pt-c2` cùng tên "Dám lên
      // tiếng". Ghi danh cả hai thì hai dòng hiện y hệt nhau, và vì bộ đếm nhận
      // sự kiện theo tên nên tiến độ cũng luôn trùng khít.
      final intel = FakeWrIntelligenceRepository();
      intel.seedPracticeThemes([
        _theme('pt-voice', 'Dám lên tiếng'),
        _theme('pt-c2', 'Dám lên tiếng'),
      ]);
      for (final t in ['pt-voice', 'pt-c2']) {
        intel.seedPracticeSteps(t, [_step('$t-1', t, 1, 'Nhận diện')]);
      }
      intel.seedEnrollments([
        _enroll('pt-voice', startedAt: DateTime(2026, 7, 1)),
        _enroll('pt-c2', startedAt: DateTime(2026, 8, 1)),
      ]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.text('Dám lên tiếng'), findsOneWidget);
      // Giữ chủ đề mới hơn — nội dung bước của nó là bản đang dùng.
      expect(find.byKey(_row('pt-c2')), findsOneWidget);
      expect(find.byKey(_row('pt-voice')), findsNothing);
    });

    // Script Sprint 2: hết bốn bước KHÔNG tự khép; chủ đề chỉ rời "Đang làm
    // quen" khi người dùng bấm "Đưa vào phần duy trì" (completed_at).
    testWidgets('đi hết bốn bước mà chưa đưa vào duy trì thì vẫn ở Đang làm '
        'quen, mời "Hết một vòng · Đưa vào phần duy trì"', (tester) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll(
          'pt-voice',
          done: ['pt-voice-1', 'pt-voice-2', 'pt-voice-3', 'pt-voice-4'],
        ),
      ]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      // Máy thật 13/10: "Bước 4 / 4" không nói cho người dùng biết còn một
      // lần bấm nữa mới sang Đang duy trì.
      expect(
        inRow('pt-voice', 'Hết một vòng · Đưa vào phần duy trì ›'),
        findsOneWidget,
      );
      expect(inRow('pt-voice', 'Bước 4 / 4'), findsNothing);
      expect(find.byKey(const Key('wr_growth_keeping')), findsNothing);
    });

    testWidgets('chủ đề đã đưa vào duy trì rời Đang làm quen, sang Đang duy '
        'trì', (tester) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll(
          'pt-voice',
          done: ['pt-voice-1', 'pt-voice-2', 'pt-voice-3', 'pt-voice-4'],
          completedAt: DateTime(2026, 7, 1),
        ),
        _enroll('pt-rhythm'),
      ]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.byKey(_row('pt-voice')), findsNothing);
      expect(find.byKey(_row('pt-rhythm')), findsOneWidget);
      expect(find.byKey(const Key('wr_growth_keeping')), findsOneWidget);
      expect(find.byKey(const Key('wr_keep_row_pt-voice')), findsOneWidget);
      // Khối duy trì nằm DƯỚI khối đang làm quen (thứ tự script).
      expect(
        tester.getTopLeft(find.byKey(_row('pt-rhythm'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('wr_keep_row_pt-voice'))).dy,
        ),
      );
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

      final moiNhat = tester.getTopLeft(find.byKey(_row('pt-rhythm')));
      final cuHon = tester.getTopLeft(find.byKey(_row('pt-voice')));
      expect(moiNhat.dy, lessThan(cuHon.dy));
    });

    testWidgets(
      'quá $kGrowthThemesPreview chủ đề thì phần dôi nằm sau Xem thêm',
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

        // Ba dòng mới nhất hiện sẵn, hai dòng cũ nhất nằm sau nút.
        expect(find.byKey(_row('pt-5')), findsOneWidget);
        expect(find.byKey(_row('pt-3')), findsOneWidget);
        expect(find.byKey(_row('pt-2')), findsNothing);
        expect(find.byKey(_row('pt-1')), findsNothing);
        // Script `actShowLearn`: "Xem thêm ${Math.min(3,moreLearn)} chủ đề".
        expect(find.text('Xem thêm 2 chủ đề'), findsOneWidget);

        await tester.tap(find.byKey(const Key('wr_growth_learn_more')));
        await tester.pumpAndSettle();

        // Không có chủ đề nào bị cắt mất — bấm là ra đủ cả năm.
        for (final id in ids) {
          expect(
            find.byKey(_row(id)),
            findsOneWidget,
            reason: '$id phải hiện sau khi xổ',
          );
        }
        expect(find.byKey(const Key('wr_growth_learn_more')), findsNothing);
      },
    );

    testWidgets('đúng $kGrowthThemesPreview chủ đề thì không có nút Xem thêm', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice'), _enroll('pt-rhythm')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(_themeRows, findsNWidgets(2));
      expect(find.byKey(const Key('wr_growth_learn_more')), findsNothing);
    });

    testWidgets('bấm dòng chủ đề mở màn chủ đề đó', (tester) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-rhythm')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      await tester.tap(find.byKey(_row('pt-rhythm')));
      await tester.pumpAndSettle();

      expect(find.byType(WrPracticeThemeScreen), findsOneWidget);
      expect(find.text('Nhịp làm việc ổn định'), findsWidgets);
      for (final id in [
        'pt-rhythm-1',
        'pt-rhythm-2',
        'pt-rhythm-3',
        'pt-rhythm-4',
      ]) {
        expect(find.byKey(Key('wr_practice_step_$id')), findsOneWidget);
      }
    });

    // Script Sprint 2 bỏ thẻ quota trên tab. Trần Free vẫn giữ: hết chỗ thì
    // lối "Chủ đề chưa có trong thư viện" dẫn sang paywall thay vì màn thêm.
    testWidgets('Free hết 2/2 chỗ: dòng thêm chủ đề dẫn sang paywall', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice'), _enroll('pt-rhythm')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.text('Chủ đề chưa có trong thư viện'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wr_growth_add_theme')));
      await tester.pumpAndSettle();
      expect(find.text('Paywall practice_limit'), findsOneWidget);
    });

    testWidgets('Free còn chỗ: dòng thêm chủ đề mở màn thêm', (tester) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      await tester.tap(find.byKey(const Key('wr_growth_add_theme')));
      await tester.pumpAndSettle();
      expect(find.text('AddTheme'), findsOneWidget);
    });

    testWidgets('Premium không có trần: hai chủ đề vẫn mở màn thêm', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice'), _enroll('pt-rhythm')]);
      intel.seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.textContaining('Free:'), findsNothing);
      await tester.tap(find.byKey(const Key('wr_growth_add_theme')));
      await tester.pumpAndSettle();
      expect(find.text('AddTheme'), findsOneWidget);
    });

    // Đã theo chủ đề rồi thì màn này không mời thêm chủ đề thư viện, kể cả
    // premium: chủ đề mới do phần mềm tự thêm khi đã tổng hợp đủ dữ liệu
    // (khách 2026-08-04).
    testWidgets('đã theo chủ đề thì không bày chủ đề thư viện chưa ghi danh', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice')]);
      intel.seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(find.byKey(_row('pt-voice')), findsOneWidget);
      expect(find.byKey(_row('pt-rhythm')), findsNothing);
    });

    testWidgets('chưa ghi danh chủ đề nào: không mời chủ đề thư viện '
        '(khách 04/8, chủ đề do phần mềm tự thêm)', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      final ids = ['pt-1', 'pt-2', 'pt-3', 'pt-4'];
      intel.seedPracticeThemes([for (final id in ids) _theme(id, 'Chủ đề $id')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      expect(_themeRows, findsNothing);
      expect(find.text('Chưa bắt đầu'), findsNothing);
      expect(find.text('ĐANG LÀM QUEN'), findsNothing);
      expect(find.byKey(const Key('wr_growth_learn_more')), findsNothing);
    });

    testWidgets('thư viện trống và chưa ghi danh thì không dựng khối rỗng', (
      tester,
    ) async {
      await _pumpLarge(
        tester,
        _wrap(const WrGrowthScreen(), intel: FakeWrIntelligenceRepository()),
      );

      expect(_themeRows, findsNothing);
      expect(find.text('ĐANG LÀM QUEN'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ghi danh trỏ tới chủ đề không còn trong thư viện thì bỏ qua', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-da-xoa')]);

      await _pumpLarge(tester, _wrap(const WrGrowthScreen(), intel: intel));

      // Không dòng rỗng, không văng lỗi, không dựng khối "Đang làm quen" trống.
      expect(_themeRows, findsNothing);
      expect(find.text('ĐANG LÀM QUEN'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Màn chủ đề
  // ───────────────────────────────────────────────────────────────────────────

  group('Màn chủ đề', () {
    Future<void> openTheme(
      WidgetTester tester,
      FakeWrIntelligenceRepository intel, {
      FakeWrContentRepository? content,
      String themeId = 'pt-voice',
    }) => _pumpLarge(
      tester,
      _wrap(
        WrPracticeThemeScreen(themeId: themeId),
        intel: intel,
        content: content,
      ),
    );

    Finder inStep(String stepId, Finder f) => find.descendant(
      of: find.byKey(Key('wr_practice_step_$stepId')),
      matching: f,
    );

    testWidgets('đầu màn: Đang thực hành, Bốn bước làm quen, n / 4', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll('pt-voice', done: ['pt-voice-1']),
      ]);
      await openTheme(tester, intel);

      expect(find.text('ĐANG THỰC HÀNH'), findsOneWidget);
      expect(find.text('BỐN BƯỚC LÀM QUEN'), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.text('ĐIỀU BẠN TỪNG VIẾT'), findsOneWidget);
      // Các khối v47 mà script không có đã bỏ.
      expect(find.text('BƯỚC TIẾP THEO'), findsNothing);
      expect(find.textContaining('Giai đoạn'), findsNothing);
      expect(find.text('Lưu cách tôi muốn thử'), findsNothing);
    });

    testWidgets('chỉ bước đang làm mở ra; bước sau một dòng, không mô tả', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll('pt-voice', done: ['pt-voice-1']),
      ]);
      await openTheme(tester, intel);

      // Bước đã xong: hậu tố "· đã thử", không nút.
      expect(
        inStep('pt-voice-1', find.text('NHẬN DIỆN · ĐÃ THỬ')),
        findsOneWidget,
      );
      // Bước đang làm: mô tả + nút.
      expect(
        inStep(
          'pt-voice-2',
          find.text('Điều gì thuộc quyền quyết định của bạn?'),
        ),
        findsOneWidget,
      );
      expect(_stepDoneButtons, findsOneWidget);
      expect(
        find.byKey(const Key('wr_practice_step_done_pt-voice-2')),
        findsOneWidget,
      );
      // Bước sau: chỉ tên việc.
      expect(
        inStep('pt-voice-3', find.text('Chọn một cách rồi thử')),
        findsOneWidget,
      );
      expect(
        inStep(
          'pt-voice-3',
          find.text(
            'Mở phần gợi ý, chọn một cách, rồi thử trong một cuộc họp thật.',
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('mỗi bước một câu hỏi riêng khi bấm Tôi đã thử bước này', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([_enroll('pt-voice')]);
      await openTheme(tester, intel);

      await tester.tap(
        find.byKey(const Key('wr_practice_step_done_pt-voice-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bạn để ý thấy gì?'), findsOneWidget);
      expect(find.text('Chỉ đánh dấu'), findsOneWidget);
      expect(find.byKey(const Key('wr_practice_note_later')), findsOneWidget);
    });

    testWidgets('bước 3 chưa chọn cách: chỉ có lối Xem ba cách gợi ý', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll('pt-voice', done: ['pt-voice-1', 'pt-voice-2']),
      ]);
      await openTheme(tester, intel);

      expect(find.byKey(const Key('wr_practice_open_options')), findsOneWidget);
      expect(find.text('Xem ba cách gợi ý'), findsOneWidget);
      // Ba cách KHÔNG xổ tại chỗ, và chưa đánh dấu được.
      expect(find.text('Đặt một câu hỏi nhỏ trước'), findsNothing);
      expect(_stepDoneButtons, findsNothing);

      await tester.tap(find.byKey(const Key('wr_practice_open_options')));
      await tester.pumpAndSettle();
      expect(find.text('StepOptions'), findsOneWidget);
    });

    testWidgets(
      'đã chọn cách: thẻ Cách bạn đang thử, thử xong thành "Thử: ‹cách›"',
      (tester) async {
        final intel = _twoThemes();
        final content = FakeWrContentRepository();
        intel.seedEnrollments([
          _enroll(
            'pt-voice',
            done: ['pt-voice-1', 'pt-voice-2'],
            pendingChoice: 'small',
          ),
        ]);
        await openTheme(tester, intel, content: content);

        final choice = find.byKey(const Key('wr_practice_choice'));
        expect(
          find.descendant(
            of: choice,
            matching: find.text('Đặt một câu hỏi nhỏ trước'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: choice,
            matching: find.text('✓ Cách bạn đang thử'),
          ),
          findsOneWidget,
        );
        expect(find.text('Tôi đã thử cách này'), findsOneWidget);
        expect(find.text('Đổi sang cách khác'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('wr_practice_step_done_pt-voice-3')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã thử như thế nào?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('wr_practice_note_field')),
          'Mình hỏi lại một câu.',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('wr_practice_note_save')));
        await tester.pumpAndSettle();

        expect(
          inStep('pt-voice-3', find.text('Thử: Đặt một câu hỏi nhỏ trước')),
          findsOneWidget,
        );
        expect(
          inStep('pt-voice-3', find.text('CHỌN MỘT CÁCH · ĐÃ THỬ')),
          findsOneWidget,
        );
        expect(
          intel.upsertPracticeStepNoteCalls.single.choice,
          'Đặt một câu hỏi nhỏ trước',
        );
      },
    );

    testWidgets('bước Premium hiện kèm nút mở khoá cho bản miễn phí', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEnrollments([
        _enroll('pt-voice', done: ['pt-voice-1', 'pt-voice-2', 'pt-voice-3']),
      ]);
      await openTheme(tester, intel);

      // §IV khoá cấp nội dung: vẫn thấy mình đang bỏ lỡ gì.
      expect(
        inStep('pt-voice-4', find.text('Điều bạn muốn hỏi lần tới')),
        findsOneWidget,
      );
      expect(
        inStep('pt-voice-4', find.text('CÂU HỎI CHO LẦN SAU')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wr_practice_step_unlock_pt-voice-4')),
        findsOneWidget,
      );
      // Và không có đường vòng để tự đánh dấu xong.
      expect(
        find.byKey(const Key('wr_practice_step_done_pt-voice-4')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('wr_practice_step_unlock_pt-voice-4')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Paywall practice_step'), findsOneWidget);
    });

    // Bước 4 khoá Premium với bản miễn phí. Đòi đủ bốn bước thì người dùng
    // miễn phí không bao giờ vào được phần duy trì.
    testWidgets(
      'miễn phí hết ba bước mở được: thẻ Hết một vòng → Đưa vào phần duy trì',
      (tester) async {
        final intel = _twoThemes();
        final content = FakeWrContentRepository();
        intel.seedEnrollments([
          _enroll('pt-voice', done: ['pt-voice-1', 'pt-voice-2', 'pt-voice-3']),
        ]);
        await openTheme(tester, intel, content: content);

        expect(find.byKey(const Key('wr_practice_round_done')), findsOneWidget);
        expect(find.text('HẾT MỘT VÒNG'), findsOneWidget);
        expect(find.text('Bạn vừa đi hết bốn bước'), findsOneWidget);
        expect(intel.completeThemeCalls, isEmpty);

        await tester.tap(find.byKey(const Key('wr_practice_move_to_keep')));
        await tester.pumpAndSettle();

        expect(intel.completeThemeCalls, hasLength(1));
        final milestone = content.insertMemoryEventCalls.singleWhere(
          (e) => e.behavior == 'career_milestone',
        );
        expect(milestone.reflectionText, 'Hết một vòng: Dám lên tiếng');
        expect(milestone.themeId, isNull);
        expect(find.text('StanceKeep'), findsOneWidget);
      },
    );

    testWidgets('đã đưa vào duy trì: thẻ Đang duy trì, không còn gì để bấm', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );
      intel.seedEnrollments([
        _enroll(
          'pt-voice',
          done: ['pt-voice-1', 'pt-voice-2', 'pt-voice-3', 'pt-voice-4'],
          completedAt: DateTime(2026, 7, 1),
        ),
      ]);
      await openTheme(tester, intel);

      expect(find.byKey(const Key('wr_practice_keeping')), findsOneWidget);
      expect(find.byKey(const Key('wr_practice_round_done')), findsNothing);
      expect(_stepDoneButtons, findsNothing);
    });

    testWidgets('nâng cấp Premium rồi thì bước cuối bấm được, dù đã duy trì', (
      tester,
    ) async {
      final intel = _twoThemes();
      intel.seedEntitlement(
        WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
      );
      intel.seedEnrollments([
        _enroll(
          'pt-voice',
          done: ['pt-voice-1', 'pt-voice-2', 'pt-voice-3'],
          completedAt: DateTime(2026, 7, 1),
        ),
      ]);
      await openTheme(tester, intel);

      // Khoá vĩnh viễn bước 4 chỉ vì hôm còn miễn phí đã khép chủ đề là ăn quỵt
      // đúng thứ người ta vừa trả tiền để mở.
      expect(
        find.byKey(const Key('wr_practice_step_done_pt-voice-4')),
        findsOneWidget,
      );
      expect(find.text('Ghi lại câu hỏi'), findsOneWidget);
    });

    testWidgets('chưa ghi danh thì đọc được nội dung nhưng chưa bấm được', (
      tester,
    ) async {
      final intel = _twoThemes();
      await openTheme(tester, intel);

      expect(
        inStep('pt-voice-1', find.text('Quan sát một tuần.')),
        findsOneWidget,
      );
      expect(_stepDoneButtons, findsNothing);
    });

    testWidgets('chủ đề không tồn tại thì báo rõ, không màn trắng', (
      tester,
    ) async {
      final intel = _twoThemes();
      await openTheme(tester, intel, themeId: 'khong-co');

      expect(find.byKey(const Key('wr_practice_theme_gone')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'bước cuối: Ghi lại câu hỏi · Chưa có; xong KHÔNG tự khép chủ đề',
      (tester) async {
        final intel = _twoThemes();
        final content = FakeWrContentRepository();
        // Chủ đề hai bước để bước cuối không phải bước Premium.
        intel.seedPracticeThemes([_theme('pt-mini', 'Chủ đề hai bước')]);
        intel.seedPracticeSteps('pt-mini', [
          _step('pt-mini-1', 'pt-mini', 1, 'Nhận diện: Bước một'),
          _step('pt-mini-2', 'pt-mini', 4, 'Câu hỏi cho lần sau: Bước hai'),
        ]);
        intel.seedEnrollments([
          _enroll('pt-mini', done: ['pt-mini-1']),
        ]);
        await openTheme(tester, intel, content: content, themeId: 'pt-mini');

        expect(find.text('Ghi lại câu hỏi'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('wr_practice_step_done_pt-mini-2')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Câu hỏi bạn muốn mang theo cho lần sau?'),
          findsOneWidget,
        );
        expect(find.text('Chưa có'), findsOneWidget);
        expect(
          find.text('Chưa nghĩ ra cũng không sao. Quay lại khi bạn nghĩ ra.'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('wr_practice_note_skip')));
        await tester.pumpAndSettle();

        // Script `moveToKeep`: người dùng tự đưa vào duy trì.
        expect(intel.completeThemeCalls, isEmpty);
        expect(
          content.insertMemoryEventCalls.map((e) => e.behavior),
          isNot(contains('practice_theme_done')),
        );
        expect(find.byKey(const Key('wr_practice_round_done')), findsOneWidget);
        expect(
          inStep('pt-mini-2', find.text('CÂU HỎI CHO LẦN SAU · ĐỂ SAU')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Premium đi nốt bước cuối không sinh thêm dòng "hoàn thành" thứ hai',
      (tester) async {
        final intel = _twoThemes();
        final content = FakeWrContentRepository();
        intel.seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        );
        // Đã đưa vào duy trì hồi còn miễn phí, giờ nâng cấp và đi nốt bước 4.
        intel.seedEnrollments([
          _enroll(
            'pt-voice',
            done: ['pt-voice-1', 'pt-voice-2', 'pt-voice-3'],
            completedAt: DateTime(2026, 7, 1),
          ),
        ]);
        await openTheme(tester, intel, content: content);

        await tester.tap(
          find.byKey(const Key('wr_practice_step_done_pt-voice-4')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('wr_practice_note_skip')));
        await tester.pumpAndSettle();

        expect(intel.completeThemeCalls, isEmpty);
        expect(
          content.insertMemoryEventCalls.map((e) => e.behavior),
          isNot(contains('practice_theme_done')),
        );
        expect(find.byKey(const Key('wr_practice_keeping')), findsOneWidget);
      },
    );
  });
}
