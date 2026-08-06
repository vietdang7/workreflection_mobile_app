// Bộ ảnh chụp cho trang App Store.
//
// Vì sao dựng bằng test thay vì cầm điện thoại chụp: máy dev là Linux, không
// có iPhone lẫn Simulator, mà Apple đòi đúng khổ 1290×2796 (cỡ iPhone Pro
// Max). Render bằng chính widget của app ở surface 430×932 với
// devicePixelRatio 3 thì ra đúng số pixel đó, và bù lại còn ba cái lợi: dữ
// liệu trong ảnh do mình đặt nên không lộ gì thật, không dính dải DEBUG, và
// chụp lại được y hệt khi giao diện đổi.
//
// Khác bộ `wr_v1_6_screens_test.dart`: bộ kia chụp để soi giao diện so với
// mockup, khổ 390 và cắt dài tuỳ màn. Bộ này chụp để bán hàng, khổ cố định
// đúng chuẩn kho.
//
// Chạy:
//   WR_SCREENSHOTS=1 flutter test test/screenshots/app_store_test.dart \
//     --update-goldens
//
// Ảnh ra ở `screenshots/app_store/`.
//
// KHÔNG chụp màn Premium — xem `docs/app_store_listing.md`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_chat_repository.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_chat.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/theme/wr_text.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_ask_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_growth_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_chat_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';

/// Chỉ chạy khi được gọi tên. Bộ này ghi đè file ảnh, không phải thứ nên chạy
/// lẫn trong `flutter test` thường ngày.
final bool _enabled = Platform.environment['WR_SCREENSHOTS'] == '1';

/// Khổ ảnh App Store bắt buộc: iPhone 6.9" = 1290×2796.
///
/// 430×932 là kích thước logic của iPhone 16 Pro Max; nhân devicePixelRatio 3
/// ra đúng số pixel Apple đòi. Sai một pixel là App Store Connect từ chối file.
const _iPhone69 = Size(430, 932);

// ---------------------------------------------------------------------------
// Nạp font
// ---------------------------------------------------------------------------

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final loader = FontLoader(family)
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }

  await load('NotoSans', 'assets/fonts/NotoSans-Regular.ttf');
  await load('NotoSans', 'assets/fonts/NotoSans-Bold.ttf');
  await load(WrText.serifFamily, 'assets/fonts/Lora-Italic.ttf');

  // Icon cũng là font. Không nạp thì mọi Icon() ra ô vuông rỗng — ảnh coi như
  // bỏ. Font nằm trong cache của Flutter SDK chứ không trong repo.
  for (final candidate in _materialIconCandidates()) {
    if (File(candidate).existsSync()) {
      await load('MaterialIcons', candidate);
      break;
    }
  }
}

List<String> _materialIconCandidates() {
  const relative =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      Platform.environment['FLUTTER_ROOT']!,
    '${Platform.environment['HOME']}/snap/flutter/common/flutter',
    '${Platform.environment['HOME']}/flutter',
    '/opt/flutter',
    '/usr/local/flutter',
  ];
  return [for (final r in roots) '$r/$relative'];
}

// ---------------------------------------------------------------------------
// Dữ liệu trong ảnh
//
// Viết như một người dùng thật ba tuần đầu: đủ để thấy sản phẩm sống, không
// hoàn hảo đến mức giả. Không dùng dữ liệu của tài khoản thật nào.
// ---------------------------------------------------------------------------

const _situations = [
  WrSituation(
    code: 'C2-sit-01',
    text: 'Không dám lên tiếng',
    scaDimension: ScaDimension.c2,
    humanNeed: HumanNeed.ketNoi,
    wave: 1,
  ),
  WrSituation(
    code: 'C2-sit-02',
    text: 'Không được lắng nghe',
    scaDimension: ScaDimension.c2,
    humanNeed: HumanNeed.ketNoi,
    wave: 1,
  ),
  WrSituation(
    code: 'A3-sit-02',
    text: 'Liên tục lặp lại cùng một vấn đề',
    scaDimension: ScaDimension.a3,
    humanNeed: HumanNeed.thichNghi,
    wave: 1,
  ),
  WrSituation(
    code: 'A3-sit-05',
    text: 'Không có thời gian nhìn lại',
    scaDimension: ScaDimension.a3,
    humanNeed: HumanNeed.thichNghi,
    wave: 1,
  ),
];

