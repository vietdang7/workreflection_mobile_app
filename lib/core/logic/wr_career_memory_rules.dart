// Quy tắc sinh mảnh ký ức — Career Memory.
//
// Nguồn: WorkReflection_Changelog_20260824.docx §8.2 và §9.
//
// §8.2, điều quan trọng nhất: "STORY là đơn vị dữ liệu gốc. Ba loại còn lại
// (Cột mốc, Chủ đề, Insight) đều là lớp diễn giải được sinh THÊM dựa trên
// STORY, không phải 4 loại dữ liệu độc lập ngang hàng."
//
//   Câu chuyện · tự động 1-1 mỗi lượt Reflection khép lại (đã có sẵn từ trước).
//   Cột mốc    · khi STORY vừa tạo là lần ĐẦU TIÊN thuộc một loại nào đó.
//   Chủ đề     · khi cùng một nhóm xuất hiện ≥3 lần trong 14 ngày gần nhất.
//   Insight    · định kỳ (14 ngày, hoặc 5 lượt Reflection mới), Premium.
//
// §8.2 ghi chú cho dev, và đây là lý do file này tồn tại: "Mỗi lần một trong
// các sự kiện trên xảy ra, backend cần LƯU LẠI thành một bản ghi riêng (ngày,
// loại, tiêu đề, excerpt, chi tiết mở rộng) — không suy luận lại từ
// recentSituationIds mỗi lần hiển thị". Nên các hàm ở đây trả về BẢN NHÁP để
// người gọi ghi xuống `wr_career_memory_events`, chứ không trả về chữ để vẽ.
//
// GOM NHÓM THEO NHU CẦU, KHÔNG THEO MÃ CHIỀU. §8.2 nói "cùng một dim/need".
// Mười chiều SCA không có tên tiếng Việt nào — chỉ có mã S1…A4, mà v1.6 §XII.5
// cấm hiện mã ra cho người dùng. Bốn nhu cầu thì có sẵn tên đọc được
// ([needLabel]), và mỗi chiều đều thuộc đúng một nhu cầu. Nên "nhóm" ở đây là
// nhu cầu.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

import '../models/wr_content.dart';
import '../models/wr_episode.dart';
import 'wr_dominant_need.dart';

/// Mã `behavior` của ba loại mảnh ký ức được sinh thêm.
const String kMilestoneBehavior = 'career_milestone';
const String kThemeBehavior = 'career_theme';
const String kInsightBehavior = 'career_insight';

/// §8.2: "cùng một dim/need xuất hiện từ 3 lần trở lên trong 14 ngày gần nhất".
const int kThemeMinCount = 3;
const int kThemeWindowDays = 14;

/// §8.2: "định kỳ (ví dụ mỗi 14 ngày, hoặc sau mỗi 5 lượt Reflection mới)".
const int kInsightEveryDays = 14;
const int kInsightEveryStories = 5;

/// §9, khung "Một khoảng lặng đáng chú ý": bao nhiêu ngày vắng mặt thì đáng nói.
///
/// Dài hơn cửa sổ chủ đề (14 ngày) một tuần. Bằng đúng 14 thì một nhóm vừa rơi
/// khỏi cửa sổ đã bị gọi là "khoảng lặng" ngay hôm sau, trong khi người dùng chỉ
/// mới nghỉ vài ngày.
const int kQuietGapDays = 21;

/// Một mảnh ký ức sắp được ghi xuống.
///
/// Không phải [CareerMemoryEvent] vì `id` và `createdAt` do DB sinh; người gọi
/// dựng bản ghi thật từ đây cộng `userId`.
class CareerMemoryDraft {
  const CareerMemoryDraft({
    required this.behavior,
    required this.text,
    this.need,
    this.scaDimension,
    this.situationCode,
  });

  /// Một trong ba mã ở trên.
  final String behavior;

  /// Nội dung hiển thị trên dòng thời gian.
  final String text;

