// Widget tests for MyWorkshopsScreen — Task 11.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/data/workshop_repository.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';
import 'package:workreflection_mobile/features/workshops/presentation/my_workshops_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_workshop_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(FakeWorkshopRepository repo) {
  return ProviderScope(
    overrides: [
      workshopRepositoryProvider.overrideWithValue(repo),
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
      home: MyWorkshopsScreen(),
    ),
  );
}

WorkshopDetail _ws({
  String id = 'ws-1',
  String title = 'My Workshop',
}) =>
    WorkshopDetail(
      id: id,
      title: title,
      date: DateTime(2026, 8, 1),
      price: 0,
      currency: 'VND',
      currentParticipants: 0,
      status: 'active',
      isActive: true,
    );

WorkshopRegistration _reg({
  String id = 'reg-1',
  String workshopId = 'ws-1',
  String status = 'registered',
  bool attended = false,
  DateTime? checkedInAt,
}) =>
    WorkshopRegistration(
      id: id,
      workshopId: workshopId,
      userId: 'user-1',
      status: status,
      attended: attended,
      checkedInAt: checkedInAt,
      createdAt: DateTime(2026, 7, 1),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MyWorkshopsScreen', () {
    late FakeWorkshopRepository repo;

    setUp(() {
      repo = FakeWorkshopRepository();
    });

    testWidgets('shows workshop title and registered status chip', (tester) async {
      repo.seedWorkshops([_ws(title: 'Leadership 101')]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Leadership 101'), findsOneWidget);
      expect(find.text('Đã đăng ký'), findsOneWidget);
    });

    testWidgets('attended chip when attended=true', (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg(attended: true));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Đã tham dự'), findsOneWidget);
    });

    testWidgets('attended chip when checkedInAt is set', (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg(checkedInAt: DateTime(2026, 8, 1, 9, 0)));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Đã tham dự'), findsOneWidget);
    });

    testWidgets('cancelled chip for cancelled registration', (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg(status: 'cancelled'));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Đã hủy'), findsOneWidget);
    });

    testWidgets('shows empty state when no registrations', (tester) async {
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa đăng ký workshop nào'), findsOneWidget);
    });

    testWidgets('shows error card and retry refetches', (tester) async {
      repo.nextError = Exception('fail');

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Seed data so retry succeeds
      repo.seedWorkshops([_ws(title: 'Retry Workshop')]);
      repo.seedRegistration(_reg());

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Retry Workshop'), findsOneWidget);
    });

    // Spec §07: chỗ chưa có dữ liệu phải là một câu tường minh, không phải dấu
    // gạch ngang dài.
    testWidgets('fallback title when workshop detail is null', (tester) async {
      // Register for a workshop not in the seed list → getWorkshop returns null
      repo.seedRegistration(_reg(workshopId: 'missing-ws'));
      // No workshops seeded → getWorkshop('missing-ws') returns null

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có tên'), findsOneWidget);
    });

    testWidgets('cancel button visible when workshop is >48h away', (tester) async {
      final futureDate = DateTime.now().add(const Duration(days: 5));
      repo.seedWorkshops([
        WorkshopDetail(
          id: 'ws-1',
          title: 'Future Workshop',
          date: futureDate,
          price: 0,
          currency: 'VND',
          currentParticipants: 0,
          status: 'active',
          isActive: true,
        ),
      ]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_ws_cancel')), findsOneWidget);
    });

    testWidgets('cancel button NOT visible when workshop is <48h away', (tester) async {
      final soonDate = DateTime.now().add(const Duration(hours: 24));
      repo.seedWorkshops([
        WorkshopDetail(
          id: 'ws-1',
          title: 'Soon Workshop',
          date: soonDate,
          price: 0,
          currency: 'VND',
          currentParticipants: 0,
          status: 'active',
          isActive: true,
        ),
      ]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_ws_cancel')), findsNothing);
    });

    testWidgets('tapping cancel shows confirmation dialog then cancels',
        (tester) async {
      final futureDate = DateTime.now().add(const Duration(days: 5));
      repo.seedWorkshops([
        WorkshopDetail(
          id: 'ws-1',
          title: 'Workshop To Cancel',
          date: futureDate,
          price: 0,
          currency: 'VND',
          currentParticipants: 0,
          status: 'active',
          isActive: true,
        ),
      ]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Tap cancel link.
      await tester.tap(find.byKey(const Key('my_ws_cancel')));
      await tester.pumpAndSettle();

      // Confirmation dialog buttons should appear.
      expect(find.byKey(const Key('cancel_confirm')), findsOneWidget);
      expect(find.byKey(const Key('cancel_dismiss')), findsOneWidget);

      // Confirm cancellation.
      await tester.tap(find.byKey(const Key('cancel_confirm')));
      await tester.pumpAndSettle();

      expect(repo.cancelRegistrationCalls, hasLength(1));
      expect(repo.cancelRegistrationCalls.first, ('reg-1', 'ws-1'));
    });

    testWidgets('dismiss cancel dialog hides dialog without calling repo',
        (tester) async {
      final futureDate = DateTime.now().add(const Duration(days: 5));
      repo.seedWorkshops([
        WorkshopDetail(
          id: 'ws-1',
          title: 'Workshop X',
          date: futureDate,
          price: 0,
          currency: 'VND',
          currentParticipants: 0,
          status: 'active',
          isActive: true,
        ),
      ]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('my_ws_cancel')));
      await tester.pumpAndSettle();

      // Dismiss.
      await tester.tap(find.byKey(const Key('cancel_dismiss')));
      await tester.pumpAndSettle();

      expect(repo.cancelRegistrationCalls, isEmpty);
      expect(find.byKey(const Key('cancel_confirm')), findsNothing);
    });

    testWidgets('view results link shown for attended workshop with survey done',
        (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg(attended: true));
      repo.seedSubmittedSurvey('ws-1');

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_ws_view_results')), findsOneWidget);
    });

    testWidgets('view results link NOT shown when survey not submitted',
        (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg(attended: true));
      // No survey submitted.

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_ws_view_results')), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Certificate download button — Phase 5 Task 10
    // Eligibility: reg.attended == true (mirrors web line 586)
    // -----------------------------------------------------------------------

    testWidgets('download certificate button shown when attended=true',
        (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg(attended: true));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_ws_download_cert')), findsOneWidget);
    });

    testWidgets('download certificate button NOT shown when attended=false',
        (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg(attended: false));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_ws_download_cert')), findsNothing);
    });

    testWidgets(
        'download certificate button NOT shown for cancelled registration',
        (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg(status: 'cancelled', attended: false));

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_ws_download_cert')), findsNothing);
    });
  });
}
