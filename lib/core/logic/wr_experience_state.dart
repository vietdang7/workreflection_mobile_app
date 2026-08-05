// Experience State Machine — WXS v1.0 §4.4 + HXA v1.0 §3.2, §3.6, §3.8.
// Pure Dart, no Flutter dependencies.
//
// Hai luật không được phá:
//   1. Không nhảy cóc (WXS §4.4): Captured → Committed, Exploring → Integrated,
//      Emerging → Meaning* đều bất hợp lệ. Mọi transition phải bảo toàn
//      Human Understanding.
//   2. Người dùng không chọn Pattern theo tên (HXA Invariant 5): Pattern tiếp
//      theo được suy ra từ Human Moment Archetype và các Pattern đã đi qua.

import 'package:workreflection_mobile/core/models/wr_episode.dart';

// ---------------------------------------------------------------------------
// Transition table — WXS §4.4
// ---------------------------------------------------------------------------

const Map<ExperienceState, Set<ExperienceState>> _allowedTransitions = {
  ExperienceState.emerging: {
    ExperienceState.captured,
  },
  ExperienceState.captured: {
    ExperienceState.exploring,
    // Bỏ dở ngay sau khi ghi nhận — Episode ngủ, không mất.
    ExperienceState.dormant,
  },
  ExperienceState.exploring: {
    ExperienceState.meaningForming,
    ExperienceState.dormant,
  },
  ExperienceState.meaningForming: {
    // Quay lại đào sâu thêm khi ý nghĩa chưa rõ.
    ExperienceState.exploring,
    ExperienceState.meaningConfirmed,
    ExperienceState.dormant,
  },
  ExperienceState.meaningConfirmed: {
    ExperienceState.committed,
    // Phiên đủ ý nghĩa nhưng chưa muốn cam kết hành động — vẫn được lưu.
    ExperienceState.integrated,
    ExperienceState.dormant,
  },
  ExperienceState.committed: {
    ExperienceState.integrated,
  },
  ExperienceState.integrated: {
    ExperienceState.dormant,
    ExperienceState.reactivated,
  },
  ExperienceState.dormant: {
    ExperienceState.reactivated,
  },
  // Reactivated luôn quay về Exploring (WXS §4.3 State 9).
  ExperienceState.reactivated: {
    ExperienceState.exploring,
  },
};

/// True khi [from] → [to] là transition hợp lệ theo WXS §4.4.
bool canTransition(ExperienceState from, ExperienceState to) {
  return _allowedTransitions[from]?.contains(to) ?? false;
}

/// Các state có thể đi tới từ [from].
Set<ExperienceState> allowedNextStates(ExperienceState from) {
  return _allowedTransitions[from] ?? const {};
}

/// Ném [StateError] nếu transition bất hợp lệ. Dùng ở tầng repository trước
/// khi ghi xuống DB, để một lỗi UI không bao giờ phá được Reflection Integrity.
void assertTransition(ExperienceState from, ExperienceState to) {
  if (!canTransition(from, to)) {
    throw StateError(
      'Transition bất hợp lệ: ${from.dbValue} → ${to.dbValue}. '
      'WXS §4.4, Reflection không có đường tắt.',
    );
  }
}

// ---------------------------------------------------------------------------
// Pattern sequence per Archetype — HXA §3.6 Session Grammar
//
// ⚠ TỪ 2026-07-31 CÁC CHUỖI NÀY KHÔNG CÒN ĐIỀU KHIỂN LUỒNG NGƯỜI DÙNG ĐI.
//
// Kiến trúc Dữ liệu v2.0 §V chốt một luồng 5 bước CỐ ĐỊNH cho mọi phiên: chọn
// tình huống → chi tiết (tuỳ chọn) → Aha → Lựa chọn → đã lưu. Xem
// `lib/core/logic/wr_reflect_flow.dart`.
//
// Chạy theo chuỗi của archetype là đúng chỗ đã hỏng: bước đầu của mọi chuỗi là
// `notice` (một ô chữ trống), chip tình huống nằm ở `name`, và `name` VẮNG MẶT
// trong chuỗi của `growth` lẫn `recovery` — nên hai archetype đó không bao giờ
// ghi được `situation_code`.
//
// Giữ lại vì: `promptFor` còn dùng để đọc lại ghi chú của các Episode CŨ ở màn
// chi tiết Hành trình, và bảng này là tài liệu HXA §3.6. Đừng nối nó lại vào
// điều hướng.
// ---------------------------------------------------------------------------

