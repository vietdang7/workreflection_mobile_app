import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/wr_repository.dart';
import '../../core/models/checkin.dart';
import '../../core/models/insight.dart';
import '../../core/models/recurring_situation.dart';

// ---------------------------------------------------------------------------
// Today's check-in — AsyncNotifier with optimistic update
// ---------------------------------------------------------------------------

class CheckinNotifier extends AsyncNotifier<Mood?> {
  @override
  Future<Mood?> build() async {
    final repo = ref.watch(wrRepositoryProvider);
    final checkin = await repo.getTodayCheckin();
    return checkin?.mood;
  }

  Future<void> selectMood(Mood mood) async {
    // Optimistic update
    state = AsyncData(mood);
    final repo = ref.read(wrRepositoryProvider);
    try {
      await repo.upsertCheckin(mood);
    } catch (e, st) {
      // Revert on failure
      state = AsyncError(e, st);
    }
  }
}

final checkinProvider = AsyncNotifierProvider<CheckinNotifier, Mood?>(() {
  return CheckinNotifier();
});

// ---------------------------------------------------------------------------
// Latest insight
// ---------------------------------------------------------------------------

final latestInsightProvider = FutureProvider<Insight?>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  return repo.getLatestInsight();
});

// ---------------------------------------------------------------------------
// Recurring situations (top for home card)
// ---------------------------------------------------------------------------

final recurringSituationsProvider =
    FutureProvider<List<RecurringSituation>>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  return repo.getRecurringSituations();
});
