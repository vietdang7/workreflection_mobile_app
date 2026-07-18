// Fake RoadmapRepository for widget/unit tests — Phase 5 Task 5.
//
// Pre-populate via seed* helpers before pumping widgets.
// Inspect recorded calls via the *Calls fields.
// Set [nextError] to simulate a single failure (auto-cleared after throw).

import 'package:workreflection_mobile/core/data/roadmap_repository.dart';

class FakeRoadmapRepository implements RoadmapRepository {
  // --- Internal state ---
  final List<PremiumReport> _reports = [];
  RoadmapProgressData _progress = const RoadmapProgressData(
    completedActionIds: {},
    completedActionDates: {},
    customTasks: [],
  );
  final List<RoadmapAction> _actions = [];
  final List<CoachAccessEntry> _coachAccess = [];
  final List<AvailableCoach> _coaches = [];

  /// When set, the next repo call throws this error once, then clears it.
  Object? nextError;

  // --- Call recorders ---
  final List<Map<String, Object>> toggleActionCalls = [];
  final List<Map<String, Object>> toggleCustomTaskCalls = [];
  final List<Map<String, Object?>> addCustomTaskCalls = [];
  final List<Map<String, Object?>> updateCustomTaskCalls = [];
  final List<String> deleteCustomTaskCalls = [];
  final List<Map<String, String>> updateNicknameCalls = [];
  final List<String> inviteCoachCalls = [];

  // --- Seed helpers ---

  void seedReports(List<PremiumReport> reports) {
    _reports
      ..clear()
      ..addAll(reports);
  }

  void seedProgress(RoadmapProgressData progress) {
    _progress = progress;
  }

  void seedActions(List<RoadmapAction> actions) {
    _actions
      ..clear()
      ..addAll(actions);
  }

  void seedCoachAccess(List<CoachAccessEntry> entries) {
    _coachAccess
      ..clear()
      ..addAll(entries);
  }

  void seedCoaches(List<AvailableCoach> coaches) {
    _coaches
      ..clear()
      ..addAll(coaches);
  }

  // --- Helpers ---

  void _maybeThrow() {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      // ignore: only_throw_errors
      throw err;
    }
  }

  // --- RoadmapRepository impl ---

  @override
  Future<List<PremiumReport>> getPremiumReports() async {
    _maybeThrow();
    return List.unmodifiable(_reports);
  }

  @override
  Future<RoadmapProgressData> getProgressForReport(String reportId) async {
    _maybeThrow();
    return _progress;
  }

  @override
  Future<List<RoadmapAction>> getRoadmapActions() async {
    _maybeThrow();
    return List.unmodifiable(_actions);
  }

  @override
  Future<void> toggleRoadmapAction({
    required String reportId,
    required String actionRefId,
    required bool isCompleted,
  }) async {
    _maybeThrow();
    toggleActionCalls.add({
      'reportId': reportId,
      'actionRefId': actionRefId,
      'isCompleted': isCompleted,
    });
  }

  @override
  Future<void> toggleCustomTask({
    required String taskId,
    required bool isCompleted,
  }) async {
    _maybeThrow();
    toggleCustomTaskCalls.add({'taskId': taskId, 'isCompleted': isCompleted});
  }

  @override
  Future<CustomTask> addCustomTask({
    required String reportId,
    required String title,
    String? description,
    required String layer,
    required int day,
    String? dueDate,
  }) async {
    _maybeThrow();
    final task = CustomTask(
      id: 'new-task-${addCustomTaskCalls.length + 1}',
      reportId: reportId,
      title: title,
      description: description,
      layer: layer,
      day: day,
      isCompleted: false,
      createdBy: 'test-user',
      displayOrder: 0,
      dueDate: dueDate,
    );
    addCustomTaskCalls.add({
      'reportId': reportId,
      'title': title,
      'description': description,
      'layer': layer,
      'day': day,
      'dueDate': dueDate,
    });
    return task;
  }

  @override
  Future<void> updateCustomTask({
    required String taskId,
    required String title,
    String? description,
    String? dueDate,
  }) async {
    _maybeThrow();
    updateCustomTaskCalls.add({
      'taskId': taskId,
      'title': title,
      'description': description,
      'dueDate': dueDate,
    });
  }

  @override
  Future<void> deleteCustomTask(String taskId) async {
    _maybeThrow();
    deleteCustomTaskCalls.add(taskId);
  }

  @override
  Future<void> updateReportNickname({
    required String reportId,
    required String nickname,
  }) async {
    _maybeThrow();
    updateNicknameCalls.add({'reportId': reportId, 'nickname': nickname});
  }

  @override
  Future<List<CoachAccessEntry>> getCoachAccess() async {
    _maybeThrow();
    return List.unmodifiable(_coachAccess);
  }

  @override
  Future<void> inviteCoach(String coachId) async {
    _maybeThrow();
    inviteCoachCalls.add(coachId);
  }

  @override
  Future<List<AvailableCoach>> getAvailableCoaches() async {
    _maybeThrow();
    return List.unmodifiable(_coaches);
  }
}
