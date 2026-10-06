// Hiểu mình + chi tiết điều lặp lại — ranh giới GHI NHẬN / DIỄN GIẢI.
//
// Yêu cầu khách 2026-07-27:
//   • tích lũy đủ (5 lần) mới đọc ra nguyên nhân sâu
//   • phần đọc ra nguyên nhân là Premium
//   • bản miễn phí chỉ xem thông tin ghi nhận hành trình đã làm
//
// Bố cục tab theo mockup v47 (06/10): hero → thẻ đầu trang hỏi "có đúng với
// bạn không" → "Những vòng lặp quen thuộc" (chạm mở từng lần) → lời mời
// Self-Check → "Xem theo nhóm trải nghiệm" (thu gọn, mở ra mới thấy Career
// Snapshot) → thẻ navy "Diễn giải sâu & xu hướng" luôn hiện.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';

import 'package:workreflection_mobile/core/logic/wr_sca_deep_dive.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_pattern_detail_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_patterns_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

const _sit = WrSituation(
  code: 'sit-01',
  text: 'Không được lắng nghe trong họp',
  scaDimension: ScaDimension.c1,
  wave: 1,
  humanNeed: HumanNeed.ketNoi,
  pillarCode: 'C',
  subgroup: 'C1',
  mood: 'stress',
  valence: WrValence.thachThuc,
);

/// Tình huống thuộc một chiều SCA bất kỳ — dùng cho các ca cần cả ba trụ.
WrSituation _sitOf(String code, ScaDimension dim, {String? pillar}) {
  final resolvedPillar =
      pillar ??
      switch (dim) {
        ScaDimension.s1 || ScaDimension.s2 || ScaDimension.s3 => 'S',
        ScaDimension.c1 || ScaDimension.c2 || ScaDimension.c3 => 'C',
        _ => 'A',
      };
  final resolvedSubgroup = switch (dim) {
    ScaDimension.s1 || ScaDimension.s3 => 'S1',
    ScaDimension.s2 => 'S2',
    ScaDimension.c1 || ScaDimension.c3 => 'C1',
    ScaDimension.c2 => 'C2',
    ScaDimension.a3 => 'A3',
    ScaDimension.pAchieve || ScaDimension.pSteady => switch (resolvedPillar) {
      'S' => 'Sp',
      'C' => 'Cp',
      _ => 'Ap',
    },
    _ => 'A1',
  };
  final resolvedMood = switch (dim) {
    ScaDimension.s1 => 'foggy',
    ScaDimension.s2 => 'outofsync',
    ScaDimension.a1 ||
    ScaDimension.a2 ||
    ScaDimension.a3 ||
    ScaDimension.a4 => 'tired',
    ScaDimension.pAchieve => 'happy',
    ScaDimension.pSteady => 'ok',
    _ => 'stress',
  };
  return WrSituation(
    code: code,
    text: code,
    scaDimension: dim,
    // Bảng §2.1 của `DienGiaiSau v2` gán trụ CẮT NGANG hai nhóm P, nên trụ
    // của tình huống tích cực không suy được từ [dim] — phải nói thẳng ra.
    pillarCode: resolvedPillar,
    subgroup: resolvedSubgroup,
    mood: resolvedMood,
    valence: dim.isPositive ? WrValence.tichCuc : WrValence.thachThuc,
    wave: 1,
  );
}

PatternCount _pattern(int count) => PatternCount(
  id: 'p1',
  userId: 'u1',
  situationCode: 'sit-01',
  scaDimension: ScaDimension.c1,
  occurrenceCount: count,
  lastSeenAt: DateTime(2026, 7, 26),
);

/// Episode mang mã tình huống, mỗi mã lặp đúng số lần yêu cầu.
///
/// Từ 2026-07-31 mọi khối "đang phản chiếu về điều gì" đọc recentSituationIds —
/// tức chính bảng Episode (Kiến trúc v2.0 §4.3) — nên test phải gieo Episode
/// thật thay vì gieo con số tích luỹ trong `wr_pattern_counts`.
///
/// `openedAt` là mốc sắp xếp: recentSituationIds tính từ lúc CHỌN tình huống.
List<ReflectionEpisode> _episodes(
  Map<String, int> countByCode, {
  DateTime? from,
}) {
  final base = from ?? DateTime(2026, 7, 20);
  final list = <ReflectionEpisode>[];
  var i = 0;
  countByCode.forEach((code, times) {
    for (var k = 0; k < times; k++) {
      i++;
      list.add(
        ReflectionEpisode(
          id: 'e\${base.month}\${base.day}-\$i',
          userId: 'u1',
          humanMoment: HumanMoment.confusion,
          state: ExperienceState.integrated,
          situationCode: code,
          openedAt: base.add(Duration(hours: i)),
          closedAt: base.add(Duration(hours: i)),
        ),
      );
    }
  });
  return list;
}

