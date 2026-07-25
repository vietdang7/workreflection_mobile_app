import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

GoRouter _makeRouter({required Widget home}) => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/home', builder: (_, __) => home),
    GoRoute(
      path: '/profile',
      builder: (_, __) => const Scaffold(body: Text('ProfileScreen')),
    ),
    GoRoute(
      path: '/wr/situation',
      builder: (_, __) => const Scaffold(body: Text('SituationScreen')),
    ),
    GoRoute(
      path: '/wr/discover',
      builder: (_, __) => const Scaffold(body: Text('DiscoverScreen')),
    ),
    GoRoute(
      path: '/wr/story',
      builder: (_, __) => const Scaffold(body: Text('StoryScreen')),
    ),
    GoRoute(
      path: '/wr/story/flow',
      builder: (_, __) => const Scaffold(body: Text('StoryFlowScreen')),
    ),
  ],
);

Widget _wrap(
  Widget home, {
  FakeWrRepository? wr,
  FakeWrContentRepository? content,
  FakeWrIntelligenceRepository? intel,
  String? userId,
  bool nullUserId = false,
}) {
  final router = _makeRouter(home: home);
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(wr ?? FakeWrRepository()),
      wrContentRepositoryProvider.overrideWithValue(
        content ?? FakeWrContentRepository(),
      ),
      wrIntelligenceRepositoryProvider.overrideWithValue(
        intel ?? FakeWrIntelligenceRepository(),
      ),
      currentUserIdProvider.overrideWithValue(
        nullUserId ? null : (userId ?? 'u1'),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Future<void> _completeCheckin(
  WidgetTester tester, {
  String energy = 'Mệt mỏi',
  String direction = 'Đứng yên',
}) async {
  await tester.tap(find.text(energy));
  await tester.pumpAndSettle();
  await tester.tap(find.text(direction));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('wr_save_checkin_button')));
  await tester.pumpAndSettle();
}

MobileProfile _profile({String name = 'Minh'}) => MobileProfile(
  userId: 'u1',
  displayName: name,
  reminderEnabled: true,
  language: 'vi',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026, 7, 22),
);

WrSituation _situation({
  String code = 'sit-01',
  String text = 'Áp lực deadline',
  ScaDimension dimension = ScaDimension.c2,
  HumanNeed need = HumanNeed.thichNghi,
  String? expectedOutcome,
  String? perspective,
}) {
  return WrSituation(
    code: code,
    text: text,
    scaDimension: dimension,
    wave: 2,
    humanNeed: need,
    expectedOutcome: expectedOutcome,
    scaPerspective: perspective,
  );
}