const _stories = [
  WrStory(
    storyId: 'C2-01',
    title: 'Ý tưởng của tôi biến mất trong cuộc họp',
    scaDimension: ScaDimension.c2,
    humanNeed: HumanNeed.ketNoi,
    storyContent: 'Tôi đã chuẩn bị khá kỹ.',
    emotionTags: [],
    behaviorTags: [],
    careerStages: [],
    selfReflection:
        'Lần gần nhất tôi cảm thấy tiếng nói của mình không được nhìn thấy '
        'là khi nào?',
    ahaMessage:
        'Đôi khi điều khiến chúng ta im lặng không phải vì thiếu ý tưởng. '
        'Mà vì nhiều lần lên tiếng nhưng không tạo ra khác biệt.',
    practiceAction:
        'Tuần này hãy ghi lại một lần tôi muốn lên tiếng nhưng đã chọn im lặng.',
  ),
];

final _moodContent = [
  fakeMoodContent(
    id: 'm-ok-1',
    mood: Mood.okay,
    sortOrder: 1,
    title: 'Điều gì đang vận hành tốt trong bạn?',
    kind: 'BÀI ĐỌC',
    duration: '4 phút đọc',
    body: 'Những ngày ổn định là lúc tốt nhất để nhận diện điều gì đang thực '
        'sự hiệu quả.',
    placeholder: true,
  ),
];

const _insightText =
    'Tôi thường im lặng không phải vì không có ý kiến, mà vì sợ bị đánh giá.';

/// Lịch sử nhìn lại — nguồn duy nhất để màn Hiểu mình đếm ra "tình huống lặp
/// lại". Ngưỡng hiện là 3 lần, nên tình huống chính phải xuất hiện đủ số đó.
final _episodeHistory = <ReflectionEpisode>[
  for (var i = 0; i < 5; i++)
    ReflectionEpisode(
      id: 'ep-noi-$i',
      userId: 'u1',
      humanMoment: HumanMoment.confusion,
      state: ExperienceState.integrated,
      situationCode: 'C2-sit-01',
      scaDimension: ScaDimension.c2,
      humanNeed: HumanNeed.ketNoi,
      closedAt: DateTime(2026, 8, 5 - i),
      updatedAt: DateTime(2026, 8, 5 - i),
    ),
  for (var i = 0; i < 3; i++)
    ReflectionEpisode(
      id: 'ep-lap-$i',
      userId: 'u1',
      humanMoment: HumanMoment.decision,
      state: ExperienceState.integrated,
      situationCode: 'A3-sit-02',
      scaDimension: ScaDimension.a3,
      humanNeed: HumanNeed.thichNghi,
      closedAt: DateTime(2026, 7, 30 - i),
      updatedAt: DateTime(2026, 7, 30 - i),
    ),
];

/// Career Memory — mỗi lần nhìn lại để lại một mảnh ở màn Hành trình.
final _memoryEvents = <CareerMemoryEvent>[
  CareerMemoryEvent(
    id: 'me1',
    userId: 'u1',
    situationCode: 'C2-sit-01',
    scaDimension: ScaDimension.c2,
    humanNeed: HumanNeed.ketNoi,
    reflectionText: 'Lần đầu tôi nói hết ý mình trong cuộc họp dự án, dù tay '
        'vẫn run.',
    createdAt: DateTime(2026, 8, 4),
  ),
  CareerMemoryEvent(
    id: 'me2',
    userId: 'u1',
    situationCode: 'A3-sit-02',
    scaDimension: ScaDimension.a3,
    humanNeed: HumanNeed.thichNghi,
    reflectionText: 'Nhận ra mình cứ nhận thêm việc vào cuối ngày rồi mang về '
        'nhà làm tiếp.',
    createdAt: DateTime(2026, 7, 29),
  ),
  CareerMemoryEvent(
    id: 'me3',
    userId: 'u1',
    situationCode: 'C2-sit-02',
    scaDimension: ScaDimension.c2,
    humanNeed: HumanNeed.ketNoi,
    reflectionText: 'Ý tưởng của tôi biến mất trong cuộc họp — lần đầu tôi gọi '
        'tên được cảm giác đó.',
    createdAt: DateTime(2026, 7, 20),
  ),
];

// ---------------------------------------------------------------------------

class _Stage {
  final content = FakeWrContentRepository();
  final intel = FakeWrIntelligenceRepository();
  final moodContent = FakeWrMoodContentRepository();
  final episodes = FakeWrEpisodeRepository();
  final wr = FakeWrRepository();
  final chat = FakeWrChatRepository();

