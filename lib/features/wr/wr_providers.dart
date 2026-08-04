// lib/features/wr/wr_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../../core/logic/wr_growth_opportunity.dart';
import '../../core/logic/wr_premium_override.dart';
import '../../core/logic/wr_pricing.dart';
import '../../core/logic/wr_repeated_situations.dart';
import '../../core/logic/wr_situation_picker.dart';
import '../../core/models/wr_mood_content.dart';
import '../profile/profile_providers.dart';
import 'episode_flow_controller.dart';
// Nhập ngược từ growth_providers (file kia cũng nhập file này). Dart cho phép
// nhập vòng; giữ như vậy vì Cơ hội phát triển cần khoảng trống kỹ năng, mà
// nguồn của nó là ghi danh + Career Memory đã gom sẵn ở growth_providers.
import 'growth_providers.dart';

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

/// Email của người đang đăng nhập. Override trong test.
///
/// Chỉ dùng để quyết định ai thấy công tắc Premium thử nghiệm — mọi thứ khác
/// định danh bằng [currentUserIdProvider].
final currentUserEmailProvider = Provider<String?>((ref) {
  try {
    return Supabase.instance.client.auth.currentUser?.email;
  } catch (_) {
    return null;
  }
});

/// True khi người đang đăng nhập được phép bật/tắt gói ngay trong app.
final canTogglePremiumProvider = Provider<bool>(
  (ref) => canTogglePremium(ref.watch(currentUserEmailProvider)),
);

/// Trạng thái công tắc Premium thử nghiệm, lưu trên máy.
///
/// null = chưa động vào, dùng gói thật. Xem `wr_premium_override.dart`.
final premiumOverrideProvider =
    StateNotifierProvider<PremiumOverrideNotifier, bool?>(
  (ref) => PremiumOverrideNotifier()..load(),
);

class PremiumOverrideNotifier extends StateNotifier<bool?> {
  PremiumOverrideNotifier() : super(null);

  static const String _key = 'wr_dev_premium_override';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // containsKey chứ không phải getBool ?? false: "chưa động vào" và "đã ép
      // về miễn phí" là hai trạng thái khác nhau.
      if (prefs.containsKey(_key)) state = prefs.getBool(_key);
    } catch (_) {
      /* không đọc được thì coi như chưa động vào — dùng gói thật */
    }
  }

  /// [value] null nghĩa là trả về gói thật.
  Future<void> set(bool? value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setBool(_key, value);
      }
    } catch (_) {
      /* best-effort: đổi được trong phiên này, mở lại app thì mất */
    }
  }
}

