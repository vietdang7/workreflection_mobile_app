// Widget tests for CheckinScreen — Task 12.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/workshop_repository.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';
import 'package:workreflection_mobile/features/workshops/presentation/checkin_screen.dart';
import 'package:workreflection_mobile/features/workshops/workshops_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_workshop_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(FakeWorkshopRepository repo) {
  return ProviderScope(
    overrides: [
      workshopRepositoryProvider.overrideWithValue(repo),
      // Disable the real scanner in tests.
      checkinScannerEnabledProvider.overrideWithValue(false),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('vi')],
      home: CheckinScreen(),
    ),
  );
}

/// Pump the screen and tap the submit button with the given code.
Future<void> _submitCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
}

WorkshopDetail _ws({
  String id = 'ws-1',
  String checkinCode = 'ABCD1234',
  DateTime? startsAt,
}) =>
    WorkshopDetail(
      id: id,
      title: 'Test Workshop',
      date: DateTime(2026, 8, 1),
      startsAt: startsAt,
      price: 0,
      currency: 'VND',
      currentParticipants: 0,
      status: 'active',
      isActive: true,
      checkinCode: checkinCode,
    );

WorkshopRegistration _reg({
  String id = 'reg-1',
  String workshopId = 'ws-1',
  DateTime? checkedInAt,
  bool? imageConsent,
}) =>
    WorkshopRegistration(
      id: id,
      workshopId: workshopId,
      userId: 'user-1',
      status: 'registered',
      attended: false,
      checkedInAt: checkedInAt,
      imageConsent: imageConsent,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CheckinScreen', () {
    late FakeWorkshopRepository repo;

    setUp(() {
      repo = FakeWorkshopRepository();
    });

    testWidgets('invalid code shows wsCheckinInvalidCode', (tester) async {
      await tester.pumpWidget(_wrap(repo));
      await _submitCode(tester, 'BAD');

      expect(find.byKey(const Key('checkin_error')), findsOneWidget);
      expect(find.text('Mã không hợp lệ'), findsOneWidget);
      expect(repo.checkInCalls, isEmpty);
    });

    testWidgets('valid code but workshop not found shows wsCheckinNotFound',
        (tester) async {
      // No workshops seeded → getWorkshopByCheckinCode returns null.
      await tester.pumpWidget(_wrap(repo));
      await _submitCode(tester, 'ABCD1234');

      expect(find.byKey(const Key('checkin_error')), findsOneWidget);
      expect(find.text('Không tìm thấy workshop với mã này'), findsOneWidget);
    });

    testWidgets('user not registered shows wsCheckinNotRegistered',
        (tester) async {
      repo.seedWorkshops([_ws()]);
      // No registration seeded.

      await tester.pumpWidget(_wrap(repo));
      await _submitCode(tester, 'ABCD1234');

      expect(find.byKey(const Key('checkin_error')), findsOneWidget);
      expect(find.text('Bạn chưa đăng ký workshop này'), findsOneWidget);
    });

    testWidgets('too early shows wsCheckinTooEarly', (tester) async {
      // startsAt is 10 hours in the future → tooEarly.
      final startsAt = DateTime.now().add(const Duration(hours: 10));
      repo.seedWorkshops([_ws(startsAt: startsAt)]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap(repo));
      await _submitCode(tester, 'ABCD1234');

      expect(find.byKey(const Key('checkin_error')), findsOneWidget);
      expect(
          find.text(
              'Chưa đến giờ check-in (mở trước giờ bắt đầu 2 tiếng)'),
          findsOneWidget);
      expect(repo.checkInCalls, isEmpty);
    });

    testWidgets('closed shows wsCheckinClosed', (tester) async {
      // startsAt was 10 hours ago → closed (window is startsAt+4h).
      final startsAt = DateTime.now().subtract(const Duration(hours: 10));
      repo.seedWorkshops([_ws(startsAt: startsAt)]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap(repo));
      await _submitCode(tester, 'ABCD1234');

      expect(find.byKey(const Key('checkin_error')), findsOneWidget);
      expect(find.text('Đã hết giờ check-in'), findsOneWidget);
      expect(repo.checkInCalls, isEmpty);
    });

    testWidgets('success open window — checkIn called, shows success text',
        (tester) async {
      // startsAt 30 min ago → open window.
      final startsAt = DateTime.now().subtract(const Duration(minutes: 30));
      repo.seedWorkshops([_ws(startsAt: startsAt)]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap(repo));
      await _submitCode(tester, 'ABCD1234');

      expect(repo.checkInCalls, ['reg-1']);
      expect(find.byKey(const Key('checkin_success')), findsOneWidget);
      expect(find.text('Check-in thành công!'), findsOneWidget);
    });

    testWidgets('success unknown window (null startsAt) — checkIn called',
        (tester) async {
      // startsAt is null → unknown → treated as open.
      repo.seedWorkshops([_ws(startsAt: null)]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap(repo));
      await _submitCode(tester, 'ABCD1234');

      expect(repo.checkInCalls, ['reg-1']);
      expect(find.byKey(const Key('checkin_success')), findsOneWidget);
    });

    testWidgets('already-checked-in is idempotent — no checkIn call',
        (tester) async {
      final startsAt = DateTime.now().subtract(const Duration(minutes: 30));
      repo.seedWorkshops([_ws(startsAt: startsAt)]);
      // checkedInAt already set → idempotent.
      repo.seedRegistration(_reg(checkedInAt: DateTime.now()));

      await tester.pumpWidget(_wrap(repo));
      await _submitCode(tester, 'ABCD1234');

      expect(repo.checkInCalls, isEmpty);
      expect(find.byKey(const Key('checkin_success')), findsOneWidget);
    });

    testWidgets('consent dialog accept records setImageConsent true',
        (tester) async {
      final startsAt = DateTime.now().subtract(const Duration(minutes: 30));
      repo.seedWorkshops([_ws(startsAt: startsAt)]);
      // imageConsent is null → consent dialog should appear.
      repo.seedRegistration(_reg(imageConsent: null));

      await tester.pumpWidget(_wrap(repo));
      await _submitCode(tester, 'ABCD1234');

      // Consent dialog should be visible.
      expect(find.text('Cho phép sử dụng hình ảnh'), findsOneWidget);

      // Tap Accept.
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();

      expect(
        repo.setImageConsentCalls,
        contains(('reg-1', true)),
      );
    });

    testWidgets('consent dialog decline records setImageConsent false',
        (tester) async {
      final startsAt = DateTime.now().subtract(const Duration(minutes: 30));
      repo.seedWorkshops([_ws(startsAt: startsAt)]);
      repo.seedRegistration(_reg(imageConsent: null));

      await tester.pumpWidget(_wrap(repo));
      await _submitCode(tester, 'ABCD1234');

      expect(find.text('Cho phép sử dụng hình ảnh'), findsOneWidget);

      // Tap Decline.
      await tester.tap(find.text('Không đồng ý'));
      await tester.pumpAndSettle();

      expect(
        repo.setImageConsentCalls,
        contains(('reg-1', false)),
      );
    });

    testWidgets('repo error shows wsCheckinError', (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg());
      // Error thrown on checkIn call.
      repo.nextError = Exception('network error');

      await tester.pumpWidget(_wrap(repo));
      // The error fires on getWorkshopByCheckinCode because nextError fires
      // on the next ANY repo call. Re-seed so error fires at right step.
      // Reset and use a more targeted approach:
      repo = FakeWorkshopRepository();
      // Seed normally, then error fires on checkIn.
      final startsAt = DateTime.now().subtract(const Duration(minutes: 30));
      repo.seedWorkshops([_ws(startsAt: startsAt)]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap(repo));
      await tester.pump(); // settle initial build

      // Set error before submitting so it fires during checkIn.
      repo.nextError = Exception('network error');
      await _submitCode(tester, 'ABCD1234');

      expect(find.byKey(const Key('checkin_error')), findsOneWidget);
      expect(find.text('Check-in thất bại. Vui lòng thử lại.'), findsOneWidget);
    });
  });
}
