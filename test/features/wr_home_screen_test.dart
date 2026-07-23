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

    testWidgets('energy=low or stressed shows share card after save', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.textContaining('mệt mỏi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsOneWidget);
      expect(find.text('Chia sẻ thêm'), findsOneWidget);
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
}
