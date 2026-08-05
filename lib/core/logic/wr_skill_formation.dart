// Kỹ năng đã hình thành (Skill Formation) — spec "Kỹ năng đã hình thành".
// Pure Dart, không phụ thuộc Flutter.
//
// Vì sao phải viết lại lớp này (bản cũ: wr_skill_certification.dart):
//
// Mỗi Practice Theme chỉ có ba bước cố định (Nhận diện → Thử nghiệm → Chuyển
// hoá), làm xong là hết. Bản cũ coi "đi hết ba bước" là đã thành kỹ năng, nên
// một chủ đề làm một lượt đã được chứng nhận — trong khi ngưỡng ghi trong spec
// là 5 LẦN THỰC HÀNH THẬT. Ba bước không thể sinh ra năm lần lặp, nên ngưỡng ấy
// vĩnh viễn không có ý nghĩa.
//
// Spec gỡ nút này bằng hai giai đoạn:
//   • Làm quen (onboarding): ba bước, đi đúng một lần.
//   • Duy trì (maintaining): sau khi xong ba bước, chủ đề mở ra một hành động
//     nhẹ "Tôi vừa thực hành điều này hôm nay", bấm lại được nhiều lần theo
//     thời gian, mỗi lần cộng một vào bộ đếm của chính chủ đề đó.
// Kỹ năng hình thành khi bộ đếm chạm ngưỡng — đúng bản chất của Practice Theme:
// một hành vi cần lặp lại để thành phản xạ, không phải một việc làm một lần.
//
// Nguồn sự thật: KHÔNG có bảng đếm riêng (luật số 1, Nguyên tắc Logic Dữ liệu).
// practiceCount đếm thẳng từ Career Memory — cùng những mảnh ký ức mà tab Hành
// trình đang hiển thị.

import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

// ---------------------------------------------------------------------------
// Ngưỡng — cấu hình được, không hardcode cứng
// ---------------------------------------------------------------------------

/// Ngưỡng mặc định: 5 lần thực hành thật.
const int kSkillThresholdDefault = 5;

/// Ngưỡng đang áp dụng.
///
/// Spec yêu cầu "nên để cấu hình được, không hardcode cứng khi lên production,
/// phòng khi cần điều chỉnh theo dữ liệu thật sau này". Đổi bằng build flag,
/// không cần sửa mã:
///
///     flutter build apk --dart-define=WR_SKILL_THRESHOLD=7
///
/// Mọi hàm dưới đây vẫn nhận `threshold` rời để test và để sau này đọc từ
/// remote config mà không phải sửa chữ ký hàm.
const int kSkillThreshold =
    int.fromEnvironment('WR_SKILL_THRESHOLD', defaultValue: kSkillThresholdDefault);

// ---------------------------------------------------------------------------
// Mã behavior trong Career Memory
// ---------------------------------------------------------------------------

/// Mỗi lần hoàn thành một bước của giai đoạn làm quen.
const String kPracticeStepBehavior = 'practice_step_done';

/// Mỗi lần người dùng tự ghi nhận "tôi vừa thực hành điều này hôm nay".
const String kPracticeMaintainedBehavior = 'practice_maintained';

/// Dấu mốc kỹ năng đã hình thành.
///
/// Giữ nguyên chuỗi cũ `skill_certified`: dữ liệu người dùng đã có mảnh ký ức
/// mang mã này, và tab Hành trình đang gắn nhãn "KỸ NĂNG" theo nó. Đổi chuỗi là
/// làm mất dấu mốc cũ của họ.
const String kSkillFormedBehavior = 'skill_certified';

/// Hai loại sự kiện được tính là một lần thực hành thật.
const Set<String> kPracticeBehaviors = {
  kPracticeStepBehavior,
  kPracticeMaintainedBehavior,
};

// ---------------------------------------------------------------------------
// Giai đoạn của một chủ đề
// ---------------------------------------------------------------------------

enum SkillStage {
  /// Đang đi ba bước Nhận diện → Thử nghiệm → Chuyển hoá.
  onboarding,

  /// Đã xong ba bước, đang lặp lại để thành phản xạ.
  maintaining,

  /// Đã chạm ngưỡng — kỹ năng đã hình thành.
  formed,
}

