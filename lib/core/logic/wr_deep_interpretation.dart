// Thư viện nội dung "Diễn giải sâu & xu hướng" — Premium.
//
// Nguồn: `WorkReflection_DienGiaiSau_NoiDung.docx` (khách gửi 10/09/2026).
//
// ---------------------------------------------------------------------------
// Kiến trúc ba lớp, và vì sao thứ tự không được đảo
// ---------------------------------------------------------------------------
//
//   Lớp 1 · Tính dữ kiện    Đếm, so sánh, xác định nhánh nào được kích hoạt.
//                           Đầu ra là một tập dữ kiện đã chốt.        → code
//   Lớp 2 · Ghép câu        Chọn câu mẫu đúng nhánh, chèn dữ kiện.
//                           Đầu ra đã là câu hoàn chỉnh, đọc được ngay. → code
//   Lớp 3 · Diễn đạt lại    Nhận câu đã hoàn chỉnh, viết cho mượt hơn.  → AI
//
// Nguyên tắc nền: **sự thật do hệ thống tính, câu chữ do người viết trước, AI
// chỉ được phép diễn đạt lại.** AI không bao giờ được tự suy ra con số hay tự
// kết luận. §1: "Nếu để AI nhận dữ liệu thô rồi tự phân tích, mọi con số trong
// sản phẩm sẽ mất tính bảo đảm, và một sai lệch nhỏ về số liệu trong sản phẩm
// nói về chính cuộc sống người dùng sẽ làm mất niềm tin rất nhanh."
//
// File này là TRỌN VẸN lớp 1 và lớp 2. Bỏ hẳn lớp 3 thì sản phẩm vẫn chạy đầy
// đủ và đúng — đó là lý do lớp 3 nằm ở một hạng mục riêng.
//
// ---------------------------------------------------------------------------
// Ba tầng nội dung, ba điều kiện mở khác nhau
// ---------------------------------------------------------------------------
//
//   Tầng 1 · Khoảng lệch          1 Self-Check + 15 Reflection
//   Tầng 2 · Xu hướng Reflection  2 cửa sổ liền kề, mỗi cửa sổ ≥ 10 lần
//   Tầng 3 · Xu hướng Self-Check  2 lần Self-Check cách nhau ≥ 6 tuần
//
// Điều kiện tầng 1 đúng BẰNG điều kiện người dùng đã thoả khi nhìn thấy nút mở
// khoá, nên không ai trả tiền xong lại gặp màn hình trống.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

import '../models/wr_content.dart';
import '../models/wr_episode.dart';
import '../models/wr_intelligence.dart';
import 'wr_career_health.dart';
import 'wr_sca_deep_dive.dart';
import 'wr_self_check_questions.dart';

// ---------------------------------------------------------------------------
// Ngưỡng
// ---------------------------------------------------------------------------

/// Số lần Reflection tối thiểu để mở tầng 1. Đúng ngưỡng của Career Snapshot.
const int kDeepTier1MinReflections = kCareerHealthThreshold;

/// Mỗi cửa sổ của tầng 2 phải có ít nhất bấy nhiêu lần Reflection (§4).
const int kDeepTrendMinPerWindow = 10;

/// Chênh lệch tỉ trọng dưới mức này thì coi như không đổi.
///
/// 8 điểm phần trăm. Dưới mức đó, với cửa sổ 10–30 lượt, một hai lượt lệch đã
/// đủ làm tỉ trọng nhúc nhích — gọi đó là "đang tăng lên" là đọc ra xu hướng từ
/// nhiễu.
const double kDeepTrendEpsilon = 0.08;

/// Hai lần Self-Check phải cách nhau ít nhất bấy nhiêu ngày mới sinh câu xu
/// hướng (§5, "6 tuần").
///
/// §5 nói rõ đây là ràng buộc BẮT BUỘC: "Hai lần Self-Check cách nhau vài ngày
/// chỉ phản ánh dao động tâm trạng, không phải thay đổi điều kiện làm việc."
/// Làm lại quá sớm thì kết quả mới vẫn hiện bình thường, chỉ là không có câu
/// xu hướng.
const int kDeepSelfCheckMinGapDays = 42;

