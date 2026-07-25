// lib/features/wr/wr_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/data/wr_content_repository.dart';
import '../../core/data/wr_intelligence_repository.dart';
import '../../core/data/wr_repository.dart';
import '../../core/logic/wr_career_profile.dart';
import '../../core/logic/wr_entitlement.dart';
import '../../core/models/checkin.dart';
import '../../core/models/wr_content.dart';
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

/// Fetch pattern counts for current user, ordered by occurrence_count desc.
final wrPatternCountsProvider = FutureProvider<List<PatternCount>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchPatternCounts(userId);
});

/// Fetch self-check history for current user, newest first.
final wrSelfCheckHistoryProvider = FutureProvider<List<ScaSelfCheckResponse>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchSelfCheckHistory(userId);
});

/// Fetch latest insight for current user.
final wrLatestInsightProvider = FutureProvider<WrInsight?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchLatestInsight(userId);
});

/// Fetch WR situations list (shared between home and discover screens).
final wrSituationsProvider = FutureProvider<List<WrSituation>>((ref) async {
  final repo = ref.watch(wrContentRepositoryProvider);
  return repo.fetchSituations();
});

/// Pattern Nâng cao — bản tường thuật diễn biến thay đổi qua thời gian.
/// Hai Lớp v1.2 §III: Paid.
final wrPatternNarrativesProvider =
    FutureProvider<List<PatternNarrative>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchPatternNarratives(userId);
});

/// Growth Journey snapshots (Progress, Direction). Hai Lớp v1.2 §III: Paid.
final wrGrowthSnapshotsProvider =
    FutureProvider<List<GrowthJourneySnapshot>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchGrowthSnapshots(userId);
});

/// Context Document (JD, CV). Hai Lớp v1.2 §III: tải lên Free (giới hạn số
/// lượng), phân tích sâu Paid.
final wrContextDocumentsProvider =
    FutureProvider<List<WrContextDocument>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchContextDocuments(userId);
});

/// Career Snapshot của người dùng hiện tại (vai trò · mục tiêu · trăn trở).
/// Trả về snapshot rỗng khi chưa đăng nhập hoặc chưa thiết lập.
final wrCareerSnapshotProvider = FutureProvider<CareerSnapshot>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  try {
    final profile = await repo.getMobileProfile();
    return profile?.careerSnapshot ?? const CareerSnapshot();
  } catch (_) {
    return const CareerSnapshot();
  }
});
