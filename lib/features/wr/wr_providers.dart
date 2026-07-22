// lib/features/wr/wr_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/data/wr_intelligence_repository.dart';
import '../../core/data/wr_repository.dart';
import '../../core/logic/wr_entitlement.dart';
import '../../core/models/checkin.dart';
import '../../core/models/wr_intelligence.dart';

/// Provides the current authenticated user's id.
/// Override in tests with a fixed userId string.
/// Returns null when no user is logged in.
final currentUserIdProvider = Provider<String?>((ref) {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
});

/// Fetches WrEntitlement for current user.
/// Returns WrEntitlement(plan: WrPlan.free) on null/error (safe default).
final wrEntitlementProvider = FutureProvider<WrEntitlement>((ref) async {
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  try {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return WrEntitlement(plan: WrPlan.free);
    final record = await repo.fetchEntitlement(userId);
    if (record == null) return WrEntitlement(plan: WrPlan.free);
    return WrEntitlement.fromRecord(record);
  } catch (_) {
    return WrEntitlement(plan: WrPlan.free);
  }
});

/// Fetch today's check-in (nullable). Used by WrHomeScreen to detect saved state.
final todayCheckinProvider = FutureProvider<Checkin?>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  return repo.getTodayCheckin();
});
