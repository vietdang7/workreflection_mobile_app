// Widget tests for CoachingSessionsScreen — Phase 3 Task 15.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/data/coaching_repository.dart';
import 'package:workreflection_mobile/core/models/coaching_models.dart';
import 'package:workreflection_mobile/features/coaching/presentation/coaching_sessions_screen.dart';
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
      builder: wrTextScaleBuilder,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('vi')],
      home: CoachingSessionsScreen(),
    ),
  );
}

CoachingBooking _booking({
  String id = 'b-1',
  String packageId = 'pkg-1',
  String status = 'scheduled',
  int? sessionNumber = 1,
  int? totalSessions = 3,
  DateTime? scheduledAt,
  String? meetingLink,
}) =>
    CoachingBooking(
      id: id,
      packageId: packageId,
      status: status,
      sessionNumber: sessionNumber,
      totalSessions: totalSessions,
      scheduledAt: scheduledAt,
      meetingLink: meetingLink,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CoachingSessionsScreen', () {
    late FakeCoachingRepository repo;

    setUp(() {
      repo = FakeCoachingRepository();
    });

    testWidgets('groups bookings by status', (tester) async {
      repo.seedBookings([
        _booking(id: 'b1', status: 'scheduled', sessionNumber: 1, totalSessions: 2),
        _booking(id: 'b2', status: 'pending', sessionNumber: 2, totalSessions: 2),
        _booking(id: 'b3', status: 'completed', sessionNumber: 1, totalSessions: 1),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // All three section eyebrows visible (uppercased by WrEyebrow)
      expect(find.text('ĐÃ XẾP LỊCH'), findsOneWidget);
      expect(find.text('CHỜ XẾP LỊCH'), findsOneWidget);
      expect(find.text('HOÀN THÀNH'), findsOneWidget);
    });

    testWidgets('session x/y label renders correctly', (tester) async {
      repo.seedBookings([
        _booking(status: 'scheduled', sessionNumber: 2, totalSessions: 5),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Buổi 2/5'), findsOneWidget);
    });

    testWidgets('meeting link row taps and shows copied snackbar', (tester) async {
      // Use a tall surface so the card is well below the AppBar and tappable.
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      repo.seedBookings([
        _booking(
          status: 'scheduled',
          meetingLink: 'https://meet.example.com/abc',
        ),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Meeting link row is present
      expect(find.text('Link buổi học'), findsOneWidget);

      await tester.tap(find.text('Link buổi học'));
      await tester.pumpAndSettle();

      expect(find.text('Đã sao chép liên kết'), findsOneWidget);
    });

    testWidgets('pending chip renders for pending booking', (tester) async {
      repo.seedBookings([
        _booking(status: 'pending'),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Status chip shows "Chờ xếp lịch"
      expect(find.text('Chờ xếp lịch'), findsOneWidget);
    });

    testWidgets('shows empty state when no bookings', (tester) async {
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa có buổi coaching nào'), findsOneWidget);
    });

    testWidgets('error state shows retry button and retry refetches',
        (tester) async {
      repo.nextError = Exception('fail');

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Seed data so retry succeeds
      repo.seedBookings([_booking(status: 'pending')]);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Chờ xếp lịch'), findsOneWidget);
    });
  });
}
