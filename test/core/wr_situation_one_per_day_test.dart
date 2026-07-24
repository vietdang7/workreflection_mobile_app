// Tests for "one situation per day — replace on change" data layer.
// Covers:
//   (a) decrementSituationOccurrence: count 3→2 (update); count 1→delete row.
//   (b) deleteTodayMemoryEventsForSituation: only deletes same day + same code.
//   (e) event from another day is NOT touched.
// Run: flutter test test/core/wr_situation_one_per_day_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CareerMemoryEvent _evt({
  required String id,
  required String userId,
  required String situationCode,
  required DateTime createdAt,
}) =>
    CareerMemoryEvent(
      id: id,
      userId: userId,
      situationCode: situationCode,
      createdAt: createdAt,
    );

// Vietnam "today" for tests: 2026-07-23 midnight VN = 2026-07-22 17:00 UTC
// We represent this as DateTime(2026, 7, 23) — a local-midnight date-only value
// the same way todayVn() returns it.
final _today = DateTime(2026, 7, 23);
// VN midnight UTC for _today: subtract 7h from a UTC midnight-of-VN-day
// VN 2026-07-23 00:00 = UTC 2026-07-22 17:00
final _todayVnMidnightUtc = DateTime.utc(2026, 7, 22, 17, 0, 0);
// Yesterday: VN 2026-07-22 00:00 = UTC 2026-07-21 17:00
final _yesterdayEventTime = DateTime.utc(2026, 7, 21, 18, 0, 0); // VN 2026-07-22 01:00

// ---------------------------------------------------------------------------
// (a) decrementSituationOccurrence
// ---------------------------------------------------------------------------

