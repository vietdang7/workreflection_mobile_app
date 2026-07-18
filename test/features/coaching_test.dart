// Widget tests for CoachingScreen — Phase 3 Task 14.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/coaching_repository.dart';
import 'package:workreflection_mobile/core/models/coaching_models.dart';
import 'package:workreflection_mobile/features/coaching/presentation/coaching_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_coaching_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(FakeCoachingRepository repo) {
  return ProviderScope(
    overrides: [
      coachingRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('vi')],
      home: CoachingScreen(),
    ),
  );
}

CoachingPackage _pkg({
  String id = 'pkg-1',
  String name = 'Starter Pack',
  num price = 0,
  String currency = 'VND',
  int sessionsCount = 3,
  int? durationMinutes,
  List<String> features = const ['Feature A', 'Feature B'],
  String? targetAudience,
}) =>
    CoachingPackage(
      id: id,
      name: name,
      price: price,
      currency: currency,
      sessionsCount: sessionsCount,
      durationMinutes: durationMinutes,
      features: features,
      targetAudience: targetAudience,
      isActive: true,
      displayOrder: 0,
    );

Coach _coach({
  String id = 'coach-1',
  String fullName = 'Nguyen Van A',
  String? title = 'Senior Coach',
  String? avatarUrl,
  List<String> specializations = const ['Leadership', 'Career'],
  int? experienceYears = 5,
}) =>
    Coach(
      id: id,
      fullName: fullName,
      title: title,
      avatarUrl: avatarUrl,
      specializations: specializations,
      experienceYears: experienceYears,
      isActive: true,
      displayOrder: 0,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CoachingScreen', () {
    late FakeCoachingRepository repo;

    setUp(() {
      repo = FakeCoachingRepository();
    });

    testWidgets('renders package name and features', (tester) async {
      repo.seedPackages([
        _pkg(name: 'Starter Pack', features: ['Feature A', 'Feature B']),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Starter Pack'), findsOneWidget);
      expect(find.text('Feature A'), findsOneWidget);
      expect(find.text('Feature B'), findsOneWidget);
    });

    testWidgets('audience filter shows only matching packages', (tester) async {
      repo.seedPackages([
        _pkg(id: 'p1', name: 'Young Pack', targetAudience: 'young'),
        _pkg(id: 'p2', name: 'Manager Pack', targetAudience: 'manager'),
        _pkg(id: 'p3', name: 'All Pack', targetAudience: null),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Tap "Người trẻ" chip to filter to 'young'
      await tester.tap(find.text('Người trẻ'));
      await tester.pumpAndSettle();

      expect(find.text('Young Pack'), findsOneWidget);
      expect(find.text('All Pack'), findsOneWidget); // null always shown
      expect(find.text('Manager Pack'), findsNothing);
    });

    testWidgets('free CTA → confirm dialog → claim recorded', (tester) async {
      repo.seedPackages([_pkg(price: 0, name: 'Free Pack')]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Tap claim free button
      await tester.tap(find.text('Nhận gói miễn phí'));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Nhận gói coaching'), findsOneWidget);
      // Dialog body contains the package name (may also appear in card, use widgetList)
      expect(find.textContaining('Free Pack'), findsWidgets);

      // Tap OK
      await tester.tap(find.byKey(const Key('claimOkBtn')));
      await tester.pumpAndSettle();

      // Claim was recorded
      expect(repo.claimFreePackageCalls.length, 1);
      expect(repo.claimFreePackageCalls.first.name, 'Free Pack');
    });

    testWidgets('claim error shows snackbar and button re-enables',
        (tester) async {
      repo.seedPackages([_pkg(price: 0, name: 'Free Pack')]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nhận gói miễn phí'));
      await tester.pumpAndSettle();

      // Set error BEFORE confirming
      repo.nextError = Exception('network');

      await tester.tap(find.byKey(const Key('claimOkBtn')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Không thể kích hoạt gói. Vui lòng thử lại.'),
          findsOneWidget);

      // Button should be re-enabled (not loading) — find the claim button again
      await tester.pumpAndSettle();
      expect(find.text('Nhận gói miễn phí'), findsOneWidget);
    });

    testWidgets('paid package → shows paid dialog, no claim', (tester) async {
      repo.seedPackages([
        _pkg(id: 'p2', name: 'Premium Pack', price: 2000000),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Paid button
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      // Paid dialog
      expect(find.text('Thanh toán trên web'), findsOneWidget);
      expect(repo.claimFreePackageCalls, isEmpty);
    });

    testWidgets('coaches section renders initials fallback', (tester) async {
      repo.seedCoaches([
        _coach(fullName: 'Nguyen Van A', avatarUrl: null),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Initials: N + A = 'NA'
      expect(find.text('NA'), findsOneWidget);
      expect(find.text('Nguyen Van A'), findsOneWidget);
    });

    testWidgets('empty packages state shows empty text', (tester) async {
      // No packages seeded

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // wsEmpty string
      expect(find.text('Chưa có workshop nào sắp diễn ra'), findsOneWidget);
    });

    testWidgets('error state shows retry button and retry refetches',
        (tester) async {
      repo.nextError = Exception('fail');

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Seed data so retry succeeds
      repo.seedPackages([_pkg(name: 'Retry Pack')]);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Retry Pack'), findsOneWidget);
    });

    testWidgets('view-my button exists in AppBar', (tester) async {
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('coachViewMyBtn')), findsOneWidget);
      expect(find.text('Xem lịch của tôi'), findsOneWidget);
    });
  });
}
