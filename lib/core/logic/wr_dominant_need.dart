// Shared helpers for computing the dominant HumanNeed from behaviour or SCA self-check.
// Used by WrDiscoverScreen and WrGrowthScreen.
// Pure Dart — no Flutter dependencies.

import '../models/wr_content.dart';
import '../models/wr_intelligence.dart';

// ---------------------------------------------------------------------------
// dominantNeedFromBehaviour
// ---------------------------------------------------------------------------

/// Nhu cầu chủ đạo, đọc từ [recent] — recentSituationIds.
///
/// v2.0 §4.3: "nhóm recentSituationIds theo trường need của từng Situation, lấy
/// nhu cầu xuất hiện nhiều nhất. Nếu recentSituationIds rỗng, hiển thị trạng
/// thái chưa đủ dữ liệu, không suy đoán."
///
/// Trước bản 2026-07-31 hàm này đọc `wr_pattern_counts` — con số tích luỹ vĩnh
/// viễn, còn cộng cả những lần ghi qua màn `/wr/situation` cũ. §4.3 cấm: chỉ
/// recentSituationIds được trả lời câu hỏi "đang phản chiếu nhiều về điều gì".
HumanNeed? dominantNeedFromBehaviour(
  List<String> recent,
  List<WrSituation> situations,
) {
  if (recent.isEmpty) return null;
  final codeToNeed = <String, HumanNeed>{
    for (final s in situations)
      if (s.humanNeed != null) s.code: s.humanNeed!,
  };
  final tally = <HumanNeed, int>{};
  for (final code in recent) {
    final need = codeToNeed[code];
    if (need == null) continue;
    tally[need] = (tally[need] ?? 0) + 1;
  }
  if (tally.isEmpty) return null;
  return tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

// ---------------------------------------------------------------------------
// dominantNeedFromSelfCheck
// ---------------------------------------------------------------------------

/// Map SCA lowest pillar → HumanNeed (fallback when no patterns yet).
/// S → roRang, C → ketNoi, A → phatTrien.
/// Tie-break: C > S > A.
/// Null scores treated as 5.0 (no problem in that pillar).
HumanNeed dominantNeedFromSelfCheck(ScaSelfCheckResponse r) {
  final s = r.structureScore ?? 5.0;
  final c = r.cultureScore ?? 5.0;
  final a = r.activityScore ?? 5.0;
  final minScore = [s, c, a].reduce((a, b) => a < b ? a : b);
  // Tie-break: C > S > A (C wins if tied)
  if (c == minScore) return HumanNeed.ketNoi;
  if (s == minScore) return HumanNeed.roRang;
  return HumanNeed.phatTrien;
}

// ---------------------------------------------------------------------------
// needPillarLetter
// ---------------------------------------------------------------------------

/// Returns the SCA pillar letter for matching [PracticeTheme.scaDimension.dbValue].
/// roRang → 'S', ketNoi → 'C', thichNghi → 'A', phatTrien → 'A'.
String needPillarLetter(HumanNeed need) => switch (need) {
      HumanNeed.roRang => 'S',
      HumanNeed.ketNoi => 'C',
      HumanNeed.thichNghi => 'A',
      HumanNeed.phatTrien => 'A',
    };

// ---------------------------------------------------------------------------
// needSeekingLabel
// ---------------------------------------------------------------------------

/// Tên ngắn của nhu cầu — dùng làm nhãn phân loại nội dung.
String needLabel(HumanNeed need) => switch (need) {
      HumanNeed.roRang => 'Rõ ràng',
      HumanNeed.ketNoi => 'Kết nối',
      HumanNeed.thichNghi => 'Thích nghi',
      HumanNeed.phatTrien => 'Phát triển',
    };

/// Vietnamese label for what the user is seeking, used in suggestion card reason.
String needSeekingLabel(HumanNeed need) => switch (need) {
      HumanNeed.roRang => 'sự rõ ràng',
      HumanNeed.ketNoi => 'sự kết nối',
      HumanNeed.thichNghi => 'sự thích nghi',
      HumanNeed.phatTrien => 'sự phát triển',
    };

// ---------------------------------------------------------------------------
// Đọc vị nhu cầu — ba lớp, bằng ngôn ngữ đời thường (yêu cầu khách 2026-07-29)
// ---------------------------------------------------------------------------

/// Ba lớp diễn giải của một nhu cầu, viết bằng lời thường.
///
/// Không lớp nào được nhắc tới mã nội bộ (S1, C2, A3…) hay chữ "SCA": người
/// dùng đọc điều họ đang trải qua, không đọc bộ khung phân loại của hệ thống.
class NeedReading {
  const NeedReading({
    required this.expectedOutcome,
    required this.coreNeed,
    required this.perspectiveLabel,
    required this.perspectiveText,
  });

  /// Lớp 1 — điều người dùng đang mong tới.
  final String expectedOutcome;

  /// Lớp 2 — nhu cầu đứng sau mong đợi đó.
  final String coreNeed;

  /// Lớp 3 — mặt nào của công việc đang bị chạm tới (tên đời thường của trụ).
  final String perspectiveLabel;

  /// Lớp 3 — câu đọc vị: điều người dùng tưởng là nguyên nhân, và điều thật sự
  /// đứng sau. Đây là phần khách gọi là "diễn giải thấu cảm".
  final String perspectiveText;
}

/// Ba lớp diễn giải cho [need].
NeedReading needReading(HumanNeed need) => switch (need) {
      HumanNeed.roRang => const NeedReading(
          expectedOutcome:
              'Biết mình đang ở đâu và việc nào đáng làm trước.',
          coreNeed:
              'Sự rõ ràng, rõ vai trò của mình, rõ điều người khác chờ đợi.',
          perspectiveLabel: 'Sự rõ ràng',
          perspectiveText:
              'Điều làm bạn mệt nhiều khả năng không phải vì nhiều việc, mà '
              'vì chưa rõ vai trò, kỳ vọng và thứ tự ưu tiên.',
        ),
      HumanNeed.ketNoi => const NeedReading(
          expectedOutcome:
              'Nói được điều mình nghĩ mà vẫn thấy an toàn.',
          coreNeed:
              'Sự kết nối, được lắng nghe, và được nhìn thấy đúng như mình.',
          perspectiveLabel: 'Mối quan hệ',
          perspectiveText:
              'Điều giữ bạn im lặng thường không phải vì thiếu ý kiến, mà vì '
              'chưa chắc nói ra thì có an toàn hay không.',
        ),
      HumanNeed.thichNghi => const NeedReading(
          expectedOutcome:
              'Giữ được nhịp của mình khi mọi thứ đổi thay.',
          coreNeed:
              'Sự thích nghi, đổi cách làm mà không đánh mất chính mình.',
          perspectiveLabel: 'Cách làm việc',
          perspectiveText:
              'Cảm giác đuối sức thường đến từ một cách làm cũ đặt vào hoàn '
              'cảnh đã khác, chứ không phải từ việc bạn kém đi.',
        ),
      HumanNeed.phatTrien => const NeedReading(
          expectedOutcome:
              'Thấy rõ mình đang đi về phía trước.',
          coreNeed:
              'Sự phát triển, làm được điều hôm qua mình chưa làm được.',
          perspectiveLabel: 'Cách làm việc',
          perspectiveText:
              'Cảm giác mắc kẹt thường không phải vì bạn đứng yên, mà vì chưa '
              'có gì đánh dấu lại những bước bạn đã đi.',
        ),
    };

/// Câu đọc lên ở khối "Điều bạn đang tìm kiếm" của màn Hiểu mình.
///
/// Đây là định nghĩa của chính nhu cầu, không phải diễn giải riêng cho một
/// người — phần diễn giải nằm ở màn chi tiết. Nhu cầu nào được chọn mới là
/// dữ liệu thật: nó suy ra từ những tình huống đang lặp lại của người dùng.
String needSeekingSentence(HumanNeed need) => switch (need) {
      HumanNeed.roRang => 'Biết rõ mình đang ở đâu và được chờ đợi điều gì.',
      HumanNeed.ketNoi => 'Được lắng nghe và thể hiện quan điểm.',
      HumanNeed.thichNghi => 'Giữ được mình khi mọi thứ đổi thay.',
      HumanNeed.phatTrien => 'Thấy mình đang đi về phía trước.',
    };
