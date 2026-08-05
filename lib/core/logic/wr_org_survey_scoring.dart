// Tính điểm Khảo sát tổ chức. Thuần, không chạm Supabase — để test được mà
// không cần mạng.
//
// Máy chủ cũng tính bốn số trung bình này (trigger `wr_org_survey_compute_avgs`).
// Có hai chỗ tính KHÔNG phải trùng lặp thừa: máy chủ tính để gộp benchmark cho
// mọi người, còn ở đây tính để hiện kết quả NGAY sau khi bấm xong câu cuối,
// không phải chờ một vòng đọc lại. Cả hai phải cho cùng một con số, nên luật
// loại câu trả lời ngoài thang 0..4 được viết giống hệt ở hai nơi.

import '../models/wr_org_survey.dart';

/// Khoảng coi là "ngang mặt bằng chung", tính theo phần trăm.
///
/// Lấy từ mockup (`minePct > benchPct + 3` / `< benchPct - 3`). Không có dải
/// này thì chênh 1% cũng bị tuyên là "cao hơn mặt bằng chung" — một khẳng định
/// mạnh dựng trên một khác biệt không có nghĩa gì.
const int kOrgSurveyEqualBandPct = 3;

/// Số người tối thiểu để bản so sánh được tính từ dữ liệu thật.
/// Phải khớp tham số mặc định của RPC `wr_org_survey_benchmark`.
const int kOrgSurveyMinSample = 30;

/// Trung bình của [area] theo [answers], chỉ tính trên câu đã trả lời.
///
/// Trả về null khi mảng đó chưa có câu nào — KHÔNG trả về 0. Người bỏ qua cả
/// mảng Đãi ngộ mà bị vẽ vạch sát đáy là bị nói sai về mình.
double? orgSurveyAreaAverage(
  Map<String, int> answers,
  List<OrgSurveyQuestion> questions,
  OrgSurveyArea area,
) {
  var sum = 0;
  var n = 0;
  for (final q in questions) {
    if (q.area != area) continue;
    final v = answers[q.id];
    if (v == null || v < 0 || v > kOrgSurveyMaxScore) continue;
    sum += v;
    n++;
  }
  return n == 0 ? null : sum / n;
}

/// Trung bình cả bốn mảng. Mảng chưa trả lời câu nào thì vắng mặt.
Map<OrgSurveyArea, double> orgSurveyAreaAverages(
  Map<String, int> answers,
  List<OrgSurveyQuestion> questions,
) {
  final out = <OrgSurveyArea, double>{};
  for (final area in OrgSurveyArea.values) {
    final avg = orgSurveyAreaAverage(answers, questions, area);
    if (avg != null) out[area] = avg;
  }
  return out;
}

/// Đổi điểm sang phần trăm chiều dài vạch, làm tròn như mockup.
int orgSurveyPercent(double value, {int max = kOrgSurveyMaxScore}) {
  if (max <= 0) return 0;
  final pct = (value / max * 100).round();
  return pct.clamp(0, 100);
}

/// Kết quả so sánh một mảng với mặt bằng chung.
enum OrgSurveyStanding {
  above('Cao hơn mặt bằng chung'),
  equal('Ngang mặt bằng chung'),
  below('Thấp hơn mặt bằng chung'),

  /// Người dùng chưa trả lời mảng này.
  unanswered('Chưa trả lời'),

  /// Có câu trả lời của người dùng, nhưng chưa có mặt bằng chung để đối chiếu.
  noBenchmark('Chưa đủ dữ liệu để so sánh');

  const OrgSurveyStanding(this.label);

  final String label;
}

/// So [mine] với [benchmark] trên cùng một thang [max].
///
/// So bằng PHẦN TRĂM chứ không bằng điểm thô, giống mockup: đó là chính con số
/// quyết định chiều dài hai vạch, nên nhãn chữ không bao giờ nói ngược với thứ
/// mắt đang nhìn thấy.
OrgSurveyStanding orgSurveyStanding({
  required double? mine,
  required double? benchmark,
  int max = kOrgSurveyMaxScore,
}) {
  if (mine == null) return OrgSurveyStanding.unanswered;
  if (benchmark == null) return OrgSurveyStanding.noBenchmark;

  final minePct = orgSurveyPercent(mine, max: max);
  final benchPct = orgSurveyPercent(benchmark, max: max);
  if (minePct > benchPct + kOrgSurveyEqualBandPct) {
    return OrgSurveyStanding.above;
  }
  if (minePct < benchPct - kOrgSurveyEqualBandPct) {
    return OrgSurveyStanding.below;
  }
  return OrgSurveyStanding.equal;
}

/// Đã trả lời được bao nhiêu trên tổng số câu, tính cả câu eNPS.
int orgSurveyAnsweredCount({
  required Map<String, int> answers,
  required List<OrgSurveyQuestion> questions,
  required int? enps,
}) {
  var n = questions.where((q) => answers.containsKey(q.id)).length;
  if (enps != null) n++;
  return n;
}
