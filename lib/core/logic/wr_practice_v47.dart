// Thực hành theo mockup v47 (06/10/2026): bộ 4 bước dùng chung và ba cách để
// chọn.
//
// Mockup: "Mỗi chủ đề, dù đến từ thư viện hay do người dùng tự thêm, đều dùng
// đúng bộ 4 bước này" — Nhận diện → Phần của tôi → Chọn một cách → Mang về.
// Thư viện đã chuyển sang 4 bước bằng migration 20261006120000; file này lo
// phần chủ đề người dùng tự thêm (`buildPracticeSteps`,
// `buildUserThemeMentorOptions`) và bộ cách dự phòng (`getMentorOptions`).
//
// Lớp AI viết lại mô tả từng bước (lớp 3 trong mockup) chưa làm: bản theo luật
// ở đây là lớp 2, luôn chạy được.
//
// Pure Dart → test được trực tiếp.

import '../l10n/wr_tr.dart';
import '../models/wr_content.dart' show CareerMemoryEvent;
import '../models/wr_intelligence.dart';
import '../models/wr_mood_content.dart' show PracticeStepNote;
import 'wr_skill_formation.dart'
    show kPracticeBehaviors, kPracticeMaintainedBehavior, maintainedToday;

/// Số bước của mọi chủ đề.
const int kPracticeStageCount = 4;

/// Phần hành động của tiêu đề bước, bỏ nhãn giai đoạn ở đầu.
///
/// Tiêu đề trong DB có dạng "Nhận diện: Quan sát lúc muốn im lặng"; nhãn giai
/// đoạn hiện riêng (`practiceStageTag`), nên phần còn lại mới là việc cần làm.
String practiceStepAction(String title) {
  final i = title.indexOf(':');
  if (i < 0) return title.trim();
  final rest = title.substring(i + 1).trim();
  return rest.isEmpty ? title.trim() : rest;
}

/// Bốn bước cho một chủ đề người dùng tự thêm (`buildPracticeSteps`).
///
/// Có câu "đã thử" thì bước "Chọn một cách" dặn thêm đừng lặp lại đúng điều đó
/// (họp khách 05/10: không gợi ý lại cách đã thử mà không có kết quả).
List<PracticeStep> buildUserPracticeSteps({
  required String themeId,
  required PracticeIntake intake,
}) {
  // Script Sprint 2 `buildPracticeSteps`. Điều người dùng "đã thử" không nằm
  // trong mô tả bước nữa: ba cách gợi ý (`buildUserThemeMentorOptions`) đã
  // tránh lặp lại nó.
  final g = intake.goal.trim().toLowerCase().replaceAll(RegExp(r'\.$'), '');
  final what = g.isEmpty ? 'điều bạn muốn khác đi' : g;
  final whatEn = g.isEmpty ? 'what you want to change' : g;
  return [
    PracticeStep(
      stepId: '$themeId-1',
      themeId: themeId,
      stepOrder: 1,
      title: 'Nhận diện: Quan sát một tình huống thật',
      titleEn: 'Notice: Watch one real situation',
      content:
          'Lần tới khi chuyện này xảy ra, chú ý xem bạn phản ứng thế nào trước '
          'khi kịp nghĩ.',
      contentEn:
          'Next time this happens, notice how you react before you have time '
          'to think.',
      isPremium: false,
    ),
    PracticeStep(
      stepId: '$themeId-2',
      themeId: themeId,
      stepOrder: 2,
      title: 'Phần của tôi: Tách phần mình và phần bối cảnh',
      titleEn: 'Your part: Separate your part from the context',
      content:
          'Trong tình huống đó, điều gì thuộc quyền quyết định của bạn, và điều '
          'gì thì chưa?',
      contentEn:
          'In that situation, what is yours to decide, and what is not yet?',
      isPremium: false,
    ),
    PracticeStep(
      stepId: '$themeId-3',
      themeId: themeId,
      stepOrder: 3,
      title: 'Chọn một cách: Chọn một cách rồi thử',
      titleEn: 'Pick one way: Pick one way and try it',
      content:
          'Mở phần gợi ý, chọn một cách, rồi thử trong một tình huống thật liên '
          'quan tới $what.',
      contentEn:
          'Open the suggestions, pick one way, then try it in a real situation '
          'related to $whatEn.',
      isPremium: false,
    ),
    PracticeStep(
      stepId: '$themeId-4',
      themeId: themeId,
      stepOrder: 4,
      title: 'Câu hỏi cho lần sau: Điều bạn muốn hỏi lần tới',
      titleEn: 'A question for next time: What you want to ask next time',
      content: 'Sau khi thử, bạn muốn mang theo câu hỏi nào cho lần sau?',
      contentEn:
          'After trying, what question do you want to carry into next time?',
      isPremium: true,
    ),
  ];
}