/// Trạng thái hình thành kỹ năng của một chủ đề.
///
/// Ứng với bảng Schema trong spec: practiceCount, skillFormed, skillFormedDate.
/// Không có trường nào ở đây được lưu xuống DB — tất cả tính lại lúc đọc từ
/// Career Memory và ghi danh.
class SkillFormation {
  const SkillFormation({
    required this.themeId,
    required this.title,
    required this.practiceCount,
    required this.threshold,
    required this.onboardingDone,
    required this.skillFormedDate,
    this.scaDimension,
    this.lastPracticedAt,
    this.formedLine,
  });

  final String themeId;
  final String title;
  final ScaDimension? scaDimension;

  /// Câu nói riêng của chủ đề này khi chạm ngưỡng (bảng A.2).
  ///
  /// Ví dụ "Bạn không còn phải đoán, bạn hỏi." Null với ba chủ đề đời đầu và
  /// khi cột chưa được cập nhật — lúc đó màn ăn mừng dùng câu chung.
  final String? formedLine;

  /// Số lần thực hành thật đã ghi nhận: hoàn thành bước + ghi nhận duy trì.
  final int practiceCount;

  final int threshold;

  /// Đã đi hết ba bước làm quen (ghi danh đã khép).
  final bool onboardingDone;

  /// Ngày chạm ngưỡng. Null khi chưa hình thành.
  final DateTime? skillFormedDate;

  /// Lần thực hành gần nhất — dùng cho luật một lần mỗi ngày.
  final DateTime? lastPracticedAt;

  bool get skillFormed => practiceCount >= threshold;

  /// Còn bao nhiêu lần nữa. 0 khi đã đủ.
  int get remaining {
    final left = threshold - practiceCount;
    return left < 0 ? 0 : left;
  }

  /// 0..1 — dùng cho dải tiến độ.
  double get progress {
    if (threshold <= 0) return 1;
    final p = practiceCount / threshold;
    return p > 1 ? 1 : p;
  }

  SkillStage get stage {
    if (skillFormed) return SkillStage.formed;
    return onboardingDone ? SkillStage.maintaining : SkillStage.onboarding;
  }

  /// Chủ đề đã mở giai đoạn duy trì chưa — điều kiện hiện nút "Tôi vừa thực
  /// hành điều này hôm nay".
  ///
  /// Vẫn true sau khi kỹ năng đã hình thành: hình thành rồi không có nghĩa là
  /// thôi thực hành, và bộ đếm vẫn nên chạy tiếp.
  bool get canMaintain => onboardingDone;
}

// ---------------------------------------------------------------------------
// Đếm từ Career Memory
// ---------------------------------------------------------------------------

/// Sự kiện [e] có thuộc [theme] không, bất kể loại sự kiện.
///
/// Một sự kiện có `theme_id` thì `theme_id` là câu trả lời cuối cùng — không
/// bao giờ lùi về so tên nữa (Phần C mục 1). So theo tên là nguồn gốc của lỗi
/// cộng chung bộ đếm giữa các chủ đề trùng tên hoặc trùng chiều (`pt-voice`
/// với `pt-c2`, `pt-rhythm` với `pt-a2`, `pt-feedback` với `pt-c3`).
///
/// Chỉ những mảnh ký ức ghi trước 05/08/2026 mới không có `theme_id`; với
/// riêng chúng vẫn so theo tên, nếu không người dùng mất sạch tiến độ đã có.
bool _belongsTo(CareerMemoryEvent e, PracticeTheme theme) {
  final id = e.themeId;
  if (id != null && id.isNotEmpty) return id == theme.themeId;
  return _titleMatches(e.reflectionText, theme.title);
}

/// So theo tên — chỉ dùng cho dữ liệu cũ chưa có `theme_id`.
///
/// Sự kiện được ghi dạng "&lt;tên chủ đề&gt; · &lt;tên bước&gt;". Không so
/// bằng `startsWith` trần: chủ đề "Lắng nghe" sẽ nuốt luôn sự kiện của chủ đề
/// "Lắng nghe chủ động". Ký tự ngay sau tên phải là dấu phân cách, không phải
/// chữ.
bool _titleMatches(String? text, String title) {
  if (text == null) return false;
  if (!text.startsWith(title)) return false;
  final rest = text.substring(title.length).trimLeft();
  if (rest.isEmpty) return true;
  return _kTitleSeparators.contains(rest[0]);
}

/// Sự kiện [e] có phải một lần thực hành của [theme] không?
bool _isPracticeOf(CareerMemoryEvent e, PracticeTheme theme) {
  if (!kPracticeBehaviors.contains(e.behavior)) return false;
  return _belongsTo(e, theme);
}