  Widget app(String location) {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
        GoRoute(
          path: '/wr/journey',
          builder: (_, __) => const WrJourneyScreen(),
        ),
        GoRoute(
          path: '/wr/discover',
          builder: (_, __) => const WrDiscoverScreen(),
        ),
        GoRoute(path: '/wr/growth', builder: (_, __) => const WrGrowthScreen()),
        GoRoute(path: '/wr/ask', builder: (_, __) => const WrAskScreen()),
        // Các đích điều hướng phụ: có mặt để router không nổ khi widget dựng
        // link tới, không màn nào trong số này được chụp.
        GoRoute(path: '/profile', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/wr/paywall', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/wr/flow/step', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/wr/flow/done', builder: (_, __) => const Scaffold()),
        GoRoute(
          path: '/wr/mood-library',
          builder: (_, __) => const Scaffold(),
        ),
        GoRoute(
          path: '/wr/pattern/:code',
          builder: (_, __) => const Scaffold(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        wrContentRepositoryProvider.overrideWithValue(content),
        wrIntelligenceRepositoryProvider.overrideWithValue(intel),
        wrMoodContentRepositoryProvider.overrideWithValue(moodContent),
        wrEpisodeRepositoryProvider.overrideWithValue(episodes),
        wrRepositoryProvider.overrideWithValue(wr),
        wrChatRepositoryProvider.overrideWithValue(chat),
        currentUserIdProvider.overrideWithValue('u1'),
      ],
      child: MaterialApp.router(
        builder: wrTextScaleBuilder,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'NotoSans', useMaterial3: true),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
      ),
    );
  }
}