/// Ba cách cho chủ đề người dùng tự thêm (`buildUserThemeMentorOptions`).
///
/// Không có [tried]: đúng ba cách của mockup (nhỏ nhất · đổi cách · quan sát).
///
/// Có [tried] (câu "đã thử rồi mà không có kết quả", họp khách 05/10): cách
/// nào cùng hướng với điều đã thử thì bị loại, chỗ trống lấy "Đưa người khác
/// vào cuộc"; "Đổi cách tiếp cận" lên đầu và nhắc lại đúng điều đã thử. Luật
/// theo từ khoá, không đoán: không khớp từ nào thì giữ cả ba.
List<PracticeMentorOption> buildUserThemeMentorOptions(
  String goal, {
  String? tried,
}) {
  final base = _baseUserThemeOptions(goal);
  final quote = _triedQuote(tried);
  if (quote == null) return base;

  final reframe = PracticeMentorOption(
    id: 'reframe',
    title: 'Đổi cách tiếp cận',
    titleEn: 'Change the approach',
    fit:
        'Bạn đã thử "$quote" mà chưa có kết quả. Cách này là để hướng đó lại '
        'và thử một hướng khác hẳn.',
    fitEn:
        'You tried "$quote" and it did not work. This is about leaving that '
        'direction and trying a different one.',
    tradeoff: base[1].tradeoff,
    tradeoffEn: base[1].tradeoffEn,
  );
  final pool = [reframe, base[0], base[2], _talkOption];
  final kept = [
    for (final o in pool)
      if (!triedMatchesOption(tried!, o.id)) o,
  ].take(3).toList();
  // Điều đã thử chạm cả ba hướng kia (hiếm) thì vẫn đủ ba thẻ: thà một hướng
  // gần giống còn hơn để trống chỗ chọn.
  for (final o in pool) {
    if (kept.length >= 3) break;
    if (!kept.contains(o)) kept.add(o);
  }
  return kept;
}

const _talkOption = PracticeMentorOption(
  id: 'talk',
  title: 'Đưa người khác vào cuộc',
  titleEn: 'Bring someone else in',
  fit: 'Phù hợp khi tình huống phụ thuộc vào ai đó hoặc cần thêm một góc nhìn.',
  fitEn:
      'Fits when the situation depends on someone else or needs another view.',
  tradeoff:
      'Bạn phải mở lời và chấp nhận có thể nhận phản hồi không như mong đợi.',
  tradeoffEn: 'You have to speak up and may hear something you did not expect.',
);

/// Từ khoá cho biết điều đã thử cùng hướng với một cách. "Đổi cách tiếp cận"
/// không có từ khoá: điều đã thử không có kết quả chính là lý do để đổi cách.
const Map<String, List<String>> kTriedOptionKeywords = {
  'small': [
    'từng chút',
    'từng bước',
    'bước nhỏ',
    'từ từ',
    'little by little',
    'small step',
    'step by step',
  ],
  'observe': [
    'quan sát',
    'để ý',
    'theo dõi',
    'ghi lại',
    'ghi chép',
    'chờ',
    'đợi',
    'im lặng',
    'observe',
    'observed',
    'notice',
    'noticed',
    'watch',
    'watched',
    'wait',
    'waited',
    'track',
    'tracked',
  ],
  'talk': [
    'nói',
    'trao đổi',
    'hỏi',
    'nhờ',
    'góp ý',
    'chia sẻ',
    'gặp',
    'đề xuất',
    'phản hồi',
    'xin ý kiến',
    'talk',
    'talked',
    'ask',
    'asked',
    'tell',
    'told',
    'discuss',
    'discussed',
    'feedback',
    'speak',
    'spoke',
  ],
};

