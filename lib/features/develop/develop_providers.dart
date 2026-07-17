import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/wr_repository.dart';
import '../../core/models/development_theme.dart';
import '../../core/models/practice.dart';
import '../../core/models/workshop.dart';

final activeThemeProvider = FutureProvider<DevelopmentTheme?>((ref) async {
  return ref.watch(wrRepositoryProvider).getActiveTheme();
});

final upcomingWorkshopProvider = FutureProvider<Workshop?>((ref) async {
  return ref.watch(wrRepositoryProvider).getUpcomingWorkshop();
});

// ---------------------------------------------------------------------------
// Practices — AsyncNotifier so we can optimistically update status
// ---------------------------------------------------------------------------

class PracticesNotifier extends AsyncNotifier<List<Practice>> {
  @override
  Future<List<Practice>> build() async {
    return ref.watch(wrRepositoryProvider).getTodayPractices();
  }

  Future<void> advanceStatus(String id) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((p) => p.id == id);
    if (idx == -1) return;

    final practice = current[idx];
    // done is terminal — no-op
    if (practice.status == PracticeStatus.done) return;

    final next = practice.status == PracticeStatus.todo
        ? PracticeStatus.doing
        : PracticeStatus.done;

    final prior = state;
    // Optimistic update
    final updated = List<Practice>.from(current);
    updated[idx] = practice.copyWith(
      status: next,
      completedAt: next == PracticeStatus.done ? DateTime.now() : null,
    );
    state = AsyncData(updated);

    try {
      await ref.read(wrRepositoryProvider).updatePracticeStatus(id, next);
    } catch (e) {
      // Revert to prior state so the UI stays consistent.
      state = prior;
    }
  }
}

final practicesProvider =
    AsyncNotifierProvider<PracticesNotifier, List<Practice>>(() {
  return PracticesNotifier();
});
