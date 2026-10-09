// Tab Phát triển, màn chủ đề và hai màn mới theo mockup v47 (06/10/2026):
// thẻ cầu nối "Điều bạn từng viết", "Tự thêm" một chủ đề, "Ghi nhận một
// điều", và luồng chọn cách → lưu → "Tôi đã thử" → ghi chú ở màn chủ đề.
//
// Run: flutter test test/features/wr_growth_v47_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_career_memory_rules.dart';
import 'package:workreflection_mobile/core/logic/wr_practice_v47.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_add_practice_theme_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_learning_capture_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_practice_theme_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Khung test
// ─────────────────────────────────────────────────────────────────────────────

/// Router thật cho các màn v47; những đích còn lại là màn giả chỉ in tên, đủ
/// để biết bấm có dẫn đúng chỗ không.
GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/base',
      builder: (_, __) => const Scaffold(body: Text('BASE')),
    ),
    GoRoute(path: '/wr/growth', builder: (_, __) => const WrGrowthScreen()),
    GoRoute(
      path: '/wr/growth/theme/:id',
      builder: (_, state) =>
          WrPracticeThemeScreen(themeId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/wr/growth/add-theme',
      builder: (_, __) => const WrAddPracticeThemeScreen(),
    ),
    GoRoute(
      path: '/wr/growth/learning',
      builder: (_, __) => const WrLearningCaptureScreen(),
    ),
    GoRoute(
      path: '/wr/paywall',
      builder: (_, state) => Scaffold(
        body: Text('PAYWALL ${state.uri.queryParameters['trigger'] ?? '-'}'),
      ),
    ),
    GoRoute(
      path: '/wr/growth/skills',
      builder: (_, __) => const Scaffold(body: Text('SKILLS')),
    ),
    GoRoute(
      path: '/wr/context-docs',
      builder: (_, __) => const Scaffold(body: Text('CONTEXT_DOCS')),
    ),
    GoRoute(
      path: '/wr/tra-chieu',
      builder: (_, __) => const Scaffold(body: Text('TRA_CHIEU')),
    ),
    GoRoute(
      path: '/wr/self-check',
      builder: (_, __) => const Scaffold(body: Text('SELF_CHECK')),
    ),
  ],
);

