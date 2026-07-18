// Roadmap tracker providers — Phase 5 Task 5.
//
// Mirrors web logic in useRoadmapTracker.ts and RoadmapTracker.tsx:
//   - premiumReportsProvider  → usePremiumReports
//   - roadmapProgressProvider → useRoadmapForReport
//   - roadmapActionsProvider  → useRoadmapNarratives (fetches cc_roadmap_actions)
//   - coachAccessProvider     → useRoadmapCoachAccess
//   - availableCoachesProvider→ useAvailableCoaches
//   - roadmapActionToggleNotifierProvider → useToggleRoadmapAction (optimistic)
//   - customTaskToggleNotifierProvider    → useToggleCustomTask (optimistic)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/roadmap_repository.dart';
export '../../core/data/roadmap_repository.dart'
    show
        RoadmapRepository,
        roadmapRepositoryProvider,
        PremiumReport,
        RoadmapAction,
        CustomTask,
        RoadmapProgressData,
        CoachAccessEntry,
        AvailableCoach;

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

/// All premium reports for the current user (with nicknames).
final premiumReportsProvider = FutureProvider<List<PremiumReport>>((ref) {
  return ref.watch(roadmapRepositoryProvider).getPremiumReports();
});

/// Progress + custom tasks for a given report.
final roadmapProgressProvider =
    FutureProvider.family<RoadmapProgressData, String>((ref, reportId) {
  return ref.watch(roadmapRepositoryProvider).getProgressForReport(reportId);
});

/// All active roadmap action templates.
final roadmapActionsProvider =
    FutureProvider<List<RoadmapAction>>((ref) {
  return ref.watch(roadmapRepositoryProvider).getRoadmapActions();
});

/// Coach access entries for the current user.
final coachAccessProvider =
    FutureProvider<List<CoachAccessEntry>>((ref) {
  return ref.watch(roadmapRepositoryProvider).getCoachAccess();
});

/// All active coaches (for the invite dialog).
final availableCoachesProvider =
    FutureProvider<List<AvailableCoach>>((ref) {
  return ref.watch(roadmapRepositoryProvider).getAvailableCoaches();
});

// ---------------------------------------------------------------------------
// Optimistic action toggle notifier (mirrors actionProgressNotifierProvider)
// ---------------------------------------------------------------------------

/// Family key: reportId. State: Map of actionRefId to isCompleted.
final roadmapActionToggleNotifierProvider = StateNotifierProvider.autoDispose
    .family<RoadmapActionToggleNotifier, Map<String, bool>, String>(
        (ref, reportId) {
  return RoadmapActionToggleNotifier(ref, reportId);
});

class RoadmapActionToggleNotifier
    extends StateNotifier<Map<String, bool>> {
  // ignore: avoid_unused_constructor_parameters
  RoadmapActionToggleNotifier(this._ref, this._reportId) : super({});

  final Ref _ref;
  // ignore: unused_field
  final String _reportId;
  bool _initialized = false;

  void init(Set<String> completedIds) {
    if (_initialized) return;
    _initialized = true;
    state = {for (final id in completedIds) id: true};
  }

  Future<void> toggle(String actionRefId, bool completed) async {
    final prior = state[actionRefId] ?? false;
    state = {...state, actionRefId: completed}; // optimistic
    try {
      await _ref.read(roadmapRepositoryProvider).toggleRoadmapAction(
            reportId: _reportId,
            actionRefId: actionRefId,
            isCompleted: completed,
          );
    } catch (_) {
      state = {...state, actionRefId: prior}; // rollback
    }
  }
}

// ---------------------------------------------------------------------------
// Optimistic custom task toggle notifier
// ---------------------------------------------------------------------------

/// Family key: reportId. State: Map of taskId to isCompleted.
final customTaskToggleNotifierProvider = StateNotifierProvider.autoDispose
    .family<CustomTaskToggleNotifier, Map<String, bool>, String>(
        (ref, reportId) {
  return CustomTaskToggleNotifier(ref, reportId);
});

class CustomTaskToggleNotifier extends StateNotifier<Map<String, bool>> {
  // ignore: avoid_unused_constructor_parameters
  CustomTaskToggleNotifier(this._ref, this._reportId) : super({});

  final Ref _ref;
  // ignore: unused_field
  final String _reportId;
  bool _initialized = false;

  void init(List<CustomTask> tasks) {
    if (_initialized) return;
    _initialized = true;
    state = {for (final t in tasks) t.id: t.isCompleted};
  }

  Future<void> toggle(String taskId, bool completed) async {
    final prior = state[taskId] ?? false;
    state = {...state, taskId: completed}; // optimistic
    try {
      await _ref.read(roadmapRepositoryProvider).toggleCustomTask(
            taskId: taskId,
            isCompleted: completed,
          );
    } catch (_) {
      state = {...state, taskId: prior}; // rollback
    }
  }
}
