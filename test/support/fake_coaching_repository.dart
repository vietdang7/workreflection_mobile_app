import 'package:workreflection_mobile/core/data/coaching_repository.dart';
import 'package:workreflection_mobile/core/models/coaching_models.dart';

/// In-memory fake CoachingRepository for widget/unit tests.
///
/// Pre-populate via the `seed*` methods before pumping widgets.
/// Inspect recorded calls via the `*Calls` fields.
///
/// Set [nextError] before a call to simulate an error; it is thrown once then
/// cleared automatically.
class FakeCoachingRepository implements CoachingRepository {
  // --- Internal state ---
  final List<CoachingPackage> _packages = [];
  final List<Coach> _coaches = [];
  final List<CoachingBooking> _bookings = [];
  int _bookingCounter = 0;

  /// When set, the next repo call throws this error once, then clears it.
  Object? nextError;

  // --- Call recorders ---
  final List<CoachingPackage> claimFreePackageCalls = [];

  // --- Seed helpers ---

  void seedPackages(List<CoachingPackage> packages) {
    _packages
      ..clear()
      ..addAll(packages);
  }

  void seedCoaches(List<Coach> coaches) {
    _coaches
      ..clear()
      ..addAll(coaches);
  }

  void seedBookings(List<CoachingBooking> bookings) {
    _bookings
      ..clear()
      ..addAll(bookings);
  }

  // --- Helpers ---

  void _maybeThrow() {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      // ignore: only_throw_errors
      throw err;
    }
  }

  // --- CoachingRepository impl ---

  @override
  Future<List<CoachingPackage>> getPackages() async {
    _maybeThrow();
    return List.unmodifiable(_packages);
  }

  @override
  Future<List<Coach>> getCoaches() async {
    _maybeThrow();
    return List.unmodifiable(_coaches);
  }

  @override
  Future<List<CoachingBooking>> getMyBookings() async {
    _maybeThrow();
    // Return a copy sorted by scheduled_at desc, nulls last — matching Supabase
    // query behaviour.
    final sorted = List.of(_bookings)
      ..sort((a, b) {
        if (a.scheduledAt == null && b.scheduledAt == null) return 0;
        if (a.scheduledAt == null) return 1; // null goes last
        if (b.scheduledAt == null) return -1;
        return b.scheduledAt!.compareTo(a.scheduledAt!);
      });
    return List.unmodifiable(sorted);
  }

  @override
  Future<void> claimFreePackage(CoachingPackage pkg) async {
    _maybeThrow();
    if (!pkg.isFree) {
      throw StateError('claimFreePackage called on non-free package ${pkg.id}');
    }
    claimFreePackageCalls.add(pkg);

    // Simulate the RPC: append pkg.sessionsCount pending bookings.
    for (var i = 1; i <= pkg.sessionsCount; i++) {
      _bookingCounter++;
      _bookings.add(CoachingBooking(
        id: 'booking-$_bookingCounter',
        packageId: pkg.id,
        status: 'pending',
        sessionNumber: i,
        totalSessions: pkg.sessionsCount,
      ));
    }
  }
}
