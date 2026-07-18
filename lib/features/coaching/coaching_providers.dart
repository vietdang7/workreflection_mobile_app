// Riverpod providers for the coaching feature — Phase 3.
//
// All providers are autoDispose so resources are freed when the screen is
// popped.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/coaching_repository.dart';
import '../../core/models/coaching_models.dart';

// ---------------------------------------------------------------------------
// Task 14 — Coaching packages screen
// ---------------------------------------------------------------------------

/// All active coaching packages, ordered by display_order asc.
final coachingPackagesProvider =
    FutureProvider.autoDispose<List<CoachingPackage>>((ref) {
  final repo = ref.watch(coachingRepositoryProvider);
  return repo.getPackages();
});

/// All active coaches, ordered by display_order asc.
final coachesProvider = FutureProvider.autoDispose<List<Coach>>((ref) {
  final repo = ref.watch(coachingRepositoryProvider);
  return repo.getCoaches();
});

// ---------------------------------------------------------------------------
// Task 15 — My coaching sessions screen
// ---------------------------------------------------------------------------

/// All coaching bookings for the current user.
final myBookingsProvider =
    FutureProvider.autoDispose<List<CoachingBooking>>((ref) {
  final repo = ref.watch(coachingRepositoryProvider);
  return repo.getMyBookings();
});

// ---------------------------------------------------------------------------
// Task 6 (Phase 5) — Coach reviews
// ---------------------------------------------------------------------------

/// Aggregated coach reviews (admin + user) with avg rating.
final coachReviewsProvider =
    FutureProvider.autoDispose<CoachReviewSummary>((ref) {
  final repo = ref.watch(coachingRepositoryProvider);
  return repo.getCoachReviews();
});