  final HumanNeed? need;
  final ScaDimension? scaDimension;
  final String? situationCode;
}

// ---------------------------------------------------------------------------
// Tiện ích chung
// ---------------------------------------------------------------------------

/// Những lượt Reflection đã khép, mới nhất đứng đầu.
///
/// Chỉ Episode đã khép mới tính là STORY — WDA Inv.6, và cũng là điều §8.2 mô
/// tả: "mỗi khi hoàn thành một lượt Reflection (xong bước Lựa chọn)".
List<ReflectionEpisode> closedStories(List<ReflectionEpisode> episodes) {
  final closed = [
    for (final e in episodes)
      if (e.state == ExperienceState.integrated) e,
  ]..sort((a, b) {
      final av = _storyAt(a);
      final bv = _storyAt(b);
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;
      return bv.compareTo(av);
    });
  return closed;
}

DateTime? _storyAt(ReflectionEpisode e) =>
    e.closedAt ?? e.updatedAt ?? e.openedAt;

/// Chọn một biến thể câu chữ theo cách LẶP LẠI ĐƯỢC.
///
/// §9: "khoảng 4–6 khung × 2–3 biến thể câu chữ mỗi khung". Không dùng ngẫu
/// nhiên: cùng một dữ liệu phải luôn cho ra cùng một câu, nếu không thì test
/// không khoá được nội dung, và mảnh ký ức đã ghi hôm nay sẽ khác với thứ người
/// dùng đọc lại ngày mai.
String pickVariant(List<String> variants, int seed) =>
    variants[seed.abs() % variants.length];

// ---------------------------------------------------------------------------
// Cột mốc — §8.2
// ---------------------------------------------------------------------------

/// Câu giải thích vì sao lượt này là một cột mốc. Null = không phải cột mốc.
///
/// §8.2 nói rõ Cột mốc KHÔNG phải một bản ghi tách biệt: "Hệ thống gắn cờ 'lần
/// đầu' lên STORY đó". Nên hàm này trả về CHỮ để dán lên chính STORY, không trả
/// về [CareerMemoryDraft] để ghi thêm một dòng.
///
/// Sai chỗ này thì đếm sai: mỗi lượt Reflection đầu tiên sẽ thành hai mảnh ký
/// ức, và con số "bạn đã để lại N mảnh" ở tab Hành trình lệch khỏi số lần người
/// dùng thật sự ngồi xuống nhìn lại — đúng loại lệch mà khách đã báo 24/08.
///
/// Hai loại "lần đầu" mà luồng Reflect biết chắc:
///   · lần nhìn lại đầu tiên của cả hành trình,
///   · lần đầu chạm vào một nhóm nhu cầu mới.
///
/// [previousStories] là các STORY có TRƯỚC lượt đang xét — không chứa chính nó.
/// Truyền nhầm cả nó vào thì mọi "lần đầu" đều trượt, vì nhóm của nó đã có mặt.
String? milestoneTextForStory({
  required ReflectionEpisode story,
  required List<ReflectionEpisode> previousStories,
}) {
  if (previousStories.isEmpty) {
    return 'Lần đầu tiên bạn dừng lại và nhìn lại một chuyện ở công việc.';
  }

  final need = story.humanNeed;
  if (need == null) return null;
  if (previousStories.any((e) => e.humanNeed == need)) return null;

  return 'Lần đầu bạn nhìn vào một chuyện thuộc về ${needSeekingLabel(need)}.';
}