// ---------------------------------------------------------------------------
// LỚP 1 — dữ kiện
// ---------------------------------------------------------------------------

/// Một trụ đang tăng lên, lùi lại, hay giữ nguyên giữa hai cửa sổ.
enum DeepTrend { rising, falling, steady }

/// Khoảng lệch giữa tự đánh giá và tần suất đang đi về đâu.
enum DeepGapStatus { narrowing, unchanged, widening }

/// Toàn bộ dữ kiện đã chốt của một lần dựng nội dung.
///
/// Mọi câu ở lớp 2 chỉ được đọc từ đây. Không hàm nào ở lớp 2 được nhận
/// `episodes` hay `history` thô — nhận thô là mở đường cho hai chỗ đếm theo hai
/// luật rồi nói hai con số khác nhau về cùng một người.
class DeepFacts {
  const DeepFacts({
    required this.pillarStatus,
    required this.pillarCount,
    required this.totalReflection,
    required this.dominant,
    required this.selfCheckDate,
    required this.previousSelfCheckDate,
    required this.pillarTrend,
    required this.reflectionTrend,
    required this.gapStatus,
    required this.hasScoredSelfCheck,
    required this.hasTwoWindows,
    required this.variantSeed,
  });

  /// Mức tự đánh giá từng trụ ở lần Self-Check gần nhất. Rỗng khi chưa làm.
  final Map<SelfCheckPillar, ScaPillarStatus> pillarStatus;

  /// Số lần mỗi trụ xuất hiện trong cửa sổ hiện tại.
  final Map<SelfCheckPillar, int> pillarCount;

  /// Mẫu số của mọi câu "{count} trong {total} lần".
  final int totalReflection;

  /// Trụ nổi trội, hoặc null khi phân bố tương đối đều.
  final SelfCheckPillar? dominant;

  final DateTime? selfCheckDate;
  final DateTime? previousSelfCheckDate;

  /// So điểm Self-Check gần nhất với lần trước đó. Rỗng khi chưa đủ hai lần.
  final Map<SelfCheckPillar, DeepTrend> pillarTrend;

  /// So tỉ trọng từng trụ ở cửa sổ hiện tại với cửa sổ liền trước.
  final Map<SelfCheckPillar, DeepTrend> reflectionTrend;

  /// Null khi chưa đủ hai lần Self-Check để so khoảng lệch.
  final DeepGapStatus? gapStatus;

  final bool hasScoredSelfCheck;

  /// Hai cửa sổ liền kề đều đủ [kDeepTrendMinPerWindow] lượt.
  final bool hasTwoWindows;

  /// Chỉ số xoay vòng biến thể câu.
  final int variantSeed;

  /// Tầng 1 mở được chưa (§3).
  bool get tier1Unlocked =>
      hasScoredSelfCheck && totalReflection >= kDeepTier1MinReflections;

  /// Tầng 2 mở được chưa (§4).
  bool get tier2Unlocked => hasTwoWindows;

  /// Tầng 3 mở được chưa (§5).
  bool get tier3Unlocked {
    final a = selfCheckDate;
    final b = previousSelfCheckDate;
    if (a == null || b == null) return false;
    return a.difference(b).inDays.abs() >= kDeepSelfCheckMinGapDays;
  }

  /// Trụ tự đánh giá thấp nhất. Null khi chưa tự đánh giá.
  ///
  /// "Thấp nhất" theo MỨC, không theo điểm thô: nhánh D nói về "phần bạn thấy
  /// khó nhất", và người đọc hiểu điều đó theo nhãn họ nhìn thấy chứ không theo
  /// số thập phân họ chưa từng thấy.
  SelfCheckPillar? get weakestPillar {
    SelfCheckPillar? worst;
    for (final e in pillarStatus.entries) {
      if (worst == null || e.value.index > pillarStatus[worst]!.index) {
        worst = e.key;
      }
    }
    return worst;
  }
}

