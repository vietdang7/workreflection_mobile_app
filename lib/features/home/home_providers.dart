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
    final prior = state;
    // Optimistic update
    state = AsyncData(mood);
    final repo = ref.read(wrRepositoryProvider);
    try {
      await repo.upsertCheckin(mood);
    } catch (e) {
      // Revert to prior state so the UI stays consistent.
      state = prior;
      // Surface the error via a side channel if needed (callers can listen to
      // checkinErrorProvider or catch via notifier wrapper).
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
