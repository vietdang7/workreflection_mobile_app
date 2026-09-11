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
import '../l10n/wr_tr.dart';

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

Map<ReflectionPattern, String> get _defaultPrompts => {
  ReflectionPattern.notice: tr('Điều gì đang chiếm nhiều năng lượng của bạn nhất lúc này?', 'What is taking the most out of you right now?'),
  ReflectionPattern.name: tr('Nếu gọi tên điều bạn đang trải qua bằng một câu, bạn sẽ nói gì?', 'If you named what you are going through in one line, what would it be?'),
  ReflectionPattern.explore: tr('Tình huống này làm bạn nhớ đến điều gì?', 'What does this situation remind you of?'),
  ReflectionPattern.reframe: tr('Nếu một người bạn kể lại chuyện này, bạn sẽ nói gì với họ?', 'If a friend told you this story, what would you say to them?'),
  ReflectionPattern.commit: tr('Ngày mai bạn muốn thử điều gì?', 'What do you want to try tomorrow?'),
  ReflectionPattern.preserve: tr('Điều gì trong hôm nay đáng được giữ lại?', 'What from today is worth keeping?'),
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
Map<HumanMoment, Map<ReflectionPattern, String>> get _momentPrompts => {
  HumanMoment.arrival: {
    ReflectionPattern.notice: tr('Lúc này trong bạn đang có điều gì?', 'What is going on inside you right now?'),
    ReflectionPattern.name:
        tr('Nếu gọi tên cảm giác đó bằng một câu, bạn sẽ nói gì?', 'If you named that feeling in one line, what would you say?'),
    ReflectionPattern.preserve:
        tr('Có chi tiết nào của hôm nay bạn muốn nhớ lại sau này?', 'Is there a detail from today you want to remember later?'),
  },
  HumanMoment.confusion: {
    ReflectionPattern.notice: tr('Điều gì đang khiến bạn thấy chưa ổn?', 'What is making you feel off?'),
    ReflectionPattern.name: tr('Nếu phải gọi tên điều chưa ổn đó, bạn gọi là gì?', 'If you had to name what feels off, what would you call it?'),
    ReflectionPattern.explore:
        tr('Chuyện này làm bạn nhớ tới lần nào trước đây không?', 'Does this remind you of another time?'),
    ReflectionPattern.preserve:
        tr('Chi tiết nào trong chuyện này bạn muốn nhớ lại sau?', 'Which detail of this do you want to remember later?'),
  },
  HumanMoment.decision: {
    ReflectionPattern.notice: tr('Bạn đang phải chọn giữa những điều gì?', 'What are you having to choose between?'),
    ReflectionPattern.name: tr('Điều gì làm lựa chọn này khó với bạn?', 'What makes this choice hard for you?'),
    ReflectionPattern.explore: tr('Điều gì thực sự quan trọng với bạn ở đây?', 'What actually matters to you here?'),
    ReflectionPattern.reframe:
        tr('Ba năm nữa nhìn lại, bạn mong mình đã chọn thế nào?', 'Looking back in three years, how do you hope you chose?'),
    ReflectionPattern.commit:
        tr('Tuần này bạn làm được việc nhỏ nào để chọn dễ hơn?', 'What small thing could you do this week to make the choice easier?'),
  },
  HumanMoment.growth: {
    ReflectionPattern.notice: tr('Bạn muốn mình khá hơn ở điều gì?', 'What do you want to get better at?'),
    ReflectionPattern.explore:
        tr('Kể lại một lần bạn làm được điều đó. Chuyện gì đã xảy ra?', 'Tell me about a time you did it. What happened?'),
    ReflectionPattern.commit:
        tr('Tuần này, trong tình huống nào bạn có thể thử lại điều đó?', 'Where this week could you try that again?'),
    ReflectionPattern.preserve: tr('Điều gì trong lần làm được đó bạn muốn nhớ?', 'What from that time do you want to remember?'),
  },
  HumanMoment.recovery: {
    ReflectionPattern.notice: tr('Điều gì đang làm bạn mất năng lượng?', 'What is draining you?'),
    ReflectionPattern.explore:
        tr('Điều gì làm chuyện này nặng hơn mức bình thường?', 'What makes this heavier than usual?'),
    ReflectionPattern.preserve:
        tr('Điều gì đã giúp bạn dễ thở hơn, dù chỉ một chút?', 'What made it easier to breathe, even a little?'),
  },
  HumanMoment.celebration: {
    ReflectionPattern.notice: tr('Bạn vừa làm được điều gì?', 'What did you just pull off?'),
    ReflectionPattern.name: tr('Điều gì làm bạn thấy điều đó đáng tự hào?', 'What makes that feel worth being proud of?'),
    ReflectionPattern.preserve:
        tr('Khoảnh khắc nào trong chuyện đó bạn muốn nhớ lâu?', 'Which moment in it do you want to remember for a long time?'),
  },
};

/// Câu hỏi dẫn dắt cho một bước phản tư.
String promptFor(HumanMoment moment, ReflectionPattern pattern) {
  return _momentPrompts[moment]?[pattern] ??
      _defaultPrompts[pattern] ??
      tr('Bạn đang nghĩ gì?', 'What are you thinking?');
}

// ---------------------------------------------------------------------------
// Nửa câu mở đầu gợi ý trong ô nhập.
//
// HXA §3.5 Pattern Name nói thẳng cách làm: đưa sẵn "Tôi thấy… / Tôi đang…".
// Một ô trống với dòng "Viết vài dòng cho riêng bạn…" không giúp ai bắt đầu;
// nửa câu có sẵn thì có.
// ---------------------------------------------------------------------------

Map<ReflectionPattern, String> get _defaultHints => {
  ReflectionPattern.notice: tr('Tôi đang…', 'I am…'),
  ReflectionPattern.name: tr('Tôi thấy…', 'I feel…'),
  ReflectionPattern.explore: tr('Hôm đó…', 'That day…'),
  ReflectionPattern.reframe: tr('Có lẽ…', 'Maybe…'),
  ReflectionPattern.commit: tr('Tôi sẽ…', 'I will…'),
  ReflectionPattern.preserve: tr('Tôi muốn nhớ…', 'I want to remember…'),
};

Map<HumanMoment, Map<ReflectionPattern, String>> get _momentHints => {
  HumanMoment.arrival: {
    ReflectionPattern.notice: tr('Trong đầu tôi đang…', 'In my head right now…'),
    ReflectionPattern.preserve: tr('Lúc…', 'When…'),
  },
  HumanMoment.confusion: {
    ReflectionPattern.notice: tr('Chuyện là…', 'What happened was…'),
    ReflectionPattern.explore: tr('Nó giống lần…', 'It is like the time…'),
    ReflectionPattern.preserve: tr('Khoảnh khắc…', 'The moment…'),
  },
  HumanMoment.decision: {
    ReflectionPattern.notice: tr('Một bên là… bên kia là…', 'On one side… on the other…'),
    ReflectionPattern.name: tr('Khó vì…', 'Hard because…'),
    ReflectionPattern.explore: tr('Với tôi, quan trọng nhất là…', 'For me, what matters most is…'),
    ReflectionPattern.reframe: tr('Tôi mong mình đã…', 'I hope I will have…'),
    ReflectionPattern.commit: tr('Tuần này tôi sẽ…', 'This week I will…'),
  },
  HumanMoment.growth: {
    ReflectionPattern.notice: tr('Tôi muốn khá hơn ở…', 'I want to get better at…'),
    ReflectionPattern.commit: tr('Khi… tôi sẽ…', 'When… I will…'),
  },
  HumanMoment.recovery: {
    ReflectionPattern.notice: tr('Tôi đang mệt vì…', 'I am tired because…'),
    ReflectionPattern.explore: tr('Có lẽ vì…', 'Maybe because…'),
    ReflectionPattern.preserve: tr('Tôi thấy nhẹ hơn khi…', 'I felt lighter when…'),
  },
  HumanMoment.celebration: {
    ReflectionPattern.notice: tr('Tôi vừa…', 'I just…'),
    ReflectionPattern.name: tr('Vì…', 'Because…'),
    ReflectionPattern.preserve: tr('Lúc…', 'When…'),
  },
};

/// Nửa câu gợi ý hiện mờ trong ô nhập của một bước.
String promptHintFor(HumanMoment moment, ReflectionPattern pattern) {
  return _momentHints[moment]?[pattern] ??
      _defaultHints[pattern] ??
      tr('Viết vài dòng cho riêng bạn…', 'Write a few lines just for you…');
}