/// Điều đã thử có cùng hướng với cách [optionId] không. Khớp nguyên từ, không
/// khớp nửa chữ ("chờ" không dính "chờn").
bool triedMatchesOption(String tried, String optionId) {
  final words = kTriedOptionKeywords[optionId];
  if (words == null) return false;
  final t =
      ' ${tried.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')} ';
  return words.any((w) => t.contains(' $w '));
}

/// Câu "đã thử" gọn để chèn vào chữ, hoặc null khi bỏ trống.
String? _triedQuote(String? tried) {
  final t = tried?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t == null || t.isEmpty) return null;
  final s = t.replaceAll(RegExp(r'[.!?…]+$'), '');
  return s.length <= 80 ? s : '${s.substring(0, 79).trimRight()}…';
}

List<PracticeMentorOption> _baseUserThemeOptions(String goal) {
  final g = goal.trim().isEmpty ? 'cải thiện điều này' : goal.trim();
  final gEn = goal.trim().isEmpty ? 'improve this' : goal.trim();
  return [
    PracticeMentorOption(
      id: 'small',
      title: 'Thử cách nhỏ nhất',
      titleEn: 'Try the smallest way',
      fit:
          'Phù hợp khi bạn đã biết mình muốn ${g.toLowerCase()} nhưng chưa muốn '
          'thay đổi quá nhiều cùng lúc.',
      fitEn:
          'Fits when you know you want to ${gEn.toLowerCase()} but do not want '
          'to change too much at once.',
      tradeoff:
          'Bạn có thêm dữ liệu thật, nhưng thay đổi ban đầu có thể khá nhỏ.',
      tradeoffEn:
          'You get real information, but the first change may be small.',
    ),
    const PracticeMentorOption(
      id: 'reframe',
      title: 'Đổi cách tiếp cận',
      titleEn: 'Change the approach',
      fit:
          'Phù hợp khi cách bạn đang làm chưa đưa đến điều bạn muốn, dù bạn đã '
          'thử một vài lần.',
      fitEn:
          'Fits when your current way has not led where you want, even after a '
          'few tries.',
      tradeoff:
          'Bạn phải chấp nhận rời khỏi cách quen thuộc và có thể chưa biết kết '
          'quả sẽ ra sao.',
      tradeoffEn:
          'You have to step away from the familiar way without knowing how it '
          'will turn out.',
    ),
    const PracticeMentorOption(
      id: 'observe',
      title: 'Quan sát thêm một lần',
      titleEn: 'Observe one more time',
      fit:
          'Phù hợp khi bạn chưa đủ thông tin để biết chính xác điều gì cần thay '
          'đổi.',
      fitEn: 'Fits when you do not yet know exactly what needs to change.',
      tradeoff: 'Bạn có thêm dữ liệu, nhưng vấn đề có thể chưa thay đổi ngay.',
      tradeoffEn: 'You learn more, but the problem may not change right away.',
    ),
  ];
}

/// Bộ cách chung (`getMentorOptions`) cho chủ đề chưa có `mentor_options`.
List<PracticeMentorOption> fallbackMentorOptions({String? practice}) {
  final p = practice?.trim();
  return [
    PracticeMentorOption(
      id: 'try',
      title: (p == null || p.isEmpty) ? 'Thử một bước nhỏ' : p,
      titleEn: (p == null || p.isEmpty) ? 'Try one small step' : null,
      fit: 'Hợp khi bạn đã biết điều nhỏ mình muốn thử.',
      fitEn: 'Good when you already know the small thing you want to try.',
      tradeoff: 'Bạn chấp nhận một chút khó chịu để có dữ liệu mới.',
      tradeoffEn:
          'You accept a little discomfort in exchange for new information.',
    ),
    const PracticeMentorOption(
      id: 'observe',
      title: 'Quan sát thêm một lần',
      titleEn: 'Observe one more time',
      fit:
          'Hợp khi bạn chưa chắc đây là một mẫu hình hay chỉ là một lần xảy ra.',
      fitEn:
          'Good when you are not sure whether this is a pattern or a one-off.',
      tradeoff: 'Bạn có thêm thông tin, nhưng điều này có thể kéo dài thêm.',
      tradeoffEn:
          'You learn more, but the situation may go on a little longer.',
    ),
    const PracticeMentorOption(
      id: 'talk',
      title: 'Đưa người khác vào cuộc',
      titleEn: 'Bring someone else in',
      fit: 'Hợp khi tình huống phụ thuộc vào ai đó hoặc cần thêm một góc nhìn.',
      fitEn:
          'Good when the situation depends on someone else or needs another view.',
      tradeoff:
          'Bạn phải mở lời và chấp nhận có thể nhận phản hồi không như mong đợi.',
      tradeoffEn:
          'You have to speak up and may hear something you did not expect.',
    ),
  ];
}

