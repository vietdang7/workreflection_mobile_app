// "Diễn giải sâu & xu hướng" — ba lớp thông tin cho mỗi trụ S / C / A.
//
// Nguồn: WorkReflection_Changelog_20260824.docx §7, mockup v16 `screenScaDeepDive`.
//
//   Lớp 1 — Mức điểm hiện tại: tái dùng đúng nhãn/màu của màn Kết quả Self-Check.
//   Lớp 2 — Xu hướng: so với LẦN SELF-CHECK LIỀN TRƯỚC.
//   Lớp 3 — Đối chiếu Pattern Reflection: so điểm tự đánh giá với tần suất chọn
//           tình huống thuộc trụ đó trong Reflection gần đây.
//
// §7 gọi Lớp 3 là "lớp giá trị nhất": khi một người tự chấm trụ nào đó là ổn
// nhưng chính trụ đó lại là nơi họ quay lại nhiều nhất khi nhìn lại, chênh lệch
// ấy đáng nói hơn bản thân con số.
//
// Nội dung là TEMPLATE GHÉP BIẾN (mức điểm × xu hướng × có/không khớp pattern
// nổi bật), không phải AI sinh tự do — §7 nói rõ để giữ nhất quán giọng văn và
// kiểm soát chi phí. Vì vậy toàn bộ phần này là Dart thuần, test được trực tiếp.
//
// HAI CHỖ CỐ Ý LỆCH SO VỚI MOCKUP, và vì sao:
//
//   · Thang điểm. Mockup chấm Likert 1–4 và chia ba mức (>=3, >=2, còn lại).
//     App chấm Likert 1–5 và màn Kết quả đã có sẵn ba nhãn theo ngưỡng 3.8 /
//     2.5. §7 yêu cầu "tái dùng ĐÚNG logic màu/nhãn của màn Kết quả", nên ở đây
//     dùng ngưỡng của app chứ không bê ngưỡng mockup sang — bê sang là hai màn
//     nói hai mức khác nhau cho cùng một điểm.
//
//   · Cửa sổ pattern. Mockup đếm trên 30 MỤC gần nhất và §7 ghi chú đó là chỗ
//     cần sửa: "Cần lưu kèm timestamp cho mỗi lần Reflection để lọc đúng cửa sổ
//     30 ngày lịch như nội dung hiển thị đang mô tả". Episode đã có `openedAt`
//     nên ở đây lọc theo 30 NGÀY LỊCH thật, đúng như dòng chú thích cuối màn.

import '../models/wr_content.dart';
import '../models/wr_episode.dart';
import '../models/wr_intelligence.dart';
import 'wr_repeated_situations.dart';
import 'wr_self_check_narrative.dart';
import 'wr_self_check_questions.dart';

/// Cửa sổ đối chiếu Pattern, tính bằng NGÀY LỊCH (§7).
const int kScaPatternWindowDays = 30;

/// Chênh lệch điểm dưới mức này thì coi như không đổi (mockup: 0.15).
const double kScaTrendEpsilon = 0.15;

// ---------------------------------------------------------------------------
// Lớp 1 — mức điểm hiện tại
// ---------------------------------------------------------------------------

/// Ba mức của màn Kết quả Self-Check, tách ra để màn Diễn giải sâu dùng chung.
///
/// Trước đây luật này nằm trong `_PillarScoreCard._badge` — private, nên màn
/// thứ hai muốn hiện cùng một nhãn thì chỉ còn cách chép lại ngưỡng. Chép là
/// bắt đầu đếm ngược tới ngày hai màn lệch nhau.
enum ScaPillarStatus {
  developing,
  needsAttention,
  priority;

  String get label => switch (this) {
        ScaPillarStatus.developing => 'Đang phát triển',
        ScaPillarStatus.needsAttention => 'Cần chú ý',
        ScaPillarStatus.priority => 'Ưu tiên cải thiện',
      };