/// Dựng dữ kiện lớp 1 từ dữ liệu thô. Đây là chỗ DUY NHẤT đọc dữ liệu thô.
DeepFacts buildDeepFacts({
  required List<ScaSelfCheckResponse> history,
  required List<ReflectionEpisode> episodes,
  required List<WrSituation> situations,
  required DateTime now,
  int windowDays = kScaPatternWindowDays,
}) {
  final scored = scoredSelfChecks(history);
  final latest = scored.isEmpty ? null : scored.first;
  final previous = scored.length > 1 ? scored[1] : null;

  final status = <SelfCheckPillar, ScaPillarStatus>{};
  if (latest != null) {
    for (final p in SelfCheckPillar.values) {
      final s = scaScoreOf(latest, p);
      if (s != null) status[p] = scaPillarStatus(s);
    }
  }

  final counts = pillarPatternCounts(
    episodes,
    situations,
    now: now,
    days: windowDays,
  );
  final total = totalReflectionInWindow(episodes, now: now, days: windowDays);

  // Cửa sổ liền trước: cùng độ dài, dịch lùi đúng một cửa sổ.
  final previousWindowEnd = now.subtract(Duration(days: windowDays));
  final prevCounts = pillarPatternCounts(
    episodes,
    situations,
    now: previousWindowEnd,
    days: windowDays,
  );
  final prevTotal = totalReflectionInWindow(
    episodes,
    now: previousWindowEnd,
    days: windowDays,
  );

  return DeepFacts(
    pillarStatus: status,
    pillarCount: counts,
    totalReflection: total,
    dominant: dominantPillar(counts, total),
    selfCheckDate: latest?.takenAt,
    previousSelfCheckDate: previous?.takenAt,
    pillarTrend: _scoreTrends(latest, previous),
    reflectionTrend: _shareTrends(counts, total, prevCounts, prevTotal),
    gapStatus: _gapStatus(
      latest: latest,
      previous: previous,
      counts: counts,
      total: total,
      prevCounts: prevCounts,
      prevTotal: prevTotal,
    ),
    hasScoredSelfCheck: latest != null,
    hasTwoWindows: total >= kDeepTrendMinPerWindow &&
        prevTotal >= kDeepTrendMinPerWindow,
    // Xoay vòng theo tổng số lần nhìn lại: người dùng quay lại sau vài lần nữa
    // thì đọc được một cách nói khác, mà vẫn thuần tuý tính ra được nên test
    // không phải đoán.
    variantSeed: total,
  );
}

Map<SelfCheckPillar, DeepTrend> _scoreTrends(
  ScaSelfCheckResponse? latest,
  ScaSelfCheckResponse? previous,
) {
  if (latest == null || previous == null) return const {};
  final out = <SelfCheckPillar, DeepTrend>{};
  for (final p in SelfCheckPillar.values) {
    final now = scaScoreOf(latest, p);
    final before = scaScoreOf(previous, p);
    if (now == null || before == null) continue;
    final diff = now - before;
    out[p] = diff.abs() < kScaTrendEpsilon
        ? DeepTrend.steady
        : (diff > 0 ? DeepTrend.rising : DeepTrend.falling);
  }
  return out;
}

Map<SelfCheckPillar, DeepTrend> _shareTrends(
  Map<SelfCheckPillar, int> counts,
  int total,
  Map<SelfCheckPillar, int> prevCounts,
  int prevTotal,
) {
  if (total == 0 || prevTotal == 0) return const {};
  final out = <SelfCheckPillar, DeepTrend>{};
  for (final p in SelfCheckPillar.values) {
    final diff = (counts[p] ?? 0) / total - (prevCounts[p] ?? 0) / prevTotal;
    out[p] = diff.abs() < kDeepTrendEpsilon
        ? DeepTrend.steady
        : (diff > 0 ? DeepTrend.rising : DeepTrend.falling);
  }
  return out;
}

