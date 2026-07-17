import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/survey_repository.dart';
import '../../core/models/survey_models.dart';

// ---------------------------------------------------------------------------
// Repository provider (overridable in tests)
// ---------------------------------------------------------------------------

export '../../core/data/survey_repository.dart' show surveyRepositoryProvider;

// ---------------------------------------------------------------------------
// Intro info (set from SurveyIntroScreen, read in SurveyProcessingScreen)
// ---------------------------------------------------------------------------

class SurveyIntroInfo {
  const SurveyIntroInfo({
    this.userPosition,
    this.userWorkExperience,
    this.userCompanyTenure,
    this.userCompanySize,
    this.userDepartment,
  });
  final String? userPosition;
  final String? userWorkExperience;
  final String? userCompanyTenure;
  final String? userCompanySize;
  final String? userDepartment;
}

final surveyIntroInfoProvider =
    StateProvider<SurveyIntroInfo>((ref) => const SurveyIntroInfo());

// Tracks surveyId created in step 1 of submitSurvey so retry can skip it
final surveyIdInProgressProvider = StateProvider<String?>((ref) => null);

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
    FutureProvider<Map<String, bool>>((ref) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getActionProgress();
});

// ---------------------------------------------------------------------------
// Optimistic action progress notifier
// ---------------------------------------------------------------------------

final actionProgressNotifierProvider = StateNotifierProvider.autoDispose.family<
    ActionProgressNotifier, Map<String, bool>, String>((ref, reportId) {
  return ActionProgressNotifier(ref, reportId);
});

class ActionProgressNotifier extends StateNotifier<Map<String, bool>> {
  // ignore: avoid_unused_constructor_parameters
  ActionProgressNotifier(this._ref, String reportId) : super({});

  final Ref _ref;
  bool _initialized = false;

  void init(Map<String, bool> progress) {
    if (_initialized) return;
    _initialized = true;
    state = Map.of(progress);
  }

  Future<void> toggle(String taskId, bool completed) async {
    final priorValue = state[taskId] ?? false;
    state = {...state, taskId: completed}; // optimistic
    try {
      final repo = _ref.read(surveyRepositoryProvider);
      await repo.toggleTask(taskId, completed);
    } catch (_) {
      state = {...state, taskId: priorValue}; // revert to prior
    }
  }
}
