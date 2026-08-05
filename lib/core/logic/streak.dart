import '../models/wr_episode.dart';

/// Số NGÀY người dùng đã nhìn lại — thay cho chuỗi ngày liên tiếp ở màn Hồ sơ
/// (yêu cầu 05/08).
///
/// Vì sao đổi: chuỗi liên tiếp là một con số biết tụt. Nghỉ đúng một ngày là nó
/// về 0, và cái người dùng nhìn thấy ở màn Hồ sơ của chính mình là "bạn vừa mất
/// hết" — trong khi mọi lần nhìn lại họ đã làm vẫn còn nguyên đó. Đếm tổng số
/// ngày thì con số chỉ đi lên, đúng với bản chất của việc tích luỹ.
///
/// Chỉ đếm Episode đã KHÉP (`closedAt`), tức là đã đi hết luồng và có một mảnh
/// ký ức thật. Mở luồng rồi bỏ dở giữa chừng không phải một ngày đã nhìn lại.
/// Nhiều lần trong cùng một ngày vẫn tính là một ngày.
int reflectionDayCount(List<ReflectionEpisode> episodes) {
  final days = <DateTime>{};
  for (final e in episodes) {
    final at = e.closedAt;
    if (at == null) continue;
    days.add(DateTime(at.year, at.month, at.day));
  }
  return days.length;
}

/// Computes the current streak given a list of check-in dates and today's date.
///
/// Rules:
/// - A streak is a run of consecutive calendar days ending on [today] or
///   [today - 1 day] (the streak survives until a full calendar day is missed).
/// - Duplicate dates and time components are ignored — only the calendar date
///   (year/month/day) matters.
/// - Unordered input is accepted.
/// - Empty input returns 0.
int computeStreak(List<DateTime> checkinDates, DateTime today) {
  if (checkinDates.isEmpty) return 0;

  // Strip time components and deduplicate by converting to a Set of date-only
  // DateTimes (midnight UTC — consistent since we only care about Y/M/D).
  final uniqueDays = checkinDates
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet();

  final todayOnly = DateTime(today.year, today.month, today.day);
  final yesterdayOnly = todayOnly.subtract(const Duration(days: 1));

  // The streak must include today or yesterday; otherwise it's broken.
  if (!uniqueDays.contains(todayOnly) && !uniqueDays.contains(yesterdayOnly)) {
    return 0;
  }

  // Walk backwards from the latest anchor (today if present, else yesterday).
  DateTime cursor =
      uniqueDays.contains(todayOnly) ? todayOnly : yesterdayOnly;

  int streak = 0;
  while (uniqueDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return streak;
}
