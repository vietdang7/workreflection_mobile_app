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
      'WXS §4.4 — Reflection không có đường tắt.',
    );
  }
}

// ---------------------------------------------------------------------------
// Pattern sequence per Archetype — HXA §3.6 Session Grammar
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

const Map<HumanMoment, Map<ReflectionPattern, String>> _momentPrompts = {
  HumanMoment.arrival: {
    ReflectionPattern.notice: 'Lúc này trong bạn đang có điều gì?',
    ReflectionPattern.name: 'Bạn sẽ gọi tên cảm giác đó là gì?',
    ReflectionPattern.preserve: 'Điều gì hôm nay bạn muốn nhớ lại sau này?',
  },
  HumanMoment.confusion: {
    ReflectionPattern.notice: 'Điều gì đang khiến bạn thấy chưa ổn?',
    ReflectionPattern.name: 'Nếu phải gọi tên điều chưa ổn đó, bạn gọi là gì?',
    ReflectionPattern.explore: 'Có điều gì bạn chưa từng để ý trong chuyện này?',
    ReflectionPattern.preserve: 'Bạn muốn giữ lại điều gì từ lần nhìn lại này?',
  },
  HumanMoment.decision: {
    ReflectionPattern.notice: 'Bạn đang phải chọn giữa những điều gì?',
    ReflectionPattern.name: 'Điều gì làm lựa chọn này khó với bạn?',
    ReflectionPattern.explore: 'Điều gì thực sự quan trọng với bạn ở đây?',
    ReflectionPattern.reframe: 'Nhìn từ ba năm sau, bạn sẽ mong mình đã chọn thế nào?',
    ReflectionPattern.commit: 'Bước nhỏ nào giúp bạn tiến gần hơn tới lựa chọn đó?',
  },
  HumanMoment.growth: {
    ReflectionPattern.notice: 'Bạn muốn mình khá hơn ở điều gì?',
    ReflectionPattern.explore: 'Lần gần nhất bạn làm tốt điều đó là khi nào?',
    ReflectionPattern.commit: 'Tuần này bạn muốn thử một điều nhỏ nào?',
    ReflectionPattern.preserve: 'Điều gì đáng được ghi lại cho chặng sau?',
  },
  HumanMoment.recovery: {
    ReflectionPattern.notice: 'Điều gì đang làm bạn mất năng lượng?',
    ReflectionPattern.explore: 'Điều đó chạm tới điều gì bên trong bạn?',
    ReflectionPattern.preserve: 'Điều gì bạn muốn ghi lại để lần sau nhẹ hơn?',
  },
  HumanMoment.celebration: {
    ReflectionPattern.notice: 'Bạn vừa làm được điều gì?',
    ReflectionPattern.name: 'Điều gì làm bạn thấy điều đó đáng tự hào?',
    ReflectionPattern.preserve: 'Bạn muốn giữ lại điều gì từ trải nghiệm này?',
  },
};

/// Câu hỏi dẫn dắt cho một bước phản tư.
String promptFor(HumanMoment moment, ReflectionPattern pattern) {
  return _momentPrompts[moment]?[pattern] ??
      _defaultPrompts[pattern] ??
      'Bạn đang nghĩ gì?';
}
