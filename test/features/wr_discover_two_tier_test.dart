// Hiểu mình + chi tiết điều lặp lại — ranh giới GHI NHẬN / DIỄN GIẢI.
//
// Yêu cầu khách 2026-07-27:
//   • tích lũy đủ (5 lần) mới đọc ra nguyên nhân sâu
//   • phần đọc ra nguyên nhân là Premium
//   • bản miễn phí chỉ xem thông tin ghi nhận hành trình đã làm
//
// Bố cục tab theo script `screenUnderstand` (Sprint 2): hero → thẻ "QUAY LẠI
// NHIỀU NHẤT" (chỉ một chuyện, hỏi "có đúng với bạn không", lối sang "Những
// điều khác đang lặp lại") → thẻ "Trải nghiệm của bạn" (sang màn Diễn giải) →
// thẻ "Khảo sát điều kiện làm việc".
//
// Danh sách đầy đủ những điều lặp lại (mỗi dòng xổ ra từng lần) nằm ở màn
// riêng `screenRepeatList` = `WrPatternsScreen`. Các khối cũ của v47 — "Những
// vòng lặp quen thuộc", "Xem theo nhóm trải nghiệm"/Career Snapshot, thẻ navy
// "Diễn giải sâu & xu hướng" — script không còn, nên các test khoá chúng đã
// chuyển sang màn danh sách hoặc bỏ (xem ghi chú tại từng chỗ).

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
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

