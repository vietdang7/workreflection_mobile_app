// Widget tests for WorkshopsScreen — Task 9.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/data/workshop_repository.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';
import 'package:workreflection_mobile/features/workshops/presentation/workshops_screen.dart';
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
      home: WorkshopsScreen(),
    ),
  );
}

WorkshopDetail _ws({
  String id = 'ws-1',
  String title = 'Test Workshop',
  num price = 0,
  int current = 0,
  int? max,
  String? category,
  String? imageUrl,
  bool isActive = true,
}) =>
    WorkshopDetail(
      id: id,
      title: title,
      date: DateTime(2026, 8, 1),
      price: price,
      currency: 'VND',
      currentParticipants: current,
      maxParticipants: max,
      status: 'active',
      isActive: isActive,
      category: category,
      imageUrl: imageUrl,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WorkshopsScreen', () {
    late FakeWorkshopRepository repo;

    setUp(() {
      repo = FakeWorkshopRepository();
    });

    testWidgets('renders workshop items from provider', (tester) async {
      repo.seedWorkshops([
        _ws(id: 'ws-1', title: 'Workshop A'),
        _ws(id: 'ws-2', title: 'Workshop B'),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Workshop A'), findsOneWidget);
      expect(find.text('Workshop B'), findsOneWidget);
    });

    testWidgets('shows free chip for free workshop', (tester) async {
      repo.seedWorkshops([_ws(price: 0)]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Miễn phí'), findsOneWidget);
    });

    testWidgets('shows formatted price for paid workshop', (tester) async {
      repo.seedWorkshops([_ws(price: 500000, id: 'paid')]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Formatted price should contain '500' (locale separator may vary)
      expect(find.textContaining('500'), findsWidgets);
    });

    testWidgets('shows full badge when workshop is full', (tester) async {
      repo.seedWorkshops([_ws(current: 10, max: 10)]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Đã đầy'), findsOneWidget);
    });

    testWidgets('shows empty state when no workshops', (tester) async {
      repo.seedWorkshops([]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có workshop nào sắp diễn ra'), findsOneWidget);
    });

    testWidgets('shows error card and retry refetches', (tester) async {
      repo.nextError = Exception('network error');

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Error UI should be visible
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Seed workshops so retry succeeds
      repo.seedWorkshops([_ws(title: 'After Retry')]);

      // Tap retry
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('After Retry'), findsOneWidget);
    });
  });
}
