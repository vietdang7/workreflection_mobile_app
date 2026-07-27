// Chứng nhận kỹ năng mới — WDA §2.5 (Growth is Accumulated) + WPA Block 7.
// Pure Dart, no Flutter dependencies.
//
// Yêu cầu khách 2026-07-27: "nếu người dùng lặp đi lặp lại việc thực hành một
// hành vi đủ nhiều, hệ thống sẽ chứng nhận họ đã nâng cấp thành kỹ năng mới".
//
// Đây là GHI NHẬN, không phải diễn giải — nên bản miễn phí cũng thấy.
// WDA Invariant: Growth là kết quả tích lũy của nhiều vòng lặp, không phải của
// một sự kiện; vì vậy điều kiện là lặp lại, không phải hoàn thành một lần.

import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

/// Số lần thực hành lặp lại đủ để một chủ đề trở thành kỹ năng.
const int kSkillPracticeThreshold = 5;

/// Mã behavior của memory event ghi mỗi lần hoàn thành một bước thực hành.
const String kPracticeStepBehavior = 'practice_step_done';

/// Mã behavior của memory event đánh dấu một kỹ năng đã được chứng nhận.
const String kSkillCertifiedBehavior = 'skill_certified';

/// Một kỹ năng đã được chứng nhận.
class CertifiedSkill {
  const CertifiedSkill({
    required this.themeId,
    required this.title,
    required this.practiceCount,
    required this.completed,
  });

  final String themeId;
  final String title;

  /// Số lần đã thực hành (đếm từ Career Memory).
  final int practiceCount;

  /// Đã đi hết chuỗi bước của chủ đề.
  final bool completed;
}

/// Số lần đã thực hành một chủ đề, đếm từ các sự kiện Career Memory.
int practiceCountForTheme(
  PracticeTheme theme,
  List<CareerMemoryEvent> events,
) {
  var count = 0;
  for (final e in events) {
    if (e.behavior != kPracticeStepBehavior) continue;
    final text = e.reflectionText;
    if (text == null) continue;
    // Sự kiện được ghi dạng "<tên chủ đề> — <tên bước>".
    if (text.startsWith(theme.title)) count++;
  }
  return count;
}

/// Chủ đề [theme] đã đủ điều kiện thành kỹ năng chưa?
///
/// Đủ khi một trong hai điều xảy ra:
///   • đã đi hết chuỗi bước của chủ đề (enrollment.completedAt != null), hoặc
///   • đã lặp lại thực hành ít nhất [kSkillPracticeThreshold] lần.
bool isSkillCertified({
  required PracticeTheme theme,
  required PracticeEnrollment? enrollment,
  required List<CareerMemoryEvent> events,
}) {
  if (enrollment == null) return false;
  if (enrollment.completedAt != null) return true;
  return practiceCountForTheme(theme, events) >= kSkillPracticeThreshold;
}

/// Toàn bộ kỹ năng đã được chứng nhận, theo thứ tự chủ đề truyền vào.
List<CertifiedSkill> certifiedSkills({
  required List<PracticeTheme> themes,
  required List<PracticeEnrollment> enrollments,
  required List<CareerMemoryEvent> events,
}) {
  final byTheme = <String, PracticeEnrollment>{
    for (final e in enrollments) e.themeId: e,
  };

  final result = <CertifiedSkill>[];
  for (final theme in themes) {
    final enrollment = byTheme[theme.themeId];
    if (!isSkillCertified(
      theme: theme,
      enrollment: enrollment,
      events: events,
    )) {
      continue;
    }
    result.add(CertifiedSkill(
      themeId: theme.themeId,
      title: theme.title,
      practiceCount: practiceCountForTheme(theme, events),
      completed: enrollment?.completedAt != null,
    ));
  }
  return result;
}

/// Còn bao nhiêu lần thực hành nữa thì chủ đề thành kỹ năng.
/// Trả về 0 khi đã đủ.
int practicesUntilSkill({
  required PracticeTheme theme,
  required List<CareerMemoryEvent> events,
}) {
  final remaining =
      kSkillPracticeThreshold - practiceCountForTheme(theme, events);
  return remaining < 0 ? 0 : remaining;
}

/// Những kỹ năng vừa đạt mà chưa từng được ghi nhận trong Career Memory.
/// Dùng để chỉ ghi dấu mốc đúng một lần.
List<CertifiedSkill> newlyCertified({
  required List<CertifiedSkill> certified,
  required List<CareerMemoryEvent> events,
}) {
  final announced = <String>{
    for (final e in events)
      if (e.behavior == kSkillCertifiedBehavior && e.reflectionText != null)
        e.reflectionText!,
  };
  return certified.where((s) => !announced.contains(s.title)).toList();
}
