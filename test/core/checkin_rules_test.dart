import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/checkin_rules.dart';

void main() {
  // ---------------------------------------------------------------------------
  // parseCheckinCode
  // ---------------------------------------------------------------------------
  group('parseCheckinCode', () {
    test('bare uppercase code returns as-is uppercased', () {
      expect(parseCheckinCode('AB12CD34'), 'AB12CD34');
    });

    test('bare lowercase code returns uppercased', () {
      expect(parseCheckinCode('ab12cd34'), 'AB12CD34');
    });

    test('bare mixed-case code returns uppercased', () {
      expect(parseCheckinCode('Ab12cD34'), 'AB12CD34');
    });

    test('surrounding whitespace is trimmed', () {
      expect(parseCheckinCode('  AB12CD34  '), 'AB12CD34');
    });

    test('URL with code in last path segment', () {
      expect(
        parseCheckinCode('https://app.example.com/workshop/checkin/AB12CD34'),
        'AB12CD34',
      );
    });

    test('URL with trailing slash — last non-empty segment is code', () {
      expect(
        parseCheckinCode('https://app.example.com/workshop/checkin/AB12CD34/'),
        'AB12CD34',
      );
    });

    test('7-char code returns null', () {
      expect(parseCheckinCode('AB12CD3'), isNull);
    });

    test('9-char code returns null', () {
      expect(parseCheckinCode('AB12CD345'), isNull);
    });

    test('code with hyphen returns null', () {
      expect(parseCheckinCode('AB12-CD3'), isNull);
    });

    test('empty string returns null', () {
      expect(parseCheckinCode(''), isNull);
    });

    test('garbage string returns null', () {
      expect(parseCheckinCode('not-a-code!!'), isNull);
    });

    test('URL with 7-char last segment returns null', () {
      expect(
        parseCheckinCode('https://app.example.com/workshop/checkin/SHORT7X'),
        isNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // checkinWindow
  // ---------------------------------------------------------------------------
  group('checkinWindow', () {
    // startsAt = 2026-08-01 09:00 UTC
    final startsAt = DateTime.utc(2026, 8, 1, 9, 0, 0);

    test('exactly at startsAt − 2h is open (inclusive lower bound)', () {
      final now = DateTime.utc(2026, 8, 1, 7, 0, 0); // −2h exactly
      expect(checkinWindow(startsAt, now), CheckinWindow.open);
    });

    test('just before startsAt − 2h is tooEarly', () {
      final now = DateTime.utc(2026, 8, 1, 6, 59, 59); // 1s before lower bound
      expect(checkinWindow(startsAt, now), CheckinWindow.tooEarly);
    });

    test('inside window is open', () {
      final now = DateTime.utc(2026, 8, 1, 10, 0, 0); // +1h after start
      expect(checkinWindow(startsAt, now), CheckinWindow.open);
    });

    test('exactly at startsAt + 4h is open (inclusive upper bound)', () {
      final now = DateTime.utc(2026, 8, 1, 13, 0, 0); // +4h exactly
      expect(checkinWindow(startsAt, now), CheckinWindow.open);
    });

    test('just after startsAt + 4h is closed', () {
      final now = DateTime.utc(2026, 8, 1, 13, 0, 1); // 1s after upper bound
      expect(checkinWindow(startsAt, now), CheckinWindow.closed);
    });

    test('null startsAt returns unknown', () {
      final now = DateTime.utc(2026, 8, 1, 9, 0, 0);
      expect(checkinWindow(null, now), CheckinWindow.unknown);
    });
  });
}
