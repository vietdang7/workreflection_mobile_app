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
//   - If sit.code is already today's situation (in memory events), is idempotent:
//     does NOT increment count again, returns current count.
//   - If user had a different situation today, removes it first (decrement + delete
//     memory event), then records the new one.
//   - insertMemoryEvent / insertReflectionStep errors are swallowed (non-fatal).
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
/// Returns the occurrenceCount of [sit.code] after the operation.
/// Returns 0 if userId is empty/null.
Future<int> commitTodaySituation(
  // WidgetRef extends Ref in Riverpod; both have `.read()`.
  // We accept WidgetRef explicitly since both call sites are ConsumerState.
  WidgetRef ref, {
  required WrSituation sit,
  String? emotion,
}) async {
  final userId = ref.read(currentUserIdProvider) ?? '';
  if (userId.isEmpty) return 0;

  final contentRepo = ref.read(wrContentRepositoryProvider);
  final intelRepo = ref.read(wrIntelligenceRepositoryProvider);
  final today = todayVn();

  // Step 2: Find today's already-recorded situation codes from memory events.
  final allEvents = await contentRepo.fetchMemoryEventsForUser(userId);
  final todayCodes = <String>{};
  for (final e in allEvents) {
    if (e.situationCode == null) continue;
    final created = e.createdAt;
    if (created == null) continue;
    // todayVnFrom expects a UTC DateTime and adds 7h internally.
    final eventDay = todayVnFrom(created.toUtc());
    if (eventDay == today) {
      todayCodes.add(e.situationCode!);
    }
  }

  // Step 3: sit.code already today → idempotent, skip write.
  if (!todayCodes.contains(sit.code)) {
    // Step 4: Remove any other today situations (old choices).
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

    // Step 5: Record new situation.
    // recordSituationOccurrence throws on error → caller handles SnackBar.
    await intelRepo.recordSituationOccurrence(
      userId: userId,
      situationCode: sit.code,
      scaDimensionDb: sit.scaDimension.dbValue,
    );

    // Memory event — non-fatal.
    try {
      await contentRepo.insertMemoryEvent(CareerMemoryEvent(
        id: '',
        userId: userId,
        situationCode: sit.code,
        humanNeed: sit.humanNeed,
        scaDimension: sit.scaDimension,
        emotion: emotion,
      ));
    } catch (_) { /* nuốt lỗi */ }

    // Reflection step — non-fatal.
    try {
      await intelRepo.insertReflectionStep(ReflectionStep(
        userId: userId,
        step: ReflectionStepType.notice,
        content: sit.code,
      ));
    } catch (_) { /* nuốt lỗi */ }
  }

  // Step 6: Return current occurrenceCount for sit.code.
  final counts = await intelRepo.fetchPatternCounts(userId);
  return counts
      .where((p) => p.situationCode == sit.code)
      .fold<int>(0, (acc, p) => acc + p.occurrenceCount);
}
