// Màn Hôm nay dựng từ dữ liệu thật — không có chuỗi minh hoạ nào cứng trong mã.
//   • "Hệ thống nhận ra" đọc lại số lần lặp thật của người dùng
//   • "Gợi ý khi …" chọn story theo trụ SCA / nhu cầu đang nổi
//   • "Insight gần nhất" là câu người dùng đã xác nhận
// Run: flutter test test/features/wr_home_surface_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_mood_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_home_surface.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_wr_mood_content_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

WrSituation _sit(
  String code,
  String text, {
  ScaDimension dim = ScaDimension.c1,
  HumanNeed? need,
}) =>
    WrSituation(
      code: code,
      text: text,
      scaDimension: dim,
      wave: 1,
      humanNeed: need,
    );

/// [count] lần xuất hiện của [code] trong recentSituationIds.
List<String> _pattern(String code, int count) => List.filled(count, code);

/// [count] Episode đã chọn tình huống [code] — nguồn thật của
/// recentSituationIds (v2.0 §4.3). Trước đây các test này gieo
/// `wr_pattern_counts`; màn hình không còn đọc bảng đó nữa.
List<ReflectionEpisode> _episodes(String code, int count) => [
      for (var i = 0; i < count; i++)
        ReflectionEpisode(
          id: '\$code-\$i',
          userId: 'u1',
          humanMoment: HumanMoment.confusion,
          state: ExperienceState.integrated,
          situationCode: code,
          openedAt: DateTime(2026, 7, 1).add(Duration(hours: i)),
        ),
    ];

WrStory _story(
  String id,
  String title, {
  ScaDimension dim = ScaDimension.c1,
  HumanNeed? need,
  String content = 'một hai ba bốn năm',
}) =>
    WrStory(
      storyId: id,
      title: title,
      scaDimension: dim,
      humanNeed: need,
      storyContent: content,
      emotionTags: const [],
      behaviorTags: const [],
      careerStages: const [],
    );

CareerMemoryEvent _readEvent(String storyId) => CareerMemoryEvent(
      id: 'e-$storyId',
      userId: 'u1',
      storyId: storyId,
      createdAt: DateTime(2026, 7, 21),
    );

