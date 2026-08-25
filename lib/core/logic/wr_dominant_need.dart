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
// Câu đọc lên ở khối "Điều bạn đang tìm kiếm"
//
// LỊCH SỬ, vì chỗ này đã đổi hai lần theo hai hướng ngược nhau:
//
//   · Trước 04/08 là ba khối chữ gán cứng theo nhu cầu. Khách bác vì ai rơi vào
//     cùng một nhu cầu thì đọc y hệt nhau.
//   · Từ 04/08 đổi sang đọc `expected_outcome` / `aha_message` của tình huống
//     lặp nhiều nhất — tức nội dung riêng theo từng chip.
//   · Họp 26_1: khách bác bản đó. Khối này đang hiện câu Insight (ví dụ "Sự
//     đồng thuận không phải lúc nào cũng là dấu hiệu của sự đồng lòng…"), trong
//     khi nhãn của nó hứa NHU CẦU. Khách gọi thẳng tên câu mình muốn thấy:
//     "được lắng nghe và thể hiện quan điểm" — chính là [needSeekingSentence].
//
// Nên khối này quay về đọc NHU CẦU. Điều đó KHÔNG kéo lại lỗi của bản trước
// 04/08: cái sai hồi đó là ba khối diễn giải gán cứng chồng lên nhau, còn ở đây
// là một câu duy nhất, và nhu cầu thì vẫn suy từ dữ liệu thật
// ([dominantNeedFromBehaviour] đọc recentSituationIds).
//
// Phần đọc vị riêng theo từng tình huống không mất đi — nó nằm ở màn chi tiết
// một điều lặp lại, đúng chỗ người dùng đang hỏi về CHÍNH tình huống đó.
// ---------------------------------------------------------------------------

/// Câu đọc lên ở khối "Điều bạn đang tìm kiếm" của màn Hiểu mình.
///
/// Đây là định nghĩa của chính nhu cầu, không phải diễn giải riêng cho một
/// người — phần diễn giải nằm ở màn chi tiết. Nhu cầu nào được chọn mới là
/// dữ liệu thật: nó suy ra từ những tình huống đang lặp lại của người dùng.
///
/// CẢ BỐN CÂU ĐỀU MỞ BẰNG "ĐƯỢC" — và đó là điều kiện, không phải nhịp văn.
///
/// Khách hỏi 2026-08-25: "người đó không có ai lắng nghe thì hiển thị là CẦN
/// được lắng nghe hay sao đó". Bản trước có hai câu viết ở thể trần thuật —
/// "Thấy mình đang đi về phía trước", "Biết rõ mình đang ở đâu" — nên đọc ra
/// thành MÔ TẢ một trạng thái người dùng đang có. Với chính người vừa mười một
/// lần chọn "Tôi đang đi rất nhanh, nhưng đi đâu?", đó là câu nói ngược lại
/// điều họ vừa kể. Nhãn "Điều bạn đang tìm kiếm" cứu được nghĩa, nhưng bắt
/// người đọc phải ghép lại mới hiểu đúng.
///
/// Câu duy nhất khách đã duyệt (họp 26_1, và cũng là câu in trong mockup v16)
/// là "Được lắng nghe và thể hiện quan điểm." — thể bị động, đọc ra ngay thành
/// điều còn thiếu. Ba câu kia nay kéo về đúng khuôn ấy; câu của khách giữ
/// nguyên từng chữ.
String needSeekingSentence(HumanNeed need) => switch (need) {
      HumanNeed.roRang =>
        'Được biết rõ mình đang ở đâu và người khác chờ đợi điều gì.',
      HumanNeed.ketNoi => 'Được lắng nghe và thể hiện quan điểm.',
      HumanNeed.thichNghi => 'Được là chính mình khi mọi thứ đổi thay.',
      HumanNeed.phatTrien => 'Được thấy mình đang đi về phía trước.',
    };
