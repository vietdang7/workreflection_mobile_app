import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/widgets/section_divider.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

Widget _wrap({
  FakeWrRepository? wr,
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/wr/story', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/wr/situation', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/wr/discover', builder: (_, __) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(wr ?? FakeWrRepository()),
      wrContentRepositoryProvider.overrideWithValue(
        content ?? FakeWrContentRepository(),
      ),
      wrIntelligenceRepositoryProvider.overrideWithValue(
        intel ?? FakeWrIntelligenceRepository(),
      ),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('header shows name, date and profile avatar', (tester) async {
    final wr = FakeWrRepository()
      ..seedProfile(
        MobileProfile(
          userId: 'u1',
          displayName: 'Linh',
          reminderEnabled: true,
          language: 'vi',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026, 7, 25),
        ),
      );
    await _pump(tester, _wrap(wr: wr));

    expect(find.textContaining('Chào Linh'), findsOneWidget);
    expect(find.byKey(const Key('wr_home_profile_button')), findsOneWidget);
    expect(find.textContaining('/'), findsWidgets);
  });

  testWidgets('check-in follows the six-control prototype', (tester) async {
    await _pump(tester, _wrap());
    expect(find.text('Có năng lượng'), findsOneWidget);
    expect(find.text('Bình thường'), findsOneWidget);
    expect(find.text('Mệt mỏi'), findsOneWidget);

    await tester.tap(find.text('Mệt mỏi'));
    await tester.pumpAndSettle();
    expect(find.text('Tiến lên'), findsOneWidget);
    expect(find.text('Đứng yên'), findsOneWidget);
    expect(find.text('Thụt lùi'), findsOneWidget);
  });

  testWidgets('shows Career Snapshot setup prompt when profile is empty', (
    tester,
  ) async {
    await _pump(tester, _wrap());
    expect(find.text('CAREER SNAPSHOT'), findsOneWidget);
    expect(find.text('Thiết lập hồ sơ'), findsOneWidget);
  });

  testWidgets('shows latest insight and recurring pattern', (tester) async {
    final intel = FakeWrIntelligenceRepository()
      ..seedInsights([
        WrInsight(
          userId: 'u1',
          content: 'Tôi cần lên tiếng sớm hơn.',
          createdAt: DateTime(2026, 7, 20),
        ),
      ])
      ..seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-01',
          occurrenceCount: 3,
          lastSeenAt: DateTime(2026, 7, 20),
        ),
      ]);
    final content = FakeWrContentRepository()
      ..seedSituations([
        const WrSituation(
          code: 'sit-01',
          text: 'Ngại nêu ý kiến',
          scaDimension: ScaDimension.c2,
          wave: 2,
        ),
      ]);
    await _pump(tester, _wrap(content: content, intel: intel));

    expect(find.text('HỆ THỐNG NHẬN RA'), findsOneWidget);
    expect(find.textContaining('Ngại nêu ý kiến'), findsOneWidget);
    expect(find.textContaining('lên tiếng sớm hơn'), findsOneWidget);
  });

  testWidgets('keeps a single section divider before supporting content', (
    tester,
  ) async {
    await _pump(tester, _wrap());
    expect(find.byType(WrSectionDivider), findsOneWidget);
  });
}
