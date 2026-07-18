// Pure scheduling logic — no Flutter/Supabase dependencies.
//
// Web reference: CoachingSchedule.tsx
//   - TIME_SLOTS = ["9:00","10:00","11:00","14:00","15:00","16:00"]
//   - calendarDays: dates from tomorrow onward (today is disabled).
//   - No DB availability table is queried; slots are static.

import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Constants mirroring web TIME_SLOTS
// ---------------------------------------------------------------------------

/// Fixed time slots, identical to web CoachingSchedule.tsx TIME_SLOTS.
const kTimeSlots = [
  '9:00',
  '10:00',
  '11:00',
  '14:00',
  '15:00',
  '16:00',
];

// ---------------------------------------------------------------------------
// Date helpers
// ---------------------------------------------------------------------------

/// Returns true if [date] is strictly after today (i.e., tomorrow or later).
/// Mirrors web logic: `date < tomorrow` is disabled.
bool isDateSelectable(DateTime date, DateTime today) {
  final todayMidnight = DateTime(today.year, today.month, today.day);
  final dateMidnight = DateTime(date.year, date.month, date.day);
  return dateMidnight.isAfter(todayMidnight);
}

/// Formats a [DateTime] to 'YYYY-MM-DD'.
String formatDateKey(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

/// Formats a [DateTime] to a display string like '01/08/2026'.
String formatDateDisplay(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}

/// Returns the name of the weekday in Vietnamese short form.
/// Monday=T2 ... Sunday=CN — mirrors web WEEKDAY_LABELS.
String weekdayLabelVI(int weekday) {
  // DateTime.weekday: 1=Mon, 7=Sun
  const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  return labels[weekday - 1];
}

// ---------------------------------------------------------------------------
// Calendar generation
// ---------------------------------------------------------------------------

/// A single calendar cell (may be null for empty leading cells).
class CalendarCell {
  const CalendarCell({
    required this.date,
    required this.dateKey,
    required this.isSelectable,
  });

  final DateTime date;
  final String dateKey; // 'YYYY-MM-DD'
  final bool isSelectable;
}

/// Generates the grid of calendar cells for the given [year]/[month].
/// Null entries represent empty cells before the 1st of the month (Mon-start).
/// [today] is used to determine which dates are selectable (tomorrow onward).
List<CalendarCell?> buildCalendarCells({
  required int year,
  required int month,
  required DateTime today,
}) {
  final firstDay = DateTime(year, month, 1);
  final lastDay = DateTime(year, month + 1, 0);

  // Monday=0 … Sunday=6 (mirrors web: firstDay.getDay()-1, clamped to ≥0)
  var startDow = firstDay.weekday - 1; // weekday: 1=Mon → 0
  if (startDow < 0) startDow = 6;

  final cells = <CalendarCell?>[];

  // Empty leading cells
  for (var i = 0; i < startDow; i++) {
    cells.add(null);
  }

  for (var d = 1; d <= lastDay.day; d++) {
    final date = DateTime(year, month, d);
    cells.add(CalendarCell(
      date: date,
      dateKey: formatDateKey(date),
      isSelectable: isDateSelectable(date, today),
    ));
  }

  return cells;
}

/// Returns whether we can go to the previous month.
/// We can only go back if that month is still >= tomorrow's month.
bool canGoPrevMonth(int year, int month, DateTime today) {
  final tomorrow = today.add(const Duration(days: 1));
  if (year > tomorrow.year) return true;
  if (year == tomorrow.year && month > tomorrow.month) return true;
  return false;
}

/// Returns the previous (year, month) pair.
(int, int) prevMonth(int year, int month) {
  if (month == 1) return (year - 1, 12);
  return (year, month - 1);
}

/// Returns the next (year, month) pair.
(int, int) nextMonth(int year, int month) {
  if (month == 12) return (year + 1, 1);
  return (year, month + 1);
}
