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
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_journey_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_content_repository.dart';
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
      ],
    );

Widget _wrapJourney({
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String userId = 'u1',
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = _makeRouter(home: const WrJourneyScreen());
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue(userId),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _wrapDiscover({
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String userId = 'u1',
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = _makeRouter(home: const WrDiscoverScreen());
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue(userId),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

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

      await _pumpLarge(tester, _wrapJourney(content: content));

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

      await _pumpLarge(tester, _wrapJourney(content: content));

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

      await _pumpLarge(tester, _wrapJourney(content: content));

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

      await _pumpLarge(tester, _wrapJourney(content: content));

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

      await _pumpLarge(tester, _wrapJourney(content: content));

      expect(find.text('Hôm nay tôi học được điều mới'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Task A: Chip chủ đề (humanNeed)
  // ─────────────────────────────────────────────────────────────────────────────

  group('Task A — Chip chủ đề humanNeed', () {
    testWidgets('humanNeed roRang → chip "Rõ ràng" hiện cạnh label loại', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          reflectionText: 'Cần biết rõ vai trò',
          humanNeed: HumanNeed.roRang,
          createdAt: DateTime(2026, 7, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content));

      expect(find.text('Rõ ràng'), findsOneWidget);
    });

    testWidgets('humanNeed ketNoi → chip "Kết nối"', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          reflectionText: 'Muốn kết nối đồng đội',
          humanNeed: HumanNeed.ketNoi,
          createdAt: DateTime(2026, 7, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content));

      expect(find.text('Kết nối'), findsOneWidget);
    });

    testWidgets('humanNeed phatTrien → chip "Phát triển"', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          reflectionText: 'Muốn phát triển bản thân',
          humanNeed: HumanNeed.phatTrien,
          createdAt: DateTime(2026, 7, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content));

      expect(find.text('Phát triển'), findsOneWidget);
    });

    testWidgets('không có humanNeed → không có chip', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          reflectionText: 'Không có nhu cầu',
          humanNeed: null,
          createdAt: DateTime(2026, 7, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content));

      // Không có chip text nào trong bộ 4 nhu cầu
      expect(find.text('Rõ ràng'), findsNothing);
      expect(find.text('Kết nối'), findsNothing);
      expect(find.text('Thích nghi'), findsNothing);
      expect(find.text('Phát triển'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Task B: Section "CHỦ ĐỀ LẶP LẠI" trên Journey
  // ─────────────────────────────────────────────────────────────────────────────

  group('Task B — Section CHỦ ĐỀ LẶP LẠI', () {
    testWidgets('có patterns → thấy eyebrow CHỦ ĐỀ LẶP LẠI', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_situation(code: 'sit-01', text: 'Áp lực deadline')]);

      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(code: 'sit-01', count: 4)]);

      await _pumpLarge(
        tester,
        _wrapJourney(content: content, intel: intel),
      );

      expect(find.textContaining('CHỦ ĐỀ LẶP LẠI'), findsOneWidget);
    });

    testWidgets('có patterns → thấy text tình huống và "N lần"', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_situation(code: 'sit-01', text: 'Áp lực deadline')]);

      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(code: 'sit-01', count: 4)]);

      await _pumpLarge(
        tester,
        _wrapJourney(content: content, intel: intel),
      );

      expect(find.text('Áp lực deadline'), findsWidgets);
      expect(find.textContaining('4 lần'), findsOneWidget);
    });

    testWidgets('có patterns → thấy link "Xem trong Hiểu mình →"', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(code: 'sit-01', count: 2)]);

      await _pumpLarge(tester, _wrapJourney(intel: intel));

      expect(find.textContaining('Xem trong Hiểu mình'), findsOneWidget);
    });

    testWidgets('không có patterns → section ẩn (không thấy CHỦ ĐỀ LẶP LẠI)', (tester) async {
      await _pumpLarge(tester, _wrapJourney());

      expect(find.textContaining('CHỦ ĐỀ LẶP LẠI'), findsNothing);
    });

    testWidgets('chỉ hiện top 3 patterns', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _situation(code: 'sit-01', text: 'Pattern 1'),
        _situation(code: 'sit-02', text: 'Pattern 2'),
        _situation(code: 'sit-03', text: 'Pattern 3'),
        _situation(code: 'sit-04', text: 'Pattern 4'),
      ]);

      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([
        _pattern(code: 'sit-01', count: 10),
        _pattern(code: 'sit-02', count: 8),
        _pattern(code: 'sit-03', count: 6),
        _pattern(code: 'sit-04', count: 4),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content, intel: intel));

      // 3 đầu hiện, cái 4 không hiện trong section CHỦ ĐỀ LẶP LẠI
      expect(find.text('Pattern 1'), findsWidgets);
      expect(find.text('Pattern 2'), findsWidgets);
      expect(find.text('Pattern 3'), findsWidgets);
      expect(find.text('Pattern 4'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Task C: Stats theo loại
  // ─────────────────────────────────────────────────────────────────────────────

  group('Task C — Stats theo loại', () {
    testWidgets('events nhiều loại → đếm đúng số lượng từng loại', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        // 2 Trải nghiệm (situationCode)
        _event(id: 'e1', userId: 'u1', situationCode: 'sit-01', createdAt: DateTime(2026, 7, 20)),
        _event(id: 'e2', userId: 'u1', situationCode: 'sit-02', createdAt: DateTime(2026, 7, 19)),
        // 1 Phản chiếu (storyId)
        _event(id: 'e3', userId: 'u1', storyId: 'story-01', createdAt: DateTime(2026, 7, 18)),
        // 1 Thực hành (practice_step_done)
        _event(id: 'e4', userId: 'u1', behavior: 'practice_step_done', createdAt: DateTime(2026, 7, 17)),
        // 1 Insight
        _event(id: 'e5', userId: 'u1', behavior: 'insight', createdAt: DateTime(2026, 7, 16)),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content));

      // Kiểm tra số đếm xuất hiện
      expect(find.text('2'), findsWidgets); // 2 Trải nghiệm
      expect(find.text('Trải nghiệm'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // Phản chiếu / Thực hành / Insight đều = 1
      expect(find.text('Phản chiếu'), findsOneWidget);
      expect(find.text('Thực hành'), findsOneWidget);
      expect(find.text('Insight'), findsWidgets); // Cũng có label INSIGHT trong timeline
    });

    testWidgets('0 events → stats row (journey_stats_row) không xuất hiện trong cây widget',
        (tester) async {
      await _pumpLarge(tester, _wrapJourney());

      // Narrative luôn hiện kể cả 0 events
      expect(find.textContaining('0 khoảnh khắc'), findsOneWidget);

      // _StatsRow có Key('journey_stats_row') — khi hasStats = false, widget không render
      expect(find.byKey(const Key('journey_stats_row')), findsNothing);
    });

    testWidgets('chỉ có event loại Trải nghiệm → chỉ hiện count Trải nghiệm', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(id: 'e1', userId: 'u1', situationCode: 'sit-01', createdAt: DateTime(2026, 7, 20)),
        _event(id: 'e2', userId: 'u1', situationCode: 'sit-02', createdAt: DateTime(2026, 7, 19)),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content));

      expect(find.text('Trải nghiệm'), findsOneWidget);
      // Phản chiếu và Thực hành không có → không hiện
      expect(find.text('Phản chiếu'), findsNothing);
      expect(find.text('Thực hành'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Task D: Empty state mới
  // ─────────────────────────────────────────────────────────────────────────────

  group('Task D — Empty state Journey mới', () {
    testWidgets('0 events → thấy "Career Memory trống"', (tester) async {
      await _pumpLarge(tester, _wrapJourney());

      expect(find.text('Career Memory trống'), findsOneWidget);
    });

    testWidgets('0 events → thấy 4 thẻ loại sự kiện', (tester) async {
      await _pumpLarge(tester, _wrapJourney());

      expect(find.text('Trải nghiệm'), findsOneWidget);
      expect(find.text('Phản chiếu'), findsOneWidget);
      expect(find.text('Thực hành'), findsOneWidget);
      expect(find.text('Insight'), findsOneWidget);
    });

    testWidgets('0 events → thấy nút "Tạo Memory đầu tiên →"', (tester) async {
      await _pumpLarge(tester, _wrapJourney());

      expect(find.textContaining('Tạo Memory đầu tiên'), findsOneWidget);
    });

    testWidgets('có events → không thấy grid empty state', (tester) async {
      final content = FakeWrContentRepository();
      content.seedMemoryEvents([
        _event(
          id: 'e1',
          userId: 'u1',
          reflectionText: 'Insight đầu tiên',
          createdAt: DateTime(2026, 7, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrapJourney(content: content));

      // Empty state không hiện
      expect(find.textContaining('Tạo Memory đầu tiên'), findsNothing);
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

      await _pumpLarge(tester, _wrapDiscover(content: content, intel: intel));

      expect(find.textContaining('Xem toàn bộ hành trình'), findsNothing);
      expect(find.text('Áp lực deadline'), findsOneWidget);
      expect(find.text('4 lần'), findsOneWidget);
    });
  });
}
