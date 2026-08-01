// Một luồng liên thông, đi bằng tay từ đầu tới cuối:
//
//   Home check-in  →  chọn tình huống  →  chi tiết  →  Ý nghĩa  →  Lựa chọn
//        →  tab Hiểu mình đọc ra "Tình huống lặp lại" + Trải nghiệm hiện tại
//        →  tab Phát triển gợi ra đúng chủ đề thực hành của chiều đó
//
// Đây là mắt xích mà bản trước 2026-07-31 ĐỨT: luồng phản tư không bao giờ
// buộc người dùng chọn một tình huống (bước đầu là ô chữ trống, và chip tình
// huống vắng mặt ở hai trong sáu archetype), nên `situation_code` để trống và
// mọi thứ đọc từ nó — "Tình huống lặp lại", nhu cầu chủ đạo, gợi ý Practice
// Theme — đều trống theo. Người dùng phản tư 16 lần mà tab Hiểu mình vẫn nói
// "sau vài lần nhìn lại...".
//
// Tệp này cố tình KHÔNG gieo sẵn Episode. Nó bấm đúng những nút người dùng bấm,
// vì lỗi cũ chỉ lộ ra khi đi bằng tay: mọi test cũ đều gieo sẵn Episode đã có
// `situationCode`, nên không test nào nhìn thấy chỗ đứt.
//
// Kiến trúc Dữ liệu v2.0 §V (luồng 5 bước), §4.3 (một nguồn sự thật),
// §XIII (Practice Theme).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_reflect_flow.dart';
import 'package:workreflection_mobile/core/logic/wr_repeated_situations.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_commit_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_detail_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_done_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_flow_scaffold.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_meaning_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_step_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';

/// Thư viện chỉ có tình huống chiều C2, để biết chắc lần nào cũng chọn trúng nó
/// dù danh sách được trộn ngẫu nhiên (§4.1).
const _situationText = 'Không dám lên tiếng trong cuộc họp';
const _situations = [
  WrSituation(
    code: 'C2-sit-01',
    text: _situationText,
    scaDimension: ScaDimension.c2,
    wave: 1,
    humanNeed: HumanNeed.ketNoi,
  ),
];

const _theme = PracticeTheme(
  themeId: 'pt-c2',
  title: 'Nói điều khó nói mà vẫn giữ được quan hệ',
  scaDimension: ScaDimension.c2,
  description: 'Ba bước nhỏ để lên tiếng đúng lúc.',
);

/// Thư viện rộng của cùng một chiều — tái dựng đúng điều kiện đã khoá người
/// dùng lại: cụm cảm xúc còn nhiều mục chưa xem, nên nhánh "loại mã đã chọn"
/// của §4.1 chạy và không cho chạm lại điều cũ.
final _wideSituations = [
  for (var i = 1; i <= 6; i++)
    WrSituation(
      code: 'C2-0$i',
      text: 'Tình huống C2 số $i',
      scaDimension: ScaDimension.c2,
      wave: 1,
      humanNeed: HumanNeed.ketNoi,
    ),
];

class _Stage {
  _Stage({List<WrSituation>? situations}) {
    content
      ..seedSituations(situations ?? _situations)
      ..seedStories(const [
        WrStory(
          storyId: 'C2-01',
          title: 'Ý tưởng của tôi biến mất trong cuộc họp',
          scaDimension: ScaDimension.c2,
          humanNeed: HumanNeed.ketNoi,
          storyContent: 'Tôi đã chuẩn bị khá kỹ, nhưng rồi vẫn im lặng.',
          emotionTags: [],
          behaviorTags: [],
          careerStages: [],
          reflectionQuestion: 'Điều gì khiến tôi giữ lại lời mình định nói?',
          selfReflection: 'Lần gần nhất tôi thấy tiếng nói mình bị bỏ qua?',
          ahaMessage: 'Im lặng của tôi không đến từ việc thiếu ý tưởng.',
          practiceAction: 'Tuần này ghi lại một lần tôi muốn lên tiếng.',
        ),
      ]);
    // Hồ sơ phải có sẵn: `saveRecentSituationIds` là UPDATE trên hàng đã tồn
    // tại (production tạo hàng lúc đăng ký). Không gieo thì mọi lệnh ghi lịch
    // sử xoay vòng rơi vào hư không và test xoay vòng nào cũng thành vô nghĩa.
    wr.seedProfile(MobileProfile(
      userId: 'u1',
      reminderEnabled: true,
      language: 'vi',
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    ));
    intel.seedPracticeThemes(const [_theme]);
    moodContent.seedChoicePool(const [
      'Ghi nhớ điều này để xem lại sau',
      'Nói chuyện với ai đó về điều này',
      'Chưa biết, cần thêm thời gian',
      'Không cần hành động gì, chỉ cần ghi nhận là đủ',
    ]);
  }

