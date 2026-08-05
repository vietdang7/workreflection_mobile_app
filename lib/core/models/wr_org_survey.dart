// Khảo sát tổ chức (ESI + eNPS) — mockup Sprint 2, màn Hồ sơ.
//
// Bài này CỐ Ý không dính vào Reflection: màn giới thiệu hứa với người dùng
// "Hoàn toàn không ảnh hưởng đến Reflection, Insight hay Career Memory cá nhân
// của bạn", nên không model nào ở đây được tham chiếu Episode, Insight hay
// Career Memory.
//
// Đừng nhầm với `SurveyLayer.esi` trong `survey_models.dart`: đó là một tầng
// của bộ khảo sát SCA bên web, chảy vào báo cáo cá nhân. Hai thứ khác nhau,
// khác cả bảng lẫn mục đích.

/// Bốn mảng của Khảo sát tổ chức.
enum OrgSurveyArea {
  compensation('compensation', 'Đãi ngộ'),
  growth('growth', 'Phát triển'),
  fairness('fairness', 'Công bằng'),
  support('support', 'Hỗ trợ');

  const OrgSurveyArea(this.code, this.label);

  /// Mã dùng ở tầng dữ liệu. Không bao giờ hiện ra màn hình.
  final String code;

  /// Nhãn tiếng Việt hiện trên bản so sánh.
  final String label;

  static OrgSurveyArea? fromCode(String? code) {
    for (final a in OrgSurveyArea.values) {
      if (a.code == code) return a;
    }
    return null;
  }
}

/// Thang 5 mức hài lòng. Chỉ số 0..4, đúng thứ tự hiện trên màn hình.
const List<String> kOrgSurveyScale = [
  'Hoàn toàn không hài lòng',
  'Không hài lòng',
  'Bình thường',
  'Hài lòng',
  'Hoàn toàn hài lòng',
];

/// Giá trị lớn nhất của thang hài lòng (4 = chỉ số cuối của [kOrgSurveyScale]).
const int kOrgSurveyMaxScore = 4;

/// Giá trị lớn nhất của thang eNPS.
const int kEnpsMaxScore = 10;

class OrgSurveyQuestion {
  const OrgSurveyQuestion({
    required this.id,
    required this.area,
    required this.text,
    required this.sortOrder,
  });

  final String id;
  final OrgSurveyArea area;
  final String text;
  final int sortOrder;

  static OrgSurveyQuestion? fromJson(Map<String, dynamic> json) {
    final area = OrgSurveyArea.fromCode(json['area'] as String?);
    // Mảng lạ nghĩa là bảng câu hỏi đã đi trước app một bước. Bỏ câu đó còn hơn
    // đếm nó vào một mảng bừa: người dùng sẽ trả lời một câu rồi thấy nó ảnh
    // hưởng tới đúng cái ô mà nó không thuộc về.
    if (area == null) return null;
    return OrgSurveyQuestion(
      id: json['id'] as String,
      area: area,
      text: json['text'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Một lần đã làm khảo sát.
class OrgSurveyResponse {
  const OrgSurveyResponse({
    required this.id,
    required this.answers,
    required this.createdAt,
    this.enps,
    this.areaAverages = const {},
  });

  final String id;

  /// `{question_id: 0..4}`.
  final Map<String, int> answers;

  /// Null khi người dùng thoát trước câu cuối.
  final int? enps;

  /// Trung bình mỗi mảng, do máy chủ tính. Mảng chưa trả lời câu nào thì vắng
  /// mặt trong map chứ không phải bằng 0 — "chưa trả lời" và "hoàn toàn không
  /// hài lòng" là hai chuyện rất khác nhau.
  final Map<OrgSurveyArea, double> areaAverages;

  final DateTime createdAt;

  factory OrgSurveyResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['answers'] as Map?) ?? const {};
    final answers = <String, int>{};
    for (final e in raw.entries) {
      final v = e.value;
      final n = v is num ? v.toInt() : int.tryParse('$v');
      if (n != null) answers['${e.key}'] = n;
    }

    final averages = <OrgSurveyArea, double>{};
    for (final area in OrgSurveyArea.values) {
      final v = json['avg_${area.code}'] as num?;
      if (v != null) averages[area] = v.toDouble();
    }

    return OrgSurveyResponse(
      id: json['id'] as String,
      answers: answers,
      enps: (json['enps'] as num?)?.toInt(),
      areaAverages: averages,
      createdAt:
          DateTime.tryParse('${json['created_at']}')?.toLocal() ?? DateTime.now(),
    );
  }
}

/// Nguồn của con số mặt bằng chung.
enum BenchmarkSource {
  /// Tính thật từ câu trả lời của đủ số người.
  live,

  /// Số tham chiếu ngành do người vận hành nhập, chưa đủ mẫu thật.
  reference,

  /// Chưa có gì để so sánh. Màn kết quả không được vẽ vạch so sánh.
  none,
}

/// Một dòng mặt bằng chung: bốn mảng dùng [OrgSurveyArea], eNPS có dòng riêng
/// với `area == null`.
class OrgSurveyBenchmark {
  const OrgSurveyBenchmark({
    required this.area,
    required this.source,
    required this.sampleSize,
    this.value,
  });

  /// Null nghĩa là dòng eNPS.
  final OrgSurveyArea? area;

  /// Null khi [source] là [BenchmarkSource.none].
  final double? value;

  final BenchmarkSource source;

  /// Số người đã trả lời phần này. Luôn là số thật, kể cả khi [value] đang lấy
  /// từ số tham chiếu — nếu không, không ai biết mẫu thật đang ở đâu.
  final int sampleSize;

  bool get isComparable => value != null && source != BenchmarkSource.none;

  factory OrgSurveyBenchmark.fromJson(Map<String, dynamic> json) {
    final code = json['area'] as String?;
    return OrgSurveyBenchmark(
      area: OrgSurveyArea.fromCode(code),
      value: (json['avg_value'] as num?)?.toDouble(),
      sampleSize: (json['sample_size'] as num?)?.toInt() ?? 0,
      source: switch (json['source'] as String?) {
        'live' => BenchmarkSource.live,
        'reference' => BenchmarkSource.reference,
        _ => BenchmarkSource.none,
      },
    );
  }
}
