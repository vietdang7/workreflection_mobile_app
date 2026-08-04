// Widget tests for CoachingScheduleScreen + schedule button in sessions screen
// — Phase 5 Task 6.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/coaching_repository.dart';
import 'package:workreflection_mobile/core/models/coaching_models.dart';
import 'package:workreflection_mobile/features/coaching/presentation/coaching_schedule_screen.dart';
import 'package:workreflection_mobile/features/coaching/presentation/coaching_screen.dart';
import 'package:workreflection_mobile/features/coaching/presentation/coaching_sessions_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_coaching_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _locDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _viLocale = [Locale('vi')];

/// Wraps [home] in GoRouter so context.push('/coaching/schedule/...') works.
Widget _wrapWithRouter(Widget home, FakeCoachingRepository repo) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => home),
      GoRoute(
        path: '/coaching/schedule/:bookingId',
        builder: (_, state) => CoachingScheduleScreen(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [coachingRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      routerConfig: router,
      localizationsDelegates: _locDelegates,
      supportedLocales: _viLocale,
    ),
  );
}

/// Simple MaterialApp wrapper (no router navigation needed).
Widget _wrapSimple(Widget home, FakeCoachingRepository repo) {
  return ProviderScope(
    overrides: [coachingRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      builder: wrTextScaleBuilder,
      localizationsDelegates: _locDelegates,
      supportedLocales: _viLocale,
      home: home,
    ),
  );
}

/// Cuộn tới nút gửi rồi mới bấm.
///
/// Nút nằm dưới đáy màn hình giả lập: cả trang là một `SingleChildScrollView`
/// nên trên máy thật người dùng cuộn xuống là thấy, nhưng trong test thì tâm nút
/// rơi ra ngoài khung 800×1400 và cú `tap` bắn vào khoảng không — không có gì
/// nhận sự kiện, và bài test đỏ ở chỗ chẳng liên quan gì tới thứ nó muốn kiểm.
Future<void> _tapSubmit(WidgetTester tester) async {
  final btn = find.byKey(const Key('scheduleSubmitBtn'));
  await tester.ensureVisible(btn);
  await tester.pumpAndSettle();
  await tester.tap(btn);
}

