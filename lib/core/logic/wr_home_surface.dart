// Nội dung của màn Hôm nay — dựng từ dữ liệu thật, không có chuỗi minh hoạ.
// Pure Dart, no Flutter dependencies.
//
// Bố cục lấy theo giao diện chính (`giao-dien-chinh.html` §screen-home):
//   check-in → "Hệ thống nhận ra" → "Gợi ý khi …" → "Insight gần nhất".
//
// Ba khối sau đều là GHI NHẬN, không phải diễn giải (WDA Inv.5, ranh giới
// free/premium ở [kInsightThreshold] nằm tại màn chi tiết):
//   • "Hệ thống nhận ra" chỉ đọc lại con số lặp lại của chính người dùng.
//   • "Gợi ý" chọn từ thư viện story theo trụ SCA / nhu cầu đang nổi.
//   • "Insight gần nhất" là câu chính người dùng đã xác nhận.
//
// WXS Orch. Inv.5 — Silence là lựa chọn hợp lệ: chưa đủ dữ liệu thì khối
// tương ứng biến mất hẳn, không hiện chỗ trống hay câu mời chào rỗng.

import '../models/wr_content.dart';
import '../models/wr_intelligence.dart';
import 'wr_dominant_need.dart';

/// Số lần lặp tối thiểu để hệ thống dám nói "đây là lần thứ N".
/// Một lần chưa phải mẫu hình (WXS §3.12 Inv.6).
const int kSystemNoticeThreshold = kDevelopmentFlowThreshold;

/// Tốc độ đọc tiếng Việt dùng để ước lượng thời lượng story.
const int kWordsPerMinute = 180;

// ---------------------------------------------------------------------------
// "Hệ thống nhận ra"
// ---------------------------------------------------------------------------

class SystemNotice {
  const SystemNotice({
    required this.situationCode,
    required this.situationText,
    required this.count,
  });

  final String situationCode;
  final String situationText;
  final int count;

  /// Câu hiển thị trên thẻ navy — đúng một sự kiện, không kết luận gì thêm.
  String get sentence =>
      'Đây là lần thứ $count bạn gặp tình huống $situationText.';
}

/// Tình huống lặp lại nhiều nhất, nếu đã đủ ngưỡng.
/// Trả về null khi chưa lặp lại lần nào — lúc đó thẻ không hiện.
SystemNotice? systemNotice({
  required List<PatternCount> patterns,
  required List<WrSituation> situations,
  int threshold = kSystemNoticeThreshold,
}) {
  final labels = {for (final s in situations) s.code: s.text};
  PatternCount? top;
  for (final p in patterns) {
    if (p.situationCode == null) continue;
    if (p.occurrenceCount < threshold) continue;
    if (top == null || p.occurrenceCount > top.occurrenceCount) top = p;
  }
  if (top == null) return null;
  final code = top.situationCode!;
  return SystemNotice(
    situationCode: code,
    situationText: (labels[code] ?? code).toLowerCase(),
    count: top.occurrenceCount,
  );
}

// ---------------------------------------------------------------------------
// "Gợi ý khi …"
// ---------------------------------------------------------------------------

class StorySuggestion {
  const StorySuggestion({
    required this.story,
    required this.minutes,
    required this.alreadyRead,
  });

  final WrStory story;

  /// Ước lượng từ độ dài nội dung thật, không phải con số cố định.
  final int minutes;

  /// Đã có dấu vết đọc trong Career Memory.
  final bool alreadyRead;
}

/// Số phút đọc ước lượng của một story.
int readingMinutes(String content) {
  final words = content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final minutes = (words.length / kWordsPerMinute).ceil();
  return minutes < 1 ? 1 : minutes;
}

/// Story gợi ý cho hôm nay.
///
/// Thứ tự ưu tiên — mọi bước đều dựa trên dữ liệu của chính người dùng:
///   1. cùng trụ SCA với tình huống đang lặp nhiều nhất
///   2. cùng nhu cầu chủ đạo suy ra từ hành vi
///   3. story đầu tiên chưa đọc
/// Đọc hết rồi thì vẫn gợi lại story hợp nhất, kèm dấu "đã đọc".
StorySuggestion? suggestStory({
  required List<WrStory> stories,
  required List<PatternCount> patterns,
  required List<WrSituation> situations,
  required List<CareerMemoryEvent> events,
}) {
  if (stories.isEmpty) return null;

  final readIds = <String>{
    for (final e in events)
      if (e.storyId != null) e.storyId!,
  };
  bool unread(WrStory s) => !readIds.contains(s.storyId);

  final notice = systemNotice(
    patterns: patterns,
    situations: situations,
    threshold: 1,
  );
  final topDimension = notice == null
      ? null
      : situations
          .where((s) => s.code == notice.situationCode)
          .map((s) => s.scaDimension)
          .firstOrNull;
  final need = dominantNeedFromBehaviour(patterns, situations);

  WrStory? pick;
  if (topDimension != null) {
    pick = stories
        .where((s) => s.scaDimension == topDimension && unread(s))
        .firstOrNull;
  }
  if (pick == null && need != null) {
    pick = stories.where((s) => s.humanNeed == need && unread(s)).firstOrNull;
  }
  pick ??= stories.where(unread).firstOrNull;
  pick ??= stories.first;

  return StorySuggestion(
    story: pick,
    minutes: readingMinutes(pick.storyContent),
    alreadyRead: readIds.contains(pick.storyId),
  );
}
