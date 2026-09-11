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

import '../l10n/wr_tr.dart';
import '../models/wr_content.dart';
import '../models/wr_episode.dart';
import '../models/wr_intelligence.dart';
import 'wr_career_health.dart'
    show PillarTally, dominantPillar, pillarTally, selfCheckDateLabel;
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

  /// Nhãn hiển thị trên huy hiệu (A7, khách chốt 10/09/2026).
  ///
  /// Bộ chữ này là bộ THỨ BA trong ba bộ từng cùng tồn tại. Hai bộ kia:
  /// "Đang phát triển / Cần chú ý / Ưu tiên cải thiện" (bản dev cũ) và "Ổn định
  /// / Đang cải thiện / Cần chú ý" (changelog bảng 2). Chọn bộ này vì cả thư
  /// viện câu Diễn giải sâu (`WorkReflection_DienGiaiSau_NoiDung.docx`) rẽ
  /// nhánh theo đúng ba chữ đó — nhánh A đọc "Đang hỗ trợ tốt", nhánh B/D đọc
  /// "Đang cản trở" và "Ổn, còn dư địa".
  ///
  /// **Ngưỡng KHÔNG đổi theo.** Mockup chấm Likert 1–4, app chấm 1–5; bê ngưỡng
  /// của mockup sang đây là mọi người dùng cũ mở app lên thấy đánh giá của mình
  /// tự nhiên khác đi mà không ai chạm vào dữ liệu của họ.
  String get label => switch (this) {
        ScaPillarStatus.developing => tr('Đang hỗ trợ tốt', 'Supporting you well'),
        ScaPillarStatus.needsAttention => tr('Ổn, còn dư địa', 'Fine, room to grow'),
        ScaPillarStatus.priority => tr('Đang cản trở', 'Holding you back'),
      };

  /// Dạng nhúng giữa câu — "bạn tự đánh giá phần này {inlineLabel}, nhưng…".
  ///
  /// Không dùng `label.toLowerCase()` được nữa: nhãn giữa mang sẵn một dấu
  /// phẩy, nên "tự đánh giá ổn, còn dư địa, vừa là nơi…" đọc ra thành hai mệnh
  /// đề rời. Mức giữa cần một dạng liền câu riêng.
  String get inlineLabel => switch (this) {
        ScaPillarStatus.developing => tr('đang hỗ trợ tốt', 'supporting you well'),
        ScaPillarStatus.needsAttention => tr('ổn nhưng còn dư địa', 'fine but with room to grow'),
        ScaPillarStatus.priority => tr('đang cản trở', 'holding you back'),
      };

  /// Người dùng đang tự chấm trụ này là ỔN.
  ///
  /// Chỉ mức cao nhất mới tính. "Ổn, còn dư địa" nằm giữa thang 1–5 và người tự
  /// chấm như vậy KHÔNG nói rằng mình ổn — gộp nó vào đây thì câu "bạn tự đánh
  /// giá phần này ổn, nhưng…" sẽ bịa lại lời của họ.
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
///
/// Uỷ lại cho `wr_career_health.dart`: màn Hiểu mình cũng phải in ngày
/// Self-Check gần nhất (Changelog CareerSnapshot §5), và hai màn cùng nói về
/// một lần tự đánh giá thì không được định dạng ngày theo hai luật.
String scaDateLabel(DateTime d) => selfCheckDateLabel(d);

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
    return tr('Gần như không đổi so với lần trước ($date).', 'Almost unchanged from last time ($date).');
  }
  return diff > 0
      ? tr('Tăng nhẹ so với lần trước ($date).', 'Slightly up from last time ($date).')
      : tr('Giảm nhẹ so với lần trước ($date).', 'Slightly down from last time ($date).');
}

/// Câu thay thế khi đây là lần Self-Check đầu tiên được ghi lại.
String get kScaNoTrendText => tr('Đây là lần tự soi đầu tiên được ghi lại, nên chưa có gì để so. Làm lại sau '
    'vài tuần, phần này sẽ cho bạn thấy điều gì đã đổi.', 'This is the first self-check on record, so there is nothing to compare '
    'against yet. Take it again in a few weeks and this part will show you '
    'what has shifted.');

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
///
/// CHẶN CẢ HAI ĐẦU. Bản trước chỉ chặn đầu dưới, vì `now` lúc chạy thật luôn là
/// bây giờ nên không có gì đứng sau nó. Nhưng tầng 2 của Diễn giải sâu cần một
/// cửa sổ LIỀN TRƯỚC, và nó lấy cửa sổ đó bằng cách truyền một `now` lùi lại
/// một cửa sổ — không chặn đầu trên thì "cửa sổ trước" nuốt luôn cả cửa sổ hiện
/// tại, hai cửa sổ thành một, và mọi câu xu hướng đều đọc ra "ổn định".
List<ReflectionEpisode> episodesWithinDays(
  List<ReflectionEpisode> episodes, {
  required DateTime now,
  int days = kScaPatternWindowDays,
}) {
  final endOfDay = DateTime(now.year, now.month, now.day)
      .add(const Duration(days: 1));
  final cutoff = endOfDay.subtract(Duration(days: days));
  return [
    for (final e in episodes)
      if (e.openedAt != null &&
          !e.openedAt!.isBefore(cutoff) &&
          e.openedAt!.isBefore(endOfDay))
        e,
  ];
}

