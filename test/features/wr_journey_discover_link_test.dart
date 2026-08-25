// Tests phủ Task A–E:
// A: Timeline bug display (situationCode + emotion)
// B: Section "CHỦ ĐỀ LẶP LẠI" trên Journey
// C: Stats theo loại trên Journey
// D: Empty state Journey mới
// E: Link chéo trên Discover
// Run: flutter test test/features/wr_journey_discover_link_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/logic/wr_career_memory_rules.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_episode_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

GoRouter _makeRouter({required Widget home, String initialLocation = '/test'}) =>
    GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/test', builder: (_, __) => home),
        GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HomeScreen'))),
        GoRoute(path: '/wr/journey', builder: (_, __) => const Scaffold(body: Text('JourneyScreen'))),
        GoRoute(path: '/wr/discover', builder: (_, __) => const Scaffold(body: Text('DiscoverScreen'))),
        GoRoute(path: '/wr/paywall', builder: (_, __) => const Scaffold(body: Text('PaywallScreen'))),
        GoRoute(path: '/wr/self-check', builder: (_, __) => const Scaffold(body: Text('SelfCheckScreen'))),
        GoRoute(path: '/wr/journey/narrative', builder: (_, __) => const Scaffold(body: Text('Narrative'))),
      ],
    );

Widget _wrapJourney({
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String userId = 'u1',
  // Dòng thời gian Career Memory chỉ hiện với Premium (khách chốt 2026-07-29),
  // nên test nào kiểm cách dựng dòng thời gian phải bật cờ này.
  bool premium = false,
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  if (premium) {
    intelRepo.seedEntitlement(
      WrEntitlementRecord(userId: userId, plan: WrPlan.premium),
    );
  }
  final router = _makeRouter(home: const WrJourneyScreen());
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue(userId),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,routerConfig: router),
  );
}

/// Mở mốc đầu tiên trên dòng thời gian.
///
/// Từ 2026-08-03 mỗi mốc thu gọn sẵn: mặc định chỉ hiện LOẠI mốc, còn điều
/// người dùng rút ra và tình huống họ chọn nằm sau một cú chạm. Các bài kiểm
/// dưới đây nói về NỘI DUNG mốc nên phải mở ra trước, không thì chúng đang kiểm
/// một hàng đã thu.
Future<void> _expandFirstEntry(WidgetTester tester) async {
  final arrow = find.byIcon(Icons.keyboard_arrow_down_rounded).first;
  await tester.ensureVisible(arrow);
  await tester.pumpAndSettle();
  await tester.tap(arrow);
  await tester.pumpAndSettle();
}

Widget _wrapDiscover({
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  FakeWrEpisodeRepository? episodes,
  String userId = 'u1',
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = _makeRouter(home: const WrDiscoverScreen());
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      // Danh sách "Tình huống lặp lại" đọc từ Episode chứ không từ
      // `wr_pattern_counts` kể từ 2026-07-29.
      wrEpisodeRepositoryProvider
          .overrideWithValue(episodes ?? FakeWrEpisodeRepository()),
      currentUserIdProvider.overrideWithValue(userId),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,routerConfig: router),
  );
}

/// [count] Episode đã khép cho cùng một mã tình huống.
List<ReflectionEpisode> _closedEpisodes(String code, int count) => [
      for (var i = 1; i <= count; i++)
        ReflectionEpisode(
          id: 'ep-$code-$i',
          userId: 'u1',
          humanMoment: HumanMoment.confusion,
          state: ExperienceState.integrated,
          situationCode: code,
          closedAt: DateTime(2026, 7, 20).add(Duration(hours: i)),
        ),
    ];

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

/// Helper tạo CareerMemoryEvent.
CareerMemoryEvent _event({
  String id = 'e1',
  String userId = 'u1',
  String? situationCode,
  String? emotion,
  String? behavior,
  String? storyId,
  String? reflectionText,
  HumanNeed? humanNeed,
  DateTime? createdAt,
}) =>
    CareerMemoryEvent(
      id: id,
      userId: userId,
      situationCode: situationCode,
      emotion: emotion,
      behavior: behavior,
      storyId: storyId,
      reflectionText: reflectionText,
      humanNeed: humanNeed,
      createdAt: createdAt ?? DateTime(2026, 7, 20),
    );

