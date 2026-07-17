import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/wr_repository.dart';
import '../../core/logic/streak.dart';
import '../../core/models/mobile_profile.dart';

// ---------------------------------------------------------------------------
// App locale provider — drives WrApp locale live
// ---------------------------------------------------------------------------

final appLocaleProvider = StateProvider<String>((ref) => 'vi');

// ---------------------------------------------------------------------------
// Profile data
// ---------------------------------------------------------------------------

final mobileProfileProvider = FutureProvider<MobileProfile?>((ref) async {
  return ref.watch(wrRepositoryProvider).getMobileProfile();
});

final ccProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(wrRepositoryProvider).getCcProfile();
});

final insightCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(wrRepositoryProvider).countInsights();
});

final milestoneCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(wrRepositoryProvider).countMilestones();
});

final streakProvider = FutureProvider<int>((ref) async {
  final dates = await ref.watch(wrRepositoryProvider).getCheckinDates();
  return computeStreak(dates, DateTime.now());
});

// ---------------------------------------------------------------------------
// Reminder toggle notifier
// ---------------------------------------------------------------------------

class ReminderNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final profile = await ref.watch(mobileProfileProvider.future);
    return profile?.reminderEnabled ?? true;
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? true;
    state = AsyncData(!current);
    try {
      await ref.read(wrRepositoryProvider).updateReminder(!current);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final reminderProvider =
    AsyncNotifierProvider<ReminderNotifier, bool>(ReminderNotifier.new);