/// Bảng đếm hai valence của cửa sổ đang xét.
///
/// Đếm theo LƯỢT, không theo tình huống khác nhau: §7 hỏi "bạn quay lại nhóm
/// này bao nhiêu lần", nên chọn lại cùng một tình huống năm lần là năm lần.
///
/// LỖI ĐÃ SỬA 10/09: `pillarOfDimension` trước đây lấy từ
/// `wr_self_check_narrative.dart`, bản có `_ => SelfCheckPillar.a`. Mọi lượt
/// thuộc hai nhóm tình huống TÍCH CỰC (P-ACHIEVE, P-STEADY) bị dồn hết vào trụ
/// A, nên "Cách làm việc" phồng lên bằng đúng số lần người dùng ghi lại điều
/// hay — và có thể thành trụ nổi trội giả, kéo theo cả câu diễn giải sai.
///
/// LỖI ĐÃ SỬA 11/09: bản trước trả về MỘT bảng đếm, bỏ hẳn nhóm P, trong khi
/// mẫu số vẫn là tổng mọi Episode trong cửa sổ. Xem [PillarTally].
PillarTally patternTally(
  List<ReflectionEpisode> episodes,
  List<WrSituation> situations, {
  required DateTime now,
  int days = kScaPatternWindowDays,
}) =>
    pillarTally(episodesWithinDays(episodes, now: now, days: days), situations);

/// Số lần mỗi trụ THÁCH THỨC xuất hiện trong cửa sổ.
///
/// Vẫn còn vì ba nơi chỉ cần đúng bảng này. Trụ nổi trội và khoảng lệch phải
/// tính trên valence thách thức (`DienGiaiSau v2` §2.2), nên đây là bảng đúng
/// cho chúng — nhưng mẫu số đi kèm phải là [PillarTally.challengeTotal], KHÔNG
/// phải tổng số Episode trong cửa sổ.
Map<SelfCheckPillar, int> pillarPatternCounts(
  List<ReflectionEpisode> episodes,
  List<WrSituation> situations, {
  required DateTime now,
  int days = kScaPatternWindowDays,
}) =>
    patternTally(episodes, situations, now: now, days: days).challenge;

/// Tổng số lần Reflection trong cửa sổ, kể cả lượt không gắn được trụ nào.
///
/// KHÔNG CÒN LÀ MẪU SỐ của câu "{count} / {total}". `DienGiaiSau v1` bảng 2
/// định nghĩa `totalReflection` là "tổng số Reflection trong cùng cửa sổ" và
/// dùng nó làm mẫu số; v2 §1.1 chỉ ra đó chính là chỗ hỏng, vì tử số bỏ nhóm P
/// còn mẫu số thì không. Mẫu số nay lấy từ [PillarTally].
///
/// Vẫn giữ hàm này vì tầng 2 cần biết mỗi cửa sổ có bao nhiêu lượt để quyết
/// định đã đủ [kDeepTrendMinPerWindow] hay chưa — đó là câu hỏi về CÔNG SỨC
/// người dùng bỏ ra, nên đếm cả lượt tự viết mới đúng.
int totalReflectionInWindow(
  List<ReflectionEpisode> episodes, {
  required DateTime now,
  int days = kScaPatternWindowDays,
}) =>
    episodesWithinDays(episodes, now: now, days: days).length;

/// Trụ được quay lại nhiều nhất. Null khi chưa đủ chênh lệch để gọi là nổi trội.
///
/// Uỷ lại cho [dominantPillar] của `wr_career_health.dart` — cùng một luật với
/// khối Career Snapshot ở tab Hiểu mình, để hai màn không bao giờ nói khác nhau
/// về việc trụ nào đang nổi lên.
///
/// LUẬT ĐÃ ĐỔI. Bản cũ chỉ loại trường hợp HOÀ tuyệt đối, nên 10 / 9 / 8 lần vẫn
/// tuyên bố có một trụ nổi trội. `DienGiaiSau §2` nêu đích danh ví dụ đó: "Nếu
/// cứ lấy trụ cao nhất bất kể chênh lệch, hệ thống sẽ khẳng định một xu hướng
/// không thật." Nay trụ cao nhất phải VƯỢT 40% tổng.
///
/// [total] là tổng số lần Reflection trong cùng cửa sổ. Không truyền thì lấy
/// tổng ba trụ — giữ đúng hành vi của những nơi gọi chỉ có mỗi bảng đếm.
SelfCheckPillar? dominantPatternPillar(
  Map<SelfCheckPillar, int> counts, {
  int? total,
}) =>
    dominantPillar(
      counts,
      total ?? counts.values.fold<int>(0, (s, v) => s + v),
    );