/// Dấu ngăn giữa tên chủ đề và phần sau nó trong `reflection_text`.
/// `·` là dạng đang ghi; các dấu kia là dữ liệu cũ còn trong Career Memory.
const Set<String> _kTitleSeparators = {'·', '—', '–', '-', ':', '|'};

/// Số lần đã thực hành một chủ đề, đếm từ Career Memory.
int practiceCountForTheme(
  PracticeTheme theme,
  List<CareerMemoryEvent> events,
) =>
    events.where((e) => _isPracticeOf(e, theme)).length;

/// Lần thực hành gần nhất của một chủ đề.
DateTime? lastPracticedAtForTheme(
  PracticeTheme theme,
  List<CareerMemoryEvent> events,
) {
  DateTime? latest;
  for (final e in events) {
    if (!_isPracticeOf(e, theme)) continue;
    final at = e.createdAt;
    if (at == null) continue;
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest;
}

/// Đã ghi nhận duy trì cho [theme] trong ngày [now] chưa?
///
/// Một ngày một lần. Spec nói "bấm lặp lại nhiều lần theo thời gian" — theo
/// THỜI GIAN, nghĩa là năm lần rải ra năm ngày, không phải năm cú bấm trong
/// mười giây. Không có ràng buộc này thì con số "đã thực hành 5 lần" không còn
/// phản chiếu nỗ lực thật, và cái khoảnh khắc ăn mừng cũng mất giá trị theo.
bool maintainedToday(
  PracticeTheme theme,
  List<CareerMemoryEvent> events,
  DateTime now,
) {
  for (final e in events) {
    if (e.behavior != kPracticeMaintainedBehavior) continue;
    if (!_isPracticeOf(e, theme)) continue;
    final at = e.createdAt;
    if (at == null) continue;
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return true;
    }
  }
  return false;
}

/// Ngày kỹ năng của [theme] được ghi nhận là đã hình thành.
///
/// Ưu tiên mảnh ký ức dấu mốc; chưa kịp ghi (mất mạng chẳng hạn) thì lấy ngày
/// của lần thực hành thứ [threshold] — đúng cái ngày người dùng chạm ngưỡng.
DateTime? skillFormedDateFor(
  PracticeTheme theme,
  List<CareerMemoryEvent> events, {
  int threshold = kSkillThreshold,
}) {
  for (final e in events) {
    if (e.behavior == kSkillFormedBehavior &&
        _belongsTo(e, theme) &&
        e.createdAt != null) {
      return e.createdAt;
    }
  }

  final dates = <DateTime>[
    for (final e in events)
      if (_isPracticeOf(e, theme) && e.createdAt != null) e.createdAt!,
  ]..sort();
  if (dates.length < threshold) return null;
  return dates[threshold - 1];
}

// ---------------------------------------------------------------------------
// Dựng trạng thái
// ---------------------------------------------------------------------------

/// Trạng thái hình thành kỹ năng của một chủ đề đã ghi danh.
///
/// Trả null khi chưa ghi danh: chưa bắt đầu thì không có gì để hình thành.
SkillFormation? skillFormationFor({
  required PracticeTheme theme,
  required PracticeEnrollment? enrollment,
  required List<CareerMemoryEvent> events,
  int threshold = kSkillThreshold,
}) {
  if (enrollment == null) return null;
  final count = practiceCountForTheme(theme, events);
  return SkillFormation(
    themeId: theme.themeId,
    title: theme.title,
    scaDimension: theme.scaDimension,
    formedLine: theme.formedLine,
    practiceCount: count,
    threshold: threshold,
    onboardingDone: enrollment.completedAt != null,
    skillFormedDate: count >= threshold
        ? skillFormedDateFor(theme, events, threshold: threshold)
        : null,
    lastPracticedAt: lastPracticedAtForTheme(theme, events),
  );
}

