// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/recurring_situation.dart';
import 'package:workreflection_mobile/features/home/presentation/home_screen.dart';
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

/// Set viewport to a large height so all content is visible in tests.
Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
  });

  group('HomeScreen widget', () {
    testWidgets('renders greeting with display name', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(displayName: 'Yumi'), repo));

      expect(find.textContaining('Chào Yumi'), findsOneWidget);
    });

    testWidgets('renders date title key', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(displayName: 'Bạn'), repo));

      final dateFinder = find.byKey(const Key('home_date_title'));
      expect(dateFinder, findsOneWidget);
    });

    testWidgets('renders check-in question', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(displayName: 'Test'), repo));

      expect(find.textContaining('Bạn đang trải qua điều gì?'), findsOneWidget);
    });

    testWidgets('renders 4 mood buttons', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(displayName: 'Test'), repo));

      expect(find.textContaining('căng thẳng'), findsOneWidget);
      expect(find.textContaining('mệt mỏi'), findsOneWidget);
      expect(find.textContaining('khá ổn'), findsOneWidget);
      expect(find.textContaining('đang vui'), findsOneWidget);
    });

    testWidgets('tapping mood button calls upsertCheckin', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(displayName: 'Test'), repo));

      await tester.tap(find.textContaining('khá ổn').first);
      await tester.pumpAndSettle();

      expect(repo.upsertCheckinCalls, contains(Mood.okay));
    });

    testWidgets('selected mood key changes after tap', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(displayName: 'Test'), repo));

      expect(find.byKey(const Key('mood_btn_happy_selected')), findsNothing);

      await tester.tap(find.textContaining('đang vui').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mood_btn_happy_selected')), findsOneWidget);
    });

    testWidgets('shows INSIGHT eyebrow and content when insight available', (tester) async {
      final repo = FakeWrRepository();
      repo.seedInsights([
        Insight(
          id: 'ins1',
          userId: 'u1',
          content: 'Tôi thường im lặng không phải vì không có ý kiến.',
          source: 'VOICE',
          savedAt: DateTime(2026, 6, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrap(const HomeScreen(displayName: 'Test'), repo));

      // WrEyebrow uppercases text: "INSIGHT GẦN NHẤT"
      expect(find.textContaining('INSIGHT'), findsWidgets);
      expect(find.textContaining('im lặng'), findsWidgets);
    });

    testWidgets('shows empty state when no insight', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(displayName: 'Test'), repo));

      expect(find.byKey(const Key('home_insight_empty')), findsOneWidget);
    });

    testWidgets('shows system card eyebrow when situation available', (tester) async {
      final repo = FakeWrRepository();
      repo.seedSituations([
        RecurringSituation(
          id: 's1',
          userId: 'u1',
          label: 'Ngại phản biện',
          occurrenceCount: 5,
          updatedAt: DateTime(2026, 6, 20),
        ),
      ]);

      await _pumpLarge(tester, _wrap(const HomeScreen(displayName: 'Test'), repo));

      // WrEyebrow uppercases: "HỆ THỐNG NHẬN RA"
      expect(find.textContaining('HỆ THỐNG'), findsOneWidget);
      expect(find.textContaining('Ngại phản biện'), findsOneWidget);
    });

    testWidgets('shows suggestion card eyebrow', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const HomeScreen(displayName: 'Test'), repo));

      // WrEyebrow uppercases: "GỢI Ý KHI MỆT MỎI"
      expect(find.textContaining('GỢI Ý'), findsOneWidget);
    });
  });
}