// ---------------------------------------------------------------------------
// ĐÃ BỎ: scaPatternText
// ---------------------------------------------------------------------------
//
// Hàm này sinh câu "đối chiếu Pattern" cho TỪNG trụ, và màn hình in cả ba.
// `DienGiaiSau v2` §1.3 gọi thẳng tên vấn đề: "Mỗi trụ đang hiện nhãn mức đánh
// giá (đã có ở Career Snapshot) cộng số lần xuất hiện (cũng đã có ở Career
// Snapshot), cộng một câu gần như giống hệt nhau ba lần. Nói với người dùng ba
// lần rằng không có gì nổi trội thì đúng về logic nhưng vô nghĩa về trải
// nghiệm."
//
// Điều nó nói đúng — chỗ lệch pha giữa tự đánh giá và tần suất — nay do khối
// chính nói, đúng MỘT lần, ở bậc R3 của thang ưu tiên. Giữ lại hàm này là để
// hai nguồn cùng kết luận về một chênh lệch rồi có ngày nói khác nhau.
//
// Khung "Lệch pha tự nhận thức" ở Insight Career Memory KHÔNG dùng hàm này —
// nó gọi [selfAwarenessGapNarrative] bên dưới, và khung đó vẫn còn.

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

  final tally = patternTally(episodes, situations, now: now);
  final counts = tally.challenge;
  final dominant = dominantPatternPillar(
    counts,
    total: tally.challengeTotal,
  );
  if (dominant == null) return null;

  final score = scaScoreOf(scored.first, dominant);
  if (score == null) return null;

  final status = scaPillarStatus(score);
  if (!status.isReassuring) return null;

  final count = counts[dominant] ?? 0;
  return tr('Bạn tự đánh giá ${dominant.displayName.toLowerCase()} là '
      '${status.inlineLabel}, nhưng $kScaPatternWindowDays ngày qua đây '
      'lại là nhóm bạn quay lại nhiều nhất khi nhìn lại ($count lần). Chênh '
      'lệch giữa hai điều đó thường đáng nhìn kỹ hơn bản thân điểm số.', 'You rate ${dominant.displayName.toLowerCase()} as '
      '${status.inlineLabel}, yet over the past $kScaPatternWindowDays days it '
      'is the group you return to most when looking back ($count times). That '
      'gap is usually worth a closer look than the score itself.');
}

/// Dòng chú thích cuối màn.
String scaDeepDiveFootnote(ScaSelfCheckResponse? previous) =>
    tr('Pattern được tính từ $kScaPatternWindowDays ngày Reflection gần nhất. '
    'Self-Check trước đó: '
    '${previous == null ? 'chưa có' : scaDateLabel(previous.takenAt)}.', 'Patterns are drawn from the last $kScaPatternWindowDays days of '
    'Reflection. Previous Self-Check: '
    '${previous == null ? 'none yet' : scaDateLabel(previous.takenAt)}.');

// ---------------------------------------------------------------------------
// Gói dữ liệu một trụ, để màn hình chỉ việc dựng
// ---------------------------------------------------------------------------

class ScaDeepDivePillar {
  const ScaDeepDivePillar({
    required this.pillar,
    required this.score,
    required this.status,
    required this.trendText,
    required this.patternCount,
    required this.isDominant,
  });

  final SelfCheckPillar pillar;
  final double score;
  final ScaPillarStatus status;

  /// So với LẦN SELF-CHECK TRƯỚC. Null khi chưa có lần nào trước đó.
  ///
  /// Là thứ duy nhất còn lại của ba lớp cũ, vì là thứ duy nhất Career Snapshot
  /// không có. Xem chú thích chỗ [ScaDeepDivePillar] cũ có `patternText`.
  final String? trendText;

  /// Số lần trụ này bị chạm bởi tình huống THÁCH THỨC trong cửa sổ.
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
  final tally = patternTally(episodes, situations, now: now);
  final counts = tally.challenge;
  final dominant = dominantPatternPillar(
    counts,
    total: tally.challengeTotal,
  );

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
          patternCount: counts[pillar] ?? 0,
          isDominant: dominant == pillar,
        ),
  ];
}