/// Khoảng lệch lần này so với lần Self-Check trước.
///
/// "Khoảng lệch" đo bằng một thứ duy nhất: trụ quay lại nhiều nhất được người
/// dùng tự chấm cao tới đâu. Tự chấm càng cao trong khi tần suất càng dày thì
/// khoảng lệch càng rộng. Dùng CHỈ SỐ MỨC (0 tốt nhất … 2 tệ nhất) nhân với tỉ
/// trọng, nên hai lần Self-Check có thể so được với nhau bằng một con số.
DeepGapStatus? _gapStatus({
  required ScaSelfCheckResponse? latest,
  required ScaSelfCheckResponse? previous,
  required Map<SelfCheckPillar, int> counts,
  required int total,
  required Map<SelfCheckPillar, int> prevCounts,
  required int prevTotal,
}) {
  if (latest == null || previous == null) return null;
  if (total == 0 || prevTotal == 0) return null;

  double gap(
    ScaSelfCheckResponse check,
    Map<SelfCheckPillar, int> c,
    int t,
  ) {
    final dom = dominantPillar(c, t);
    if (dom == null) return 0;
    final score = scaScoreOf(check, dom);
    if (score == null) return 0;
    // Mức "Đang phát triển" (index 0) là chỗ lệch pha lớn nhất: tự chấm ổn mà
    // vẫn quay lại nhiều nhất. Đảo chỉ số để số càng lớn = lệch càng rộng.
    final reassurance = 2 - scaPillarStatus(score).index;
    return reassurance * ((c[dom] ?? 0) / t);
  }

  final diff = gap(latest, counts, total) - gap(previous, prevCounts, prevTotal);
  if (diff.abs() < kDeepTrendEpsilon) return DeepGapStatus.unchanged;
  return diff < 0 ? DeepGapStatus.narrowing : DeepGapStatus.widening;
}

// ---------------------------------------------------------------------------
// LỚP 2 — ghép câu
// ---------------------------------------------------------------------------

/// Nhánh nào của tầng 1 đang được kích hoạt (§3.1–3.4).
enum DeepGapBranch {
  /// A · Lệch pha: tự đánh giá ổn, nhưng là trụ quay lại nhiều nhất.
  outOfSync,

  /// B · Hai nguồn xác nhận lẫn nhau.
  aligned,

  /// C · Chưa có trụ nào nổi trội rõ.
  even,

  /// D · Trụ nổi trội không trùng với trụ tự đánh giá thấp nhất.
  mismatch,
}

/// Chọn nhánh cho tầng 1.
///
/// THỨ TỰ XÉT: A → D → B → C, không phải A → B → D → C như §8 liệt kê.
///
/// §8 xếp thứ tự đó để nói ƯU TIÊN CHỌN INSIGHT DẪN DẮT khi có nhiều thứ đáng
/// nói. Nhưng điều kiện của D ("nổi trội ở mức Ổn còn dư địa, mà có trụ khác
/// đang cản trở") nằm TRỌN trong điều kiện của B ("nổi trội ở mức Đang cản trở
/// hoặc Ổn còn dư địa"). Xét B trước thì D không bao giờ chạy tới — mà §3.4 lại
/// viết hẳn ba biến thể câu cho nó. Nên D, vốn hẹp hơn, phải đứng trước B.
DeepGapBranch deepGapBranch(DeepFacts f) {
  final dom = f.dominant;
  if (dom == null) return DeepGapBranch.even;

  final status = f.pillarStatus[dom];
  if (status == null) return DeepGapBranch.even;

  if (status.isReassuring) return DeepGapBranch.outOfSync;

  // D hẹp hơn B: nổi trội chỉ ở mức giữa, mà nơi người dùng thấy khó nhất lại
  // là một trụ khác.
  if (status == ScaPillarStatus.needsAttention) {
    final weakest = f.weakestPillar;
    if (weakest != null &&
        weakest != dom &&
        f.pillarStatus[weakest] == ScaPillarStatus.priority) {
      return DeepGapBranch.mismatch;
    }
  }
  return DeepGapBranch.aligned;
}

