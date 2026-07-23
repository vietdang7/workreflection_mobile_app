// Widget tests for WrHomeScreen — updated for 2×2 mood grid restyle.
// UI mới: tap 1 nút → auto-save ngay, không cần chọn direction.
// Run: flutter test test/features/wr_home_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

GoRouter _makeRouter({required Widget home}) => GoRouter(
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
      ],
    );

Widget _wrap(
  Widget home, {
  FakeWrRepository? wr,
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String? userId,
}) {
  final wrRepo = wr ?? FakeWrRepository();
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = _makeRouter(home: home);
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

MobileProfile _profile({String name = 'Minh'}) => MobileProfile(
      userId: 'u1',
      displayName: name,
      reminderEnabled: true,
      language: 'vi',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 7, 22),
    );

void main() {
  group('WrHomeScreen — header', () {
    testWidgets('shows displayName from profile', (tester) async {
      final wr = FakeWrRepository()..seedProfile(_profile(name: 'Linh'));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      expect(find.textContaining('Linh'), findsWidgets);
    });

    testWidgets('falls back gracefully when no profile', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.byType(WrHomeScreen), findsOneWidget);
    });

    testWidgets('no profile avatar/person icon in header (profile is tab 5)', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.byIcon(Icons.person), findsNothing);
    });
  });

  group('WrHomeScreen — check-in 2×2 grid', () {
    testWidgets('renders 4 mood options', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.textContaining('căng thẳng'), findsOneWidget);
      expect(find.textContaining('mệt mỏi'), findsOneWidget);
      expect(find.textContaining('khá ổn'), findsOneWidget);
      expect(find.textContaining('đang vui'), findsOneWidget);
    });

    testWidgets('old energy labels gone', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.text('Có năng lượng'), findsNothing);
      expect(find.text('Bình thường'), findsNothing);
      expect(find.text('Mệt mỏi'), findsNothing);
    });

    testWidgets('old direction labels gone', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.text('Tiến lên'), findsNothing);
      expect(find.text('Đứng yên'), findsNothing);
      expect(find.text('Thụt lùi'), findsNothing);
    });

    testWidgets('no explicit Lưu check-in button', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.widgetWithText(ElevatedButton, 'Lưu check-in'), findsNothing);
    });

    testWidgets('tap mood option → auto-saves immediately (no second step)', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();
      expect(wr.upsertCheckinCalls.map((c) => c.mood), contains(Mood.happy));
      expect(wr.upsertCheckinCalls.first.direction, isNull);
    });

    testWidgets('tap "mệt mỏi" saves energy=low', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(wr.upsertCheckinCalls.first.energy, CheckinEnergy.low);
      expect(wr.upsertCheckinCalls.first.direction, isNull);
    });

    testWidgets('tap "khá ổn" saves energy=ok', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();
      expect(wr.upsertCheckinCalls.first.energy, CheckinEnergy.ok);
      expect(wr.upsertCheckinCalls.first.direction, isNull);
    });

    testWidgets('energy=low or stressed shows Q2 inline after save', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsOneWidget);
      expect(find.text('Chia sẻ thêm'), findsNothing);
    });

    testWidgets('energy=good does NOT show share card', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsNothing);
    });

    testWidgets('shows saved state when today checkin already exists', (tester) async {
      final wr = FakeWrRepository();
      final now = DateTime.now();
      wr.seedTodayCheckin(Checkin(
        id: 'c1',
        userId: 'u1',
        mood: Mood.okay,
        energy: CheckinEnergy.ok,
        direction: null,
        checkinDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      ));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      // Prepopulated — no error, screen renders fine
      expect(find.byType(WrHomeScreen), findsOneWidget);
    });
  });

  group('WrHomeScreen — error feedback', () {
    testWidgets('repo throws → no share card, shows SnackBar', (tester) async {
      final wr = FakeWrRepository();
      wr.setUpsertError(Exception('db error'));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsNothing);
      expect(find.textContaining('Không lưu được'), findsWidgets);
    });

    testWidgets('after error, re-tapping another option triggers upsert again', (tester) async {
      final wr = FakeWrRepository();
      wr.setUpsertError(Exception('db error'));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      // First attempt — fails (error thrown before recording in fake)
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      // Clear error
      wr.clearUpsertError();
      // Tap another option
      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();
      expect(wr.upsertCheckinCalls.length, 1);
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsNothing);
    });
  });

  // ── C1: race condition guard ────────────────────────────────────────────────

  group('WrHomeScreen — C1 race condition guard', () {
    testWidgets('tap nhanh 2 nút: trạng thái cuối (đang vui) được giữ, upsert cuối đúng mood', (tester) async {
      // FakeWrRepository.upsertCheckin() resolves synchronously in fake,
      // but _saving guard ensures sequential execution (latest-wins).
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      // Tap "căng thẳng" then immediately "đang vui" (before settle).
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pump(); // start first save, do not settle
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle(); // let both saves complete

      // Final UI state: "đang vui" selected (no share card)
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsNothing);

      // Last upsert was for happy mood
      expect(wr.upsertCheckinCalls.last.mood, Mood.happy);
      expect(wr.upsertCheckinCalls.last.energy, CheckinEnergy.good);
    });

    testWidgets('tap nhanh 2 nút: _selected không bị revert về null sau khi save xong', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pump();
      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();

      // Final selection is "khá ổn" — screen renders fine with no share card
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsNothing);
      expect(find.byType(WrHomeScreen), findsOneWidget);
    });
  });

  // ── I1: Mood.stressed mapping ───────────────────────────────────────────────

  group('WrHomeScreen — I1 Mood.stressed mapping', () {
    testWidgets('tap căng thẳng → upsertCheckin nhận Mood.stressed + energy low', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();

      expect(wr.upsertCheckinCalls, isNotEmpty);
      final call = wr.upsertCheckinCalls.first;
      expect(call.mood, Mood.stressed);
      expect(call.energy, CheckinEnergy.low);
      expect(call.direction, isNull);
    });

    testWidgets('tap mệt mỏi → upsertCheckin nhận Mood.tired (không phải stressed)', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();

      expect(wr.upsertCheckinCalls.first.mood, Mood.tired);
      expect(wr.upsertCheckinCalls.first.mood, isNot(Mood.stressed));
    });
  });

  // ── Q2 conversational reveal ────────────────────────────────────────────────

  group('WrHomeScreen — Q2 conversational reveal', () {
    testWidgets('stressed → Q2 shows "Điều gì đang khiến bạn căng thẳng?"', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await tester.tap(find.textContaining('căng thẳng'));
      await tester.pumpAndSettle();
      expect(find.text('Điều gì đang khiến bạn căng thẳng?'), findsOneWidget);
    });

    testWidgets('tired → Q2 shows "Bạn mệt vì điều gì?"', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn mệt vì điều gì?'), findsOneWidget);
    });

    testWidgets('okay → Q2 shows "Có điều gì bạn muốn nhìn lại hôm nay không?"', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await tester.tap(find.textContaining('khá ổn'));
      await tester.pumpAndSettle();
      expect(find.text('Có điều gì bạn muốn nhìn lại hôm nay không?'), findsOneWidget);
    });

    testWidgets('happy → Q2 shows "Điều gì làm bạn vui hôm nay?"', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await tester.tap(find.textContaining('đang vui'));
      await tester.pumpAndSettle();
      expect(find.text('Điều gì làm bạn vui hôm nay?'), findsOneWidget);
    });

    testWidgets('Q2 shows chips from wrSituationsProvider', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        WrSituation(code: 'sit-01', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
        WrSituation(code: 'sit-02', text: 'Mâu thuẫn nhóm', scaDimension: ScaDimension.s1, wave: 2),
      ]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(find.text('Áp lực deadline'), findsOneWidget);
      expect(find.text('Mâu thuẫn nhóm'), findsOneWidget);
    });

    testWidgets('"Khác →" chip navigates to /wr/situation', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khác →'));
      await tester.pumpAndSettle();
      expect(find.text('SituationScreen'), findsOneWidget);
    });

    testWidgets('chip tap → recordSituationOccurrence called with correct situationCode', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        WrSituation(code: 'sit-01', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
      ]);
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp lực deadline'));
      await tester.pumpAndSettle();
      expect(intel.recordSituationOccurrenceCalls, isNotEmpty);
      expect(intel.recordSituationOccurrenceCalls.first.situationCode, 'sit-01');
    });

    testWidgets('chip tap → first-time confirmation "Cảm ơn bạn đã chia sẻ..." shown', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        WrSituation(code: 'sit-01', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
      ]);
      final intel = FakeWrIntelligenceRepository();
      // No prior patterns → count will be 1 after save
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp lực deadline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cảm ơn bạn đã chia sẻ. Hệ thống sẽ ghi nhớ điều này.'), findsOneWidget);
    });

    testWidgets('chip tap → repeat confirmation "lần thứ N" shown when count>=2', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        WrSituation(code: 'sit-01', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
      ]);
      final intel = FakeWrIntelligenceRepository();
      // Seed 1 prior occurrence → after save fake increments to 2
      intel.seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-01',
          occurrenceCount: 1,
          lastSeenAt: DateTime(2026, 7, 20),
        ),
      ]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp lực deadline'));
      await tester.pumpAndSettle();
      // Confirmation text with "lần thứ 2" (not the HỆ THỐNG NHẬN RA card)
      expect(
        find.textContaining('Hệ thống đã ghi nhớ — đây là lần thứ 2 bạn chia sẻ điều này.'),
        findsOneWidget,
      );
    });

    testWidgets('(d) old share card "Bạn mệt vì điều gì?" no longer present after tired tap', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(find.text('Chia sẻ thêm'), findsNothing);
    });

    testWidgets('(e) prepopulate: Q2 visible immediately when today checkin exists', (tester) async {
      final wr = FakeWrRepository();
      final now = DateTime.now();
      wr.seedTodayCheckin(Checkin(
        id: 'c-ok',
        userId: 'u1',
        mood: Mood.okay,
        energy: CheckinEnergy.ok,
        direction: null,
        checkinDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      ));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      // Q2 visible for "okay" mood without tapping
      expect(find.text('Có điều gì bạn muốn nhìn lại hôm nay không?'), findsOneWidget);
    });

    testWidgets('chip error → SnackBar shown, chip deselected', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        WrSituation(code: 'sit-01', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
      ]);
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
      // Tap mood first and let it settle (invalidates wrPatternCountsProvider → fetchPatternCounts)
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      // Now set error — next intel call will be recordSituationOccurrence
      intel.nextError = Exception('db error');
      await tester.tap(find.text('Áp lực deadline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không lưu được tình huống'), findsWidgets);
    });

    testWidgets('story eyebrow is GỢI Ý CHO BẠN after chip saved', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        WrSituation(code: 'sit-01', text: 'Áp lực deadline', scaDimension: ScaDimension.s1, wave: 2),
      ]);
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content, intel: intel));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp lực deadline'));
      await tester.pumpAndSettle();
      expect(find.text('GỢI Ý CHO BẠN'), findsOneWidget);
    });
  });

  // ── I1: prepopulate dùng mood field ────────────────────────────────────────

  group('WrHomeScreen — I1 prepopulate theo checkin.mood', () {
    testWidgets('checkin mood=stressed → nút căng thẳng được chọn (Q2 hiện)', (tester) async {
      final wr = FakeWrRepository();
      final now = DateTime.now();
      wr.seedTodayCheckin(Checkin(
        id: 'c-stressed',
        userId: 'u1',
        mood: Mood.stressed,
        energy: CheckinEnergy.low,
        direction: null,
        checkinDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      ));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      // stressed → Q2 title hiện
      expect(find.textContaining('Điều gì đang khiến bạn căng thẳng?'), findsOneWidget);
      expect(find.text('Chia sẻ thêm'), findsNothing);
    });

    testWidgets('checkin mood=tired → Q2 hiện, stressed không bị chọn nhầm', (tester) async {
      final wr = FakeWrRepository();
      final now = DateTime.now();
      wr.seedTodayCheckin(Checkin(
        id: 'c-tired',
        userId: 'u1',
        mood: Mood.tired,
        energy: CheckinEnergy.low,
        direction: null,
        checkinDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      ));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      // tired → Q2 title "Bạn mệt vì điều gì?"
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsOneWidget);
      expect(find.text('Chia sẻ thêm'), findsNothing);
    });

    testWidgets('checkin mood=happy → không có share card', (tester) async {
      final wr = FakeWrRepository();
      final now = DateTime.now();
      wr.seedTodayCheckin(Checkin(
        id: 'c-happy',
        userId: 'u1',
        mood: Mood.happy,
        energy: CheckinEnergy.good,
        direction: null,
        checkinDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      ));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsNothing);
    });
  });
}
