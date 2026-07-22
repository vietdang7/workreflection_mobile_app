import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

/// In-memory fake WrIntelligenceRepository for unit/widget tests.
///
/// Pre-populate via seed* methods. Inspect via *Calls fields.
/// Set [nextError] before a call to simulate errors (thrown once then cleared).
class FakeWrIntelligenceRepository implements WrIntelligenceRepository {
  // --- State ---
  WrEntitlementRecord? _entitlement;
  final List<PatternCount> _patternCounts = [];
  final List<ReflectionStep> _reflectionSteps = [];
  final List<ScaSelfCheckResponse> _selfCheckHistory = [];
  final List<WrInsight> _insights = [];
  final List<PracticeTheme> _practiceThemes = [];
  final Map<String, List<PracticeStep>> _practiceSteps = {};
  final List<PracticeEnrollment> _enrollments = [];
  final List<WrContextDocument> _contextDocuments = [];
  final List<PatternNarrative> _patternNarratives = [];
  final List<GrowthJourneySnapshot> _growthSnapshots = [];

  Object? nextError;

  // --- Call recorders ---
  final List<ReflectionStep> insertReflectionStepCalls = [];
  final List<ScaSelfCheckResponse> insertSelfCheckResponseCalls = [];
  final List<WrInsight> insertInsightCalls = [];
  final List<PracticeEnrollment> enrollThemeCalls = [];
  final List<({String userId, String themeId})> completeThemeCalls = [];
  final List<WrContextDocument> insertContextDocumentCalls = [];
  final List<({String userId, String situationCode, String scaDimensionDb})>
      recordSituationOccurrenceCalls = [];

  // --- Seed helpers ---
  void seedEntitlement(WrEntitlementRecord? r) => _entitlement = r;
  void seedPatternCounts(List<PatternCount> counts) {
    _patternCounts
      ..clear()
      ..addAll(counts);
  }

  void seedSelfCheckHistory(List<ScaSelfCheckResponse> history) {
    _selfCheckHistory
      ..clear()
      ..addAll(history);
  }

  void seedInsights(List<WrInsight> insights) {
    _insights
      ..clear()
      ..addAll(insights);
  }

  void seedPracticeThemes(List<PracticeTheme> themes) {
    _practiceThemes
      ..clear()
      ..addAll(themes);
  }

  void seedPracticeSteps(String themeId, List<PracticeStep> steps) {
    _practiceSteps[themeId] = List.of(steps);
  }

  void seedEnrollments(List<PracticeEnrollment> enrollments) {
    _enrollments
      ..clear()
      ..addAll(enrollments);
  }

  void seedContextDocuments(List<WrContextDocument> docs) {
    _contextDocuments
      ..clear()
      ..addAll(docs);
  }

  void seedPatternNarratives(List<PatternNarrative> narratives) {
    _patternNarratives
      ..clear()
      ..addAll(narratives);
  }

  void seedGrowthSnapshots(List<GrowthJourneySnapshot> snapshots) {
    _growthSnapshots
      ..clear()
      ..addAll(snapshots);
  }