/// Fetches WrEntitlement for current user.
/// Returns WrEntitlement(plan: WrPlan.free) on null/error (safe default).
///
/// Công tắc thử nghiệm được áp ở ĐÂY, tức trước mọi cổng Premium của app —
/// `canUseFeature`, hạn mức chủ đề thực hành, hạn mức tài liệu bối cảnh đều
/// đọc qua provider này, nên bật một chỗ là cả app đổi theo.
///
/// HAI NGUỒN, HOẶC BÊN NÀO CŨNG ĐƯỢC (khách chốt 2026-08-01: "nếu trên web
/// role Premium thì trên app cũng Premium luôn"):
///   • `cc_profiles.role` ∈ {premium, admin} — gói mua trên web;
///   • `wr_entitlements` — gói mua trong app, khi nào mở thanh toán thì tới.
/// Không đồng bộ dữ liệu giữa hai bảng, chỉ HỢP hai câu trả lời lúc đọc. Đồng
/// bộ bằng migration là cách đã làm hỏng một lần rồi (xem migration
/// `20260731160000` và bản lùi `20260731170000`): nó chép trạng thái tại một
/// thời điểm, rồi trạng thái đó mốc đi. Hợp lúc đọc thì không bao giờ mốc.
final wrEntitlementProvider = FutureProvider<WrEntitlement>((ref) async {
  final override = ref.watch(premiumOverrideProvider);
  if (override != null && ref.watch(canTogglePremiumProvider)) {
    // validUntil để null: WrEntitlement.isPremium coi null là còn hạn, đúng ý
    // "ép cứng", khỏi phải bịa một ngày hết hạn.
    return WrEntitlement(plan: override ? WrPlan.premium : WrPlan.free);
  }

  // Nguồn 1 — vai trò trên web.
  //
  // `await ... .future` chứ không phải `.valueOrNull`: chờ hồ sơ tải xong rồi
  // hẵng trả lời. Đọc giá trị hiện có sẽ trả "miễn phí" trong khoảnh khắc đầu
  // và người Premium thấy paywall nháy lên rồi mới biến mất.
  var webPremium = false;
  try {
    final cc = await ref.watch(ccProfileProvider.future);
    webPremium = isWebPremiumRole(cc['role'] as String?);
  } catch (_) {
    /* không đọc được hồ sơ web thì còn nguồn 2 bên dưới */
  }
  // validUntil null: vai trò web không mang hạn dùng, hết hạn là trang quản trị
  // hạ role xuống. Bịa một ngày ở đây sẽ tự khoá app trong khi web vẫn mở.
  if (webPremium) return WrEntitlement(plan: WrPlan.premium);

  // Nguồn 2 — gói mua trong app.
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

/// Các gói Premium bán trong app (năm / tháng), xếp theo `display_order`.
///
/// Không bao giờ ném và không bao giờ rỗng: hỏng mạng hoặc bảng chưa có gói nào
/// thì trả đúng một [WrPremiumPricing.fallback] — Paywall vẫn có con số để
/// hiển thị, còn nút mua tự khoá vì gói mặc định thiếu `productId`.
final wrPremiumPlansProvider =
    FutureProvider<List<WrPremiumPricing>>((ref) async {
  try {
    final plans = await ref.watch(wrRepositoryProvider).getPremiumPlans();
    return plans.isEmpty ? const [WrPremiumPricing.fallback] : plans;
  } catch (_) {
    return const [WrPremiumPricing.fallback];
  }
});

/// Gói chọn sẵn — phần tử đầu của [wrPremiumPlansProvider], tức gói có
/// `display_order` nhỏ nhất (hiện là gói năm).
///
/// Dùng cho những chỗ chỉ cần MỘT con số: màn thanh toán khi mở thẳng không
/// kèm gói đã chọn. Suy ra từ danh sách nên không tốn thêm một lượt gọi mạng.
final wrPremiumPricingProvider = FutureProvider<WrPremiumPricing>((ref) async {
  final plans = await ref.watch(wrPremiumPlansProvider.future);
  return plans.first;
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

/// Bối cảnh công việc dưới dạng CHỮ, gộp từ mọi nguồn đang có.
///
/// Thứ tự ưu tiên, và vì sao:
///   1. Tài liệu đã phân tích xong (JD trước CV) — đây là lời của chính công
///      việc đó, không phải trí nhớ của người dùng về nó.
///   2. `role_text` người dùng tự viết — vẫn quý, và là thứ duy nhất có trước
///      khi họ tải tài liệu lên.
/// Gộp cả hai chứ không thay thế: một người có thể tải JD của vị trí đang ứng
/// tuyển nhưng mô tả công việc hiện tại bằng chữ, và cả hai đều là bối cảnh thật.
///
/// Null khi không có gì — nơi dùng phải im lặng chứ không bịa.
final wrJobContextTextProvider = FutureProvider<String?>((ref) async {
  final parts = <String>[];

  try {
    final docs = await ref.watch(wrContextDocumentsProvider.future);
    final ready = docs.where((d) => d.isReady).toList()
      // JD nói về công việc, CV nói về người. Đối chiếu kỹ năng với công việc
      // thì JD phải đứng trước.
      ..sort((a, b) {
        int rank(String? t) => switch (t) { 'jd' => 0, 'cv' => 1, _ => 2 };
        return rank(a.docType).compareTo(rank(b.docType));
      });

    for (final d in ready.take(2)) {
      final a = d.analysis;
      if (a != null && !a.isEmpty) {
        parts.addAll([
          if (a.title != null) a.title!,
          a.summary,
          ...a.responsibilities,
          ...a.requirements,
          ...a.skills,
          ...a.keywords,
        ].where((s) => s.trim().isNotEmpty));
      }
      final raw = d.extractedText;
      if (raw != null && raw.isNotEmpty) parts.add(raw);
    }
  } catch (_) {
    /* không đọc được tài liệu thì còn `role_text` bên dưới */
  }

  final role = await ref.watch(wrRoleTextProvider.future);
  if (role != null && role.trim().isNotEmpty) parts.add(role.trim());

  if (parts.isEmpty) return null;
  return parts.join('\n');
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

/// Lịch sử tình huống đã chọn gần đây (Hai Lớp v1.6 §4.1).
///
/// Nguồn cho cơ chế xoay vòng chống lặp ở bước chọn tình huống. Lưu theo Person
/// trên `wr_mobile_profiles` chứ không theo phiên (§XII.2), nên vẫn còn hiệu lực
/// sau khi đóng app hoặc đổi thiết bị.
final wrRecentSituationIdsProvider =
    FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  try {
    final profile = await repo.getMobileProfile();
    return profile?.recentSituationIds ?? const [];
  } catch (_) {
    // Không đọc được lịch sử thì coi như chưa xem gì — xoay vòng kém đi một
    // nhịp, nhưng danh sách gợi ý vẫn hiện đủ.
    return const [];
  }
});

/// Story ứng với tình huống của Episode đang mở — nguồn cho câu Self Reflection,
/// gợi ý Aha (bước Ý nghĩa) và Practice (bước Lựa chọn).
///
/// Kiến trúc Dữ liệu v1.6 §V. Null khi Episode chưa gắn tình huống nào (người
/// dùng tự viết thay vì chọn chip) hoặc không nối được sang story cùng chiều —
/// khi đó UI phải im lặng, không bịa một câu Aha.
final wrEpisodeStoryProvider = Provider<WrStory?>((ref) {
  final episode = ref.watch(episodeFlowProvider);
  final code = episode?.situationCode;
  if (code == null) return null;

  final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
  final stories = ref.watch(wrStoriesProvider).valueOrNull ?? const [];
  if (situations.isEmpty || stories.isEmpty) return null;

  WrSituation? situation;
  for (final s in situations) {
    if (s.code == code) {
      situation = s;
      break;
    }
  }
  if (situation == null) return null;

  return resolveStoryFor(situation, stories);
});

/// Mô tả công việc hiện tại người dùng tự viết (§XI, `wr_mobile_profiles.role_text`).
final wrRoleTextProvider = FutureProvider<String?>((ref) async {
  try {
    return (await ref.watch(wrRepositoryProvider).getMobileProfile())?.roleText;
  } catch (_) {
    // Không đọc được mô tả công việc thì Cơ hội phát triển vẫn nói được ở mức
    // trụ SCA — không đáng để cả khối biến mất.
    return null;
  }
});

/// Câu hỏi nghề nghiệp người dùng đã gửi, mới nhất trước (họp khách 2026-07-29).
///
/// Rỗng khi chưa đăng nhập hoặc bảng chưa tồn tại — ô hỏi vẫn dùng được, chỉ là
/// không có lịch sử để đọc lại.
final wrCareerQuestionsProvider =
    FutureProvider<List<CareerQuestion>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  try {
    return await ref
        .watch(wrIntelligenceRepositoryProvider)
        .fetchCareerQuestions(userId);
  } catch (_) {
    return const [];
  }
});

/// Cơ hội phát triển hiện tại (§XI).
///
/// Ưu tiên bản đối tác đã tổng hợp sẵn trong `wr_growth_opportunities`; chưa có
/// thì suy ra bằng luật ngay trên máy. Thứ tự này để khi đối tác bật AI, app tự
/// dùng bản của họ mà không cần sửa gì thêm.
///
/// Null nghĩa là chưa đủ dữ liệu — §11.3 yêu cầu im lặng, không bịa.
final wrGrowthOpportunityProvider =
    FutureProvider<GrowthOpportunity?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  try {
    final stored = await ref
        .watch(wrIntelligenceRepositoryProvider)
        .fetchLatestGrowthOpportunity(userId);
    if (stored != null) return stored;
  } catch (_) {
    /* bảng chưa có hoặc mạng hỏng — rơi xuống bản suy ra bằng luật */
  }

  final episodes = await ref.watch(wrEpisodeHistoryProvider.future);
  final situations = await ref.watch(wrSituationsProvider.future);
  final roleText = await ref.watch(wrRoleTextProvider.future);

  // Khoảng trống giữa công việc đang làm và kỹ năng đã hình thành là một nguồn
  // đầu vào của Cơ hội phát triển (spec Kỹ năng đã hình thành). Chỉ Premium:
  // phép đối chiếu với JD là diễn giải, đúng trục đã định ở chương Nguyên tắc
  // Logic Dữ liệu — phần GHI NHẬN kỹ năng thì vẫn Free.
  var gapTitles = const <String>[];
  final entitlement = await ref.watch(wrEntitlementProvider.future);
  if (entitlement.isPremium) {
    final match = await ref.watch(wrSkillJdMatchProvider.future);
    if (match != null) {
      gapTitles = [for (final t in match.gapThemes) t.title];
    }
  }

  return deriveGrowthOpportunity(
    userId: userId,
    recent: recentSituationIds(episodes),
    situations: situations,
    roleText: roleText,
    skillGapTitles: gapTitles,
    now: DateTime.now(),
  );
});