  /// Người dùng đang tự chấm trụ này là ỔN.
  ///
  /// Chỉ mức cao nhất mới tính. "Cần chú ý" nằm giữa thang 1–5 và người tự chấm
  /// như vậy KHÔNG nói rằng mình ổn — gộp nó vào đây thì câu "bạn tự đánh giá
  /// phần này ổn, nhưng…" sẽ bịa lại lời của họ.
  bool get isReassuring => this == ScaPillarStatus.developing;
}

/// Ngưỡng lấy đúng từ màn Kết quả Self-Check.
ScaPillarStatus scaPillarStatus(double score) {
  if (score >= 3.8) return ScaPillarStatus.developing;
  if (score >= 2.5) return ScaPillarStatus.needsAttention;
  return ScaPillarStatus.priority;
}

// ---------------------------------------------------------------------------
// Lớp 2 — xu hướng so với lần Self-Check trước
// ---------------------------------------------------------------------------

/// Điểm của một trụ trong một lần trả lời.
double? scaScoreOf(ScaSelfCheckResponse r, SelfCheckPillar pillar) =>
    switch (pillar) {
      SelfCheckPillar.s => r.structureScore,
      SelfCheckPillar.c => r.cultureScore,
      SelfCheckPillar.a => r.activityScore,
    };

/// Hai lần trả lời gần nhất có đủ điểm, mới nhất đứng đầu.
///
/// Cùng phép lọc với [trendFromHistory] để hai chỗ không bao giờ nói khác nhau
/// về "lần trước là lần nào".
List<ScaSelfCheckResponse> scoredSelfChecks(
  List<ScaSelfCheckResponse> history,
) =>
    history
        .where((r) =>
            r.structureScore != null &&
            r.cultureScore != null &&
            r.activityScore != null)
        .toList()
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));

/// Ngày dạng dd/MM/yyyy — dạng mockup dùng trong câu "so với lần trước (…)".
String scaDateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Câu Lớp 2. Null khi chưa có lần Self-Check nào trước đó để so.
String? scaTrendText({
  required SelfCheckPillar pillar,
  required double score,
  required ScaSelfCheckResponse? previous,
}) {
  if (previous == null) return null;
  final prev = scaScoreOf(previous, pillar);
  if (prev == null) return null;

  final date = scaDateLabel(previous.takenAt);
  final diff = score - prev;
  if (diff.abs() < kScaTrendEpsilon) {
    return 'Gần như không đổi so với lần trước ($date).';
  }
  return diff > 0
      ? 'Tăng nhẹ so với lần trước ($date).'
      : 'Giảm nhẹ so với lần trước ($date).';
}

/// Câu thay thế khi đây là lần Self-Check đầu tiên được ghi lại.
const String kScaNoTrendText =
    'Đây là lần tự soi đầu tiên được ghi lại, nên chưa có gì để so. Làm lại sau '
    'vài tuần, phần này sẽ cho bạn thấy điều gì đã đổi.';

// ---------------------------------------------------------------------------
// Lớp 3 — đối chiếu Pattern Reflection
// ---------------------------------------------------------------------------

/// Những Episode có `openedAt` nằm trong [days] ngày lịch gần nhất tính từ
/// [now].
///
/// Cắt theo NGÀY chứ không theo mốc 24 giờ: dòng chú thích cuối màn nói "30
/// ngày Reflection gần nhất", và người đọc hiểu đó là 30 ngày lịch.
///
/// Episode thiếu `openedAt` bị loại. Không có ngày thì không thể nói nó thuộc
/// cửa sổ nào — giữ lại là để một lượt Reflect cũ đội lốt lượt vừa xong.
List<ReflectionEpisode> episodesWithinDays(
  List<ReflectionEpisode> episodes, {
  required DateTime now,
  int days = kScaPatternWindowDays,
}) {
  final cutoff = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: days - 1));
  return [
    for (final e in episodes)
      if (e.openedAt != null && !e.openedAt!.isBefore(cutoff)) e,
  ];
}