const Map<HumanMoment, List<ReflectionPattern>> patternSequences = {
  HumanMoment.arrival: [
    ReflectionPattern.notice,
    ReflectionPattern.name,
    ReflectionPattern.preserve,
  ],
  HumanMoment.confusion: [
    ReflectionPattern.notice,
    ReflectionPattern.name,
    ReflectionPattern.explore,
    ReflectionPattern.preserve,
  ],
  HumanMoment.decision: [
    ReflectionPattern.notice,
    ReflectionPattern.name,
    ReflectionPattern.explore,
    ReflectionPattern.reframe,
    ReflectionPattern.commit,
  ],
  HumanMoment.growth: [
    ReflectionPattern.notice,
    ReflectionPattern.explore,
    ReflectionPattern.commit,
    ReflectionPattern.preserve,
  ],
  // HXA §3.2: Recovery mặc định bắt đầu Notice → Explore, không bắt đầu Commit.
  HumanMoment.recovery: [
    ReflectionPattern.notice,
    ReflectionPattern.explore,
    ReflectionPattern.preserve,
  ],
  HumanMoment.celebration: [
    ReflectionPattern.notice,
    ReflectionPattern.name,
    ReflectionPattern.preserve,
  ],
};

/// Pattern kế tiếp cho [moment] khi đã đi qua [done].
/// Trả về null khi chuỗi Pattern đã hết — lúc đó Episode sẵn sàng sang
/// Meaning Forming.
ReflectionPattern? nextPattern(
  HumanMoment moment,
  List<ReflectionPattern> done,
) {
  final sequence = patternSequences[moment] ?? const <ReflectionPattern>[];
  for (final pattern in sequence) {
    if (!done.contains(pattern)) return pattern;
  }
  return null;
}

/// Tổng số bước phản tư của [moment] — dùng cho thanh tiến trình.
int patternCount(HumanMoment moment) =>
    (patternSequences[moment] ?? const <ReflectionPattern>[]).length;

// ---------------------------------------------------------------------------
// Câu hỏi dẫn dắt — HXA §3.5. Một câu cho mỗi (Archetype × Pattern).
// AI có thể thay thế về sau (WIA Layer 3); đây là bản tĩnh, luôn có sẵn.
// ---------------------------------------------------------------------------

const Map<ReflectionPattern, String> _defaultPrompts = {
  ReflectionPattern.notice: 'Điều gì đang chiếm nhiều năng lượng của bạn nhất lúc này?',
  ReflectionPattern.name: 'Nếu gọi tên điều bạn đang trải qua bằng một câu, bạn sẽ nói gì?',
  ReflectionPattern.explore: 'Tình huống này làm bạn nhớ đến điều gì?',
  ReflectionPattern.reframe: 'Nếu một người bạn kể lại chuyện này, bạn sẽ nói gì với họ?',
  ReflectionPattern.commit: 'Ngày mai bạn muốn thử điều gì?',
  ReflectionPattern.preserve: 'Điều gì trong hôm nay đáng được giữ lại?',
};

// Ba luật rút từ mục tiêu của từng Pattern (HXA §3.5). Câu hỏi vi phạm một
// trong ba luật này sẽ nhận về câu trả lời cụt:
//
//   1. Không hỏi một dữ kiện. "Lần gần nhất là khi nào?" chỉ nhận được một mốc
//      thời gian, mà Explore cần Surface → Depth — một cái ngày thì không sâu.
//   2. Không bắt nghĩ ra từ chỗ trống. Commit là Insight → Action: hành động
//      phải bám vào tình huống vừa kể, không phải sáng tác một việc mới.
//   3. Preserve không được trùng bước Ý nghĩa. Bước đó đã hỏi "giữ lại điều
//      gì"; Preserve giữ một chi tiết cụ thể, không phải bài học.
const Map<HumanMoment, Map<ReflectionPattern, String>> _momentPrompts = {
  HumanMoment.arrival: {
    ReflectionPattern.notice: 'Lúc này trong bạn đang có điều gì?',
    ReflectionPattern.name:
        'Nếu gọi tên cảm giác đó bằng một câu, bạn sẽ nói gì?',
    ReflectionPattern.preserve:
        'Có chi tiết nào của hôm nay bạn muốn nhớ lại sau này?',
  },
  HumanMoment.confusion: {
    ReflectionPattern.notice: 'Điều gì đang khiến bạn thấy chưa ổn?',
    ReflectionPattern.name: 'Nếu phải gọi tên điều chưa ổn đó, bạn gọi là gì?',
    ReflectionPattern.explore:
        'Chuyện này làm bạn nhớ tới lần nào trước đây không?',
    ReflectionPattern.preserve:
        'Chi tiết nào trong chuyện này bạn muốn nhớ lại sau?',
  },
  HumanMoment.decision: {
    ReflectionPattern.notice: 'Bạn đang phải chọn giữa những điều gì?',
    ReflectionPattern.name: 'Điều gì làm lựa chọn này khó với bạn?',
    ReflectionPattern.explore: 'Điều gì thực sự quan trọng với bạn ở đây?',
    ReflectionPattern.reframe:
        'Ba năm nữa nhìn lại, bạn mong mình đã chọn thế nào?',
    ReflectionPattern.commit:
        'Tuần này bạn làm được việc nhỏ nào để chọn dễ hơn?',
  },
  HumanMoment.growth: {
    ReflectionPattern.notice: 'Bạn muốn mình khá hơn ở điều gì?',
    ReflectionPattern.explore:
        'Kể lại một lần bạn làm được điều đó. Chuyện gì đã xảy ra?',
    ReflectionPattern.commit:
        'Tuần này, trong tình huống nào bạn có thể thử lại điều đó?',
    ReflectionPattern.preserve: 'Điều gì trong lần làm được đó bạn muốn nhớ?',
  },
  HumanMoment.recovery: {
    ReflectionPattern.notice: 'Điều gì đang làm bạn mất năng lượng?',
    ReflectionPattern.explore:
        'Điều gì làm chuyện này nặng hơn mức bình thường?',
    ReflectionPattern.preserve:
        'Điều gì đã giúp bạn dễ thở hơn, dù chỉ một chút?',
  },
  HumanMoment.celebration: {
    ReflectionPattern.notice: 'Bạn vừa làm được điều gì?',
    ReflectionPattern.name: 'Điều gì làm bạn thấy điều đó đáng tự hào?',
    ReflectionPattern.preserve:
        'Khoảnh khắc nào trong chuyện đó bạn muốn nhớ lâu?',
  },
};

