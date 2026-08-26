// Ảnh kiểm chứng cho ca của khách báo ngày 24/08/2026.
//
// Không phải ảnh quảng cáo. Đây là cách nhìn tận mắt xem bốn chỗ đã sửa có ra
// đúng chữ và đúng số hay không, mà không cần đăng nhập vào tài khoản thật.
//
// Hình dạng dữ liệu dưới đây lấy theo ĐÚNG cấu trúc tài khoản của khách đọc
// được từ Postgres ngày 24/08:
//
//   15 Episode  ·  13 đã khép (integrated)  ·  2 dormant
//   13 có situation_code  ·  2 để NULL (nhánh "Điều khác, để tôi tự mô tả")
//   21 mảnh Career Memory = 13 reflection_episode + 8 dấu mốc thực hành
//   đã từng làm Self-check
//
// Nội dung chữ thì KHÔNG lấy của khách — nhãn tình huống là nội dung công khai
// trong `wr_situations`, phần ghi chép cá nhân được bịa lại. Ảnh này để soi
// giao diện, không phải để mang dữ liệu người thật ra ngoài.
//
// Chạy:
//   WR_SCREENSHOTS=1 flutter test test/screenshots/wr_customer_case_test.dart \
//     --update-goldens
//
// Ảnh ra ở `build/verify/` — thư mục build, không vào git.

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
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/theme/wr_text.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_chat_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';

final bool _enabled = Platform.environment['WR_SCREENSHOTS'] == '1';

/// Một khổ thôi. Đây là ảnh để soi, không phải ảnh nộp kho.
const _size = Size(430, 932);

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

  const relative =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  for (final root in <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      Platform.environment['FLUTTER_ROOT']!,
    '${Platform.environment['HOME']}/snap/flutter/common/flutter',
    '${Platform.environment['HOME']}/flutter',
    '/opt/flutter',
    '/usr/local/flutter',
  ]) {
    if (File('$root/$relative').existsSync()) {
      await load('MaterialIcons', '$root/$relative');
      break;
    }
  }
}

// ---------------------------------------------------------------------------
// Tình huống — nhãn lấy nguyên văn từ `wr_situations` để chữ trên ảnh giống
// hệt chữ khách nhìn thấy.
// ---------------------------------------------------------------------------

const _situations = <WrSituation>[
  WrSituation(
    code: 'P-08',
    text: 'Tôi vừa học được một điều nhỏ nhưng hữu ích',
    scaDimension: ScaDimension.pSteady,
    humanNeed: HumanNeed.phatTrien,
    wave: 1,
  ),
  WrSituation(
    code: 'P-09',
    text: 'Tôi có một cuộc trò chuyện tốt với đồng nghiệp',
    scaDimension: ScaDimension.pSteady,
    humanNeed: HumanNeed.phatTrien,
    wave: 1,
  ),
  WrSituation(
    code: 'C2-03',
    text: 'Tôi đồng ý dù trong lòng không đồng ý',
    scaDimension: ScaDimension.c2,
    humanNeed: HumanNeed.ketNoi,
    wave: 1,
  ),
  WrSituation(
    code: 'C2-09',
    text: 'Tôi luôn là người cuối cùng phát biểu',
    scaDimension: ScaDimension.c2,
    humanNeed: HumanNeed.ketNoi,
    wave: 1,
  ),
  WrSituation(
    code: 'A3-08',
    text: 'Tôi luôn nghĩ mình phải làm tốt hơn',
    scaDimension: ScaDimension.a3,
    humanNeed: HumanNeed.thichNghi,
    wave: 1,
  ),
  WrSituation(
    code: 'A1-08',
    text: 'Tôi muốn nhiều hơn, nhưng không biết là gì',
    scaDimension: ScaDimension.a1,
    humanNeed: HumanNeed.phatTrien,
    wave: 1,
  ),
  WrSituation(
    code: 'P-02',
    text: 'Tôi được ghi nhận tích cực từ cấp trên',
    scaDimension: ScaDimension.pAchieve,
    humanNeed: HumanNeed.phatTrien,
    wave: 1,
  ),
  WrSituation(
    code: 'P-04',
    text: 'Tôi được tăng lương hoặc thăng chức',
    scaDimension: ScaDimension.pAchieve,
    humanNeed: HumanNeed.phatTrien,
    wave: 1,
  ),
];

/// Một Episode. `state` quyết định nó có vào Hành trình hay không, còn
/// `situationCode` quyết định nó có được các phần đọc mẫu hình nhìn thấy hay
/// không — hai điều kiện KHÁC NHAU, và đó chính là gốc của việc 15 ≠ 21.
ReflectionEpisode _ep({
  required String id,
  required String? code,
  required ExperienceState state,
  required DateTime at,
  ScaDimension? dim,
  HumanNeed? need,
  String? meaning,
}) =>
    ReflectionEpisode(
      id: id,
      userId: 'u1',
      humanMoment: HumanMoment.confusion,
      state: state,
      situationCode: code,
      scaDimension: dim,
      humanNeed: need,
      draftMeaning: meaning,
      openedAt: at,
      updatedAt: at,
      closedAt: state == ExperienceState.integrated ? at : null,
    );

