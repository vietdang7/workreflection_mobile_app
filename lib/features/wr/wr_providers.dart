// lib/features/wr/wr_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/data/wr_content_repository.dart';
import '../../core/data/wr_episode_repository.dart';
import '../../core/data/wr_intelligence_repository.dart';
import '../../core/data/wr_repository.dart';
import '../../core/logic/wr_career_profile.dart';
import '../../core/logic/wr_entitlement.dart';
import '../../core/models/checkin.dart';
import '../../core/models/wr_content.dart';
import '../../core/models/wr_episode.dart';
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
/// Episode phản tư đang mở của người dùng — WXS §4.5 (pause/resume).
/// Home dùng provider này để mời tiếp tục thay vì bắt đầu lại từ đầu.
/// Trả về null khi bảng chưa tồn tại hoặc chưa có Episode nào đang mở.
final wrOpenEpisodeProvider = FutureProvider<ReflectionEpisode?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final repo = ref.watch(wrEpisodeRepositoryProvider);
  try {
    return await repo.fetchOpenEpisode(userId);
  } catch (_) {
    return null;
  }
});

/// Thư viện story — nguồn cho khối "Gợi ý khi …" trên màn Hôm nay.
final wrStoriesProvider = FutureProvider<List<WrStory>>((ref) async {
  final repo = ref.watch(wrContentRepositoryProvider);
  try {
    return await repo.fetchStories();
  } catch (_) {
    return const [];
  }
});

/// Career Memory events của người dùng — nguồn phụ cho tab Hành trình
/// (thực hành, kỹ năng, insight rời). Rỗng khi chưa đăng nhập hoặc lỗi đọc.
final wrMemoryEventsProvider =
    FutureProvider<List<CareerMemoryEvent>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrContentRepositoryProvider);
  try {
    return await repo.fetchMemoryEventsForUser(userId);
  } catch (_) {
    return const [];
  }
});

/// Một Episode cụ thể — nguồn cho màn đọc chi tiết mở từ Hành trình.
final wrEpisodeByIdProvider =
    FutureProvider.family<ReflectionEpisode?, String>((ref, id) async {
  final repo = ref.watch(wrEpisodeRepositoryProvider);
  try {
    return await repo.fetchEpisode(id);
  } catch (_) {
    return null;
  }
});

/// Lịch sử Episode, mới nhất trước — nguồn cho tab Hành trình.
final wrEpisodeHistoryProvider =
    FutureProvider<List<ReflectionEpisode>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrEpisodeRepositoryProvider);
  try {
    return await repo.fetchEpisodes(userId, limit: 50);
  } catch (_) {
    return const [];
  }
});

final wrCareerSnapshotProvider = FutureProvider<CareerSnapshot>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  try {
    final profile = await repo.getMobileProfile();
    return profile?.careerSnapshot ?? const CareerSnapshot();
  } catch (_) {
    return const CareerSnapshot();
  }
});
