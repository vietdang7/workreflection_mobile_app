import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_discover_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

WrSituation _situation({
  required String code,
  required String text,
  required HumanNeed need,
  ScaDimension dimension = ScaDimension.c1,
}) {
  return WrSituation(
    code: code,
    text: text,
    scaDimension: dimension,
    wave: 2,
    humanNeed: need,
  );
}

Widget _wrapHome({
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const WrHomeScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/wr/story', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/wr/story/flow', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/wr/discover', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/wr/situation', builder: (_, __) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(FakeWrRepository()),
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

Future<void> _checkIn(WidgetTester tester, {required String energy}) async {
  await tester.tap(find.text(energy));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Đứng yên'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('wr_save_checkin_button')));
  await tester.pumpAndSettle();
}

Widget _wrapDiscover({
  FakeWrIntelligenceRepository? intel,
  FakeWrContentRepository? content,
}) {
  final router = GoRouter(
    initialLocation: '/discover',
    routes: [
      GoRoute(path: '/discover', builder: (_, __) => const WrDiscoverScreen()),
      GoRoute(path: '/wr/self-check', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/wr/paywall', builder: (_, __) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(
        intel ?? FakeWrIntelligenceRepository(),
      ),
      wrContentRepositoryProvider.overrideWithValue(
        content ?? FakeWrContentRepository(),
      ),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

PatternCount _pattern(String code, int count) => PatternCount(
  userId: 'u1',
  situationCode: code,
  occurrenceCount: count,
  lastSeenAt: DateTime(2026, 7, 18),
);

ScaSelfCheckResponse _selfCheck({
  required double s,
  required double c,
  required double a,
}) {
  return ScaSelfCheckResponse(
    id: 'r1',
    userId: 'u1',
    answers: const {},
    structureScore: s,
    cultureScore: c,
    activityScore: a,
    takenAt: DateTime(2026, 7, 20),
  );
}

void main() {
  group('Home — situation chips follow the selected energy', () {
    testWidgets('low energy prioritizes adaptability then connection', (
      tester,
    ) async {
      final content = FakeWrContentRepository()
        ..seedSituations([
          _situation(
            code: 'tn',
            text: 'Áp lực thay đổi',
            need: HumanNeed.thichNghi,
          ),
          _situation(
            code: 'kn',
            text: 'Mâu thuẫn nhóm',
            need: HumanNeed.ketNoi,
          ),
          _situation(code: 'rr', text: 'Mơ hồ vai trò', need: HumanNeed.roRang),
        ]);
      await _pumpLarge(tester, _wrapHome(content: content));
      await _checkIn(tester, energy: 'Mệt mỏi');

      expect(find.text('Áp lực thay đổi'), findsOneWidget);
      expect(find.text('Mâu thuẫn nhóm'), findsOneWidget);
      expect(find.text('Mơ hồ vai trò'), findsNothing);
    });

    testWidgets('normal energy only offers clarity situations', (tester) async {
      final content = FakeWrContentRepository()
        ..seedSituations([
          _situation(
            code: 'rr',
            text: 'Mơ hồ vai trò',
            need: HumanNeed.roRang,
            dimension: ScaDimension.s1,
          ),
          _situation(
            code: 'kn',
            text: 'Mâu thuẫn nhóm',
            need: HumanNeed.ketNoi,
          ),
        ]);
      await _pumpLarge(tester, _wrapHome(content: content));
      await _checkIn(tester, energy: 'Bình thường');

      expect(find.text('Mơ hồ vai trò'), findsOneWidget);
      expect(find.text('Mâu thuẫn nhóm'), findsNothing);
      expect(find.text('Không, hôm nay ổn'), findsOneWidget);
    });

    testWidgets('good energy only offers growth situations and joy escape', (
      tester,
    ) async {
      final content = FakeWrContentRepository()
        ..seedSituations([
          _situation(
            code: 'pt',
            text: 'Muốn thăng tiến',
            need: HumanNeed.phatTrien,
            dimension: ScaDimension.a4,
          ),
          _situation(
            code: 'kn',
            text: 'Mâu thuẫn nhóm',
            need: HumanNeed.ketNoi,
          ),
        ]);
      await _pumpLarge(tester, _wrapHome(content: content));
      await _checkIn(tester, energy: 'Có năng lượng');

      expect(find.text('Muốn thăng tiến'), findsOneWidget);
      expect(find.text('Mâu thuẫn nhóm'), findsNothing);
      expect(find.text('Chỉ muốn ghi lại niềm vui'), findsOneWidget);
    });

    testWidgets('selecting a chip records one Notice reflection step', (
      tester,
    ) async {
      final content = FakeWrContentRepository()
        ..seedSituations([
          _situation(
            code: 'kn',
            text: 'Mâu thuẫn nhóm',
            need: HumanNeed.ketNoi,
          ),
        ]);
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrapHome(content: content, intel: intel));
      await _checkIn(tester, energy: 'Mệt mỏi');
      await tester.tap(find.text('Mâu thuẫn nhóm'));
      await tester.pumpAndSettle();

      expect(intel.recordSituationOccurrenceCalls, hasLength(1));
      expect(intel.insertReflectionStepCalls, hasLength(1));
      expect(
        intel.insertReflectionStepCalls.single.step,
        ReflectionStepType.notice,
      );
      expect(intel.insertReflectionStepCalls.single.content, 'kn');
    });
  });

  group('Discover — dominant need from observed behaviour', () {
    testWidgets('connection-heavy patterns surface connection narrative', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern('kn', 5), _pattern('pt', 1)]);
      final content = FakeWrContentRepository()
        ..seedSituations([
          _situation(
            code: 'kn',
            text: 'Mâu thuẫn nhóm',
            need: HumanNeed.ketNoi,
          ),
          _situation(
            code: 'pt',
            text: 'Muốn thăng tiến',
            need: HumanNeed.phatTrien,
            dimension: ScaDimension.a4,
          ),
        ]);
      await _pumpLarge(tester, _wrapDiscover(intel: intel, content: content));
      expect(find.textContaining('lắng nghe, tin tưởng'), findsOneWidget);
      expect(find.textContaining('Kết nối · Nhu cầu chủ đạo'), findsOneWidget);
    });

    testWidgets('growth-heavy patterns surface growth narrative', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern('pt', 6), _pattern('kn', 1)]);
      final content = FakeWrContentRepository()
        ..seedSituations([
          _situation(
            code: 'pt',
            text: 'Muốn thăng tiến',
            need: HumanNeed.phatTrien,
            dimension: ScaDimension.a4,
          ),
          _situation(
            code: 'kn',
            text: 'Mâu thuẫn nhóm',
            need: HumanNeed.ketNoi,
          ),
        ]);
      await _pumpLarge(tester, _wrapDiscover(intel: intel, content: content));
      expect(
        find.textContaining('ý nghĩa và ngày càng tiến bộ'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Phát triển · Nhu cầu chủ đạo'),
        findsOneWidget,
      );
    });

    testWidgets('lowest Self-Check pillar is used when patterns are absent', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedSelfCheckHistory([_selfCheck(s: 4, c: 1, a: 3)]);
      await _pumpLarge(tester, _wrapDiscover(intel: intel));
      expect(find.textContaining('lắng nghe, tin tưởng'), findsOneWidget);
      expect(find.textContaining('Kết nối · Nhu cầu chủ đạo'), findsOneWidget);
    });

    testWidgets('patterns can render without a Self-Check result', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([_pattern('kn', 3)]);
      final content = FakeWrContentRepository()
        ..seedSituations([
          _situation(
            code: 'kn',
            text: 'Mâu thuẫn nhóm',
            need: HumanNeed.ketNoi,
          ),
        ]);
      await _pumpLarge(tester, _wrapDiscover(intel: intel, content: content));
      expect(find.textContaining('TÌNH HUỐNG LẶP LẠI'), findsOneWidget);
      expect(find.textContaining('TRẢI NGHIỆM HIỆN TẠI'), findsNothing);
    });
  });
}
