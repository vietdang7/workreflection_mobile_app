import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/checkin_history.dart';

void main() {
  group('buildCheckinHistory', () {
    final today = DateTime(2026, 7, 18); // Saturday

    test('returns exactly 30 elements', () {
      final result = buildCheckinHistory(checkinDates: [], today: today);
      expect(result.length, 30);
    });

    test('empty dates → all false', () {
      final result = buildCheckinHistory(checkinDates: [], today: today);
      expect(result.every((v) => !v), isTrue);
    });

    test('today checked in → last element true', () {
      final result = buildCheckinHistory(
        checkinDates: [today],
        today: today,
      );
      expect(result.last, isTrue);
      // All others should be false
      for (int i = 0; i < 29; i++) {
        expect(result[i], isFalse);
      }
    });

    test('yesterday checked in → index 28 true', () {
      final yesterday = today.subtract(const Duration(days: 1));
      final result = buildCheckinHistory(
        checkinDates: [yesterday],
        today: today,
      );
      expect(result[28], isTrue);
      expect(result[29], isFalse);
    });

    test('29 days ago checked in → index 0 true', () {
      final oldest = today.subtract(const Duration(days: 29));
      final result = buildCheckinHistory(
        checkinDates: [oldest],
        today: today,
      );
      expect(result[0], isTrue);
      for (int i = 1; i < 30; i++) {
        expect(result[i], isFalse);
      }
    });

    test('date 30 days ago (outside window) → all false', () {
      final outside = today.subtract(const Duration(days: 30));
      final result = buildCheckinHistory(
        checkinDates: [outside],
        today: today,
      );
      expect(result.every((v) => !v), isTrue);
    });

    test('date far in the future (outside window) → all false', () {
      final future = today.add(const Duration(days: 10));
      final result = buildCheckinHistory(
        checkinDates: [future],
        today: today,
      );
      expect(result.every((v) => !v), isTrue);
    });

    test('duplicates on same day count as single checkin', () {
      // Three entries all on today
      final result = buildCheckinHistory(
        checkinDates: [today, today, today],
        today: today,
      );
      expect(result.last, isTrue);
      expect(result.where((v) => v).length, 1);
    });

    test('multiple distinct days within window', () {
      final d1 = today.subtract(const Duration(days: 5));
      final d2 = today.subtract(const Duration(days: 2));
      final result = buildCheckinHistory(
        checkinDates: [d1, d2, today],
        today: today,
      );
      // index 24 = today-5, index 27 = today-2, index 29 = today
      expect(result[24], isTrue);
      expect(result[27], isTrue);
      expect(result[29], isTrue);
      expect(result.where((v) => v).length, 3);
    });

    test('dates with non-midnight time are still matched by calendar day', () {
      // today with a specific time component
      final todayWithTime = DateTime(2026, 7, 18, 23, 59, 59);
      final result = buildCheckinHistory(
        checkinDates: [todayWithTime],
        today: today,
      );
      expect(result.last, isTrue);
    });

    test('index ordering: index 0 is oldest, index 29 is today', () {
      // Seed every day from today-4 to today
      final dates = List.generate(
        5,
        (i) => today.subtract(Duration(days: 4 - i)),
      );
      final result = buildCheckinHistory(checkinDates: dates, today: today);
      // Indices 0–24 are outside the seeded range → false
      for (int i = 0; i < 25; i++) {
        expect(result[i], isFalse, reason: 'index $i should be false');
      }
      // Indices 25–29 are seeded → true
      for (int i = 25; i < 30; i++) {
        expect(result[i], isTrue, reason: 'index $i should be true');
      }
    });
  });
}
