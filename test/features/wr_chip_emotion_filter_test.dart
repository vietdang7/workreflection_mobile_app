// Tests cho Task 1: chip lọc theo cảm xúc + câu hỏi hướng tương lai + nhật ký ngày
// Task 2: Discover — nhu cầu chủ đạo từ hành vi
// Run: flutter test test/features/wr_chip_emotion_filter_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers — Home
// ─────────────────────────────────────────────────────────────────────────────

GoRouter _makeHomeRouter({required Widget home}) => GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => home),
        GoRoute(
          path: '/wr/situation',
          builder: (_, __) => const Scaffold(body: Text('SituationScreen')),
        ),
        GoRoute(
          path: '/wr/discover',
          builder: (_, __) => const Scaffold(body: Text('DiscoverScreen')),
        ),
        GoRoute(
          path: '/wr/story',
          builder: (_, __) => const Scaffold(body: Text('StoryScreen')),
        ),
        GoRoute(
          path: '/wr/story/flow',
          builder: (_, __) => const Scaffold(body: Text('StoryFlowScreen')),
        ),
      ],
    );

Widget _wrapHome(
  Widget home, {
  FakeWrRepository? wr,
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String? userId,
}) {
  final wrRepo = wr ?? FakeWrRepository();
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = _makeHomeRouter(home: home);
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(wrRepo),
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      currentUserIdProvider.overrideWithValue(userId ?? 'u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────────────
// Situation fixtures — nhóm theo humanNeed
// ─────────────────────────────────────────────────────────────────────────────

/// ketNoi situation
WrSituation _sitKetNoi({String code = 'kn-01', String text = 'Mâu thuẫn nhóm'}) =>
    WrSituation(
      code: code,
      text: text,
      scaDimension: ScaDimension.c1,
      wave: 1,
      humanNeed: HumanNeed.ketNoi,
    );

/// thichNghi situation
WrSituation _sitThichNghi({String code = 'tn-01', String text = 'Áp lực thay đổi'}) =>
    WrSituation(
      code: code,
      text: text,
      scaDimension: ScaDimension.c2,
      wave: 1,
      humanNeed: HumanNeed.thichNghi,
    );

/// roRang situation
WrSituation _sitRoRang({String code = 'rr-01', String text = 'Mơ hồ vai trò'}) =>
    WrSituation(
      code: code,
      text: text,
      scaDimension: ScaDimension.s1,
      wave: 2,
      humanNeed: HumanNeed.roRang,
    );

/// phatTrien situation
WrSituation _sitPhatTrien({
  String code = 'pt-01',
  String text = 'Muốn thăng tiến',
  ScaDimension dim = ScaDimension.a4,
}) =>
    WrSituation(
      code: code,
      text: text,
      scaDimension: dim,
      wave: 2,
      humanNeed: HumanNeed.phatTrien,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Helpers — Discover
// ─────────────────────────────────────────────────────────────────────────────

GoRouter _makeDiscoverRouter({required Widget home}) => GoRouter(
      initialLocation: '/discover',
      routes: [
        GoRoute(path: '/discover', builder: (_, __) => home),
        GoRoute(
          path: '/wr/self-check',
          builder: (_, __) => const Scaffold(body: Text('SelfCheckScreen')),
        ),
        GoRoute(
          path: '/wr/paywall',
          builder: (_, __) => const Scaffold(body: Text('PaywallScreen')),
        ),
      ],
    );

Widget _wrapDiscover(
  Widget home, {
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
  String? userId,
}) {
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final contentRepo = content ?? FakeWrContentRepository();
  final router = _makeDiscoverRouter(home: home);
  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      currentUserIdProvider.overrideWithValue(userId ?? 'u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

ScaSelfCheckResponse _selfCheck({
  double s = 3.5,
  double c = 4.0,
  double a = 2.0,
}) =>
    ScaSelfCheckResponse(
      id: 'r1',
      userId: 'u1',
      answers: const {},
      structureScore: s,
      cultureScore: c,
      activityScore: a,
      takenAt: DateTime(2026, 7, 20),
    );

PatternCount _pattern({
  required String code,
  int count = 3,
}) =>
    PatternCount(
      userId: 'u1',
      situationCode: code,
      occurrenceCount: count,
      lastSeenAt: DateTime(2026, 7, 18),
    );

// ─────────────────────────────────────────────────────────────────────────────
// TASK 1 — Home: Q2 title per emotion
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Task 1a — Q2 title per emotion', () {
    testWidgets('(a) stressed → "Điều gì đang khiến bạn căng thẳng?"', (tester) async {
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen()));
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();
      expect(find.text('Điều gì đang khiến bạn căng thẳng?'), findsOneWidget);
    });

    testWidgets('(a) tired → "Bạn mệt vì điều gì?"', (tester) async {
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen()));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn mệt vì điều gì?'), findsOneWidget);
    });

    testWidgets('(a) okay → "Có điều gì bạn muốn nhìn lại hôm nay không?"', (tester) async {
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen()));
      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();
      expect(find.text('Có điều gì bạn muốn nhìn lại hôm nay không?'), findsOneWidget);
    });

    testWidgets('(a) happy → "Bạn muốn phát triển điều gì tiếp theo?"', (tester) async {
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen()));
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn muốn phát triển điều gì tiếp theo?'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Task 1b — Chip filtering per need
  // ─────────────────────────────────────────────────────────────────────────

  group('Task 1b — stressed: chips chỉ thuộc ketNoi/thichNghi', () {
    testWidgets('(b) stressed: ketNoi chip có mặt', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitKetNoi(code: 'kn-01', text: 'Mâu thuẫn nhóm'),
        _sitThichNghi(code: 'tn-01', text: 'Áp lực thay đổi'),
        _sitRoRang(code: 'rr-01', text: 'Mơ hồ vai trò'),
      ]);
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), content: content));
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();
      expect(find.text('Mâu thuẫn nhóm'), findsOneWidget);
      expect(find.text('Áp lực thay đổi'), findsOneWidget);
    });

    testWidgets('(b) stressed: roRang chip KHÔNG có mặt', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitKetNoi(code: 'kn-01', text: 'Mâu thuẫn nhóm'),
        _sitRoRang(code: 'rr-01', text: 'Mơ hồ vai trò'),
      ]);
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), content: content));
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();
      expect(find.text('Mơ hồ vai trò'), findsNothing);
    });

    testWidgets('(b) stressed: phatTrien chip KHÔNG có mặt', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitKetNoi(code: 'kn-01', text: 'Mâu thuẫn nhóm'),
        _sitPhatTrien(code: 'pt-01', text: 'Muốn thăng tiến'),
      ]);
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), content: content));
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();
      expect(find.text('Muốn thăng tiến'), findsNothing);
    });
  });

  group('Task 1b — tired: chips chỉ thuộc thichNghi/phatTrien', () {
    testWidgets('tired: thichNghi chip có mặt', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitThichNghi(code: 'tn-01', text: 'Áp lực thay đổi'),
        _sitKetNoi(code: 'kn-01', text: 'Mâu thuẫn nhóm'),
      ]);
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), content: content));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(find.text('Áp lực thay đổi'), findsOneWidget);
      // ketNoi không thuộc tired's needs → không hiện
      expect(find.text('Mâu thuẫn nhóm'), findsNothing);
    });
  });

  group('Task 1b — happy: chips chỉ thuộc phatTrien + chip "Chỉ muốn ghi lại niềm vui"', () {
    testWidgets('(c) happy: phatTrien chip có mặt', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitPhatTrien(code: 'pt-01', text: 'Muốn thăng tiến'),
        _sitKetNoi(code: 'kn-01', text: 'Mâu thuẫn nhóm'),
      ]);
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), content: content));
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();
      expect(find.text('Muốn thăng tiến'), findsOneWidget);
    });

    testWidgets('(c) happy: ketNoi chip KHÔNG có mặt', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitPhatTrien(code: 'pt-01', text: 'Muốn thăng tiến'),
        _sitKetNoi(code: 'kn-01', text: 'Mâu thuẫn nhóm'),
      ]);
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), content: content));
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();
      expect(find.text('Mâu thuẫn nhóm'), findsNothing);
    });

    testWidgets('(c) happy: "Chỉ muốn ghi lại niềm vui" chip hiện', (tester) async {
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen()));
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();
      expect(find.text('Chỉ muốn ghi lại niềm vui'), findsOneWidget);
    });
  });

  group('Task 1b — okay: chip roRang + chip "Không, hôm nay ổn"', () {
    testWidgets('(d) okay: "Không, hôm nay ổn" chip hiện', (tester) async {
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen()));
      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();
      expect(find.text('Không, hôm nay ổn'), findsOneWidget);
    });

    testWidgets('(d) okay: roRang chip có mặt', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitRoRang(code: 'rr-01', text: 'Mơ hồ vai trò'),
        _sitKetNoi(code: 'kn-01', text: 'Mâu thuẫn nhóm'),
      ]);
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), content: content));
      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();
      expect(find.text('Mơ hồ vai trò'), findsOneWidget);
    });

    testWidgets('(d) okay: ketNoi chip KHÔNG có mặt', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitRoRang(code: 'rr-01', text: 'Mơ hồ vai trò'),
        _sitKetNoi(code: 'kn-01', text: 'Mâu thuẫn nhóm'),
      ]);
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), content: content));
      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();
      expect(find.text('Mâu thuẫn nhóm'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Task 1c — insertReflectionStep khi chọn chip tình huống
  // ─────────────────────────────────────────────────────────────────────────

  group('Task 1c — insertReflectionStep khi chọn chip tình huống', () {
    testWidgets('(e) chọn chip tình huống → insertReflectionStep gọi 1 lần, step=notice, content=code', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitKetNoi(code: 'kn-01', text: 'Mâu thuẫn nhóm'),
      ]);
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), content: content, intel: intel));
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mâu thuẫn nhóm'));
      await tester.pumpAndSettle();

      // recordSituationOccurrence phải được gọi
      expect(intel.recordSituationOccurrenceCalls, isNotEmpty);
      expect(intel.recordSituationOccurrenceCalls.first.situationCode, 'kn-01');

      // insertReflectionStep phải được gọi đúng 1 lần với step=notice, content=code
      expect(intel.insertReflectionStepCalls.length, 1);
      expect(intel.insertReflectionStepCalls.first.step, ReflectionStepType.notice);
      expect(intel.insertReflectionStepCalls.first.content, 'kn-01');
    });

    testWidgets('(e) chip tình huống dedup: tap lại chip đã ghi → insertReflectionStep KHÔNG gọi lần 2', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitKetNoi(code: 'kn-01', text: 'Mâu thuẫn nhóm'),
      ]);
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), content: content, intel: intel));

      // Tap lần 1
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mâu thuẫn nhóm'));
      await tester.pumpAndSettle();
      expect(intel.insertReflectionStepCalls.length, 1);

      // Đổi mood và quay lại → tap lại chip đã ghi
      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mâu thuẫn nhóm'));
      await tester.pumpAndSettle();

      // dedup: insertReflectionStep vẫn chỉ 1 lần
      expect(intel.insertReflectionStepCalls.length, 1,
          reason: 'Chip đã record trong session → insertReflectionStep không gọi lần 2');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Task 1c — "Chỉ muốn ghi lại niềm vui" (happy escape)
  // ─────────────────────────────────────────────────────────────────────────

  group('Task 1c — Chỉ muốn ghi lại niềm vui (happy escape)', () {
    testWidgets('(f) tap "Chỉ muốn ghi lại niềm vui" → insertReflectionStep gọi (content=Ghi lại niềm vui)', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), intel: intel));
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chỉ muốn ghi lại niềm vui'));
      await tester.pumpAndSettle();

      expect(intel.insertReflectionStepCalls.length, 1);
      expect(intel.insertReflectionStepCalls.first.step, ReflectionStepType.notice);
      expect(intel.insertReflectionStepCalls.first.content, 'Ghi lại niềm vui');
    });

    testWidgets('(f) tap "Chỉ muốn ghi lại niềm vui" → recordSituationOccurrence KHÔNG gọi', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), intel: intel));
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chỉ muốn ghi lại niềm vui'));
      await tester.pumpAndSettle();

      expect(intel.recordSituationOccurrenceCalls, isEmpty);
    });

    testWidgets('(f) tap "Chỉ muốn ghi lại niềm vui" → dòng kết "Đã ghi lại" hiện', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen(), intel: intel));
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chỉ muốn ghi lại niềm vui'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã ghi lại'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Task 1b — "Khác →" navigates to /wr/situation
  // ─────────────────────────────────────────────────────────────────────────

  group('Task 1b — "Khác →" navigation', () {
    testWidgets('(g) tap "Khác →" → navigates to /wr/situation', (tester) async {
      await _pumpLarge(tester, _wrapHome(const WrHomeScreen()));
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khác →'));
      await tester.pumpAndSettle();
      expect(find.text('SituationScreen'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TASK 2 — Discover: dominant need từ hành vi
  // ─────────────────────────────────────────────────────────────────────────

  group('Task 2 — Discover: nhu cầu chủ đạo từ hành vi', () {
    testWidgets('(h) patterns nghiêng ketNoi → quote "Được lắng nghe..." + caption "Kết nối · Nhu cầu chủ đạo"', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      // ketNoi count=5, phatTrien count=1
      intel.seedPatternCounts([
        _pattern(code: 'kn-01', count: 5),
        _pattern(code: 'pt-01', count: 1),
      ]);
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitKetNoi(code: 'kn-01'),
        _sitPhatTrien(code: 'pt-01'),
      ]);

      await _pumpLarge(tester, _wrapDiscover(const WrDiscoverScreen(), intel: intel, content: content));

      expect(find.textContaining('lắng nghe, tin tưởng'), findsOneWidget);
      expect(find.textContaining('Kết nối · Nhu cầu chủ đạo'), findsOneWidget);
    });

    testWidgets('(i) patterns nghiêng phatTrien → quote "Được làm công việc có ý nghĩa..." + "Phát triển · Nhu cầu chủ đạo"', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([
        _pattern(code: 'pt-01', count: 6),
        _pattern(code: 'kn-01', count: 1),
      ]);
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitPhatTrien(code: 'pt-01'),
        _sitKetNoi(code: 'kn-01'),
      ]);

      await _pumpLarge(tester, _wrapDiscover(const WrDiscoverScreen(), intel: intel, content: content));

      expect(find.textContaining('ý nghĩa và ngày càng tiến bộ'), findsOneWidget);
      expect(find.textContaining('Phát triển · Nhu cầu chủ đạo'), findsOneWidget);
    });

    testWidgets('(j) không có pattern nhưng có self-check, trụ C thấp nhất → fallback quote Kết nối', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      // No patterns
      // self-check: S=4.0, C=1.0 (lowest), A=3.0 → C lowest → ketNoi
      intel.seedSelfCheckHistory([_selfCheck(s: 4.0, c: 1.0, a: 3.0)]);

      await _pumpLarge(tester, _wrapDiscover(const WrDiscoverScreen(), intel: intel));

      expect(find.textContaining('lắng nghe, tin tưởng'), findsOneWidget);
      expect(find.textContaining('Kết nối · Nhu cầu chủ đạo'), findsOneWidget);
    });

    testWidgets('(k) không có pattern, không có self-check → empty state', (tester) async {
      await _pumpLarge(tester, _wrapDiscover(const WrDiscoverScreen()));
      expect(find.textContaining('15 câu phản chiếu'), findsWidgets);
    });

    testWidgets('(h2) patterns nghiêng roRang → quote "Được rõ ràng..." + "Rõ ràng · Nhu cầu chủ đạo"', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([
        _pattern(code: 'rr-01', count: 4),
        _pattern(code: 'kn-01', count: 1),
      ]);
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitRoRang(code: 'rr-01'),
        _sitKetNoi(code: 'kn-01'),
      ]);

      await _pumpLarge(tester, _wrapDiscover(const WrDiscoverScreen(), intel: intel, content: content));

      expect(find.textContaining('rõ ràng về vai trò'), findsOneWidget);
      expect(find.textContaining('Rõ ràng · Nhu cầu chủ đạo'), findsOneWidget);
    });

    testWidgets('(h3) patterns nghiêng thichNghi → quote "nhịp làm việc ổn định" + "Thích nghi · Nhu cầu chủ đạo"', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([
        _pattern(code: 'tn-01', count: 4),
      ]);
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sitThichNghi(code: 'tn-01'),
      ]);

      await _pumpLarge(tester, _wrapDiscover(const WrDiscoverScreen(), intel: intel, content: content));

      expect(find.textContaining('nhịp làm việc ổn định'), findsOneWidget);
      expect(find.textContaining('Thích nghi · Nhu cầu chủ đạo'), findsOneWidget);
    });

    testWidgets('Discover: tình huống lặp lại hiện khi chỉ có patterns (không cần self-check)', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(code: 'kn-01', count: 3)]);
      final content = FakeWrContentRepository();
      content.seedSituations([_sitKetNoi(code: 'kn-01')]);

      await _pumpLarge(tester, _wrapDiscover(const WrDiscoverScreen(), intel: intel, content: content));

      expect(find.textContaining('TÌNH HUỐNG LẶP LẠI'), findsOneWidget);
    });

    testWidgets('Discover: SCA card KHÔNG hiện khi chỉ có patterns, không có self-check', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      intel.seedPatternCounts([_pattern(code: 'kn-01', count: 3)]);
      final content = FakeWrContentRepository();
      content.seedSituations([_sitKetNoi(code: 'kn-01')]);

      await _pumpLarge(tester, _wrapDiscover(const WrDiscoverScreen(), intel: intel, content: content));

      expect(find.textContaining('TRẢI NGHIỆM HIỆN TẠI'), findsNothing);
    });
  });
}
