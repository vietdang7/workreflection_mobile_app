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
// Câu insight ở khối "Điều bạn đang tìm kiếm"
//
// Trước 2026-08-04 chỗ này là ba khối chữ (`NeedReading`) gán cứng: đúng bốn bộ
// text viết sẵn trong một switch trên HumanNeed. Hệ quả là mọi người rơi vào
// cùng một nhu cầu đọc y hệt nhau, và nội dung không nhúc nhích dù người dùng
// đã nhìn lại bao nhiêu lần hay lặp lại tình huống nào. Khách bác: màn Hiểu
// mình phải phản chiếu dữ liệu thật, và chỉ cần MỘT câu chính chứ không phải ba
// khối diễn giải.
//
// Bản này đọc từ nội dung của chính tình huống người dùng đang lặp nhiều nhất
// trong recentSituationIds. Nội dung đó đã có sẵn trong DB, per-situation:
//
//   • wr_situations.expected_outcome — "Tôi muốn…", đúng nghĩa của nhãn
//     "ĐIỀU BẠN ĐANG TÌM KIẾM". Có ở 60 chip Tầng 1 và 10 tình huống tích cực.
//   • wr_stories.aha_message — câu đọc vị ngắn, mã trùng chip (v2.0 §2.2), nên
//     phủ được cả 100 chip đang hoạt động của Career Situation Library.
//
// Chỉ khi cả hai đều trống mới rơi về [needSeekingSentence] — định nghĩa của
// nhu cầu, vẫn là câu chung nhưng chỉ còn là lưới an toàn khi nội dung thiếu,
// không còn là đường đi mặc định.
// ---------------------------------------------------------------------------

/// Mã tình huống xuất hiện nhiều nhất trong [recent].
///
/// Hoà thì lấy cái GẦN ĐÂY nhất — [recent] xếp mới nhất đứng đầu, nên chỉ cần
/// giữ mã gặp trước. Không có ngưỡng [kRepeatedSituationsMinCount] ở đây: ngưỡng
/// đó chỉ chặn phần hiển thị "Tình huống lặp lại", còn khối này đọc từ lần đầu.
String? topSituationCode(List<String> recent) {
  if (recent.isEmpty) return null;
  final tally = <String, int>{};
  for (final code in recent) {
    tally[code] = (tally[code] ?? 0) + 1;
  }
  String? best;
  var bestCount = 0;
  for (final code in recent) {
    final count = tally[code]!;
    if (count > bestCount) {
      best = code;
      bestCount = count;
    }
  }
  return best;
}

/// Câu insight đọc từ dữ liệu thật, hoặc null khi không có nội dung nào.
///
/// [recent] là recentSituationIds — lịch sử Reflect thật của người dùng.
String? seekingInsight({
  required List<String> recent,
  required List<WrSituation> situations,
  required List<WrStory> stories,
}) {
  final code = topSituationCode(recent);
  if (code == null) return null;

  for (final s in situations) {
    if (s.code != code) continue;
    final text = _clean(s.expectedOutcome);
    if (text != null) return text;
    break;
  }
  for (final story in stories) {
    if (story.storyId != code) continue;
    return _clean(story.ahaMessage);
  }
  return null;
}

/// Bỏ khoảng trắng thừa và gộp xuống dòng — câu này hiện canh giữa một dòng
/// lớn, giữ nguyên `\n` của nội dung DB sẽ vỡ bố cục.
String? _clean(String? raw) {
  if (raw == null) return null;
  final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.isEmpty ? null : text;
}

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
