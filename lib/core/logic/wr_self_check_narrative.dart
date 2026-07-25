// SCA Self-Check — tầng diễn giải.
//
// Spec: Kiến trúc Dữ liệu Hai Lớp v1.2 §II
//   Free : 15 câu, kết quả tức thời cho từng trụ tại thời điểm trả lời,
//          không lưu xu hướng.
//   Paid : diễn giải sâu theo bộ narrative sẵn có (theo khoảng điểm),
//          phát hiện mất cân bằng giữa các trụ, theo dõi xu hướng qua nhiều
//          lần trả lời, đối chiếu chéo với Pattern rút ra từ Story tự do.
//
// Khoảng điểm bám theo bộ narrative đang dùng ở báo cáo SCA:
//   4.20–5.00 · 3.50–4.19 · 2.80–3.49 · 0.00–2.79
//
// Toàn bộ nội dung hiển thị bằng ngôn ngữ tình huống — không lộ mã nội bộ
// S1–S3 / C1–C3 / A1–A4 ra client (DataSpec v3).

import '../models/wr_content.dart';
import '../models/wr_intelligence.dart';
import 'wr_self_check_questions.dart';

// ---------------------------------------------------------------------------
// Khoảng điểm
// ---------------------------------------------------------------------------

enum SelfCheckBand { strong, adequate, friction, blocked }

SelfCheckBand bandForScore(double score) {
  if (score >= 4.2) return SelfCheckBand.strong;
  if (score >= 3.5) return SelfCheckBand.adequate;
  if (score >= 2.8) return SelfCheckBand.friction;
  return SelfCheckBand.blocked;
}

// ---------------------------------------------------------------------------
// Diễn giải từng trụ
// ---------------------------------------------------------------------------

class SelfCheckPillarNarrative {
  const SelfCheckPillarNarrative({
    required this.pillar,
    required this.band,
    required this.title,
    required this.text,
  });

  final SelfCheckPillar pillar;
  final SelfCheckBand band;
  final String title;
  final String text;

  String get pillarName => pillar.displayName;
}