/// Số lần mỗi trụ xuất hiện trong Reflection của cửa sổ đang xét.
///
/// Đếm theo LƯỢT, không theo tình huống khác nhau: §7 hỏi "bạn quay lại nhóm
/// này bao nhiêu lần", nên chọn lại cùng một tình huống năm lần là năm lần.
Map<SelfCheckPillar, int> pillarPatternCounts(
  List<ReflectionEpisode> episodes,
  List<WrSituation> situations, {
  required DateTime now,
  int days = kScaPatternWindowDays,
}) {
  final codeToDim = {for (final s in situations) s.code: s.scaDimension};
  final counts = <SelfCheckPillar, int>{
    SelfCheckPillar.s: 0,
    SelfCheckPillar.c: 0,
    SelfCheckPillar.a: 0,
  };
  final window = episodesWithinDays(episodes, now: now, days: days);
  for (final code in recentSituationIds(window, window: window.length)) {
    final dim = codeToDim[code];
    if (dim == null) continue;
    final pillar = pillarOfDimension(dim);
    counts[pillar] = counts[pillar]! + 1;
  }
  return counts;
}

/// Trụ được quay lại nhiều nhất. Null khi chưa có lượt nào, hoặc khi HOÀ —
/// không có "nhóm chiếm ưu thế" thì đừng chỉ tay vào một nhóm bất kỳ.
SelfCheckPillar? dominantPatternPillar(Map<SelfCheckPillar, int> counts) {
  var best = 0;
  SelfCheckPillar? winner;
  var tied = false;
  for (final e in counts.entries) {
    if (e.value > best) {
      best = e.value;
      winner = e.key;
      tied = false;
    } else if (e.value == best && best > 0) {
      tied = true;
    }
  }
  if (best == 0 || tied) return null;
  return winner;
}

/// Câu Lớp 3 — ba nhánh template của §7.
String scaPatternText({
  required SelfCheckPillar pillar,
  required ScaPillarStatus status,
  required Map<SelfCheckPillar, int> counts,
  required SelfCheckPillar? dominant,
}) {
  final count = counts[pillar] ?? 0;
  if (count == 0) {
    return 'Chưa có đủ tín hiệu từ Reflection gần đây để đối chiếu thêm cho '
        'nhóm này.';
  }

  if (dominant != pillar) {
    return 'Nhóm này xuất hiện $count lần trong Reflection gần đây, chưa phải '
        'nhóm chiếm ưu thế nhất.';
  }

  // Đây là chỗ §7 gọi là "lệch pha giữa tự nhận thức và trải nghiệm thực tế".
  if (status.isReassuring) {
    return 'Bạn tự đánh giá phần này ${status.label.toLowerCase()}, nhưng đây '
        'lại là nhóm tình huống bạn quay lại nhiều nhất trong Reflection gần '
        'đây ($count lần). Sự chênh lệch này thường đáng chú ý hơn bản thân '
        'điểm số, có thể bạn đã quen đến mức không còn nhận ra ảnh hưởng của '
        'nó nữa.';
  }

  return 'Nhóm này vừa được bạn tự đánh giá ${status.label.toLowerCase()}, vừa '
      'là nơi bạn quay lại nhiều nhất trong Reflection ($count lần). Hai nguồn '
      'dữ liệu đang xác nhận lẫn nhau.';
}

// ---------------------------------------------------------------------------
// Khung "Lệch pha tự nhận thức" — §9, khung thứ ba của Insight Career Memory
// ---------------------------------------------------------------------------
//
// §9 ghi đúng một dòng cho khung này: "Tái dùng logic đã có ở Diễn giải sâu —
// so điểm Self-Check với tần suất Reflection cùng trụ. Điều kiện kích hoạt: có
// cả dữ liệu Self-Check lẫn Reflection trong cùng kỳ."
//
// Nên nó nằm ở ĐÂY chứ không nằm trong `wr_career_memory_rules.dart`: tính lại
// ở bên kia là dựng nguồn sự thật thứ hai cho cùng một câu, và hai màn sẽ nói
// hai điều khác nhau về cùng một chênh lệch.
//
// Chỉ trả về câu khi thật sự CÓ lệch pha — tự chấm là ổn, nhưng chính trụ đó
// lại là nơi quay lại nhiều nhất. Hai nguồn xác nhận lẫn nhau thì không phải
// một Insight, đó chỉ là điều người dùng đã biết.

