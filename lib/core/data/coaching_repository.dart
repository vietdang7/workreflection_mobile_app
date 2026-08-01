// Coaching repository — Phase 3.
// Abstract interface + SupabaseCoachingRepository + provider.
// Supabase queries live ONLY here. Screens consume via coachingRepositoryProvider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coaching_models.dart';

// Static time slots mirroring the web (CoachingSchedule.tsx TIME_SLOTS).
const kCoachingTimeSlots = [
  '9:00',
  '10:00',
  '11:00',
  '14:00',
  '15:00',
  '16:00',
];

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class CoachingRepository {
  /// Returns all active coaching packages ordered by display_order asc.
  Future<List<CoachingPackage>> getPackages();

  /// Returns all active coaches ordered by display_order asc.
  Future<List<Coach>> getCoaches();

  /// Returns all coaching bookings for the current user, ordered by
  /// scheduled_at desc (nulls last).
  Future<List<CoachingBooking>> getMyBookings();

  /// Claims a free coaching package for the current user.
  ///
  /// Flow:
  ///   1. INSERT cc_orders {order_code:'TEMP', user_id, product_type:'coaching',
  ///      product_id, original_amount:0, final_amount:0, currency,
  ///      status:'pending'}
  ///      → get order id
  ///   2. UPDATE cc_orders SET order_code = 'CC<8 hex chars>'
  ///   3. RPC complete_payment(p_order_id) — SECURITY DEFINER, creates N
  ///      cc_coaching_bookings rows (one per session).
  ///
  /// Throws [StateError] if [pkg.isFree] is false.
  Future<void> claimFreePackage(CoachingPackage pkg);

  /// Schedules a booking: sets scheduled_date, scheduled_time, scheduled_at,
  /// status='scheduled', and optional notes.
  ///
  /// Mirrors the web write path exactly (CoachingSchedule.tsx scheduleMutation):
  ///   UPDATE cc_coaching_bookings SET
  ///     scheduled_date = date,
  ///     scheduled_time = time + ':00',
  ///     scheduled_at   = date + 'T' + time + ':00',
  ///     status         = 'scheduled',
  ///     notes          = notes (nullable)
  ///   WHERE id = bookingId
  ///
  /// DEVIATION vs web: the web performs no taken-slot race check. This
  /// implementation also omits one since Supabase row-level-security and the
  /// absence of a cc_coach_availability table means the slot model is purely
  /// calendar-based (date + fixed TIME_SLOTS). A duplicate booking for the same
  /// slot is an admin concern, not enforced client-side on either platform.
  Future<void> scheduleBooking({
    required String bookingId,
    required String date,   // 'YYYY-MM-DD'
    required String time,   // 'H:mm' e.g. '9:00'
    String? notes,
  });

  /// Returns aggregated coach reviews (cc_coaching_reviews + cc_reviews where
  /// review_type='coaching') with avg rating and up to 6 recent reviews.
  Future<CoachReviewSummary> getCoachReviews();
}

// ---------------------------------------------------------------------------
// Riverpod provider (overridable in tests)
// ---------------------------------------------------------------------------

