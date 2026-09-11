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

import '../l10n/wr_tr.dart';
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
    // Mức "Đang hỗ trợ tốt" (index 0) là chỗ lệch pha lớn nhất: tự chấm ổn mà
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
      0 => tr('Trong $total lần nhìn lại gần đây, những điều bạn ghi nhận trải khá '
          'đều giữa ba nhóm, chưa nhóm nào nổi lên rõ hơn hẳn. Điều này không '
          'có gì bất thường. Nó thường xuất hiện khi công việc đang có nhiều '
          'thứ diễn ra cùng lúc, hoặc khi bạn mới bắt đầu thói quen nhìn lại. '
          'Sau một thời gian nữa, bức tranh sẽ dần rõ hơn.', 'Across your last $total look-backs, what you recorded is spread '
          'fairly evenly across the three groups, with none standing out. '
          'There is nothing odd about that. It usually shows up when a lot is '
          'happening at work at once, or when you have only just started the '
          'habit of looking back. Give it a while and the picture will sharpen.'),
      1 => tr('Chưa có nhóm nào chiếm ưu thế rõ rệt trong $total lần ghi nhận gần '
          'đây của bạn. Có thể mọi thứ đang khá cân bằng, cũng có thể bức '
          'tranh cần thêm thời gian để hiện ra. Bạn cứ tiếp tục nhìn lại đều '
          'đặn nhé, hệ thống sẽ báo cho bạn khi có điều gì đó lặp lại đủ nhiều.', 'No group stands out clearly across your last $total entries. Things '
          'may be fairly balanced, or the picture may just need more time to '
          'appear. Keep looking back regularly and the app will tell you when '
          'something repeats often enough to mean anything.'),
      _ => tr('Ba nhóm trải nghiệm của bạn đang khá cân nhau trong thời gian qua. '
          'Điều đáng chú ý ở đây không nằm ở một nhóm cụ thể, mà ở chính sự cân '
          'bằng đó. Bạn có thấy điều này giống với cảm nhận của mình về công '
          'việc hiện tại không?', 'Your three groups have been fairly even lately. What is worth '
          'noticing here is not any one group but that evenness itself. Does '
          'it match how your work actually feels to you right now?'),
    };
  }

  final dom = f.dominant!;
  final name = dom.displayName.toLowerCase();
  final count = f.pillarCount[dom] ?? 0;

  return switch (branch) {
    DeepGapBranch.outOfSync => switch (v) {
        0 => tr('Trong bộ Self-Check gần nhất, bạn đánh giá $name đang ở mức khá '
            'ổn. Nhưng khi nhìn lại, $count trong $total lần ghi nhận gần đây '
            'của bạn lại xoay quanh chính nhóm này. Khoảng cách giữa hai điều '
            'đó thường đáng để dừng lại một chút. Có thể đây là điều bạn đã '
            'quen đến mức không còn thấy nó ảnh hưởng nữa. Bạn thử nghĩ xem sao '
            'nhé.', 'In your last Self-Check you rated $name as fairly okay. Yet '
            'looking back, $count of your last $total entries circle around '
            'this very group. That distance is usually worth pausing on. It may '
            'be something you have grown so used to that you no longer see it '
            'affecting you. Worth a thought.'),
        1 => tr('Bạn từng đánh giá $name là phần đang ổn trong công việc của mình. '
            'Tuy nhiên, $count trong $total lần nhìn lại gần đây đều liên quan '
            'đến nhóm này. Hai điều đó chưa hẳn mâu thuẫn, nhưng chúng đang kể '
            'hai câu chuyện khác nhau. Điều gì có thể giải thích cho khoảng '
            'cách này?', 'You once rated $name as a part of work that was fine. But $count '
            'of your last $total look-backs relate to this group. The two are '
            'not necessarily in conflict, yet they are telling different '
            'stories. What might explain the gap?'),
        _ => tr('Có một chi tiết đáng chú ý. ${dom.displayName} là nhóm bạn tự '
            'đánh giá không đáng lo, nhưng cũng là nhóm xuất hiện nhiều nhất '
            'trong những lần bạn dừng lại để nhìn lại, $count trên $total lần. '
            'Đôi khi những điều ta cho là bình thường lại chính là thứ chiếm '
            'nhiều tâm trí nhất.', 'Here is something worth noticing. ${dom.displayName} is the group '
            'you rate as no cause for concern, and also the one that comes up '
            'most when you stop to look back, $count out of $total. Sometimes '
            'what we call normal is exactly what occupies most of our mind.'),
      },
    DeepGapBranch.aligned => switch (v) {
        0 => tr('${dom.displayName} vừa là phần bạn tự đánh giá cần được chú ý, '
            'vừa là nhóm tình huống quay lại nhiều nhất trong $total lần ghi '
            'nhận gần đây, $count lần. Cảm nhận của bạn và những gì đang thực '
            'sự diễn ra đang khớp với nhau. Đây thường là dấu hiệu cho thấy bạn '
            'đã nhìn khá rõ điều đang xảy ra với mình.', '${dom.displayName} is both the part you rate as needing '
            'attention and the group of situations that returns most across '
            'your last $total entries, $count times. What you sense and what is '
            'actually happening line up. That usually means you are seeing your '
            'own situation fairly clearly.'),
        1 => tr('Cả hai nguồn đang chỉ về cùng một hướng. Bạn tự đánh giá $name là '
            'phần cần cải thiện, và trong $total lần nhìn lại gần đây thì có '
            '$count lần thuộc về nhóm này. Khi cảm nhận và trải nghiệm thật '
            'khớp nhau như vậy, đây thường là chỗ đáng để bắt đầu.', 'Both sources point the same way. You rate $name as the part to '
            'improve, and $count of your last $total look-backs belong to this '
            'group. When feeling and lived experience match like this, it is '
            'usually the place to start.'),
        _ => tr('${dom.displayName} đang là điều rõ ràng nhất trong bức tranh hiện '
            'tại của bạn. Bạn đã tự nhận ra nó qua Self-Check, và nó cũng chiếm '
            '$count trong $total lần bạn dừng lại nhìn lại. Bạn muốn thử một '
            'bước nhỏ nào cho phần này trong tuần tới không?', '${dom.displayName} is the clearest thing in your picture right '
            'now. You spotted it yourself in the Self-Check, and it accounts '
            'for $count of the $total times you stopped to look back. Fancy '
            'trying one small step on it this coming week?'),
      },
    DeepGapBranch.mismatch => () {
        final weak = f.weakestPillar!.displayName.toLowerCase();
        return switch (v) {
          0 => tr('Bạn tự đánh giá $weak là phần khó khăn nhất hiện tại. Nhưng '
              'trong $total lần nhìn lại gần đây, nhóm quay lại nhiều nhất lại '
              'là $name, với $count lần. Đôi khi điều làm ta bận tâm mỗi ngày '
              'không trùng với điều ta nghĩ là vấn đề lớn nhất.', 'You rate $weak as the hardest part right now. But across your '
              'last $total look-backs, the group that returns most is $name, '
              'with $count. Sometimes what occupies us daily is not what we '
              'think of as the biggest problem.'),
          1 => tr('Có hai điều đang cùng nổi lên. Self-Check cho thấy $weak là '
              'phần bạn thấy khó nhất, còn các lần nhìn lại của bạn lại tập '
              'trung nhiều vào $name, $count trên $total lần. Cả hai đều là dữ '
              'liệu thật về bạn, chỉ là chúng đang nói về hai lớp khác nhau.', 'Two things are surfacing together. The Self-Check says $weak is '
              'what you find hardest, while your look-backs cluster around '
              '$name, $count out of $total. Both are real data about you; they '
              'are just speaking about different layers.'),
          _ => tr('${dom.displayName} đang là nhóm chiếm nhiều lần nhìn lại nhất '
              'của bạn, $count trên $total lần, dù đây không phải phần bạn tự '
              'đánh giá thấp nhất. Điều gì khiến nhóm này thường xuyên quay lại '
              'như vậy?', '${dom.displayName} takes up more of your look-backs than any '
              'other, $count out of $total, even though it is not the part you '
              'rate lowest. What keeps bringing this group back?'),
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
        ? tr('So với giai đoạn trước, $name đang chiếm nhiều hơn trong các lần bạn '
            'nhìn lại. Điều này có thể đến từ một thay đổi trong công việc, '
            'hoặc đơn giản là bạn đang chú ý đến nó nhiều hơn trước. Bạn có '
            'nhận ra điều gì đã khác đi không?', 'Compared with the previous stretch, $name takes up more of your '
            'look-backs. That could come from a change at work, or simply from '
            'you paying it more attention than before. Can you spot what has '
            'become different?')
        : tr('${rising.displayName} đang xuất hiện dày hơn trong thời gian gần đây '
            'so với giai đoạn trước đó. Khi một nhóm tăng dần như vậy, thường '
            'có điều gì đó trong công việc đang chuyển động. Bạn thử nhớ lại '
            'xem giai đoạn này có gì khác không nhé.', '${rising.displayName} has been showing up more densely lately than '
            'in the stretch before. When a group climbs like that, something at '
            'work is usually moving. Try to recall what has been different in '
            'this period.');
  }

  if (falling != null) {
    final name = falling.displayName.toLowerCase();
    return v == 0
        ? tr('${falling.displayName} từng chiếm phần lớn trong những lần bạn nhìn '
            'lại, nhưng gần đây đã ít dần. Đây có thể là dấu hiệu tích cực, cho '
            'thấy điều đó đã bớt chiếm tâm trí bạn. Bạn có thấy vậy không?', '${falling.displayName} used to take up most of your look-backs, but '
            'lately it has thinned out. That can be a good sign, showing it '
            'takes up less of your mind now. Does that match?')
        : tr('Có một điều đã lùi lại phía sau. $name không còn quay lại thường '
            'xuyên như giai đoạn trước. Những thay đổi kiểu này thường diễn ra '
            'âm thầm và dễ bị bỏ qua, nên đây là một điều đáng để ghi nhận cho '
            'chính mình.', 'Something has stepped back. $name no longer returns as often as it '
            'did in the previous stretch. Changes like this happen quietly and '
            'are easy to miss, so it is worth marking for yourself.');
  }

  return tr('Bức tranh của bạn khá ổn định so với giai đoạn trước, không nhóm nào '
      'tăng hay giảm rõ rệt. Sự ổn định này tự nó cũng là một thông tin, nó cho '
      'thấy điều kiện xung quanh bạn đang giữ nguyên nhịp.', 'Your picture is fairly steady compared with the previous stretch, with '
      'no group clearly up or down. That steadiness is information in itself: '
      'the conditions around you are holding their rhythm.');
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
          ? tr('Ở lần Self-Check trước, bạn đánh giá $name khá ổn trong khi đây lại '
              'là nhóm quay lại nhiều nhất trong các lần nhìn lại. Lần này, '
              'đánh giá của bạn đã sát hơn với điều đang thực sự diễn ra. Việc '
              'dừng lại nhìn lại đều đặn đang giúp bạn thấy rõ hơn chính mình.', 'At your previous Self-Check you rated $name as fairly okay while '
              'it was the group returning most in your look-backs. This time '
              'your rating sits closer to what is actually happening. Stopping '
              'to look back regularly is helping you see yourself more '
              'clearly.')
          : tr('Có một thay đổi đáng ghi nhận. Khoảng cách giữa điều bạn tự đánh '
              'giá và điều thực sự lặp lại đã thu hẹp so với lần trước. Nói '
              'cách khác, bạn đang nhìn công việc của mình rõ hơn so với vài '
              'tháng trước.', 'Here is a change worth marking. The distance between what you '
              'rate yourself and what actually repeats has narrowed since last '
              'time. Put another way, you are seeing your own work more clearly '
              'than you were a few months ago.');

    case DeepGapStatus.unchanged:
      // Không có trụ nổi trội thì không gọi tên trụ nào — câu I1 vốn có chỗ
      // chèn tên nhóm, nhưng chèn một cái tên không có thật thì tệ hơn là bỏ.
      final dom = f.dominant;
      final tail = dom == null
          ? tr('Bạn có muốn thử nhìn kỹ hơn vào những điều đang lặp lại trong thời '
              'gian tới không?', 'Would you like to look more closely at what keeps repeating over '
              'the coming while?')
          : tr('Bạn có muốn thử nhìn kỹ hơn vào nhóm '
              '${dom.displayName.toLowerCase()} trong thời gian tới không?', 'Would you like to look more closely at the '
              '${dom.displayName.toLowerCase()} group over the coming while?');
      return tr('Khoảng cách giữa cảm nhận của bạn và những gì đang lặp lại vẫn '
          'tương tự lần trước. Điều này khá bình thường, những mẫu hình đã hình '
          'thành lâu thường cần thời gian để nhận ra. $tail', 'The distance between what you sense and what repeats is much as it '
          'was last time. That is quite normal; patterns formed over a long '
          'while usually take time to recognise. $tail');

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
            ? tr('tăng lên', 'gone up')
            : tr('giảm xuống', 'gone down');
        return tr('So với lần cập nhật Self-Check trước vào $date, đánh giá của '
            'bạn về ${changed.displayName.toLowerCase()} đã $dir. Bạn có nhớ '
            'điều gì trong công việc đã thay đổi trong khoảng thời gian này '
            'không?', 'Since your previous Self-Check on $date, your rating of '
            '${changed.displayName.toLowerCase()} has $dir. Do you remember '
            'what changed at work over that period?');
      }
      if (stable != null) {
        return tr('${stable.displayName} gần như giữ nguyên so với lần bạn cập '
            'nhật vào $date. Khi một phần giữ nguyên qua thời gian, đó thường '
            'là điều kiện nền của công việc chứ không phải chuyện nhất thời.', '${stable.displayName} is much as it was when you last updated on '
            '$date. When a part holds steady over time, it is usually a '
            'baseline condition of the job rather than a passing thing.');
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
String get kDeepNoTrendYet => tr('Phần xu hướng sẽ mở ra khi bạn có thêm một khoảng thời gian nhìn lại nữa. '
    'Khi đó bạn sẽ thấy được điều gì đang tăng lên và điều gì đang lùi lại '
    'trong công việc của mình.', 'The trend part opens once you have another stretch of looking back behind '
    'you. Then you will see what is rising and what is stepping back in your '
    'work.');

/// Câu thay cho tầng 3 khi mới có một lần Self-Check.
String get kDeepOneSelfCheckOnly => tr('Sau lần cập nhật Self-Check tiếp theo, bạn sẽ thấy được cảm nhận của mình '
    'đã thay đổi ra sao so với hôm nay. Bạn có thể cập nhật bất cứ khi nào thấy '
    'công việc có gì khác đi.', 'After your next Self-Check update, you will see how your sense of things '
    'has shifted since today. Update it whenever work feels different.');

/// Câu thay cho tầng 3 khi ĐÃ có hai lần Self-Check nhưng cách nhau chưa đủ
/// [kDeepSelfCheckMinGapDays].
///
/// Phải là một câu RIÊNG. Người đã làm hai lần mà đọc [kDeepOneSelfCheckOnly]
/// sẽ hiểu là cứ làm thêm một lần nữa là mở ra, rồi làm ngay hôm sau và vẫn gặp
/// đúng câu đó — câu chữ hoá ra chỉ đường sai. Thứ còn thiếu ở đây là KHOẢNG
/// CÁCH giữa hai lần, không phải số lần.
///
/// Vẫn theo §6: nói cái sắp mở ra và lý do, không nói "chưa đủ dữ liệu" cũng
/// không đếm ngược "còn N ngày nữa".
String get kDeepSelfChecksTooClose => tr('Cảm nhận về công việc thường đổi theo tháng chứ không theo tuần, nên phần '
    'so sánh này chờ hai lần Self-Check cách nhau một quãng đủ dài. Khi bạn cập '
    'nhật lại sau một thời gian nữa, bạn sẽ thấy được điều gì đã dịch chuyển so '
    'với hôm nay.', 'How work feels tends to shift over months rather than weeks, so this '
    'comparison waits for two Self-Checks a good stretch apart. When you update '
    'again after a while, you will see what has moved since today.');

/// Câu mời cập nhật khi lần Self-Check gần nhất đã quá 3 tháng.
String deepStaleSelfCheckText(DateTime takenAt) =>
    tr('Lần Self-Check gần nhất của bạn là vào ${selfCheckDateLabel(takenAt)}. '
    'Công việc có thể đã khác đi từ đó, bạn thử cập nhật lại để bức tranh sát '
    'với hiện tại hơn nhé.', 'Your last Self-Check was on ${selfCheckDateLabel(takenAt)}. Work may have '
    'changed since, so it is worth updating to keep the picture close to now.');

/// Câu mời khi chưa đủ số lần nhìn lại để mở tầng 1.
///
/// Cố ý KHÔNG nói "cần thêm N lần nữa mới hiển thị được" — đó đúng là dạng câu
/// §6 cấm. Nói cái sẽ mở ra, không nói cái đang thiếu.
String get kDeepNotEnoughReflection => tr('Bức tranh này rõ dần theo số lần bạn dừng lại nhìn lại. Cứ ghi lại những '
    'lúc đáng nhớ trong công việc, rồi quay lại đây để đọc điều đang lặp lại '
    'phía sau chúng.', 'This picture sharpens with every time you stop to look back. Keep '
    'recording the moments at work that stay with you, then come back here to '
    'read what repeats behind them.');

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

  /// Những câu ĐƯỢC PHÉP nhờ AI viết lại ở lớp 3 (§7.3).
  ///
  /// §7.3: "Chỉ áp dụng cho tầng 1 đến tầng 3, không áp dụng cho các câu ở mục 6
  /// (trạng thái chưa đủ dữ liệu), vì các câu đó đã ngắn và cần chính xác về mặt
  /// hướng dẫn."
  ///
  /// Đúng như vậy: câu mục 6 nói cho người dùng biết còn thiếu bao nhiêu lần và
  /// làm gì để mở khoá. Nhờ AI viết lại một chỉ dẫn là mở cửa cho nó đổi con số
  /// ngưỡng hay đổi tên việc cần làm — rào chắn 1 chặn được số, không chặn được
  /// "làm bộ 15 câu" thành "hoàn thành bài đánh giá".
  ///
  /// Câu nhắc Self-Check đã cũ cũng KHÔNG vào đây, cùng một lý do.
  List<String> get polishableTexts => [
        if (branch != null) leadText,
        if (!deepTextIsGuidance(trendText)) trendText,
        if (selfCheckTrendText case final String t)
          if (!deepTextIsGuidance(t)) t,
      ];
}

/// True khi [text] là một câu CHỈ DẪN của mục 6, không phải một câu diễn giải.
///
/// So sánh bằng chính hằng thay vì dò từ khoá: ba câu đó là hằng, nên so đúng
/// bằng là chính xác tuyệt đối và không lệch khi ai đó sửa câu chữ.
bool deepTextIsGuidance(String text) =>
    text == kDeepNoTrendYet ||
    text == kDeepOneSelfCheckOnly ||
    text == kDeepSelfChecksTooClose ||
    text == kDeepNotEnoughReflection;

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
        : (deepSelfCheckTrendText(f) ??
            (f.previousSelfCheckDate == null
                ? kDeepOneSelfCheckOnly
                : kDeepSelfChecksTooClose)),
    staleSelfCheckText: takenAt != null && selfCheckIsStale(takenAt, now)
        ? deepStaleSelfCheckText(takenAt)
        : null,
  );
}
