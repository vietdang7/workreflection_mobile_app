// Widget tests for WrHomeScreen — updated for restyle (Task 2A).
// UI mới: auto-save khi đủ energy+direction, không có nút "Lưu check-in",
// không có Icons.person trong header, direction row ẩn cho đến khi chọn energy.

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
      // New design: profile moved to tab 5, no inline avatar
      expect(find.byIcon(Icons.person), findsNothing);
    });
  });

  group('WrHomeScreen — check-in (auto-save UI)', () {
    testWidgets('renders 3 energy options always visible', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.text('Có năng lượng'), findsOneWidget);
      expect(find.text('Bình thường'), findsOneWidget);
      expect(find.text('Mệt mỏi'), findsOneWidget);
    });

    testWidgets('direction row hidden before energy selected', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.text('Tiến lên'), findsNothing);
      expect(find.text('Đứng yên'), findsNothing);
      expect(find.text('Thụt lùi'), findsNothing);
    });

    testWidgets('direction row revealed after energy selected', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await tester.tap(find.text('Có năng lượng'));
      await tester.pumpAndSettle();
      expect(find.text('Tiến lên'), findsOneWidget);
      expect(find.text('Đứng yên'), findsOneWidget);
      expect(find.text('Thụt lùi'), findsOneWidget);
    });

    testWidgets('no explicit Lưu check-in button', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      expect(find.widgetWithText(ElevatedButton, 'Lưu check-in'), findsNothing);
    });

    testWidgets('auto-saves when energy + direction both selected', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Có năng lượng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiến lên'));
      await tester.pumpAndSettle();
      expect(wr.upsertCheckinCalls, contains(Mood.happy));
    });

    testWidgets('shows saved confirmation after auto-save', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Bình thường'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đứng yên'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã lưu'), findsOneWidget);
    });

    testWidgets('energy=low + direction shows share card after auto-save', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Mệt mỏi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thụt lùi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn mệt vì điều gì?'), findsOneWidget);
      expect(find.text('Chia sẻ thêm'), findsOneWidget);
    });

    testWidgets('energy=good does NOT show share card', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      await tester.tap(find.text('Có năng lượng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiến lên'));
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
        direction: CheckinDirection.steady,
        checkinDate: DateTime(now.year, now.month, now.day),
        createdAt: now,
      ));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));
      expect(find.textContaining('Đã lưu'), findsOneWidget);
    });
  });
}