/// Trạng thái của MỌI chủ đề đang theo, theo thứ tự chủ đề truyền vào.
///
/// Trả cả chủ đề chưa đạt ngưỡng — màn Kỹ năng cần cả hai nửa: cái đã hình
/// thành và cái đang trên đường, để người dùng thấy mình còn cách bao xa.
List<SkillFormation> skillFormations({
  required List<PracticeTheme> themes,
  required List<PracticeEnrollment> enrollments,
  required List<CareerMemoryEvent> events,
  int threshold = kSkillThreshold,
}) {
  final byTheme = <String, PracticeEnrollment>{
    for (final e in enrollments) e.themeId: e,
  };
  // Gộp theo TÊN, không theo theme_id — xem `_keepsOver`.
  final byTitle = <String, SkillFormation>{};
  final retiredOf = <String, bool>{};
  final order = <String>[];
  for (final theme in themes) {
    final f = skillFormationFor(
      theme: theme,
      enrollment: byTheme[theme.themeId],
      events: events,
      threshold: threshold,
    );
    if (f == null) continue;
    final kept = byTitle[f.title];
    if (kept == null) {
      order.add(f.title);
      byTitle[f.title] = f;
      retiredOf[f.title] = theme.isRetired;
    } else if (_keepsOver(f, theme.isRetired, kept, retiredOf[f.title]!)) {
      byTitle[f.title] = f;
      retiredOf[f.title] = theme.isRetired;
    }
  }
  return [for (final t in order) byTitle[t]!];
}

/// Trong hai chủ đề cùng tên, chủ đề nào đại diện cho kỹ năng đó.
///
/// Vì sao phải gộp: thư viện có hai chủ đề trùng tên — `pt-voice` (bản cũ) và
/// `pt-c2` (bản theo chiều SCA) đều tên "Dám lên tiếng". Ai ghi danh cả hai sẽ
/// thấy hai dòng y hệt nhau ở màn Kỹ năng, và vì bộ đếm nhận sự kiện THEO TÊN
/// (Career Memory không lưu theme_id), hai dòng ấy luôn hiện cùng một con số.
/// Tệ hơn: chạm ngưỡng là ăn mừng hai lần và ghi hai dấu mốc cho cùng một kỹ
/// năng. Một cái tên là một kỹ năng — gộp ở đây thì mọi màn đọc chung đều sạch.
///
/// Giữ chủ đề đã xong ba bước làm quen trước: đó là chỗ người dùng thực sự có
/// tiến độ, và cũng là chỗ mở nút "vừa thực hành hôm nay". Hoà thì giữ chủ đề
/// còn đang đề xuất (chưa `retired_at`), vì nội dung bước của nó mới hơn.
bool _keepsOver(
  SkillFormation candidate,
  bool candidateRetired,
  SkillFormation kept,
  bool keptRetired,
) {
  if (candidate.onboardingDone != kept.onboardingDone) {
    return candidate.onboardingDone;
  }
  if (candidateRetired != keptRetired) return !candidateRetired;
  return false;
}

/// Chỉ những kỹ năng đã hình thành, mới nhất trước.
List<SkillFormation> formedSkills(List<SkillFormation> all) {
  final formed = all.where((f) => f.skillFormed).toList();
  formed.sort((a, b) {
    final da = a.skillFormedDate;
    final db = b.skillFormedDate;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return formed;
}

/// Chủ đề đang trên đường, gần đích nhất trước.
List<SkillFormation> formingSkills(List<SkillFormation> all) {
  final forming = all.where((f) => !f.skillFormed).toList();
  forming.sort((a, b) => b.practiceCount.compareTo(a.practiceCount));
  return forming;
}

/// Kỹ năng vừa hình thành mà Career Memory chưa có dấu mốc.
///
/// Dùng để ghi dấu mốc và ăn mừng ĐÚNG MỘT LẦN.
/// [themes] là chính những chủ đề đã dựng nên [formations] — cần để nhận dấu
/// mốc theo `theme_id`, vì [SkillFormation] không mang theo tên chủ đề gốc của
/// dữ liệu cũ.
List<SkillFormation> newlyFormed({
  required List<SkillFormation> formations,
  required List<CareerMemoryEvent> events,
  List<PracticeTheme> themes = const [],
}) {
  final themeById = {for (final t in themes) t.themeId: t};
  final milestones =
      events.where((e) => e.behavior == kSkillFormedBehavior).toList();

  // Dữ liệu cũ chỉ có tên; dữ liệu mới có `theme_id`. Một kỹ năng coi là đã ăn
  // mừng nếu khớp một trong hai — bỏ sót một dấu mốc cũ là ăn mừng lần thứ hai
  // cho cùng một kỹ năng, và tab Hành trình sẽ có hai dòng cho một chuyện.
  bool announced(SkillFormation f) {
    final theme = themeById[f.themeId];
    for (final e in milestones) {
      if (theme != null && _belongsTo(e, theme)) return true;
      if (e.themeId == f.themeId) return true;
      if (e.themeId == null && e.reflectionText == f.title) return true;
    }
    return false;
  }

  return [
    for (final f in formations)
      if (f.skillFormed && !announced(f)) f,
  ];
}