/// Câu tầng 1 — Khoảng lệch. Luôn có chữ khi [DeepFacts.tier1Unlocked].
String deepGapText(DeepFacts f) {
  final branch = deepGapBranch(f);
  final total = f.totalReflection;
  final v = f.variantSeed % 3;

  if (branch == DeepGapBranch.even) {
    return switch (v) {
      0 => 'Trong $total lần nhìn lại gần đây, những điều bạn ghi nhận trải khá '
          'đều giữa ba nhóm, chưa nhóm nào nổi lên rõ hơn hẳn. Điều này không '
          'có gì bất thường. Nó thường xuất hiện khi công việc đang có nhiều '
          'thứ diễn ra cùng lúc, hoặc khi bạn mới bắt đầu thói quen nhìn lại. '
          'Sau một thời gian nữa, bức tranh sẽ dần rõ hơn.',
      1 => 'Chưa có nhóm nào chiếm ưu thế rõ rệt trong $total lần ghi nhận gần '
          'đây của bạn. Có thể mọi thứ đang khá cân bằng, cũng có thể bức '
          'tranh cần thêm thời gian để hiện ra. Bạn cứ tiếp tục nhìn lại đều '
          'đặn nhé, hệ thống sẽ báo cho bạn khi có điều gì đó lặp lại đủ nhiều.',
      _ => 'Ba nhóm trải nghiệm của bạn đang khá cân nhau trong thời gian qua. '
          'Điều đáng chú ý ở đây không nằm ở một nhóm cụ thể, mà ở chính sự cân '
          'bằng đó. Bạn có thấy điều này giống với cảm nhận của mình về công '
          'việc hiện tại không?',
    };
  }

  final dom = f.dominant!;
  final name = dom.displayName.toLowerCase();
  final count = f.pillarCount[dom] ?? 0;

  return switch (branch) {
    DeepGapBranch.outOfSync => switch (v) {
        0 => 'Trong bộ Self-Check gần nhất, bạn đánh giá $name đang ở mức khá '
            'ổn. Nhưng khi nhìn lại, $count trong $total lần ghi nhận gần đây '
            'của bạn lại xoay quanh chính nhóm này. Khoảng cách giữa hai điều '
            'đó thường đáng để dừng lại một chút. Có thể đây là điều bạn đã '
            'quen đến mức không còn thấy nó ảnh hưởng nữa. Bạn thử nghĩ xem sao '
            'nhé.',
        1 => 'Bạn từng đánh giá $name là phần đang ổn trong công việc của mình. '
            'Tuy nhiên, $count trong $total lần nhìn lại gần đây đều liên quan '
            'đến nhóm này. Hai điều đó chưa hẳn mâu thuẫn, nhưng chúng đang kể '
            'hai câu chuyện khác nhau. Điều gì có thể giải thích cho khoảng '
            'cách này?',
        _ => 'Có một chi tiết đáng chú ý. ${dom.displayName} là nhóm bạn tự '
            'đánh giá không đáng lo, nhưng cũng là nhóm xuất hiện nhiều nhất '
            'trong những lần bạn dừng lại để nhìn lại, $count trên $total lần. '
            'Đôi khi những điều ta cho là bình thường lại chính là thứ chiếm '
            'nhiều tâm trí nhất.',
      },
    DeepGapBranch.aligned => switch (v) {
        0 => '${dom.displayName} vừa là phần bạn tự đánh giá cần được chú ý, '
            'vừa là nhóm tình huống quay lại nhiều nhất trong $total lần ghi '
            'nhận gần đây, $count lần. Cảm nhận của bạn và những gì đang thực '
            'sự diễn ra đang khớp với nhau. Đây thường là dấu hiệu cho thấy bạn '
            'đã nhìn khá rõ điều đang xảy ra với mình.',
        1 => 'Cả hai nguồn đang chỉ về cùng một hướng. Bạn tự đánh giá $name là '
            'phần cần cải thiện, và trong $total lần nhìn lại gần đây thì có '
            '$count lần thuộc về nhóm này. Khi cảm nhận và trải nghiệm thật '
            'khớp nhau như vậy, đây thường là chỗ đáng để bắt đầu.',
        _ => '${dom.displayName} đang là điều rõ ràng nhất trong bức tranh hiện '
            'tại của bạn. Bạn đã tự nhận ra nó qua Self-Check, và nó cũng chiếm '
            '$count trong $total lần bạn dừng lại nhìn lại. Bạn muốn thử một '
            'bước nhỏ nào cho phần này trong tuần tới không?',
      },
    DeepGapBranch.mismatch => () {
        final weak = f.weakestPillar!.displayName.toLowerCase();
        return switch (v) {
          0 => 'Bạn tự đánh giá $weak là phần khó khăn nhất hiện tại. Nhưng '
              'trong $total lần nhìn lại gần đây, nhóm quay lại nhiều nhất lại '
              'là $name, với $count lần. Đôi khi điều làm ta bận tâm mỗi ngày '
              'không trùng với điều ta nghĩ là vấn đề lớn nhất.',
          1 => 'Có hai điều đang cùng nổi lên. Self-Check cho thấy $weak là '
              'phần bạn thấy khó nhất, còn các lần nhìn lại của bạn lại tập '
              'trung nhiều vào $name, $count trên $total lần. Cả hai đều là dữ '
              'liệu thật về bạn, chỉ là chúng đang nói về hai lớp khác nhau.',
          _ => '${dom.displayName} đang là nhóm chiếm nhiều lần nhìn lại nhất '
              'của bạn, $count trên $total lần, dù đây không phải phần bạn tự '
              'đánh giá thấp nhất. Điều gì khiến nhóm này thường xuyên quay lại '
              'như vậy?',
        };
      }(),
    DeepGapBranch.even => '',
  };
}

