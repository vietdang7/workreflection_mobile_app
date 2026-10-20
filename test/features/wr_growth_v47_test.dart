// Tab Phát triển, màn chủ đề và hai màn mới theo mockup v47 (06/10/2026):
// thẻ cầu nối "Điều bạn từng viết", "Tự thêm" một chủ đề, "Ghi nhận một
// điều", và luồng chọn cách → lưu → "Tôi đã thử" → ghi chú ở màn chủ đề.
//
// Run: flutter test test/features/wr_growth_v47_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_ai_consent_repository.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_practice_suggest_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_ai_disclosure.dart';
import 'package:workreflection_mobile/core/logic/wr_career_memory_rules.dart';
import 'package:workreflection_mobile/core/logic/wr_practice_v47.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_add_practice_theme_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_learning_capture_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_practice_theme_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_step_options_screen.dart';
import 'package:workreflection_mobile/features/wr/ai_consent_providers.dart';
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
      path: '/wr/practice-options/:themeId',
      builder: (_, state) =>
          WrStepOptionsScreen(themeId: state.pathParameters['themeId']!),
    ),
    GoRoute(
      path: '/wr/growth/stance-keep',
      builder: (_, __) => const Scaffold(body: Text('STANCE_KEEP')),
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
      path: '/wr/job-context',
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

/// Gợi ý AI giả: trả đúng [result], ghi lại mỗi lần được gọi.
class _FakeSuggest implements WrPracticeSuggestRepository {
  _FakeSuggest([this.result = const PracticeAiSuggestion.none()]);

  final PracticeAiSuggestion result;
  final calls = <PracticeIntake>[];

  @override
  Future<PracticeAiSuggestion> suggest({
    required String title,
    required PracticeIntake intake,
  }) async {
    calls.add(intake);
    return result;
  }
}

/// Mặc định: người dùng đã TỪ CHỐI AI — tạo chủ đề đi đường bộ luật, đúng như
/// trước khi có lớp AI.
final _declined = WrAiConsent(
  version: kWrAiDisclosureVersion,
  revokedAt: DateTime(2026, 10, 1),
);
final _granted = WrAiConsent(
  version: kWrAiDisclosureVersion,
  grantedAt: DateTime(2026, 10, 1),
);

Widget _wrap(
  GoRouter router, {
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
  FakeWrEpisodeRepository? episodes,
  WrAiConsent? consent,
  WrPracticeSuggestRepository? suggest,
}) {
  return ProviderScope(
    overrides: [
      wrAiConsentProvider.overrideWith((ref) async => consent ?? _declined),
      wrPracticeSuggestRepositoryProvider.overrideWithValue(
        suggest ?? _FakeSuggest(),
      ),
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
    content: 'Mở phần gợi ý, chọn một cách, rồi thử trong một cuộc họp thật.',
    isPremium: false,
  ),
  PracticeStep(
    stepId: '$themeId-4',
    themeId: themeId,
    stepOrder: 4,
    title: 'Câu hỏi cho lần sau: Điều bạn muốn hỏi lần tới',
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

  // Script Sprint 2 (PR #48) bỏ thẻ cầu nối "Điều bạn từng viết" khỏi tab
  // Phát triển cùng toàn bộ logic chọn Insight của nó; năm test của thẻ đó đã
  // xoá theo.

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

    // Script Sprint 2 bỏ dòng quota trên tab; trần Free vẫn chặn ở dòng thêm
    // chủ đề (test "Free hết 2 chỗ" ở trên).
    testWidgets('không còn dòng quota, badge x/y hay tiêu đề CHỦ ĐỀ CỦA BẠN', (
      tester,
    ) async {
      await _pumpTall(tester, _wrap(_router('/wr/growth'), intel: twoActive()));

      expect(find.textContaining('Free: tối đa'), findsNothing);
      expect(find.text('2/2'), findsNothing);
      expect(find.text('CHỦ ĐỀ CỦA BẠN'), findsNothing);
      expect(find.text('ĐANG LÀM QUEN'), findsOneWidget);
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

      expect(
        find.byKey(const Key('wr_growth_theme_row_pt-c2')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_growth_theme_row_u-1')), findsOneWidget);
    });

    testWidgets('họp 08/10 + script: bỏ "Ghi nhận một điều", dòng thêm chủ '
        'đề theo chữ script', (tester) async {
      await _pumpTall(tester, _wrap(_router('/wr/growth')));

      expect(find.byKey(const Key('wr_growth_learning_card')), findsNothing);
      expect(find.text('GHI NHẬN MỘT ĐIỀU'), findsNothing);
      expect(find.text('TỰ THÊM'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('wr_growth_add_theme')),
          matching: find.text('Chủ đề chưa có trong thư viện'),
        ),
        findsOneWidget,
      );
    });

    // Script Sprint 2: khối "Đang làm quen" mở sẵn, không còn dòng xổ "Điều
    // bạn đang thực hành" của họp 08/10.
    testWidgets('"Đang làm quen" hiện sẵn chủ đề, không còn dòng xổ', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPracticeThemes(const [
          PracticeTheme(themeId: 'pt-1', title: 'Chủ đề một'),
        ])
        ..seedPracticeSteps('pt-1', _libSteps('pt-1'))
        ..seedEnrollments([_enroll('pt-1')]);

      await _pumpTall(tester, _wrap(_router('/wr/growth'), intel: intel));

      expect(find.byKey(const Key('wr_growth_themes_toggle')), findsNothing);
      expect(find.text('Điều bạn đang thực hành'), findsNothing);
      expect(find.byKey(const Key('wr_growth_theme_row_pt-1')), findsOneWidget);
      expect(
        find.text('Những chủ đề bạn đang đi qua bốn bước làm quen.'),
        findsOneWidget,
      );
    });

    testWidgets('dòng Bối cảnh công việc mở màn JD/CV', (tester) async {
      await _pumpTall(tester, _wrap(_router('/wr/growth')));

      expect(find.text('Bối cảnh công việc'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('wr_growth_context_docs_row')));
      expect(find.text('CONTEXT_DOCS'), findsOneWidget);
    });

    // Dòng "Kỹ năng của bạn" đã rời tab theo script Sprint 2 (PR #48); script
    // không có lối nào sang màn đó nên test lối vào đã xoá.
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
        // Chỉ bước "Câu hỏi cho lần sau" là Premium, như bộ 4 bước của thư viện.
        expect(call.steps.map((s) => s.isPremium), [false, false, false, true]);

        // pushReplacement: mở màn chủ đề, form không còn trong ngăn xếp.
        expect(router.state.uri.path, '/wr/growth/theme/$id');
        expect(find.byType(WrPracticeThemeScreen), findsOneWidget);
        expect(find.byType(WrAddPracticeThemeScreen), findsNothing);
        expect(find.text('Phản hồi hiệu quả'), findsOneWidget);
        // Script `practiceDetail`: chủ đề tự thêm trích lại câu tình huống.
        expect(find.text('TỰ THÊM'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('wr_practice_written')),
            matching: find.text('“Mỗi khi góp ý, tôi vòng vo.”'),
          ),
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
      // Script `buildPracticeSteps`: mô tả bước 3 không nhắc lại điều đã thử —
      // ba cách gợi ý ở trên đã tránh nó.
      expect(call.steps[2].content, isNot(contains('đừng lặp lại')));
      expect(call.steps[2].content, startsWith('Mở phần gợi ý, chọn một cách'));
    });

    Future<void> fillAndCreate(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('wr_add_theme_name')), 'A');
      await tester.enterText(
        find.byKey(const Key('wr_add_theme_situation')),
        'B',
      );
      await tester.enterText(find.byKey(const Key('wr_add_theme_goal')), 'C');
      await tester.enterText(
        find.byKey(const Key('wr_add_theme_tried')),
        'Im lặng chờ',
      );
      await tester.pump();
      await _tap(tester, find.byKey(const Key('wr_add_theme_create')));
    }

    testWidgets(
      'đã cho phép AI: ba cách AI qua đối soát + câu hỏi vào bước 4',
      (tester) async {
        final intel = FakeWrIntelligenceRepository();
        final suggest = _FakeSuggest(
          PracticeAiSuggestion.fromJson({
            'generated': true,
            'locale': 'vi',
            'options': [
              {
                'title': 'Im lặng chờ thêm lần nữa',
                'fit': 'f',
                'tradeoff': 't',
              },
              {'title': 'Xin hai phút cuối họp', 'fit': 'f', 'tradeoff': 't'},
              {'title': 'Gửi ghi chú trước', 'fit': 'f', 'tradeoff': 't'},
            ],
            'question': 'Điều gì giúp bạn nói trọn ý?',
          }),
        );
        await _pumpTall(
          tester,
          _wrap(
            _router('/wr/growth/add-theme'),
            intel: intel,
            consent: _granted,
            suggest: suggest,
          ),
        );
        await fillAndCreate(tester);

        expect(suggest.calls.single.tried, 'Im lặng chờ');
        final call = intel.createUserThemeCalls.single;
        final titles = call.theme.mentorOptions.map((o) => o.titleVi).toList();
        // Cách lặp lại điều đã thử bị loại; chỗ trống lấy từ bộ luật.
        expect(titles, hasLength(3));
        expect(titles.take(2), ['Xin hai phút cuối họp', 'Gửi ghi chú trước']);
        expect(titles, isNot(contains('Im lặng chờ thêm lần nữa')));
        expect(call.steps[3].content, contains('Điều gì giúp bạn nói trọn ý?'));
      },
    );

    testWidgets('đã cho phép AI nhưng AI không trả gì: vẫn tạo bằng bộ luật', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      final suggest = _FakeSuggest();
      await _pumpTall(
        tester,
        _wrap(
          _router('/wr/growth/add-theme'),
          intel: intel,
          consent: _granted,
          suggest: suggest,
        ),
      );
      await fillAndCreate(tester);

      expect(suggest.calls, hasLength(1));
      final call = intel.createUserThemeCalls.single;
      expect(
        call.theme.mentorOptions.map((o) => o.id),
        buildUserThemeMentorOptions('C', tried: 'Im lặng chờ').map((o) => o.id),
      );
      expect(call.steps[3].content, isNot(contains('Gợi ý:')));
    });

    testWidgets('đã từ chối AI: không gọi AI', (tester) async {
      final suggest = _FakeSuggest();
      await _pumpTall(
        tester,
        _wrap(_router('/wr/growth/add-theme'), suggest: suggest),
      );
      await fillAndCreate(tester);
      expect(suggest.calls, isEmpty);
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
    FakeWrIntelligenceRepository library({
      String? pendingChoice,
      List<String> done = const [],
    }) => FakeWrIntelligenceRepository()
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
          done: done,
          startedAt: DateTime(2026, 10, 2),
          pendingChoice: pendingChoice,
        ),
      ]);

    testWidgets('đầu màn: Đang thực hành, Điều bạn từng viết, 0 / 4', (
      tester,
    ) async {
      await _pumpTall(
        tester,
        _wrap(_router('/wr/growth/theme/pt-c2'), intel: library()),
      );

      expect(find.text('ĐANG THỰC HÀNH'), findsOneWidget);
      expect(find.text('0 / 4'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('wr_practice_written')),
          matching: find.text('Bạn từng im lặng trong cuộc họp.'),
        ),
        findsOneWidget,
      );
      // Các khối v47 script không có.
      expect(find.text('BƯỚC TIẾP THEO'), findsNothing);
      expect(find.byKey(const Key('wr_practice_intake')), findsNothing);
      expect(find.byKey(const Key('wr_practice_notice')), findsNothing);
      // Ba cách không xổ tại chỗ.
      expect(find.byKey(const Key('wr_practice_choice')), findsNothing);
      expect(find.text('Đặt một câu hỏi nhỏ trước'), findsNothing);
    });

    testWidgets('bước đầu: ghi chú → Cột mốc lần đầu, hậu tố đã thử', (
      tester,
    ) async {
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

      await _tap(
        tester,
        find.byKey(const Key('wr_practice_step_done_pt-c2-1')),
      );
      expect(
        find.byKey(const Key('wr_practice_writer_pt-c2-1')),
        findsOneWidget,
      );
      expect(find.text('Bạn để ý thấy gì?'), findsOneWidget);
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

      expect(intel.updateEnrollmentStepsCalls.single.completedSteps, [
        'pt-c2-1',
      ]);
      final row1 = find.byKey(const Key('wr_practice_step_pt-c2-1'));
      expect(
        find.descendant(of: row1, matching: find.text('NHẬN DIỆN · ĐÃ THỬ')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row1,
          matching: find.text('“Mình ngồi im nhưng đã thấy rõ lúc muốn nói.”'),
        ),
        findsOneWidget,
      );
      final milestones = content.insertMemoryEventCalls
          .where((e) => e.behavior == kMilestoneBehavior)
          .toList();
      expect(milestones, hasLength(1));
      expect(milestones.single.themeId, 'pt-c2');
      expect(milestones.single.reflectionText, 'Dám lên tiếng');
      expect(find.text('1 / 4'), findsOneWidget);

      // Bước hai, chỉ đánh dấu: không thêm Cột mốc.
      expect(
        find.text('Điều gì thuộc quyền quyết định của bạn?'),
        findsNothing,
      );
      await _tap(
        tester,
        find.byKey(const Key('wr_practice_step_done_pt-c2-2')),
      );
      expect(
        find.text('Điều gì thuộc quyền quyết định của bạn?'),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('wr_practice_note_skip')));
      expect(
        content.insertMemoryEventCalls.where(
          (e) => e.behavior == kMilestoneBehavior,
        ),
        hasLength(1),
      );
    });

    testWidgets('bước 3: Xem ba cách gợi ý → chọn → về màn chủ đề', (
      tester,
    ) async {
      final intel = library(done: ['pt-c2-1', 'pt-c2-2']);
      await _pumpTall(
        tester,
        _wrap(_router('/wr/growth/theme/pt-c2'), intel: intel),
      );

      await _tap(tester, find.byKey(const Key('wr_practice_open_options')));
      expect(find.byType(WrStepOptionsScreen), findsOneWidget);
      // STEP3_OPTIONS.t1 — không có dòng "Đánh đổi".
      for (final t in [
        'Đặt một câu hỏi nhỏ trước',
        'Quan sát thêm một lần',
        'Nói trước với một người',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.textContaining('Đánh đổi'), findsNothing);
      expect(find.text('Đang chọn'), findsNothing);
      // Chân trang là mô tả bước 3.
      expect(find.byKey(const Key('wr_step_options_footer')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('wr_step_option_watch')));

      expect((await _enrollmentOf(intel, 'pt-c2')).pendingChoice, 'watch');
      expect(find.byType(WrPracticeThemeScreen), findsOneWidget);
      final choice = find.byKey(const Key('wr_practice_choice'));
      expect(
        find.descendant(
          of: choice,
          matching: find.text('Quan sát thêm một lần'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tôi đã thử cách này'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_practice_change_option')),
        findsOneWidget,
      );
    });

    testWidgets('cách đã lưu từ trước (bản cũ lưu tên) vẫn nhận ra', (
      tester,
    ) async {
      await _pumpTall(
        tester,
        _wrap(
          _router('/wr/growth/theme/pt-c2'),
          intel: library(
            done: ['pt-c2-1', 'pt-c2-2'],
            pendingChoice: 'Nói trước với một người',
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('wr_practice_choice')),
          matching: find.text('Nói trước với một người'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wr_practice_step_done_pt-c2-3')),
        findsOneWidget,
      );
    });

    testWidgets(
      'chủ đề tự thêm: Tự thêm, trích câu tình huống, ba cách riêng',
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
          ..seedEnrollments([
            _enroll(
              'u-1',
              done: ['u-1-1', 'u-1-2', 'u-1-3'],
              startedAt: DateTime(2026, 6, 8),
            ),
          ]);

        await _pumpTall(
          tester,
          _wrap(_router('/wr/growth/theme/u-1'), intel: intel),
        );

        expect(find.text('TỰ THÊM'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('wr_practice_written')),
            matching: find.text('“Mỗi khi góp ý, tôi vòng vo.”'),
          ),
          findsOneWidget,
        );
        // Bước "Câu hỏi cho lần sau" Premium khoá với bản miễn phí.
        expect(
          find.byKey(const Key('wr_practice_step_unlock_u-1-4')),
          findsOneWidget,
        );
        expect(find.text('Điều bạn muốn hỏi lần tới'), findsOneWidget);
      },
    );
  });
}