/// Helper tạo WrSituation.
WrSituation _situation({
  String code = 'sit-01',
  String text = 'Áp lực deadline',
  HumanNeed? humanNeed,
}) =>
    WrSituation(
      code: code,
      text: text,
      scaDimension: ScaDimension.s1,
      wave: 1,
      humanNeed: humanNeed,
    );

/// Helper tạo PatternCount.
PatternCount _pattern({
  String code = 'sit-01',
  int count = 3,
}) =>
    PatternCount(
      userId: 'u1',
      situationCode: code,
      occurrenceCount: count,
      lastSeenAt: DateTime(2026, 7, 18),
    );

ScaSelfCheckResponse _selfCheck() => ScaSelfCheckResponse(
      id: 'r1',
      userId: 'u1',
      answers: const {},
      structureScore: 3.5,
      cultureScore: 4.0,
      activityScore: 2.0,
      takenAt: DateTime(2026, 7, 20),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Task A: Bug hiển thị timeline
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Task A — Timeline: situationCode + emotion display', () {
    testWidgets(
        'event có situationCode + emotion low → hiển thị TEXT tình huống, KHÔNG phải chuỗi thô "low"',
        (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _situation(code: 'sit-01', text: 'Áp lực deadline'),
      ]);
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          situationCode: 'sit-01',
          emotion: 'low',
          createdAt: DateTime(2026, 7, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));
      await _expandFirstEntry(tester);

      // Title phải là text tình huống
      expect(find.text('Áp lực deadline'), findsOneWidget);
      // KHÔNG hiển thị chuỗi thô 'low'
      expect(find.text('low'), findsNothing);
    });

    testWidgets('emotion low → body hiển thị "Mệt mỏi" (tiếng Việt)', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _situation(code: 'sit-01', text: 'Áp lực deadline'),
      ]);
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          situationCode: 'sit-01',
          emotion: 'low',
          createdAt: DateTime(2026, 7, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));
      await _expandFirstEntry(tester);

      // Body phải hiện emotion đã map
      expect(find.text('Mệt mỏi'), findsOneWidget);
    });

    testWidgets('emotion ok → body hiển thị "Ổn"', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_situation(code: 'sit-02', text: 'Họp nhóm')]);
      content.seedMemoryEvents([
        _event(
          id: 'e2',
          userId: 'u1',
          situationCode: 'sit-02',
          emotion: 'ok',
          createdAt: DateTime(2026, 7, 19),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));
      await _expandFirstEntry(tester);

      expect(find.text('Ổn'), findsOneWidget);
      expect(find.text('ok'), findsNothing);
    });

    testWidgets('emotion good → body hiển thị "Vui"', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_situation(code: 'sit-03', text: 'Demo sản phẩm')]);
      content.seedMemoryEvents([
        _event(
          id: 'e3',
          userId: 'u1',
          situationCode: 'sit-03',
          emotion: 'good',
          createdAt: DateTime(2026, 7, 18),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));
      await _expandFirstEntry(tester);

      expect(find.text('Vui'), findsOneWidget);
      expect(find.text('good'), findsNothing);
    });

    testWidgets('event không có situationCode nhưng có reflectionText → hiện reflectionText',
        (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e4',
          userId: 'u1',
          reflectionText: 'Hôm nay tôi học được điều mới',
          emotion: 'good',
          createdAt: DateTime(2026, 7, 17),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));
      await _expandFirstEntry(tester);

      expect(find.text('Hôm nay tôi học được điều mới'), findsOneWidget);
    });

    // ── Thu gọn sẵn ────────────────────────────────────────────────────────
    //
    // Dòng thời gian là nơi nhìn lại cả một tháng. Mỗi mốc trải ra ba dòng chữ
    // đậm cộng một dòng phụ thì một tuần bận đã dài hơn màn hình, và tác dụng
    // "nhìn một cái thấy hết" mất sạch.

    testWidgets('tiêu đề và trích LUÔN hiện, dòng luật nằm sau một cú chạm',
        (tester) async {
      // Mockup v16 bày ba tầng chữ: nhãn loại + tiêu đề + trích luôn hiện, chỉ
      // `detail` ("vì sao mảnh này có mặt") nằm sau cú chạm.
      //
      // Bản trước thu tới mức chỉ còn NHÃN LOẠI, nên dòng thời gian là một cột
      // "CÂU CHUYỆN · CÂU CHUYỆN · CỘT MỐC" không phân biệt được mảnh nào với
      // mảnh nào — phải mở từng cái mới biết mình đang nhìn gì.
      final content = FakeWrContentRepository();
      content.seedSituations([
        _situation(code: 'sit-01', text: 'Áp lực deadline'),
      ]);
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          situationCode: 'sit-01',
          emotion: 'low',
          createdAt: DateTime(2026, 7, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));

      expect(find.text('Áp lực deadline'), findsOneWidget);
      expect(find.text('Mệt mỏi'), findsOneWidget);
      // Mũi tên phải còn đó: nó là thứ duy nhất báo rằng hàng còn chữ bên
      // trong. Thiếu nó thì phần nội dung xem như biến mất hẳn.
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsWidgets);
    });

    testWidgets('dòng luật của Chủ đề chỉ hiện khi mở ra', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          behavior: kThemeBehavior,
          reflectionText: '3 lần nhìn lại gần đây đều xoay quanh một điều.',
          createdAt: DateTime(2026, 7, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));

      expect(find.text('CHỦ ĐỀ'), findsOneWidget);
      expect(
        find.text('3 lần nhìn lại gần đây đều xoay quanh một điều.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wr_journey_entry_detail')), findsNothing);

      await _expandFirstEntry(tester);
      expect(find.byKey(const Key('wr_journey_entry_detail')), findsOneWidget);

      // Chạm lần nữa thì thu lại — thu được cả hai chiều, không thì mở ra rồi
      // là trang dài mãi.
      await _expandFirstEntry(tester);
      expect(find.byKey(const Key('wr_journey_entry_detail')), findsNothing);
    });

    testWidgets('mở một mốc KHÔNG kéo theo mốc khác', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          behavior: kThemeBehavior,
          reflectionText: 'Mốc thứ nhất',
          createdAt: DateTime(2026, 7, 20, 10),
        ),
        _event(
          id: 'e2',
          userId: 'u1',
          behavior: kThemeBehavior,
          reflectionText: 'Mốc thứ hai',
          createdAt: DateTime(2026, 7, 20, 9),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));
      await _expandFirstEntry(tester);

      expect(find.byKey(const Key('wr_journey_entry_detail')), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Task A: Chip chủ đề (humanNeed)
  // ─────────────────────────────────────────────────────────────────────────────

  // ───────────────────────────────────────────────────────────────────────────
  // Hành trình sau tối giản: chỉ ghi nhận + dòng thời gian, mọi diễn giải
  // chuyển sang màn riêng.
  // ───────────────────────────────────────────────────────────────────────────

  group('Hành trình — ghi nhận, không diễn giải', () {
    testWidgets('đếm đúng số mảnh ký ức', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(id: 'e1', userId: 'u1', reflectionText: 'Một', createdAt: DateTime(2026, 7, 20)),
        _event(id: 'e2', userId: 'u1', reflectionText: 'Hai', createdAt: DateTime(2026, 7, 19)),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));

      expect(find.textContaining('2 mảnh ký ức'), findsOneWidget);
      // Dòng thời gian gom theo tháng — hai mục cùng tháng 7 nằm chung một cụm.
      expect(find.text('THÁNG 7, 2026'), findsOneWidget);
    });

    testWidgets('0 events → lời mời, không có dòng thời gian', (tester) async {
      await _pumpLarge(tester, _wrapJourney());

      expect(find.textContaining('Chưa có mảnh ký ức nào'), findsOneWidget);
      expect(find.textContaining('THÁNG '), findsNothing);
    });

    testWidgets('không còn khối diễn giải ngay trên tab', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_situation(code: 'sit-01', text: 'Áp lực deadline')]);

      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(code: 'sit-01', count: 4)]);

      await _pumpLarge(tester, _wrapJourney(content: content, intel: intel));

      // "CHỦ ĐỀ LẶP LẠI" thuộc về Hiểu mình, không lặp lại ở đây.
      expect(find.textContaining('CHỦ ĐỀ LẶP LẠI'), findsNothing);
      // Diễn biến theo thời gian giờ là một dòng dẫn sang màn riêng.
      expect(find.byKey(const Key('wr_journey_narrative_row')), findsOneWidget);
    });

    testWidgets('có patterns → vẫn có lối sang Hiểu mình', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(code: 'sit-01', count: 2)]);

      await _pumpLarge(tester, _wrapJourney(intel: intel));

      expect(find.textContaining('Xem trong Hiểu mình'), findsOneWidget);
    });

    testWidgets('không có patterns → ẩn lối sang Hiểu mình', (tester) async {
      await _pumpLarge(tester, _wrapJourney());

      expect(find.textContaining('Xem trong Hiểu mình'), findsNothing);
    });

    testWidgets('nhãn loại sự kiện hiện đúng', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(id: 'e1', userId: 'u1', storyId: 'story-01', createdAt: DateTime(2026, 7, 18)),
        _event(
          id: 'e2',
          userId: 'u1',
          behavior: 'practice_step_done',
          reflectionText: 'Chủ đề — Bước 1',
          createdAt: DateTime(2026, 7, 17),
        ),
        _event(id: 'e3', userId: 'u1', behavior: 'insight', reflectionText: 'Nhận ra', createdAt: DateTime(2026, 7, 16)),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));

      expect(find.text('PHẢN CHIẾU'), findsOneWidget);
      expect(find.text('THỰC HÀNH'), findsOneWidget);
      // §XII.5: nhãn loại dùng tiếng Việt, không phơi tên loại nội bộ.
      expect(find.text('NHẬN RA'), findsOneWidget);
    });

    testWidgets('mỗi tháng một tiêu đề riêng', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          reflectionText: 'Tháng bảy',
          createdAt: DateTime(2026, 7, 20),
        ),
        _event(
          id: 'e2',
          userId: 'u1',
          reflectionText: 'Tháng sáu',
          createdAt: DateTime(2026, 6, 2),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, premium: true));

      expect(find.text('THÁNG 7, 2026'), findsOneWidget);
      expect(find.text('THÁNG 6, 2026'), findsOneWidget);
    });
  });

  // Career Memory gom ba tầng: tháng → tuần trong tháng → ngày trong tuần
  // (yêu cầu khách 2026-08-01). `now` truyền vào để nhãn "Hôm nay"/"Hôm qua"
  // kiểm được mà không phụ thuộc lúc chạy test.
  group('groupJourneyByWeekAndDay', () {
    JourneyEntry entry(String title, DateTime? at) =>
        JourneyEntry(at: at, label: 'PHẢN TƯ', title: title, color: Colors.black);

    final now = DateTime(2026, 8, 1);

    test('gom các mục cùng tháng vào một cụm, giữ thứ tự đã sắp', () {
      final months = groupJourneyByWeekAndDay([
        entry('a', DateTime(2026, 7, 20)),
        entry('b', DateTime(2026, 7, 2)),
        entry('c', DateTime(2026, 6, 30)),
      ], now: now);

      expect(months.map((m) => m.label).toList(),
          ['THÁNG 7, 2026', 'THÁNG 6, 2026']);
    });

    test('cùng tháng khác năm không bị gộp', () {
      final months = groupJourneyByWeekAndDay([
        entry('a', DateTime(2026, 7, 1)),
        entry('b', DateTime(2025, 7, 1)),
      ], now: now);

      expect(months.length, 2);
    });

    test('mục không có thời gian dồn xuống cuối', () {
      final months = groupJourneyByWeekAndDay([
        entry('a', DateTime(2026, 7, 1)),
        entry('b', null),
      ], now: now);

      expect(months.last.label, 'CHƯA RÕ THỜI GIAN');
      expect(months.last.weeks.single.days.single.entries.single.title, 'b');
    });

    test('đánh số tuần từ đầu tháng, dù danh sách đang mới-trước', () {
      // 03/08 là Thứ Hai tuần 2; 01/08 là Thứ Bảy tuần 1.
      final months = groupJourneyByWeekAndDay([
        entry('mới', DateTime(2026, 8, 3)),
        entry('cũ', DateTime(2026, 8, 1)),
      ], now: DateTime(2026, 8, 20));

      final weeks = months.single.weeks;
      expect(weeks.first.label, startsWith('TUẦN 2'));
      expect(weeks.last.label, startsWith('TUẦN 1'));
    });

    test('khoảng ngày của tuần bị cắt theo biên tháng', () {
      // Tuần chứa 01/08/2026 bắt đầu từ Thứ Hai 27/07 — nhưng nhãn phải nói
      // 01–02/08, không lôi ngày của tháng trước vào.
      final months = groupJourneyByWeekAndDay(
        [entry('a', DateTime(2026, 8, 1))],
        now: DateTime(2026, 8, 20),
      );

      expect(months.single.weeks.single.label, 'TUẦN 1 · 01–02/08');
    });

    test('ngày mang tên thứ trong tuần', () {
      final months = groupJourneyByWeekAndDay(
        [entry('a', DateTime(2026, 8, 5))], // Thứ Tư
        now: DateTime(2026, 8, 20),
      );

      expect(months.single.weeks.single.days.single.label, 'Thứ Tư, 05/08');
    });

    test('hôm nay và hôm qua gọi thẳng tên, không đọc ra ngày', () {
      final today = DateTime(2026, 8, 20, 9);
      final months = groupJourneyByWeekAndDay([
        entry('a', DateTime(2026, 8, 20, 8)),
        entry('b', DateTime(2026, 8, 19, 8)),
      ], now: today);

      final days = months.single.weeks.single.days;
      expect(days.map((d) => d.label).toList(), ['Hôm nay', 'Hôm qua']);
    });

    test('nhiều mục cùng ngày gom về một tiêu đề ngày', () {
      final months = groupJourneyByWeekAndDay([
        entry('a', DateTime(2026, 8, 5, 18)),
        entry('b', DateTime(2026, 8, 5, 9)),
      ], now: DateTime(2026, 8, 20));

      final days = months.single.weeks.single.days;
      expect(days.length, 1);
      expect(days.single.entries.map((e) => e.title).toList(), ['a', 'b']);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Task E: Link chéo Discover → Journey
  // ─────────────────────────────────────────────────────────────────────────────

  // Link chéo "Xem toàn bộ hành trình" đã bỏ khỏi Hiểu mình sau khi tối giản:
  // mỗi dòng nay mở màn chi tiết của chính điều lặp lại đó.
  group('Hiểu mình sau tối giản', () {
    testWidgets('không còn link chéo sang Hành trình', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _situation(code: 'sit-01', text: 'Áp lực deadline'),
      ]);

      final intel = FakeWrIntelligenceRepository();
      intel.seedSelfCheckHistory([_selfCheck()]);
      intel.seedPatternCounts([_pattern(code: 'sit-01', count: 4)]);

      final episodes = FakeWrEpisodeRepository()
        ..seed(_closedEpisodes('sit-01', 4));

      await _pumpLarge(
        tester,
        _wrapDiscover(content: content, intel: intel, episodes: episodes),
      );

      expect(find.textContaining('Xem toàn bộ hành trình'), findsNothing);
      expect(find.text('Áp lực deadline'), findsOneWidget);
      expect(find.text('4 lần'), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Thẻ "Diễn biến theo thời gian" mở đầu tab (giao diện mẫu Sprint 2)
  // ───────────────────────────────────────────────────────────────────────────

  group('Hành trình — thẻ Diễn biến theo thời gian', () {
    testWidgets('bản miễn phí không thấy một chữ nào của nội dung diễn giải', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternNarratives([
        PatternNarrative(
          id: 'n1',
          userId: 'u1',
          narrative: 'Bạn đang học cách lên tiếng.',
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(intel: intel));

      expect(find.byKey(const Key('wr_journey_narrative_card')), findsOneWidget);
      // Khoá, không phải làm mờ: chữ mờ vẫn là chữ đã gửi xuống máy.
      expect(find.text('Bạn đang học cách lên tiếng.'), findsNothing);
      expect(find.text('Xem bản đầy đủ có gì'), findsOneWidget);
    });

    testWidgets('Premium đọc được ngay diễn giải mới nhất trên tab', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternNarratives([
        PatternNarrative(
          id: 'n1',
          userId: 'u1',
          narrative: 'Bạn đang học cách lên tiếng.',
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(intel: intel, premium: true));

      expect(find.text('Bạn đang học cách lên tiếng.'), findsOneWidget);
      expect(find.text('Đọc toàn bộ diễn biến'), findsOneWidget);
    });

    testWidgets('Premium chưa đủ dữ liệu thì nói thẳng, không dựng thẻ rỗng', (
      tester,
    ) async {
      await _pumpLarge(tester, _wrapJourney(premium: true));

      expect(find.byKey(const Key('wr_journey_narrative_card')), findsOneWidget);
      expect(find.textContaining('Chưa đủ dữ liệu'), findsOneWidget);
    });

    testWidgets('thẻ nằm TRÊN Career Memory — nó tóm cả chặng đường', (
      tester,
    ) async {
      await _pumpLarge(tester, _wrapJourney(premium: true));

      final card = tester
          .getTopLeft(find.byKey(const Key('wr_journey_narrative_card')));
      final memory = tester.getTopLeft(find.text('CAREER MEMORY'));
      expect(card.dy, lessThan(memory.dy));
    });

    testWidgets('bấm dòng dẫn mở màn Diễn biến riêng', (tester) async {
      await _pumpLarge(tester, _wrapJourney());

      await tester.tap(find.byKey(const Key('wr_journey_narrative_row')));
      await tester.pumpAndSettle();

      expect(find.text('Narrative'), findsOneWidget);
    });

    // ── Khung cố định, bấm để mở rộng (khách, họp 26_1) ───────────────────
    //
    // Bản kể do `wr-narrative` sinh ra không có giới hạn độ dài, nên chiều cao
    // thẻ phụ thuộc vào mô hình chứ không phải vào thiết kế — có hôm nó đẩy hết
    // Career Memory xuống dưới màn hình.

    testWidgets('đoạn dài bị kẹp lại, không kéo dài thẻ vô hạn', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternNarratives([
        PatternNarrative(
          id: 'n1',
          userId: 'u1',
          narrative: List.filled(80, 'Bạn đang học cách lên tiếng.').join(' '),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(intel: intel, premium: true));

      final para = tester.widget<WrParagraph>(
        find.descendant(
          of: find.byKey(const Key('wr_journey_narrative_expand')),
          matching: find.byType(WrParagraph),
        ),
      );
      expect(para.maxLines, kNarrativeCollapsedLines);
      expect(para.overflow, TextOverflow.ellipsis);
      expect(find.text('Mở rộng'), findsOneWidget);
    });

    testWidgets('bấm vào đoạn chữ thì bung ra, bấm lần nữa thì thu lại', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternNarratives([
        PatternNarrative(
          id: 'n1',
          userId: 'u1',
          narrative: List.filled(80, 'Bạn đang học cách lên tiếng.').join(' '),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(intel: intel, premium: true));

      WrParagraph body() => tester.widget<WrParagraph>(
            find.descendant(
              of: find.byKey(const Key('wr_journey_narrative_expand')),
              matching: find.byType(WrParagraph),
            ),
          );

      await tester.tap(find.byKey(const Key('wr_journey_narrative_expand')));
      await tester.pumpAndSettle();
      expect(body().maxLines, isNull);
      expect(find.text('Thu gọn'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wr_journey_narrative_expand')));
      await tester.pumpAndSettle();
      expect(body().maxLines, kNarrativeCollapsedLines);
    });

    testWidgets('câu chờ và câu quảng cáo Premium KHÔNG bị kẹp', (tester) async {
      // Hai câu đó do mình viết, độ dài đã biết trước. Kẹp thêm chỉ tổ cắt cụt
      // đúng câu đang giải thích vì sao chưa có gì để đọc.
      await _pumpLarge(tester, _wrapJourney(premium: true));

      final para = tester.widget<WrParagraph>(
        find.descendant(
          of: find.byKey(const Key('wr_journey_narrative_expand')),
          matching: find.byType(WrParagraph),
        ),
      );
      expect(para.maxLines, isNull);
      expect(find.text('Mở rộng'), findsNothing);
    });
  });
}
