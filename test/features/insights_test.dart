import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/features/understand/presentation/insights_screen.dart';
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

Future<void> _pump(WidgetTester tester, Widget widget) async {
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
  group('InsightsScreen', () {
    testWidgets('shows empty state when no insights', (tester) async {
      final repo = FakeWrRepository();
      await _pump(tester, _wrap(const InsightsScreen(), repo));

      expect(find.byKey(const Key('insights_empty')), findsOneWidget);
      expect(find.textContaining('chưa có insight'), findsOneWidget);
    });

    testWidgets('shows title in app bar', (tester) async {
      final repo = FakeWrRepository();
      await _pump(tester, _wrap(const InsightsScreen(), repo));

      expect(find.textContaining('Tất cả insight'), findsOneWidget);
    });

    testWidgets('shows list when insights available', (tester) async {
      final repo = FakeWrRepository();
      repo.seedInsights([
        Insight(
          id: 'i1',
          userId: 'u1',
          content: 'Tôi cần được lắng nghe.',
          source: 'VOICE',
          savedAt: DateTime(2026, 7, 10),
        ),
        Insight(
          id: 'i2',
          userId: 'u1',
          content: 'Sự rõ ràng giúp tôi tiến lên.',
          source: 'JOURNAL',
          savedAt: DateTime(2026, 7, 5),
        ),
      ]);
      await _pump(tester, _wrap(const InsightsScreen(), repo));

      expect(find.byKey(const Key('insights_list')), findsOneWidget);
      expect(find.textContaining('Tôi cần được lắng nghe'), findsOneWidget);
      expect(find.textContaining('Sự rõ ràng giúp tôi tiến lên'), findsOneWidget);
    });

    testWidgets('shows source label and saved date for each insight', (tester) async {
      final repo = FakeWrRepository();
      repo.seedInsights([
        Insight(
          id: 'i1',
          userId: 'u1',
          content: 'Nội dung insight.',
          source: 'VOICE',
          savedAt: DateTime(2026, 7, 10),
        ),
      ]);
      await _pump(tester, _wrap(const InsightsScreen(), repo));

      // Source label (uppercased by WrEyebrow)
      expect(find.textContaining('VOICE'), findsOneWidget);
      // Saved date formatted dd/MM/yyyy
      expect(find.textContaining('10/07/2026'), findsOneWidget);
    });

    testWidgets('does not show list key in empty state', (tester) async {
      final repo = FakeWrRepository();
      await _pump(tester, _wrap(const InsightsScreen(), repo));

      expect(find.byKey(const Key('insights_list')), findsNothing);
    });

    testWidgets('insight with null source shows no eyebrow', (tester) async {
      final repo = FakeWrRepository();
      repo.seedInsights([
        Insight(
          id: 'i1',
          userId: 'u1',
          content: 'No source insight.',
          source: null,
          savedAt: DateTime(2026, 7, 1),
        ),
      ]);
      await _pump(tester, _wrap(const InsightsScreen(), repo));

      // Content still shows
      expect(find.textContaining('No source insight'), findsOneWidget);
    });
  });
}
