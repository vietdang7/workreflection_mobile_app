import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_story_flow_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

WrStory _story({
  String storyId = 'st1',
  ScaDimension dim = ScaDimension.c2,
  String content = 'Có một lần tôi...',
  String? aha = 'Điều tôi nhận ra là...',
  String? reflection = 'Điều này gợi lên điều gì?',
  String? practice = 'Hôm nay thử làm một việc nhỏ.',
  HumanNeed? need = HumanNeed.roRang,
}) => WrStory(
  storyId: storyId,
  title: 'Story $storyId',
  scaDimension: dim,
  storyContent: content,
  emotionTags: [],
  behaviorTags: [],
  careerStages: [],
  ahaMessage: aha,
  reflectionQuestion: reflection,
  practiceAction: practice,
  humanNeed: need,
);

Widget _wrap(
  Widget screen, {
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  FakeWrRepository? wr,
}) {
  final contentRepo = content ?? FakeWrContentRepository();
  final intelRepo = intel ?? FakeWrIntelligenceRepository();
  final wrRepo = wr ?? FakeWrRepository();
  final router = GoRouter(
    initialLocation: '/wr/story/flow',
    routes: [
      GoRoute(path: '/wr/story/flow', builder: (_, __) => screen),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      wrContentRepositoryProvider.overrideWithValue(contentRepo),
      wrIntelligenceRepositoryProvider.overrideWithValue(intelRepo),
      wrRepositoryProvider.overrideWithValue(wrRepo),
      currentUserIdProvider.overrideWithValue('u1'),
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
  group('WrStoryFlowScreen — story phase', () {
    testWidgets('renders storyContent', (tester) async {
      final content = FakeWrContentRepository();
      content.seedStories([_story(content: 'Có một lần tôi gặp khó khăn')]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      expect(
        find.textContaining('Có một lần tôi gặp khó khăn'),
        findsOneWidget,
      );
    });

    testWidgets('shows label "Bạn có bao giờ?" for story phase', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      content.seedStories([_story()]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      expect(find.textContaining('Bạn có bao giờ?'), findsOneWidget);
    });

    testWidgets('tapping "Tôi cũng từng như vậy" moves to aha phase', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      content.seedStories([_story(aha: 'Điều WorkReflection nhận ra')]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.text('Tôi cũng từng như vậy'));
      await tester.pumpAndSettle();
      // text appears in both phase label header and aha body
      expect(find.textContaining('Điều WorkReflection nhận ra'), findsWidgets);
    });
  });

  group('WrStoryFlowScreen — aha phase', () {
    testWidgets('shows aha phase label', (tester) async {
      final content = FakeWrContentRepository();
      content.seedStories([_story(aha: 'Aha message here')]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.text('Tôi cũng từng như vậy'));
      await tester.pumpAndSettle();
      // phase label appears in header
      expect(find.textContaining('Điều WorkReflection nhận ra'), findsWidgets);
    });

    testWidgets('Tiếp tục moves to confidence phase', (tester) async {
      final content = FakeWrContentRepository();
      content.seedStories([_story()]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.text('Tôi cũng từng như vậy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mức độ nhận ra'), findsOneWidget);
    });
  });

  group('WrStoryFlowScreen — confidence phase', () {
    Future<void> toConfidence(
      WidgetTester tester,
      FakeWrContentRepository content,
    ) async {
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.text('Tôi cũng từng như vậy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders 3 confidence options', (tester) async {
      final content = FakeWrContentRepository()..seedStories([_story()]);
      await toConfidence(tester, content);
      expect(find.text('Rất liên quan'), findsOneWidget);
      expect(find.text('Hơi liên quan'), findsOneWidget);
      expect(find.text('Không liên quan'), findsOneWidget);
    });

    testWidgets('selecting confidence moves to reflection phase', (
      tester,
    ) async {
      final content = FakeWrContentRepository()
        ..seedStories([_story(reflection: 'Gợi lên điều gì?')]);
      await toConfidence(tester, content);
      await tester.tap(find.text('Rất liên quan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ghi lại suy nghĩ'), findsOneWidget);
    });
  });

  group('WrStoryFlowScreen — memory phase', () {
    Future<void> toMemory(
      WidgetTester tester,
      FakeWrContentRepository content, {
      FakeWrIntelligenceRepository? intel,
    }) async {
      final w = _wrap(
        const WrStoryFlowScreen(),
        content: content,
        intel: intel,
      );
      await _pump(tester, w);
      await tester.tap(find.text('Tôi cũng từng như vậy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rất liên quan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle(); // reflection skip
      await tester.tap(find.text('Lần này bỏ qua'));
      await tester.pumpAndSettle(); // practice skip
    }

    testWidgets('shows 4 memory type buttons', (tester) async {
      final content = FakeWrContentRepository()..seedStories([_story()]);
      await toMemory(tester, content);
      expect(find.text('Nhận ra điều gì đó'), findsOneWidget);
      expect(find.text('Góc nhìn mới'), findsOneWidget);
      expect(find.text('Khám phá về mình'), findsOneWidget);
      expect(find.text('Quyết định đã rõ'), findsOneWidget);
    });

    testWidgets(
      'selecting memory type saves memory, insight and the complete 5-step reflection cycle',
      (tester) async {
        final content = FakeWrContentRepository()..seedStories([_story()]);
        final intel = FakeWrIntelligenceRepository();
        await toMemory(tester, content, intel: intel);
        await tester.tap(find.text('Nhận ra điều gì đó'));
        await tester.pumpAndSettle();
        // memory event
        expect(content.insertMemoryEventCalls.length, 1);
        // insight
        expect(intel.insertInsightCalls.length, 1);
        expect(intel.insertReflectionStepCalls.length, 5);
        expect(
          intel.insertReflectionStepCalls.map((step) => step.step),
          ReflectionStepType.values,
        );
      },
    );

    testWidgets('"Câu chuyện này không quen" goes to next story', (
      tester,
    ) async {
      final content = FakeWrContentRepository();
      content.seedStories([
        _story(storyId: 'st1', dim: ScaDimension.c2, content: 'Story 1'),
        _story(storyId: 'st2', dim: ScaDimension.a1, content: 'Story 2'),
      ]);
      await _pump(tester, _wrap(const WrStoryFlowScreen(), content: content));
      await tester.tap(find.textContaining('không quen'));
      await tester.pumpAndSettle();
      // storyContent is wrapped in quotes: '"Story 2"'
      expect(find.textContaining('Story 2'), findsOneWidget);
    });
  });
}