/// Câu hỏi dẫn dắt cho một bước phản tư.
String promptFor(HumanMoment moment, ReflectionPattern pattern) {
  return _momentPrompts[moment]?[pattern] ??
      _defaultPrompts[pattern] ??
      'Bạn đang nghĩ gì?';
}

// ---------------------------------------------------------------------------
// Nửa câu mở đầu gợi ý trong ô nhập.
//
// HXA §3.5 Pattern Name nói thẳng cách làm: đưa sẵn "Tôi thấy… / Tôi đang…".
// Một ô trống với dòng "Viết vài dòng cho riêng bạn…" không giúp ai bắt đầu;
// nửa câu có sẵn thì có.
// ---------------------------------------------------------------------------

const Map<ReflectionPattern, String> _defaultHints = {
  ReflectionPattern.notice: 'Tôi đang…',
  ReflectionPattern.name: 'Tôi thấy…',
  ReflectionPattern.explore: 'Hôm đó…',
  ReflectionPattern.reframe: 'Có lẽ…',
  ReflectionPattern.commit: 'Tôi sẽ…',
  ReflectionPattern.preserve: 'Tôi muốn nhớ…',
};

const Map<HumanMoment, Map<ReflectionPattern, String>> _momentHints = {
  HumanMoment.arrival: {
    ReflectionPattern.notice: 'Trong đầu tôi đang…',
    ReflectionPattern.preserve: 'Lúc…',
  },
  HumanMoment.confusion: {
    ReflectionPattern.notice: 'Chuyện là…',
    ReflectionPattern.explore: 'Nó giống lần…',
    ReflectionPattern.preserve: 'Khoảnh khắc…',
  },
  HumanMoment.decision: {
    ReflectionPattern.notice: 'Một bên là… bên kia là…',
    ReflectionPattern.name: 'Khó vì…',
    ReflectionPattern.explore: 'Với tôi, quan trọng nhất là…',
    ReflectionPattern.reframe: 'Tôi mong mình đã…',
    ReflectionPattern.commit: 'Tuần này tôi sẽ…',
  },
  HumanMoment.growth: {
    ReflectionPattern.notice: 'Tôi muốn khá hơn ở…',
    ReflectionPattern.commit: 'Khi… tôi sẽ…',
  },
  HumanMoment.recovery: {
    ReflectionPattern.notice: 'Tôi đang mệt vì…',
    ReflectionPattern.explore: 'Có lẽ vì…',
    ReflectionPattern.preserve: 'Tôi thấy nhẹ hơn khi…',
  },
  HumanMoment.celebration: {
    ReflectionPattern.notice: 'Tôi vừa…',
    ReflectionPattern.name: 'Vì…',
    ReflectionPattern.preserve: 'Lúc…',
  },
};

/// Nửa câu gợi ý hiện mờ trong ô nhập của một bước.
String promptHintFor(HumanMoment moment, ReflectionPattern pattern) {
  return _momentHints[moment]?[pattern] ??
      _defaultHints[pattern] ??
      'Viết vài dòng cho riêng bạn…';
}