/// Ba cách của một chủ đề: của riêng nó nếu có, không thì bộ chung.
List<PracticeMentorOption> mentorOptionsFor(PracticeTheme theme) =>
    theme.mentorOptions.isNotEmpty
    ? theme.mentorOptions
    : fallbackMentorOptions();

/// Dòng nguồn trên thẻ chủ đề (`t.src` của mockup): "Bạn thêm · 08/06" /
/// "Từ Reflection · 13/6".
String practiceThemeSourceLabel(PracticeTheme theme, DateTime? startedAt) {
  final d = startedAt ?? theme.createdAt;
  final date = d == null
      ? ''
      : ' · ${d.toLocal().day.toString().padLeft(2, '0')}/'
            '${d.toLocal().month.toString().padLeft(2, '0')}';
  return theme.isUserAdded
      ? tr('Bạn thêm$date', 'Added by you$date')
      : tr('Từ Reflection$date', 'From Reflection$date');
}

// ─────────────────────────────────────────────────────────────────────────────
// Script Sprint 2 — màn chủ đề, phần duy trì, câu tâm thế.
// ─────────────────────────────────────────────────────────────────────────────

/// Câu hỏi + chữ mờ khi bấm "Tôi đã thử bước này" (script `STEP_PROMPTS`).
///
/// Mỗi bước một câu riêng, vì mỗi bước hỏi một thứ khác nhau. Tra theo THỨ TỰ
/// bước chứ không theo nhãn: nhãn đổi theo ngôn ngữ, thứ tự thì không.
({String q, String ph}) practiceStepPrompt(
  int stepOrder,
) => switch (stepOrder) {
  1 => (
    q: tr('Bạn để ý thấy gì?', 'What did you notice?'),
    ph: tr(
      'Ví dụ: Chiều thứ Năm nào mình cũng thấy đuối, thường sau cuộc họp dài.',
      'For example: Every Thursday afternoon I feel drained, usually after a '
          'long meeting.',
    ),
  ),
  2 => (
    q: tr(
      'Điều gì thuộc quyền quyết định của bạn?',
      'What is yours to decide?',
    ),
    ph: tr(
      'Ví dụ: Mình chọn được giờ họp, nhưng không chọn được số lượng họp.',
      'For example: I can choose when we meet, but not how many meetings '
          'there are.',
    ),
  ),
  4 => (
    q: tr(
      'Câu hỏi bạn muốn mang theo cho lần sau?',
      'What question do you want to carry into next time?',
    ),
    ph: tr(
      'Ví dụ: Lần tới mình có cần chờ đến lúc chắc chắn mới nói không?',
      'For example: Next time, do I really need to wait until I am sure before '
          'I speak?',
    ),
  ),
  _ => (
    q: tr('Bạn đã thử như thế nào?', 'How did you try it?'),
    ph: tr(
      'Ví dụ: Mình dời một cuộc họp sang sáng hôm sau, và buổi chiều nhẹ hẳn.',
      'For example: I moved one meeting to the next morning, and the afternoon '
          'felt much lighter.',
    ),
  ),
};

// Ba cách gợi ý ở bước 3 (script `STEP3_OPTIONS`): chỉ có tên cách và một dòng
// "hợp khi", không có "đánh đổi". Mang cả hai thứ tiếng nên để là hằng được:
// [PracticeMentorOption.title] chọn ngôn ngữ lúc đọc chứ không phải lúc dựng.