const _narratives =
    <SelfCheckPillar, Map<SelfCheckBand, (String, String)>>{
  SelfCheckPillar.s: {
    SelfCheckBand.strong: (
      'Bạn đang có đủ sự rõ ràng để tự chủ',
      'Bạn biết mình phụ trách đến đâu, thế nào là làm xong, và tìm thông tin ở '
          'đâu khi cần. Sự rõ ràng này giúp bạn dồn năng lượng vào chất lượng '
          'công việc thay vì vào việc đoán ý người khác. Đây là nền tốt, và nó '
          'cần được giữ có chủ đích chứ không tự tồn tại mãi.'
    ),
    SelfCheckBand.adequate: (
      'Đủ rõ để chạy, chưa đủ rõ để yên tâm',
      'Trong điều kiện bình thường bạn biết mình cần làm gì. Nhưng khi ưu tiên '
          'đổi hoặc việc dính đến nhiều người, bạn vẫn phải hỏi lại hoặc tự suy '
          'đoán. Khoảng trống đó chưa gây hại rõ rệt, song nó âm thầm lấy đi '
          'thời gian mỗi tuần và sẽ lộ ra khi khối lượng công việc tăng lên.'
    ),
    SelfCheckBand.friction: (
      'Sự mơ hồ đang lấy đi một phần năng lượng của bạn',
      'Bạn đang phải tự làm rõ khá nhiều thứ trước khi có thể bắt tay vào việc: '
          'ai phụ trách phần nào, thế nào là đủ tốt, thông tin nằm ở đâu. Phần '
          'công sức đó không hiện lên trong kết quả nhưng vẫn tiêu tốn thật. '
          'Đây là dấu hiệu của điều kiện làm việc, không phải của năng lực bạn.'
    ),
    SelfCheckBand.blocked: (
      'Bạn đang làm việc mà thiếu những mốc cơ bản để dựa vào',
      'Kỳ vọng chưa được nói rõ, ranh giới trách nhiệm chưa được vẽ, thông tin '
          'đến muộn hoặc không đến. Ở mức này, dù bạn cố đến đâu thì kết quả '
          'vẫn phụ thuộc nhiều vào may rủi. Điều cần thay đổi trước không phải '
          'là bạn cố hơn, mà là làm rõ được một vài mốc quan trọng nhất.'
    ),
  },
  SelfCheckPillar.c: {
    SelfCheckBand.strong: (
      'Bạn đang ở một môi trường đủ an toàn để là chính mình',
      'Bạn tin được người làm cùng, nói thật mà không phải cân nhắc quá nhiều, '
          'và bất đồng có chỗ để đưa ra bàn. Đây là điều kiện hiếm và nó tạo ra '
          'khác biệt lớn trong khả năng học hỏi của cả bạn lẫn nhóm.'
    ),
    SelfCheckBand.adequate: (
      'Quan hệ ổn khi thuận, chưa chắc chắn khi căng',
      'Ở nhịp bình thường mọi thứ diễn ra dễ chịu. Nhưng khi có áp lực, sai sót '
          'hoặc bất đồng, mức độ tin cậy và chất lượng đối thoại chưa đủ vững '
          'để mọi người nói thẳng. Đó là lúc những điều quan trọng nhất thường '
          'không được nói ra.'
    ),
    SelfCheckBand.friction: (
      'Bạn đang phải giữ ý nhiều hơn mức đáng phải giữ',
      'Bạn cân nhắc trước khi nói, tránh vài cuộc trò chuyện, và không chắc ý '
          'kiến của mình có được xem xét thật không. Đây không phải bạn thiếu '
          'dũng cảm — đó là phản ứng hợp lý với một môi trường chưa đủ an toàn. '
          'Cái giá là bạn và nhóm mất dần khả năng học từ nhau.'
    ),
    SelfCheckBand.blocked: (
      'Chi phí tâm lý bạn đang trả là rất cao',
      'Niềm tin thấp, nói thật thì có rủi ro, mâu thuẫn âm ỉ mà không có lối '
          'ra. Ở mức này phần lớn năng lượng của bạn đi vào việc phòng thủ chứ '
          'không phải vào công việc. Điều này ảnh hưởng thật đến sức khoẻ tinh '
          'thần, và nó xứng đáng được nhìn nhận nghiêm túc.'
    ),
  },
  SelfCheckPillar.a: {
    SelfCheckBand.strong: (
      'Cách bạn làm việc đang giúp bạn tiến lên thật',
      'Bạn thấy việc mình làm nối với điều gì lớn hơn, nhịp làm việc đủ ổn để '
          'chủ động, và bạn có khoảng dừng để nhìn lại. Nhờ vậy mỗi lần làm là '
          'một lần học chứ không chỉ là hoàn thành nhiệm vụ.'
    ),
    SelfCheckBand.adequate: (
      'Có nhịp, nhưng chưa đều',
      'Bạn có lúc làm việc sâu và có lúc bị cuốn theo việc gấp. Việc nhìn lại '
          'diễn ra nhưng chưa thành thói quen đủ đều để tạo ra thay đổi rõ. Ở '
          'mức này bạn vẫn tiến, chỉ là chậm hơn công sức bạn bỏ ra.'
    ),
    SelfCheckBand.friction: (
      'Bạn đang bận hơn là đang tiến',
      'Công việc bị cắt ngang thường xuyên, việc quan trọng hay thua việc gấp, '
          'và bạn ít có dịp dừng lại xem điều gì đang thực sự diễn ra. Đó là lý '
          'do cảm giác "làm rất nhiều mà không thấy mình đi tới đâu" xuất hiện.'
    ),
    SelfCheckBand.blocked: (
      'Bạn đang chạy mà không có cơ chế nào giữ hướng',
      'Mục tiêu không rõ hoặc đổi liên tục, nhịp làm việc thiếu cấu trúc, và '
          'những gì đã trải qua chưa bao giờ được nhìn lại đủ sâu để thành bài '
          'học. Ở mức này, kinh nghiệm tích lại nhưng năng lực thì không. Chỗ '
          'cần bắt đầu là một khoảng dừng đều đặn, dù rất ngắn.'
    ),
  },
};

SelfCheckPillarNarrative pillarNarrative(SelfCheckPillar pillar, double score) {
  final band = bandForScore(score);
  final (title, text) = _narratives[pillar]![band]!;
  return SelfCheckPillarNarrative(
    pillar: pillar,
    band: band,
    title: title,
    text: text,
  );
}

/// Trụ có điểm thấp nhất. Hoà điểm → ưu tiên S, rồi C, rồi A (ổn định).
SelfCheckPillar lowestPillar(double s, double c, double a) {
  if (s <= c && s <= a) return SelfCheckPillar.s;
  if (c <= a) return SelfCheckPillar.c;
  return SelfCheckPillar.a;
}

// ---------------------------------------------------------------------------
// Mất cân bằng giữa các trụ
// ---------------------------------------------------------------------------