/// Tình huống thuộc một chiều SCA bất kỳ — dùng cho các ca cần nhiều mã.
WrSituation _sitOf(String code, ScaDimension dim) {
  final pillar = switch (dim) {
    ScaDimension.s1 || ScaDimension.s2 || ScaDimension.s3 => 'S',
    ScaDimension.c1 || ScaDimension.c2 || ScaDimension.c3 => 'C',
    _ => 'A',
  };
  final subgroup = switch (dim) {
    ScaDimension.s1 || ScaDimension.s3 => 'S1',
    ScaDimension.s2 => 'S2',
    ScaDimension.c1 || ScaDimension.c3 => 'C1',
    ScaDimension.c2 => 'C2',
    ScaDimension.a3 => 'A3',
    _ => 'A1',
  };
  return WrSituation(
    code: code,
    text: code,
    scaDimension: dim,
    pillarCode: pillar,
    subgroup: subgroup,
    mood: 'stress',
    valence: WrValence.thachThuc,
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
          id: 'e${base.month}${base.day}-$i',
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
        path: '/wr/experience-interpret',
        builder: (_, __) => const Scaffold(body: Text('EXPERIENCE')),
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

/// Mở một dòng của màn danh sách "Những điều đang lặp lại".
Future<void> _toggleRow(WidgetTester tester, String code) =>
    _tapKey(tester, 'wr_patterns_row_$code');

/// Những dòng mang [text] trong phần mở ra của một dòng ở màn danh sách.
Finder _logEntries(String code, String text) => find.descendant(
  of: find.byKey(Key('wr_patterns_row_log_$code')),
  matching: find.text(text),
);

const _noNote = 'Bạn không viết gì lần này';

void main() {
  // Mỗi test bắt đầu từ kho SharedPreferences rỗng.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Hiểu mình — chỉ ghi nhận', () {
    testWidgets('nói điều quay lại nhiều nhất kèm số lần, không diễn giải', (
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

      expect(find.byKey(const Key('wr_discover_hero')), findsOneWidget);
      expect(find.text('Những điều đang lặp lại'), findsOneWidget);

      // Thẻ "QUAY LẠI NHIỀU NHẤT": tên tình huống trong ngoặc kép + đúng con
      // số, đúng chữ script `${top.count} lần trong ${total} lần nhìn lại`.
      expect(find.text('QUAY LẠI NHIỀU NHẤT'), findsOneWidget);
      expect(find.text('“Không được lắng nghe trong họp”'), findsOneWidget);
      expect(find.text('3 lần trong 3 lần nhìn lại'), findsOneWidget);
      // Chỉ MỘT chuyện ở tab: không có danh sách xổ tại chỗ.
      expect(find.text('Không được lắng nghe trong họp'), findsNothing);
      expect(find.text('NHỮNG VÒNG LẶP QUEN THUỘC'), findsNothing);

      // Khối đọc vị nhu cầu "Điều bạn đang tìm kiếm" không quay lại.
      expect(find.byKey(const Key('wr_discover_need_lock')), findsNothing);
      expect(find.byKey(const Key('wr_discover_need_reading')), findsNothing);
      expect(find.byKey(const Key('wr_discover_seeking')), findsNothing);
      expect(find.text('Mở phần đọc vị'), findsNothing);
      expect(find.text('KẾT NỐI · Nhu cầu chủ đạo'), findsNothing);
      // Không có câu diễn giải riêng cho người này ở tầng ghi nhận.
      expect(find.textContaining('ĐIỀU ĐỨNG SAU'), findsNothing);
    });

    testWidgets('chưa có dữ liệu thì mời nhìn lại, không dựng thẻ rỗng', (
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
        find.byKey(const Key('wr_discover_patterns_empty')),
        findsOneWidget,
      );
      // Chưa có gì thì cũng không hỏi "có đúng với bạn không".
      expect(find.byKey(const Key('wr_discover_feedback_yes')), findsNothing);
      expect(find.byKey(const Key('wr_discover_top_count')), findsNothing);
      expect(
        find.byKey(const Key('wr_discover_repeat_list_link')),
        findsNothing,
      );
    });

    testWidgets('premium cũng chỉ thấy ghi nhận, không còn câu nhu cầu hay câu '
        'aha nào trên tab', (tester) async {
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

      expect(find.text('MONG ĐỢI KẾT QUẢ'), findsNothing);
      expect(find.text('NHU CẦU CỐT LÕI'), findsNothing);
      expect(find.textContaining('GÓC NHÌN'), findsNothing);

      expect(find.textContaining('SCA'), findsNothing);
      expect(find.textContaining('sit-01'), findsNothing);
    });

    testWidgets('mẫu số là số lần có chọn tình huống trong cửa sổ đang đếm', (
      tester,
    ) async {
      // Mẫu số phải cùng phạm vi với số đếm. Lần tự viết (không mã tình huống)
      // không nằm trong cửa sổ đếm nên không vào mẫu số.
      final episodes = FakeWrEpisodeRepository()
        ..seed([
          ..._episodes({'sit-01': 2}),
          const ReflectionEpisode(
            id: 'free-text',
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
          content: FakeWrContentRepository()..seedSituations([_sit]),
          episodes: episodes,
        ),
      );

      expect(find.text('2 lần trong 2 lần nhìn lại'), findsOneWidget);
    });

    // Lỗi khách báo 2026-08-01: ngoài ghi "4 lần", bấm vào thì đầu màn ghi
    // "5 lần" mà bên dưới chỉ có 4 mục. Trên tài khoản thật, `wr_pattern_counts`
    // của A1-01 = 5 trong khi chỉ có 4 Episode — chênh vì một Episode được khép
    // hai lần (mở lại rồi xác nhận Ý nghĩa lần nữa cộng thêm một).
    //
    // Test gieo đúng thế lệch đó: bảng cũ nói 5, Episode nói 4. Ba con số phải
    // khớp: thẻ đầu tab, pill "N lần" ở màn danh sách, và số mục khi xổ ra.
    testWidgets(
      'số ngoài tab, số trong danh sách và số mục liệt kê — cùng một con số',
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

        expect(find.text('4 lần trong 4 lần nhìn lại'), findsOneWidget);
        expect(find.textContaining('5 lần'), findsNothing);

        // Chạm thẻ đầu tab → sang màn danh sách đầy đủ.
        await _tapKey(tester, 'wr_discover_top_title');
        expect(find.byType(WrPatternsScreen), findsOneWidget);
        expect(find.text('4 lần'), findsOneWidget);
        expect(find.text('5 lần'), findsNothing);

        await _toggleRow(tester, 'sit-01');
        // Đúng bằng số mục thật sự liệt kê — chỗ người dùng đếm được bằng mắt.
        expect(_logEntries('sit-01', _noNote), findsNWidgets(4));

        // Màn chi tiết vẫn còn (Home và Diễn giải sâu còn trỏ tới) và cũng
        // phải nói 4.
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

  // Script `screenRepeatList`: danh sách đầy đủ ở màn riêng, mỗi dòng tự xổ
  // ra từng lần. Tab Hiểu mình chỉ giữ một chuyện + lối "Những điều khác đang
  // lặp lại · N điều ›".
  group('Những điều đang lặp lại — màn danh sách', () {
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

    testWidgets('tab đếm đúng số điều khác và mở ra màn danh sách đủ cả bốn', (
      tester,
    ) async {
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(6));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-00': 4, 'sit-01': 4, 'sit-02': 3, 'sit-03': 3}));

      await _pump(
        tester,
        _wrap(
          const WrDiscoverScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      // Đúng chữ script: "Những điều khác đang lặp lại" + "${n-1} điều ›".
      expect(find.text('Những điều khác đang lặp lại'), findsOneWidget);
      expect(find.text('3 điều ›'), findsOneWidget);
      // Tab chỉ nói một chuyện: ba điều còn lại không bày ra ở đây.
      for (var i = 1; i < 4; i++) {
        expect(find.textContaining('Tình huống số $i'), findsNothing);
      }

      await _tapKey(tester, 'wr_discover_repeat_list_link');
      expect(find.byType(WrPatternsScreen), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(
          find.byKey(Key('wr_patterns_row_sit-0$i')),
          findsOneWidget,
          reason: 'thiếu dòng $i ở màn danh sách',
        );
        expect(find.text('Tình huống số $i'), findsOneWidget);
      }
      // Hai tình huống chưa từng được chọn thì không có dòng.
      expect(find.byKey(const Key('wr_patterns_row_sit-04')), findsNothing);
      expect(find.textContaining('ĐIỀU ĐỨNG SAU'), findsNothing);
      expect(find.byType(WrPatternRow), findsNothing);
    });

    testWidgets('dưới ngưỡng lặp thì chưa lên bảng', (tester) async {
      // Ngưỡng là HAI lần (họp 26_1 hạ từ 3 xuống 2). Gặp đúng một lần là
      // chuyện vừa xảy ra, chưa phải nếp.
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

      // Mẫu số vẫn là MỌI lần nhìn lại — kể cả hai lượt chưa đủ ngưỡng.
      expect(find.text('3 lần trong 5 lần nhìn lại'), findsOneWidget);
      // Không còn điều nào khác đủ ngưỡng thì không mời "Những điều khác".
      expect(
        find.byKey(const Key('wr_discover_repeat_list_link')),
        findsNothing,
      );

      await _tapKey(tester, 'wr_discover_top_title');
      expect(find.byKey(const Key('wr_patterns_row_sit-00')), findsOneWidget);
      expect(find.byKey(const Key('wr_patterns_row_sit-01')), findsNothing);
      expect(find.byKey(const Key('wr_patterns_row_sit-02')), findsNothing);
      expect(find.text('Tình huống số 1'), findsNothing);
      expect(find.text('Tình huống số 2'), findsNothing);
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
      expect(find.byKey(const Key('wr_discover_feedback_yes')), findsNothing);
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

      expect(find.text('“Tình huống số 0”'), findsOneWidget);
      // Tử số và mẫu số cùng trong cửa sổ 30 lần gần nhất (không phải 33),
      // khớp câu đầu màn danh sách.
      expect(find.text('16 lần trong 30 lần nhìn lại'), findsOneWidget);
      expect(find.text('1 điều ›'), findsOneWidget);

      await _tapKey(tester, 'wr_discover_repeat_list_link');
      expect(find.text('Tình huống số 0'), findsOneWidget);
      expect(find.text('Tình huống số 1'), findsOneWidget);
      expect(find.text('Tình huống số 2'), findsNothing);
      expect(
        find.textContaining('trong 30 lần nhìn lại gần đây'),
        findsOneWidget,
      );
    });

    testWidgets('bấm một dòng mở ra từng lần ngay tại chỗ, bấm lần nữa thì '
        'thu lại', (tester) async {
      final content = FakeWrContentRepository()..seedSituations([_sit]);
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 3}));

      await _pump(
        tester,
        _wrap(
          const WrPatternsScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      expect(find.byKey(const Key('wr_patterns_row_log_sit-01')), findsNothing);

      await _toggleRow(tester, 'sit-01');

      // Vẫn ở màn này, không rơi sang màn chi tiết.
      expect(find.byType(WrPatternDetailScreen), findsNothing);
      // Ba lần, cả ba không có chữ kể lại → ba dòng "không viết gì", mỗi dòng
      // kèm ngày dd/MM.
      expect(_logEntries('sit-01', _noNote), findsNWidgets(3));
      expect(_logEntries('sit-01', '20/07'), findsNWidgets(3));

      await _toggleRow(tester, 'sit-01');
      expect(find.byKey(const Key('wr_patterns_row_log_sit-01')), findsNothing);
    });

    testWidgets('mở dòng thứ hai thì dòng đang mở thu lại', (tester) async {
      final content = FakeWrContentRepository()
        ..seedSituations(manySituations(2));
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-00': 3, 'sit-01': 2}));

      await _pump(
        tester,
        _wrap(
          const WrPatternsScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      await _toggleRow(tester, 'sit-00');
      expect(_logEntries('sit-00', _noNote), findsNWidgets(3));

      await _toggleRow(tester, 'sit-01');
      expect(find.byKey(const Key('wr_patterns_row_log_sit-00')), findsNothing);
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
          const WrPatternsScreen(),
          intel: FakeWrIntelligenceRepository(),
          content: content,
          episodes: episodes,
        ),
      );

      await _toggleRow(tester, 'sit-01');

      expect(
        _logEntries('sit-01', '“Sếp cắt lời khi tôi vừa mở miệng”'),
        findsOneWidget,
      );
      expect(_logEntries('sit-01', _noNote), findsOneWidget);
      expect(_logEntries('sit-01', '15/07'), findsOneWidget);
      expect(_logEntries('sit-01', '03/07'), findsOneWidget);
    });

    testWidgets('mọi dòng mở được, số mục mở ra khớp pill', (tester) async {
      // Lỗi khách báo 2026-08-24: đủ số lần rồi mà "không có nút để click vào
      // xem bức tranh". Dòng nào cũng phải chạm được, và mở ra đúng bằng số
      // trên pill.
      final episodes = FakeWrEpisodeRepository()
        ..seed(_episodes({'sit-01': 5, 'sit-02': 4, 'sit-03': 3, 'sit-04': 3}));

      await _pump(
        tester,
        _wrap(
          const WrPatternsScreen(),
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
        final row = find.byKey(Key('wr_patterns_row_$code'));
        expect(
          find.descendant(of: row, matching: find.text('$n lần')),
          findsOneWidget,
          reason: 'pill của $code',
        );
        await _toggleRow(tester, code);
        expect(
          _logEntries(code, _noNote),
          findsNWidgets(n),
          reason: 'số mục mở ra của $code lệch với pill',
        );
      }
    });
  });

  // Thẻ "QUAY LẠI NHIỀU NHẤT" của script: hỏi lại người dùng. Script giữ câu
  // trả lời trong `state.patternFeedback` (bộ nhớ phiên), nhánh "Chưa đúng
  // lắm" chỉ cảm ơn — không còn danh sách "điều khác" để chọn.
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

      final title = tester.widget<Text>(
        find.byKey(const Key('wr_discover_top_title')),
      );
      expect(title.data, '“Không được lắng nghe trong họp”');
      final count = tester.widget<Text>(
        find.byKey(const Key('wr_discover_top_count')),
      );
      expect(count.data, '3 lần trong 5 lần nhìn lại');

      expect(find.text('Điều này có đúng với bạn không?'), findsOneWidget);
      expect(find.text('Đúng với tôi'), findsOneWidget);
      expect(find.text('Chưa đúng lắm'), findsOneWidget);
      expect(find.text('1 điều ›'), findsOneWidget);
    });

    testWidgets('trả lời Đúng: mời sang chủ đề thực hành', (tester) async {
      await _pump(tester, app(threeAndTwo()));

      await _tapKey(tester, 'wr_discover_feedback_yes');

      expect(
        find.text(
          'Vậy thì đây có thể là chỗ đáng để bạn dành thêm chú ý trong thời '
          'gian tới.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_discover_feedback_yes')), findsNothing);
      expect(find.byKey(const Key('wr_discover_feedback_no')), findsNothing);
      expect(find.text('Xem chủ đề thực hành liên quan'), findsOneWidget);

      // Chưa theo chủ đề nào cùng chiều → về tab Phát triển.
      await _tapKey(tester, 'wr_discover_feedback_practice');
      expect(find.text('GROWTH'), findsOneWidget);
    });

    testWidgets('trả lời Chưa đúng: cảm ơn, không mời thực hành', (
      tester,
    ) async {
      await _pump(tester, app(threeAndTwo()));

      await _tapKey(tester, 'wr_discover_feedback_no');

      expect(
        find.text(
          'Cảm ơn bạn đã cho biết. Quan sát này sẽ được đọc lại sau vài lần '
          'nhìn lại nữa.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_discover_feedback_yes')), findsNothing);
      expect(
        find.byKey(const Key('wr_discover_feedback_practice')),
        findsNothing,
      );
      // Script không bày danh sách "điều khác" để chọn trong thẻ này — lối
      // sang các điều khác vẫn là dòng "Những điều khác đang lặp lại".
      expect(
        find.byKey(const Key('wr_discover_feedback_alt_sit-02')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('wr_discover_repeat_list_link')),
        findsOneWidget,
      );
    });

    testWidgets('câu trả lời chỉ sống trong phiên: mở lại tab thì hỏi lại', (
      tester,
    ) async {
      final episodes = threeAndTwo();
      await _pump(tester, app(episodes));
      await _tapKey(tester, 'wr_discover_feedback_no');

      // Dựng lại từ đầu — ProviderScope mới, State mới.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(episodes));
      await tester.pumpAndSettle();

      expect(find.text('Điều này có đúng với bạn không?'), findsOneWidget);
      expect(find.textContaining('Cảm ơn bạn đã cho biết'), findsNothing);
    });

    testWidgets('câu trả lời cũ còn lưu trong máy không còn được đọc', (
      tester,
    ) async {
      // Bản trước lưu câu trả lời theo người dùng + tình huống. Script không
      // nhớ qua phiên, nên kho cũ phải bị bỏ qua, kẻo người dùng thấy câu trả
      // lời cũ quay lại.
      SharedPreferences.setMockInitialValues({
        'wr_pattern_feedback_u1_sit-01': 'yes',
      });
      await _pump(tester, app(threeAndTwo()));

      expect(find.text('Điều này có đúng với bạn không?'), findsOneWidget);
      expect(
        find.byKey(const Key('wr_discover_feedback_practice')),
        findsNothing,
      );
    });
  });

  // v1.6 §XII.5: mã nội bộ (sit-01, C2-sit-01…) không bao giờ được hiện ra.
  // Đường lộ thật là lúc thư viện tình huống chưa tải xong hoặc mất mạng.
  group('Hiểu mình — hai dòng chữ nhỏ của thẻ đầu trang nằm một dòng', () {
    // Máy thật 13/10 (khổ 360, cỡ chữ hệ thống 1.15): "Điều này có đúng với
    // bạn không?" và "Những điều khác đang lặp lại" xuống hàng. Script để cả
    // hai một dòng (`.tiny` 11px và 13px).
    for (final scale in [1.0, 1.15, 1.3]) {
      testWidgets('cỡ chữ $scale, khổ 360', (tester) async {
        tester.view.physicalSize = const Size(360, 3000);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          _wrap(
            const WrDiscoverScreen(),
            intel: FakeWrIntelligenceRepository(),
            content: FakeWrContentRepository()
              ..seedSituations([
                _sit,
                _sitOf('sit-02', ScaDimension.a1),
              ]),
            episodes: FakeWrEpisodeRepository()
              ..seed(_episodes({'sit-01': 3, 'sit-02': 2})),
          ),
        );
        await tester.pumpAndSettle();

        for (final text in [
          'Điều này có đúng với bạn không?',
          'Những điều khác đang lặp lại',
        ]) {
          final f = find.text(text);
          expect(f, findsOneWidget, reason: text);
          expect(tester.widget<Text>(f).maxLines, 1, reason: text);
          expect(tester.widget<Text>(f).softWrap, isFalse, reason: text);
          final para = tester.renderObject<RenderParagraph>(
            find.descendant(of: f, matching: find.byType(RichText)),
          );
          final tops = para
              .getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: text.length),
              )
              .map((b) => b.top.round())
              .toSet();
          expect(tops.length, 1, reason: text);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

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

        await _tapKey(tester, 'wr_discover_top_title');
        expect(find.textContaining('sit-01'), findsNothing);
        expect(find.text('Tình huống'), findsOneWidget); // dòng danh sách
        expect(find.text('3 lần'), findsOneWidget);
      },
    );

    testWidgets('trả lời câu hỏi và mở dòng cũng không rơi về mã', (
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

      await _tapKey(tester, 'wr_discover_feedback_no');
      expect(find.textContaining('sit-0'), findsNothing);

      await _tapKey(tester, 'wr_discover_repeat_list_link');
      await _toggleRow(tester, 'sit-02');
      expect(_logEntries('sit-02', _noNote), findsNWidgets(2));
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

  // Career Snapshot đã rời tab (script `screenUnderstand` không có khối "Xem
  // theo nhóm trải nghiệm"); phần đọc ba trụ chuyển sang màn Diễn giải, có test
  // riêng ở `wr_understand_parity_test`. Ở đây chỉ giữ các hàm thuần còn sống
  // trong `wr_discover_screen.dart`.
  group('Hiểu mình — nhãn trạng thái trụ (hàm thuần)', () {
    test('ngưỡng trạng thái trụ giữ đúng như màn Tự đánh giá', () {
      expect(pillarStatusLabel(null), 'Chưa đánh giá');
      expect(pillarStatusLabel(0), 'Chưa đánh giá');
      // Ngưỡng của script (>=3 / >=2 trên thang 0–4) quy sang thang 1–5.
      expect(pillarStatusLabel(1.8), 'Đang cản trở');
      expect(pillarStatusLabel(2.5), 'Đang cản trở');
      expect(pillarStatusLabel(3.0), 'Nâng đỡ nhưng chưa đều');
      expect(pillarStatusLabel(3.8), 'Nâng đỡ nhưng chưa đều');
      expect(pillarStatusLabel(4.0), 'Đang nâng đỡ bạn');
    });

    // A7 đổi bộ nhãn, và trước đó màn này CHÉP lại cả ngưỡng lẫn chữ. Khoá
    // bằng chính enum: chép lại lần nữa thì bài này đỏ ngay.
    test('lấy thẳng từ ScaPillarStatus, không chép lại', () {
      for (final score in [1.0, 2.5, 3.0, 3.8, 4.6, 5.0]) {
        expect(pillarStatusLabel(score), scaPillarStatus(score).label);
      }
      expect(pillarStatusIsReassuring(pillarStatusLabel(4.0)), isTrue);
      expect(pillarStatusIsReassuring(pillarStatusLabel(3.99)), isFalse);
      expect(pillarStatusIsReassuring('Chưa đánh giá'), isFalse);
    });

    test('bản ghi thiếu điểm một trụ thì coi như chưa tự đánh giá', () {
      // Di chứng lỗi nuốt câu: có bản ghi thật thiếu điểm.
      expect(snapshotHasSelfCheck(null), isFalse);
      expect(
        snapshotHasSelfCheck(
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4.2,
            cultureScore: 3.0,
            takenAt: DateTime(2026, 7, 26),
          ),
        ),
        isFalse,
      );
      expect(
        snapshotHasSelfCheck(
          ScaSelfCheckResponse(
            userId: 'u1',
            answers: const {},
            structureScore: 4.2,
            cultureScore: 3.0,
            activityScore: 1.8,
            takenAt: DateTime(2026, 7, 26),
          ),
        ),
        isTrue,
      );
    });
  });

  // Hai thẻ cuối tab theo script: "Trải nghiệm của bạn" (lối vào màn Diễn
  // giải) và "Khảo sát điều kiện làm việc" (bộ 15 câu).
  group('Hiểu mình — thẻ Trải nghiệm & lời mời khảo sát', () {
    testWidgets(
      'chưa làm lần nào thì mời bắt đầu, không có dòng lần gần nhất',
      (tester) async {
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
        expect(find.text('Khảo sát điều kiện làm việc'), findsOneWidget);
        expect(
          find.textContaining('Giúp hệ thống hiểu rõ hơn trạng thái hiện tại'),
          findsOneWidget,
        );
        expect(find.text('Bắt đầu khảo sát →'), findsOneWidget);
        expect(find.text('Cập nhật lại →'), findsNothing);
        expect(
          find.byKey(const Key('wr_discover_self_check_progress')),
          findsNothing,
        );
      },
    );

    testWidgets('đã làm rồi thì đổi thành lời mời cập nhật lại', (
      tester,
    ) async {
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

      expect(find.text('Lần gần nhất: 15/15 câu'), findsOneWidget);
      expect(find.text('Cập nhật lại →'), findsOneWidget);
      expect(find.text('Bắt đầu khảo sát →'), findsNothing);
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

    testWidgets('bản ghi thiếu câu thì nói đúng số thật, không làm tròn', (
      tester,
    ) async {
      // Di chứng của lỗi nuốt câu (đã vá): bản 30/7 trên DB thật chỉ còn 12/15.
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

      expect(find.text('Lần gần nhất: 12/15 câu'), findsOneWidget);
    });

    testWidgets('các con số cũ đếm trùng không quay lại', (tester) async {
      // Yêu cầu khách 2026-07-31: bỏ các con số đếm cùng một thứ bằng hai đơn
      // vị — "Đã tự đánh giá 7 lần", "5/15 Reflection", "Bạn đã nhìn lại 16
      // lần"…
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
          content: FakeWrContentRepository()..seedSituations([_sit]),
          episodes: episodes,
        ),
      );

      expect(find.text('5 lần trong 5 lần nhìn lại'), findsOneWidget);
      expect(find.text('Lần gần nhất: 15/15 câu'), findsOneWidget);

      expect(find.text('Bạn đã nhìn lại 5 lần.'), findsNothing);
      expect(find.text('HÀNH TRÌNH ĐÃ ĐI'), findsNothing);
      expect(find.textContaining('Đã tự đánh giá'), findsNothing);
      // "WorkReflection" là tên sản phẩm trong chữ script của thẻ Trải nghiệm;
      // điều bị cấm là chữ "Reflection" đứng riêng làm đơn vị đếm.
      expect(find.textContaining(RegExp(r'\bReflection')), findsNothing);
    });

    // Lỗi khách báo 12/09/2026: "phiên bản mới mất nút Diễn giải sâu". Lối
    // vào phần diễn giải từ tab nay là thẻ "Trải nghiệm của bạn" — nó phải
    // LUÔN có, cho cả free lẫn premium, và không chặn paywall ngay tại tab:
    // script để màn Diễn giải tự chia phần miễn phí / Premium.
    for (final premium in [false, true]) {
      testWidgets('thẻ Trải nghiệm của bạn luôn dẫn sang màn Diễn giải '
          '(${premium ? 'premium' : 'free'})', (tester) async {
        final intel = FakeWrIntelligenceRepository();
        if (premium) {
          intel.seedEntitlement(
            WrEntitlementRecord(userId: 'u1', plan: WrPlan.premium),
          );
        }

        await _pump(
          tester,
          _wrap(
            const WrDiscoverScreen(),
            intel: intel,
            content: FakeWrContentRepository(),
          ),
        );

        expect(find.text('GHI NHẬN TỪ HỆ THỐNG'), findsOneWidget);
        expect(find.text('Trải nghiệm của bạn'), findsOneWidget);
        expect(
          find.textContaining(
            'Dựa vào những lần nhìn lại cũng như cập nhật điều kiện bạn đang '
            'làm việc',
          ),
          findsOneWidget,
        );
        expect(find.text('Mở khoá'), findsNothing);
        // Khảo sát không phải thứ phải trả tiền: lời mời luôn còn.
        expect(
          find.byKey(const Key('wr_discover_self_check_invite')),
          findsOneWidget,
        );

        await _tapKey(tester, 'wr_discover_experience_read');
        expect(find.text('EXPERIENCE'), findsOneWidget);
        expect(find.textContaining('PAYWALL'), findsNothing);
      });
    }
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
