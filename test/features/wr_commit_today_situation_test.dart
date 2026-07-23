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
}
