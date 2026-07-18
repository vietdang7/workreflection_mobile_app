// Tests for FakeCoachingRepository — verifies the behavior contract that all
// widget tests and unit tests depend on.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/coaching_models.dart';

import '../support/fake_coaching_repository.dart';

CoachingPackage _freePackage({
  String id = 'pkg-free',
  int sessionsCount = 3,
}) {
  return CoachingPackage(
    id: id,
    name: 'Free Package',
    price: 0,
    currency: 'VND',
    sessionsCount: sessionsCount,
    features: const [],
    isActive: true,
    displayOrder: 0,
  );
}

CoachingPackage _paidPackage({String id = 'pkg-paid'}) {
  return CoachingPackage(
    id: id,
    name: 'Paid Package',
    price: 500000,
    currency: 'VND',
    sessionsCount: 5,
    features: const [],
    isActive: true,
    displayOrder: 1,
  );
}

Coach _coach({String id = 'coach-1'}) {
  return Coach(
    id: id,
    fullName: 'Test Coach',
    specializations: const [],
    isActive: true,
    displayOrder: 0,
  );
}

CoachingBooking _booking({
  String id = 'booking-1',
  DateTime? scheduledAt,
}) {
  return CoachingBooking(
    id: id,
    packageId: 'pkg-1',
    status: 'pending',
    scheduledAt: scheduledAt,
  );
}

void main() {
  late FakeCoachingRepository repo;

  setUp(() {
    repo = FakeCoachingRepository();
  });

  // --- getPackages ---

  test('getPackages returns seeded packages', () async {
    repo.seedPackages([_freePackage(), _paidPackage()]);
    final result = await repo.getPackages();
    expect(result.length, 2);
    expect(result.map((p) => p.id), containsAll(['pkg-free', 'pkg-paid']));
  });

  // --- getCoaches ---

  test('getCoaches returns seeded coaches', () async {
    repo.seedCoaches([_coach(id: 'c1'), _coach(id: 'c2')]);
    final result = await repo.getCoaches();
    expect(result.map((c) => c.id), containsAll(['c1', 'c2']));
  });

  // --- claimFreePackage ---

  test('claimFreePackage records the call', () async {
    final pkg = _freePackage(sessionsCount: 2);

    await repo.claimFreePackage(pkg);

    expect(repo.claimFreePackageCalls, [pkg]);
  });

  test('claimFreePackage creates sessionsCount pending bookings', () async {
    final pkg = _freePackage(sessionsCount: 3);

    await repo.claimFreePackage(pkg);

    final bookings = await repo.getMyBookings();
    expect(bookings.length, 3);
    expect(bookings.every((b) => b.status == 'pending'), isTrue);
    expect(bookings.every((b) => b.packageId == pkg.id), isTrue);
  });

  test('claimFreePackage assigns session numbers 1..N', () async {
    final pkg = _freePackage(sessionsCount: 3);

    await repo.claimFreePackage(pkg);

    final bookings = await repo.getMyBookings();
    final sessionNumbers = bookings.map((b) => b.sessionNumber).toSet();
    expect(sessionNumbers, containsAll([1, 2, 3]));
  });

  test('claimFreePackage throws StateError for paid package', () async {
    final pkg = _paidPackage();

    expect(
      () => repo.claimFreePackage(pkg),
      throwsA(isA<StateError>()),
    );
    expect(repo.claimFreePackageCalls, isEmpty);
  });

  // --- getMyBookings ordering ---

  test('getMyBookings returns scheduled bookings before null ones', () async {
    repo.seedBookings([
      _booking(id: 'b-null'),
      _booking(id: 'b-early', scheduledAt: DateTime(2026, 1, 1)),
      _booking(id: 'b-late', scheduledAt: DateTime(2026, 12, 1)),
    ]);

    final bookings = await repo.getMyBookings();

    expect(bookings.last.id, 'b-null');
    expect(bookings.first.id, 'b-late');
  });

  // --- nextError ---

  test('nextError throws once then clears', () async {
    repo.nextError = Exception('forced error');

    expect(() => repo.getPackages(), throwsException);
    expect(() => repo.getPackages(), returnsNormally);
  });

  test('nextError is cleared after throw so subsequent calls succeed', () async {
    repo.seedPackages([_freePackage()]);
    repo.nextError = Exception('one-shot');

    // First call blows up.
    Object? caught;
    try {
      await repo.getPackages();
    } catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);

    // Second call returns normally.
    final result = await repo.getPackages();
    expect(result.length, 1);
  });
}
