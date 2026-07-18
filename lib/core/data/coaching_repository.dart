// Coaching repository — Phase 3.
// Abstract interface + SupabaseCoachingRepository + provider.
// Supabase queries live ONLY here. Screens consume via coachingRepositoryProvider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coaching_models.dart';

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
  ///      product_id, original_amount:0, final_amount:0, currency, status:'paid'}
  ///      → get order id
  ///   2. UPDATE cc_orders SET order_code = 'CC<8 hex chars>'
  ///   3. RPC complete_payment(p_order_id) — SECURITY DEFINER, creates N
  ///      cc_coaching_bookings rows (one per session).
  ///
  /// Throws [StateError] if [pkg.isFree] is false.
  Future<void> claimFreePackage(CoachingPackage pkg);
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
      'status': 'paid',
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
