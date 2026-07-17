import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/survey_repository.dart';
import '../../core/models/survey_models.dart';

// ---------------------------------------------------------------------------
// Repository provider (overridable in tests)
// ---------------------------------------------------------------------------

export '../../core/data/survey_repository.dart' show surveyRepositoryProvider;

// ---------------------------------------------------------------------------
// Role + survey type
// ---------------------------------------------------------------------------

final surveyRoleProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getUserRole();
});

final surveyTypeProvider = FutureProvider<SurveyType>((ref) async {
  final role = await ref.watch(surveyRoleProvider.future);
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.surveyTypeForRole(role);
});

// ---------------------------------------------------------------------------
// Questions + likert options
// ---------------------------------------------------------------------------

final surveyQuestionsProvider =
    FutureProvider.family<List<CcQuestion>, SurveyType>((ref, type) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getQuestions(type);
});

final likertOptionsProvider =
    FutureProvider<Map<ScaleType, List<CcLikertOption>>>((ref) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getLikertOptions();
});

// ---------------------------------------------------------------------------
// Answers state (question id → answer value)
// ---------------------------------------------------------------------------

final surveyAnswersProvider =
    StateNotifierProvider<SurveyAnswersNotifier, Map<String, int>>((ref) {
  return SurveyAnswersNotifier();
});

class SurveyAnswersNotifier extends StateNotifier<Map<String, int>> {
  SurveyAnswersNotifier() : super({});

  void setAnswer(String questionId, int value) {
    state = {...state, questionId: value};
  }

  void reset() => state = {};
}

// ---------------------------------------------------------------------------
// Current question index
// ---------------------------------------------------------------------------

final currentQuestionIndexProvider = StateProvider<int>((ref) => 0);

// ---------------------------------------------------------------------------
// Latest report (for Understand screen link)
// ---------------------------------------------------------------------------

final latestReportProvider = FutureProvider<CcReportFull?>((ref) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getLatestReportFull();
});

// ---------------------------------------------------------------------------
// Narratives
// ---------------------------------------------------------------------------

final narrativesProvider = FutureProvider<List<CcNarrative>>((ref) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getNarratives();
});

// ---------------------------------------------------------------------------
// Action plan
// ---------------------------------------------------------------------------

final actionPlanProvider =
    FutureProvider.family<List<ActionPlanPhase>, SurveyType>((ref, type) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getActionPlan(type);
});

final actionProgressProvider =
    FutureProvider.family<Map<String, bool>, String>((ref, reportId) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getActionProgress(reportId);
});

// ---------------------------------------------------------------------------
// Optimistic action progress notifier
// ---------------------------------------------------------------------------

final actionProgressNotifierProvider = StateNotifierProvider.family<
    ActionProgressNotifier, Map<String, bool>, String>((ref, reportId) {
  return ActionProgressNotifier(ref, reportId);
});

class ActionProgressNotifier extends StateNotifier<Map<String, bool>> {
  ActionProgressNotifier(this._ref, this._reportId) : super({});

  final Ref _ref;
  final String _reportId;

  void init(Map<String, bool> progress) {
    state = Map.of(progress);
  }

  Future<void> toggle(String taskId, bool completed) async {
    // Optimistic update
    state = {...state, taskId: completed};
    try {
      final repo = _ref.read(surveyRepositoryProvider);
      await repo.toggleTask(taskId, _reportId, completed);
    } catch (_) {
      // Revert on error
      state = {...state, taskId: !completed};
    }
  }
}