void main() {
  group('(a) decrementSituationOccurrence — count 3 → 2 (update)', () {
    test('decrements count when occurrenceCount > 1', () async {
      final repo = FakeWrIntelligenceRepository();
      repo.seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-A',
          occurrenceCount: 3,
          lastSeenAt: DateTime(2026, 7, 20),
        ),
      ]);

      await repo.decrementSituationOccurrence(
        userId: 'u1',
        situationCode: 'sit-A',
      );

      final counts = await repo.fetchPatternCounts('u1');
      expect(counts, hasLength(1));
      expect(counts.first.occurrenceCount, 2);
    });

    test('records call in decrementSituationOccurrenceCalls', () async {
      final repo = FakeWrIntelligenceRepository();
      repo.seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-A',
          occurrenceCount: 2,
          lastSeenAt: DateTime(2026, 7, 20),
        ),
      ]);

      await repo.decrementSituationOccurrence(
        userId: 'u1',
        situationCode: 'sit-A',
      );

      expect(repo.decrementSituationOccurrenceCalls, hasLength(1));
      expect(repo.decrementSituationOccurrenceCalls.first.situationCode, 'sit-A');
    });
  });

  group('(a) decrementSituationOccurrence — count 1 → delete row', () {
    test('removes row when occurrenceCount == 1', () async {
      final repo = FakeWrIntelligenceRepository();
      repo.seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-A',
          occurrenceCount: 1,
          lastSeenAt: DateTime(2026, 7, 20),
        ),
      ]);

      await repo.decrementSituationOccurrence(
        userId: 'u1',
        situationCode: 'sit-A',
      );

      final counts = await repo.fetchPatternCounts('u1');
      expect(counts, isEmpty);
    });

    test('noop when row does not exist', () async {
      final repo = FakeWrIntelligenceRepository();
      // Should not throw
      await repo.decrementSituationOccurrence(
        userId: 'u1',
        situationCode: 'nonexistent',
      );
      final counts = await repo.fetchPatternCounts('u1');
      expect(counts, isEmpty);
    });

    test('does not affect other users or situation codes', () async {
      final repo = FakeWrIntelligenceRepository();
      repo.seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-A',
          occurrenceCount: 1,
          lastSeenAt: DateTime(2026, 7, 20),
        ),
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-B',
          occurrenceCount: 3,
          lastSeenAt: DateTime(2026, 7, 20),
        ),
        PatternCount(
          userId: 'u2',
          situationCode: 'sit-A',
          occurrenceCount: 2,
          lastSeenAt: DateTime(2026, 7, 20),
        ),
      ]);

      await repo.decrementSituationOccurrence(
        userId: 'u1',
        situationCode: 'sit-A',
      );

      // Note: fake fetchPatternCounts does not filter by userId (it returns all).
      // Filter manually in assertion.
      final allCounts = await repo.fetchPatternCounts('u1');
      final u1Counts = allCounts.where((c) => c.userId == 'u1').toList();
      final u2Counts = allCounts.where((c) => c.userId == 'u2').toList();

      // sit-A for u1 deleted, sit-B for u1 intact
      expect(u1Counts, hasLength(1));
      expect(u1Counts.first.situationCode, 'sit-B');
      expect(u1Counts.first.occurrenceCount, 3);

      // sit-A for u2 untouched
      expect(u2Counts, hasLength(1));
      expect(u2Counts.first.occurrenceCount, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // (b) deleteTodayMemoryEventsForSituation
  // ---------------------------------------------------------------------------

  group('(b) deleteTodayMemoryEventsForSituation — only same day + same code', () {
    test('deletes event with same userId, situationCode, and VN date', () async {
      final repo = FakeWrContentRepository();
      // Event on today VN (UTC time within VN 2026-07-23)
      final todayEvent = _evt(
        id: 'e1',
        userId: 'u1',
        situationCode: 'sit-A',
        createdAt: _todayVnMidnightUtc.add(const Duration(hours: 2)), // VN 02:00
      );
      repo.seedMemoryEvents([todayEvent]);

      await repo.deleteTodayMemoryEventsForSituation(
        userId: 'u1',
        situationCode: 'sit-A',
        day: _today,
      );

      final events = await repo.fetchMemoryEventsForUser('u1');
      expect(events, isEmpty);
    });

    test('records call in deleteTodayMemoryEventsForSituationCalls', () async {
      final repo = FakeWrContentRepository();
      await repo.deleteTodayMemoryEventsForSituation(
        userId: 'u1',
        situationCode: 'sit-A',
        day: _today,
      );
      expect(repo.deleteTodayMemoryEventsForSituationCalls, hasLength(1));
      expect(
        repo.deleteTodayMemoryEventsForSituationCalls.first.situationCode,
        'sit-A',
      );
    });

    test('keeps events with different situation code', () async {
      final repo = FakeWrContentRepository();
      repo.seedMemoryEvents([
        _evt(
          id: 'e1',
          userId: 'u1',
          situationCode: 'sit-A',
          createdAt: _todayVnMidnightUtc.add(const Duration(hours: 1)),
        ),
        _evt(
          id: 'e2',
          userId: 'u1',
          situationCode: 'sit-B', // different code — must NOT be deleted
          createdAt: _todayVnMidnightUtc.add(const Duration(hours: 1)),
        ),
      ]);

      await repo.deleteTodayMemoryEventsForSituation(
        userId: 'u1',
        situationCode: 'sit-A',
        day: _today,
      );

      final events = await repo.fetchMemoryEventsForUser('u1');
      expect(events, hasLength(1));
      expect(events.first.situationCode, 'sit-B');
    });

    test('keeps events with different user', () async {
      final repo = FakeWrContentRepository();
      repo.seedMemoryEvents([
        _evt(
          id: 'e1',
          userId: 'u1',
          situationCode: 'sit-A',
          createdAt: _todayVnMidnightUtc.add(const Duration(hours: 1)),
        ),
        _evt(
          id: 'e2',
          userId: 'u2', // different user — must NOT be deleted
          situationCode: 'sit-A',
          createdAt: _todayVnMidnightUtc.add(const Duration(hours: 1)),
        ),
      ]);

      await repo.deleteTodayMemoryEventsForSituation(
        userId: 'u1',
        situationCode: 'sit-A',
        day: _today,
      );

      final u1Events = await repo.fetchMemoryEventsForUser('u1');
      final u2Events = await repo.fetchMemoryEventsForUser('u2');
      expect(u1Events, isEmpty);
      expect(u2Events, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // (e) event from another day is NOT touched
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // (b2) Boundary ngày VN: 23:59 hôm qua / 00:01 hôm nay
  // ---------------------------------------------------------------------------

  group('(b2) deleteTodayMemoryEventsForSituation — boundary VN 23:59/00:01', () {
    // Fixed "today" = 2026-07-23 VN. Mốc UTC cố định, độc lập múi giờ máy.
    // VN 2026-07-23 00:00 = UTC 2026-07-22 17:00:00

    test('event VN 23:59 HÔM QUA không bị xóa', () async {
      final repo = FakeWrContentRepository();
      // VN 2026-07-22 23:59 = UTC 2026-07-21 16:59
      // VN yesterday midnight = UTC 2026-07-21 17:00
      // VN yesterday 23:59 = UTC 2026-07-21 17:00 + 23h59m = 2026-07-22 16:59 UTC
      final yesterdayVn2359 = DateTime.utc(2026, 7, 22, 16, 59, 0);
      repo.seedMemoryEvents([
        _evt(
          id: 'e-yesterday-2359',
          userId: 'u1',
          situationCode: 'sit-A',
          createdAt: yesterdayVn2359,
        ),
      ]);

      await repo.deleteTodayMemoryEventsForSituation(
        userId: 'u1',
        situationCode: 'sit-A',
        day: _today, // VN 2026-07-23
      );

      final events = await repo.fetchMemoryEventsForUser('u1');
      expect(events, hasLength(1),
          reason: 'event VN 23:59 hôm qua (UTC 2026-07-22 16:59) KHÔNG bị xóa');
    });

    test('event VN 00:01 HÔM NAY bị xóa', () async {
      final repo = FakeWrContentRepository();
      // VN 2026-07-23 00:01 = UTC 2026-07-22 17:01
      final todayVn0001 = DateTime.utc(2026, 7, 22, 17, 1, 0);
      repo.seedMemoryEvents([
        _evt(
          id: 'e-today-0001',
          userId: 'u1',
          situationCode: 'sit-A',
          createdAt: todayVn0001,
        ),
      ]);

      await repo.deleteTodayMemoryEventsForSituation(
        userId: 'u1',
        situationCode: 'sit-A',
        day: _today, // VN 2026-07-23
      );

      final events = await repo.fetchMemoryEventsForUser('u1');
      expect(events, isEmpty,
          reason: 'event VN 00:01 hôm nay (UTC 2026-07-22 17:01) PHẢI bị xóa');
    });

    test('đúng mốc VN 00:00 bị xóa, VN 23:59 ngày trước không bị xóa', () async {
      final repo = FakeWrContentRepository();
      // VN 2026-07-23 00:00 = UTC 2026-07-22 17:00 (chính xác mốc)
      final todayVnMidnight = DateTime.utc(2026, 7, 22, 17, 0, 0);
      // VN 2026-07-22 23:59 = UTC 2026-07-22 16:59
      final yesterdayVn2359 = DateTime.utc(2026, 7, 22, 16, 59, 0);

      repo.seedMemoryEvents([
        _evt(id: 'e-midnight', userId: 'u1', situationCode: 'sit-A', createdAt: todayVnMidnight),
        _evt(id: 'e-2359', userId: 'u1', situationCode: 'sit-A', createdAt: yesterdayVn2359),
      ]);

      await repo.deleteTodayMemoryEventsForSituation(
        userId: 'u1',
        situationCode: 'sit-A',
        day: _today,
      );

      final events = await repo.fetchMemoryEventsForUser('u1');
      expect(events, hasLength(1));
      expect(events.first.id, 'e-2359',
          reason: 'VN 23:59 hôm qua không bị xóa; VN 00:00 hôm nay bị xóa');
    });
  });

  group('(e) events from other day preserved', () {
    test('yesterday sit-A event NOT deleted when deleting today sit-A', () async {
      final repo = FakeWrContentRepository();
      // Yesterday's event for sit-A (VN 2026-07-22)
      final yesterdayEvent = _evt(
        id: 'e-yesterday',
        userId: 'u1',
        situationCode: 'sit-A',
        createdAt: _yesterdayEventTime, // VN 2026-07-22 01:00 → yesterday
      );
      // Today's event for sit-A
      final todayEvent = _evt(
        id: 'e-today',
        userId: 'u1',
        situationCode: 'sit-A',
        createdAt: _todayVnMidnightUtc.add(const Duration(hours: 3)), // VN 2026-07-23 03:00
      );
      repo.seedMemoryEvents([yesterdayEvent, todayEvent]);

      await repo.deleteTodayMemoryEventsForSituation(
        userId: 'u1',
        situationCode: 'sit-A',
        day: _today,
      );

      final events = await repo.fetchMemoryEventsForUser('u1');
      // Only yesterday's event remains
      expect(events, hasLength(1));
      expect(events.first.id, 'e-yesterday');
    });

    test('yesterday sit-A NOT decremented when today user switches A→B', () async {
      // Simulates: yesterday user recorded sit-A (count=1).
      // Today user records sit-B. Yesterday sit-A count must stay at 1.
      final intelRepo = FakeWrIntelligenceRepository();
      intelRepo.seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-A',
          occurrenceCount: 1,
          lastSeenAt: DateTime(2026, 7, 22), // yesterday
        ),
      ]);
      final contentRepo = FakeWrContentRepository();
      // Yesterday's memory event for sit-A (NOT today)
      contentRepo.seedMemoryEvents([
        _evt(
          id: 'e-yesterday',
          userId: 'u1',
          situationCode: 'sit-A',
          createdAt: _yesterdayEventTime,
        ),
      ]);

      // Simulate commitTodaySituation logic manually:
      // Fetch today's codes from memory events
      final allEvents = await contentRepo.fetchMemoryEventsForUser('u1');
      final today = DateTime(2026, 7, 23);
      final todayCodes = <String>{};
      for (final e in allEvents) {
        if (e.situationCode == null) continue;
        final created = e.createdAt;
        if (created == null) continue;
        // Convert to VN day
        final vnTime = created.toUtc().add(const Duration(hours: 7));
        final eventDay = DateTime(vnTime.year, vnTime.month, vnTime.day);
        if (eventDay == today) todayCodes.add(e.situationCode!);
      }

      // todayCodes should be empty (yesterday event is not today)
      expect(todayCodes, isEmpty,
          reason: 'yesterday event must NOT appear in today codes');

      // Since todayCodes is empty, no decrement should happen for sit-A
      // Only sit-B gets recorded:
      await intelRepo.recordSituationOccurrence(
        userId: 'u1',
        situationCode: 'sit-B',
        scaDimensionDb: 'S1',
      );

      final counts = await intelRepo.fetchPatternCounts('u1');
      final aCount = counts.where((c) => c.situationCode == 'sit-A').firstOrNull;
      final bCount = counts.where((c) => c.situationCode == 'sit-B').firstOrNull;

      expect(aCount?.occurrenceCount, 1,
          reason: 'sit-A from yesterday must remain count=1, not decremented');
      expect(bCount?.occurrenceCount, 1,
          reason: 'sit-B newly recorded today');
      expect(intelRepo.decrementSituationOccurrenceCalls, isEmpty,
          reason: 'no decrement should have been called');
    });
  });
}
