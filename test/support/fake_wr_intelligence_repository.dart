import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';

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
  final List<GrowthOpportunity> _growthOpportunities = [];
  final List<PracticeStepNote> _stepNotes = [];

  Object? nextError;

  // --- Call recorders ---
  final List<ReflectionStep> insertReflectionStepCalls = [];
  final List<ScaSelfCheckResponse> insertSelfCheckResponseCalls = [];
  final List<WrInsight> insertInsightCalls = [];
  final List<PracticeEnrollment> enrollThemeCalls = [];
  final List<({String userId, String themeId, List<String> completedSteps})>
      updateEnrollmentStepsCalls = [];
  final List<GrowthOpportunity> insertGrowthOpportunityCalls = [];
  final List<PracticeStepNote> upsertPracticeStepNoteCalls = [];
  final List<CareerQuestion> insertCareerQuestionCalls = [];
  final List<({String userId, String themeId})> completeThemeCalls = [];
  final List<WrContextDocument> insertContextDocumentCalls = [];
  final List<({String userId, String situationCode, String scaDimensionDb})>
      recordSituationOccurrenceCalls = [];
  final List<({String userId, String situationCode})>
      decrementSituationOccurrenceCalls = [];

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
  Future<void> decrementSituationOccurrence({
    required String userId,
    required String situationCode,
  }) async {
    _maybeThrow();
    decrementSituationOccurrenceCalls.add((
      userId: userId,
      situationCode: situationCode,
    ));
    final idx = _patternCounts.indexWhere(
      (p) => p.userId == userId && p.situationCode == situationCode,
    );
    if (idx < 0) return;
    final existing = _patternCounts[idx];
    if (existing.occurrenceCount > 1) {
      _patternCounts[idx] = PatternCount(
        id: existing.id,
        userId: userId,
        situationCode: situationCode,
        scaDimension: existing.scaDimension,
        occurrenceCount: existing.occurrenceCount - 1,
        lastSeenAt: existing.lastSeenAt,
      );
    } else {
      _patternCounts.removeAt(idx);
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
    _assertInsightConstraints(i);
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
  Future<void> updateEnrollmentSteps({
    required String userId,
    required String themeId,
    required List<String> completedSteps,
  }) async {
    _maybeThrow();
    updateEnrollmentStepsCalls.add((
      userId: userId,
      themeId: themeId,
      completedSteps: completedSteps,
    ));
    final idx = _enrollments.indexWhere(
      (e) => e.userId == userId && e.themeId == themeId,
    );
    if (idx >= 0) {
      _enrollments[idx] = _enrollments[idx].copyWith(completedSteps: completedSteps);
    }
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
        completedSteps: e.completedSteps,
      );
    }
  }

  @override
  Future<String?> insertContextDocument(WrContextDocument d) async {
    _maybeThrow();
    insertContextDocumentCalls.add(d);
    final id = d.id ?? 'doc-${_contextDocuments.length + 1}';
    _contextDocuments.add(WrContextDocument(
      id: id,
      userId: d.userId,
      docType: d.docType,
      filePath: d.filePath,
      uploadedAt: d.uploadedAt ?? DateTime.now(),
      analysisStatus: d.analysisStatus,
    ));
    return id;
  }

  /// Kết quả `analyzeContextDocument` sẽ trả về. Chưa gieo thì fake tự dựng một
  /// bản phân tích tối thiểu — đủ để màn hình đổi trạng thái sang "Đã đọc".
  WrDocAnalysis? nextAnalysis;

  /// Lỗi ném ra ở lần gọi phân tích kế tiếp, ném một lần rồi tự xoá.
  Object? nextAnalysisError;

  final List<String> analyzeContextDocumentCalls = [];

  @override
  Future<WrContextDocument> analyzeContextDocument(String documentId) async {
    analyzeContextDocumentCalls.add(documentId);
    if (nextAnalysisError != null) {
      final err = nextAnalysisError!;
      nextAnalysisError = null;
      // ignore: only_throw_errors
      throw err;
    }
    final i = _contextDocuments.indexWhere((d) => d.id == documentId);
    if (i < 0) {
      throw const WrDocAnalysisException('Không tìm thấy tài liệu này.');
    }
    final old = _contextDocuments[i];
    final analysis = nextAnalysis ??
        const WrDocAnalysis(
          title: 'Chuyên viên nhân sự',
          summary: 'Tuyển dụng và đào tạo nhân sự.',
          responsibilities: ['Tuyển dụng nhân sự mới'],
          pillars: {'S': 1, 'C': 4, 'A': 1},
        );
    final updated = WrContextDocument(
      id: old.id,
      userId: old.userId,
      docType: old.docType,
      filePath: old.filePath,
      uploadedAt: old.uploadedAt,
      analysisStatus: DocAnalysisStatus.ready,
      extractedText: 'Chữ đọc được từ tài liệu.',
      analysis: analysis,
      analyzedAt: DateTime.now(),
    );
    _contextDocuments[i] = updated;
    return updated;
  }

  @override
  Future<void> deleteContextDocument(WrContextDocument doc) async {
    _maybeThrow();
    _contextDocuments.removeWhere(
      (d) => d.id == doc.id && d.filePath == doc.filePath,
    );
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

  // --- Hai Lớp v1.6 ---

  void seedGrowthOpportunity(GrowthOpportunity o) => _growthOpportunities.add(o);

  @override
  Future<GrowthOpportunity?> fetchLatestGrowthOpportunity(String userId) async {
    _maybeThrow();
    final mine = _growthOpportunities.where((o) => o.userId == userId).toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return mine.isEmpty ? null : mine.first;
  }

  @override
  Future<void> insertGrowthOpportunity(GrowthOpportunity opportunity) async {
    _maybeThrow();
    insertGrowthOpportunityCalls.add(opportunity);
    _growthOpportunities.add(opportunity);
  }

  @override
  Future<String?> upsertPracticeStepNote(PracticeStepNote note) async {
    _maybeThrow();
    upsertPracticeStepNoteCalls.add(note);
    // Một bước chỉ giữ một ghi chú — ghi lại thì đè lên, giống unique
    // (user_id, step_id) ở DB.
    _stepNotes.removeWhere(
      (n) => n.userId == note.userId && n.stepId == note.stepId,
    );
    final id = 'note-${_stepNotes.length + 1}';
    _stepNotes.add(PracticeStepNote(
      id: id,
      userId: note.userId,
      stepId: note.stepId,
      note: note.note,
      memoryEventId: note.memoryEventId,
    ));
    return id;
  }

  List<PracticeStepNote> get stepNotes => List.unmodifiable(_stepNotes);

  // --- Câu hỏi nghề nghiệp (họp khách 2026-07-29) ---

  final List<CareerQuestion> _careerQuestions = [];

  /// Seed câu hỏi đã có sẵn, mới nhất trước như DB trả về.
  void seedCareerQuestions(List<CareerQuestion> questions) {
    _careerQuestions
      ..clear()
      ..addAll(questions);
  }

  @override
  Future<void> insertCareerQuestion(CareerQuestion question) async {
    _maybeThrow();
    insertCareerQuestionCalls.add(question);
    // Chèn lên đầu: DB sắp theo created_at giảm dần, fake phải cho ra cùng thứ
    // tự thì test mới nói được điều gì về màn hình thật.
    _careerQuestions.insert(
      0,
      CareerQuestion(
        id: 'q-${_careerQuestions.length + 1}',
        userId: question.userId,
        question: question.question,
        createdAt: DateTime(2026, 7, 29),
      ),
    );
  }

  @override
  Future<List<CareerQuestion>> fetchCareerQuestions(String userId) async {
    _maybeThrow();
    return _careerQuestions.where((q) => q.userId == userId).toList();
  }
}