final coachingRepositoryProvider = Provider<CoachingRepository>((ref) {
  return SupabaseCoachingRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Live Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseCoachingRepository implements CoachingRepository {
  const SupabaseCoachingRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  // ---------------------------------------------------------------------------
  // Packages
  // ---------------------------------------------------------------------------

  @override
  Future<List<CoachingPackage>> getPackages() async {
    final rows = await _client
        .from('cc_coaching_packages')
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true);
    return rows.map(CoachingPackage.fromJson).toList();
  }

  // ---------------------------------------------------------------------------
  // Coaches
  // ---------------------------------------------------------------------------

  @override
  Future<List<Coach>> getCoaches() async {
    final rows = await _client
        .from('cc_coaches')
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true);
    return rows.map(Coach.fromJson).toList();
  }

  // ---------------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------------

  @override
  Future<List<CoachingBooking>> getMyBookings() async {
    final uid = _uid;
    // cc_coaching_bookings.user_id is TEXT; uid is a UUID string — works as-is.
    // Always filter by user_id (cc_orders_select analogue: read-all policy exists
    // on some tables, so never omit this filter).
    final rows = await _client
        .from('cc_coaching_bookings')
        .select()
        .eq('user_id', uid)
        .order('scheduled_at', ascending: false, nullsFirst: false);
    return rows.map(CoachingBooking.fromJson).toList();
  }

  // ---------------------------------------------------------------------------
  // Schedule booking
  // ---------------------------------------------------------------------------

  @override
  Future<void> scheduleBooking({
    required String bookingId,
    required String date,
    required String time,
    String? notes,
  }) async {
    // Exact mirror of web scheduleMutation (CoachingSchedule.tsx lines 127-142):
    //   scheduled_at = '${date}T${time}:00'
    //   scheduled_time = time + ':00'
    //   scheduled_date = date
    //   status = 'scheduled'
    //   notes = trimmed or null
    final scheduledAt = '${date}T$time:00';
    final scheduledTime = '$time:00';

    final response = await _client.from('cc_coaching_bookings').update({
      'scheduled_date': date,
      'scheduled_time': scheduledTime,
      'scheduled_at': scheduledAt,
      'status': 'scheduled',
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
    }).eq('id', bookingId).select('id');

    // Defensive re-check: if no row was updated the booking no longer exists
    // (or the user doesn't own it). The web does not check this — this is a
    // DEVIATION that adds safety without altering the write path.
    if (response.isEmpty) {
      throw StateError('scheduleBooking: booking $bookingId not found or already scheduled');
    }
  }

  // ---------------------------------------------------------------------------
  // Coach reviews
  // ---------------------------------------------------------------------------

  @override
  Future<CoachReviewSummary> getCoachReviews() async {
    // 1. Admin-curated reviews (cc_reviews where review_type='coaching')
    //    mirrors Coaching.tsx query for `reviews`.
    final adminRows = await _client
        .from('cc_reviews')
        .select('rating, review_text, reviewer_name')
        .eq('is_active', true)
        .eq('review_type', 'coaching')
        .order('display_order', ascending: true);

    // 2. User-submitted reviews (cc_coaching_reviews) — most recent 20,
    //    then join cc_profiles for names.
    //    Mirrors Coaching.tsx query for `userReviews`.
    final userRows = await _client
        .from('cc_coaching_reviews')
        .select('rating, comment, created_at, user_id')
        .order('created_at', ascending: false)
        .limit(20);

    List<CoachReview> allReviews = [];
    final allRatings = <num>[];

    // Admin reviews
    for (final r in adminRows) {
      final rating = (r['rating'] as num?) ?? 5;
      allRatings.add(rating);
      final text = r['review_text'] as String?;
      if (text != null && text.isNotEmpty) {
        allReviews.add(CoachReview(
          rating: rating,
          reviewerName: (r['reviewer_name'] as String?) ?? 'Khách hàng',
          comment: text,
        ));
      }
    }

    // User reviews — fetch profile names if needed
    if (userRows.isNotEmpty) {
      final userIds =
          userRows.map((r) => r['user_id'] as String).toSet().toList();
      final profileRows = await _client
          .from('cc_profiles')
          .select('id, full_name')
          .inFilter('id', userIds);
      final nameMap = <String, String>{
        for (final p in profileRows)
          p['id'] as String: (p['full_name'] as String?) ?? 'Khách hàng',
      };
      for (final r in userRows) {
        final rating = (r['rating'] as num?) ?? 5;
        allRatings.add(rating);
        final comment = r['comment'] as String?;
        if (comment != null && comment.isNotEmpty) {
          allReviews.add(CoachReview(
            rating: rating,
            reviewerName: nameMap[r['user_id'] as String] ?? 'Khách hàng',
            comment: comment,
          ));
        }
      }
    }

    final avgRating = allRatings.isEmpty
        ? 5.0
        : allRatings.reduce((a, b) => a + b) / allRatings.length;

    return CoachReviewSummary(
      avgRating: avgRating.toDouble(),
      totalCount: allRatings.length,
      reviews: allReviews.take(6).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Claim free package
  // ---------------------------------------------------------------------------

  @override
  Future<void> claimFreePackage(CoachingPackage pkg) async {
    if (!pkg.isFree) {
      throw StateError('claimFreePackage called on non-free package ${pkg.id}');
    }

    final uid = _uid;

    // Step 1: Insert the order with a temporary order_code.
    final orderRow = await _client.from('cc_orders').insert({
      'order_code': 'TEMP',
      'user_id': uid, // TEXT column — uid string works as-is
      'product_type': 'coaching',
      'product_id': pkg.id,
      'original_amount': 0,
      'final_amount': 0,
      'currency': pkg.currency,
      // Phải là 'pending'. RLS cc_orders_insert không cho client tự khai một
      // đơn là 'paid' — chỉ complete_payment (SECURITY DEFINER) mới được đặt
      // trạng thái đó, ở Step 3 ngay bên dưới.
      'status': 'pending',
    }).select('id').single();

    final orderId = orderRow['id'] as String;

    // Step 2: Generate a unique order_code and update the row.
    // Format matches web generateOrderCode (src/lib/order-utils.ts):
    // 'CNC' + first 8 hex chars of orderId uppercased (dashes stripped).
    final orderCode =
        'CNC${orderId.replaceAll('-', '').substring(0, 8).toUpperCase()}';
    await _client
        .from('cc_orders')
        .update({'order_code': orderCode}).eq('id', orderId);

    // Step 3: Call the SECURITY DEFINER RPC which creates N cc_coaching_bookings
    // rows (one per session_number). Mobile must NOT insert bookings directly.
    await _client.rpc('complete_payment', params: {'p_order_id': orderId});
  }
}
