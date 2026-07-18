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
  // Mirrors idempotent cc_reports: surveyId → report already created
  final Map<String, CcReportFull> _reportsBySurveyId = {};
  TtsResult _ttsResult = const TtsResult(
    audioUrl: 'https://fake.audio/tts.mp3',
    durationMs: 3000,
    fromCache: true,
  );

  // --- Blocker-faithful fields ---
  bool _toggleShouldFail = false;
  bool _narrativesFails = false;
  List<String>? _configQuestionIds;

  // --- Submit-failure-once fields ---
  bool _submitFailsOnce = false;
  int _submitCount = 0;

  // --- Call recorders ---
  final List<Map<String, int>> submitSurveyCalls = [];
  final List<String?> submitExistingIds = [];
  final List<(String, bool)> toggleTaskCalls = [];
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

  void setToggleFails(bool v) => _toggleShouldFail = v;
  void setNarrativesFails(bool v) => _narrativesFails = v;
  void setSubmitFailsOnce(bool v) {
    _submitFailsOnce = v;
    _submitCount = 0;
  }

  void seedConfigQuestionIds(List<String> ids, {SurveyType? surveyType}) {
    _configQuestionIds = ids;
  }

  // --- SurveyRepository impl ---

  @override
  Future<String> getUserRole() async => _role;

  @override
  SurveyType surveyTypeForRole(String role) =>
      (role == 'premium' || role == 'admin')
          ? SurveyType.premium
          : SurveyType.free;

  @override
  Future<List<CcQuestion>> getQuestions(SurveyType type) async {
    if (_configQuestionIds != null) {
      final byId = {for (final q in _questions) q.id: q};
      return _configQuestionIds!
          .where((id) => byId.containsKey(id) && byId[id]!.isActive)
          .map((id) => byId[id]!)
          .toList();
    }
    return List.unmodifiable(_questions);
  }

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
    String? existingSurveyId,
    void Function(String surveyId)? onSurveyCreated,
  }) async {
    _submitCount++;
    submitSurveyCalls.add(Map.of(answers));
    submitExistingIds.add(existingSurveyId);

    final surveyId = existingSurveyId ?? 'fake-survey-id';
    if (existingSurveyId == null) {
      onSurveyCreated?.call(surveyId);
    }
    if (_submitFailsOnce && _submitCount == 1) {
      throw Exception('first submit fails');
    }

    // Idempotent: if a report already exists for this surveyId, return it.
    if (_reportsBySurveyId.containsKey(surveyId)) {
      return _reportsBySurveyId[surveyId]!;
    }

    final report = _latestReport ??
        CcReportFull(
          id: 'fake-report-id',
          surveyId: surveyId,
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
    _reportsBySurveyId[surveyId] = report;
    return report;
  }

  @override
  Future<CcReportFull?> getReport(String reportId) async =>
      _reports[reportId];

  @override
  Future<CcReportFull?> getLatestReportFull() async => _latestReport;

  // Reports list (for survey history)
  List<CcReportSummary> _reportSummaries = [];
  Exception? _myReportsError;

  void seedReportSummaries(List<CcReportSummary> summaries) =>
      _reportSummaries = List.of(summaries);

  void setMyReportsError(Exception? e) => _myReportsError = e;

  @override
  Future<List<CcReportSummary>> getMyReports() async {
    if (_myReportsError != null) throw _myReportsError!;
    return List.unmodifiable(_reportSummaries);
  }

  @override
  Future<List<CcNarrative>> getNarratives() async {
    if (_narrativesFails) throw Exception('forced narrative failure');
    return List.unmodifiable(_narratives);
  }

  @override
  Future<List<ActionPlanPhase>> getActionPlan(SurveyType type) async {
    final sorted = List.of(_actionPlan)..sort((a, b) => a.day.compareTo(b.day));
    return List.unmodifiable(sorted);
  }

  @override
  Future<Map<String, bool>> getActionProgress() async =>
      Map.of(_actionProgress);

  @override
  Future<void> toggleTask(String taskId, bool completed) async {
    if (_toggleShouldFail) throw Exception('toggleTask failed');
    toggleTaskCalls.add((taskId, completed));
    _actionProgress[taskId] = completed;
  }

  @override
  Future<TtsResult> tts(String text, String language) async {
    ttsCalls.add((text, language));
    return _ttsResult;
  }

  // --- Layer sub-scores ---
  final Map<String, List<SubComponentScore>> _layerSubScores = {};

  void seedLayerSubScores(String layer, List<SubComponentScore> scores) {
    _layerSubScores[layer] = scores;
  }

  @override
  Future<List<SubComponentScore>> getLayerSubScores(
      String surveyId, String layer) async {
    return List.unmodifiable(_layerSubScores[layer] ?? []);
  }

  // --- ESI pillar scores ---
  Map<String, double> _esiPillarScores = {};

  void seedEsiPillarScores(Map<String, double> scores) {
    _esiPillarScores = Map.of(scores);
  }

  @override
  Future<Map<String, double>> getEsiPillarScores(String surveyId) async {
    return Map.unmodifiable(_esiPillarScores);
  }
}
