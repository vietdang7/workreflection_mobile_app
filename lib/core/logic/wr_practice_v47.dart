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
import '../models/wr_intelligence.dart';

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
  final g = intake.goal.trim().toLowerCase().replaceAll(RegExp(r'\.$'), '');
  final what = g.isEmpty ? 'điều bạn muốn khác đi' : g;
  final whatEn = g.isEmpty ? 'what you want to change' : g;
  final tried = _triedQuote(intake.tried);
  final avoid = tried == null
      ? ''
      : ' Lần này đừng lặp lại điều bạn đã thử: "$tried".';
  final avoidEn = tried == null
      ? ''
      : ' This time, do not repeat what you already tried: "$tried".';
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
          'Chọn một trong các cách ở trên và thử trong một tình huống thật, liên '
          'quan tới $what.$avoid',
      contentEn:
          'Pick one of the ways above and try it in a real situation, related '
          'to $whatEn.$avoidEn',
      isPremium: false,
    ),
    PracticeStep(
      stepId: '$themeId-4',
      themeId: themeId,
      stepOrder: 4,
      title: 'Mang về: Giữ lại một câu hỏi',
      titleEn: 'Take it with you: Keep one question',
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
      fit: 'Hợp khi bạn chưa chắc đây là một mẫu hình hay chỉ là một lần xảy ra.',
      fitEn: 'Good when you are not sure whether this is a pattern or a one-off.',
      tradeoff: 'Bạn có thêm thông tin, nhưng điều này có thể kéo dài thêm.',
      tradeoffEn:
          'You learn more, but the situation may go on a little longer.',
    ),
    const PracticeMentorOption(
      id: 'talk',
      title: 'Đưa người khác vào cuộc',
      titleEn: 'Bring someone else in',
      fit: 'Hợp khi tình huống phụ thuộc vào ai đó hoặc cần thêm một góc nhìn.',
      fitEn: 'Good when the situation depends on someone else or needs another view.',
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
