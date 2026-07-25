import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_intelligence_fallback.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

void main() {
  test('pattern fallback describes a recurring recent situation', () {
    final now = DateTime(2026, 7, 25);
    final events = [
      CareerMemoryEvent(
        id: 'e1',
        userId: 'u1',
        situationCode: 'sit-01',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      CareerMemoryEvent(
        id: 'e2',
        userId: 'u1',
        situationCode: 'sit-01',
        createdAt: now.subtract(const Duration(days: 8)),
      ),
      CareerMemoryEvent(
        id: 'e3',
        userId: 'u1',
        situationCode: 'sit-01',
        createdAt: now.subtract(const Duration(days: 40)),
      ),
    ];
    final narratives = buildPatternNarrativeFallback(
      userId: 'u1',
      events: events,
      situations: const [
        WrSituation(
          code: 'sit-01',
          text: 'Ngại nêu ý kiến',
          scaDimension: ScaDimension.c2,
          wave: 2,
        ),
      ],
      now: now,
    );

    expect(narratives, hasLength(1));
    expect(narratives.single.narrative, contains('Ngại nêu ý kiến'));
    expect(narratives.single.narrative, contains('2 lần'));
    expect(narratives.single.narrative, contains('nhiều hơn'));
  });

  test('pattern fallback waits until a pattern actually repeats', () {
    final now = DateTime(2026, 7, 25);
    final narratives = buildPatternNarrativeFallback(
      userId: 'u1',
      events: [
        CareerMemoryEvent(
          id: 'e1',
          userId: 'u1',
          situationCode: 'one',
          createdAt: now,
        ),
        CareerMemoryEvent(
          id: 'e2',
          userId: 'u1',
          situationCode: 'two',
          createdAt: now,
        ),
      ],
      situations: const [],
      now: now,
    );
    expect(narratives, isEmpty);
  });

  test('growth fallback turns practice progress into a next direction', () {
    final snapshots = buildGrowthSnapshotFallback(
      userId: 'u1',
      enrollments: const [
        PracticeEnrollment(
          userId: 'u1',
          themeId: 'voice',
          completedSteps: ['voice-1'],
        ),
      ],
      themes: const [PracticeTheme(themeId: 'voice', title: 'Dám lên tiếng')],
      stepsByTheme: const {
        'voice': [
          PracticeStep(
            stepId: 'voice-1',
            themeId: 'voice',
            stepOrder: 1,
            title: 'Nhận diện',
            isPremium: false,
          ),
          PracticeStep(
            stepId: 'voice-2',
            themeId: 'voice',
            stepOrder: 2,
            title: 'Thử nghiệm',
            isPremium: false,
          ),
        ],
      },
      now: DateTime(2026, 7, 25),
    );

    expect(snapshots, hasLength(1));
    expect(snapshots.single.periodLabel, 'Tháng 7/2026');
    expect(snapshots.single.direction, contains('Dám lên tiếng'));
    expect(snapshots.single.progress['Bước hoàn thành'], '1/2');
  });
}