/// Ngưỡng lệch giữa hai trụ để coi là mất cân bằng (đồng bộ với báo cáo SCA).
const kImbalanceThreshold = 0.8;

/// Ngưỡng "thấp rõ rệt": điểm dưới mức này và kém trung bình ≥ 1.0.
const kNotablyLowThreshold = 2.8;

enum PillarImbalance {
  allLow,
  sNotablyLow,
  cNotablyLow,
  aNotablyLow,
  aHighScLow,
  cHighSLow,
  sHighCLow,
}

/// Phát hiện mất cân bằng giữa ba trụ. Trả về null khi ba trụ tương đối đều
/// hoặc khi thiếu điểm.
PillarImbalance? detectPillarImbalance(double? s, double? c, double? a) {
  if (s == null || c == null || a == null) return null;

  if (s < kNotablyLowThreshold &&
      c < kNotablyLowThreshold &&
      a < kNotablyLowThreshold) {
    return PillarImbalance.allLow;
  }

  // Một trụ thấp rõ rệt so với ít nhất một trụ khác.
  if (s < kNotablyLowThreshold && (c - s >= 1.0 || a - s >= 1.0)) {
    return PillarImbalance.sNotablyLow;
  }
  if (c < kNotablyLowThreshold && (s - c >= 1.0 || a - c >= 1.0)) {
    return PillarImbalance.cNotablyLow;
  }
  if (a < kNotablyLowThreshold && (s - a >= 1.0 || c - a >= 1.0)) {
    return PillarImbalance.aNotablyLow;
  }

  final maxDiff = [
    (s - c).abs(),
    (s - a).abs(),
    (c - a).abs(),
  ].reduce((x, y) => x > y ? x : y);
  if (maxDiff < kImbalanceThreshold) return null;

  if (a - s >= kImbalanceThreshold && a - c >= kImbalanceThreshold) {
    return PillarImbalance.aHighScLow;
  }
  if ((s - c).abs() >= kImbalanceThreshold) {
    return c > s ? PillarImbalance.cHighSLow : PillarImbalance.sHighCLow;
  }
  // Lệch nằm ở cặp có liên quan tới cách làm việc.
  return a > s && a > c ? PillarImbalance.aHighScLow : PillarImbalance.aNotablyLow;
}

String imbalanceNarrative(PillarImbalance key) => switch (key) {
      PillarImbalance.allLow =>
        'Cả ba mặt đều đang ở mức thấp cùng lúc. Khi mọi thứ cùng khó, rất dễ '
            'kết luận rằng vấn đề nằm ở mình. Thường thì không phải vậy — đó là '
            'dấu hiệu điều kiện xung quanh đang thiếu nhiều thứ nền tảng cùng '
            'lúc. Đừng cố sửa hết. Chọn một mặt duy nhất và bắt đầu từ đó.',
      PillarImbalance.sNotablyLow =>
        'Quan hệ và cách làm việc của bạn ổn hơn hẳn sự rõ ràng. Điều đó có '
            'nghĩa bạn đang bù đắp cho sự mơ hồ bằng nỗ lực cá nhân và bằng vốn '
            'quan hệ. Cách này chạy được một thời gian, nhưng nó tốn của bạn '
            'nhiều hơn mức cần thiết và sẽ đuối khi công việc phức tạp lên.',
      PillarImbalance.cNotablyLow =>
        'Bạn biết rõ mình cần làm gì và làm được, nhưng phải làm trong một môi '
            'trường mà nói thật là có rủi ro. Đây là dạng mất cân bằng mệt mỏi '
            'nhất, vì bên ngoài mọi thứ trông vẫn ổn trong khi bên trong bạn '
            'phải giữ ý liên tục. Nó hiếm khi tự tốt lên theo thời gian.',
      PillarImbalance.aNotablyLow =>
        'Sự rõ ràng và quan hệ đang tốt hơn hẳn cách bạn làm việc. Nghĩa là bối '
            'cảnh xung quanh không phải vấn đề chính — chỗ nghẽn nằm ở nhịp làm '
            'việc và ở việc thiếu khoảng dừng để nhìn lại. Đây cũng là mặt bạn '
            'có nhiều quyền chủ động nhất để thay đổi.',
      PillarImbalance.aHighScLow =>
        'Bạn đang duy trì được nhịp làm việc và khả năng học hỏi tốt hơn hẳn '
            'điều kiện xung quanh cho phép. Đó là một năng lực thật, nhưng nó '
            'cũng có nghĩa bạn đang tự bù cho những gì hệ thống chưa hỗ trợ. '
            'Hãy để ý: kiểu bù đắp này rất dễ dẫn tới kiệt sức âm thầm.',
      PillarImbalance.cHighSLow =>
        'Quan hệ trong nhóm tốt hơn sự rõ ràng về công việc. Nhóm của bạn đang '
            'lấy sự thân thiện để bù cho việc thiếu quy ước rõ ràng. Điều đó '
            'giúp mọi thứ dễ chịu, nhưng nó khiến những vấn đề về vai trò và '
            'ranh giới không bao giờ được nói ra đúng lúc.',
      PillarImbalance.sHighCLow =>
        'Công việc được tổ chức rõ hơn hẳn chất lượng quan hệ. Quy trình chạy '
            'tốt nhưng người ta chưa thực sự nói được với nhau. Kiểu mất cân '
            'bằng này thường tạo ra một môi trường vận hành trơn tru trên giấy '
            'mà vẫn khiến người trong đó thấy đơn độc.',
    };