Widget _wrap(
  GoRouter router, {
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
  FakeWrEpisodeRepository? episodes,
}) {
  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(
        intel ?? FakeWrIntelligenceRepository(),
      ),
      wrContentRepositoryProvider.overrideWithValue(
        content ?? FakeWrContentRepository(),
      ),
      wrEpisodeRepositoryProvider.overrideWithValue(
        episodes ?? FakeWrEpisodeRepository(),
      ),
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

/// Khung cao để ListView dựng hết, khỏi phải cuộn trước mỗi lần bấm.
Future<void> _pumpTall(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

/// Bấm rồi chờ — kèm kiểm cú bấm có trúng không (bấm trượt mà test vẫn xanh
/// là test sai).
Future<void> _tap(WidgetTester tester, Finder f) async {
  expect(f, findsOneWidget);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Xổ dòng "Điều bạn đang thực hành" — mặc định thu gọn (họp khách 08/10).
Future<void> _expandThemes(WidgetTester tester) =>
    _tap(tester, find.byKey(const Key('wr_growth_themes_toggle')));

/// Bốn bước kiểu thư viện mới (migration 20261006120000): bước 4 Premium.
List<PracticeStep> _libSteps(String themeId) => [
  PracticeStep(
    stepId: '$themeId-1',
    themeId: themeId,
    stepOrder: 1,
    title: 'Nhận diện: Quan sát lúc muốn im lặng',
    content: 'Để ý xem lúc nào bạn định nói rồi thôi.',
    isPremium: false,
  ),
  PracticeStep(
    stepId: '$themeId-2',
    themeId: themeId,
    stepOrder: 2,
    title: 'Phần của tôi: Điều gì giữ bạn lại',
    isPremium: false,
  ),
  PracticeStep(
    stepId: '$themeId-3',
    themeId: themeId,
    stepOrder: 3,
    title: 'Chọn một cách: Nói một câu',
    isPremium: false,
  ),
  PracticeStep(
    stepId: '$themeId-4',
    themeId: themeId,
    stepOrder: 4,
    title: 'Mang về: Giữ lại một câu hỏi',
    isPremium: true,
  ),
];

PracticeEnrollment _enroll(
  String themeId, {
  List<String> done = const [],
  String? pendingChoice,
  DateTime? startedAt,
}) => PracticeEnrollment(
  userId: 'u1',
  themeId: themeId,
  completedSteps: done,
  pendingChoice: pendingChoice,
  startedAt: startedAt,
);

ReflectionEpisode _episode(
  String id, {
  required String situation,
  required DateTime openedAt,
  String? meaning,
}) => ReflectionEpisode(
  id: id,
  userId: 'u1',
  humanMoment: HumanMoment.confusion,
  state: ExperienceState.integrated,
  situationCode: situation,
  draftMeaning: meaning,
  openedAt: openedAt,
);

Future<PracticeEnrollment> _enrollmentOf(
  FakeWrIntelligenceRepository intel,
  String themeId,
) async => (await intel.fetchEnrollments(
  'u1',
)).firstWhere((e) => e.themeId == themeId);

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // Tab Phát triển
  // ───────────────────────────────────────────────────────────────────────────

  group('Tab Phát triển — thẻ cầu nối "Điều bạn từng viết"', () {
    testWidgets(
      'nhắc Insight gần nhất có chữ và mở chủ đề cùng chiều với tình huống đó',
      (tester) async {
        final content = FakeWrContentRepository()
          ..seedSituations(const [
            WrSituation(
              code: 'C-01',
              text: 'Bị ngắt lời trong họp',
              scaDimension: ScaDimension.c2,
              wave: 1,
            ),
            WrSituation(
              code: 'A-01',
              text: 'Quá tải việc',
              scaDimension: ScaDimension.a1,
              wave: 1,
            ),
          ]);
        final episodes = FakeWrEpisodeRepository()
          ..seed([
            // Mới nhất nhưng chưa viết gì → bỏ qua, lấy lần có chữ kế đó.
            _episode('e3', situation: 'A-01', openedAt: DateTime(2026, 10, 5)),
            _episode(
              'e2',
              situation: 'C-01',
              meaning: 'mình cần nói sớm hơn',
              openedAt: DateTime(2026, 10, 4),
            ),
            _episode(
              'e1',
              situation: 'A-01',
              meaning: 'mình ôm quá nhiều',
              openedAt: DateTime(2026, 10, 1),
            ),
          ]);
        final intel = FakeWrIntelligenceRepository()
          ..seedPracticeThemes(const [
            PracticeTheme(
              themeId: 'pt-a1',
              title: 'Nhịp làm việc',
              scaDimension: ScaDimension.a1,
            ),
            PracticeTheme(
              themeId: 'pt-c2',
              title: 'Dám lên tiếng',
              scaDimension: ScaDimension.c2,
            ),
          ])
          ..seedPracticeSteps('pt-a1', _libSteps('pt-a1'))
          ..seedPracticeSteps('pt-c2', _libSteps('pt-c2'))
          // pt-a1 đứng đầu danh sách: nút phải bỏ qua nó để tìm chủ đề cùng
          // chiều C2 với tình huống vừa viết.
          ..seedEnrollments([_enroll('pt-a1'), _enroll('pt-c2')]);

        await _pumpTall(
          tester,
          _wrap(
            _router('/wr/growth'),
            intel: intel,
            content: content,
            episodes: episodes,
          ),
        );

        expect(find.byKey(const Key('wr_growth_bridge')), findsOneWidget);
        final text = tester.widget<Text>(
          find.byKey(const Key('wr_growth_bridge_text')),
        );
        expect(
          text.textSpan!.toPlainText(),
          'Lần gần nhất bạn viết về “Bị ngắt lời trong họp”, bạn nhận ra: '
          'mình cần nói sớm hơn',
        );
        expect(
          find.text('Bạn muốn thử một cách khác trong lần tới?'),
          findsOneWidget,
        );

        final open = find.byKey(const Key('wr_growth_bridge_open'));
        expect(
          find.descendant(
            of: open,
            matching: find.text('Xem 3 cách để cân nhắc'),
          ),
          findsOneWidget,
        );
        await _tap(tester, open);

        expect(find.byType(WrPracticeThemeScreen), findsOneWidget);
        expect(find.text('Dám lên tiếng'), findsOneWidget);
      },
    );

    testWidgets('không có chủ đề cùng chiều thì mở chủ đề đang theo đầu tiên', (
      tester,
    ) async {
      final content = FakeWrContentRepository()
        ..seedSituations(const [
          WrSituation(
            code: 'S-01',
            text: 'Không rõ việc của mình',
            scaDimension: ScaDimension.s1,
            wave: 1,
          ),
        ]);
      final episodes = FakeWrEpisodeRepository()
        ..seed([
          _episode(
            'e1',
            situation: 'S-01',
            meaning: 'mình cần hỏi lại',
            openedAt: DateTime(2026, 10, 4),
          ),
        ]);
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(const [
          PracticeTheme(
            themeId: 'pt-a1',
            title: 'Nhịp làm việc',
            scaDimension: ScaDimension.a1,
          ),
          PracticeTheme(
            themeId: 'pt-c2',
            title: 'Dám lên tiếng',
            scaDimension: ScaDimension.c2,
          ),
        ])
        ..seedPracticeSteps('pt-a1', _libSteps('pt-a1'))
        ..seedPracticeSteps('pt-c2', _libSteps('pt-c2'))
        // pt-c2 đã đi hết giai đoạn làm quen → không còn là chủ đề "đang theo".
        ..seedEnrollments([
          PracticeEnrollment(
            userId: 'u1',
            themeId: 'pt-c2',
            completedAt: DateTime(2026, 9, 1),
          ),
          _enroll('pt-a1'),
        ]);

      await _pumpTall(
        tester,
        _wrap(
          _router('/wr/growth'),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      await _tap(tester, find.byKey(const Key('wr_growth_bridge_open')));
      expect(find.text('Nhịp làm việc'), findsOneWidget);
    });

    testWidgets(
      'nhánh "Điều khác" không có mã tình huống vẫn nhắc điều đã viết',
      (tester) async {
        final episodes = FakeWrEpisodeRepository()
          ..seed([
            _episode(
              'e1',
              situation: 'other',
              meaning: 'mình cần nghỉ một nhịp',
              openedAt: DateTime(2026, 10, 4),
            ),
          ]);

        await _pumpTall(
          tester,
          _wrap(_router('/wr/growth'), episodes: episodes),
        );

        final text = tester.widget<Text>(
          find.byKey(const Key('wr_growth_bridge_text')),
        );
        expect(
          text.textSpan!.toPlainText(),
          'Lần gần nhất bạn nhìn lại, bạn nhận ra: mình cần nghỉ một nhịp',
        );
        expect(
          find.text('Bạn muốn thử một cách khác trong lần tới?'),
          findsOneWidget,
        );
      },
    );

    testWidgets('chưa viết gì và chưa theo chủ đề nào: câu chung, không nút', (
      tester,
    ) async {
      await _pumpTall(tester, _wrap(_router('/wr/growth')));

      expect(find.byKey(const Key('wr_growth_bridge')), findsOneWidget);
      expect(find.byKey(const Key('wr_growth_bridge_text')), findsNothing);
      expect(
        find.textContaining('Những điều bạn từng nhìn lại có thể trở thành'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Khi một điều lặp lại đủ lâu'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_growth_bridge_open')), findsNothing);
    });

    testWidgets('mặc định mở đủ, bấm vào thì thu còn một dòng trích', (
      tester,
    ) async {
      final episodes = FakeWrEpisodeRepository()
        ..seed([
          _episode(
            'e1',
            situation: 'other',
            meaning: 'mình cần nghỉ một nhịp',
            openedAt: DateTime(2026, 10, 4),
          ),
        ]);
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(const [
          PracticeTheme(themeId: 'pt-1', title: 'Chủ đề một'),
        ])
        ..seedPracticeSteps('pt-1', _libSteps('pt-1'))
        ..seedEnrollments([_enroll('pt-1')]);

      await _pumpTall(
        tester,
        _wrap(_router('/wr/growth'), intel: intel, episodes: episodes),
      );

      Text quote() =>
          tester.widget<Text>(find.byKey(const Key('wr_growth_bridge_text')));
      expect(quote().maxLines, isNull);
      expect(find.byKey(const Key('wr_growth_bridge_open')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('wr_growth_bridge')));
      expect(quote().maxLines, 1);
      expect(
        find.text('Bạn muốn thử một cách khác trong lần tới?'),
        findsNothing,
      );
      expect(find.byKey(const Key('wr_growth_bridge_open')), findsNothing);
    });
  });

  group('Tab Phát triển — Tự thêm, Ghi nhận, quota, lối rẽ', () {
    FakeWrIntelligenceRepository twoActive({bool premium = false}) {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(const [
          PracticeTheme(themeId: 'pt-1', title: 'Chủ đề một'),
          PracticeTheme(themeId: 'pt-2', title: 'Chủ đề hai'),
        ])
        ..seedPracticeSteps('pt-1', _libSteps('pt-1'))
        ..seedPracticeSteps('pt-2', _libSteps('pt-2'))
        ..seedEnrollments([_enroll('pt-1'), _enroll('pt-2')]);
      if (premium) {
        intel.seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        );
      }
      return intel;
    }

    testWidgets('Free hết 2 chỗ: thẻ Tự thêm dẫn sang paywall practice_limit', (
      tester,
    ) async {
      await _pumpTall(tester, _wrap(_router('/wr/growth'), intel: twoActive()));

      await _tap(tester, find.byKey(const Key('wr_growth_add_theme')));
      expect(find.text('PAYWALL practice_limit'), findsOneWidget);
      expect(find.byType(WrAddPracticeThemeScreen), findsNothing);
    });

    testWidgets('Free còn chỗ: thẻ Tự thêm mở form tự thêm', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(const [
          PracticeTheme(themeId: 'pt-1', title: 'Chủ đề một'),
        ])
        ..seedPracticeSteps('pt-1', _libSteps('pt-1'))
        ..seedEnrollments([_enroll('pt-1')]);

      await _pumpTall(tester, _wrap(_router('/wr/growth'), intel: intel));

      await _tap(tester, find.byKey(const Key('wr_growth_add_theme')));
      expect(find.byType(WrAddPracticeThemeScreen), findsOneWidget);
    });

    testWidgets('Premium không có trần: Tự thêm mở form, không thẻ quota', (
      tester,
    ) async {
      await _pumpTall(
        tester,
        _wrap(_router('/wr/growth'), intel: twoActive(premium: true)),
      );

      expect(find.byKey(const Key('wr_growth_quota_card')), findsNothing);
      expect(find.text('Premium: không giới hạn'), findsNothing);

      await _tap(tester, find.byKey(const Key('wr_growth_add_theme')));
      expect(find.byType(WrAddPracticeThemeScreen), findsOneWidget);
    });

    testWidgets('Free thấy dòng quota, không còn badge x/y cạnh tiêu đề', (
      tester,
    ) async {
      await _pumpTall(tester, _wrap(_router('/wr/growth'), intel: twoActive()));

      final quota = find.byKey(const Key('wr_growth_quota_card'));
      expect(
        find.descendant(
          of: quota,
          matching: find.text('Free: tối đa 2 chủ đề cùng lúc'),
        ),
        findsOneWidget,
      );
      expect(find.text('2/2'), findsNothing);
      expect(find.text('CHỦ ĐỀ CỦA BẠN'), findsNothing);

      await _tap(tester, quota);
      expect(find.text('PAYWALL practice_limit'), findsOneWidget);
    });

    testWidgets('chủ đề tự thêm trùng tên chủ đề thư viện vẫn có thẻ riêng', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(const [
          PracticeTheme(themeId: 'pt-c2', title: 'Dám lên tiếng'),
          PracticeTheme(
            themeId: 'u-1',
            title: 'Dám lên tiếng',
            source: PracticeThemeSource.user,
            ownerId: 'u1',
          ),
        ])
        ..seedPracticeSteps('pt-c2', _libSteps('pt-c2'))
        ..seedPracticeSteps('u-1', _libSteps('u-1'))
        ..seedEnrollments([_enroll('pt-c2'), _enroll('u-1')]);

      await _pumpTall(tester, _wrap(_router('/wr/growth'), intel: intel));
      await _expandThemes(tester);

      expect(
        find.byKey(const Key('wr_growth_theme_card_pt-c2')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_growth_theme_card_u-1')), findsOneWidget);
    });

    testWidgets('họp 08/10: bỏ "Ghi nhận một điều", đổi tên dòng thêm chủ đề', (
      tester,
    ) async {
      await _pumpTall(tester, _wrap(_router('/wr/growth')));

      expect(find.byKey(const Key('wr_growth_learning_card')), findsNothing);
      expect(find.text('GHI NHẬN MỘT ĐIỀU'), findsNothing);
      expect(find.text('TỰ THÊM'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('wr_growth_add_theme')),
          matching: find.text('Thêm một chủ đề chưa có trong thư viện'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Điều bạn đang thực hành" thu gọn sẵn, bấm mới xổ chủ đề', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(const [
          PracticeTheme(themeId: 'pt-1', title: 'Chủ đề một'),
        ])
        ..seedPracticeSteps('pt-1', _libSteps('pt-1'))
        ..seedEnrollments([_enroll('pt-1')]);

      await _pumpTall(tester, _wrap(_router('/wr/growth'), intel: intel));

      expect(find.text('Điều bạn đang thử'), findsNothing);
      expect(find.byKey(const Key('wr_growth_theme_card_pt-1')), findsNothing);
      await _expandThemes(tester);
      expect(
        find.byKey(const Key('wr_growth_theme_card_pt-1')),
        findsOneWidget,
      );
    });

    testWidgets('dòng Cập nhật bối cảnh công việc mở màn JD/CV', (
      tester,
    ) async {
      await _pumpTall(tester, _wrap(_router('/wr/growth')));

      expect(find.text('Cập nhật bối cảnh công việc'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('wr_growth_context_docs_row')));
      expect(find.text('CONTEXT_DOCS'), findsOneWidget);
    });

    testWidgets('dòng Kỹ năng của bạn vẫn còn', (tester) async {
      await _pumpTall(tester, _wrap(_router('/wr/growth')));

      await _tap(tester, find.byKey(const Key('wr_growth_skills_row')));
      expect(find.text('SKILLS'), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Tự thêm chủ đề
  // ───────────────────────────────────────────────────────────────────────────

  group('WrAddPracticeThemeScreen', () {
    FilledButton createButton(WidgetTester tester) => tester
        .widget<FilledButton>(find.byKey(const Key('wr_add_theme_create')));

    testWidgets('nút Tạo chủ đề chỉ bật khi đủ ba câu bắt buộc', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      await _pumpTall(
        tester,
        _wrap(_router('/wr/growth/add-theme'), intel: intel),
      );

      expect(createButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('wr_add_theme_name')),
        'Phản hồi hiệu quả',
      );
      await tester.pump();
      expect(createButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('wr_add_theme_situation')),
        'Mỗi khi góp ý, tôi vòng vo.',
      );
      await tester.pump();
      expect(createButton(tester).onPressed, isNull);

      // "Đã thử" không bắt buộc: điền nó cũng chưa đủ.
      await tester.enterText(
        find.byKey(const Key('wr_add_theme_tried')),
        'Góp ý ngay trong họp.',
      );
      await tester.pump();
      expect(createButton(tester).onPressed, isNull);

      // Toàn khoảng trắng không tính là đã trả lời.
      await tester.enterText(find.byKey(const Key('wr_add_theme_goal')), '   ');
      await tester.pump();
      expect(createButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('wr_add_theme_goal')),
        'Nói rõ hơn',
      );
      await tester.pump();
      expect(createButton(tester).onPressed, isNotNull);
      expect(intel.createUserThemeCalls, isEmpty);
    });

    testWidgets('vào thẳng form khi Free đã hết 2 chỗ: dẫn sang paywall', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(const [
          PracticeTheme(themeId: 'pt-1', title: 'Chủ đề một'),
          PracticeTheme(themeId: 'pt-2', title: 'Chủ đề hai'),
        ])
        ..seedEnrollments([_enroll('pt-1'), _enroll('pt-2')]);
      final router = _router('/base');
      await _pumpTall(tester, _wrap(router, intel: intel));
      router.push('/wr/growth/add-theme');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('wr_add_theme_name')),
        'Phản hồi hiệu quả',
      );
      await tester.enterText(
        find.byKey(const Key('wr_add_theme_situation')),
        'Mỗi khi góp ý, tôi vòng vo.',
      );
      await tester.enterText(
        find.byKey(const Key('wr_add_theme_goal')),
        'Nói rõ hơn',
      );
      await tester.pump();
      await _tap(tester, find.byKey(const Key('wr_add_theme_create')));

      expect(find.text('PAYWALL practice_limit'), findsOneWidget);
      expect(intel.createUserThemeCalls, isEmpty);
    });

    testWidgets(
      'Tạo chủ đề ghi chủ đề + 4 bước + 3 cách rồi mở màn chủ đề vừa tạo',
      (tester) async {
        final intel = FakeWrIntelligenceRepository();
        final router = _router('/base');
        await _pumpTall(tester, _wrap(router, intel: intel));
        router.push('/wr/growth/add-theme');
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('wr_add_theme_name')),
          '  Phản hồi hiệu quả ',
        );
        await tester.enterText(
          find.byKey(const Key('wr_add_theme_situation')),
          'Mỗi khi góp ý, tôi vòng vo.',
        );
        await tester.enterText(
          find.byKey(const Key('wr_add_theme_goal')),
          'Nói rõ hơn mà không làm ai phòng thủ',
        );
        await tester.pump();
        await _tap(tester, find.byKey(const Key('wr_add_theme_create')));

        expect(intel.createUserThemeCalls, hasLength(1));
        final call = intel.createUserThemeCalls.single;
        final theme = call.theme;
        final id = theme.themeId;
        expect(theme.title, 'Phản hồi hiệu quả');
        expect(theme.source, PracticeThemeSource.user);
        expect(theme.isUserAdded, isTrue);
        expect(theme.ownerId, 'u1');
        expect(theme.intake?.situation, 'Mỗi khi góp ý, tôi vòng vo.');
        expect(theme.intake?.goal, 'Nói rõ hơn mà không làm ai phòng thủ');
        // Bỏ trống "Đã thử" thì không ghi một chuỗi rỗng.
        expect(theme.intake?.tried, isNull);
        expect(theme.mentorOptions.map((o) => o.id), [
          'small',
          'reframe',
          'observe',
        ]);

        expect(call.steps.map((s) => s.stepId), [
          '$id-1',
          '$id-2',
          '$id-3',
          '$id-4',
        ]);
        expect(call.steps.map((s) => s.stepOrder), [1, 2, 3, 4]);
        expect(call.steps.every((s) => s.themeId == id), isTrue);
        // Chỉ bước "Mang về" là Premium, như bộ 4 bước của thư viện.
        expect(call.steps.map((s) => s.isPremium), [false, false, false, true]);

        // pushReplacement: mở màn chủ đề, form không còn trong ngăn xếp.
        expect(router.state.uri.path, '/wr/growth/theme/$id');
        expect(find.byType(WrPracticeThemeScreen), findsOneWidget);
        expect(find.byType(WrAddPracticeThemeScreen), findsNothing);
        expect(find.text('Phản hồi hiệu quả'), findsOneWidget);
        expect(find.byKey(const Key('wr_practice_intake')), findsOneWidget);
        expect(
          find.byKey(const Key('wr_practice_option_small')),
          findsOneWidget,
        );

        await _tap(tester, find.byKey(const Key('wr_practice_back')));
        expect(find.text('BASE'), findsOneWidget);
      },
    );

    testWidgets('điền cả "Đã thử" thì nó đi theo vào intake', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      await _pumpTall(
        tester,
        _wrap(_router('/wr/growth/add-theme'), intel: intel),
      );

      await tester.enterText(find.byKey(const Key('wr_add_theme_name')), 'A');
      await tester.enterText(
        find.byKey(const Key('wr_add_theme_situation')),
        'B',
      );
      await tester.enterText(find.byKey(const Key('wr_add_theme_goal')), 'C');
      await tester.enterText(
        find.byKey(const Key('wr_add_theme_tried')),
        'Đã thử nói thẳng',
      );
      await tester.pump();
      await _tap(tester, find.byKey(const Key('wr_add_theme_create')));

      final call = intel.createUserThemeCalls.single;
      expect(call.theme.intake?.tried, 'Đã thử nói thẳng');
      // Họp khách 05/10: điều đã thử mà không có kết quả không được gợi ý lại.
      // "nói" cùng hướng với "Đưa người khác vào cuộc" nên cách đó không có.
      expect(call.theme.mentorOptions.map((o) => o.id), [
        'reframe',
        'small',
        'observe',
      ]);
      expect(
        call.theme.mentorOptions.first.fit,
        contains('"Đã thử nói thẳng"'),
      );
      expect(call.steps[2].content, contains('đừng lặp lại'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Ghi nhận một điều
  // ───────────────────────────────────────────────────────────────────────────

  group('WrLearningCaptureScreen', () {
    testWidgets('Lưu bài học ghi một Cột mốc P-08 rồi cho quay lại', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      final router = _router('/base');
      await _pumpTall(tester, _wrap(router, content: content));
      router.push('/wr/growth/learning');
      await tester.pumpAndSettle();

      FilledButton save() => tester.widget<FilledButton>(
        find.byKey(const Key('wr_learning_save')),
      );
      expect(save().onPressed, isNull);

      await tester.enterText(find.byKey(const Key('wr_learning_field')), '   ');
      await tester.pump();
      expect(save().onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('wr_learning_field')),
        ' Gửi brief sớm giúp ít phải sửa lại. ',
      );
      await tester.pump();
      expect(save().onPressed, isNotNull);

      await _tap(tester, find.byKey(const Key('wr_learning_save')));

      expect(content.insertMemoryEventCalls, hasLength(1));
      final event = content.insertMemoryEventCalls.single;
      expect(event.behavior, kLearningBehavior);
      expect(event.situationCode, kLearningSituationCode);
      expect(event.situationCode, 'P-08');
      expect(event.userId, 'u1');
      expect(event.reflectionText, 'Gửi brief sớm giúp ít phải sửa lại.');

      expect(find.byKey(const Key('wr_learning_saved')), findsOneWidget);
      expect(find.byKey(const Key('wr_learning_memory')), findsOneWidget);
      expect(find.text('Gửi brief sớm giúp ít phải sửa lại.'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('wr_learning_done')));
      expect(find.text('BASE'), findsOneWidget);
      expect(find.byType(WrLearningCaptureScreen), findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Màn chủ đề — chọn cách, lưu, thử, ghi chú
  // ───────────────────────────────────────────────────────────────────────────

  group('Màn chủ đề v47', () {
    FakeWrIntelligenceRepository library({String? pendingChoice}) =>
        FakeWrIntelligenceRepository()
          ..seedPracticeThemes(const [
            PracticeTheme(
              themeId: 'pt-c2',
              title: 'Dám lên tiếng',
              description: 'Bạn từng im lặng trong cuộc họp.',
            ),
          ])
          ..seedPracticeSteps('pt-c2', _libSteps('pt-c2'))
          ..seedEnrollments([
            _enroll(
              'pt-c2',
              startedAt: DateTime(2026, 10, 2),
              pendingChoice: pendingChoice,
            ),
          ]);

    testWidgets(
      'đầu màn: nguồn, Giai đoạn, Điều bạn từng viết, Bước tiếp theo',
      (tester) async {
        await _pumpTall(
          tester,
          _wrap(_router('/wr/growth/theme/pt-c2'), intel: library()),
        );

        expect(find.text('TỪ REFLECTION · 02/10'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('wr_practice_theme_progress')),
            matching: find.text('Giai đoạn 1/4'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('wr_practice_written')),
            matching: find.text('Bạn từng im lặng trong cuộc họp.'),
          ),
          findsOneWidget,
        );
        // Chủ đề thư viện không có khối "Thông tin bạn đã thêm".
        expect(find.byKey(const Key('wr_practice_intake')), findsNothing);
        expect(find.text('BƯỚC TIẾP THEO'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('wr_practice_next_step')))
              .data,
          'Quan sát lúc muốn im lặng',
        );
        // Chưa có mentor_options riêng → bộ ba cách chung.
        for (final id in ['try', 'observe', 'talk']) {
          expect(find.byKey(Key('wr_practice_option_$id')), findsOneWidget);
        }
        // Chưa chọn thì chưa có thẻ "Cách bạn chọn".
        expect(find.byKey(const Key('wr_practice_choice')), findsNothing);
        expect(find.text('Bạn đang cân nhắc cách này'), findsNothing);
      },
    );

    testWidgets(
      'chọn cách → lưu → Tôi đã thử → ghi chú: Cột mốc mới, rồi Đã ghi nhận',
      (tester) async {
        final intel = library();
        final content = FakeWrContentRepository();
        await _pumpTall(
          tester,
          _wrap(
            _router('/wr/growth/theme/pt-c2'),
            intel: intel,
            content: content,
          ),
        );

        // 1. Chọn "Quan sát thêm một lần".
        final observe = find.byKey(const Key('wr_practice_option_observe'));
        await _tap(tester, observe);
        expect(
          find.descendant(
            of: observe,
            matching: find.text('Bạn đang cân nhắc cách này'),
          ),
          findsOneWidget,
        );
        final choice = find.byKey(const Key('wr_practice_choice'));
        expect(
          find.descendant(
            of: choice,
            matching: find.text('Quan sát thêm một lần'),
          ),
          findsOneWidget,
        );
        // Chọn chưa phải lưu: chưa ghi gì xuống DB.
        expect((await _enrollmentOf(intel, 'pt-c2')).pendingChoice, isNull);

        // 2. Lưu cách muốn thử.
        await _tap(tester, find.byKey(const Key('wr_practice_save_choice')));
        expect(
          (await _enrollmentOf(intel, 'pt-c2')).pendingChoice,
          'Quan sát thêm một lần',
        );
        expect(find.byKey(const Key('wr_practice_save_choice')), findsNothing);
        expect(
          find.byKey(const Key('wr_practice_choice_saved')),
          findsOneWidget,
        );

        // 3. "Tôi đã thử" mở ô ghi chú ở đúng bước kế tiếp.
        await _tap(tester, find.byKey(const Key('wr_practice_tried')));
        expect(
          find.byKey(const Key('wr_practice_writer_pt-c2-1')),
          findsOneWidget,
        );
        // Ô trống thì "Lưu lại" tắt.
        expect(
          tester
              .widget<FilledButton>(
                find.descendant(
                  of: find.byKey(const Key('wr_practice_note_save')),
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNull,
        );

        await tester.enterText(
          find.byKey(const Key('wr_practice_note_field')),
          'Mình ngồi im nhưng đã thấy rõ lúc muốn nói.',
        );
        await tester.pump();
        await _tap(tester, find.byKey(const Key('wr_practice_note_save')));

        // Bước đã xong, ghi chú hiện ngay trong hàng bước.
        expect(intel.updateEnrollmentStepsCalls.single.completedSteps, [
          'pt-c2-1',
        ]);
        final row1 = find.byKey(const Key('wr_practice_step_pt-c2-1'));
        expect(
          find.descendant(of: row1, matching: find.text('Bạn đã ghi lại')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row1,
            matching: find.text(
              '“Mình ngồi im nhưng đã thấy rõ lúc muốn nói.”',
            ),
          ),
          findsOneWidget,
        );
        // Ghi chú mang theo cách đã chọn.
        expect(
          intel.upsertPracticeStepNoteCalls.single.choice,
          'Quan sát thêm một lần',
        );

        // Lần đầu thử một bước của chủ đề = Cột mốc mới.
        final notice = find.byKey(const Key('wr_practice_notice'));
        expect(
          find.descendant(of: notice, matching: find.text('CỘT MỐC MỚI')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: notice,
            matching: find.text('Quan sát lúc muốn im lặng'),
          ),
          findsOneWidget,
        );
        final milestones = content.insertMemoryEventCalls
            .where((e) => e.behavior == kMilestoneBehavior)
            .toList();
        expect(milestones, hasLength(1));
        expect(milestones.single.themeId, 'pt-c2');
        expect(milestones.single.reflectionText, 'Dám lên tiếng');

        // Cách đã lưu xong nhiệm vụ → xoá.
        expect((await _enrollmentOf(intel, 'pt-c2')).pendingChoice, isNull);
        expect(find.byKey(const Key('wr_practice_choice')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('wr_practice_theme_progress')),
            matching: find.text('Giai đoạn 2/4'),
          ),
          findsOneWidget,
        );

        // 4. Bước thứ hai, chỉ đánh dấu: "Đã ghi nhận", không thêm Cột mốc.
        await _tap(
          tester,
          find.byKey(const Key('wr_practice_step_done_pt-c2-2')),
        );
        await _tap(tester, find.byKey(const Key('wr_practice_note_skip')));

        expect(intel.updateEnrollmentStepsCalls.last.completedSteps, [
          'pt-c2-1',
          'pt-c2-2',
        ]);
        expect(
          find.descendant(of: notice, matching: find.text('ĐÃ GHI NHẬN')),
          findsOneWidget,
        );
        expect(find.text('CỘT MỐC MỚI'), findsNothing);
        expect(
          content.insertMemoryEventCalls.where(
            (e) => e.behavior == kMilestoneBehavior,
          ),
          hasLength(1),
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('wr_practice_step_pt-c2-2')),
            matching: find.text('Đã đánh dấu, bạn không ghi chú gì lần này.'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'chạm chọn một cách mà chưa lưu thì ghi chú không ghi cách đó',
      (tester) async {
        final intel = library();
        await _pumpTall(
          tester,
          _wrap(_router('/wr/growth/theme/pt-c2'), intel: intel),
        );

        await _tap(tester, find.byKey(const Key('wr_practice_option_observe')));
        await _tap(
          tester,
          find.byKey(const Key('wr_practice_step_done_pt-c2-1')),
        );
        await tester.enterText(
          find.byKey(const Key('wr_practice_note_field')),
          'Tôi đã để ý.',
        );
        await tester.pump();
        await _tap(tester, find.byKey(const Key('wr_practice_note_save')));

        expect(intel.upsertPracticeStepNoteCalls, hasLength(1));
        expect(intel.upsertPracticeStepNoteCalls.single.choice, isNull);
      },
    );

    testWidgets('cách đã lưu từ trước được chọn sẵn khi mở lại màn', (
      tester,
    ) async {
      await _pumpTall(
        tester,
        _wrap(
          _router('/wr/growth/theme/pt-c2'),
          intel: library(pendingChoice: 'Đưa người khác vào cuộc'),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('wr_practice_option_talk')),
          matching: find.text('Bạn đang cân nhắc cách này'),
        ),
        findsOneWidget,
      );
      expect(find.text('Bạn đang cân nhắc cách này'), findsOneWidget);
      expect(find.byKey(const Key('wr_practice_choice_saved')), findsOneWidget);
      expect(find.byKey(const Key('wr_practice_tried')), findsOneWidget);
      expect(find.byKey(const Key('wr_practice_save_choice')), findsNothing);
    });

    testWidgets(
      'chủ đề tự thêm: nguồn Bạn thêm, ngày bắt đầu, thông tin đã thêm',
      (tester) async {
        const intake = PracticeIntake(
          situation: 'Mỗi khi góp ý, tôi vòng vo.',
          goal: 'Nói rõ hơn',
          tried: 'Góp ý ngay trong họp',
        );
        final intel = FakeWrIntelligenceRepository()
          ..seedPracticeThemes([
            PracticeTheme(
              themeId: 'u-1',
              title: 'Phản hồi hiệu quả',
              source: PracticeThemeSource.user,
              ownerId: 'u1',
              intake: intake,
              mentorOptions: buildUserThemeMentorOptions('Nói rõ hơn'),
            ),
          ])
          ..seedPracticeSteps(
            'u-1',
            buildUserPracticeSteps(themeId: 'u-1', intake: intake),
          )
          ..seedEnrollments([_enroll('u-1', startedAt: DateTime(2026, 6, 8))]);

        await _pumpTall(
          tester,
          _wrap(_router('/wr/growth/theme/u-1'), intel: intel),
        );

        expect(find.text('BẠN THÊM · 08/06'), findsOneWidget);
        expect(find.text('Bạn bắt đầu chủ đề này từ 08/06.'), findsOneWidget);
        final block = find.byKey(const Key('wr_practice_intake'));
        for (final t in [
          'Đang xảy ra',
          'Mỗi khi góp ý, tôi vòng vo.',
          'Bạn muốn khác đi',
          'Nói rõ hơn',
          'Đã thử',
          'Góp ý ngay trong họp',
        ]) {
          expect(
            find.descendant(of: block, matching: find.text(t)),
            findsOneWidget,
            reason: t,
          );
        }
        for (final id in ['small', 'reframe', 'observe']) {
          expect(find.byKey(Key('wr_practice_option_$id')), findsOneWidget);
        }
        // Bước "Mang về" Premium khoá với bản miễn phí.
        expect(
          find.byKey(const Key('wr_practice_step_unlock_u-1-4')),
          findsOneWidget,
        );
      },
    );
  });
}