/// Chụp một màn ở đúng khổ App Store.
///
/// Nội dung dài hơn màn hình thì bị cắt đúng như trên máy thật — đó là điều
/// mình muốn: ảnh phải giống cái người ta thấy khi mở app, không phải một
/// trang web dài cuộn hết cỡ.
Future<void> _shoot(WidgetTester tester, Widget app, String name) async {
  tester.view.physicalSize = _iPhone69 * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../screenshots/app_store/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  _Stage buildStage({Mood mood = Mood.okay}) {
    final s = _Stage();
    s.content
      ..seedSituations(_situations)
      ..seedStories(_stories);
    s.moodContent.seedContent(_moodContent);
    s.wr.seedTodayCheckin(Checkin(
      id: 'ck',
      userId: 'u1',
      mood: mood,
      checkinDate: DateTime(2026, 8, 6),
      createdAt: DateTime(2026, 8, 6),
    ));
    // Ba nguồn dưới đây quyết định màn Hiểu mình và Hành trình có nội dung hay
    // chỉ hiện câu "chưa có gì". Phải gieo ĐÚNG nguồn từng màn đọc:
    //   - "Tình huống lặp lại" đếm từ lịch sử episode, không từ bảng đếm nào
    //     khác (xem `wrEpisodeHistoryProvider`).
    //   - Career Memory đọc `fetchMemoryEvents` của content repo.
    //   - Ba chiều "Trải nghiệm hiện tại" đọc lịch sử Self-check.
    // Bộ ảnh đầu gieo nhầm sang FakeWrRepository nên hai màn đó chụp ra trống.
    s.episodes.seed([
      for (final e in _episodeHistory) e,
    ]);
    s.content.seedMemoryEvents(_memoryEvents);
    // Tài khoản trong ảnh là bản đầy đủ. Không phải để khoe gói: để ảnh không
    // đầy những khối "Premium" khoá kín. Màn Hành trình ở bản free là ba khối
    // mời nâng cấp xếp chồng, chụp ra thì người xem không thấy sản phẩm làm
    // được gì. Trưng bày trải nghiệm đầy đủ là chuyện bình thường trên kho.
    s.intel.seedEntitlement(const WrEntitlementRecord(
      userId: 'u1',
      plan: WrPlan.premium,
    ));
    // Khối "Diễn biến theo thời gian" ở đầu màn Hành trình đọc nguồn này. Không
    // gieo thì nó nói "chưa đủ dữ liệu" ngay giữa ảnh quảng cáo.
    s.intel.seedPatternNarratives([
      PatternNarrative(
        id: 'pn1',
        userId: 'u1',
        narrative: 'Ba tuần qua, điều lặp lại nhiều nhất ở bạn là chọn im lặng '
            'trong những cuộc họp đông người. Nhưng tuần này đã khác: bạn ghi '
            'lại hai lần nói ra được ý mình, và cả hai lần đều nhẹ hơn bạn '
            'tưởng.',
        periodStart: DateTime(2026, 7, 16),
        periodEnd: DateTime(2026, 8, 6),
        createdAt: DateTime(2026, 8, 6),
      ),
    ]);
    s.intel.seedSelfCheckHistory([
      ScaSelfCheckResponse(
        id: 'sc1',
        userId: 'u1',
        answers: const {},
        structureScore: 3.4,
        cultureScore: 2.8,
        activityScore: 4.1,
        takenAt: DateTime(2026, 8, 2),
      ),
    ]);
    s.intel
      ..seedInsights([
        WrInsight(
          userId: 'u1',
          content: _insightText,
          createdAt: DateTime(2026, 8, 4),
        ),
      ])
      ..seedPatternCounts([
        PatternCount(
          id: 'p1',
          userId: 'u1',
          situationCode: 'C2-sit-01',
          scaDimension: ScaDimension.c2,
          occurrenceCount: 5,
          lastSeenAt: DateTime(2026, 8, 5),
        ),
        PatternCount(
          id: 'p2',
          userId: 'u1',
          situationCode: 'A3-sit-02',
          scaDimension: ScaDimension.a3,
          occurrenceCount: 3,
          lastSeenAt: DateTime(2026, 8, 3),
        ),
      ])
      // Hai chủ đề, không phải một: màn Phát triển với đúng một thẻ thì nửa
      // dưới trống trơn, ảnh nhìn như app chưa làm xong.
      ..seedPracticeThemes([
        const PracticeTheme(themeId: 't1', title: 'Dám lên tiếng'),
        const PracticeTheme(themeId: 't2', title: 'Giữ ranh giới công việc'),
      ])
      ..seedPracticeSteps('t1', [
        const PracticeStep(
          stepId: 's1',
          themeId: 't1',
          stepOrder: 1,
          title: 'Quan sát lúc muốn im lặng',
          isPremium: false,
        ),
        const PracticeStep(
          stepId: 's2',
          themeId: 't1',
          stepOrder: 2,
          title: 'Đặt một câu hỏi trong họp',
          isPremium: false,
        ),
        const PracticeStep(
          stepId: 's3',
          themeId: 't1',
          stepOrder: 3,
          title: 'Nói ra điều mình nghĩ trước khi họp kết thúc',
          isPremium: false,
        ),
      ])
      ..seedPracticeSteps('t2', [
        const PracticeStep(
          stepId: 's4',
          themeId: 't2',
          stepOrder: 1,
          title: 'Ghi lại lần nhận việc sau giờ làm',
          isPremium: false,
        ),
        const PracticeStep(
          stepId: 's5',
          themeId: 't2',
          stepOrder: 2,
          title: 'Nói "để mai tôi làm" một lần',
          isPremium: false,
        ),
      ])
      ..seedEnrollments([
        const PracticeEnrollment(
          userId: 'u1',
          themeId: 't1',
          completedSteps: ['s1'],
        ),
        const PracticeEnrollment(
          userId: 'u1',
          themeId: 't2',
          completedSteps: [],
        ),
      ]);
    return s;
  }

  testWidgets('01 · Home — mở ra là thấy hôm nay', skip: !_enabled,
      (tester) async {
    await _shoot(tester, buildStage().app('/home'), '01_home');
  });

  testWidgets('02 · Hiểu mình — những gì cứ lặp lại', skip: !_enabled,
      (tester) async {
    await _shoot(tester, buildStage().app('/wr/discover'), '02_hieu_minh');
  });

  testWidgets('03 · Phát triển — chủ đề thực hành', skip: !_enabled,
      (tester) async {
    await _shoot(tester, buildStage().app('/wr/growth'), '03_phat_trien');
  });

  testWidgets('04 · Hành trình — dòng thời gian nghề nghiệp', skip: !_enabled,
      (tester) async {
    await _shoot(tester, buildStage().app('/wr/journey'), '04_hanh_trinh');
  });

  testWidgets('05 · Trợ lý AI — hỏi về chính ghi chép của mình',
      skip: !_enabled, (tester) async {
    final s = buildStage();
    // Một lượt hỏi đáp đã xong, chọn đoạn nói về công việc thuần tuý: không
    // một chữ nào nghe như tư vấn tâm lý hay y tế, đó là thứ App Review soi.
    s.chat.seedConversation(
      'c1',
      const [
        WrChatMessage(
          role: WrChatRole.user,
          content: 'Vì sao tôi cứ ngại nói ra ý kiến trong các cuộc họp lớn?',
        ),
        WrChatMessage(
          role: WrChatRole.assistant,
          content: 'Trong ba tuần vừa rồi, bạn ghi lại năm lần thấy mình muốn '
              'lên tiếng nhưng đã chọn im lặng. Bốn lần trong số đó là họp có '
              'mặt cấp trên, và cả bốn lần bạn đều viết rằng ý kiến của mình '
              '"chưa đủ chắc". Có vẻ điều ngăn bạn lại không phải là đám đông, '
              'mà là một tiêu chuẩn bạn tự đặt cho mình về việc thế nào là đủ '
              'chắc để nói.',
        ),
      ],
      title: 'Ngại nói trong họp',
      lastMessageAt: DateTime(2026, 8, 5),
    );
    await _shoot(tester, s.app('/wr/ask'), '05_tro_ly_ai');
  });
}
