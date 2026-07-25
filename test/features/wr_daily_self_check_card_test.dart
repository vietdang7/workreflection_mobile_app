import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_daily_self_check_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_daily_self_check.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_daily_self_check_card.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_wr_intelligence_repository.dart';

class _FakeDailySelfCheckRepository implements WrDailySelfCheckRepository {
  _FakeDailySelfCheckRepository(this.draft);

  WrDailySelfCheckDraft draft;
  bool markedCompleted = false;

  @override
  Future<WrDailySelfCheckDraft> fetchDraft(String userId) async => draft;

  @override
  Future<WrDailySelfCheckDraft> saveAnswer({
    required String userId,
    required String questionId,
    required int value,
  }) async {
    draft = draft.copyWith(answers: {...draft.answers, questionId: value});
    return draft;
  }

  @override
  Future<void> markCompleted(String userId) async {
    markedCompleted = true;
    draft = draft.copyWith(completedAt: DateTime(2026, 7, 25));
  }
}

Widget _wrap({
  required _FakeDailySelfCheckRepository daily,
  required FakeWrIntelligenceRepository intel,
  ScaDimension dimension = ScaDimension.c2,
}) {
  final router = GoRouter(
    initialLocation: '/card',
    routes: [
      GoRoute(
        path: '/card',
        builder: (_, __) =>
            Scaffold(body: WrDailySelfCheckCard(dimension: dimension)),
      ),
      GoRoute(
        path: '/wr/discover',
        builder: (_, __) => const Scaffold(body: Text('Discover')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      wrDailySelfCheckRepositoryProvider.overrideWithValue(daily),
      wrIntelligenceRepositoryProvider.overrideWithValue(intel),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test('maps all ten SCA dimensions to the correct pillar', () {
    expect(pillarForDimension(ScaDimension.s1), SelfCheckPillar.s);
    expect(pillarForDimension(ScaDimension.s2), SelfCheckPillar.s);
    expect(pillarForDimension(ScaDimension.s3), SelfCheckPillar.s);
    expect(pillarForDimension(ScaDimension.c1), SelfCheckPillar.c);
    expect(pillarForDimension(ScaDimension.c2), SelfCheckPillar.c);
    expect(pillarForDimension(ScaDimension.c3), SelfCheckPillar.c);
    expect(pillarForDimension(ScaDimension.a1), SelfCheckPillar.a);
    expect(pillarForDimension(ScaDimension.a2), SelfCheckPillar.a);
    expect(pillarForDimension(ScaDimension.a3), SelfCheckPillar.a);
    expect(pillarForDimension(ScaDimension.a4), SelfCheckPillar.a);
  });

  test('selects an unanswered question from the contextual pillar first', () {
    final question = nextDailySelfCheckQuestion(
      answers: const {},
      preferredPillar: SelfCheckPillar.c,
    );
    expect(question?.id, 'scq-06');
  });

  testWidgets('answers one optional question and stops for the day', (
    tester,
  ) async {
    final daily = _FakeDailySelfCheckRepository(
      const WrDailySelfCheckDraft(userId: 'u1'),
    );
    final intel = FakeWrIntelligenceRepository();
    await tester.pumpWidget(_wrap(daily: daily, intel: intel));
    await tester.pumpAndSettle();

    expect(find.text('MỘT CÂU NHỎ, NẾU BẠN MUỐN'), findsOneWidget);
    expect(find.text('Để lúc khác'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '4'));
    await tester.pumpAndSettle();

    expect(daily.draft.answers['scq-06'], 4);
    expect(find.textContaining('1/15 mảnh ghép'), findsOneWidget);
    expect(intel.insertSelfCheckResponseCalls, isEmpty);
  });

  testWidgets(
    'the fifteenth small answer creates a standard Self-Check result',
    (tester) async {
      final firstFourteen = {
        for (final question in kSelfCheckQuestions.take(14)) question.id: 4,
      };
      final daily = _FakeDailySelfCheckRepository(
        WrDailySelfCheckDraft(userId: 'u1', answers: firstFourteen),
      );
      final intel = FakeWrIntelligenceRepository();
      await tester.pumpWidget(
        _wrap(daily: daily, intel: intel, dimension: ScaDimension.a4),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, '5'));
      await tester.pumpAndSettle();

      expect(daily.markedCompleted, isTrue);
      expect(intel.insertSelfCheckResponseCalls, hasLength(1));
      final response = intel.insertSelfCheckResponseCalls.single;
      expect(response.answers, hasLength(15));
      expect(response.structureScore, 4);
      expect(response.cultureScore, 4);
      expect(response.activityScore, 4.2);
      expect(find.text('BỨC TRANH ĐÃ SẴN SÀNG'), findsOneWidget);
    },
  );
}
