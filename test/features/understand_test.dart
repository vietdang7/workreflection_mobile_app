import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/recurring_situation.dart';
import 'package:workreflection_mobile/core/models/sca_report.dart';
import 'package:workreflection_mobile/features/understand/presentation/understand_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';

Widget _wrap(Widget child, WrRepository repo) {
  return ProviderScope(
    overrides: [wrRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      builder: wrTextScaleBuilder,
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

void main() {
  group('UnderstandScreen widget', () {
    testWidgets('renders header greeting and title', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      expect(find.textContaining('Career Snapshot'), findsOneWidget);
      expect(find.textContaining('Hiểu mình'), findsOneWidget);
    });

    testWidgets('renders ĐIỀU BẠN ĐANG TÌM KIẾM eyebrow', (tester) async {
      final repo = FakeWrRepository();
      repo.seedInsights([
        Insight(
          id: 'i1',
          userId: 'u1',
          content: 'Được lắng nghe và thể hiện quan điểm.',
          source: 'VOICE',
          savedAt: DateTime(2026, 6, 1),
        ),
      ]);
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      // WrEyebrow uppercases
      expect(find.textContaining('ĐIỀU BẠN'), findsOneWidget);
    });

    testWidgets('renders recurring situations list', (tester) async {
      final repo = FakeWrRepository();
      repo.seedSituations([
        RecurringSituation(
          id: 's1',
          userId: 'u1',
          label: 'Ngại phản biện',
          occurrenceCount: 5,
          updatedAt: DateTime(2026, 6, 20),
        ),
        RecurringSituation(
          id: 's2',
          userId: 'u1',
          label: 'Tránh đối thoại khó',
          occurrenceCount: 4,
          updatedAt: DateTime(2026, 6, 20),
        ),
      ]);
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      expect(find.textContaining('Ngại phản biện'), findsOneWidget);
      expect(find.textContaining('Tránh đối thoại khó'), findsOneWidget);
      // Situation count labels
      expect(find.textContaining('5 lần'), findsOneWidget);
      expect(find.textContaining('4 lần'), findsOneWidget);
    });

    testWidgets('SCA card shows "Ổn định" for score >= 4', (tester) async {
      final repo = FakeWrRepository();
      repo.seedScaReport(ScaReport(
        id: 'r1',
        userId: 'u1',
        scoreStructure: 4.5,
        scoreCulture: 4.1,
        scoreActivity: 4.0,
        createdAt: DateTime(2026, 6, 1),
      ));
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      expect(find.textContaining('Ổn định'), findsWidgets);
    });

    testWidgets('SCA card shows "Đang cải thiện" for score 2.5–3.9', (tester) async {
      final repo = FakeWrRepository();
      repo.seedScaReport(ScaReport(
        id: 'r1',
        userId: 'u1',
        scoreStructure: 2.5,
        scoreCulture: 3.0,
        scoreActivity: 2.6,
        createdAt: DateTime(2026, 6, 1),
      ));
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      expect(find.textContaining('Đang cải thiện'), findsWidgets);
    });

    testWidgets('SCA card shows "Cần chú ý" for score < 2.5', (tester) async {
      final repo = FakeWrRepository();
      repo.seedScaReport(ScaReport(
        id: 'r1',
        userId: 'u1',
        scoreStructure: 2.4,
        scoreCulture: 1.0,
        scoreActivity: 2.0,
        createdAt: DateTime(2026, 6, 1),
      ));
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      expect(find.textContaining('Cần chú ý'), findsWidgets);
    });

    testWidgets('SCA card shows "Chưa đánh giá" when no report', (tester) async {
      final repo = FakeWrRepository();
      // No SCA report seeded
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      expect(find.textContaining('Chưa đánh giá'), findsWidgets);
    });

    testWidgets('renders Career Health Check section', (tester) async {
      final repo = FakeWrRepository();
      repo.seedInsights([
        Insight(id: 'i1', userId: 'u1', content: 'A', savedAt: DateTime(2026, 6, 1)),
        Insight(id: 'i2', userId: 'u1', content: 'B', savedAt: DateTime(2026, 6, 2)),
      ]);
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      expect(find.textContaining('reflection'), findsOneWidget);
      expect(find.textContaining('Bắt đầu kiểm tra'), findsOneWidget);
    });

    testWidgets('shows SCA row labels', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      expect(find.textContaining('Minh bạch vai trò'), findsOneWidget);
      expect(find.textContaining('An toàn khi lên tiếng'), findsOneWidget);
      expect(find.textContaining('Định hướng ý nghĩa'), findsOneWidget);
    });

    testWidgets('Career Health Check counts checkins + insights combined', (tester) async {
      // 3 checkins + 2 insights = 5 total reflections
      final repo = FakeWrRepository();
      repo.seedCheckinDates([
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 2),
        DateTime(2026, 6, 3),
      ]);
      repo.seedInsights([
        Insight(id: 'i1', userId: 'u1', content: 'A', savedAt: DateTime(2026, 6, 1)),
        Insight(id: 'i2', userId: 'u1', content: 'B', savedAt: DateTime(2026, 6, 2)),
      ]);
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      // understandHealthReady uses the combined count: "Bạn đã có đủ 5 reflection."
      expect(find.textContaining('5'), findsWidgets);
    });

    testWidgets('view-all insights link hidden when no insights but checkins exist',
        (tester) async {
      final repo = FakeWrRepository();
      // Seed checkins but ZERO insights — regression case: combined count > 0
      // but the link must still be hidden because there are no insights.
      repo.seedCheckinDates([
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 2),
        DateTime(2026, 6, 3),
      ]);
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      expect(find.byKey(const Key('understand_view_all_insights')), findsNothing);
    });

    testWidgets('view-all insights link visible when insights exist', (tester) async {
      final repo = FakeWrRepository();
      repo.seedInsights([
        Insight(
          id: 'i1',
          userId: 'u1',
          content: 'Tôi cần không gian để suy nghĩ.',
          source: 'VOICE',
          savedAt: DateTime(2026, 7, 1),
        ),
      ]);
      await _pumpLarge(tester, _wrap(const UnderstandScreen(), repo));

      expect(find.byKey(const Key('understand_view_all_insights')), findsOneWidget);
      expect(find.textContaining('Xem tất cả insight'), findsOneWidget);
    });
  });
}
