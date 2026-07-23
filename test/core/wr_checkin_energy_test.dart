import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import '../support/fake_repository.dart';

void main() {
  group('FakeWrRepository — energy/direction upsert', () {
    late FakeWrRepository repo;
    setUp(() => repo = FakeWrRepository());

    test('upsertCheckin with energy+direction stores energy on checkin', () async {
      await repo.upsertCheckin(
        Mood.happy,
        energy: CheckinEnergy.good,
        direction: CheckinDirection.forward,
      );
      final c = await repo.getTodayCheckin();
      expect(c!.energy, CheckinEnergy.good);
      expect(c.direction, CheckinDirection.forward);
    });

    test('upsertCheckin without energy preserves backward compat', () async {
      await repo.upsertCheckin(Mood.okay);
      final c = await repo.getTodayCheckin();
      expect(c!.mood, Mood.okay);
      expect(c.energy, isNull);
    });

    test('upsertCheckin records energy in call log', () async {
      await repo.upsertCheckin(Mood.tired, energy: CheckinEnergy.low);
      expect(repo.upsertCheckinCalls.single.mood, Mood.tired);
      expect(repo.upsertCheckinCalls.single.energy, CheckinEnergy.low);
      expect(repo.upsertCheckinCalls.single.direction, isNull);
    });
  });
}
