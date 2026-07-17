import 'package:workreflection_mobile/core/data/survey_repository.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';

/// In-memory fake SurveyRepository for widget/unit tests.
/// Pre-populate via seed* methods; inspect calls via *Calls fields.
class FakeSurveyRepository implements SurveyRepository {
  // --- Internal state ---
  String _role = 'user';
  List<CcQuestion> _questions = [];
  Map<ScaleType, List<CcLikertOption>> _likertOptions = {};
  List<CcNarrative> _narratives = [];
  List<ActionPlanPhase> _actionPlan = [];
  Map<String, bool> _actionProgress = {};
  CcReportFull? _latestReport;
  final Map<String, CcReportFull> _reports = {};
  TtsResult _ttsResult = const TtsResult(
    audioUrl: 'https://fake.audio/tts.mp3',
    durationMs: 3000,
    fromCache: true,
  );

  // --- Call recorders ---
  final List<Map<String, int>> submitSurveyCalls = [];
  final List<(String, String, bool)> toggleTaskCalls = [];
  final List<(String, String)> ttsCalls = [];

  // --- Seed helpers ---

  void seedRole(String role) => _role = role;

  void seedQuestions(List<CcQuestion> questions) =>
      _questions = List.of(questions);

  void seedLikertOptions(Map<ScaleType, List<CcLikertOption>> options) =>
      _likertOptions = Map.of(options);

  void seedNarratives(List<CcNarrative> narratives) =>
      _narratives = List.of(narratives);

  void seedActionPlan(List<ActionPlanPhase> phases) =>
      _actionPlan = List.of(phases);

  void seedActionProgress(Map<String, bool> progress) =>
      _actionProgress = Map.of(progress);

  void seedLatestReport(CcReportFull report) {
    _latestReport = report;
    _reports[report.id] = report;
  }

  void seedTtsResult(TtsResult result) => _ttsResult = result;

  // --- SurveyRepository impl ---

  @override
  Future<String> getUserRole() async => _role;

  @override
  SurveyType surveyTypeForRole(String role) =>
      (role == 'premium' || role == 'admin')
          ? SurveyType.premium
          : SurveyType.free;

  @override
  Future<List<CcQuestion>> getQuestions(SurveyType type) async =>
      List.unmodifiable(_questions);

  @override
  Future<Map<ScaleType, List<CcLikertOption>>> getLikertOptions() async =>
      Map.unmodifiable(_likertOptions);

  @override
  Future<CcReportFull> submitSurvey({
    required SurveyType type,
    required Map<String, int> answers,
    required List<CcQuestion> questions,
    String? userPosition,
    String? userWorkExperience,
    String? userCompanyTenure,
    String? userCompanySize,
    String? userDepartment,
  }) async {
    submitSurveyCalls.add(Map.of(answers));
    final report = _latestReport ??
        CcReportFull(
          id: 'fake-report-id',
          surveyId: 'fake-survey-id',
          userId: 'fake-user',
          scoreTotal: 3.8,
          scoreStructure: 4.0,
          scoreCulture: 3.5,
          scoreActivity: 3.9,
          bottleneckLayer: SurveyLayer.culture,
          scoreLevel: ScoreLevel.good,
          createdAt: DateTime.now(),
        );
    _latestReport = report;
    _reports[report.id] = report;
    return report;
  }

  @override
  Future<CcReportFull?> getReport(String reportId) async =>
      _reports[reportId];

  @override
  Future<CcReportFull?> getLatestReportFull() async => _latestReport;

  @override
  Future<List<CcNarrative>> getNarratives() async =>
      List.unmodifiable(_narratives);

  @override
  Future<List<ActionPlanPhase>> getActionPlan(SurveyType type) async =>
      List.unmodifiable(_actionPlan);

  @override
  Future<Map<String, bool>> getActionProgress(String reportId) async =>
      Map.of(_actionProgress);

  @override
  Future<void> toggleTask(String taskId, String reportId, bool completed) async {
    toggleTaskCalls.add((taskId, reportId, completed));
    _actionProgress[taskId] = completed;
  }

  @override
  Future<TtsResult> tts(String text, String language) async {
    ttsCalls.add((text, language));
    return _ttsResult;
  }
}