/// `STEP3_OPTIONS.t1` — "Dám lên tiếng".
const List<PracticeMentorOption> kStep3OptionsVoice = [
  PracticeMentorOption(
    id: 'small',
    title: 'Đặt một câu hỏi nhỏ trước',
    titleEn: 'Ask one small question first',
    fit: 'Hợp khi bạn chưa muốn nêu nguyên một quan điểm.',
    fitEn: 'Fits when you are not ready to put forward a whole view.',
    tradeoff: '',
  ),
  PracticeMentorOption(
    id: 'watch',
    title: 'Quan sát thêm một lần',
    titleEn: 'Observe one more time',
    fit: 'Hợp khi bạn chưa chắc đây là mẫu hình hay chỉ một lần xảy ra.',
    fitEn: 'Fits when you are not sure whether this is a pattern or a one-off.',
    tradeoff: '',
  ),
  PracticeMentorOption(
    id: 'ally',
    title: 'Nói trước với một người',
    titleEn: 'Tell one person first',
    fit: 'Hợp khi nói riêng dễ hơn nói giữa cuộc họp.',
    fitEn: 'Fits when speaking privately is easier than speaking in a meeting.',
    tradeoff: '',
  ),
];

/// `STEP3_OPTIONS.t2` — chủ đề phản hồi.
const List<PracticeMentorOption> kStep3OptionsFeedback = [
  PracticeMentorOption(
    id: 'ask',
    title: 'Hỏi lại điều chưa rõ',
    titleEn: 'Ask about what is unclear',
    fit: 'Hợp khi bạn thấy mình đang đoán ý người kia.',
    fitEn: 'Fits when you notice you are guessing what the other person means.',
    tradeoff: '',
  ),
  PracticeMentorOption(
    id: 'watch',
    title: 'Quan sát thêm một lần',
    titleEn: 'Observe one more time',
    fit: 'Hợp khi bạn chưa chắc đây là mẫu hình hay chỉ một lần xảy ra.',
    fitEn: 'Fits when you are not sure whether this is a pattern or a one-off.',
    tradeoff: '',
  ),
  PracticeMentorOption(
    id: 'time',
    title: 'Chọn thời điểm khác để nói',
    titleEn: 'Pick another moment to say it',
    fit: 'Hợp khi nội dung đúng nhưng lúc nói chưa hợp.',
    fitEn: 'Fits when the message is right but the moment is not.',
    tradeoff: '',
  ),
];

/// `STEP3_OPTIONS._default`.
const List<PracticeMentorOption> kStep3OptionsDefault = [
  PracticeMentorOption(
    id: 'small',
    title: 'Thử một thay đổi nhỏ nhất',
    titleEn: 'Try the smallest change',
    fit: 'Hợp khi bạn đã biết điều mình muốn thử.',
    fitEn: 'Fits when you already know what you want to try.',
    tradeoff: '',
  ),
  PracticeMentorOption(
    id: 'watch',
    title: 'Quan sát thêm một lần',
    titleEn: 'Observe one more time',
    fit: 'Hợp khi bạn chưa chắc đây là mẫu hình hay chỉ một lần xảy ra.',
    fitEn: 'Fits when you are not sure whether this is a pattern or a one-off.',
    tradeoff: '',
  ),
  PracticeMentorOption(
    id: 'ally',
    title: 'Đưa người khác vào cuộc',
    titleEn: 'Bring someone else in',
    fit: 'Hợp khi tình huống phụ thuộc vào ai đó hoặc cần thêm một góc nhìn.',
    fitEn:
        'Fits when the situation depends on someone else or needs another '
        'view.',
    tradeoff: '',
  ),
];

/// Ba cách của bước "Chọn một cách" cho một chủ đề.
///
/// Chủ đề thư viện theo `STEP3_OPTIONS` của script: "Dám lên tiếng" (`pt-c2`,
/// bản cũ `pt-voice`) dùng bộ t1, chủ đề phản hồi (`pt-c3`, bản cũ
/// `pt-feedback`) dùng bộ t2, còn lại bộ chung. Chủ đề người dùng tự thêm giữ ba
/// cách dựng từ chính lời họ kể (`buildUserThemeMentorOptions`), vì đó là dữ
/// liệu thật của riêng họ.
List<PracticeMentorOption> step3OptionsFor(PracticeTheme theme) {
  if (theme.isUserAdded) {
    return theme.mentorOptions.isNotEmpty
        ? theme.mentorOptions
        : kStep3OptionsDefault;
  }
  return switch (theme.themeId) {
    'pt-c2' || 'pt-voice' => kStep3OptionsVoice,
    'pt-c3' || 'pt-feedback' => kStep3OptionsFeedback,
    _ => kStep3OptionsDefault,
  };
}

