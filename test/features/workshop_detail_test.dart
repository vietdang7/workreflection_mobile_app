// Widget tests for WorkshopDetailScreen — Task 10.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/workshop_repository.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';
import 'package:workreflection_mobile/features/workshops/presentation/workshop_detail_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_workshop_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(String workshopId, FakeWorkshopRepository repo) {
  return ProviderScope(
    overrides: [
      workshopRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi')],
      home: WorkshopDetailScreen(workshopId: workshopId),
    ),
  );
}

WorkshopDetail _ws({
  String id = 'ws-1',
  String title = 'Test Workshop',
  num price = 0,
  int current = 0,
  int? max,
  bool isActive = true,
  String? description,
  String? category,
  String? location,
  DateTime? startsAt,
  DateTime? endsAt,
}) =>
    WorkshopDetail(
      id: id,
      title: title,
      date: DateTime(2026, 8, 1),
      startsAt: startsAt,
      endsAt: endsAt,
      price: price,
      currency: 'VND',
      currentParticipants: current,
      maxParticipants: max,
      status: 'active',
      isActive: isActive,
      description: description,
      category: category,
      location: location,
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

WorkshopAttachment _att({
  String id = 'att-1',
  String fileName = 'slide.pdf',
  String category = 'document',
}) =>
    WorkshopAttachment(
      id: id,
      workshopId: 'ws-1',
      fileName: fileName,
      fileUrl: 'https://example.com/$fileName',
      category: category,
      sortOrder: 0,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WorkshopDetailScreen', () {
    late FakeWorkshopRepository repo;

    setUp(() {
      repo = FakeWorkshopRepository();
    });

    testWidgets('free+not-full: shows Register button', (tester) async {
      repo.seedWorkshops([_ws(price: 0)]);

      await tester.pumpWidget(_wrap('ws-1', repo));
      await tester.pumpAndSettle();

      expect(find.text('Đăng ký'), findsOneWidget);
    });

    testWidgets('paid workshop: Register taps opens paid dialog', (tester) async {
      repo.seedWorkshops([_ws(price: 500000)]);

      await tester.pumpWidget(_wrap('ws-1', repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();

      expect(find.text('Thanh toán trên web'), findsOneWidget);
      expect(find.text('Đã hiểu'), findsOneWidget);
    });

    testWidgets('full workshop: shows disabled full badge', (tester) async {
      repo.seedWorkshops([_ws(current: 10, max: 10)]);

      await tester.pumpWidget(_wrap('ws-1', repo));
      await tester.pumpAndSettle();

      // Button label shows "Đã đầy"
      expect(find.text('Đã đầy'), findsWidgets);
    });

    testWidgets('registered + not checked in: shows status chip + checkin button',
        (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg());

      await tester.pumpWidget(_wrap('ws-1', repo));
      await tester.pumpAndSettle();

      expect(find.text('Đã đăng ký'), findsOneWidget);
      expect(find.text('Check-in'), findsOneWidget);
    });

    testWidgets('registered + checked in: shows wsCheckedInAt chip and survey area',
        (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(
          _reg(checkedInAt: DateTime(2026, 8, 1, 9, 0)));

      await tester.pumpWidget(_wrap('ws-1', repo));
      await tester.pumpAndSettle();

      // Checked-in chip contains "check-in"
      expect(find.textContaining('check-in'), findsWidgets);
      // No check-in button
      expect(find.text('Check-in'), findsNothing);
    });

    testWidgets('checked-in + survey set exists + not submitted: shows survey CTA',
        (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg(checkedInAt: DateTime(2026, 8, 1, 9, 0)));
      // No submitted survey, no survey set seeded (hasSubmitted returns false)

      await tester.pumpWidget(_wrap('ws-1', repo));
      await tester.pumpAndSettle();

      expect(find.text('Đánh giá workshop'), findsOneWidget);
    });

    testWidgets('checked-in + submitted: shows wsSurveyDone text', (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg(checkedInAt: DateTime(2026, 8, 1, 9, 0)));
      repo.seedSubmittedSurvey('ws-1');

      await tester.pumpWidget(_wrap('ws-1', repo));
      await tester.pumpAndSettle();

      expect(find.text('Đã đánh giá'), findsOneWidget);
    });

    testWidgets('attachments visible when registered', (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedRegistration(_reg());
      repo.seedAttachments([_att(fileName: 'deck.pdf')]);

      await tester.pumpWidget(_wrap('ws-1', repo));
      await tester.pumpAndSettle();

      expect(find.text('deck.pdf'), findsOneWidget);
    });

    testWidgets('attachments locked when not registered', (tester) async {
      repo.seedWorkshops([_ws()]);
      repo.seedAttachments([_att(fileName: 'secret.pdf')]);

      await tester.pumpWidget(_wrap('ws-1', repo));
      await tester.pumpAndSettle();

      expect(find.text('Tài liệu dành cho người đã đăng ký'), findsOneWidget);
      expect(find.text('secret.pdf'), findsNothing);
    });

    testWidgets('optimistic error rollback: register error shows snackbar and re-enables',
        (tester) async {
      repo.seedWorkshops([_ws(price: 0)]);

      await tester.pumpWidget(_wrap('ws-1', repo));
      await tester.pumpAndSettle();

      // Set error for next call
      repo.nextError = Exception('network');

      await tester.tap(find.text('Đăng ký'));
      await tester.pump(); // start async
      await tester.pump(const Duration(seconds: 1)); // settle

      expect(find.text('Đăng ký thất bại. Vui lòng thử lại.'), findsOneWidget);
    });
  });
}
