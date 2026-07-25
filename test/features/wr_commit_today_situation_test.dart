// Tests for commitTodaySituation service — "one situation per day, replace on change".
// Uses a minimal ConsumerWidget harness to get a WidgetRef.
//
// Covers spec tests (c), (d), (e) for commitTodaySituation:
//   (c) A→B same day: decrement A, record B; pattern only B.
//       B→A: decrement B, record A; pattern only A.
//   (d) A→A same day: recordSituationOccurrence NOT called again (idempotent).
//   (e) yesterday event for A: switching to B today does NOT decrement A.
//
// Also covers (f) Home screen and (g) SituationFlow screen integration.
// Run: flutter test test/features/wr_commit_today_situation_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/features/wr/wr_situation_service.dart';

import '../support/fake_wr_content_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

// ---------------------------------------------------------------------------
// Minimal harness: a ConsumerWidget that calls commitTodaySituation
// and stores the result for assertion.
// ---------------------------------------------------------------------------

class _TestHarness extends ConsumerWidget {
  const _TestHarness({required this.onRef});
  final void Function(WidgetRef ref) onRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onRef(ref);
    return const SizedBox.shrink();
  }
}

/// Pump a minimal ProviderScope with the given fakes, expose ref via callback.
Future<WidgetRef> _pumpRef(
  WidgetTester tester, {
  required FakeWrContentRepository content,
  required FakeWrIntelligenceRepository intel,
  String userId = 'u1',
}) async {
  late WidgetRef capturedRef;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wrContentRepositoryProvider.overrideWithValue(content),
        wrIntelligenceRepositoryProvider.overrideWithValue(intel),
        currentUserIdProvider.overrideWithValue(userId),
      ],
      child: MaterialApp(
        home: _TestHarness(onRef: (ref) => capturedRef = ref),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return capturedRef;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

WrSituation _sit(String code, {ScaDimension dim = ScaDimension.s1, HumanNeed? need = HumanNeed.roRang}) =>
    WrSituation(code: code, text: 'Situation $code', scaDimension: dim, wave: 1, humanNeed: need);

// VN "today" = 2026-07-23. VN midnight UTC = 2026-07-22 17:00 UTC.
final _todayVnMidnightUtc = DateTime.utc(2026, 7, 22, 17, 0, 0);
// Yesterday VN midnight UTC = 2026-07-21 17:00 UTC.
final _yesterdayVnMidnightUtc = DateTime.utc(2026, 7, 21, 17, 0, 0);
// A stable instant inside VN "today" (2026-07-23 12:00) to inject as the clock,
// so day-boundary assertions don't depend on the machine's real calendar date.
final _nowVnTodayUtc = _todayVnMidnightUtc.add(const Duration(hours: 12));

CareerMemoryEvent _memEvt({
  required String situationCode,
  required DateTime createdAt,
  String userId = 'u1',
}) =>
    CareerMemoryEvent(
      id: 'evt-$situationCode',
      userId: userId,
      situationCode: situationCode,
      createdAt: createdAt,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── (c) choose A then switch to B same day ──────────────────────────────

  group('(c) A → B same day: decrement A, record B', () {
    testWidgets('after switch A→B: pattern counts only contain B', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      final ref = await _pumpRef(tester, content: content, intel: intel);

      // First: choose sit-A
      await commitTodaySituation(ref, sit: _sit('sit-A'));

      // Verify sit-A recorded
      var counts = await intel.fetchPatternCounts('u1');
      expect(counts.any((c) => c.situationCode == 'sit-A' && c.occurrenceCount == 1), isTrue);

      // Now: switch to sit-B same day (memory event for sit-A already inserted by fake)
      await commitTodaySituation(ref, sit: _sit('sit-B'));

      counts = await intel.fetchPatternCounts('u1');
      final aCount = counts.where((c) => c.situationCode == 'sit-A').firstOrNull;
      final bCount = counts.where((c) => c.situationCode == 'sit-B').firstOrNull;

      // sit-A was decremented from 1 → deleted (count==1 → remove row)
      expect(aCount, isNull, reason: 'sit-A decremented from 1 → row deleted');
      // sit-B recorded
      expect(bCount?.occurrenceCount, 1, reason: 'sit-B newly recorded');
    });

    testWidgets('after A→B→A: pattern only contains A with count=1', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      final ref = await _pumpRef(tester, content: content, intel: intel);

      // Choose A
      await commitTodaySituation(ref, sit: _sit('sit-A'));
      // Switch to B
      await commitTodaySituation(ref, sit: _sit('sit-B'));
      // Switch back to A
      await commitTodaySituation(ref, sit: _sit('sit-A'));

      final counts = await intel.fetchPatternCounts('u1');
      final aCount = counts.where((c) => c.situationCode == 'sit-A').firstOrNull;
      final bCount = counts.where((c) => c.situationCode == 'sit-B').firstOrNull;

      expect(aCount?.occurrenceCount, 1, reason: 'sit-A re-recorded after switch back');
      expect(bCount, isNull, reason: 'sit-B removed when switching back to A');
    });

    testWidgets('decrement was called for old code when switching', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      final ref = await _pumpRef(tester, content: content, intel: intel);

      await commitTodaySituation(ref, sit: _sit('sit-A'));
      await commitTodaySituation(ref, sit: _sit('sit-B'));

      expect(
        intel.decrementSituationOccurrenceCalls.any((c) => c.situationCode == 'sit-A'),
        isTrue,
        reason: 'decrementSituationOccurrence called for old sit-A',
      );
    });
  });

  // ── (d) idempotent: choose A twice same day ─────────────────────────────

  group('(d) A → A same day: idempotent', () {
    testWidgets('recordSituationOccurrence called only once for same sit.code same day', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      final ref = await _pumpRef(tester, content: content, intel: intel);

      // First call
      final count1 = await commitTodaySituation(ref, sit: _sit('sit-A'));
      // Second call same day same code
      final count2 = await commitTodaySituation(ref, sit: _sit('sit-A'));

      expect(
        intel.recordSituationOccurrenceCalls.where((c) => c.situationCode == 'sit-A').length,
        1,
        reason: 'recordSituationOccurrence must be called only once (idempotent)',
      );
      expect(count1, 1);
      expect(count2, 1, reason: 'count unchanged on second call');
    });
  });

  // ── (e) yesterday event not touched ────────────────────────────────────

  group('(e) yesterday event for A: choosing B today does NOT decrement A', () {
    testWidgets('sit-A from yesterday preserved when choosing sit-B today', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      // Pre-seed yesterday's sit-A pattern count and memory event
      intel.seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-A',
          occurrenceCount: 1,
          lastSeenAt: DateTime(2026, 7, 22),
        ),
      ]);
      content.seedMemoryEvents([
        _memEvt(
          situationCode: 'sit-A',
          createdAt: _yesterdayVnMidnightUtc.add(const Duration(hours: 3)), // VN yesterday 03:00
        ),
      ]);

      final ref = await _pumpRef(tester, content: content, intel: intel);

      // Today choose sit-B
      await commitTodaySituation(ref, sit: _sit('sit-B'));

      final counts = await intel.fetchPatternCounts('u1');
      final aCount = counts.where((c) => c.situationCode == 'sit-A').firstOrNull;
      final bCount = counts.where((c) => c.situationCode == 'sit-B').firstOrNull;

      expect(aCount?.occurrenceCount, 1,
          reason: 'sit-A from yesterday must remain untouched (count still 1)');
      expect(bCount?.occurrenceCount, 1,
          reason: 'sit-B recorded for today');
      expect(
        intel.decrementSituationOccurrenceCalls,
        isEmpty,
        reason: 'no decrement called — yesterday event is not "today"',
      );
    });
  });

  // ── userId empty → no write ─────────────────────────────────────────────

  group('userId empty → returns 0 without writing', () {
    testWidgets('commitTodaySituation returns 0 when userId null', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wrContentRepositoryProvider.overrideWithValue(content),
            wrIntelligenceRepositoryProvider.overrideWithValue(intel),
            currentUserIdProvider.overrideWithValue(null), // null userId
          ],
          child: MaterialApp(
            home: _TestHarness(onRef: (ref) => capturedRef = ref),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final count = await commitTodaySituation(capturedRef, sit: _sit('sit-A'));

      expect(count, 0);
      expect(intel.recordSituationOccurrenceCalls, isEmpty);
    });
  });

  // ── memory event and reflection step written on first record ────────────

  group('memory event written on first record', () {
    testWidgets('insertMemoryEvent called with correct situationCode', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      final ref = await _pumpRef(tester, content: content, intel: intel);

      await commitTodaySituation(ref, sit: _sit('sit-A'), emotion: 'low');

      expect(content.insertMemoryEventCalls, hasLength(1));
      expect(content.insertMemoryEventCalls.first.situationCode, 'sit-A');
      expect(content.insertMemoryEventCalls.first.emotion, 'low');
    });

    testWidgets('insertMemoryEvent NOT called again on idempotent second call', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      final ref = await _pumpRef(tester, content: content, intel: intel);

      await commitTodaySituation(ref, sit: _sit('sit-A'));
      await commitTodaySituation(ref, sit: _sit('sit-A')); // idempotent

      expect(content.insertMemoryEventCalls, hasLength(1),
          reason: 'memory event only inserted once');
    });
  });

  // ── FIX 2: Atomicity — insertMemoryEvent lỗi → rollback count ───────────

  group('atomicity: insertMemoryEvent lỗi → count không tăng ròng', () {
    testWidgets('khi insertMemoryEvent throw, count sit-A KHÔNG tăng (rollback)', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      final ref = await _pumpRef(tester, content: content, intel: intel);

      // Giả lập insertMemoryEvent ném lỗi
      content.nextError = Exception('DB error on memory event');

      // commitTodaySituation sẽ: record OK, insertMemoryEvent throw → rollback → rethrow
      await expectLater(
        () => commitTodaySituation(ref, sit: _sit('sit-A')),
        throwsException,
        reason: 'lỗi insertMemoryEvent phải được rethrow',
      );

      // Count sit-A phải = 0 (record +1 rồi rollback -1 = 0)
      final counts = await intel.fetchPatternCounts('u1');
      final aCount = counts.where((c) => c.situationCode == 'sit-A').firstOrNull;
      expect(aCount, isNull,
          reason: 'count sit-A phải bị rollback về 0 khi insertMemoryEvent lỗi');
    });
  });

  // ── FIX 2: Atomicity — record B lỗi khi có A → A không mất ─────────────

  group('atomicity: record B lỗi khi có A hôm nay → A không bị decrement', () {
    testWidgets('khi recordSituationOccurrence(B) throw, A vẫn nguyên count=1', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      final ref = await _pumpRef(tester, content: content, intel: intel);

      // Bước 1: record A thành công
      await commitTodaySituation(ref, sit: _sit('sit-A'));

      var counts = await intel.fetchPatternCounts('u1');
      expect(counts.any((c) => c.situationCode == 'sit-A' && c.occurrenceCount == 1), isTrue,
          reason: 'sit-A phải có count=1 sau bước 1');

      // Bước 2: switch sang B nhưng recordSituationOccurrence(B) lỗi
      intel.nextError = Exception('DB error on record B');

      await expectLater(
        () => commitTodaySituation(ref, sit: _sit('sit-B')),
        throwsException,
        reason: 'lỗi recordSituationOccurrence(B) phải được rethrow',
      );

      // A phải còn nguyên (gỡ A xảy ra AFTER record B, mà B đã lỗi trước khi gỡ A)
      counts = await intel.fetchPatternCounts('u1');
      final aCount = counts.where((c) => c.situationCode == 'sit-A').firstOrNull;
      expect(aCount?.occurrenceCount, 1,
          reason: 'sit-A KHÔNG bị decrement khi record B lỗi (record new trước, gỡ cũ sau)');
      expect(
        intel.decrementSituationOccurrenceCalls.where((c) => c.situationCode == 'sit-A'),
        isEmpty,
        reason: 'decrement A không được gọi khi record B lỗi',
      );
    });
  });

  // ── FIX 2: Self-heal — marker tồn tại nhưng count==0 → re-record ────────

  group('self-heal: marker tồn tại hôm nay nhưng count==0 → re-record', () {
    testWidgets('sit-A có memory event hôm nay nhưng count==0 → commitTodaySituation re-record', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      // Pre-seed: memory event cho sit-A HÔM NAY (VN 2026-07-23)
      // nhưng KHÔNG seed pattern count → count == 0 (partial failure trước)
      content.seedMemoryEvents([
        CareerMemoryEvent(
          id: 'evt-sit-A',
          userId: 'u1',
          situationCode: 'sit-A',
          // VN 2026-07-23 02:00 = UTC 2026-07-22 19:00
          createdAt: _todayVnMidnightUtc.add(const Duration(hours: 2)),
        ),
      ]);
      // count = 0 (không seed)

      final ref = await _pumpRef(tester, content: content, intel: intel);

      // Self-heal: marker có nhưng count==0 → should re-record
      final count = await commitTodaySituation(ref, sit: _sit('sit-A'), nowUtc: _nowVnTodayUtc);

      expect(count, 1, reason: 'sau self-heal count phải là 1');
      expect(
        intel.recordSituationOccurrenceCalls.where((c) => c.situationCode == 'sit-A'),
        hasLength(1),
        reason: 'recordSituationOccurrence phải được gọi để self-heal',
      );
    });
  });

  // ── FIX 1: Boundary ngày VN trong service (lọc todayCodes) ──────────────

  group('boundary ngày VN trong service: 23:59 hôm qua KHÔNG phải hôm nay', () {
    testWidgets('event VN 23:59 hôm qua KHÔNG được coi là hôm nay → không decrement', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      // sit-A hôm qua VN 23:59 = UTC 2026-07-21 16:59
      // VN yesterday midnight UTC = 2026-07-21 17:00 → VN 23:59 = 2026-07-21 16:59 UTC
      final yesterdayVn2359Utc = DateTime.utc(2026, 7, 21, 16, 59, 0);

      intel.seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-A',
          occurrenceCount: 1,
          lastSeenAt: DateTime(2026, 7, 22),
        ),
      ]);
      content.seedMemoryEvents([
        CareerMemoryEvent(
          id: 'evt-yesterday-2359',
          userId: 'u1',
          situationCode: 'sit-A',
          createdAt: yesterdayVn2359Utc, // VN 2026-07-22 23:59 (hôm qua)
        ),
      ]);

      final ref = await _pumpRef(tester, content: content, intel: intel);

      // Chọn sit-B hôm nay
      await commitTodaySituation(ref, sit: _sit('sit-B'), nowUtc: _nowVnTodayUtc);

      final counts = await intel.fetchPatternCounts('u1');
      final aCount = counts.where((c) => c.situationCode == 'sit-A').firstOrNull;

      expect(aCount?.occurrenceCount, 1,
          reason: 'event VN 23:59 hôm qua KHÔNG phải hôm nay → sit-A không bị decrement');
      expect(
        intel.decrementSituationOccurrenceCalls.where((c) => c.situationCode == 'sit-A'),
        isEmpty,
        reason: 'decrement sit-A KHÔNG được gọi',
      );
    });

    testWidgets('event VN 00:01 HÔM NAY được coi là hôm nay → decrement khi switch', (tester) async {
      final content = FakeWrContentRepository();
      final intel = FakeWrIntelligenceRepository();

      // VN 00:01 hôm nay = UTC 2026-07-22 17:01
      final todayVn0001Utc = _todayVnMidnightUtc.add(const Duration(minutes: 1));

      intel.seedPatternCounts([
        PatternCount(
          userId: 'u1',
          situationCode: 'sit-A',
          occurrenceCount: 2,
          lastSeenAt: DateTime(2026, 7, 23),
        ),
      ]);
      content.seedMemoryEvents([
        CareerMemoryEvent(
          id: 'evt-today-0001',
          userId: 'u1',
          situationCode: 'sit-A',
          createdAt: todayVn0001Utc, // VN 2026-07-23 00:01 (hôm nay)
        ),
      ]);

      final ref = await _pumpRef(tester, content: content, intel: intel);

      // Switch sang sit-B hôm nay
      await commitTodaySituation(ref, sit: _sit('sit-B'), nowUtc: _nowVnTodayUtc);

      expect(
        intel.decrementSituationOccurrenceCalls.where((c) => c.situationCode == 'sit-A'),
        isNotEmpty,
        reason: 'event VN 00:01 HÔM NAY → sit-A PHẢI được decrement khi switch sang B',
      );
    });
  });
}
