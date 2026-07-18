import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/development_theme.dart';
import 'package:workreflection_mobile/core/models/practice.dart';
import 'package:workreflection_mobile/core/models/workshop.dart';
import 'package:workreflection_mobile/features/develop/presentation/develop_screen.dart';
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

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Practice _practice(String id, String title, PracticeStatus status) => Practice(
      id: id,
      userId: 'u1',
      title: title,
      status: status,
      practiceDate: DateTime(2026, 6, 24),
      createdAt: DateTime(2026, 6, 24),
    );

DevelopmentTheme _theme() => DevelopmentTheme(
      id: 't1',
      userId: 'u1',
      code: 'VOICE',
      title: 'Khả năng lên tiếng & phản biện',
      stage: 2,
      totalStages: 4,
      progress: 0.55,
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  group('DevelopScreen widget', () {
    testWidgets('renders header greeting and title', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      expect(find.textContaining('Development Map'), findsOneWidget);
      expect(find.textContaining('Phát triển'), findsOneWidget);
    });

    testWidgets('renders theme focus card with code and title', (tester) async {
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      expect(find.textContaining('VOICE'), findsWidgets);
      expect(find.textContaining('lên tiếng'), findsOneWidget);
      // Stage text
      expect(find.textContaining('2'), findsWidgets);
      expect(find.textContaining('4'), findsWidgets);
    });

    testWidgets('renders done practice with Hoàn thành status', (tester) async {
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      repo.seedPractices([
        _practice('p1', 'Quan sát lúc muốn im lặng', PracticeStatus.done),
      ]);
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      expect(find.textContaining('Quan sát lúc muốn im lặng'), findsOneWidget);
      expect(find.textContaining('Hoàn thành'), findsOneWidget);
    });

    testWidgets('renders doing practice with Đang thực hiện status', (tester) async {
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      repo.seedPractices([
        _practice('p2', 'Đặt một câu hỏi trong họp', PracticeStatus.doing),
      ]);
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      expect(find.textContaining('Đặt một câu hỏi'), findsOneWidget);
      expect(find.textContaining('Đang thực hiện'), findsOneWidget);
    });

    testWidgets('renders todo practice with Chưa bắt đầu status', (tester) async {
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      repo.seedPractices([
        _practice('p3', 'Chia sẻ một quan điểm', PracticeStatus.todo),
      ]);
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      expect(find.textContaining('Chia sẻ một quan điểm'), findsOneWidget);
      expect(find.textContaining('Chưa bắt đầu'), findsOneWidget);
    });

    testWidgets('tapping todo practice advances to doing and calls repo', (tester) async {
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      repo.seedPractices([
        _practice('p3', 'Chia sẻ một quan điểm', PracticeStatus.todo),
      ]);
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      await tester.tap(find.textContaining('Chia sẻ một quan điểm').first);
      await tester.pumpAndSettle();

      expect(repo.updatePracticeStatusCalls, contains(('p3', PracticeStatus.doing)));
    });

    testWidgets('tapping doing practice advances to done and calls repo', (tester) async {
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      repo.seedPractices([
        _practice('p2', 'Đặt một câu hỏi trong họp', PracticeStatus.doing),
      ]);
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      await tester.tap(find.textContaining('Đặt một câu hỏi').first);
      await tester.pumpAndSettle();

      expect(repo.updatePracticeStatusCalls, contains(('p2', PracticeStatus.done)));
    });

    testWidgets('done practice is not tappable (no further status call)', (tester) async {
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      repo.seedPractices([
        _practice('p1', 'Quan sát lúc muốn im lặng', PracticeStatus.done),
      ]);
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      await tester.tap(find.textContaining('Quan sát lúc muốn im lặng').first);
      await tester.pumpAndSettle();

      expect(repo.updatePracticeStatusCalls, isEmpty);
    });

    testWidgets('shows no-theme empty state when theme is null', (tester) async {
      final repo = FakeWrRepository();
      // No theme seeded
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      expect(find.byKey(const Key('develop_no_theme')), findsOneWidget);
    });

    testWidgets('shows workshop card when workshop available', (tester) async {
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      repo.seedWorkshop(Workshop(
        id: 'w1',
        title: 'Nói để được nghe',
        date: DateTime(2026, 7, 1),
      ));
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      expect(find.textContaining('Nói để được nghe'), findsOneWidget);
      // Workshop tag (uppercased by WrEyebrow-like widget or direct Text)
      expect(find.textContaining('WORKSHOP'), findsOneWidget);
    });

    testWidgets('opportunity card shows view-workshops and view-coaching links', (tester) async {
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      repo.seedWorkshop(Workshop(
        id: 'w1',
        title: 'Nói để được nghe',
        date: DateTime(2026, 7, 1),
      ));
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      expect(find.byKey(const Key('develop_view_workshops')), findsOneWidget);
      expect(find.byKey(const Key('develop_view_coaching')), findsOneWidget);
    });

    testWidgets('hides workshop section when no workshop', (tester) async {
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      // No workshop seeded
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      expect(find.textContaining('Nói để được nghe'), findsNothing);
    });

    testWidgets('shows practices from most recent date when today has none', (tester) async {
      // Seed practices with yesterday's date only (simulates day 2+)
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final repo = FakeWrRepository();
      repo.seedActiveTheme(_theme());
      repo.seedPractices([
        Practice(
          id: 'old1',
          userId: 'u1',
          title: 'Practice from yesterday',
          status: PracticeStatus.todo,
          practiceDate: yesterday,
          createdAt: yesterday,
        ),
      ]);
      await _pumpLarge(tester, _wrap(const DevelopScreen(), repo));

      // Should show the practice from the most recent date, not show empty state
      expect(find.textContaining('Practice from yesterday'), findsOneWidget);
    });
  });
}
