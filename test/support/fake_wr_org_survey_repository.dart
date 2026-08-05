// Repo giả cho Khảo sát tổ chức.
//
// Giữ được cả những trạng thái mà bản thật gặp nhưng test hay quên: chưa đủ mẫu
// để so sánh, đọc hỏng, và người dùng ngừng tham gia.

import 'package:workreflection_mobile/core/data/wr_org_survey_repository.dart';
import 'package:workreflection_mobile/core/models/wr_org_survey.dart';

class FakeWrOrgSurveyRepository implements WrOrgSurveyRepository {
  FakeWrOrgSurveyRepository({
    List<OrgSurveyQuestion>? questions,
    this.latest,
    List<OrgSurveyBenchmark>? benchmark,
    this.failQuestions = false,
    this.failSubmit = false,
  })  : questions = questions ?? defaultQuestions,
        benchmark = benchmark ?? noBenchmark;

  List<OrgSurveyQuestion> questions;
  OrgSurveyResponse? latest;
  List<OrgSurveyBenchmark> benchmark;
  bool failQuestions;
  bool failSubmit;

  /// Ghi lại lần gửi gần nhất để test kiểm được app gửi đúng cái gì lên.
  Map<String, int>? submittedAnswers;
  int? submittedEnps;
  int withdrawCount = 0;

  static final defaultQuestions = [
    for (final (i, area) in [
      OrgSurveyArea.compensation,
      OrgSurveyArea.compensation,
      OrgSurveyArea.growth,
      OrgSurveyArea.fairness,
      OrgSurveyArea.support,
    ].indexed)
      OrgSurveyQuestion(
        id: 'OS-0${i + 1}',
        area: area,
        text: 'Câu hỏi số ${i + 1} về ${area.label.toLowerCase()}.',
        sortOrder: i + 1,
      ),
  ];

  /// Chưa đủ mẫu và cũng chưa có số tham chiếu — trạng thái lúc mới ra mắt.
  static const noBenchmark = <OrgSurveyBenchmark>[
    OrgSurveyBenchmark(
      area: OrgSurveyArea.compensation,
      source: BenchmarkSource.none,
      sampleSize: 2,
    ),
    OrgSurveyBenchmark(
      area: OrgSurveyArea.growth,
      source: BenchmarkSource.none,
      sampleSize: 2,
    ),
    OrgSurveyBenchmark(
      area: OrgSurveyArea.fairness,
      source: BenchmarkSource.none,
      sampleSize: 2,
    ),
    OrgSurveyBenchmark(
      area: OrgSurveyArea.support,
      source: BenchmarkSource.none,
      sampleSize: 2,
    ),
    OrgSurveyBenchmark(
      area: null,
      source: BenchmarkSource.none,
      sampleSize: 2,
    ),
  ];

  static const liveBenchmark = <OrgSurveyBenchmark>[
    OrgSurveyBenchmark(
      area: OrgSurveyArea.compensation,
      value: 2.1,
      source: BenchmarkSource.live,
      sampleSize: 120,
    ),
    OrgSurveyBenchmark(
      area: OrgSurveyArea.growth,
      value: 2.6,
      source: BenchmarkSource.live,
      sampleSize: 120,
    ),
    OrgSurveyBenchmark(
      area: OrgSurveyArea.fairness,
      value: 2.4,
      source: BenchmarkSource.live,
      sampleSize: 120,
    ),
    OrgSurveyBenchmark(
      area: OrgSurveyArea.support,
      value: 2.8,
      source: BenchmarkSource.live,
      sampleSize: 120,
    ),
    OrgSurveyBenchmark(
      area: null,
      value: 6.4,
      source: BenchmarkSource.live,
      sampleSize: 120,
    ),
  ];

  @override
  Future<List<OrgSurveyQuestion>> fetchQuestions() async {
    if (failQuestions) throw StateError('boom');
    return questions;
  }

  @override
  Future<OrgSurveyResponse?> fetchLatestResponse() async => latest;

  @override
  Future<List<OrgSurveyBenchmark>> fetchBenchmark() async => benchmark;

  @override
  Future<OrgSurveyResponse> submit({
    required Map<String, int> answers,
    int? enps,
  }) async {
    if (failSubmit) throw StateError('boom');
    submittedAnswers = Map.of(answers);
    submittedEnps = enps;

    // Bản thật để máy chủ tính bốn số trung bình. Ở đây tính bằng cùng một luật
    // để màn kết quả nhận được thứ có hình dạng giống hệt bản thật.
    final averages = <OrgSurveyArea, double>{};
    for (final area in OrgSurveyArea.values) {
      final qs = questions.where((q) => q.area == area);
      final vals = qs
          .map((q) => answers[q.id])
          .whereType<int>()
          .where((v) => v >= 0 && v <= kOrgSurveyMaxScore)
          .toList();
      if (vals.isNotEmpty) {
        averages[area] = vals.reduce((a, b) => a + b) / vals.length;
      }
    }

    latest = OrgSurveyResponse(
      id: 'r1',
      answers: Map.of(answers),
      enps: enps,
      areaAverages: averages,
      createdAt: DateTime(2026, 8, 5),
    );
    return latest!;
  }

  @override
  Future<void> withdraw() async {
    withdrawCount++;
    latest = null;
  }
}
