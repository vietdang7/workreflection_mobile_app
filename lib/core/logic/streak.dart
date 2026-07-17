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