// ---------------------------------------------------------------------------
// Ràng buộc của DB, chép lại ở fake
// ---------------------------------------------------------------------------

/// Giá trị `source` mà `wr_reflection_insights` chấp nhận.
///
/// Giữ khớp với check constraint trong
/// `supabase/migrations/20260728000005_wr_insights_episode_source.sql`.
const Set<String> kAllowedInsightSources = {
  'story',
  'self_check',
  'pattern',
  'episode',
};

/// Chiều SCA mà các bảng WR chấp nhận, kể cả hai nhóm tích cực của v1.6 §2.2.
const Set<String> kAllowedScaDimensions = {
  'S1', 'S2', 'S3',
  'C1', 'C2', 'C3',
  'A1', 'A2', 'A3', 'A4',
  'P-ACHIEVE', 'P-STEADY',
};

/// Ném khi payload vi phạm check constraint, đúng như Postgres sẽ làm.
///
/// Vì sao fake phải biết ràng buộc này: ngày 2026-07-28 luồng Episode ghi
/// `source = 'episode'` trong khi constraint chỉ cho ba giá trị cũ. Mọi lần xác
/// nhận Ý nghĩa đều bị Supabase trả 400, nhưng 1377 test vẫn xanh vì fake nhận
/// tuốt. Lỗi chỉ lộ khi chạy thật trên trình duyệt. Fake nhận mọi thứ thì test
/// không còn nói được gì về việc app có ghi được xuống DB thật hay không.
void _assertInsightConstraints(WrInsight i) {
  final source = i.source;
  if (source != null && !kAllowedInsightSources.contains(source)) {
    throw StateError(
      'wr_reflection_insights_source_check: "$source" không nằm trong '
      '$kAllowedInsightSources',
    );
  }

  final dim = i.scaDimension?.dbValue;
  if (dim != null && !kAllowedScaDimensions.contains(dim)) {
    throw StateError(
      'wr_reflection_insights_sca_dimension_check: "$dim" không nằm trong '
      '$kAllowedScaDimensions',
    );
  }
}