Widget _wrap(
  Widget child, {
  required FakeWrIntelligenceRepository intel,
  required FakeWrContentRepository content,
  FakeWrEpisodeRepository? episodes,
}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, __) => child),
      GoRoute(
        path: '/wr/pattern/:code',
        builder: (_, s) => WrPatternDetailScreen(
          situationCode: s.pathParameters['code'] ?? '',
        ),
      ),
      GoRoute(
        path: '/wr/patterns',
        builder: (_, __) => const WrPatternsScreen(),
      ),
      GoRoute(
        path: '/wr/self-check',
        builder: (_, __) => const Scaffold(body: Text('SELFCHECK')),
      ),
      GoRoute(
        path: '/wr/growth',
        builder: (_, __) => const Scaffold(body: Text('GROWTH')),
      ),
      GoRoute(
        path: '/wr/sca-deep-dive',
        builder: (_, __) => const Scaffold(body: Text('SCADEEP')),
      ),
      GoRoute(
        path: '/wr/paywall',
        // In ra trigger để test khẳng định paywall được gọi đúng ngữ cảnh.
        builder: (_, s) => Scaffold(
          body: Text('PAYWALL:${s.uri.queryParameters['trigger'] ?? ''}'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
      wrContentRepositoryProvider.overrideWithValue(content),
      wrEpisodeRepositoryProvider.overrideWithValue(
        episodes ?? FakeWrEpisodeRepository(),
      ),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: router,
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/// Cuộn tới rồi mới chạm — màn là một `ListView`, chạm trượt ra ngoài khung
/// thì test vẫn xanh mà chẳng kiểm được gì.
Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// v47: "Xem theo nhóm trải nghiệm" thu gọn sẵn — phải mở ra mới thấy Career
/// Snapshot.
Future<void> _openSnapshot(WidgetTester tester) =>
    _tapKey(tester, 'wr_discover_snapshot_toggle');

/// Những dòng mang [text] trong phần mở ra của một vòng lặp.
Finder _logEntries(String code, String text) => find.descendant(
  of: find.byKey(Key('wr_discover_loop_log_$code')),
  matching: find.text(text),
);

const _noNote = 'Bạn không viết gì lần này';

void main() {
  // Câu trả lời "có đúng với bạn không" được nhớ trong SharedPreferences —
  // mỗi test bắt đầu từ kho rỗng để không ăn theo câu trả lời của test trước.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Hiểu mình — chỉ ghi nhận', () {
    testWidgets('liệt kê điều lặp lại kèm số lần, không diễn giải', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      // Hero v47 thay đầu màn "Career Snapshot" cũ.
      expect(find.byKey(const Key('wr_discover_hero')), findsOneWidget);
      expect(find.text('Những điều đang lặp lại'), findsOneWidget);

      // Thẻ đầu trang: tên tình huống trong ngoặc kép + đúng con số.
      expect(find.text('“Không được lắng nghe trong họp”'), findsOneWidget);
      expect(find.text('3 lần trong 3 lần ghi nhận'), findsOneWidget);
      // Dòng trong "Những vòng lặp quen thuộc".
      expect(find.text('Không được lắng nghe trong họp'), findsOneWidget);
      expect(find.text('3 lần'), findsOneWidget);

      // v47 bỏ hẳn khối đọc vị nhu cầu "Điều bạn đang tìm kiếm" khỏi tab —
      // thẻ đầu trang thay đúng chỗ của nó.
      expect(find.byKey(const Key('wr_discover_need_lock')), findsNothing);
      expect(find.byKey(const Key('wr_discover_need_reading')), findsNothing);
      expect(find.byKey(const Key('wr_discover_seeking')), findsNothing);
      expect(find.text('Mở phần đọc vị'), findsNothing);
      expect(find.text('KẾT NỐI · Nhu cầu chủ đạo'), findsNothing);
      // Không có câu diễn giải riêng cho người này ở tầng danh sách.
      expect(find.textContaining('ĐIỀU ĐỨNG SAU'), findsNothing);
    });

    // 'bấm mở phần đọc vị thì paywall nói đúng ngữ cảnh' đã bỏ: v47 gỡ khối
    // đọc vị nhu cầu khỏi tab, không còn nút "Mở phần đọc vị" để bấm.

    testWidgets('chưa có dữ liệu thì mời nhìn lại, không dựng thẻ vòng lặp '
        'rỗng', (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );

      expect(
        find.byKey(const Key('wr_discover_patterns_empty')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_discover_loops')), findsNothing);
      // Chưa có gì thì cũng không hỏi "có đúng với bạn không".
      expect(find.byKey(const Key('wr_discover_feedback_yes')), findsNothing);
      expect(find.byKey(const Key('wr_discover_top_count')), findsNothing);
    });

    testWidgets('premium cũng chỉ thấy ghi nhận, không còn câu nhu cầu hay câu '
        'aha nào trên tab', (tester) async {
      // Ba test cũ của khối "Điều bạn đang tìm kiếm" (câu nhu cầu, chặn câu
      // aha của story, nhu cầu khi thiếu nội dung) gộp về đây: v47 bỏ cả khối,
      // nên điều còn phải giữ là KHÔNG câu diễn giải nào rò lên tab.
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        );
      final content = FakeWrContentRepository()
        ..seedSituations([
          const WrSituation(
            code: 'sit-01',
            text: 'Không được lắng nghe trong họp',
            scaDimension: ScaDimension.c1,
            wave: 1,
            humanNeed: HumanNeed.ketNoi,
            expectedOutcome: 'Tôi muốn nói ra mà vẫn thấy an toàn',
            pillarCode: 'C',
            subgroup: 'C1',
            mood: 'stress',
            valence: WrValence.thachThuc,
          ),
        ])
        ..seedStories([
          const WrStory(
            storyId: 'sit-01',
            title: 'Không được lắng nghe trong họp',
            scaDimension: ScaDimension.c1,
            storyContent: 'nội dung',
            emotionTags: [],
            behaviorTags: [],
            careerStages: [],
            ahaMessage: 'Im lặng không phải vì bạn\nkhông có gì để nói.',
          ),
        ]);
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.byKey(const Key('wr_discover_need_reading')), findsNothing);
      expect(
        find.textContaining('Được lắng nghe và thể hiện quan điểm'),
        findsNothing,
      );
      expect(find.textContaining('Tôi muốn nói ra mà vẫn'), findsNothing);
      expect(find.textContaining('Im lặng không phải vì bạn'), findsNothing);

      // Ba khối diễn giải gán cứng đã bỏ.
      expect(find.text('MONG ĐỢI KẾT QUẢ'), findsNothing);
      expect(find.text('NHU CẦU CỐT LÕI'), findsNothing);
      expect(find.textContaining('GÓC NHÌN'), findsNothing);

      expect(find.textContaining('SCA'), findsNothing);
      expect(find.textContaining('sit-01'), findsNothing);
    });

    testWidgets('đếm số lần đã nhìn lại từ lịch sử Episode', (tester) async {
      // Con số này giờ chỉ còn một chỗ hiện: thẻ Career Snapshot. Mục "Hành
      // trình đã đi" ở cuối màn đã bỏ vì nói lại đúng con số đó.
      final episodes = FakeWrEpisodeRepository()
        ..seed([
          const ReflectionEpisode(
            id: 'e1',
            userId: 'u1',
            humanMoment: HumanMoment.confusion,
            state: ExperienceState.integrated,
          ),
          const ReflectionEpisode(
            id: 'e2',
            userId: 'u1',
            humanMoment: HumanMoment.recovery,
            state: ExperienceState.integrated,
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      // Career Snapshot nói còn thiếu bao nhiêu lần nữa thì cột "Xuất hiện"
      // mở ra — 15 − 2 = 13.
      expect(
        find.textContaining('sẽ mở sau 13 lần nhìn lại nữa'),
        findsOneWidget,
      );
    });

    testWidgets('bấm một dòng mở ra từng lần ngay tại chỗ, bấm lần nữa thì '
        'thu lại', (tester) async {
      // v47: dòng vòng lặp không còn đẩy sang màn chi tiết — nó xổ ra ngay
      // dưới, liệt kê từng lần.
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      expect(
        find.byKey(const Key('wr_discover_loop_log_sit-01')),
        findsNothing,
      );

      await _tapKey(tester, 'wr_discover_loop_sit-01');

      // Vẫn ở tab này, không rơi sang màn chi tiết.
      expect(find.byType(WrPatternDetailScreen), findsNothing);
      expect(
        find.byKey(const Key('wr_discover_loop_log_sit-01')),
        findsOneWidget,
      );
      // Ba lần, cả ba không có chữ kể lại → ba dòng "không viết gì", mỗi dòng
      // kèm ngày dd/MM.
      expect(_logEntries('sit-01', _noNote), findsNWidgets(3));
      expect(_logEntries('sit-01', '20/07'), findsNWidgets(3));

      await _tapKey(tester, 'wr_discover_loop_sit-01');
      expect(
        find.byKey(const Key('wr_discover_loop_log_sit-01')),
        findsNothing,
      );
    });

    // Lỗi khách báo 2026-08-01: ngoài ghi "4 lần", bấm vào thì đầu màn ghi
    // "5 lần" mà bên dưới chỉ có 4 mục. Trên tài khoản thật, `wr_pattern_counts`
    // của A1-01 = 5 trong khi chỉ có 4 Episode — chênh vì một Episode được khép
    // hai lần (mở lại rồi xác nhận Ý nghĩa lần nữa cộng thêm một).
    //
    // Test gieo đúng thế lệch đó: bảng cũ nói 5, Episode nói 4. Ở v47 ba con
    // số phải khớp là: thẻ đầu trang, pill "N lần", và số mục khi mở dòng ra.
    testWidgets(
      'số ngoài màn, số trong màn và số mục liệt kê — cùng một con số',
      (tester) async {
        final intel = FakeWrIntelligenceRepository()
          ..seedPatternCounts([_pattern(5)]);
        final content = FakeWrContentRepository()..seedSituations([_sit]);
        final episodes = FakeWrEpisodeRepository()
          ..seed(_episodes({'sit-01': 4}));

        await _pump(
          tester,
          _wrap(
            const WrDiscoverScreen(),
            intel: intel,
            content: content,
            episodes: episodes,
          ),
        );

        expect(find.text('4 lần'), findsOneWidget);
        expect(find.text('5 lần'), findsNothing);
        expect(find.text('4 lần trong 4 lần ghi nhận'), findsOneWidget);

        await _tapKey(tester, 'wr_discover_loop_sit-01');

        // Và đúng bằng số mục thật sự liệt kê bên dưới — chỗ mà người dùng đếm
        // được bằng mắt và bắt được sự mâu thuẫn.
        expect(_logEntries('sit-01', _noNote), findsNWidgets(4));

        // Màn chi tiết vẫn còn (mở từ màn danh sách đầy đủ) và cũng phải nói 4.
        await tester.pumpWidget(
          _wrap(
            const WrPatternDetailScreen(situationCode: 'sit-01'),
            intel: intel,
            content: content,
            episodes: episodes,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã ghi lại điều này 4 lần.'), findsOneWidget);
        expect(find.text('Bạn đã ghi lại điều này 5 lần.'), findsNothing);
        expect(find.text('Có gì đó chưa ổn'), findsNWidgets(4));
      },
    );
  });

  // Trước v47: màn ngoài chỉ ba dòng, phần còn lại sau "Xem thêm" (khách
  // 2026-07-29). Mockup v47 bày đủ mọi tình huống lặp lại trong thẻ "Những
  // vòng lặp quen thuộc", mỗi dòng tự xổ ra — không còn lối sang màn khác.
  group('Hiểu mình — vòng lặp quen thuộc', () {
    List<PatternCount> manyPatterns(int n) => [
      for (var i = 0; i < n; i++)
        PatternCount(
          id: 'p$i',
          userId: 'u1',
          situationCode: 'sit-0$i',
          scaDimension: ScaDimension.c1,
          occurrenceCount: 10 - i,
          lastSeenAt: DateTime(2026, 7, 26),
        ),
    ];

    List<WrSituation> manySituations(int n) => [
      for (var i = 0; i < n; i++)
        WrSituation(
          code: 'sit-0$i',
          text: 'Tình huống số $i',
          scaDimension: ScaDimension.c1,
          wave: 1,
          humanNeed: HumanNeed.ketNoi,
          pillarCode: 'C',
          subgroup: 'C1',
          mood: 'stress',
          valence: WrValence.thachThuc,
        ),
    ];

    testWidgets('bốn tình huống lặp lại thì hiện đủ cả bốn, không còn Xem '
        'thêm', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts(manyPatterns(6));
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(6));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-00': 4, 'sit-01': 4, 'sit-02': 3, 'sit-03': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.byKey(const Key('wr_discover_loops')), findsOneWidget);
      expect(find.text('NHỮNG VÒNG LẶP QUEN THUỘC'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(
          find.byKey(Key('wr_discover_loop_sit-0$i')),
          findsOneWidget,
          reason: 'thiếu dòng $i — v47 không còn chặn ở ba dòng',
        );
        expect(find.text('Tình huống số $i'), findsOneWidget);
      }
      // Hai tình huống chưa từng được chọn thì không có dòng.
      expect(find.byKey(const Key('wr_discover_loop_sit-04')), findsNothing);
      expect(find.byKey(const Key('wr_discover_see_more')), findsNothing);
      expect(find.textContaining('Xem thêm'), findsNothing);
      expect(find.byType(WrPatternRow), findsNothing);
    });

    testWidgets('dưới ngưỡng lặp thì chưa lên bảng', (tester) async {
      // Ngưỡng là HAI lần (họp 26_1 hạ từ 3 xuống 2). Gặp đúng một lần là
      // chuyện vừa xảy ra, chưa phải nếp — để lọt lên thì bảng toàn dòng "1
      // lần" và điều đang thật sự trở đi trở lại chìm mất.
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(3));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-00': 3, 'sit-01': 1, 'sit-02': 1}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.byKey(const Key('wr_discover_loop_sit-00')), findsOneWidget);
      expect(find.byKey(const Key('wr_discover_loop_sit-01')), findsNothing);
      expect(find.byKey(const Key('wr_discover_loop_sit-02')), findsNothing);
      expect(find.text('Tình huống số 1'), findsNothing);
      expect(find.text('Tình huống số 2'), findsNothing);
      // Mẫu số của thẻ đầu trang vẫn là MỌI lượt có mã trong cửa sổ — kể cả
      // hai lượt chưa đủ ngưỡng — vì đó là số lần nhìn lại thật.
      expect(find.text('3 lần trong 5 lần ghi nhận'), findsOneWidget);
    });

    testWidgets('đã ghi lại nhưng chưa điều nào tới ngưỡng: nói rõ, '
        'không báo rỗng như chưa từng ghi', (tester) async {
      // Hai trạng thái rỗng khác hẳn nhau. Đọc phải câu "sau vài lần nhìn lại"
      // sau khi đã phản tư mấy lần thì người dùng tưởng app nuốt mất dữ liệu.
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(2));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-00': 1, 'sit-01': 1}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.byKey(const Key('wr_discover_patterns_empty')), findsNothing);
      expect(
        find.byKey(const Key('wr_discover_patterns_below_threshold')),
        findsOneWidget,
      );
      expect(find.textContaining('2 lần'), findsOneWidget);
      // Không có gì lặp thì không dựng thẻ vòng lặp rỗng.
      expect(find.byKey(const Key('wr_discover_loops')), findsNothing);
    });

    testWidgets('chỉ đếm trong 30 lần nhìn lại gần nhất', (tester) async {
      // Tình huống cũ lặp 3 lần nhưng đã bị 30 lượt mới hơn đẩy ra khỏi cửa sổ
      // thì biến mất khỏi tấm gương — màn này soi hiện tại, không soi lịch sử.
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(3));
      final episodes = FakeWrEpisodeRepository()
        ..seed([
          ..._episodes({'sit-02': 3}, from: DateTime(2026, 6, 1)),
          ..._episodes({
            'sit-00': 16,
            'sit-01': 14,
          }, from: DateTime(2026, 8, 1)),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.text('Tình huống số 0'), findsOneWidget);
      expect(find.text('Tình huống số 1'), findsOneWidget);
      expect(find.text('Tình huống số 2'), findsNothing);
      // Thẻ đầu trang nói đúng cửa sổ: 30, không phải 33.
      expect(
        find.textContaining('Trong 30 lần nhìn lại gần đây'),
        findsOneWidget,
      );
      expect(find.text('16 lần trong 30 lần ghi nhận'), findsOneWidget);
    });

    // 'đúng ba tình huống thì không hiện lối xem thêm' đã bỏ: v47 không còn
    // lối "Xem thêm" nào để ẩn hay hiện.

    testWidgets('mở dòng thứ hai thì dòng đang mở thu lại', (tester) async {
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(2));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-00': 3, 'sit-01': 2}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      await _tapKey(tester, 'wr_discover_loop_sit-00');
      expect(_logEntries('sit-00', _noNote), findsNWidgets(3));

      await _tapKey(tester, 'wr_discover_loop_sit-01');
      expect(
        find.byKey(const Key('wr_discover_loop_log_sit-00')),
        findsNothing,
      );
      expect(_logEntries('sit-01', _noNote), findsNWidgets(2));
    });

    testWidgets('mỗi lần hiện ngày và đúng câu người dùng đã kể ở bước 2', (
      tester,
    ) async {
      // Câu lấy từ `notes['explore']` — ô "Kể lại khoảnh khắc" của luồng nhìn
      // lại. Lần nào bỏ trống thì nói thẳng là không viết gì, không bịa câu.
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed([
          ReflectionEpisode(
            id: 'n1',
            userId: 'u1',
            humanMoment: HumanMoment.confusion,
            state: ExperienceState.integrated,
            situationCode: 'sit-01',
            notes: const {'explore': 'Sếp cắt lời khi tôi vừa mở miệng'},
            openedAt: DateTime(2026, 7, 15, 9),
          ),
          ReflectionEpisode(
            id: 'n2',
            userId: 'u1',
            humanMoment: HumanMoment.confusion,
            state: ExperienceState.integrated,
            situationCode: 'sit-01',
            // Chỉ toàn khoảng trắng cũng là không viết gì.
            notes: const {'explore': '   '},
            openedAt: DateTime(2026, 7, 3, 9),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      await _tapKey(tester, 'wr_discover_loop_sit-01');

      expect(
        _logEntries('sit-01', '“Sếp cắt lời khi tôi vừa mở miệng”'),
        findsOneWidget,
      );
      expect(_logEntries('sit-01', _noNote), findsOneWidget);
      expect(_logEntries('sit-01', '15/07'), findsOneWidget);
      expect(_logEntries('sit-01', '03/07'), findsOneWidget);
    });

    testWidgets('màn danh sách đầy đủ vẫn liệt kê đủ, vẫn không diễn giải', (
      tester,
    ) async {
      // Tab không còn trỏ sang `/wr/patterns`, nhưng màn đó vẫn sống (màn
      // Diễn giải sâu còn dùng) — mở thẳng để giữ hợp đồng của nó.
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts(manyPatterns(6));
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(6));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-00': 4, 'sit-01': 4, 'sit-02': 3, 'sit-03': 3}));

      await _pump(
        tester,
        _wrap(
          const WrPatternsScreen(),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      for (var i = 0; i < 4; i++) {
        expect(
          find.text('Tình huống số $i'),
          findsOneWidget,
          reason: 'thiếu dòng $i ở màn đầy đủ',
        );
      }
      expect(find.textContaining('ĐIỀU ĐỨNG SAU'), findsNothing);

      // Từ đây vẫn mở được chi tiết của từng dòng, và con số ở đó phải bằng
      // đúng con số dòng vừa bấm.
      //
      // Trước 2026-08-01 màn chi tiết đọc `wr_pattern_counts` với lý do "đã ghi
      // lại bao nhiêu lần là câu hỏi về cả chặng đường". Lý do nghe được, nhưng
      // bảng đó cộng ở bước KHÉP nên mở lại một Episode đã khép rồi xác nhận Ý
      // nghĩa lần nữa là cộng thêm một — nó không dài hơn vì nhớ xa hơn, nó dài
      // hơn vì đếm trùng. Kết quả trên máy khách: ngoài ghi 4, mở ra ghi 5,
      // trong khi chính màn đó chỉ liệt kê được 4 mục.
      await _tapKey(tester, 'wr_patterns_row_sit-03');
      expect(find.text('Bạn đã ghi lại điều này 3 lần.'), findsOneWidget);
    });
  });

  // Thẻ đầu trang v47: "Trong N lần nhìn lại gần đây, điều quay lại với bạn
  // nhiều nhất là …" rồi hỏi lại người dùng. Câu trả lời nhớ theo người dùng
  // + tình huống để lần sau mở tab không hỏi lại.
  group('Hiểu mình — thẻ đầu trang hỏi "có đúng với bạn không"', () {
    FakeWrContentRepository twoSituations() =>
        FakeWrContentRepository()
          ..seedSituations([_sit, _sitOf('sit-02', ScaDimension.c2)]);

    FakeWrEpisodeRepository threeAndTwo() =>
        FakeWrEpisodeRepository()..seed(_episodes({'sit-01': 3, 'sit-02': 2}));

    Widget app(FakeWrEpisodeRepository episodes) => _wrap(
      const WrDiscoverScreen(),
      intel: FakeWrIntelligenceRepository(),
      content: twoSituations(),
      episodes: episodes,
    );

    testWidgets('nói đúng mẫu số, tình huống nhiều nhất và hỏi lại', (
      tester,
    ) async {
      await _pump(tester, app(threeAndTwo()));

      expect(
        find.text(
          'Trong 5 lần nhìn lại gần đây, điều quay lại với bạn nhiều nhất là',
        ),
        findsOneWidget,
      );
      final title = tester.widget<Text>(
        find.byKey(const Key('wr_discover_top_title')),
      );
      expect(title.data, '“Không được lắng nghe trong họp”');
      final count = tester.widget<Text>(
        find.byKey(const Key('wr_discover_top_count')),
      );
      expect(count.data, '3 lần trong 5 lần ghi nhận');

      expect(find.text('Điều này có đúng với bạn không?'), findsOneWidget);
      expect(find.text('Đúng với tôi'), findsOneWidget);
      expect(find.text('Chưa đúng lắm'), findsOneWidget);
    });

    testWidgets('trả lời Đúng: mời sang chủ đề thực hành, nhớ câu trả lời', (
      tester,
    ) async {
      await _pump(tester, app(threeAndTwo()));

      await _tapKey(tester, 'wr_discover_feedback_yes');

      expect(
        find.textContaining('Vậy thì đây có thể là chỗ đáng'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_discover_feedback_yes')), findsNothing);
      expect(find.byKey(const Key('wr_discover_feedback_no')), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wr_pattern_feedback_u1_sit-01'), 'yes');

      await _tapKey(tester, 'wr_discover_feedback_practice');
      expect(find.text('GROWTH'), findsOneWidget);
    });

    testWidgets('trả lời Chưa đúng: đưa các điều lặp lại khác để chọn', (
      tester,
    ) async {
      await _pump(tester, app(threeAndTwo()));

      await _tapKey(tester, 'wr_discover_feedback_no');

      expect(find.textContaining('Cảm ơn bạn đã cho biết'), findsOneWidget);
      // Chỉ những điều KHÁC điều đầu trang — không mời chọn lại chính nó.
      expect(
        find.byKey(const Key('wr_discover_feedback_alt_sit-02')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wr_discover_feedback_alt_sit-01')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('wr_discover_feedback_none')),
        findsOneWidget,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wr_pattern_feedback_u1_sit-01'), 'no');

      // Chọn một điều khác → sang phần mời thực hành.
      await _tapKey(tester, 'wr_discover_feedback_alt_sit-02');
      expect(
        find.textContaining('Vậy thì đây có thể là chỗ đáng'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wr_discover_feedback_practice')),
        findsOneWidget,
      );
      // Câu "Chưa đúng" cho điều đầu trang KHÔNG bị ghi đè thành "yes": người
      // dùng vừa nói nó chưa đúng.
      expect(prefs.getString('wr_pattern_feedback_u1_sit-01'), 'no');
    });

    testWidgets('"Không có điều nào ở trên" cũng khép câu hỏi', (tester) async {
      await _pump(tester, app(threeAndTwo()));

      await _tapKey(tester, 'wr_discover_feedback_no');
      await _tapKey(tester, 'wr_discover_feedback_none');

      expect(
        find.byKey(const Key('wr_discover_feedback_practice')),
        findsOneWidget,
      );
      expect(find.textContaining('Cảm ơn bạn đã cho biết'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wr_pattern_feedback_u1_sit-01'), 'no');
    });

    testWidgets('mở lại tab thì hiện đúng câu đã trả lời, không hỏi lại', (
      tester,
    ) async {
      final episodes = threeAndTwo();
      await _pump(tester, app(episodes));
      await _tapKey(tester, 'wr_discover_feedback_no');

      // Dựng lại từ đầu — ProviderScope mới, State mới — chỉ còn kho
      // SharedPreferences mang câu trả lời qua.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(episodes));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cảm ơn bạn đã cho biết'), findsOneWidget);
      expect(find.byKey(const Key('wr_discover_feedback_yes')), findsNothing);
    });

    testWidgets('câu trả lời đã lưu "yes" thì vào thẳng phần mời thực hành', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'wr_pattern_feedback_u1_sit-01': 'yes',
      });
      await _pump(tester, app(threeAndTwo()));

      expect(
        find.byKey(const Key('wr_discover_feedback_practice')),
        findsOneWidget,
      );
      expect(find.text('Điều này có đúng với bạn không?'), findsNothing);
    });

    testWidgets('câu trả lời nhớ theo TỪNG tình huống và từng người dùng', (
      tester,
    ) async {
      // Đã trả lời cho sit-02, và một người khác đã trả lời cho sit-01: điều
      // đầu trang của u1 là sit-01 nên vẫn phải hỏi.
      SharedPreferences.setMockInitialValues({
        'wr_pattern_feedback_u1_sit-02': 'yes',
        'wr_pattern_feedback_u2_sit-01': 'no',
      });
      await _pump(tester, app(threeAndTwo()));

      expect(find.text('Điều này có đúng với bạn không?'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_discover_feedback_practice')),
        findsNothing,
      );
      expect(find.textContaining('Cảm ơn bạn đã cho biết'), findsNothing);
    });
  });

  // v1.6 §XII.5: mã nội bộ (sit-01, C2-sit-01…) không bao giờ được hiện ra.
  // Đường lộ thật là lúc thư viện tình huống chưa tải xong hoặc mất mạng —
  // trước bản vá này, mỗi dòng hiện đúng cái mã.
  group('Hiểu mình — không phơi mã kỹ thuật', () {
    testWidgets(
      'thiếu thư viện tình huống thì hiện nhãn chung, không hiện mã',
      (tester) async {
        final intel = FakeWrIntelligenceRepository()
          ..seedPatternCounts([_pattern(3)]);
        // Thư viện rỗng: đúng cảnh mất mạng.
        final content = FakeWrContentRepository();
        final episodes = FakeWrEpisodeRepository()
          ..seed(_episodes({'sit-01': 3}));

        await _pump(
          tester,
          _wrap(
            const WrDiscoverScreen(),
            intel: intel,
            content: content,
            episodes: episodes,
          ),
        );

        expect(find.textContaining('sit-01'), findsNothing);
        expect(find.text('“Tình huống”'), findsOneWidget); // thẻ đầu trang
        expect(find.text('Tình huống'), findsOneWidget); // dòng vòng lặp
        expect(find.text('3 lần'), findsOneWidget);
      },
    );

    testWidgets('mở dòng và các lựa chọn "điều khác" cũng không rơi về mã', (
      tester,
    ) async {
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3, 'sit-02': 2}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
          episodes: episodes,
        ),
      );

      await _tapKey(tester, 'wr_discover_loop_sit-02');
      await _tapKey(tester, 'wr_discover_feedback_no');

      expect(
        find.byKey(const Key('wr_discover_feedback_alt_sit-02')),
        findsOneWidget,
      );
      expect(find.textContaining('sit-0'), findsNothing);
    });

    testWidgets('màn chi tiết cũng không rơi về mã', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(3)]);

      await _pump(
        tester,
        _wrap(
          const WrPatternDetailScreen(situationCode: 'sit-01'),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );

      expect(find.textContaining('sit-01'), findsNothing);
    });
  });

  // Bố cục theo giao-dien-chinh.html §screen-understand — nhưng mọi con số và
  // trạng thái đều đọc từ dữ liệu thật, không có dòng minh hoạ nào cứng.
  // Career Snapshot — MỘT khối, mỗi trụ đúng một dòng, hai nguồn đặt cạnh nhau
  // (Changelog_CareerSnapshot.docx §3). Thay hẳn hai khối cũ "Trải nghiệm hiện
  // tại" và "Career Health Check", vốn in cùng ba trụ hai lần với hai kết luận
  // ngược nhau.
  //
  // v47: khối nằm sau "Xem theo nhóm trải nghiệm", thu gọn sẵn — mỗi test mở
  // nó ra trước khi đọc.
  group('Hiểu mình — Career Snapshot', () {
    testWidgets('mặc định thu gọn, chạm "Xem theo nhóm trải nghiệm" mới mở', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );

      expect(
        find.byKey(const Key('wr_discover_snapshot_toggle')),
        findsOneWidget,
      );
      expect(find.text('Xem theo nhóm trải nghiệm'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_discover_career_snapshot')),
        findsNothing,
      );
      expect(find.text('CAREER SNAPSHOT'), findsNothing);

      await _openSnapshot(tester);
      expect(
        find.byKey(const Key('wr_discover_career_snapshot')),
        findsOneWidget,
      );

      // Chạm lần nữa thì thu lại.
      await _openSnapshot(tester);
      expect(
        find.byKey(const Key('wr_discover_career_snapshot')),
        findsNothing,
      );
    });

    testWidgets('chưa tự đánh giá thì cột trái mời làm, không khoá', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );
      await _openSnapshot(tester);

      expect(find.text('CAREER SNAPSHOT'), findsOneWidget);
      // Hai khối cũ không còn tồn tại — đây là điều kiện để mâu thuẫn biến mất.
      expect(find.text('TRẢI NGHIỆM HIỆN TẠI'), findsNothing);
      expect(find.text('Career Health Check'), findsNothing);

      // Hai Lớp v1.6 §XII.5 — chữ "SCA" là thuật ngữ nội bộ, không lộ ra UI.
      expect(find.textContaining('SCA'), findsNothing);
      // Kể cả từng chữ cái một: ba vòng tròn "S · C · A" cũng là phơi bộ khung.
      for (final letter in ['S', 'C', 'A']) {
        expect(find.text(letter), findsNothing, reason: 'còn lộ chữ $letter');
      }
      // Ba trụ vẫn đọc được bằng tên đời thường, mỗi trụ ĐÚNG MỘT LẦN.
      expect(find.text('Sự rõ ràng'), findsOneWidget);
      expect(find.text('Mối quan hệ'), findsOneWidget);
      expect(find.text('Cách làm việc'), findsOneWidget);

      // Ô trống là LỜI MỜI, không phải ổ khoá (§4): chữ "Chưa có", kèm nút làm
      // Self-Check. Không mờ, không ổ khoá — mờ đang dành riêng cho Premium.
      expect(find.text('Chưa có'), findsNWidgets(3));
      expect(
        find.byKey(const Key('wr_snapshot_invite_self_check')),
        findsOneWidget,
      );
      expect(find.text('Làm Self-Check'), findsOneWidget);
    });

    testWidgets('cột trái đọc điểm ba trụ từ lần tự đánh giá gần nhất', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4.2,
            cultureScore: 3.0,
            activityScore: 1.8,
            takenAt: DateTime(2026, 7, 26),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );
      await _openSnapshot(tester);

      expect(
        find.text(ScaPillarStatus.developing.label),
        findsOneWidget,
      ); // 4.2
      expect(
        find.text(ScaPillarStatus.needsAttention.label),
        findsOneWidget,
      ); // 3.0
      expect(find.text(ScaPillarStatus.priority.label), findsOneWidget); // 1.8

      // §5 — Self-Check là ảnh chụp tại một thời điểm, nên LUÔN hiện thời điểm
      // kèm cột đánh giá. Không có ngày thì con số cũ đội lốt đánh giá hiện tại.
      expect(find.text('Self-Check gần nhất: 26/07/2026'), findsOneWidget);
    });

    testWidgets('bản ghi thiếu điểm một trụ thì cột trái vẫn coi là chưa có', (
      tester,
    ) async {
      // Di chứng lỗi nuốt câu: có bản ghi thật thiếu điểm. Hiện hai dòng rồi bỏ
      // trống dòng thứ ba đọc như lỗi tải dở, nên đòi đủ CẢ BA trụ.
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4.2,
            cultureScore: 3.0,
            takenAt: DateTime(2026, 7, 26),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );
      await _openSnapshot(tester);

      expect(find.text('Chưa có'), findsNWidgets(3));
      expect(find.text(ScaPillarStatus.developing.label), findsNothing);
    });

    testWidgets('đủ ngưỡng thì cột phải nói SỐ LẦN, không nhãn đánh giá nào', (
      tester,
    ) async {
      // §2 — đây là điều kiện gốc để mâu thuẫn không quay lại. Tần suất cao
      // KHÔNG đồng nghĩa với "tệ": quay lại một nhóm 14 lần có thể vì đang gặp
      // vấn đề, cũng có thể vì đang chủ động làm việc với nó.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 16}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository()..seedSituations([_sit]),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      expect(find.text('16 / 16 lần'), findsOneWidget);
      expect(find.text('0 / 16 lần'), findsNWidgets(2));
      // Không nhãn đánh giá nào rơi vào cột phải: chưa làm Self-Check nên cột
      // trái trống, và cả màn không được có chữ nào của thang đánh giá.
      for (final status in ScaPillarStatus.values) {
        expect(
          find.text(status.label),
          findsNothing,
          reason: 'tần suất bị gán ${status.label}',
        );
      }
    });

    testWidgets('cột phải KHÔNG bị chặn ở cửa sổ 30 mục gần nhất', (
      tester,
    ) async {
      // §8 — mẫu số phải là số thật. Đi qua `recentSituationIds` (chặn 30 mục)
      // thì người đã nhìn lại 80 lần vẫn đọc được "… / 30 lần".
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 80}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository()..seedSituations([_sit]),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      expect(find.text('80 / 80 lần'), findsOneWidget);
      expect(find.textContaining('/ 30 lần'), findsNothing);
    });

    testWidgets('không còn dòng nào bị giấu: mọi tình huống lặp lại mở được '
        'ngay trên tab, số mục khớp pill', (tester) async {
      // Lỗi khách báo 2026-08-24: đủ số lần rồi mà "không có nút để click vào
      // xem bức tranh". Trước v47 lối đi đó là "Xem thêm" sang `/wr/patterns`;
      // v47 bày đủ mọi dòng và cho xổ từng dòng tại chỗ — nên điều phải giữ là
      // dòng nào cũng chạm được, và mở ra đúng bằng số trên pill.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 5, 'sit-02': 4, 'sit-03': 3, 'sit-04': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository()
            ..seedSituations([
              _sit,
              _sitOf('sit-02', ScaDimension.c2),
              _sitOf('sit-03', ScaDimension.a1),
              _sitOf('sit-04', ScaDimension.s1),
            ]),
          episodes: episodes,
        ),
      );

      const expected = {'sit-01': 5, 'sit-02': 4, 'sit-03': 3, 'sit-04': 3};
      for (final MapEntry(key: code, value: n) in expected.entries) {
        final row = find.byKey(Key('wr_discover_loop_$code'));
        expect(
          find.descendant(of: row, matching: find.text('$n lần')),
          findsOneWidget,
          reason: 'pill của $code',
        );
        await _tapKey(tester, 'wr_discover_loop_$code');
        expect(
          _logEntries(code, _noNote),
          findsNWidgets(n),
          reason: 'số mục mở ra của $code lệch với pill',
        );
      }
      expect(find.byType(WrPatternsScreen), findsNothing);
    });

    testWidgets('tab không còn lối nào sang danh sách đầy đủ', (tester) async {
      // Khách 11/09 bỏ liên kết trùng ở Career Snapshot; v47 bỏ nốt "Xem
      // thêm". Người có 4 tình huống lặp lại — trước đây đúng ca thấy lối đi.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 5, 'sit-02': 4, 'sit-03': 3, 'sit-04': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository()
            ..seedSituations([
              _sit,
              _sitOf('sit-02', ScaDimension.c2),
              _sitOf('sit-03', ScaDimension.a1),
              _sitOf('sit-04', ScaDimension.s1),
            ]),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      expect(find.byKey(const Key('wr_discover_see_more')), findsNothing);
      expect(find.byKey(const Key('wr_snapshot_open_repeated')), findsNothing);
    });

    testWidgets('Self-Check quá 3 tháng thì mời cập nhật lại', (tester) async {
      // §5 — Self-Check là ảnh chụp, Reflection là dòng chảy. Hiện điểm cũ như
      // thể là đánh giá hiện tại là sai lệch, và hệ thống còn lấy chính con số
      // cũ đó đối chiếu với hành vi mới nên kết luận khoảng lệch sai theo.
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4,
            cultureScore: 4,
            activityScore: 4,
            takenAt: DateTime.now().subtract(const Duration(days: 200)),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );
      await _openSnapshot(tester);

      expect(
        find.byKey(const Key('wr_snapshot_self_check_stale')),
        findsOneWidget,
      );
    });

    testWidgets('vừa làm Self-Check thì không mời cập nhật', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4,
            cultureScore: 4,
            activityScore: 4,
            takenAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );
      await _openSnapshot(tester);

      // Mở ra rồi mới kiểm — kẻo "không thấy" chỉ vì khối còn thu gọn.
      expect(
        find.byKey(const Key('wr_snapshot_self_check_date')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wr_snapshot_self_check_stale')),
        findsNothing,
      );
    });

    testWidgets('đủ cả hai nguồn: free thấy có khoảng lệch nhưng chưa đọc được', (
      tester,
    ) async {
      // §6 — cách đối chiếu hai nguồn CHÍNH LÀ tính năng Premium. Nhưng cũng
      // không giấu sạch: người dùng phải thấy giá trị CỤ THỂ đang bị khoá, thay
      // vì một lời quảng cáo chung chung.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 20}));
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4.2,
            cultureScore: 4.2,
            activityScore: 4.2,
            takenAt: DateTime.now(),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository()..seedSituations([_sit]),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      expect(find.byKey(const Key('wr_snapshot_gap')), findsOneWidget);
      expect(
        find.textContaining('Hai cột trên đang cho thấy một khoảng lệch'),
        findsOneWidget,
      );
      // v47 bỏ luật "đã có dòng khoảng lệch thì ẩn thẻ cuối màn": thẻ navy
      // "Diễn giải sâu & xu hướng" luôn ở đó.
      expect(
        find.byKey(const Key('wr_discover_sca_deep_lock')),
        findsOneWidget,
      );
    });

    testWidgets('premium đọc được chính câu khoảng lệch', (tester) async {
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 20}));
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        )
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4.2,
            cultureScore: 4.2,
            activityScore: 4.2,
            takenAt: DateTime.now(),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository()..seedSituations([_sit]),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      expect(find.text('Khoảng lệch đáng chú ý'), findsOneWidget);
      // Nhánh lệch pha: tự chấm 4.2 là "Đang hỗ trợ tốt", mà chính trụ đó lại
      // quay lại nhiều nhất. Câu phải dựng từ đúng hai con số đang hiện.
      expect(find.textContaining('20 trong 20 lần'), findsOneWidget);
    });

    testWidgets('ba trụ chia đều thì KHÔNG bịa ra khoảng lệch', (tester) async {
      // Diễn giải sâu §2 — 10/9/8 lần mà vẫn tuyên bố có một trụ nổi trội là
      // khẳng định một xu hướng không thật, và bán một thứ không tồn tại.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-s': 10, 'sit-c': 9, 'sit-a': 8}));
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4.2,
            cultureScore: 4.2,
            activityScore: 4.2,
            takenAt: DateTime.now(),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository()
            ..seedSituations([
              _sitOf('sit-s', ScaDimension.s1),
              _sitOf('sit-c', ScaDimension.c2),
              _sitOf('sit-a', ScaDimension.a2),
            ]),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      // Khối đã mở (thấy cột "Xuất hiện") mà vẫn không có dòng khoảng lệch.
      expect(find.text('10 / 27 lần'), findsOneWidget);
      expect(find.byKey(const Key('wr_snapshot_gap')), findsNothing);
      // Thẻ Premium cuối màn vẫn còn — giờ nó luôn hiện.
      expect(
        find.byKey(const Key('wr_discover_sca_deep_lock')),
        findsOneWidget,
      );
    });

    // ── Lỗi khách báo 12/09/2026: "phiên bản mới mất nút Diễn giải sâu" ──
    //
    // Trước v47, lối vào Diễn giải sâu có HAI đường loại trừ nhau: dòng khoảng
    // lệch trong thẻ Snapshot, hoặc thẻ mời ở cuối màn — màn cha ẩn thẻ mời
    // khi nó tin rằng dòng khoảng lệch đã hiện. Bản 11/09 để hai chỗ TỰ TÍNH
    // "có trụ nổi trội không" bằng hai mẫu số khác nhau, và gặp đúng phân bố
    // mà hai công thức trả lời ngược nhau thì cả hai lối vào cùng tắt.
    //
    // v47 cho thẻ cuối màn luôn hiện, nên bất biến ấy giờ mạnh hơn: thẻ cuối
    // màn PHẢI có, bất kể dòng khoảng lệch. Test giữ đúng bộ dữ liệu cũ.
    testWidgets('không bao giờ mất CẢ HAI lối vào Diễn giải sâu', (
      tester,
    ) async {
      // Chép đúng phân bố 30 ngày của tài khoản khách, đọc từ DB ngày
      // 12/09/2026. Hai công thức cho hai kết quả ngược nhau trên bộ này:
      //   §2.2  — thách thức S 9/18 = 50%  → CÓ trụ nổi trội
      //   cũ    — xuất hiện C 11/33 = 33%  → KHÔNG có trụ nào
      final episodes = FakeWrEpisodeRepository()
        ..seed(
          _episodes({
            'sit-s': 9, // thách thức, trụ S
            'sit-c': 5, // thách thức, trụ C
            'sit-a': 4, // thách thức, trụ A
            'sit-pc': 6, // TÍCH CỰC, trụ C — đẩy "xuất hiện" của C vượt S
            'sit-pa': 5, // TÍCH CỰC, trụ A
            'khong-co-trong-thu-vien': 4, // nhánh "Điều khác", không có mã
          }),
        );
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4.2,
            cultureScore: 3.0,
            activityScore: 3.0,
            takenAt: DateTime.now(),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository()
            ..seedSituations([
              _sitOf('sit-s', ScaDimension.s1),
              _sitOf('sit-c', ScaDimension.c2),
              _sitOf('sit-a', ScaDimension.a2),
              _sitOf('sit-pc', ScaDimension.pAchieve, pillar: 'C'),
              _sitOf('sit-pa', ScaDimension.pSteady, pillar: 'A'),
            ]),
          episodes: episodes,
        ),
      );

      // Chưa mở Snapshot: chỉ còn thẻ cuối màn, và nó phải ở đó.
      expect(
        find.byKey(const Key('wr_discover_sca_deep_lock')),
        findsOneWidget,
      );

      await _openSnapshot(tester);
      final loiVao = [
        const Key('wr_snapshot_gap_open'), // Premium, trong dòng khoảng lệch
        const Key('wr_snapshot_gap_unlock'), // Free, trong dòng khoảng lệch
        const Key('wr_discover_sca_deep_open'), // Premium, thẻ cuối màn
        const Key('wr_discover_sca_deep_lock'), // Free, thẻ cuối màn
      ];
      expect(
        loiVao.any((k) => find.byKey(k).evaluate().isNotEmpty),
        isTrue,
        reason: 'mất cả hai lối vào Diễn giải sâu — đúng lỗi khách báo 12/09',
      );
      expect(
        find.byKey(const Key('wr_discover_sca_deep_lock')),
        findsOneWidget,
      );
    });

    // Cùng đợt 12/09, phát hiện khi soi màn thật: cột "Xuất hiện" hiện
    // "9 / 31 lần" còn câu khoảng lệch ngay dưới nói "9 trong 36 lần". Cùng
    // một tử số, hai mẫu số, cách nhau ba dòng.
    //
    // §9 việc 3 đổi cột sang `classifiedTotal` nhưng để `_gapText` ở lại
    // `reflectionTotal`. Chú thích của chính hàm đó ghi "dựng từ chính hai con
    // số đang hiện ở hai cột" — tức là nó tự nói ra hợp đồng mà nó đang phá.
    testWidgets('câu khoảng lệch chia CÙNG mẫu số với cột Xuất hiện', (
      tester,
    ) async {
      // 18 lượt thách thức (S 9 · C 5 · A 4) + 10 lượt tích cực + 5 lượt tự
      // viết không có mã. classifiedTotal = 28, còn tổng số lần nhìn lại = 33.
      // Hai con số phải khác nhau, nếu không thì bài này không phân biệt được
      // đúng với sai.
      //
      // Ba cột "Xuất hiện" cũng phải ra ba giá trị KHÁC NHAU (9 · 11 · 8):
      // để hai trụ trùng số thì `findsOneWidget` bắt được cột của trụ khác và
      // bài đỏ vì lý do không liên quan.
      final episodes = FakeWrEpisodeRepository()
        ..seed(
          _episodes({
            'sit-s': 9,
            'sit-c': 5,
            'sit-a': 4,
            'sit-pc': 6,
            'sit-pa': 4,
            'khong-co-trong-thu-vien': 5,
          }),
        );
      // Premium: câu mang số chỉ dựng cho người đã mua. Bản Free thấy câu mời
      // mở khoá, không có con số nào để đối chiếu.
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        )
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4.2, // "Đang hỗ trợ tốt" → nhánh trấn an của §6
            cultureScore: 3.0,
            activityScore: 3.0,
            takenAt: DateTime.now(),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository()
            ..seedSituations([
              _sitOf('sit-s', ScaDimension.s1),
              _sitOf('sit-c', ScaDimension.c2),
              _sitOf('sit-a', ScaDimension.a2),
              _sitOf('sit-pc', ScaDimension.pAchieve, pillar: 'C'),
              _sitOf('sit-pa', ScaDimension.pSteady, pillar: 'A'),
            ]),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      // Cột "Xuất hiện" của trụ nổi trội.
      expect(find.textContaining('9 / 28 lần'), findsOneWidget);

      // Câu khoảng lệch phải chở đúng cặp số ấy.
      final gap = tester
          .widget<WrParagraph>(find.byKey(const Key('wr_snapshot_gap_text')))
          .text;
      expect(gap, contains('9 trong 28 lần'));
      expect(
        gap,
        isNot(contains('33')),
        reason:
            'câu khoảng lệch đang chia cho tổng số lần nhìn lại, '
            'không phải mẫu số của cột Xuất hiện',
      );
    });

    test('ngưỡng trạng thái trụ giữ đúng như màn Tự đánh giá', () {
      expect(pillarStatusLabel(null), 'Chưa đánh giá');
      expect(pillarStatusLabel(0), 'Chưa đánh giá');
      expect(pillarStatusLabel(1.8), 'Đang cản trở');
      expect(pillarStatusLabel(2.5), 'Ổn, còn dư địa');
      expect(pillarStatusLabel(3.8), 'Đang hỗ trợ tốt');
    });

    // A7 đổi bộ nhãn, và trước đó màn này CHÉP lại cả ngưỡng lẫn chữ. Khoá
    // bằng chính enum: chép lại lần nữa thì bài này đỏ ngay, thay vì để hai màn
    // âm thầm nói về cùng một điểm số bằng hai giọng.
    test('lấy thẳng từ ScaPillarStatus, không chép lại', () {
      for (final score in [1.0, 2.5, 3.0, 3.8, 4.6, 5.0]) {
        expect(pillarStatusLabel(score), scaPillarStatus(score).label);
      }
      expect(pillarStatusIsReassuring(pillarStatusLabel(3.8)), isTrue);
      expect(pillarStatusIsReassuring(pillarStatusLabel(3.79)), isFalse);
      expect(pillarStatusIsReassuring('Chưa đánh giá'), isFalse);
    });
  });

  // Hai khối lấy từ mockup Sprint 2 §screenUnderstand: lời mời làm bộ 15 câu và
  // khối Premium "Diễn giải sâu & theo dõi xu hướng" (v47: thẻ navy).
  group('Hiểu mình — lời mời Self-Check', () {
    testWidgets('chưa làm lần nào thì mời bắt đầu', (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );

      expect(
        find.byKey(const Key('wr_discover_self_check_invite')),
        findsOneWidget,
      );
      expect(find.text('Tiến độ lần gần nhất: 0/15'), findsOneWidget);
      expect(find.text('Bắt đầu Self-Check'), findsOneWidget);
      expect(find.text('Cập nhật lại Self-Check'), findsNothing);
      expect(
        find.textContaining('15 câu hỏi ngắn giúp hệ thống hiểu rõ hơn'),
        findsOneWidget,
      );
    });

    testWidgets('đã làm rồi thì đổi thành lời mời làm lại', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: {for (var i = 1; i <= 15; i++) 'q$i': 4},
            structureScore: 4,
            cultureScore: 4,
            activityScore: 4,
            takenAt: DateTime(2026, 7, 26),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );

      expect(find.text('Tiến độ lần gần nhất: 15/15'), findsOneWidget);
      expect(find.text('Cập nhật lại Self-Check'), findsOneWidget);
      expect(find.text('Bắt đầu Self-Check'), findsNothing);
    });

    testWidgets('bấm là mở bộ câu hỏi', (tester) async {
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );

      await _tapKey(tester, 'wr_discover_self_check_start');

      expect(find.text('SELFCHECK'), findsOneWidget);
    });

    testWidgets('free thấy khối diễn giải sâu, bấm ra đúng ngữ cảnh paywall', (
      tester,
    ) async {
      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
        ),
      );

      expect(
        find.byKey(const Key('wr_discover_sca_deep_lock')),
        findsOneWidget,
      );
      expect(find.text('Diễn giải sâu & xu hướng'), findsOneWidget);
      expect(find.text('Mở khoá'), findsOneWidget);

      await _tapKey(tester, 'wr_discover_sca_deep_button');

      expect(find.text('PAYWALL:sca_deep'), findsOneWidget);
    });

    testWidgets('các con số cũ đếm trùng không quay lại', (tester) async {
      // Yêu cầu khách 2026-07-31 (vòng cuối): bỏ các con số đếm cùng một thứ
      // bằng hai đơn vị — "Đã tự đánh giá 7 lần", "5/15 Reflection", "Bạn đã
      // nhìn lại 16 lần"… Bản trước khoá "cả màn chỉ còn ĐÚNG HAI con số"; v47
      // thêm thẻ đầu trang và pill "N lần" nên tiền đề ấy không còn, phần còn
      // giữ là: hai con số cũ vẫn đúng chỗ, các con số trùng không quay lại.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 5}));
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: {for (var i = 1; i <= 15; i++) 'q$i': 3},
            structureScore: 3,
            cultureScore: 3,
            activityScore: 3,
            takenAt: DateTime(2026, 7, 26),
          ),
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: {for (var i = 1; i <= 15; i++) 'q$i': 3},
            structureScore: 3,
            cultureScore: 3,
            activityScore: 3,
            takenAt: DateTime(2026, 7, 20),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      expect(
        find.textContaining('sẽ mở sau 10 lần nhìn lại nữa'),
        findsOneWidget,
      );
      expect(find.text('Tiến độ lần gần nhất: 15/15'), findsOneWidget);

      // Ba con số cũ đã biến mất hẳn.
      expect(find.text('Bạn đã nhìn lại 5 lần.'), findsNothing);
      expect(find.text('HÀNH TRÌNH ĐÃ ĐI'), findsNothing);
      expect(find.textContaining('Đã tự đánh giá'), findsNothing);
      expect(find.textContaining('Reflection'), findsNothing);
    });

    testWidgets('bản ghi thiếu câu thì nói đúng số thật, không làm tròn', (
      tester,
    ) async {
      // Di chứng của lỗi nuốt câu (đã vá): bản 30/7 trên DB thật chỉ còn 12/15.
      // Hiện "15/15" ở đây là nói dối về dữ liệu đang có.
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: {for (var i = 1; i <= 12; i++) 'q$i': 3},
            structureScore: 3,
            cultureScore: 3,
            activityScore: 3,
            takenAt: DateTime(2026, 7, 30),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );

      expect(find.text('Tiến độ lần gần nhất: 12/15'), findsOneWidget);
    });

    testWidgets('còn đang đếm thì nói rõ cái gì được tính là một lần', (
      tester,
    ) async {
      // Khách 2026-08-24: "chị đã check in 15 lần" nhưng thẻ ghi 14/15. Đơn vị
      // ở đây là Episode — chỉ sinh ra khi đã CHỌN tình huống — nên chạm ô cảm
      // xúc rồi rời đi thì lần ấy không vào. Lời mời phải tự nói ra luật đó.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 14}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository(),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      expect(
        find.textContaining('sẽ mở sau 1 lần nhìn lại nữa'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Một lần được tính khi bạn đã chọn một tình huống'),
        findsOneWidget,
      );
    });

    testWidgets('quá ngưỡng thì bỏ hẳn phân số, cột phải thành số lần thật', (
      tester,
    ) async {
      // Bản trước ẩn thẻ khi vượt 15, với lý do "40/15 đọc như lỗi hiển thị".
      // Lý do đúng với PHÂN SỐ, nhưng cách chữa thì lấy mất luôn lối vào bức
      // tranh — đúng thứ khách đi tìm. Nay không còn tiến độ nào, cột "Xuất
      // hiện" tự nó đã là con số.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 16}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: FakeWrContentRepository()..seedSituations([_sit]),
          episodes: episodes,
        ),
      );
      await _openSnapshot(tester);

      expect(find.textContaining('16/15'), findsNothing);
      expect(
        find.byKey(const Key('wr_snapshot_invite_reflection')),
        findsNothing,
      );
      // Cột "Xuất hiện" đã mở, đó mới là thứ khách đi tìm — và nó ở ngay trong
      // khối, không cần thêm một lối bấm nào nữa.
      expect(find.text('16 / 16 lần'), findsOneWidget);
      expect(find.byKey(const Key('wr_snapshot_open_repeated')), findsNothing);
    });

    testWidgets('premium không bị mời mua lại thứ đã mua', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        );

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: intel,
          content: FakeWrContentRepository(),
        ),
      );

      expect(find.byKey(const Key('wr_discover_sca_deep_lock')), findsNothing);
      // Vẫn thấy thẻ, nhưng nút là lối vào chứ không phải "Mở khoá" (changelog
      // 24/08 §7: người đã trả tiền phải còn đường vào từ tab này).
      expect(
        find.byKey(const Key('wr_discover_sca_deep_open')),
        findsOneWidget,
      );
      expect(find.text('Mở khoá'), findsNothing);
      expect(find.text('Xem diễn giải sâu'), findsOneWidget);
      // Lời mời làm bộ câu hỏi thì vẫn còn — nó không phải thứ phải trả tiền.
      expect(
        find.byKey(const Key('wr_discover_self_check_invite')),
        findsOneWidget,
      );

      await _tapKey(tester, 'wr_discover_sca_deep_button');
      expect(find.text('SCADEEP'), findsOneWidget);
      expect(find.textContaining('PAYWALL'), findsNothing);
    });
  });

  group('Chi tiết điều lặp lại — ngưỡng dữ liệu và Premium', () {
    testWidgets('dưới 5 lần: nói còn thiếu bao nhiêu, chưa mời trả tiền', (
      tester,
    ) async {
      // Gieo Episode chứ không gieo `wr_pattern_counts`: từ 2026-08-01 màn này
      // đếm từ recentSituationIds như tab Hiểu mình (v2.0 §4.3). Con số tích
      // luỹ trong bảng kia cố tình để lệch ở đây để chứng minh nó bị bỏ.
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(99)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3}));

      await _pump(
        tester,
        _wrap(
          const WrPatternDetailScreen(situationCode: 'sit-01'),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.text('Bạn đã ghi lại điều này 3 lần.'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_pattern_not_enough_data')),
        findsOneWidget,
      );
      expect(find.textContaining('Cần thêm 2 lần nữa'), findsOneWidget);
      expect(find.byKey(const Key('wr_pattern_premium_lock')), findsNothing);
    });

    testWidgets('đủ 5 lần nhưng miễn phí: khoá phần diễn giải', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 5}));

      await _pump(
        tester,
        _wrap(
          const WrPatternDetailScreen(situationCode: 'sit-01'),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.byKey(const Key('wr_pattern_premium_lock')), findsOneWidget);
      expect(find.byKey(const Key('wr_pattern_narrative')), findsNothing);
    });

    testWidgets('đủ 5 lần và premium: hiện phần diễn giải', (tester) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(
          WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
        )
        ..seedPatternNarratives([
          const PatternNarrative(
            id: 'n1',
            userId: 'u1',
            narrative: 'Điều lặp lại này thường xuất hiện khi bạn ở nhóm mới.',
          ),
        ]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 6}));

      await _pump(
        tester,
        _wrap(
          const WrPatternDetailScreen(situationCode: 'sit-01'),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.byKey(const Key('wr_pattern_narrative')), findsOneWidget);
      expect(find.byKey(const Key('wr_pattern_premium_lock')), findsNothing);
    });

    testWidgets('những lần đã nhìn lại luôn hiện, kể cả bản miễn phí', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern(2)]);
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed([
          ReflectionEpisode(
            id: 'e1',
            userId: 'u1',
            humanMoment: HumanMoment.confusion,
            state: ExperienceState.integrated,
            situationCode: 'sit-01',
            draftMeaning: 'Mình hay im lặng khi chưa chắc chắn',
            closedAt: DateTime(2026, 7, 20),
          ),
        ]);

      await _pump(
        tester,
        _wrap(
          const WrPatternDetailScreen(situationCode: 'sit-01'),
          intel: intel,
          content: content,
          episodes: episodes,
        ),
      );

      // Mỗi lần chỉ còn tiêu đề khoảnh khắc kèm ngày. Câu nhận ra bị bỏ khỏi
      // đây vì những lần cùng một tình huống viết gần giống nhau, in đủ cả bốn
      // câu thì màn đọc như bị lặp nội dung.
      expect(find.text('Có gì đó chưa ổn'), findsOneWidget);
      expect(find.text('20/07/2026'), findsOneWidget);
      expect(find.text('Mình hay im lặng khi chưa chắc chắn'), findsNothing);
    });
  });
}
