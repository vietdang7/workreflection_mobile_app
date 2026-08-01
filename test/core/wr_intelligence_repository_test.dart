// Tests for FakeWrIntelligenceRepository behavior (Task 5).
// Run: flutter test test/core/wr_intelligence_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

import '../support/fake_wr_intelligence_repository.dart';

void main() {
  late FakeWrIntelligenceRepository repo;

  setUp(() {
    repo = FakeWrIntelligenceRepository();
  });

  // ---------------------------------------------------------------------------
  // recordSituationOccurrence — upsert behavior
  // ---------------------------------------------------------------------------
  group('recordSituationOccurrence', () {
    test('creates new entry on first call', () async {
      await repo.recordSituationOccurrence(
        userId: 'user-1',
        situationCode: 'S1-sit-01',
        scaDimensionDb: 'S1',
      );
      final counts = await repo.fetchPatternCounts('user-1');
      expect(counts, hasLength(1));
      expect(counts.first.occurrenceCount, 1);
      expect(counts.first.situationCode, 'S1-sit-01');
    });

    test('increments count on subsequent calls for same situation', () async {
      await repo.recordSituationOccurrence(
        userId: 'user-1',
        situationCode: 'S1-sit-01',
        scaDimensionDb: 'S1',
      );
      await repo.recordSituationOccurrence(
        userId: 'user-1',
        situationCode: 'S1-sit-01',
        scaDimensionDb: 'S1',
      );
      await repo.recordSituationOccurrence(
        userId: 'user-1',
        situationCode: 'S1-sit-01',
        scaDimensionDb: 'S1',
      );
      final counts = await repo.fetchPatternCounts('user-1');
      expect(counts.first.occurrenceCount, 3);
    });

    test('separate situations have independent counts', () async {
      await repo.recordSituationOccurrence(
        userId: 'user-1',
        situationCode: 'S1-sit-01',
        scaDimensionDb: 'S1',
      );
      await repo.recordSituationOccurrence(
        userId: 'user-1',
        situationCode: 'S1-sit-02',
        scaDimensionDb: 'S1',
      );
      await repo.recordSituationOccurrence(
        userId: 'user-1',
        situationCode: 'S1-sit-01',
        scaDimensionDb: 'S1',
      );
      final counts = await repo.fetchPatternCounts('user-1');
      expect(counts, hasLength(2));
      final s1 = counts.firstWhere((c) => c.situationCode == 'S1-sit-01');
      final s2 = counts.firstWhere((c) => c.situationCode == 'S1-sit-02');
      expect(s1.occurrenceCount, 2);
      expect(s2.occurrenceCount, 1);
    });

    test('records call in recordSituationOccurrenceCalls', () async {
      await repo.recordSituationOccurrence(
        userId: 'user-1',
        situationCode: 'S1-sit-01',
        scaDimensionDb: 'S1',
      );
      expect(repo.recordSituationOccurrenceCalls, hasLength(1));
      expect(repo.recordSituationOccurrenceCalls.first.situationCode, 'S1-sit-01');
    });
  });

  // ---------------------------------------------------------------------------
  // fetchSelfCheckHistory — newest first
  // ---------------------------------------------------------------------------
  group('fetchSelfCheckHistory', () {
    test('returns newest response first', () async {
      final old = ScaSelfCheckResponse(
        id: '1',
        userId: 'user-1',
        answers: {},
        structureScore: null,
        cultureScore: null,
        activityScore: null,
        takenAt: DateTime(2026, 7, 1),
      );
      final newer = ScaSelfCheckResponse(
        id: '2',
        userId: 'user-1',
        answers: {},
        structureScore: null,
        cultureScore: null,
        activityScore: null,
        takenAt: DateTime(2026, 7, 22),
      );
      repo.seedSelfCheckHistory([old, newer]);
      final history = await repo.fetchSelfCheckHistory('user-1');
      expect(history.first.id, '2');
      expect(history.last.id, '1');
    });

    test('limit parameter caps results', () async {
      for (var i = 0; i < 5; i++) {
        await repo.insertSelfCheckResponse(
          ScaSelfCheckResponse(
            id: 'r$i',
            userId: 'user-1',
            answers: {},
            structureScore: null,
            cultureScore: null,
            activityScore: null,
            takenAt: DateTime(2026, 7, i + 1),
          ),
        );
      }
      final limited = await repo.fetchSelfCheckHistory('user-1', limit: 3);
      expect(limited.length, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // nextError — error simulation
  // ---------------------------------------------------------------------------
  group('nextError', () {
    test('throws error on next call then clears', () async {
      repo.nextError = Exception('network error');
      expect(
        () => repo.fetchPatternCounts('user-1'),
        throwsA(isA<Exception>()),
      );
      // After one throw, should work normally
      final counts = await repo.fetchPatternCounts('user-1');
      expect(counts, isEmpty);
    });
  });
}
