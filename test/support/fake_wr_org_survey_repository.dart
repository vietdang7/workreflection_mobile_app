// Repo giả cho Khảo sát tổ chức.
//
// Giữ được cả những trạng thái mà bản thật gặp nhưng test hay quên: chưa đủ mẫu
// để so sánh, đọc hỏng, và người dùng ngừng tham gia.

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:workreflection_mobile/core/data/wr_org_survey_repository.dart';
import 'package:workreflection_mobile/core/models/wr_org_survey.dart';

/// Mã lĩnh vực hợp lệ: chép từ CHECK của cột `wr_org_survey_responses.industry`.
const fakeOrgSurveyIndustries = {
  'tech',
  'finance',
  'manufacturing',
  'retail',
  'education',
  'healthcare',
  'construction',
  'other',
};

/// Ngưỡng cứng của RPC `wr_org_survey_benchmark_v2` (cfg min_sample).
const fakeOrgSurveyMinSample = 10;

/// Một phiếu của một người nào đó trong bảng `wr_org_survey_responses`.
class FakeSurveyRow {
  const FakeSurveyRow({
    required this.userId,
    required this.createdAt,
    this.areaAverages = const {},
    this.enps,
    this.industry,
  });

  final String userId;
  final DateTime createdAt;
  final Map<OrgSurveyArea, double> areaAverages;
  final int? enps;
  final String? industry;
}

class FakeWrOrgSurveyRepository implements WrOrgSurveyRepository {
  FakeWrOrgSurveyRepository({
    List<OrgSurveyQuestion>? questions,
    this.latest,
    List<OrgSurveyBenchmark>? benchmark,
    this.failQuestions = false,
    this.failSubmit = false,
    this.failBenchmark = false,
    List<FakeSurveyRow>? rows,
    Map<OrgSurveyArea?, double>? reference,
  }) : questions = questions ?? defaultQuestions,
       benchmark = benchmark ?? noBenchmark,
       cannedBenchmark = benchmark != null,
       rows = rows ?? [],
       reference = reference ?? const {};

  List<OrgSurveyQuestion> questions;
  OrgSurveyResponse? latest;
  List<OrgSurveyBenchmark> benchmark;
  bool failQuestions;
  bool failSubmit;
  bool failBenchmark;

  /// Khi true, [benchmark] là danh sách dựng sẵn (các test màn hình cũ). Khi
  /// false, mặt bằng chung được TÍNH từ [rows] đúng luật của RPC v2.
  final bool cannedBenchmark;

  /// Toàn bộ bảng phiếu của mọi người, kể cả phiếu người dùng hiện tại nộp.
  final List<FakeSurveyRow> rows;

  /// Bảng `wr_org_survey_reference`: chỉ phạm vi `all` được rơi về đây.
  final Map<OrgSurveyArea?, double> reference;

  /// Id người dùng hiện tại trong [rows].
  static const currentUserId = 'me';

  /// Ghi lại lần gửi gần nhất để test kiểm được app gửi đúng cái gì lên.
  Map<String, int>? submittedAnswers;
  int? submittedEnps;
  String? submittedIndustry;
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
    OrgSurveyBenchmark(area: null, source: BenchmarkSource.none, sampleSize: 2),
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
  Future<List<OrgSurveyBenchmark>> fetchBenchmark({String? industry}) async {
    if (failBenchmark) throw StateError('boom');
    if (cannedBenchmark) return benchmark;
    return _computeBenchmark(industry);
  }

  /// Chép luật SQL của `wr_org_survey_benchmark_v2`.
  List<OrgSurveyBenchmark> _computeBenchmark(String? industry) {
    // Một người một phiếu: phiếu mới nhất theo created_at.
    final latestByUser = <String, FakeSurveyRow>{};
    for (final r in rows) {
      final cur = latestByUser[r.userId];
      if (cur == null || r.createdAt.isAfter(cur.createdAt)) {
        latestByUser[r.userId] = r;
      }
    }
    final latestRows = latestByUser.values.toList();

    final out = <OrgSurveyBenchmark>[];
    for (final scope in [
      BenchmarkScope.all,
      if (industry != null) BenchmarkScope.industry,
    ]) {
      final scoped = scope == BenchmarkScope.all
          ? latestRows
          : latestRows.where((r) => r.industry == industry).toList();
      for (final area in [...OrgSurveyArea.values, null]) {
        final vals = <double>[
          for (final r in scoped)
            if (area == null)
              if (r.enps != null) r.enps!.toDouble() else ...const <double>[]
            else if (r.areaAverages[area] != null)
              r.areaAverages[area]!,
        ];
        final n = vals.length;
        double? avg() =>
            double.parse((vals.reduce((a, b) => a + b) / n).toStringAsFixed(2));
        if (n >= fakeOrgSurveyMinSample) {
          out.add(
            OrgSurveyBenchmark(
              scope: scope,
              area: area,
              value: avg(),
              sampleSize: n,
              source: BenchmarkSource.live,
            ),
          );
        } else if (scope == BenchmarkScope.all && reference[area] != null) {
          out.add(
            OrgSurveyBenchmark(
              scope: scope,
              area: area,
              value: reference[area],
              sampleSize: n,
              source: BenchmarkSource.reference,
            ),
          );
        } else {
          out.add(
            OrgSurveyBenchmark(
              scope: scope,
              area: area,
              sampleSize: n,
              source: BenchmarkSource.none,
            ),
          );
        }
      }
    }
    return out;
  }

  @override
  Future<OrgSurveyResponse> submit({
    required Map<String, int> answers,
    int? enps,
    String? industry,
  }) async {
    if (failSubmit) throw StateError('boom');
    // Chép CHECK của cột `industry`: sai mã thì bản thật trả 400 (23514).
    if (industry != null && !fakeOrgSurveyIndustries.contains(industry)) {
      throw PostgrestException(
        message:
            'new row for relation "wr_org_survey_responses" violates check '
            'constraint "wr_org_survey_responses_industry_check"',
        code: '23514',
      );
    }
    submittedAnswers = Map.of(answers);
    submittedEnps = enps;
    submittedIndustry = industry;

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
      industry: industry,
      createdAt: DateTime(2026, 8, 5),
    );
    rows.add(
      FakeSurveyRow(
        userId: currentUserId,
        createdAt: DateTime.now(),
        areaAverages: averages,
        enps: enps,
        industry: industry,
      ),
    );
    return latest!;
  }

  @override
  Future<void> withdraw() async {
    withdrawCount++;
    latest = null;
  }
}