Widget _wrap({
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  FakeWrMoodContentRepository? moodContent,
  FakeWrRepository? repo,
  FakeWrEpisodeRepository? episodes,
}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
      GoRoute(
        path: '/wr/pattern/:code',
        builder: (_, s) =>
            Scaffold(body: Text('PATTERN ${s.pathParameters['code']}')),
      ),
      GoRoute(
        path: '/wr/mood-library',
        builder: (_, __) => const Scaffold(body: Text('THƯ VIỆN')),
      ),
      GoRoute(
        path: '/wr/mood-content/:id',
        builder: (_, s) =>
            Scaffold(body: Text('ĐỌC ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/wr/flow/moment',
        builder: (_, __) => const Scaffold(body: Text('MOMENT')),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider
          .overrideWithValue(content ?? FakeWrContentRepository()),
      wrIntelligenceRepositoryProvider
          .overrideWithValue(intel ?? FakeWrIntelligenceRepository()),
      wrMoodContentRepositoryProvider
          .overrideWithValue(moodContent ?? FakeWrMoodContentRepository()),
      wrRepositoryProvider.overrideWithValue(repo ?? FakeWrRepository()),
      wrEpisodeRepositoryProvider
          .overrideWithValue(episodes ?? FakeWrEpisodeRepository()),
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

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // Logic thuần
  // -------------------------------------------------------------------------

  group('systemNotice', () {
    final situations = [_sit('s1', 'Ngại phản biện với đồng nghiệp')];

    test('chưa lặp lại thì hệ thống chưa nhận ra gì', () {
      expect(
        systemNotice(recent: [..._pattern('s1', 1)], situations: situations),
        isNull,
      );
    });

    test('đủ ngưỡng thì đọc lại đúng con số', () {
      final n = systemNotice(
        recent: [..._pattern('s1', 5)],
        situations: situations,
      );
      expect(n, isNotNull);
      expect(n!.count, 5);
      expect(
        n.sentence,
        'Đây là lần thứ 5 bạn gặp tình huống '
        'ngại phản biện với đồng nghiệp.',
      );
    });

    test('tình huống vừa chọn chưa đủ ngưỡng thì lấy cái lặp nhiều nhất', () {
      final n = systemNotice(
        // s1 đứng đầu = vừa chọn, nhưng mới một lần.
        recent: ['s1', ..._pattern('s2', 7)],
        situations: [...situations, _sit('s2', 'Bị giao việc gấp')],
      );
      expect(n!.situationCode, 's2');
      expect(n.count, 7);
    });

    // Khách 2026-08-22: check-in xong, ghi tiếp một tình huống, mà thẻ vẫn đọc
    // tình huống của tuần trước chỉ vì nó nhiều lần hơn.
    test('tình huống vừa chọn đủ ngưỡng thì được ưu tiên dù ít lần hơn', () {
      final n = systemNotice(
        recent: ['s1', ..._pattern('s1', 1), ..._pattern('s2', 7)],
        situations: [...situations, _sit('s2', 'Bị giao việc gấp')],
      );
      expect(n!.situationCode, 's1');
      expect(n.count, 2);
    });

    // Nguyên tắc khách nói thẳng 2026-08-22: "hệ thống nhận ra là nhận diện
    // tình huống VỪA CHECK-IN". Dựng lại đúng dữ liệu tài khoản khách hôm đó.
    group('lọc theo cảm xúc vừa check-in', () {
      // P-08 trụ P-STEADY, ghi 3 lần tuần trước. C2-03 vừa ghi hôm nay, 1 lần.
      final khach = [
        _sit('C2-03', 'Tôi đồng ý dù trong lòng không đồng ý',
            dim: ScaDimension.c2),
        _sit('P-08', 'Tôi vừa học được một điều nhỏ nhưng hữu ích',
            dim: ScaDimension.pSteady),
      ];
      final lichSu = ['C2-03', ..._pattern('P-08', 3)];

      test('check-in căng thẳng thì im lặng, không đọc chuyện trụ P tuần trước',
          () {
        expect(
          systemNotice(
            recent: lichSu,
            situations: khach,
            mood: Mood.stressed,
          ),
          isNull,
          reason: 'stressed → A3+C2; trong cụm đó chưa mã nào lặp đủ 2 lần, '
              'nên im lặng đúng hơn là nói một chuyện ngược cảm xúc',
        );
      });

      test('check-in khá ổn thì đọc đúng tình huống trụ P đã lặp', () {
        final n = systemNotice(
          recent: lichSu,
          situations: khach,
          mood: Mood.okay,
        );
        expect(n!.situationCode, 'P-08');
        expect(n.count, 3);
      });

      test('không truyền cảm xúc thì giữ nguyên hành vi cũ', () {
        final n = systemNotice(recent: lichSu, situations: khach);
        expect(n!.situationCode, 'P-08');
      });
    });
  });

  group('readingMinutes', () {
    test('tối thiểu một phút', () {
      expect(readingMinutes('ngắn'), 1);
    });

    test('ước lượng theo số từ thật', () {
      final content = List.filled(kWordsPerMinute * 3, 'từ').join(' ');
      expect(readingMinutes(content), 3);
    });
  });

  group('suggestStory', () {
    test('không có story thì không gợi ý', () {
      expect(
        suggestStory(
          stories: const [],
          recent: const [],
          situations: const [],
          events: const [],
        ),
        isNull,
      );
    });

    test('ưu tiên story cùng trụ với tình huống đang lặp', () {
      final s = suggestStory(
        stories: [
          _story('st-a', 'Khác trụ', dim: ScaDimension.s1),
          _story('st-b', 'Cùng trụ', dim: ScaDimension.a2),
        ],
        recent: [..._pattern('s1', 4)],
        situations: [_sit('s1', 'Tình huống', dim: ScaDimension.a2)],
        events: const [],
      );
      expect(s!.story.storyId, 'st-b');
      expect(s.alreadyRead, isFalse);
    });

    test('bỏ qua story đã đọc', () {
      final s = suggestStory(
        stories: [
          _story('st-a', 'Đã đọc', dim: ScaDimension.a2),
          _story('st-b', 'Chưa đọc', dim: ScaDimension.a2),
        ],
        recent: [..._pattern('s1', 4)],
        situations: [_sit('s1', 'Tình huống', dim: ScaDimension.a2)],
        events: [_readEvent('st-a')],
      );
      expect(s!.story.storyId, 'st-b');
    });

    test('đọc hết rồi thì vẫn gợi lại, kèm dấu đã đọc', () {
      final s = suggestStory(
        stories: [_story('st-a', 'Đã đọc')],
        recent: const [],
        situations: const [],
        events: [_readEvent('st-a')],
      );
      expect(s!.story.storyId, 'st-a');
      expect(s.alreadyRead, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Màn Hôm nay
  // -------------------------------------------------------------------------

  group('Home — bố cục theo giao diện chính', () {
    testWidgets('chưa có dữ liệu thì ba khối dưới im lặng', (tester) async {
      await _pump(tester, _wrap());

      expect(find.text('Ngày hôm nay của bạn như thế nào?'), findsOneWidget);
      expect(find.byKey(const Key('wr_home_system_notice')), findsNothing);
      expect(find.byKey(const Key('wr_home_mood_content')), findsNothing);
      expect(find.byKey(const Key('wr_home_latest_insight')), findsNothing);
    });

    testWidgets('chưa check-in thì Hệ thống nhận ra chưa xuất hiện',
        (tester) async {
      // Họp khách 2026-07-29: màn Home lúc mở ra chỉ có ba việc. "Hệ thống nhận
      // ra" và "Gợi ý hôm nay" là hai thứ hiện SAU khi check-in xong.
      final content = FakeWrContentRepository()
        ..seedSituations([_sit('s1', 'Ngại phản biện với đồng nghiệp')]);
      final episodes = FakeWrEpisodeRepository()..seed(_episodes('s1', 5));

      await _pump(tester, _wrap(content: content, episodes: episodes));

      expect(find.byKey(const Key('wr_home_system_notice')), findsNothing);
    });

    // Khách báo 2026-08-22: check-in "đang căng thẳng" ngày 21/08 rồi rời màn
    // chọn tình huống, tin là đã ghi xong. DB ngày đó có check-in và không có
    // Episode nào, còn Home thì không nói gì.
    group('Còn dở', () {
      testWidgets('check-in rồi mà chưa mở phiên nào hôm nay thì Home nhắc',
          (tester) async {
        final repo = FakeWrRepository()
          ..seedTodayCheckin(_checkin(Mood.stressed));

        // `_episodes` mở ngày 2026-07-01 — có lịch sử, nhưng không phải hôm nay.
        final episodes = FakeWrEpisodeRepository()..seed(_episodes('s1', 3));

        await _pump(tester, _wrap(repo: repo, episodes: episodes));

        expect(
          find.byKey(const Key('wr_home_unfinished_reflection')),
          findsOneWidget,
        );
        expect(
          find.textContaining('chưa chọn điều muốn nhìn lại'),
          findsOneWidget,
        );
      });

      testWidgets('chưa check-in thì không nhắc', (tester) async {
        await _pump(tester, _wrap());

        expect(
          find.byKey(const Key('wr_home_unfinished_reflection')),
          findsNothing,
        );
      });

      testWidgets('đã mở phiên hôm nay thì thôi nhắc', (tester) async {
        final repo = FakeWrRepository()
          ..seedTodayCheckin(_checkin(Mood.stressed));
        final episodes = FakeWrEpisodeRepository()
          ..seed([
            ReflectionEpisode(
              id: 'hom-nay',
              userId: 'u1',
              humanMoment: HumanMoment.confusion,
              state: ExperienceState.integrated,
              situationCode: 's1',
              openedAt: DateTime.now().toUtc(),
            ),
          ]);

        await _pump(tester, _wrap(repo: repo, episodes: episodes));

        expect(
          find.byKey(const Key('wr_home_unfinished_reflection')),
          findsNothing,
        );
      });
    });

    testWidgets('Hệ thống nhận ra hiện đúng câu từ dữ liệu thật',
        (tester) async {
      final content = FakeWrContentRepository()
        // C2 để khớp cụm chiều của "căng thẳng" (A3+C2, §III) — từ 2026-08-22
        // thẻ chỉ đọc tình huống thuộc cảm xúc vừa check-in. Chiều này cũng
        // đúng với nội dung câu: né tránh lên tiếng.
        ..seedSituations([
          _sit('s1', 'Ngại phản biện với đồng nghiệp', dim: ScaDimension.c2),
        ]);
      final episodes = FakeWrEpisodeRepository()..seed(_episodes('s1', 5));
      final repo = FakeWrRepository()..seedTodayCheckin(_checkin(Mood.stressed));

      await _pump(
        tester,
        _wrap(content: content, episodes: episodes, repo: repo),
      );

      expect(find.byKey(const Key('wr_home_system_notice')), findsOneWidget);
      expect(find.text('HỆ THỐNG NHẬN RA'), findsOneWidget);
      expect(
        find.textContaining('lần thứ 5 bạn gặp tình huống'),
        findsOneWidget,
      );
    });

    testWidgets('Tìm hiểu thêm mở đúng màn chi tiết của tình huống đó',
        (tester) async {
      final content = FakeWrContentRepository()
        ..seedSituations([
          _sit('s1', 'Ngại phản biện', dim: ScaDimension.c2),
        ]);
      final episodes = FakeWrEpisodeRepository()..seed(_episodes('s1', 4));
      final repo = FakeWrRepository()..seedTodayCheckin(_checkin(Mood.stressed));

      await _pump(
        tester,
        _wrap(content: content, episodes: episodes, repo: repo),
      );
      await tester.tap(find.byKey(const Key('wr_home_notice_link')));
      await tester.pumpAndSettle();

      expect(find.text('PATTERN s1'), findsOneWidget);
    });

    testWidgets('chưa check-in thì khối Thư viện Cảm xúc im lặng',
        (tester) async {
      // §8.3: thẻ bám vào cảm xúc vừa check-in. Không có cảm xúc thì không có
      // gì để gợi ý — bịa một mục mặc định là sai tinh thần "đúng cảm giác
      // lúc này".
      final moodContent = FakeWrMoodContentRepository()
        ..seedContent([
          fakeMoodContent(id: 'm1', mood: Mood.stressed, title: 'Ba nhịp thở'),
        ]);

      await _pump(tester, _wrap(moodContent: moodContent));

      expect(find.byKey(const Key('wr_home_mood_content')), findsNothing);
    });

    testWidgets('khối gợi ý lấy đúng mục đầu tiên theo cảm xúc đã check-in',
        (tester) async {
      final repo = FakeWrRepository()..seedTodayCheckin(_checkin(Mood.stressed));
      final moodContent = FakeWrMoodContentRepository()
        ..seedContent([
          // sortOrder 2 nạp trước để chắc chắn thẻ chọn theo THỨ TỰ chứ không
          // phải theo thứ tự trả về của kho.
          fakeMoodContent(
            id: 'm2',
            mood: Mood.stressed,
            sortOrder: 2,
            title: 'Bài thứ hai',
          ),
          fakeMoodContent(
            id: 'm1',
            mood: Mood.stressed,
            sortOrder: 1,
            title: 'Ba nhịp thở trước khi phản hồi',
            kind: 'HEALING AUDIO',
            duration: '3 phút',
            type: MoodContentType.audio,
          ),
          fakeMoodContent(id: 'm9', mood: Mood.happy, title: 'Bài của vui'),
        ]);

      await _pump(tester, _wrap(moodContent: moodContent, repo: repo));

      expect(find.byKey(const Key('wr_home_mood_content')), findsOneWidget);
      expect(find.text('GỢI Ý KHI CĂNG THẲNG'), findsOneWidget);
      expect(find.text('Ba nhịp thở trước khi phản hồi'), findsOneWidget);
      expect(find.text('HEALING AUDIO · 3 phút'), findsOneWidget);
      // Không được lấy nhầm mục của cảm xúc khác.
      expect(find.text('Bài của vui'), findsNothing);
      expect(find.text('Bài thứ hai'), findsNothing);
    });

    testWidgets('nhãn thẻ đổi theo từng cảm xúc', (tester) async {
      // Người vừa chọn "đang vui" mà thấy "Gợi ý khi căng thẳng" thì thẻ mất
      // hết ý nghĩa.
      const expected = {
        Mood.stressed: 'GỢI Ý KHI CĂNG THẲNG',
        Mood.tired: 'GỢI Ý KHI MỆT MỎI',
        Mood.okay: 'GỢI Ý CHO HÔM NAY',
        Mood.happy: 'GIỮ LẠI CẢM XÚC NÀY',
      };

      for (final entry in expected.entries) {
        final repo = FakeWrRepository()..seedTodayCheckin(_checkin(entry.key));
        final moodContent = FakeWrMoodContentRepository()
          ..seedContent([fakeMoodContent(id: 'c', mood: entry.key)]);

        await _pump(tester, _wrap(moodContent: moodContent, repo: repo));
        expect(find.text(entry.value), findsOneWidget,
            reason: 'sai nhãn cho ${entry.key.name}');
      }
    });

    testWidgets('nội dung còn nháp hiện nhãn Nháp', (tester) async {
      // §8.2 + §XII.3: placeholder = true là chưa sẵn sàng phát hành.
      final repo = FakeWrRepository()..seedTodayCheckin(_checkin(Mood.okay));
      final moodContent = FakeWrMoodContentRepository()
        ..seedContent([
          fakeMoodContent(id: 'm1', mood: Mood.okay, placeholder: true),
        ]);

      await _pump(tester, _wrap(moodContent: moodContent, repo: repo));

      expect(find.text('Nháp'), findsOneWidget);
    });

    testWidgets('chạm thẻ mở đúng màn đọc của mục đó', (tester) async {
      final repo = FakeWrRepository()..seedTodayCheckin(_checkin(Mood.tired));
      final moodContent = FakeWrMoodContentRepository()
        ..seedContent([fakeMoodContent(id: 'abc', mood: Mood.tired)]);

      await _pump(tester, _wrap(moodContent: moodContent, repo: repo));
      await tester.tap(find.byKey(const Key('wr_home_mood_content_card')));
      await tester.pumpAndSettle();

      expect(find.text('ĐỌC abc'), findsOneWidget);
    });

    testWidgets('link Xem thêm mở màn Thư viện', (tester) async {
      final repo = FakeWrRepository()..seedTodayCheckin(_checkin(Mood.happy));
      final moodContent = FakeWrMoodContentRepository()
        ..seedContent([fakeMoodContent(id: 'm1', mood: Mood.happy)]);

      await _pump(tester, _wrap(moodContent: moodContent, repo: repo));
      await tester.tap(find.byKey(const Key('wr_home_mood_library_link')));
      await tester.pumpAndSettle();

      expect(find.text('THƯ VIỆN'), findsOneWidget);
    });

    testWidgets('Insight gần nhất hiện câu và ngày lưu thật', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedInsights([
          WrInsight(
            userId: 'u1',
            content: 'Tôi thường im lặng vì sợ phán xét.',
            createdAt: DateTime(2026, 6, 20),
          ),
        ]);

      await _pump(tester, _wrap(intel: intel));

      expect(find.byKey(const Key('wr_home_latest_insight')), findsOneWidget);
      expect(
        find.text('"Tôi thường im lặng vì sợ phán xét."'),
        findsOneWidget,
      );
      expect(find.text('Lưu ngày 20/06'), findsOneWidget);
    });
  });
}

/// Check-in hôm nay với [mood] — chỉ cần đúng trường `mood` cho các test thẻ
/// Thư viện Nội dung Cảm xúc.
Checkin _checkin(Mood mood) => Checkin(
      id: 'ck-1',
      userId: 'u1',
      mood: mood,
      checkinDate: DateTime(2026, 7, 28),
      createdAt: DateTime(2026, 7, 28),
    );
