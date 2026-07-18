// Checkin history — pure logic, no Flutter/Supabase dependencies.
//
// Used by ProfileScreen to render a 30-day dot strip.

/// Returns a 30-element list of booleans representing the last 30 calendar
/// days ending on [today] (inclusive).
///
/// Index 0 = oldest day (today − 29), index 29 = [today].
///
/// Each entry is `true` when the user checked in on that calendar day, or
/// `false` otherwise.
///
/// [checkinDates] may contain duplicates and dates outside the 30-day window;
/// both are silently ignored.
List<bool> buildCheckinHistory({
  required List<DateTime> checkinDates,
  required DateTime today,
}) {
  // Normalise today to midnight so comparisons are date-only.
  final todayDate = DateTime(today.year, today.month, today.day);

  // Build a set of day-keys (year*10000 + month*100 + day) for O(1) lookup.
  final checkedIn = <int>{};
  for (final d in checkinDates) {
    checkedIn.add(_dayKey(d));
  }

  return List<bool>.generate(30, (i) {
    final day = todayDate.subtract(Duration(days: 29 - i));
    return checkedIn.contains(_dayKey(day));
  });
}

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