/// Cách đã chọn, tra từ giá trị lưu ở `pending_choice`.
///
/// Bản mới lưu `id` của cách; bản cũ (trước script Sprint 2) lưu tên cách, có
/// thể bằng tiếng Việt hoặc tiếng Anh tuỳ ngôn ngữ lúc chọn. Nhận cả ba.
PracticeMentorOption? findPracticeOption(
  List<PracticeMentorOption> options,
  String? saved,
) {
  final v = saved?.trim();
  if (v == null || v.isEmpty) return null;
  for (final o in options) {
    if (o.id == v || o.titleVi == v || o.titleEn == v) return o;
  }
  return null;
}

/// Một chủ đề trong phần "Đang duy trì".
class KeepingTheme {
  const KeepingTheme({
    required this.theme,
    required this.count,
    required this.lastAt,
    required this.markedToday,
  });

  final PracticeTheme theme;

  /// Số lần: lần đưa vào duy trì (script `moveToKeep`, `count:1`) cộng mỗi lần
  /// người dùng bấm "Ghi nhận" (một mảnh `practice_maintained` trong Career
  /// Memory).
  final int count;

  /// Lần gần nhất: lần bấm "Ghi nhận" mới nhất, chưa bấm lần nào thì là ngày
  /// đưa vào duy trì.
  final DateTime? lastAt;

  /// Hôm nay đã ghi nhận chưa — mỗi chủ đề một lần một ngày.
  final bool markedToday;
}

bool _maintainedOf(CareerMemoryEvent e, PracticeTheme theme) {
  if (e.behavior != kPracticeMaintainedBehavior) return false;
  final id = e.themeId;
  if (id != null && id.isNotEmpty) return id == theme.themeId;
  // Mảnh ghi trước khi có cột `theme_id`: so theo tên chủ đề.
  final text = e.reflectionText ?? '';
  return text.startsWith(theme.titleVi) ||
      (theme.titleEn != null && text.startsWith(theme.titleEn!));
}

/// Danh sách "Đang duy trì": chủ đề đã đi hết bốn bước VÀ đã được đưa vào phần
/// duy trì (`completed_at` có giá trị). Mới đưa vào trước.
///
/// Hai hàng thư viện cùng một tên (`pt-voice`, `pt-c2`) là một chủ đề: giữ hàng
/// đầu tiên. Chủ đề người dùng tự thêm thì giữ cả khi trùng tên thư viện.
List<KeepingTheme> buildKeepingThemes({
  required List<PracticeTheme> themes,
  required List<PracticeEnrollment> enrollments,
  required List<CareerMemoryEvent> events,
  required DateTime now,
}) {
  final byId = {for (final t in themes) t.themeId: t};
  final kept = enrollments.where((e) => e.completedAt != null).toList()
    ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  final seenTitles = <String>{};
  final out = <KeepingTheme>[];
  for (final e in kept) {
    final theme = byId[e.themeId];
    if (theme == null) continue;
    if (!theme.isUserAdded && !seenTitles.add(theme.title)) continue;
    var count = 1;
    DateTime? last = e.completedAt;
    for (final ev in events) {
      if (!_maintainedOf(ev, theme)) continue;
      count++;
      final at = ev.createdAt;
      if (at != null && (last == null || at.isAfter(last))) last = at;
    }
    out.add(
      KeepingTheme(
        theme: theme,
        count: count,
        lastAt: last,
        markedToday: maintainedToday(theme, events, now),
      ),
    );
  }
  return out;
}