  final episodes = FakeWrEpisodeRepository();
  final intel = FakeWrIntelligenceRepository();
  final content = FakeWrContentRepository();
  final moodContent = FakeWrMoodContentRepository();
  final wr = FakeWrRepository();

  late final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
      GoRoute(
          path: '/wr/discover', builder: (_, __) => const WrDiscoverScreen()),
      GoRoute(path: '/wr/growth', builder: (_, __) => const WrGrowthScreen()),
      GoRoute(path: '/wr/flow/step', builder: (_, __) => const WrStepScreen()),
      GoRoute(
          path: '/wr/flow/detail', builder: (_, __) => const WrDetailScreen()),
      GoRoute(
          path: '/wr/flow/meaning',
          builder: (_, __) => const WrMeaningScreen()),
      GoRoute(
          path: '/wr/flow/commit', builder: (_, __) => const WrCommitScreen()),
      GoRoute(path: '/wr/flow/done', builder: (_, __) => const WrDoneScreen()),
      for (final p in const [
        '/wr/patterns',
        '/wr/paywall',
        '/wr/self-check',
        '/wr/journey',
        '/wr/story',
      ])
        GoRoute(path: p, builder: (_, __) => Scaffold(body: Text('stub $p'))),
      GoRoute(
        path: '/wr/pattern/:code',
        builder: (_, s) =>
            Scaffold(body: Text('pattern ${s.pathParameters['code']}')),
      ),
    ],
  );

  Widget app() => ProviderScope(
        overrides: [
          wrRepositoryProvider.overrideWithValue(wr),
          wrEpisodeRepositoryProvider.overrideWithValue(episodes),
          wrIntelligenceRepositoryProvider.overrideWithValue(intel),
          wrContentRepositoryProvider.overrideWithValue(content),
          wrMoodContentRepositoryProvider.overrideWithValue(moodContent),
          currentUserIdProvider.overrideWithValue('u1'),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
        ),
      );

  /// Một vòng phản tư trọn vẹn, bấm đúng nút người dùng bấm.
  ///
  /// [chip] null nghĩa là chạm ô ĐẦU TIÊN của danh sách — tức ô neo, nếu đã có
  /// lần chọn trước. Đó là cách người dùng nói "vẫn chuyện đó".
  Future<void> reflectOnce(WidgetTester tester, {Finder? chip}) async {
    router.go('/home');
    await tester.pumpAndSettle();

    // 1 · check-in "căng thẳng" → thẳng vào bước chọn tình huống.
    await tester.tap(find.byKey(const Key('wr_home_checkin_stress')));
    await tester.pumpAndSettle();

    // 2 · Notice — CHỌN, không viết.
    final target = chip ?? find.byType(WrBigChoiceTile).first;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();

    // 3 · Meaning — chi tiết cụ thể, bỏ trống (§V: không bắt buộc).
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();

    // 4 · Insight — nhận câu Aha có sẵn.
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();

    // 5 · Choice — chạm lựa chọn đầu rồi lưu → khép phiên.
    await tester.tap(find.byKey(const Key('wr_choice_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();
    expect(find.byType(WrDoneScreen), findsOneWidget);
  }
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'ba lần check-in cùng một tình huống → Hiểu mình đếm đúng 3, '
      'Phát triển gợi đúng chủ đề của chiều đó', (tester) async {
    final stage = _Stage();
    // Premium: phần diễn giải ở tab Hiểu mình nằm sau paywall với người Free,
    // mà điều cần chứng minh ở đây là DỮ LIỆU có chảy tới nơi, không phải lớp
    // khoá.
    stage.intel
        .seedEntitlement(const WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium));
    await _pump(tester, stage.app());

    final only = find.byKey(const Key('wr_situation_C2-sit-01'));
    await stage.reflectOnce(tester, chip: only);
    await stage.reflectOnce(tester, chip: only);

    // Hai lần chưa tới ngưỡng (yêu cầu khách 2026-07-31): chưa lên bảng, nhưng
    // phải nói rõ là đã ghi nhận — không được rơi về câu "sau vài lần nhìn lại"
    // như thể app chưa thấy gì.
    stage.router.go('/wr/discover');
    await tester.pumpAndSettle();
    expect(find.text(_situationText), findsNothing,
        reason: 'lặp 2 lần chưa đủ ngưỡng $kRepeatedSituationsMinCount');
    expect(find.byKey(const Key('wr_discover_patterns_empty')), findsNothing);
    expect(
      find.byKey(const Key('wr_discover_patterns_below_threshold')),
      findsOneWidget,
    );

    await stage.reflectOnce(tester, chip: only);

    // Ba Episode, cả ba đều mang mã tình huống — mắt xích từng đứt.
    expect(stage.episodes.episodes, hasLength(3));
    for (final e in stage.episodes.episodes) {
      expect(e.situationCode, 'C2-sit-01',
          reason: 'phiên nào cũng phải ghi được mã tình huống');
    }

    // ── Tab Hiểu mình ────────────────────────────────────────────────────
    stage.router.go('/wr/discover');
    await tester.pumpAndSettle();
    expect(find.byType(WrDiscoverScreen), findsOneWidget);

    // "Tình huống lặp lại" đọc ra đúng tên và đúng SỐ LẦN (§4.3).
    expect(
      find.byKey(const Key('wr_discover_patterns_below_threshold')),
      findsNothing,
      reason: 'đã lặp đủ 3 lần mà khối vẫn báo chưa tới ngưỡng',
    );
    expect(find.text(_situationText), findsOneWidget);
    expect(find.textContaining('3 lần'), findsWidgets);

    // "Điều bạn đang tìm kiếm" — nhu cầu chủ đạo đọc từ chính ba lần đó.
    expect(find.byKey(const Key('wr_discover_need_reading')), findsOneWidget);

    // Thẻ Trải nghiệm hiện tại (SCA rút gọn) dựng được.
    expect(find.byKey(const Key('wr_discover_selfcheck_row')), findsOneWidget);

    // Career Health Check đếm đúng số lần nhìn lại.
    expect(find.textContaining('Bạn đã nhìn lại 3/15 lần'), findsOneWidget);

    // ── Tab Phát triển ───────────────────────────────────────────────────
    stage.router.go('/wr/growth');
    await tester.pumpAndSettle();
    expect(find.byType(WrGrowthScreen), findsOneWidget);

    // Chủ đề gợi ra phải là chủ đề CÙNG CHIỀU với tình huống đang lặp — đây là
    // đầu ra cuối cùng của cả chuỗi (§XIII).
    expect(find.text(_theme.title), findsOneWidget);
    expect(find.byKey(const Key('wr_growth_suggestion_reason')), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Lỗi thật, tìm ra từ DB production 2026-07-31: 16 Episode mang mã, 16 mã
  // PHÂN BIỆT, 0 lần lặp. §4.1 loại khỏi bể mọi mã đã chọn, nên chuyện lặp thật
  // không bao giờ chạm lại được và "Tình huống lặp lại" trống vĩnh viễn.
  //
  // Test cũ ở trên không bắt được vì thư viện giả chỉ có ĐÚNG MỘT tình huống —
  // bể luôn cạn nên nhánh loại-trừ không bao giờ chạy. Test này dùng thư viện
  // rộng, tức đúng hình dạng của production (10 mục mỗi chiều).
  // ---------------------------------------------------------------------------
  testWidgets('thư viện rộng: chọn lại được điều lần trước, '
      'ba lần là "3 lần" ở Hiểu mình', (tester) async {
    final stage = _Stage(situations: _wideSituations);
    stage.intel.seedEntitlement(
        const WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium));
    await _pump(tester, stage.app());

    // Vòng 1: chưa có gì để neo — chạm ô đầu, bất kể nó là mục nào.
    await stage.reflectOnce(tester);
    final chosen = stage.episodes.episodes.single.situationCode;
    expect(chosen, isNotNull);

    // Vòng 2 và 3: ô đầu phải là chính điều vừa chọn, có nhãn "Lần trước".
    for (var round = 2; round <= 3; round++) {
      stage.router.go('/home');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_home_checkin_stress')));
      await tester.pumpAndSettle();

      final first = tester.widget<WrBigChoiceTile>(
        find.byType(WrBigChoiceTile).first,
      );
      expect(
        first.badge,
        kAnchorBadge,
        reason: 'vòng $round: ô đầu không phải ô neo — người dùng lại bị khoá '
            'không chạm lại được điều mình đang gặp',
      );
      expect(find.byKey(Key('wr_situation_$chosen')), findsOneWidget,
          reason: 'vòng $round: điều đã chọn biến mất khỏi danh sách');

      await tester.tap(find.byType(WrBigChoiceTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_choice_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_flow_primary')));
      await tester.pumpAndSettle();
    }

    // Ba Episode, CÙNG một mã — đây là điều production không làm được.
    expect(stage.episodes.episodes, hasLength(3));
    expect(
      stage.episodes.episodes.map((e) => e.situationCode).toSet(),
      {chosen},
    );

    stage.router.go('/wr/discover');
    await tester.pumpAndSettle();
    expect(find.textContaining('3 lần'), findsWidgets);
    expect(
      find.byKey(const Key('wr_discover_patterns_below_threshold')),
      findsNothing,
    );
  });

  testWidgets('chưa phản tư lần nào thì Hiểu mình nói rõ là chưa có, '
      'không bịa dữ liệu mẫu', (tester) async {
    final stage = _Stage();
    await _pump(tester, stage.app());

    stage.router.go('/wr/discover');
    await tester.pumpAndSettle();

    // §4.3: rỗng thì hiển thị đúng trạng thái rỗng.
    expect(
      find.byKey(const Key('wr_discover_patterns_empty')),
      findsOneWidget,
    );
    expect(find.text(_situationText), findsNothing);
  });
}