CoachingBooking _pendingBooking({
  String id = 'b-1',
  int sessionNumber = 1,
  int totalSessions = 3,
}) =>
    CoachingBooking(
      id: id,
      packageId: 'pkg-1',
      status: 'pending',
      sessionNumber: sessionNumber,
      totalSessions: totalSessions,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── CoachingSessionsScreen — schedule button ──────────────────────────────
  group('CoachingSessionsScreen — schedule button', () {
    late FakeCoachingRepository repo;

    setUp(() => repo = FakeCoachingRepository());

    testWidgets('pending booking shows Đặt lịch button', (tester) async {
      repo.seedBookings([_pendingBooking()]);

      await tester.pumpWidget(
          _wrapWithRouter(const CoachingSessionsScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Đặt lịch'), findsOneWidget);
    });

    testWidgets('scheduled booking does NOT show Đặt lịch button',
        (tester) async {
      repo.seedBookings([
        CoachingBooking(
          id: 'b-2',
          packageId: 'pkg-1',
          status: 'scheduled',
          scheduledAt: DateTime(2026, 9, 1, 10),
          sessionNumber: 1,
          totalSessions: 1,
        ),
      ]);

      await tester.pumpWidget(
          _wrapWithRouter(const CoachingSessionsScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Đặt lịch'), findsNothing);
    });
  });

  // ── CoachingScheduleScreen ────────────────────────────────────────────────
  group('CoachingScheduleScreen', () {
    late FakeCoachingRepository repo;

    setUp(() => repo = FakeCoachingRepository());

    testWidgets('shows not-found state when booking missing', (tester) async {
      await tester.pumpWidget(
          _wrapSimple(const CoachingScheduleScreen(bookingId: 'missing'), repo));
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy buổi coaching này'), findsOneWidget);
    });

    testWidgets('renders session label, date/time headers', (tester) async {
      repo.seedBookings(
          [_pendingBooking(id: 'b-1', sessionNumber: 2, totalSessions: 5)]);

      await tester.pumpWidget(
          _wrapSimple(const CoachingScheduleScreen(bookingId: 'b-1'), repo));
      await tester.pumpAndSettle();

      expect(find.text('Buổi 2/5'), findsOneWidget);
      expect(find.text('Chọn ngày'), findsOneWidget);
      expect(find.text('Chọn giờ'), findsOneWidget);
      expect(find.text('9:00'), findsOneWidget);
      expect(find.text('16:00'), findsOneWidget);
    });

    testWidgets('submit without date shows snackbar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      repo.seedBookings([_pendingBooking(id: 'b-1')]);

      await tester.pumpWidget(
          _wrapSimple(const CoachingScheduleScreen(bookingId: 'b-1'), repo));
      await tester.pumpAndSettle();

      await _tapSubmit(tester);
      await tester.pump(); // let snackbar render
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Vui lòng chọn ngày trước'), findsOneWidget);
      expect(repo.scheduleBookingCalls, isEmpty);
    });

    testWidgets(
        'selecting date + time then confirming calls repo correctly',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      repo.seedBookings([_pendingBooking(id: 'b-1')]);

      await tester.pumpWidget(
          _wrapSimple(const CoachingScheduleScreen(bookingId: 'b-1'), repo));
      await tester.pumpAndSettle();

      // Tap first selectable calendar cell
      final calendarGrid = find.byType(GridView).first;
      final detectors = tester
          .widgetList<GestureDetector>(
            find.descendant(of: calendarGrid, matching: find.byType(GestureDetector)),
          )
          .toList();

      bool tapped = false;
      for (final d in detectors) {
        if (d.onTap != null) {
          await tester.tap(find.byWidget(d));
          tapped = true;
          break;
        }
      }
      expect(tapped, isTrue, reason: 'should find at least one selectable day');
      await tester.pumpAndSettle();

      // Tap a time slot
      await tester.tap(find.text('10:00'));
      await tester.pumpAndSettle();

      // Submit
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      // Confirm dialog
      expect(find.byKey(const Key('scheduleConfirmBtn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scheduleConfirmBtn')));
      await tester.pumpAndSettle();

      expect(repo.scheduleBookingCalls.length, 1);
      expect(repo.scheduleBookingCalls.first['bookingId'], 'b-1');
      expect(repo.scheduleBookingCalls.first['time'], '10:00');
    });

    testWidgets('repo error shows error snackbar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      repo.seedBookings([_pendingBooking(id: 'b-1')]);

      await tester.pumpWidget(
          _wrapSimple(const CoachingScheduleScreen(bookingId: 'b-1'), repo));
      await tester.pumpAndSettle();

      // Select a date
      final calendarGrid = find.byType(GridView).first;
      final detectors = tester
          .widgetList<GestureDetector>(
            find.descendant(of: calendarGrid, matching: find.byType(GestureDetector)),
          )
          .toList();
      for (final d in detectors) {
        if (d.onTap != null) {
          await tester.tap(find.byWidget(d));
          break;
        }
      }
      await tester.pumpAndSettle();

      // Select a time
      await tester.tap(find.text('9:00'));
      await tester.pumpAndSettle();

      // Set error before submit
      repo.nextError = Exception('network');

      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('scheduleConfirmBtn')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Không thể đặt lịch. Vui lòng thử lại.'), findsOneWidget);
    });
  });

  // ── CoachingScreen — reviews section ─────────────────────────────────────
  group('CoachingScreen — reviews section', () {
    late FakeCoachingRepository repo;

    setUp(() => repo = FakeCoachingRepository());

    testWidgets('shows avg rating badge when reviews exist', (tester) async {
      repo.seedReviews(CoachReviewSummary(
        avgRating: 4.8,
        totalCount: 10,
        reviews: [
          const CoachReview(
              rating: 5, reviewerName: 'Nguyen A', comment: 'Rất tốt'),
          const CoachReview(
              rating: 4, reviewerName: 'Tran B', comment: 'Hài lòng'),
        ],
      ));

      await tester.pumpWidget(_wrapSimple(const CoachingScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('4.8/5.0'), findsOneWidget);
      expect(find.textContaining('Rất tốt'), findsOneWidget);
      expect(find.text('Nguyen A'), findsOneWidget);
    });

    testWidgets('hides reviews section when no reviews', (tester) async {
      // Default fake repo has 0 reviews
      await tester.pumpWidget(_wrapSimple(const CoachingScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Đánh giá từ khách hàng'), findsNothing);
    });
  });
}
