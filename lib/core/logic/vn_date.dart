// Shared Vietnam-timezone date helpers.
// Vietnam is UTC+7 and does not observe DST, so we add 7 hours to UTC.

/// Returns today's date in Vietnam time (Asia/Ho_Chi_Minh) as a date-only
/// [DateTime] (midnight local, no time component).
DateTime todayVn() => todayVnFrom(DateTime.now().toUtc());

/// Returns the Vietnam-local date for [utcNow] as a date-only [DateTime].
/// Exposed separately so tests can pass a fixed UTC instant.
DateTime todayVnFrom(DateTime utcNow) {
  final vn = utcNow.toUtc().add(const Duration(hours: 7));
  return DateTime(vn.year, vn.month, vn.day);
}