/// Cột mốc của TỪNG STORY trong [stories], khoá theo `id`.
///
/// [stories] mới nhất đứng đầu (đúng thứ tự [closedStories] trả về). Duyệt
/// ngược từ cũ tới mới để "lần đầu" được xét đúng chiều thời gian.
///
/// STORY không có `id` bị bỏ qua — không có khoá thì màn hình không tra được.
Map<String, String> milestonesByStoryId(List<ReflectionEpisode> stories) {
  final oldestFirst = stories.reversed.toList();
  final out = <String, String>{};
  final seen = <ReflectionEpisode>[];
  for (final s in oldestFirst) {
    final text = milestoneTextForStory(story: s, previousStories: seen);
    final id = s.id;
    if (text != null && id != null) out[id] = text;
    seen.add(s);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Dòng chi tiết — cột `detail` của CAREER_MEMORY_ENTRIES (mockup v16)
// ---------------------------------------------------------------------------
//
// Mockup v16 cho mỗi mảnh ký ức BA tầng chữ, không phải hai:
//
//   title    tên gọi ngắn        · luôn hiện
//   excerpt  nội dung của mảnh   · luôn hiện
//   detail   VÌ SAO mảnh này có mặt ở đây · chỉ hiện khi bấm mở
//
// Tầng thứ ba là thứ app đang thiếu hẳn, và nó không phải chữ trang trí: cả ba
// loại được sinh THÊM (Cột mốc · Chủ đề · Insight) đều do hệ thống tự gắn, nên
// nếu không nói ra luật thì người dùng mở Career Memory và thấy những dòng
// không rõ từ đâu ra. §8.2 gọi đây là "chi tiết mở rộng".
//
// KHÔNG có cột `detail` trong `wr_career_memory_events`, và cũng không cần: câu
// này suy ra được trọn vẹn từ loại mảnh cộng dữ liệu đã có. Thêm một cột để
// chép lại một luật cố định là tự tạo cho mình hai nguồn sự thật cho cùng một
// câu chữ.

/// Chi tiết của một mảnh CÂU CHUYỆN / CỘT MỐC.
///
/// [countThisMonth] là số lượt cùng nhóm nhu cầu trong CÙNG THÁNG với lượt đang
/// xét, kể cả chính nó — mockup ghi "Đây là lần thứ 3 trong tháng bạn chọn một
/// tình huống thuộc nhóm này". Bằng 1 thì bỏ câu đó đi: "lần thứ 1" không nói
/// lên điều gì.
String memoryDetailForStory({
  required ReflectionEpisode story,
  required int countThisMonth,
  String? milestoneText,
}) {
  final parts = <String>[];

  if (milestoneText != null && milestoneText.trim().isNotEmpty) {
    parts.add(milestoneText.trim());
    // Nói rõ đây không phải thứ người dùng tự đánh dấu. Không có câu này thì
    // "Cột mốc" đọc như một nhãn họ quên là mình đã gắn.
    parts.add('Cột mốc được gắn tự động, bạn không phải tự đánh dấu.');
  }

  final need = story.humanNeed;
  if (need != null) {
    parts.add('Tình huống thuộc nhóm ${needSeekingLabel(need)}.');
    if (countThisMonth > 1) {
      parts.add('Đây là lần thứ $countThisMonth trong tháng bạn nhìn vào một '
          'chuyện thuộc nhóm này.');
    }
  }

  return parts.join(' ');
}

/// Số lượt cùng nhóm nhu cầu với [story], trong cùng tháng, tính cả [story].
///
/// Đếm theo THÁNG LỊCH chứ không theo cửa sổ 30 ngày: câu hiển thị nói "trong
/// tháng", nên phép đếm phải đúng nghĩa đen của chữ đó. Hai đơn vị khác nhau
/// đứng sau cùng một chữ là đúng loại lệch khách gọi tên hôm 24/08.
int needCountThisMonth(
  ReflectionEpisode story,
  List<ReflectionEpisode> stories,
) {
  final at = _storyAt(story);
  final need = story.humanNeed;
  if (at == null || need == null) return 0;
  var n = 0;
  for (final e in stories) {
    if (e.humanNeed != need) continue;
    final t = _storyAt(e);
    if (t == null) continue;
    if (t.year != at.year || t.month != at.month) continue;
    // Chỉ đếm những lượt CÓ TRƯỚC hoặc chính nó — mảnh ký ức của ngày 3 không
    // được nói "lần thứ 5" nhờ những lượt xảy ra sau đó.
    if (t.isAfter(at)) continue;
    n++;
  }
  return n;
}

/// Chi tiết của một mảnh CHỦ ĐỀ. Luật §8.2, viết cho người dùng đọc.
const String kThemeDetail =
    'Khi một nhóm lặp lại từ $kThemeMinCount lần trở lên trong '
    '$kThemeWindowDays ngày, hệ thống tự gọi tên nó thành một chủ đề riêng. '
    'Bạn không phải tự đặt tên.';

/// Chi tiết của một mảnh INSIGHT. Luật §8.2 + §9.
const String kInsightDetail =
    'Insight được tổng hợp từ nhiều lần nhìn lại gần nhất, không phải từ một '
    'lần duy nhất. Nó sinh định kỳ mỗi $kInsightEveryDays ngày, hoặc sau mỗi '
    '$kInsightEveryStories lượt nhìn lại mới.';

// ---------------------------------------------------------------------------
// Chủ đề — §8.2
// ---------------------------------------------------------------------------

const List<String> _kThemeEmerging = [
  // §9, khung "Chủ đề vừa nổi lên" — câu mẫu của tài liệu.
  '{n} lần Reflection gần đây của bạn đều xoay quanh {need}. Đây có thể là '
      'điều đáng để nhìn kỹ hơn.',
  'Trong {days} ngày qua, {n} lần bạn nhìn lại đều dẫn về {need}. Một chủ đề '
      'đang hình thành.',
];

/// Số lượt thuộc [need] trong [days] ngày gần nhất.
int needCountWithin(
  List<ReflectionEpisode> stories,
  HumanNeed need, {
  required DateTime now,
  int days = kThemeWindowDays,
}) {
  final cutoff =
      DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
  var n = 0;
  for (final e in stories) {
    final at = _storyAt(e);
    if (at == null || at.isBefore(cutoff)) continue;
    if (e.humanNeed == need) n++;
  }
  return n;
}

/// Chủ đề mới, nếu lượt vừa khép làm nhóm của nó chạm ngưỡng.
///
/// [stories] PHẢI chứa cả lượt vừa khép — ngưỡng đếm cả nó.
///
/// [existingThemeNeeds] là các nhóm đã từng sinh chủ đề. Thiếu nó thì cứ mỗi
/// lượt mới lại sinh thêm một chủ đề trùng, và dòng thời gian đầy những dòng
/// "chủ đề vừa nổi lên" giống hệt nhau.
CareerMemoryDraft? themeForStory({
  required ReflectionEpisode story,
  required List<ReflectionEpisode> stories,
  required Set<HumanNeed> existingThemeNeeds,
  required DateTime now,
}) {
  final need = story.humanNeed;
  if (need == null || existingThemeNeeds.contains(need)) return null;

  final count = needCountWithin(stories, need, now: now);
  if (count < kThemeMinCount) return null;

  final text = pickVariant(_kThemeEmerging, count)
      .replaceAll('{n}', '$count')
      .replaceAll('{days}', '$kThemeWindowDays')
      .replaceAll('{need}', needSeekingLabel(need));

  return CareerMemoryDraft(
    behavior: kThemeBehavior,
    text: text,
    need: need,
    scaDimension: story.scaDimension,
  );
}

/// Mọi nhóm đã đủ ngưỡng mà chưa có chủ đề, cũ trước.
///
/// [themeForStory] chỉ xét nhóm của ĐÚNG lượt vừa khép — nguyên văn §8.2: "dim
/// này đã lặp đủ 3 lần trong 14 ngày chưa?". Đọc chặt như vậy thì luật bỏ sót
/// hai trường hợp, và cả hai đều xảy ra thật:
///
///   · Nhóm đủ ngưỡng nhưng lượt mới nhất thuộc nhóm KHÁC. Ví dụ bốn lượt về
///     "được lắng nghe" rồi một lượt về "rõ ràng" — nhóm thứ nhất chưa bao giờ
///     được hỏi tới, và sẽ không bao giờ được hỏi nữa nếu người dùng chuyển
///     hẳn sang chủ đề khác.
///   · Toàn bộ lịch sử có TRƯỚC ngày luật này chạy. Bản 24/08 chỉ chạy tiến,
///     nên 57 lượt đã khép trong DB không sinh nổi một chủ đề nào — người đã
///     nhìn lại hai chục lần vẫn thấy Career Memory trống trơn.
///
/// Quét cả bốn nhóm giải quyết cả hai, và không đổi ngưỡng: vẫn là ≥
/// [kThemeMinCount] lượt trong [kThemeWindowDays] ngày.
///
/// [existingThemeNeeds] được cộng dồn trong lúc quét, nên một lần gọi không thể
/// sinh hai chủ đề cho cùng một nhóm.
List<CareerMemoryDraft> themesDue({
  required List<ReflectionEpisode> stories,
  required Set<HumanNeed> existingThemeNeeds,
  required DateTime now,
}) {
  final seen = {...existingThemeNeeds};
  final out = <CareerMemoryDraft>[];

  // Duyệt theo thứ tự nhóm cố định, không theo thứ tự gặp trong dữ liệu: cùng
  // một lịch sử phải luôn cho ra cùng một thứ tự chủ đề.
  for (final need in HumanNeed.values) {
    if (seen.contains(need)) continue;
    final count = needCountWithin(stories, need, now: now);
    if (count < kThemeMinCount) continue;

    // Lấy `scaDimension` của lượt gần nhất thuộc nhóm — chủ đề là chuyện của
    // nhóm, nhưng vẫn nên mang theo chiều để phần đối chiếu sau này dùng được.
    ScaDimension? dim;
    for (final e in stories) {
      if (e.humanNeed == need) {
        dim = e.scaDimension;
        break;
      }
    }

    out.add(CareerMemoryDraft(
      behavior: kThemeBehavior,
      text: pickVariant(_kThemeEmerging, count)
          .replaceAll('{n}', '$count')
          .replaceAll('{days}', '$kThemeWindowDays')
          .replaceAll('{need}', needSeekingLabel(need)),
      need: need,
      scaDimension: dim,
    ));
    seen.add(need);
  }

  return out;
}

// ---------------------------------------------------------------------------
// Insight — §9, các khung câu chuyện
// ---------------------------------------------------------------------------

const List<String> _kThemeProgress = [
  // §9, khung "Chuyển biến trong một chủ đề".
  'Trong {days} ngày qua, bạn đang học cách {need}, từ {first}, đến {last}.',
  'Cùng một mạch {need} chạy suốt {days} ngày qua: bắt đầu ở {first}, và gần '
      'nhất là {last}.',
];

const List<String> _kQuietGap = [
  // §9, khung "Một khoảng lặng đáng chú ý".
  'Nhóm {need} từng xuất hiện thường xuyên, nhưng {days} ngày gần đây bạn '
      'không quay lại tình huống nào thuộc nhóm này.',
  '{days} ngày rồi bạn chưa nhìn lại chuyện nào thuộc {need}, dù trước đó đây '
      'là nhóm trở đi trở lại.',
];

/// Khung "Chuyển biến trong một chủ đề".
///
/// §9: "Một THEME đã có ≥3 STORY — lấy STORY đầu và cuối trong cùng nhóm dim."
/// Và ghi chú cuối §9: khi một THEME được tạo thì lưu luôn STORY đầu và STORY
/// gần nhất, "để có đủ hai đầu mối". Ở đây hai đầu mối được lấy tại thời điểm
/// sinh Insight, từ chính danh sách STORY — cùng một nguồn, không cần bảng phụ.
String? themeProgressNarrative({
  required List<ReflectionEpisode> stories,
  required HumanNeed need,
  required Map<String, String> situationLabels,
  required DateTime now,
}) {
  final cutoff = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: kThemeWindowDays - 1));
  // [stories] mới nhất đứng đầu.
  final inTheme = [
    for (final e in stories)
      if (e.humanNeed == need &&
          _storyAt(e) != null &&
          !_storyAt(e)!.isBefore(cutoff))
        e,
  ];
  if (inTheme.length < kThemeMinCount) return null;

  final last = _storyTitle(inTheme.first, situationLabels);
  final first = _storyTitle(inTheme.last, situationLabels);
  if (first == null || last == null || first == last) return null;

  return pickVariant(_kThemeProgress, inTheme.length)
      .replaceAll('{days}', '$kThemeWindowDays')
      .replaceAll('{need}', needSeekingLabel(need))
      .replaceAll('{first}', '"$first"')
      .replaceAll('{last}', '"$last"');
}

