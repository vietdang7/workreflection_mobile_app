// Chụp màn hình các giao diện mới theo Kiến trúc Dữ liệu Hai Lớp v1.6.
//
// Chạy headless trong flutter test, KHÔNG mở app và không cần máy ảo:
//
//   WR_SCREENSHOTS=1 flutter test test/screenshots/ --update-goldens
//
// Ảnh ra thư mục `screenshots/` ở gốc repo.
//
// Đây là test để XEM, không phải test để chặn hồi quy. Mặc định nó tự bỏ qua:
// so sánh golden phụ thuộc phiên bản font và engine render, nên để nó chạy
// trong bộ test thường sẽ đỏ trên máy khác hoặc CI vì lý do chẳng liên quan gì
// tới đúng/sai của sản phẩm.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_commit_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_meaning_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/flow/wr_step_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_mood_library_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_mood_reader_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';

// ---------------------------------------------------------------------------
// Font — không nạp thì chữ tiếng Việt render thành ô vuông và ảnh vô dụng.
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

  // Icon cũng là font. Không nạp thì mọi Icon() render thành ô vuông rỗng và
  // ảnh chụp không dùng để duyệt giao diện được.
  //
  // Font này nằm trong cache của Flutter SDK, không nằm trong repo — dò theo
  // đường dẫn của chính binary flutter đang chạy để máy khác vẫn tìm được.
  for (final candidate in _materialIconCandidates()) {
    if (File(candidate).existsSync()) {
      await load('MaterialIcons', candidate);
      break;
    }
  }
}

List<String> _materialIconCandidates() {
  const relative = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      Platform.environment['FLUTTER_ROOT']!,
    // Bản cài qua snap.
    '${Platform.environment['HOME']}/snap/flutter/common/flutter',
    // Các vị trí cài tay thường gặp.
    '${Platform.environment['HOME']}/flutter',
    '/opt/flutter',
    '/usr/local/flutter',
  ];
  return [for (final r in roots) '$r/$relative'];
}

// ---------------------------------------------------------------------------
// Dữ liệu mẫu
// ---------------------------------------------------------------------------

const _situations = [
  WrSituation(
    code: 'A3-sit-02',
    text: 'Liên tục lặp lại cùng một vấn đề',
    scaDimension: ScaDimension.a3,
    humanNeed: HumanNeed.thichNghi,
    wave: 1,
  ),
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
    code: 'A3-sit-05',
    text: 'Không có thời gian nhìn lại',
    scaDimension: ScaDimension.a3,
    humanNeed: HumanNeed.thichNghi,
    wave: 1,
  ),
  WrSituation(
    code: 'C2-sit-05',
    text: 'Sợ mắc lỗi trước tập thể',
    scaDimension: ScaDimension.c2,
    humanNeed: HumanNeed.ketNoi,
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
    id: 'm-stress-1',
    mood: Mood.stressed,
    sortOrder: 1,
    title: 'Ba nhịp thở trước khi phản hồi',
    kind: 'HEALING AUDIO',
    duration: '3 phút',
    type: MoodContentType.audio,
    body: 'Một bài hướng dẫn hít thở ngắn, giúp bạn lấy lại nhịp trước khi '
        'bước vào một cuộc trao đổi căng thẳng.',
    placeholder: true,
  ),
  fakeMoodContent(
    id: 'm-stress-3',
    mood: Mood.stressed,
    sortOrder: 3,
    title: 'Khi áp lực đến từ việc muốn kiểm soát mọi thứ',
    kind: 'BÀI ĐỌC',
    duration: '4 phút đọc',
    body: 'Có những ngày căng thẳng đến từ một deadline gấp, một cuộc họp khó, '
        'một quyết định lớn cần đưa ra. Nhưng cũng có những ngày căng thẳng '
        'đến mà không có lý do rõ ràng nào cả.\n\n'
        'Nếu để ý kỹ hơn, một phần không nhỏ của loại căng thẳng này đến từ '
        'việc cố gắng kiểm soát những thứ vốn dĩ không hoàn toàn nằm trong '
        'tay mình. Kết quả một cuộc họp. Cách người khác phản ứng.\n\n'
        'Điều này không đến từ việc ai đó yếu đuối hay thiếu kỷ luật. Muốn '
        'kiểm soát thường là một phản xạ tự nhiên khi môi trường xung quanh '
        'có nhiều điều không chắc chắn.',
    placeholder: true,
  ),
  fakeMoodContent(
    id: 'm-tired-1',
    mood: Mood.tired,
    sortOrder: 1,
    title: 'Một khoảng lặng 5 phút',
    kind: 'HEALING AUDIO',
    duration: '5 phút',
    type: MoodContentType.audio,
    body: 'Không cần làm gì thêm trong 5 phút này.',
    placeholder: true,
  ),
  fakeMoodContent(
    id: 'm-tired-2',
    mood: Mood.tired,
    sortOrder: 2,
    title: 'Kiệt sức không phải là yếu đuối',
    kind: 'BÀI ĐỌC',
    duration: '4 phút đọc',
    body: 'Kiệt sức thường bị hiểu nhầm là dấu hiệu của sự yếu đuối.',
    placeholder: true,
  ),
  fakeMoodContent(
    id: 'm-ok-1',
    mood: Mood.okay,
    sortOrder: 1,
    title: 'Điều gì đang vận hành tốt trong bạn?',
    kind: 'BÀI ĐỌC',
    duration: '4 phút đọc',
    body: 'Những ngày ổn định là lúc tốt nhất để nhận diện điều gì đang '
        'thực sự hiệu quả.',
    placeholder: true,
  ),
  fakeMoodContent(
    id: 'm-happy-1',
    mood: Mood.happy,
    sortOrder: 1,
    title: 'Ghi lại khoảnh khắc này trước khi nó trôi qua',
    kind: 'BÀI ĐỌC',
    duration: '3 phút đọc',
    body: 'Niềm vui thường trôi qua nhanh và ít được ghi nhớ hơn khó khăn.',
    placeholder: true,
  ),
];