// ---------------------------------------------------------------------------
// Tầng 2 — xu hướng từ Reflection (§4)
// ---------------------------------------------------------------------------
//
// Dựa vào Reflection chứ không dựa vào Self-Check, vì Reflection cập nhật liên
// tục mà không cần người dùng làm thêm việc gì. Nếu xu hướng chỉ dựa vào
// Self-Check, người vừa mua Premium mà mới làm Self-Check một lần sẽ phải chờ
// nhiều tháng mới thấy được gì.

/// Câu tầng 2, hoặc null khi chưa đủ hai cửa sổ.
String? deepReflectionTrendText(DeepFacts f) {
  if (!f.tier2Unlocked) return null;
  final v = f.variantSeed % 2;

  // Nhóm tăng rõ nhất thắng; không có thì xét nhóm lùi lại.
  SelfCheckPillar? rising;
  SelfCheckPillar? falling;
  for (final e in f.reflectionTrend.entries) {
    if (e.value == DeepTrend.rising && rising == null) rising = e.key;
    if (e.value == DeepTrend.falling && falling == null) falling = e.key;
  }

  if (rising != null) {
    final name = rising.displayName.toLowerCase();
    return v == 0
        ? 'So với giai đoạn trước, $name đang chiếm nhiều hơn trong các lần bạn '
            'nhìn lại. Điều này có thể đến từ một thay đổi trong công việc, '
            'hoặc đơn giản là bạn đang chú ý đến nó nhiều hơn trước. Bạn có '
            'nhận ra điều gì đã khác đi không?'
        : '${rising.displayName} đang xuất hiện dày hơn trong thời gian gần đây '
            'so với giai đoạn trước đó. Khi một nhóm tăng dần như vậy, thường '
            'có điều gì đó trong công việc đang chuyển động. Bạn thử nhớ lại '
            'xem giai đoạn này có gì khác không nhé.';
  }

  if (falling != null) {
    final name = falling.displayName.toLowerCase();
    return v == 0
        ? '${falling.displayName} từng chiếm phần lớn trong những lần bạn nhìn '
            'lại, nhưng gần đây đã ít dần. Đây có thể là dấu hiệu tích cực, cho '
            'thấy điều đó đã bớt chiếm tâm trí bạn. Bạn có thấy vậy không?'
        : 'Có một điều đã lùi lại phía sau. $name không còn quay lại thường '
            'xuyên như giai đoạn trước. Những thay đổi kiểu này thường diễn ra '
            'âm thầm và dễ bị bỏ qua, nên đây là một điều đáng để ghi nhận cho '
            'chính mình.';
  }

  return 'Bức tranh của bạn khá ổn định so với giai đoạn trước, không nhóm nào '
      'tăng hay giảm rõ rệt. Sự ổn định này tự nó cũng là một thông tin, nó cho '
      'thấy điều kiện xung quanh bạn đang giữ nguyên nhịp.';
}

