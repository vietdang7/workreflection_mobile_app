// Unit tests for coaching_schedule_logic.dart (pure, no Flutter deps).

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/coaching_schedule_logic.dart';

void main() {
  // ---------------------------------------------------------------------------
  // isDateSelectable
  // ---------------------------------------------------------------------------

  group('isDateSelectable', () {
    final today = DateTime(2026, 8, 1);

    test('today is NOT selectable', () {
      expect(isDateSelectable(DateTime(2026, 8, 1), today), isFalse);
    });

    test('yesterday is NOT selectable', () {
      expect(isDateSelectable(DateTime(2026, 7, 31), today), isFalse);
    });

    test('tomorrow IS selectable', () {
      expect(isDateSelectable(DateTime(2026, 8, 2), today), isTrue);
    });

    test('future date IS selectable', () {
      expect(isDateSelectable(DateTime(2026, 9, 15), today), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // buildCalendarCells
  // ---------------------------------------------------------------------------

  group('buildCalendarCells', () {
    // August 2026: 31 days, starts on Saturday (weekday=6 → index=5 leading nulls)
    test('August 2026 has correct total cells', () {
      final cells = buildCalendarCells(
        year: 2026,
        month: 8,
        today: DateTime(2026, 8, 1),
      );
      // 5 leading nulls + 31 days = 36 cells
      expect(cells.length, 36);
      expect(cells.where((c) => c == null).length, 5);
      expect(cells.where((c) => c != null).length, 31);
    });

    test('past dates in month are not selectable', () {
      final today = DateTime(2026, 8, 15);
      final cells = buildCalendarCells(
        year: 2026,
        month: 8,
        today: today,
      );
      final nonNull = cells.whereType<CalendarCell>().toList();
      // Dates up to the 15th should not be selectable
      final day1 = nonNull.firstWhere((c) => c.date.day == 1);
      expect(day1.isSelectable, isFalse);
      final day15 = nonNull.firstWhere((c) => c.date.day == 15);
      expect(day15.isSelectable, isFalse);
      // Day 16 should be selectable
      final day16 = nonNull.firstWhere((c) => c.date.day == 16);
      expect(day16.isSelectable, isTrue);
    });

    test('all days have correct dateKey format', () {
      final cells = buildCalendarCells(
        year: 2026,
        month: 8,
        today: DateTime(2026, 8, 1),
      );
      final day5 = cells
          .whereType<CalendarCell>()
          .firstWhere((c) => c.date.day == 5);
      expect(day5.dateKey, '2026-08-05');
    });

    test('January has no leading nulls (starts Monday)', () {
      // Jan 2024 starts on Monday (weekday=1 → 0 leading nulls)
      final cells = buildCalendarCells(
        year: 2024,
        month: 1,
        today: DateTime(2024, 1, 1),
      );
      expect(cells.first, isNotNull);
      expect(cells.where((c) => c == null).length, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // canGoPrevMonth
  // ---------------------------------------------------------------------------

  group('canGoPrevMonth', () {
    final today = DateTime(2026, 8, 10);

    test('same year/month as tomorrow → cannot go prev', () {
      // tomorrow is Aug 11 → Aug 2026 is the earliest month
      expect(canGoPrevMonth(2026, 8, today), isFalse);
    });

    test('one month ahead → can go prev', () {
      expect(canGoPrevMonth(2026, 9, today), isTrue);
    });

    test('next year → can go prev', () {
      expect(canGoPrevMonth(2027, 1, today), isTrue);
    });

    test('past month → cannot go prev (treated as blocked)', () {
      expect(canGoPrevMonth(2026, 7, today), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // prevMonth / nextMonth
  // ---------------------------------------------------------------------------

  group('prevMonth', () {
    test('Feb → Jan same year', () {
      expect(prevMonth(2026, 2), (2026, 1));
    });

    test('Jan wraps to Dec prev year', () {
      expect(prevMonth(2026, 1), (2025, 12));
    });
  });

  group('nextMonth', () {
    test('Aug → Sep same year', () {
      expect(nextMonth(2026, 8), (2026, 9));
    });

    test('Dec wraps to Jan next year', () {
      expect(nextMonth(2026, 12), (2027, 1));
    });
  });

  // ---------------------------------------------------------------------------
  // kTimeSlots
  // ---------------------------------------------------------------------------

  test('kTimeSlots matches web TIME_SLOTS exactly', () {
    expect(kTimeSlots, ['9:00', '10:00', '11:00', '14:00', '15:00', '16:00']);
  });

  // ---------------------------------------------------------------------------
  // formatDateKey / formatDateDisplay
  // ---------------------------------------------------------------------------

  test('formatDateKey produces YYYY-MM-DD', () {
    expect(formatDateKey(DateTime(2026, 8, 5)), '2026-08-05');
  });

  test('formatDateDisplay produces dd/MM/yyyy', () {
    expect(formatDateDisplay(DateTime(2026, 8, 5)), '05/08/2026');
  });
}