/// 15 Episode, phân bố y hệt tài khoản khách.
final _episodes = <ReflectionEpisode>[
  // P-08 × 3 — tình huống lặp nhiều nhất, đủ ngưỡng 3 lần.
  for (var i = 0; i < 3; i++)
    _ep(
      id: 'p08-$i',
      code: 'P-08',
      state: ExperienceState.integrated,
      at: DateTime(2026, 8, 22 - i),
      dim: ScaDimension.pSteady,
      need: HumanNeed.phatTrien,
      meaning: 'Học được một cách nói ngắn hơn khi báo cáo.',
    ),
  // P-09 × 2
  for (var i = 0; i < 2; i++)
    _ep(
      id: 'p09-$i',
      code: 'P-09',
      state: ExperienceState.integrated,
      at: DateTime(2026, 8, 18 - i),
      dim: ScaDimension.pSteady,
      need: HumanNeed.phatTrien,
    ),
  // C2-03 × 2 đã khép + 1 còn dở → đúng chỗ "con số ở Hiểu mình lớn hơn".
  for (var i = 0; i < 2; i++)
    _ep(
      id: 'c203-$i',
      code: 'C2-03',
      state: ExperienceState.integrated,
      at: DateTime(2026, 8, 15 - i),
      dim: ScaDimension.c2,
      need: HumanNeed.ketNoi,
    ),
  _ep(
    id: 'c203-do',
    code: 'C2-03',
    state: ExperienceState.dormant,
    at: DateTime(2026, 8, 12),
    dim: ScaDimension.c2,
    need: HumanNeed.ketNoi,
  ),
  _ep(
    id: 'a108-do',
    code: 'A1-08',
    state: ExperienceState.dormant,
    at: DateTime(2026, 8, 11),
    dim: ScaDimension.a1,
    need: HumanNeed.phatTrien,
  ),
  _ep(
    id: 'a308',
    code: 'A3-08',
    state: ExperienceState.integrated,
    at: DateTime(2026, 8, 10),
    dim: ScaDimension.a3,
    need: HumanNeed.thichNghi,
  ),
  _ep(
    id: 'p02',
    code: 'P-02',
    state: ExperienceState.integrated,
    at: DateTime(2026, 8, 8),
    dim: ScaDimension.pAchieve,
    need: HumanNeed.phatTrien,
  ),
  _ep(
    id: 'c209',
    code: 'C2-09',
    state: ExperienceState.integrated,
    at: DateTime(2026, 8, 6),
    dim: ScaDimension.c2,
    need: HumanNeed.ketNoi,
  ),
  _ep(
    id: 'p04',
    code: 'P-04',
    state: ExperienceState.integrated,
    at: DateTime(2026, 8, 4),
    dim: ScaDimension.pAchieve,
    need: HumanNeed.phatTrien,
  ),
  // Hai lần bấm "Điều khác, để tôi tự mô tả": đã khép nên CÓ mặt ở Hành trình,
  // nhưng không có tình huống nên các phần đọc mẫu hình không thấy chúng.
  for (var i = 0; i < 2; i++)
    _ep(
      id: 'khac-$i',
      code: null,
      state: ExperienceState.integrated,
      at: DateTime(2026, 8, 2 - i),
      meaning: 'Một chuyện tôi tự mô tả, không chọn tình huống nào.',
    ),
];