/// Câu "Lệch pha tự nhận thức", hoặc null khi không có lệch pha nào đáng nói.
String? selfAwarenessGapNarrative({
  required List<ScaSelfCheckResponse> history,
  required List<ReflectionEpisode> episodes,
  required List<WrSituation> situations,
  required DateTime now,
}) {
  final scored = scoredSelfChecks(history);
  if (scored.isEmpty) return null;

  final counts = pillarPatternCounts(episodes, situations, now: now);
  final dominant = dominantPatternPillar(counts);
  if (dominant == null) return null;

  final score = scaScoreOf(scored.first, dominant);
  if (score == null) return null;

  final status = scaPillarStatus(score);
  if (!status.isReassuring) return null;

  final count = counts[dominant] ?? 0;
  return 'Bạn tự đánh giá ${dominant.displayName.toLowerCase()} là '
      '${status.label.toLowerCase()}, nhưng $kScaPatternWindowDays ngày qua đây '
      'lại là nhóm bạn quay lại nhiều nhất khi nhìn lại ($count lần). Chênh '
      'lệch giữa hai điều đó thường đáng nhìn kỹ hơn bản thân điểm số.';
}

/// Dòng chú thích cuối màn.
String scaDeepDiveFootnote(ScaSelfCheckResponse? previous) =>
    'Pattern được tính từ $kScaPatternWindowDays ngày Reflection gần nhất. '
    'Self-Check trước đó: '
    '${previous == null ? 'chưa có' : scaDateLabel(previous.takenAt)}.';

// ---------------------------------------------------------------------------
// Gói dữ liệu một trụ, để màn hình chỉ việc dựng
// ---------------------------------------------------------------------------

class ScaDeepDivePillar {
  const ScaDeepDivePillar({
    required this.pillar,
    required this.score,
    required this.status,
    required this.trendText,
    required this.patternText,
    required this.patternCount,
    required this.isDominant,
  });

  final SelfCheckPillar pillar;
  final double score;
  final ScaPillarStatus status;

  /// Lớp 2. Null khi chưa có lần Self-Check nào trước đó.
  final String? trendText;

  /// Lớp 3, luôn có chữ.
  final String patternText;

  final int patternCount;
  final bool isDominant;

  String get pillarName => pillar.displayName;
}

/// Dựng cả ba trụ theo đúng thứ tự S · C · A.
///
/// Trả về danh sách rỗng khi chưa có lần Self-Check nào — không có điểm thì cả
/// ba lớp đều không nói được gì, và màn hình phải mời người dùng đi làm 15 câu
/// thay vì bày ba thẻ trống.
List<ScaDeepDivePillar> buildScaDeepDive({
  required List<ScaSelfCheckResponse> history,
  required List<ReflectionEpisode> episodes,
  required List<WrSituation> situations,
  required DateTime now,
}) {
  final scored = scoredSelfChecks(history);
  if (scored.isEmpty) return const [];

  final latest = scored.first;
  final previous = scored.length > 1 ? scored[1] : null;
  final counts = pillarPatternCounts(episodes, situations, now: now);
  final dominant = dominantPatternPillar(counts);

  return [
    for (final pillar in SelfCheckPillar.values)
      if (scaScoreOf(latest, pillar) case final double score)
        ScaDeepDivePillar(
          pillar: pillar,
          score: score,
          status: scaPillarStatus(score),
          trendText: scaTrendText(
            pillar: pillar,
            score: score,
            previous: previous,
          ),
          patternText: scaPatternText(
            pillar: pillar,
            status: scaPillarStatus(score),
            counts: counts,
            dominant: dominant,
          ),
          patternCount: counts[pillar] ?? 0,
          isDominant: dominant == pillar,
        ),
  ];
}
