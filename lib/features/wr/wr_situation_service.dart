// lib/features/wr/wr_situation_service.dart
//
// commitTodaySituation — shared "one situation per day, replace on change" logic.
//
// Used by WrHomeScreen._saveSituation and WrSituationFlowScreen._save.
// Replaces manual recordSituationOccurrence + insertMemoryEvent scattered in UI.
//
// Contract:
//   - Returns occurrenceCount of sit.code AFTER the write (for "lần thứ N" UI).
//   - If userId is empty, returns 0 without writing.
//   - Self-heal idempotency: if sit.code's memory-event exists today BUT count==0
//     (partial failure before), re-records so count becomes 1 (self-heal).
//   - If sit.code already in today codes AND count > 0: idempotent, skip write.
//   - Atomicity order: RECORD NEW FIRST, then remove old ones.
//     (1) recordSituationOccurrence(sit) — throws on error → caller reverts.
//     (2) insertMemoryEvent(sit) — if fails, rollback via decrementSituationOccurrence
//         then throw (to avoid count without marker → double-count later).
//     (3) insertReflectionStep — best-effort, errors swallowed.
//     (4) Remove old today codes: decrement + deleteTodayMemoryEventsForSituation
//         — best-effort, errors swallowed (over-count is temporary, no data loss).
//   - recordSituationOccurrence errors are re-thrown so callers can show SnackBar.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_content_repository.dart';
import '../../core/data/wr_intelligence_repository.dart';
import '../../core/logic/vn_date.dart';
import '../../core/models/wr_content.dart';
import '../../core/models/wr_intelligence.dart';
import 'wr_providers.dart';

/// Commit [sit] as today's situation for the current user.
///
/// Accepts either a [Ref] (from providers/services) or [WidgetRef] (from widgets).
/// Both expose `.read()` — we accept the common supertype via [_RefReader].
///
/// [emotion] is stored in the CareerMemoryEvent (e.g. 'low', 'ok', 'good').
///
/// [nowUtc] injects the current instant (as a UTC DateTime) for deterministic
/// tests around the VN day boundary. Defaults to the real clock in production —
/// callers (Home / SituationFlow) never pass it.
///
/// Returns the occurrenceCount of [sit.code] after the operation.
/// Returns 0 if userId is empty/null.
Future<int> commitTodaySituation(
  // WidgetRef extends Ref in Riverpod; both have `.read()`.
  // We accept WidgetRef explicitly since both call sites are ConsumerState.
  WidgetRef ref, {
  required WrSituation sit,
  String? emotion,
  DateTime? nowUtc,
}) async {
  final userId = ref.read(currentUserIdProvider) ?? '';
  if (userId.isEmpty) return 0;

  final contentRepo = ref.read(wrContentRepositoryProvider);
  final intelRepo = ref.read(wrIntelligenceRepositoryProvider);
  // Derive the VN date from the injected clock (tests) or real now (production).
  final today = todayVnFrom((nowUtc ?? DateTime.now()).toUtc());

  // Step 2: Find today's already-recorded situation codes from memory events.
  final allEvents = await contentRepo.fetchMemoryEventsForUser(userId);
  final todayCodes = <String>{};
  for (final e in allEvents) {
    if (e.situationCode == null) continue;
    final created = e.createdAt;
    if (created == null) continue;
    // todayVnFrom expects a UTC DateTime and adds 7h internally.
    // Use .toUtc() here: createdAt from DB is already a true UTC instant,
    // so .toUtc() is a no-op / safe conversion (not a local DateTime).
    final eventDay = todayVnFrom(created.toUtc());
    if (eventDay == today) {
      todayCodes.add(e.situationCode!);
    }
  }

  // Step 3: Self-heal idempotency check.
  // If sit.code marker exists today AND occurrenceCount > 0 → truly idempotent.
  // If marker exists but count == 0 (partial failure before) → fall through to re-record.
  if (todayCodes.contains(sit.code)) {
    final currentCounts = await intelRepo.fetchPatternCounts(userId);
    final currentCount = currentCounts
        .where((p) => p.situationCode == sit.code)
        .fold<int>(0, (acc, p) => acc + p.occurrenceCount);
    if (currentCount > 0) {
      // Truly idempotent: already recorded with valid count.
      return currentCount;
    }
    // count == 0 → partial failure before: remove marker from todayCodes so we re-record.
    todayCodes.remove(sit.code);
  }

  // Step 4: Record NEW situation FIRST (atomicity: new before removing old).
  // (1) recordSituationOccurrence throws on error → caller handles SnackBar.
  await intelRepo.recordSituationOccurrence(
    userId: userId,
    situationCode: sit.code,
    scaDimensionDb: sit.scaDimension.dbValue,
  );

  // (2) insertMemoryEvent — important marker: if it fails, rollback count to avoid
  //     double-count on next call (count incremented but no marker = self-heal broken).
  try {
    await contentRepo.insertMemoryEvent(CareerMemoryEvent(
      id: '',
      userId: userId,
      situationCode: sit.code,
      humanNeed: sit.humanNeed,
      scaDimension: sit.scaDimension,
      emotion: emotion,
    ));
  } catch (e) {
    // Rollback: decrement count so count stays in sync with absent marker.
    try {
      await intelRepo.decrementSituationOccurrence(
        userId: userId,
        situationCode: sit.code,
      );
    } catch (_) { /* best-effort rollback */ }
    rethrow; // Caller shows SnackBar.
  }

  // (3) Reflection step — best-effort, errors swallowed.
  try {
    await intelRepo.insertReflectionStep(ReflectionStep(
      userId: userId,
      step: ReflectionStepType.notice,
      content: sit.code,
    ));
  } catch (_) { /* nuốt lỗi */ }

  // (4) Remove old today codes AFTER new record is committed.
  //     Best-effort: failure = temporary over-count, no user data lost.
  for (final oldCode in todayCodes) {
    if (oldCode == sit.code) continue;
    try {
      await intelRepo.decrementSituationOccurrence(
        userId: userId,
        situationCode: oldCode,
      );
    } catch (_) { /* best-effort */ }
    try {
      await contentRepo.deleteTodayMemoryEventsForSituation(
        userId: userId,
        situationCode: oldCode,
        day: today,
      );
    } catch (_) { /* best-effort */ }
  }

  // Step 6: Return current occurrenceCount for sit.code.
  final counts = await intelRepo.fetchPatternCounts(userId);
  return counts
      .where((p) => p.situationCode == sit.code)
      .fold<int>(0, (acc, p) => acc + p.occurrenceCount);
}