const _choicePool = [
  'Thử một cách tiếp cận khác vào lần tới',
  'Giữ nguyên cách làm hiện tại, quan sát thêm',
  'Chưa biết, cần thêm thời gian',
  'Nói chuyện với ai đó về điều này',
  'Ghi nhớ điều này để xem lại sau',
  'Đặt lời nhắc để quay lại tình huống này sau một tuần',
  'Chia sẻ điều này với người liên quan trực tiếp',
  'Không cần hành động gì, chỉ cần ghi nhận là đủ',
];

// ---------------------------------------------------------------------------

class _Stage {
  _Stage()
      : content = FakeWrContentRepository(),
        intel = FakeWrIntelligenceRepository(),
        moodContent = FakeWrMoodContentRepository(),
        episodes = FakeWrEpisodeRepository(),
        wr = FakeWrRepository();

  final FakeWrContentRepository content;
  final FakeWrIntelligenceRepository intel;
  final FakeWrMoodContentRepository moodContent;
  final FakeWrEpisodeRepository episodes;
  final FakeWrRepository wr;

  Widget app(String location) {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
        GoRoute(
          path: '/wr/mood-library',
          builder: (_, __) => const WrMoodLibraryScreen(),
        ),
        GoRoute(
          path: '/wr/mood-content/:id',
          builder: (_, s) =>
              WrMoodReaderScreen(contentId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/wr/flow/step',
          builder: (_, __) => const WrStepScreen(),
        ),
        GoRoute(
          path: '/wr/flow/meaning',
          builder: (_, __) => const WrMeaningScreen(),
        ),
        GoRoute(
          path: '/wr/flow/commit',
          builder: (_, __) => const WrCommitScreen(),
        ),
        GoRoute(path: '/profile', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/wr/flow/done', builder: (_, __) => const Scaffold()),
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
        currentUserIdProvider.overrideWithValue('u1'),
      ],
      child: MaterialApp.router(
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
  Size size = const Size(390, 844), // iPhone 14
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../screenshots/$name.png'),
  );
}

/// Bộ chụp ảnh chỉ chạy khi được yêu cầu rõ ràng.
final bool _enabled = Platform.environment['WR_SCREENSHOTS'] == '1';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  _Stage buildStage({Mood mood = Mood.stressed}) {
    final s = _Stage();
    s.content
      ..seedSituations(_situations)
      ..seedStories(_stories);
    s.moodContent
      ..seedContent(_moodContent)
      ..seedChoicePool(_choicePool);
    s.wr.seedTodayCheckin(Checkin(
      id: 'ck',
      userId: 'u1',
      mood: mood,
      checkinDate: DateTime(2026, 7, 28),
      createdAt: DateTime(2026, 7, 28),
    ));
    return s;
  }

  testWidgets('01 · Home — check-in + Thư viện Cảm xúc', skip: !_enabled,
      (tester) async {
    final s = buildStage();
    s.intel.seedPatternCounts([
      PatternCount(
        id: 'p1',
        userId: 'u1',
        situationCode: 'C2-sit-01',
        scaDimension: ScaDimension.c2,
        occurrenceCount: 5,
        lastSeenAt: DateTime(2026, 7, 27),
      ),
    ]);
    await _shoot(tester, s.app('/home'), '01_home');
  });

  testWidgets('02 · Thư viện Nội dung Cảm xúc', skip: !_enabled, (tester) async {
    await _shoot(
      tester,
      buildStage().app('/wr/mood-library'),
      '02_thu_vien_cam_xuc',
      size: const Size(390, 1100),
    );
  });

  testWidgets('03 · Màn đọc — BÀI ĐỌC', skip: !_enabled, (tester) async {
    await _shoot(
      tester,
      buildStage().app('/wr/mood-content/m-stress-3'),
      '03_man_doc_bai_doc',
      size: const Size(390, 1000),
    );
  });

  testWidgets('04 · Màn nghe — HEALING AUDIO', skip: !_enabled, (tester) async {
    await _shoot(
      tester,
      buildStage().app('/wr/mood-content/m-stress-1'),
      '04_man_nghe_audio',
    );
  });

  testWidgets('05 · Chọn tình huống — lọc theo cảm xúc', skip: !_enabled, (tester) async {
    final s = buildStage();
    s.episodes.seed([
      const ReflectionEpisode(
        id: 'ep',
        userId: 'u1',
        humanMoment: HumanMoment.confusion,
        state: ExperienceState.exploring,
        energy: CheckinEnergy.low,
        patternsDone: [ReflectionPattern.notice],
        notes: {'notice': 'Tôi đang thấy nặng đầu vì cuộc họp sáng nay.'},
      ),
    ]);
    final app = s.app('/home');
    tester.view.physicalSize = const Size(390, 900) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wr_home_resume_reflection')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../screenshots/05_chon_tinh_huong.png'),
    );
  });

  testWidgets('06 · Ý nghĩa — Self Reflection + Aha gợi sẵn', skip: !_enabled, (tester) async {
    final s = buildStage();
    s.episodes.seed([
      const ReflectionEpisode(
        id: 'ep',
        userId: 'u1',
        humanMoment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        energy: CheckinEnergy.low,
        situationCode: 'C2-sit-01',
        patternsDone: [
          ReflectionPattern.notice,
          ReflectionPattern.name,
          ReflectionPattern.preserve,
        ],
        notes: {
          'notice': 'Tôi vừa nói ra được điều mình nghĩ trong cuộc họp.',
          'name': 'Tôi thấy nhẹ người vì đã không im lặng.',
        },
      ),
    ]);
    tester.view.physicalSize = const Size(390, 1000) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(s.app('/home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wr_home_resume_reflection')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../screenshots/06_y_nghia_aha.png'),
    );
  });

  testWidgets('07 · Lựa chọn — Practice + bể 8 câu', skip: !_enabled, (tester) async {
    final s = buildStage();
    s.episodes.seed([
      const ReflectionEpisode(
        id: 'ep',
        userId: 'u1',
        humanMoment: HumanMoment.celebration,
        state: ExperienceState.exploring,
        energy: CheckinEnergy.low,
        situationCode: 'C2-sit-01',
        patternsDone: [
          ReflectionPattern.notice,
          ReflectionPattern.name,
          ReflectionPattern.preserve,
        ],
        notes: {'notice': 'Tôi vừa nói ra được điều mình nghĩ.'},
      ),
    ]);
    tester.view.physicalSize = const Size(390, 900) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(s.app('/home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wr_home_resume_reflection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wr_flow_primary')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../screenshots/07_lua_chon.png'),
    );
  });
}