/// Khung "Một khoảng lặng đáng chú ý".
///
/// §9: "Một dim từng là THEME nhưng biến mất khỏi Reflection gần đây."
String? quietGapNarrative({
  required List<ReflectionEpisode> stories,
  required Set<HumanNeed> pastThemeNeeds,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  for (final need in pastThemeNeeds) {
    DateTime? latest;
    for (final e in stories) {
      if (e.humanNeed != need) continue;
      final at = _storyAt(e);
      if (at == null) continue;
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    if (latest == null) continue;
    final gap = today.difference(DateTime(latest.year, latest.month, latest.day)).inDays;
    if (gap < kQuietGapDays) continue;
    return pickVariant(_kQuietGap, gap)
        .replaceAll('{days}', '$gap')
        .replaceAll('{need}', needSeekingLabel(need));
  }
  return null;
}

String? _storyTitle(
  ReflectionEpisode e,
  Map<String, String> situationLabels,
) {
  final code = e.situationCode;
  if (code != null) {
    final label = situationLabels[code];
    if (label != null && label.trim().isNotEmpty) return label.trim();
  }
  final meaning = e.draftMeaning?.trim();
  if (meaning != null && meaning.isNotEmpty) {
    return meaning.length <= 60 ? meaning : '${meaning.substring(0, 57)}…';
  }
  return null;
}

/// Đã tới kỳ sinh Insight chưa.
///
/// §8.2: "Định kỳ (ví dụ mỗi 14 ngày, hoặc sau mỗi 5 lượt Reflection mới)".
/// HOẶC, không phải VÀ: người viết dày trong một tuần vẫn xứng đáng có một
/// Insight, và người viết thưa cũng không phải chờ đủ năm lượt mới được đọc.
bool insightDue({
  required DateTime? lastInsightAt,
  required List<ReflectionEpisode> stories,
  required DateTime now,
}) {
  if (lastInsightAt == null) {
    return stories.length >= kInsightEveryStories;
  }
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(
          lastInsightAt.year, lastInsightAt.month, lastInsightAt.day))
      .inDays;
  if (days >= kInsightEveryDays) return true;

  final since = stories.where((e) {
    final at = _storyAt(e);
    return at != null && at.isAfter(lastInsightAt);
  }).length;
  return since >= kInsightEveryStories;
}

/// Insight định kỳ, nếu tới kỳ VÀ có ít nhất một khung nói được điều gì.
///
/// [selfAwarenessGapText] là khung "Lệch pha tự nhận thức". §9 nói thẳng khung
/// này "tái dùng logic đã có ở Diễn giải sâu", nên nó được TRUYỀN VÀO chứ không
/// tính lại ở đây — tính lại là dựng nguồn sự thật thứ hai cho cùng một câu.
CareerMemoryDraft? periodicInsight({
  required List<ReflectionEpisode> stories,
  required Set<HumanNeed> themeNeeds,
  required Map<String, String> situationLabels,
  required DateTime? lastInsightAt,
  required DateTime now,
  String? selfAwarenessGapText,
}) {
  if (!insightDue(
    lastInsightAt: lastInsightAt,
    stories: stories,
    now: now,
  )) {
    return null;
  }

  // Thứ tự ưu tiên: chuyển biến trong chủ đề đang chạy → lệch pha → khoảng
  // lặng. Cái đầu bám sát điều người dùng đang sống nhất.
  HumanNeed? progressNeed;
  String? text;
  for (final need in themeNeeds) {
    final t = themeProgressNarrative(
      stories: stories,
      need: need,
      situationLabels: situationLabels,
      now: now,
    );
    if (t != null) {
      text = t;
      progressNeed = need;
      break;
    }
  }

  text ??= selfAwarenessGapText?.trim().isNotEmpty == true
      ? selfAwarenessGapText!.trim()
      : null;

  text ??= quietGapNarrative(
    stories: stories,
    pastThemeNeeds: themeNeeds,
    now: now,
  );

  if (text == null) return null;

  return CareerMemoryDraft(
    behavior: kInsightBehavior,
    text: text,
    need: progressNeed,
  );
}

// ---------------------------------------------------------------------------
// Gộp: chạy sau mỗi STORY mới
// ---------------------------------------------------------------------------

/// Những mảnh ký ức PHẢI GHI THÊM sau mỗi STORY mới.
///
/// §8.2: "Mỗi khi một STORY mới được tạo, hệ thống cần chạy qua 2 câu hỏi: đây
/// có phải lần đầu thuộc loại gì không? (→ có thể gắn Cột mốc) và dim này đã lặp
/// đủ 3 lần trong 14 ngày chưa? (→ có thể sinh thêm một Chủ đề)."
///
/// Chỉ CHỦ ĐỀ và INSIGHT ra khỏi đây. Câu hỏi thứ nhất được trả lời bằng
/// [milestoneTextForStory] lúc hiển thị, vì §8.2 xếp Cột mốc là cờ trên STORY
/// chứ không phải bản ghi mới.
///
/// [stories] là toàn bộ STORY KỂ CẢ lượt vừa khép, mới nhất đứng đầu.
/// [pastEvents] là các mảnh ký ức đã ghi — dùng để biết nhóm nào đã có chủ đề và
/// Insight gần nhất là khi nào.
/// KHÔNG còn nhận `story` riêng. Từ khi phần chủ đề quét mọi nhóm ([themesDue])
/// thì lượt vừa khép không còn vai trò gì đặc biệt — nó chỉ là phần tử đầu của
/// [stories]. Giữ tham số đó lại là để người đọc tin rằng nó có ảnh hưởng.
List<CareerMemoryDraft> memoryFragmentsAfterStory({
  required List<ReflectionEpisode> stories,
  required List<CareerMemoryEvent> pastEvents,
  required Map<String, String> situationLabels,
  required DateTime now,
  String? selfAwarenessGapText,
}) {
  final themeNeeds = <HumanNeed>{
    for (final ev in pastEvents)
      if (ev.behavior == kThemeBehavior && ev.humanNeed != null) ev.humanNeed!,
  };

  DateTime? lastInsightAt;
  for (final ev in pastEvents) {
    if (ev.behavior != kInsightBehavior) continue;
    final at = ev.createdAt;
    if (at == null) continue;
    if (lastInsightAt == null || at.isAfter(lastInsightAt)) lastInsightAt = at;
  }

  final drafts = <CareerMemoryDraft>[];

  // Quét MỌI nhóm, không chỉ nhóm của [story] — xem [themesDue] để biết hai
  // trường hợp bị bỏ sót khi chỉ hỏi về nhóm của lượt vừa khép.
  for (final theme in themesDue(
    stories: stories,
    existingThemeNeeds: themeNeeds,
    now: now,
  )) {
    drafts.add(theme);
    themeNeeds.add(theme.need!);
  }

  final insight = periodicInsight(
    stories: stories,
    themeNeeds: themeNeeds,
    situationLabels: situationLabels,
    lastInsightAt: lastInsightAt,
    now: now,
    selfAwarenessGapText: selfAwarenessGapText,
  );
  if (insight != null) drafts.add(insight);

  return drafts;
}