// ---------------------------------------------------------------------------
// Tầng 3 — xu hướng Self-Check và khoảng lệch (§5)
// ---------------------------------------------------------------------------

/// Câu tầng 3, hoặc null khi chưa đủ hai lần Self-Check cách nhau 6 tuần.
String? deepSelfCheckTrendText(DeepFacts f) {
  if (!f.tier3Unlocked) return null;
  final date = selfCheckDateLabel(f.previousSelfCheckDate!);
  final v = f.variantSeed % 2;

  switch (f.gapStatus) {
    case DeepGapStatus.narrowing:
      final dom = f.dominant;
      final name = (dom ?? SelfCheckPillar.s).displayName.toLowerCase();
      return v == 0
          ? 'Ở lần Self-Check trước, bạn đánh giá $name khá ổn trong khi đây lại '
              'là nhóm quay lại nhiều nhất trong các lần nhìn lại. Lần này, '
              'đánh giá của bạn đã sát hơn với điều đang thực sự diễn ra. Việc '
              'dừng lại nhìn lại đều đặn đang giúp bạn thấy rõ hơn chính mình.'
          : 'Có một thay đổi đáng ghi nhận. Khoảng cách giữa điều bạn tự đánh '
              'giá và điều thực sự lặp lại đã thu hẹp so với lần trước. Nói '
              'cách khác, bạn đang nhìn công việc của mình rõ hơn so với vài '
              'tháng trước.';

    case DeepGapStatus.unchanged:
      // Không có trụ nổi trội thì không gọi tên trụ nào — câu I1 vốn có chỗ
      // chèn tên nhóm, nhưng chèn một cái tên không có thật thì tệ hơn là bỏ.
      final dom = f.dominant;
      final tail = dom == null
          ? 'Bạn có muốn thử nhìn kỹ hơn vào những điều đang lặp lại trong thời '
              'gian tới không?'
          : 'Bạn có muốn thử nhìn kỹ hơn vào nhóm '
              '${dom.displayName.toLowerCase()} trong thời gian tới không?';
      return 'Khoảng cách giữa cảm nhận của bạn và những gì đang lặp lại vẫn '
          'tương tự lần trước. Điều này khá bình thường, những mẫu hình đã hình '
          'thành lâu thường cần thời gian để nhận ra. $tail';

    case DeepGapStatus.widening:
    case null:
      // Khoảng lệch rộng ra, hoặc không tính được: rơi về câu điểm-một-trụ.
      SelfCheckPillar? changed;
      SelfCheckPillar? stable;
      for (final e in f.pillarTrend.entries) {
        if (e.value != DeepTrend.steady && changed == null) changed = e.key;
        if (e.value == DeepTrend.steady && stable == null) stable = e.key;
      }
      if (changed != null) {
        final dir = f.pillarTrend[changed] == DeepTrend.rising
            ? 'tăng lên'
            : 'giảm xuống';
        return 'So với lần cập nhật Self-Check trước vào $date, đánh giá của '
            'bạn về ${changed.displayName.toLowerCase()} đã $dir. Bạn có nhớ '
            'điều gì trong công việc đã thay đổi trong khoảng thời gian này '
            'không?';
      }
      if (stable != null) {
        return '${stable.displayName} gần như giữ nguyên so với lần bạn cập '
            'nhật vào $date. Khi một phần giữ nguyên qua thời gian, đó thường '
            'là điều kiện nền của công việc chứ không phải chuyện nhất thời.';
      }
      return null;
  }
}

// ---------------------------------------------------------------------------
// Mục 6 — chưa đủ dữ liệu: MỜI GỌI, không báo lỗi
// ---------------------------------------------------------------------------
//
// §6: "Đây là phần dễ làm hỏng trải nghiệm nhất, vì người dùng đã trả tiền.
// Tuyệt đối không dùng các câu kiểu 'Chưa đủ dữ liệu', 'Không thể tính toán',
// 'Cần thêm X lần nữa mới hiển thị được'."

