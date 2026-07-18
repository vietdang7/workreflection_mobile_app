import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/features/profile/presentation/vouchers_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';

Widget _wrap(Widget child, WrRepository repo) {
  return ProviderScope(
    overrides: [wrRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: child,
    ),
  );
}

FakeWrRepository _repoWithVouchers() {
  final repo = FakeWrRepository();
  repo.seedVouchers([
    {
      'id': 'v1',
      'code': 'SAVE20',
      'discount_type': 'percentage',
      'discount_percent': 20,
      'discount_amount': 0,
      'applicable_products': ['premium'],
      'valid_to': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'max_uses': 100,
      'used_count': 10,
      'target_type': 'all',
      'is_active': true,
    },
    {
      'id': 'v2',
      'code': 'EXPIRED',
      'discount_type': 'percentage',
      'discount_percent': 10,
      'discount_amount': 0,
      'applicable_products': <String>[],
      'valid_to': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'max_uses': 0,
      'used_count': 0,
      'target_type': 'all',
      'is_active': true,
    },
  ]);
  return repo;
}

void main() {
  group('VouchersScreen', () {
    testWidgets('shows list of vouchers', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = _repoWithVouchers();
      await tester.pumpWidget(_wrap(const VouchersScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vouchers_list')), findsOneWidget);
      expect(find.text('SAVE20'), findsOneWidget);
      expect(find.text('EXPIRED'), findsOneWidget);
    });

    testWidgets('shows empty state when no vouchers', (tester) async {
      final repo = FakeWrRepository();
      await tester.pumpWidget(_wrap(const VouchersScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vouchers_list')), findsNothing);
    });

    testWidgets('copy button triggers snackbar for available voucher',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = _repoWithVouchers();
      await tester.pumpWidget(_wrap(const VouchersScreen(), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('voucher_copy_v1')));
      await tester.pump(); // process tap
      await tester.pump(); // build snackbar frame

      expect(find.textContaining('SAVE20'), findsWidgets);

      // Advance past the 2-second timer so no pending timers remain.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows web note banner', (tester) async {
      final repo = _repoWithVouchers();
      await tester.pumpWidget(_wrap(const VouchersScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('FakeWrRepository voucher contract', () {
    test('getVouchers returns seeded data', () async {
      final repo = FakeWrRepository();
      repo.seedVouchers([
        {'id': 'x', 'code': 'TEST', 'is_active': true},
      ]);
      final list = await repo.getVouchers();
      expect(list, hasLength(1));
      expect(list.first['code'], 'TEST');
    });

    test('getVouchers returns empty list when not seeded', () async {
      final repo = FakeWrRepository();
      final list = await repo.getVouchers();
      expect(list, isEmpty);
    });
  });
}