void main() {
  group('WrHomeScreen — header', () {
    testWidgets('shows profile name and avatar entry point', (tester) async {
      final wr = FakeWrRepository()..seedProfile(_profile(name: 'Linh'));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      expect(find.textContaining('Linh'), findsWidgets);
      expect(find.byKey(const Key('wr_home_profile_button')), findsOneWidget);
    });

    testWidgets('avatar opens standalone profile', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await tester.tap(find.byKey(const Key('wr_home_profile_button')));
      await tester.pumpAndSettle();
      expect(find.text('ProfileScreen'), findsOneWidget);
    });
  });

  group('WrHomeScreen — six-choice check-in', () {
    testWidgets('shows 3 energy choices before 3 direction choices', (
      tester,
    ) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));

      expect(find.text('Có năng lượng'), findsOneWidget);
      expect(find.text('Bình thường'), findsOneWidget);
      expect(find.text('Mệt mỏi'), findsOneWidget);
      expect(find.text('Tiến lên'), findsNothing);

      await tester.tap(find.text('Bình thường'));
      await tester.pumpAndSettle();
      expect(find.text('Tiến lên'), findsOneWidget);
      expect(find.text('Đứng yên'), findsOneWidget);
      expect(find.text('Thụt lùi'), findsOneWidget);
    });

    testWidgets('does not write before explicit save', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      await tester.tap(find.text('Mệt mỏi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thụt lùi'));
      await tester.pumpAndSettle();
      expect(wr.upsertCheckinCalls, isEmpty);
    });

    testWidgets('saves energy and direction together', (tester) async {
      final wr = FakeWrRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      await _completeCheckin(
        tester,
        energy: 'Có năng lượng',
        direction: 'Tiến lên',
      );

      expect(wr.upsertCheckinCalls, hasLength(1));
      final call = wr.upsertCheckinCalls.single;
      expect(call.mood, Mood.happy);
      expect(call.energy, CheckinEnergy.good);
      expect(call.direction, CheckinDirection.forward);
    });

    testWidgets('prepopulates saved energy and direction', (tester) async {
      final wr = FakeWrRepository();
      final now = DateTime.now();
      wr.seedTodayCheckin(
        Checkin(
          id: 'c1',
          userId: 'u1',
          mood: Mood.okay,
          energy: CheckinEnergy.ok,
          direction: CheckinDirection.steady,
          checkinDate: DateTime(now.year, now.month, now.day),
          createdAt: now,
        ),
      );
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      expect(
        find.text('Có điều gì bạn muốn nhìn lại hôm nay không?'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Đã lưu check-in'),
        findsOneWidget,
      );
    });

    testWidgets('shows friendly error and allows retry', (tester) async {
      final wr = FakeWrRepository()..setUpsertError(Exception('network error'));
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), wr: wr));

      await _completeCheckin(tester);
      expect(find.textContaining('Không lưu được check-in'), findsWidgets);
      expect(find.text('Điều gì đang làm bạn mất năng lượng?'), findsNothing);

      wr.clearUpsertError();
      await tester.tap(find.byKey(const Key('wr_save_checkin_button')));
      await tester.pumpAndSettle();
      expect(wr.upsertCheckinCalls, hasLength(1));
    });
  });

  group('WrHomeScreen — contextual follow-up', () {
    testWidgets('uses a different follow-up for each energy level', (
      tester,
    ) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await _completeCheckin(tester);
      expect(find.text('Điều gì đang làm bạn mất năng lượng?'), findsOneWidget);

      await _completeCheckin(tester, energy: 'Bình thường');
      expect(
        find.text('Có điều gì bạn muốn nhìn lại hôm nay không?'),
        findsOneWidget,
      );

      await _completeCheckin(tester, energy: 'Có năng lượng');
      expect(
        find.text('Bạn muốn phát triển điều gì tiếp theo?'),
        findsOneWidget,
      );
    });

    testWidgets('situation is recorded and confirmation is shown', (
      tester,
    ) async {
      final content = FakeWrContentRepository()
        ..seedSituations([
          _situation(
            expectedOutcome: 'Được hiểu và hỗ trợ kịp thời',
            perspective: 'Bạn đang cần rõ ràng về kỳ vọng.',
          ),
        ]);
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(
        tester,
        _wrap(const WrHomeScreen(), content: content, intel: intel),
      );

      await _completeCheckin(tester);
      await tester.tap(find.text('Áp lực deadline'));
      await tester.pumpAndSettle();

      expect(intel.recordSituationOccurrenceCalls, hasLength(1));
      expect(
        intel.recordSituationOccurrenceCalls.single.situationCode,
        'sit-01',
      );
      expect(find.textContaining('Được hiểu và hỗ trợ'), findsOneWidget);
      expect(find.textContaining('rõ ràng về kỳ vọng'), findsOneWidget);
      expect(
        find.textContaining('Hệ thống sẽ ghi nhớ điều này'),
        findsOneWidget,
      );
    });

    testWidgets('recurring situation reports the updated count', (
      tester,
    ) async {
      final content = FakeWrContentRepository()..seedSituations([_situation()]);
      final intel = FakeWrIntelligenceRepository()
        ..seedPatternCounts([
          PatternCount(
            userId: 'u1',
            situationCode: 'sit-01',
            occurrenceCount: 1,
            lastSeenAt: DateTime(2026, 7, 20),
          ),
        ]);
      await _pumpLarge(
        tester,
        _wrap(const WrHomeScreen(), content: content, intel: intel),
      );

      await _completeCheckin(tester);
      await tester.tap(find.text('Áp lực deadline'));
      await tester.pumpAndSettle();

      expect(find.textContaining('lần thứ 2'), findsWidgets);
    });

    testWidgets('Khác opens the full situation library', (tester) async {
      await _pumpLarge(tester, _wrap(const WrHomeScreen()));
      await _completeCheckin(tester);
      await tester.tap(find.text('Khác →'));
      await tester.pumpAndSettle();
      expect(find.text('SituationScreen'), findsOneWidget);
    });

    testWidgets('okay energy can stop without recording a situation', (
      tester,
    ) async {
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel));
      await _completeCheckin(tester, energy: 'Bình thường');
      await tester.tap(find.text('Không, hôm nay ổn'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hẹn gặp bạn ngày mai'), findsOneWidget);
      expect(intel.recordSituationOccurrenceCalls, isEmpty);
    });

    testWidgets('good energy can record joy once', (tester) async {
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), intel: intel));
      await _completeCheckin(tester, energy: 'Có năng lượng');
      await tester.tap(find.text('Chỉ muốn ghi lại niềm vui'));
      await tester.pumpAndSettle();

      expect(
        intel.insertReflectionStepCalls.where(
          (step) => step.content == 'Ghi lại niềm vui',
        ),
        hasLength(1),
      );
    });

    testWidgets('does not write situation data without a user id', (
      tester,
    ) async {
      final content = FakeWrContentRepository()..seedSituations([_situation()]);
      final intel = FakeWrIntelligenceRepository();
      await _pumpLarge(
        tester,
        _wrap(
          const WrHomeScreen(),
          content: content,
          intel: intel,
          nullUserId: true,
        ),
      );

      await _completeCheckin(tester);
      await tester.tap(find.text('Áp lực deadline'));
      await tester.pumpAndSettle();
      expect(intel.recordSituationOccurrenceCalls, isEmpty);
    });
  });

  group('WrHomeScreen — story suggestion', () {
    testWidgets('suggests a story from the recorded situation dimension', (
      tester,
    ) async {
      final content = FakeWrContentRepository()
        ..seedSituations([_situation()])
        ..seedStories([
          const WrStory(
            storyId: 'st-c2',
            title: 'Câu chuyện đúng C2',
            scaDimension: ScaDimension.c2,
            storyContent: 'Nội dung C2',
            emotionTags: [],
            behaviorTags: [],
            careerStages: [],
          ),
          const WrStory(
            storyId: 'st-c1',
            title: 'Câu chuyện C1',
            scaDimension: ScaDimension.c1,
            storyContent: 'Nội dung C1',
            emotionTags: [],
            behaviorTags: [],
            careerStages: [],
          ),
        ]);
      await _pumpLarge(tester, _wrap(const WrHomeScreen(), content: content));

      await _completeCheckin(tester);
      await tester.tap(find.text('Áp lực deadline'));
      await tester.pumpAndSettle();

      expect(find.text('GỢI Ý CHO BẠN'), findsOneWidget);
      expect(find.text('Câu chuyện đúng C2'), findsOneWidget);
      expect(find.text('Câu chuyện C1'), findsNothing);
      expect(find.text('Đọc câu chuyện này'), findsOneWidget);
    });
  });
}