/// Câu thay cho tầng 2 khi chưa đủ hai cửa sổ.
const String kDeepNoTrendYet =
    'Phần xu hướng sẽ mở ra khi bạn có thêm một khoảng thời gian nhìn lại nữa. '
    'Khi đó bạn sẽ thấy được điều gì đang tăng lên và điều gì đang lùi lại '
    'trong công việc của mình.';

/// Câu thay cho tầng 3 khi mới có một lần Self-Check.
const String kDeepOneSelfCheckOnly =
    'Sau lần cập nhật Self-Check tiếp theo, bạn sẽ thấy được cảm nhận của mình '
    'đã thay đổi ra sao so với hôm nay. Bạn có thể cập nhật bất cứ khi nào thấy '
    'công việc có gì khác đi.';

/// Câu mời cập nhật khi lần Self-Check gần nhất đã quá 3 tháng.
String deepStaleSelfCheckText(DateTime takenAt) =>
    'Lần Self-Check gần nhất của bạn là vào ${selfCheckDateLabel(takenAt)}. '
    'Công việc có thể đã khác đi từ đó, bạn thử cập nhật lại để bức tranh sát '
    'với hiện tại hơn nhé.';

/// Câu mời khi chưa đủ số lần nhìn lại để mở tầng 1.
///
/// Cố ý KHÔNG nói "cần thêm N lần nữa mới hiển thị được" — đó đúng là dạng câu
/// §6 cấm. Nói cái sẽ mở ra, không nói cái đang thiếu.
const String kDeepNotEnoughReflection =
    'Bức tranh này rõ dần theo số lần bạn dừng lại nhìn lại. Cứ ghi lại những '
    'lúc đáng nhớ trong công việc, rồi quay lại đây để đọc điều đang lặp lại '
    'phía sau chúng.';

// ---------------------------------------------------------------------------
// Gói cả màn
// ---------------------------------------------------------------------------

/// Nội dung đã ghép xong cho màn Diễn giải sâu.
class DeepInterpretation {
  const DeepInterpretation({
    required this.facts,
    required this.leadText,
    required this.branch,
    required this.trendText,
    required this.selfCheckTrendText,
    required this.staleSelfCheckText,
  });

  final DeepFacts facts;

  /// Một insight dẫn dắt — §8: "Một insight được đọc kỹ có giá trị hơn chín
  /// insight bị lướt qua."
  final String leadText;

  /// Nhánh nào sinh ra [leadText]. Null khi tầng 1 chưa mở.
  final DeepGapBranch? branch;

  /// Tầng 2, hoặc câu mời gọi thay thế.
  final String trendText;

  /// Tầng 3, hoặc câu mời gọi thay thế. Null khi chưa từng làm Self-Check.
  final String? selfCheckTrendText;

  /// Chỉ khác null khi lần Self-Check gần nhất đã quá 3 tháng.
  final String? staleSelfCheckText;
}

DeepInterpretation buildDeepInterpretation({
  required List<ScaSelfCheckResponse> history,
  required List<ReflectionEpisode> episodes,
  required List<WrSituation> situations,
  required DateTime now,
}) {
  final f = buildDeepFacts(
    history: history,
    episodes: episodes,
    situations: situations,
    now: now,
  );

  final takenAt = f.selfCheckDate;
  return DeepInterpretation(
    facts: f,
    leadText: f.tier1Unlocked ? deepGapText(f) : kDeepNotEnoughReflection,
    branch: f.tier1Unlocked ? deepGapBranch(f) : null,
    trendText: deepReflectionTrendText(f) ?? kDeepNoTrendYet,
    selfCheckTrendText: !f.hasScoredSelfCheck
        ? null
        : (deepSelfCheckTrendText(f) ?? kDeepOneSelfCheckOnly),
    staleSelfCheckText: takenAt != null && selfCheckIsStale(takenAt, now)
        ? deepStaleSelfCheckText(takenAt)
        : null,
  );
}