  void _maybeThrow() {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      // ignore: only_throw_errors
      throw err;
    }
  }

  // --- Implementations ---

  @override
  Future<WrEntitlementRecord?> fetchEntitlement(String userId) async {
    _maybeThrow();
    return _entitlement;
  }

  @override
  Future<List<PatternCount>> fetchPatternCounts(String userId) async {
    _maybeThrow();
    final sorted = List.of(_patternCounts)
      ..sort((a, b) => b.occurrenceCount.compareTo(a.occurrenceCount));
    return List.unmodifiable(sorted);
  }

  @override
  Future<void> recordSituationOccurrence({
    required String userId,
    required String situationCode,
    required String scaDimensionDb,
  }) async {
    _maybeThrow();
    recordSituationOccurrenceCalls.add((
      userId: userId,
      situationCode: situationCode,
      scaDimensionDb: scaDimensionDb,
    ));
    // Upsert logic: find existing by (userId, situationCode)
    final idx = _patternCounts.indexWhere(
      (p) => p.userId == userId && p.situationCode == situationCode,
    );
    if (idx >= 0) {
      final existing = _patternCounts[idx];
      _patternCounts[idx] = PatternCount(
        id: existing.id,
        userId: userId,
        situationCode: situationCode,
        scaDimension: existing.scaDimension,
        occurrenceCount: existing.occurrenceCount + 1,
        lastSeenAt: DateTime.now(),
      );
    } else {
      _patternCounts.add(PatternCount(
        id: null,
        userId: userId,
        situationCode: situationCode,
        scaDimension: null,
        occurrenceCount: 1,
        lastSeenAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> insertReflectionStep(ReflectionStep step) async {
    _maybeThrow();
    insertReflectionStepCalls.add(step);
    _reflectionSteps.add(step);
  }

  @override
  Future<void> insertSelfCheckResponse(ScaSelfCheckResponse r) async {
    _maybeThrow();
    insertSelfCheckResponseCalls.add(r);
    _selfCheckHistory.add(r);
  }

  @override
  Future<List<ScaSelfCheckResponse>> fetchSelfCheckHistory(
    String userId, {
    int? limit,
  }) async {
    _maybeThrow();
    // Newest first — sort by takenAt descending
    final sorted = List.of(_selfCheckHistory)
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final filtered = sorted.where((r) => r.userId == userId).toList();
    if (limit != null && filtered.length > limit) {
      return List.unmodifiable(filtered.sublist(0, limit));
    }
    return List.unmodifiable(filtered);
  }

  @override
  Future<WrInsight?> fetchLatestInsight(String userId) async {
    _maybeThrow();
    final userInsights = _insights.where((i) => i.userId == userId).toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
    if (userInsights.isEmpty) return null;
    return userInsights.first;
  }

  @override
  Future<List<WrInsight>> fetchInsightHistory(String userId) async {
    _maybeThrow();
    final sorted = _insights.where((i) => i.userId == userId).toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
    return List.unmodifiable(sorted);
  }

  @override
  Future<void> insertInsight(WrInsight i) async {
    _maybeThrow();
    insertInsightCalls.add(i);
    _insights.add(i);
  }

  @override
  Future<List<PracticeTheme>> fetchPracticeThemes() async {
    _maybeThrow();
    return List.unmodifiable(_practiceThemes);
  }

  @override
  Future<List<PracticeStep>> fetchPracticeSteps(String themeId) async {
    _maybeThrow();
    final steps = List.of(_practiceSteps[themeId] ?? <PracticeStep>[])
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    return List.unmodifiable(steps);
  }

  @override
  Future<List<PracticeEnrollment>> fetchEnrollments(String userId) async {
    _maybeThrow();
    return List.unmodifiable(
      _enrollments.where((e) => e.userId == userId),
    );
  }

  @override
  Future<void> enrollTheme(PracticeEnrollment e) async {
    _maybeThrow();
    enrollThemeCalls.add(e);
    _enrollments.add(e);
  }

  @override
  Future<void> completeTheme({
    required String userId,
    required String themeId,
  }) async {
    _maybeThrow();
    completeThemeCalls.add((userId: userId, themeId: themeId));
    final idx = _enrollments.indexWhere(
      (e) => e.userId == userId && e.themeId == themeId,
    );
    if (idx >= 0) {
      final e = _enrollments[idx];
      _enrollments[idx] = PracticeEnrollment(
        id: e.id,
        userId: e.userId,
        themeId: e.themeId,
        startedAt: e.startedAt,
        completedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> insertContextDocument(WrContextDocument d) async {
    _maybeThrow();
    insertContextDocumentCalls.add(d);
    _contextDocuments.add(d);
  }

  @override
  Future<List<WrContextDocument>> fetchContextDocuments(String userId) async {
    _maybeThrow();
    return List.unmodifiable(
      _contextDocuments.where((d) => d.userId == userId),
    );
  }

  @override
  Future<List<PatternNarrative>> fetchPatternNarratives(String userId) async {
    _maybeThrow();
    return List.unmodifiable(
      _patternNarratives.where((n) => n.userId == userId),
    );
  }

  @override
  Future<List<GrowthJourneySnapshot>> fetchGrowthSnapshots(String userId) async {
    _maybeThrow();
    return List.unmodifiable(
      _growthSnapshots.where((s) => s.userId == userId),
    );
  }
}
