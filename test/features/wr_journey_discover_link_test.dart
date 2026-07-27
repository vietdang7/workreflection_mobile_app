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

      await _pumpLarge(tester, _wrapJourney(content: content));

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

      await _pumpLarge(tester, _wrapJourney(content: content));

      expect(find.text('PHẢN CHIẾU'), findsOneWidget);
      expect(find.text('THỰC HÀNH'), findsOneWidget);
      expect(find.text('INSIGHT'), findsOneWidget);
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

      await _pumpLarge(tester, _wrapJourney(content: content));

      expect(find.text('THÁNG 7, 2026'), findsOneWidget);
      expect(find.text('THÁNG 6, 2026'), findsOneWidget);
    });
  });

  group('groupJourneyByMonth', () {
    JourneyEntry entry(String title, DateTime? at) =>
        JourneyEntry(at: at, label: 'PHẢN TƯ', title: title, color: Colors.black);

    test('gom các mục cùng tháng vào một cụm, giữ thứ tự đã sắp', () {
      final months = groupJourneyByMonth([
        entry('a', DateTime(2026, 7, 20)),
        entry('b', DateTime(2026, 7, 2)),
        entry('c', DateTime(2026, 6, 30)),
      ]);

      expect(months.map((m) => m.label).toList(),
          ['THÁNG 7, 2026', 'THÁNG 6, 2026']);
      expect(months.first.entries.map((e) => e.title).toList(), ['a', 'b']);
    });

    test('cùng tháng khác năm không bị gộp', () {
      final months = groupJourneyByMonth([
        entry('a', DateTime(2026, 7, 1)),
        entry('b', DateTime(2025, 7, 1)),
      ]);

      expect(months.length, 2);
    });

    test('mục không có thời gian dồn xuống cuối', () {
      final months = groupJourneyByMonth([
        entry('a', DateTime(2026, 7, 1)),
        entry('b', null),
      ]);

      expect(months.last.label, 'CHƯA RÕ THỜI GIAN');
      expect(months.last.entries.single.title, 'b');
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