/// 21 mảnh Career Memory: 13 do Episode khép sinh ra + 8 dấu mốc thực hành.
///
/// 13 mảnh đầu bị `buildJourneyEntries` bỏ qua (vì đã đọc thẳng từ Episode),
/// nên đầu đề đếm ra 13 + 8 = 21. Gieo đủ cả 21 để ảnh chứng minh phép trừ đó
/// chạy đúng chứ không phải ăn may.
final _memoryEvents = <CareerMemoryEvent>[
  for (var i = 0; i < 13; i++)
    CareerMemoryEvent(
      id: 'me-ep-$i',
      userId: 'u1',
      behavior: kEpisodeBehavior,
      situationCode: 'P-08',
      createdAt: DateTime(2026, 8, 22 - i),
    ),
  for (var i = 0; i < 4; i++)
    CareerMemoryEvent(
      id: 'me-step-$i',
      userId: 'u1',
      behavior: 'practice_step_done',
      reflectionText: 'Xong một bước thực hành.',
      createdAt: DateTime(2026, 8, 21 - i),
    ),
  for (var i = 0; i < 2; i++)
    CareerMemoryEvent(
      id: 'me-note-$i',
      userId: 'u1',
      behavior: 'practice_step_note',
      reflectionText: 'Ghi lại một điều nhận ra khi thực hành.',
      createdAt: DateTime(2026, 8, 17 - i),
    ),
  CareerMemoryEvent(
    id: 'me-theme',
    userId: 'u1',
    behavior: 'practice_theme_done',
    reflectionText: 'Khép lại một chủ đề thực hành.',
    createdAt: DateTime(2026, 8, 14),
  ),
  CareerMemoryEvent(
    id: 'me-keep',
    userId: 'u1',
    behavior: 'practice_maintained',
    reflectionText: 'Duy trì thêm một ngày.',
    createdAt: DateTime(2026, 8, 13),
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
        GoRoute(
          path: '/wr/journey',
          builder: (_, __) => const WrJourneyScreen(),
        ),
        GoRoute(
          path: '/wr/discover',
          builder: (_, __) => const WrDiscoverScreen(),
        ),
        for (final p in const [
          '/home',
          '/profile',
          '/wr/growth',
          '/wr/ask',
          '/wr/paywall',
          '/wr/patterns',
          '/wr/journey/narrative',
          '/wr/journey/all',
          '/wr/self-check',
          '/wr/flow/step',
        ])
          GoRoute(path: p, builder: (_, __) => const Scaffold()),
        GoRoute(path: '/wr/pattern/:code', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/wr/episode/:id', builder: (_, __) => const Scaffold()),
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

Future<void> _shoot(
  WidgetTester tester,
  Widget app,
  String name, {
  double scrollBy = 0,
}) async {
  tester.view.physicalSize = _size * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  if (scrollBy > 0) {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, -scrollBy),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../build/verify/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  _Stage buildStage() {
    final s = _Stage();
    s.content
      ..seedSituations(_situations)
      ..seedMemoryEvents(_memoryEvents);
    s.episodes.seed(_episodes);
    // Khách đang ở gói trả phí, và ĐÃ từng làm Self-check — chính điều kiện
    // này làm thẻ Career Health cũ đứng im ở mốc 15 mà không có gì bấm được.
    s.intel
      ..seedEntitlement(const WrEntitlementRecord(
        userId: 'u1',
        plan: WrPlan.premium,
      ))
      ..seedSelfCheckHistory([
        ScaSelfCheckResponse(
          id: 'sc1',
          userId: 'u1',
          answers: const {},
          structureScore: 3.2,
          cultureScore: 2.6,
          activityScore: 3.9,
          takenAt: DateTime(2026, 8, 9),
        ),
      ]);
    return s;
  }

  testWidgets('Hiểu mình — 15 lần nhìn lại, thẻ đã mở và bấm được', (t) async {
    final s = buildStage();
    await _shoot(t, s.app('/wr/discover'), '01_hieu_minh_15_lan');
  }, skip: !_enabled);

  testWidgets('Hiểu mình — cuộn xuống tận thẻ Career Health', (t) async {
    final s = buildStage();
    await _shoot(
      t,
      s.app('/wr/discover'),
      '01b_hieu_minh_career_health',
      scrollBy: 760,
    );
  }, skip: !_enabled);

  testWidgets('Hành trình — 21 mảnh, có dòng tự giải thích con số', (t) async {
    final s = buildStage()
      ..intel.seedPatternNarratives([
        PatternNarrative(
          id: 'pn1',
          userId: 'u1',
          narrative: 'Gần đây điều trở đi trở lại nhiều nhất ở bạn là những '
              'lần học được một điều nhỏ trong lúc làm. Trong khi đó, những '
              'lần đồng ý dù trong lòng không đồng ý đã thưa dần so với giai '
              'đoạn trước.',
          periodStart: DateTime(2026, 8, 2),
          periodEnd: DateTime(2026, 8, 22),
          createdAt: DateTime(2026, 8, 24),
        ),
      ]);
    await _shoot(t, s.app('/wr/journey'), '02_hanh_trinh_21_manh');
  }, skip: !_enabled);

  testWidgets('Hành trình — chưa có bản kể thì đếm ngược đúng', (t) async {
    // Chưa đủ để kể: hàm trả về còn thiếu 2 lần CÓ CHỌN TÌNH HUỐNG. Ảnh này để
    // soi đúng cụm chữ đó — nếu thiếu, hai màn lại nói hai con số khác nhau
    // với người hay bấm "Điều khác".
    final s = buildStage()
      ..intel.nextNarrativeRefresh = const WrNarrativeRefresh(
        status: WrNarrativeStatus.notEnoughData,
        needed: 2,
      );
    await _shoot(t, s.app('/wr/journey'), '03_hanh_trinh_cho_ke');
  }, skip: !_enabled);
}