// ---------------------------------------------------------------------------
// Xu hướng qua nhiều lần trả lời (Paid)
// ---------------------------------------------------------------------------

class SelfCheckTrend {
  const SelfCheckTrend({
    required this.latest,
    required this.previous,
    required this.takenCount,
  });

  final ScaSelfCheckResponse latest;
  final ScaSelfCheckResponse previous;

  /// Số lần trả lời có đủ điểm được dùng để tính xu hướng.
  final int takenCount;

  double get structureDelta =>
      (latest.structureScore ?? 0) - (previous.structureScore ?? 0);
  double get cultureDelta =>
      (latest.cultureScore ?? 0) - (previous.cultureScore ?? 0);
  double get activityDelta =>
      (latest.activityScore ?? 0) - (previous.activityScore ?? 0);

  double get averageDelta =>
      (structureDelta + cultureDelta + activityDelta) / 3;

  /// Mô tả xu hướng bằng ngôn ngữ đời thường.
  String get summary {
    final d = averageDelta;
    if (d.abs() < 0.15) {
      return 'So với lần trước, bức tranh của bạn gần như không đổi. Điều đó '
          'không xấu — nó cho thấy những gì bạn đang gặp là điều kiện ổn định '
          'chứ không phải một tuần tồi tệ.';
    }
    if (d > 0) {
      return 'So với lần trước, bức tranh của bạn có cải thiện. Đáng để nhìn '
          'lại xem điều gì đã thay đổi, vì thứ tạo ra khác biệt đó thường lặp '
          'lại được.';
    }
    return 'So với lần trước, bức tranh của bạn đi xuống. Đây là lúc nên nhìn '
        'kỹ điều gì đã khác đi — thường sẽ có một thay đổi cụ thể nào đó ở '
        'công việc hoặc ở nhóm đứng phía sau.';
  }
}

/// Xu hướng giữa lần trả lời mới nhất và lần liền trước.
/// Trả về null khi chưa có đủ 2 lần trả lời có điểm.
SelfCheckTrend? trendFromHistory(List<ScaSelfCheckResponse> history) {
  final scored = history
      .where((r) =>
          r.structureScore != null &&
          r.cultureScore != null &&
          r.activityScore != null)
      .toList()
    ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
  if (scored.length < 2) return null;
  return SelfCheckTrend(
    latest: scored[0],
    previous: scored[1],
    takenCount: scored.length,
  );
}

// ---------------------------------------------------------------------------
// Đối chiếu chéo với Pattern (Paid)
// ---------------------------------------------------------------------------

/// Chiều SCA thuộc về trụ nào.
SelfCheckPillar pillarOfDimension(ScaDimension d) => switch (d) {
      ScaDimension.s1 || ScaDimension.s2 || ScaDimension.s3 =>
        SelfCheckPillar.s,
      ScaDimension.c1 || ScaDimension.c2 || ScaDimension.c3 =>
        SelfCheckPillar.c,
      _ => SelfCheckPillar.a,
    };

/// Các pattern lặp lại thuộc [pillar], nhiều lần nhất trước.
List<PatternCount> patternsForPillar(
  SelfCheckPillar pillar,
  List<PatternCount> patterns, {
  int limit = 3,
}) {
  final matched = patterns
      .where((p) =>
          p.scaDimension != null && pillarOfDimension(p.scaDimension!) == pillar)
      .toList()
    ..sort((a, b) => b.occurrenceCount.compareTo(a.occurrenceCount));
  return matched.take(limit).toList();
}
