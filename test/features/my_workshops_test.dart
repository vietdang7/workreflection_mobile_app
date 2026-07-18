// Widget tests for MyWorkshopsScreen — Task 11.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('fallback title dash when workshop detail is null', (tester) async {
      // Register for a workshop not in the seed list → getWorkshop returns null
      repo.seedRegistration(_reg(workshopId: 'missing-ws'));
      // No workshops seeded → getWorkshop('missing-ws') returns null

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
    });
  });
}