/// "gần nhất ‹…›" theo cách script viết: hôm nay · hôm qua · 3 ngày trước ·
/// tuần trước. Xa hơn hai tuần thì đếm tuần, xa hơn hai tháng thì đếm tháng.
String keepLastLabel(DateTime at, DateTime now) {
  final a = at.toLocal();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(a.year, a.month, a.day)).inDays;
  if (days <= 0) return tr('hôm nay', 'today');
  if (days == 1) return tr('hôm qua', 'yesterday');
  if (days < 7) return tr('$days ngày trước', '$days days ago');
  if (days < 14) return tr('tuần trước', 'last week');
  if (days < 60) {
    final w = days ~/ 7;
    return tr('$w tuần trước', '$w weeks ago');
  }
  final m = days ~/ 30;
  return tr('$m tháng trước', '$m months ago');
}

/// Số lần thực hành tối thiểu, trên số chủ đề tối thiểu, để được sinh câu tâm
/// thế (script, NGUYÊN TẮC SINH CÂU TÂM THẾ §1).
const int kStanceMinPractices = 3;
const int kStanceMinThemes = 2;

/// Đủ dữ liệu để gọi tên một tâm thế chưa: ít nhất [kStanceMinPractices] lần
/// thực hành được ghi nhận, trải trên ít nhất [kStanceMinThemes] chủ đề.
bool stanceHasEnoughData(List<CareerMemoryEvent> events) {
  var count = 0;
  final themeIds = <String>{};
  for (final e in events) {
    if (!kPracticeBehaviors.contains(e.behavior)) continue;
    count++;
    final id = e.themeId;
    if (id != null && id.isNotEmpty) themeIds.add(id);
  }
  return count >= kStanceMinPractices && themeIds.length >= kStanceMinThemes;
}

/// Câu tâm thế dựng từ dữ liệu thật, hoặc null khi chưa đủ để gọi tên.
///
/// Chưa có lớp AI đọc ghi chú, nên câu dựng theo bốn nhịp của script ở mức tối
/// thiểu và LẤY LẠI ĐÚNG CHỮ người dùng đã viết:
///   a. nhịp cũ    : ghi chú đầu tiên
///   b. nhịp mới   : ghi chú gần nhất
///   c. tích luỹ   : "xuất hiện nhiều hơn trước, không còn là một lần"
///   d. để mở      : "chưa thành phản xạ, vẫn đang hình thành"
/// Không số lần, không tính từ chỉ con người, không tự xưng. Cần ít nhất hai ghi
/// chú khác nhau: không có chữ của chính họ thì câu chỉ còn là một lời khen
/// trống, đúng điều script dặn tránh, nên để trống.
String? buildStanceObservation({
  required List<CareerMemoryEvent> events,
  required List<PracticeStepNote> notes,
}) {
  if (!stanceHasEnoughData(events)) return null;
  final written = [
    for (final n in notes)
      if (n.note.trim().isNotEmpty) n,
  ];
  if (written.length < 2) return null;
  written.sort((a, b) {
    final ca = a.createdAt;
    final cb = b.createdAt;
    if (ca == null && cb == null) return 0;
    if (ca == null) return 1;
    if (cb == null) return -1;
    return ca.compareTo(cb);
  });
  final first = _stanceQuote(written.first.note);
  final last = _stanceQuote(written.last.note);
  if (first.toLowerCase() == last.toLowerCase()) return null;
  return tr(
    'Những ghi chú đầu tiên của bạn nói nhiều về “$first”. Mấy lần thử gần '
        'đây có thêm một nhịp khác: “$last”. Nhịp này xuất hiện nhiều hơn '
        'trước, không còn là một lần, chưa thành phản xạ nhưng đang dần hình '
        'thành.',
    'Your earliest notes talk a lot about “$first”. Your recent tries add a '
        'different beat: “$last”. This beat shows up more than before, not '
        'just once. It is not a reflex yet, but it is taking shape.',
  );
}

String _stanceQuote(String note) {
  final t = note.trim().replaceAll(RegExp(r'\s+'), ' ');
  final s = t.replaceAll(RegExp(r'[.!?…]+$'), '');
  if (s.length <= 90) return s;
  final cut = s.substring(0, 90);
  final sp = cut.lastIndexOf(' ');
  return '${(sp > 40 ? cut.substring(0, sp) : cut).trimRight()}…';
}
