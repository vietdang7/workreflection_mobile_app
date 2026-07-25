import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_situation_flow_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

WrSituation _sit({
  String code = 'S1.1',
  String text = 'Tôi không biết nên làm gì tiếp theo',
  int wave = 1,
  ScaDimension dim = ScaDimension.s1,
  String? expectedOutcome = 'Bạn muốn có sự rõ ràng về hướng đi',
  String? scaPerspective = 'Đây là giai đoạn định hướng quan trọng',
  HumanNeed? need = HumanNeed.roRang,
}) => WrSituation(
  code: code, text: text, scaDimension: dim, wave: wave,
  expectedOutcome: expectedOutcome, scaPerspective: scaPerspective,
  humanNeed: need,
);

Widget _wrap(Widget screen, {
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String? userId,
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final router = GoRouter(
    initialLocation: '/wr/situation',
    routes: [
      GoRoute(path: '/wr/situation', builder: (_, __) => screen),
      GoRoute(path: '/wr/story', builder: (_, __) => const Scaffold(body: Text('StoryTab'))),
    ],
  );
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      wrRepositoryProvider.overrideWithValue(FakeWrRepository()),
      currentUserIdProvider.overrideWithValue(userId ?? 'u1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  group('WrSituationFlowScreen — step 1: list', () {
    testWidgets('renders list of situations from fake repo', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([
        _sit(code: 'S1.1', text: 'Tôi không biết nên làm gì'),
        _sit(code: 'S1.2', text: 'Tôi cảm thấy lạc lõng'),
      ]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content));
      expect(find.text('Tôi không biết nên làm gì'), findsOneWidget);
      expect(find.text('Tôi cảm thấy lạc lõng'), findsOneWidget);
    });

    testWidgets('tapping situation moves to step 2 and shows expectedOutcome', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit(expectedOutcome: 'Bạn muốn rõ ràng về hướng đi')]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn muốn rõ ràng về hướng đi'), findsOneWidget);
    });

    testWidgets('step 2 does NOT show raw SCA code', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit()]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      // SCA codes should not appear
      expect(find.textContaining('S1'), findsNothing);
      expect(find.textContaining('A1'), findsNothing);
      expect(find.textContaining('C2'), findsNothing);
    });

    testWidgets('step 2 shows scaPerspective', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit(scaPerspective: 'Đây là giai đoạn định hướng')]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đây là giai đoạn định hướng'), findsOneWidget);
    });
  });

  group('WrSituationFlowScreen — step 3: save', () {
    testWidgets('save button calls recordSituationOccurrence', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();
      content.seedSituations([_sit(code: 'S1.1', dim: ScaDimension.s1)]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content, intel: intel));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu vào hành trình'));
      await tester.pumpAndSettle();
      expect(intel.recordSituationOccurrenceCalls.length, 1);
      expect(intel.recordSituationOccurrenceCalls.first.situationCode, 'S1.1');
    });

    testWidgets('save creates career memory event', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();
      content.seedSituations([_sit(code: 'S1.1')]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content, intel: intel));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu vào hành trình'));
      await tester.pumpAndSettle();
      expect(content.insertMemoryEventCalls.length, 1);
      expect(content.insertMemoryEventCalls.first.situationCode, 'S1.1');
      expect(content.insertMemoryEventCalls.first.emotion, 'low');
    });

    testWidgets('shows Đã ghi nhận after save', (tester) async {
      final content = FakeWrContentRepository();
      content.seedSituations([_sit()]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu vào hành trình'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã ghi nhận'), findsOneWidget);
    });

    testWidgets('pattern >= 3 shows "lần thứ N" message', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();
      // Pre-seed 2 existing occurrences (after save = 3)
      intel.seedPatternCounts([
        PatternCount(
          userId: 'u1', situationCode: 'S1.1', scaDimension: ScaDimension.s1,
          occurrenceCount: 2, lastSeenAt: DateTime.now(),
        ),
      ]);
      content.seedSituations([_sit(code: 'S1.1')]);
      await _pump(tester, _wrap(const WrSituationFlowScreen(), content: content, intel: intel));
      await tester.tap(find.text('Tôi không biết nên làm gì tiếp theo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu vào hành trình'));
      await tester.pumpAndSettle();
      expect(find.textContaining('lần thứ'), findsOneWidget);
    });
  });
}
