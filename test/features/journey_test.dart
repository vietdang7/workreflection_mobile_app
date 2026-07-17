import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/timeline_event.dart';
import 'package:workreflection_mobile/features/journey/presentation/journey_screen.dart';
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
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

TimelineEvent _event(
  String id,
  TimelineEventType type,
  String title,
  String? description,
  DateTime occurredAt,
) =>
    TimelineEvent(
      id: id,
      userId: 'u1',
      eventType: type,
      title: title,
      description: description,
      occurredAt: occurredAt,
      createdAt: occurredAt,
    );

void main() {
  group('JourneyScreen widget', () {
    testWidgets('renders header greeting and title', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const JourneyScreen(), repo));

      expect(find.textContaining('Career Memory'), findsOneWidget);
      expect(find.textContaining('Hành trình'), findsWidgets);
    });

    testWidgets('renders story quote block with eyebrow', (tester) async {
      final repo = FakeWrRepository();
      repo.seedInsights([
        Insight(
          id: 'i1',
          userId: 'u1',
          content: 'Trong 14 ngày qua, bạn đang học cách lên tiếng.',
          savedAt: DateTime(2026, 6, 20),
        ),
      ]);
      await _pumpLarge(tester, _wrap(const JourneyScreen(), repo));

      // WrEyebrow uppercases: "CÂU CHUYỆN CỦA BẠN"
      expect(find.textContaining('CÂU CHUYỆN'), findsOneWidget);
    });

    testWidgets('renders timeline month eyebrow', (tester) async {
      final repo = FakeWrRepository();
      repo.seedTimelineEvents([
        _event('e1', TimelineEventType.milestone, 'Insight đầu tiên',
            'Tôi ngại nói thật vì lo bị đánh giá.', DateTime(2026, 6, 10)),
      ]);
      await _pumpLarge(tester, _wrap(const JourneyScreen(), repo));

      // Month eyebrow for June — "THÁNG 6"
      expect(find.textContaining('THÁNG 6'), findsOneWidget);
    });

    testWidgets('renders MILESTONE event with teal dot color key', (tester) async {
      final repo = FakeWrRepository();
      repo.seedTimelineEvents([
        _event('e1', TimelineEventType.milestone, 'Insight đầu tiên',
            'Tôi ngại nói.', DateTime(2026, 6, 10)),
      ]);
      await _pumpLarge(tester, _wrap(const JourneyScreen(), repo));

      expect(find.textContaining('Insight đầu tiên'), findsOneWidget);
      expect(find.textContaining('MILESTONE'), findsOneWidget);
      expect(find.byKey(const Key('tl_dot_milestone_e1')), findsOneWidget);
    });

    testWidgets('renders STORY event with coral dot color key', (tester) async {
      final repo = FakeWrRepository();
      repo.seedTimelineEvents([
        _event('e2', TimelineEventType.story, 'Hoàn thành Story #3',
            'Khi im lặng trở thành thói quen', DateTime(2026, 6, 15)),
      ]);
      await _pumpLarge(tester, _wrap(const JourneyScreen(), repo));

      expect(find.textContaining('Hoàn thành Story'), findsOneWidget);
      expect(find.textContaining('STORY'), findsOneWidget);
      expect(find.byKey(const Key('tl_dot_story_e2')), findsOneWidget);
    });

    testWidgets('renders THEME event with navy dot color key', (tester) async {
      final repo = FakeWrRepository();
      repo.seedTimelineEvents([
        _event('e3', TimelineEventType.theme, 'Voice Journey bắt đầu',
            'Trọng tâm phát triển được xác định', DateTime(2026, 6, 20)),
      ]);
      await _pumpLarge(tester, _wrap(const JourneyScreen(), repo));

      expect(find.textContaining('Voice Journey'), findsOneWidget);
      expect(find.textContaining('THEME'), findsOneWidget);
      expect(find.byKey(const Key('tl_dot_theme_e3')), findsOneWidget);
    });

    testWidgets('groups events by month', (tester) async {
      final repo = FakeWrRepository();
      repo.seedTimelineEvents([
        _event('e1', TimelineEventType.milestone, 'Event June',
            null, DateTime(2026, 6, 10)),
        _event('e2', TimelineEventType.story, 'Event May',
            null, DateTime(2026, 5, 15)),
      ]);
      await _pumpLarge(tester, _wrap(const JourneyScreen(), repo));

      // Two month group eyebrows
      expect(find.textContaining('THÁNG 6'), findsOneWidget);
      expect(find.textContaining('THÁNG 5'), findsOneWidget);
    });

    testWidgets('shows empty state when no timeline events', (tester) async {
      final repo = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const JourneyScreen(), repo));

      expect(find.byKey(const Key('journey_timeline_empty')), findsOneWidget);
    });

    testWidgets('renders caption with month and year', (tester) async {
      final repo = FakeWrRepository();
      repo.seedInsights([
        Insight(
          id: 'i1',
          userId: 'u1',
          content: 'Test insight.',
          savedAt: DateTime(2026, 6, 20),
        ),
      ]);
      await _pumpLarge(tester, _wrap(const JourneyScreen(), repo));

      // Caption: "Career Companion · Tháng {m}, {yyyy}"
      expect(find.textContaining('Career Companion'), findsOneWidget);
    });
  });
}
