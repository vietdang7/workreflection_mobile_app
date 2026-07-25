import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';

void main() {
  group('CheckinEnergy', () {
    test('dbValue round-trip good', () {
      expect(CheckinEnergy.fromDb(CheckinEnergy.good.dbValue), CheckinEnergy.good);
    });
    test('dbValue round-trip ok', () {
      expect(CheckinEnergy.fromDb(CheckinEnergy.ok.dbValue), CheckinEnergy.ok);
    });
    test('dbValue round-trip low', () {
      expect(CheckinEnergy.fromDb(CheckinEnergy.low.dbValue), CheckinEnergy.low);
    });
    test('fromDb throws on unknown', () {
      expect(() => CheckinEnergy.fromDb('unknown'), throwsArgumentError);
    });
  });

  group('CheckinDirection', () {
    test('dbValue round-trip forward', () {
      expect(CheckinDirection.fromDb(CheckinDirection.forward.dbValue), CheckinDirection.forward);
    });
    test('dbValue round-trip steady', () {
      expect(CheckinDirection.fromDb(CheckinDirection.steady.dbValue), CheckinDirection.steady);
    });
    test('dbValue round-trip backward', () {
      expect(CheckinDirection.fromDb(CheckinDirection.backward.dbValue), CheckinDirection.backward);
    });
    test('fromDb throws on unknown', () {
      expect(() => CheckinDirection.fromDb('xyz'), throwsArgumentError);
    });
  });

  group('Checkin.fromJson backward compat', () {
    test('parses old row without energy/direction (null)', () {
      final c = Checkin.fromJson({
        'id': 'c1',
        'user_id': 'u1',
        'mood': 'happy',
        'checkin_date': '2026-07-22',
        'created_at': '2026-07-22T07:00:00Z',
      });
      expect(c.mood, Mood.happy);
      expect(c.energy, isNull);
      expect(c.direction, isNull);
    });

    test('parses new row with energy + direction', () {
      final c = Checkin.fromJson({
        'id': 'c2',
        'user_id': 'u1',
        'mood': 'happy',
        'checkin_date': '2026-07-22',
        'created_at': '2026-07-22T07:00:00Z',
        'energy': 'good',
        'direction': 'forward',
      });
      expect(c.energy, CheckinEnergy.good);
      expect(c.direction, CheckinDirection.forward);
    });
  });

  group('energyToMood mapping', () {
    test('good → happy', () => expect(CheckinEnergy.good.toMood(), Mood.happy));
    test('ok → okay', () => expect(CheckinEnergy.ok.toMood(), Mood.okay));
    test('low → tired', () => expect(CheckinEnergy.low.toMood(), Mood.tired));
  });
}
