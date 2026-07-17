import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/streak.dart';

void main() {
  group('computeStreak', () {
    test('empty list returns 0', () {
      expect(computeStreak([], DateTime(2026, 7, 17)), 0);
    });

    test('only today returns 1', () {
      expect(computeStreak([DateTime(2026, 7, 17)], DateTime(2026, 7, 17)), 1);
    });

    test('today and yesterday returns 2', () {
      expect(
        computeStreak(
          [DateTime(2026, 7, 17), DateTime(2026, 7, 16)],
          DateTime(2026, 7, 17),
        ),
        2,
      );
    });

    test('gap in middle breaks the streak', () {
      // today=17, have 17 and 15 (skipped 16) — streak is 1 (only today)
      expect(
        computeStreak(
          [DateTime(2026, 7, 17), DateTime(2026, 7, 15)],
          DateTime(2026, 7, 17),
        ),
        1,
      );
    });

    test('streak ending yesterday counts (streak not broken until a full day missed)', () {
      // have 16 and 15, today is 17 (no check-in yet today) — streak = 2
      expect(
        computeStreak(
          [DateTime(2026, 7, 16), DateTime(2026, 7, 15)],
          DateTime(2026, 7, 17),
        ),
        2,
      );
    });

    test('streak starting from yesterday breaks if day before yesterday missing', () {
      // only yesterday = 1
      expect(
        computeStreak(
          [DateTime(2026, 7, 16)],
          DateTime(2026, 7, 17),
        ),
        1,
      );
    });

    test('unordered input produces correct streak', () {
      // Provide 5 consecutive days in random order
      expect(
        computeStreak(
          [
            DateTime(2026, 7, 13),
            DateTime(2026, 7, 17),
            DateTime(2026, 7, 15),
            DateTime(2026, 7, 14),
            DateTime(2026, 7, 16),
          ],
          DateTime(2026, 7, 17),
        ),
        5,
      );
    });

    test('duplicates are ignored', () {
      expect(
        computeStreak(
          [
            DateTime(2026, 7, 17),
            DateTime(2026, 7, 17, 12, 30), // duplicate with time
            DateTime(2026, 7, 16),
            DateTime(2026, 7, 16, 8, 0), // another duplicate
          ],
          DateTime(2026, 7, 17),
        ),
        2,
      );
    });

    test('date far in the past does not contribute when streak is broken', () {
      // Only old dates that are not continuous from today/yesterday
      expect(
        computeStreak(
          [DateTime(2026, 7, 1), DateTime(2026, 7, 2)],
          DateTime(2026, 7, 17),
        ),
        0,
      );
    });

    test('long consecutive run computes correctly', () {
      final dates = List.generate(
        30,
        (i) => DateTime(2026, 7, 17).subtract(Duration(days: i)),
      );
      expect(computeStreak(dates, DateTime(2026, 7, 17)), 30);
    });

    test('time components within a day are ignored (checkins with different times on same day)', () {
      // Same calendar day, different times — counts as 1 day
      expect(
        computeStreak(
          [
            DateTime(2026, 7, 17, 9, 0),
            DateTime(2026, 7, 17, 21, 0),
            DateTime(2026, 7, 16, 8, 0),
          ],
          DateTime(2026, 7, 17, 15, 0),
        ),
        2,
      );
    });
  });
}
