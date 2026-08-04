// Providers dùng chung cho nhóm màn Phát triển.
//
// Trước đây tất cả nằm private trong `wr_growth_screen.dart`. Sau khi tách
// "Thực hành khác", "Kỹ năng đã hình thành" và "Chặng đường phát triển" ra
// những màn riêng (một màn – một hành động), các màn này cần đọc chung nguồn.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_content_repository.dart';
import '../../core/data/wr_intelligence_repository.dart';
import '../../core/logic/wr_dominant_need.dart';
import '../../core/logic/wr_practice_match.dart';
import '../../core/logic/wr_practice_theme_grant.dart';
import '../../core/logic/wr_repeated_situations.dart';
import '../../core/logic/wr_skill_formation.dart';
import '../../core/logic/wr_skill_jd_match.dart';
import '../../core/models/wr_content.dart';
import '../../core/models/wr_intelligence.dart';
import 'wr_providers.dart';

final practiceThemesProvider =
    FutureProvider<List<PracticeTheme>>((ref) async {
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchPracticeThemes();
});

final practiceEnrollmentsProvider =
    FutureProvider<List<PracticeEnrollment>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchEnrollments(userId);
});

final practiceStepsProvider =
    FutureProvider.family<List<PracticeStep>, String>((ref, themeId) async {
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchPracticeSteps(themeId);
});

/// Một bước thực hành đang chờ người dùng — chủ đề nào, bước nào.
class PendingPracticeStep {
  const PendingPracticeStep({required this.theme, required this.step});

  final PracticeTheme theme;
  final PracticeStep step;
}

/// Bước thực hành gần nhất còn dở — nguồn cho khối "Tiếp tục hôm nay" ở Home.
///
/// Xét TẤT CẢ chủ đề đang theo, không chỉ chủ đề đầu danh sách.
///
/// Bản trước chỉ soi đúng một ghi danh — cái đầu tiên — rồi bỏ cuộc nếu chủ đề
/// đó không còn bước nào mở được. Khách 2026-07-30 đang theo 3 chủ đề, hai chủ
/// đề đầu đã xong 2/3 bước và bước thứ ba của chúng là bước Premium, nên Home im
/// lặng dù chủ đề thứ ba mới 0/3 và bước đầu của nó mở thoải mái. Một chủ đề bí
/// không có nghĩa là cả ba đều bí.
///
/// Trong số các chủ đề còn bước mở được, chọn chủ đề ĐANG GẦN ĐÍCH NHẤT (nhiều
/// bước hoàn thành nhất). Hoà thì lấy chủ đề bắt đầu sớm hơn. "Tiếp tục" nên
/// nghĩa là tiếp tục việc dở dang nhất, không phải việc mới nhất.
///
/// Bỏ qua bước bị khoá là có chủ đích: mời người dùng "tiếp tục" một bước họ
/// không mở được là dẫn thẳng vào paywall từ màn Home, đúng chỗ khách muốn giữ
/// tối giản nhất.
final wrPendingPracticeStepProvider =
    FutureProvider<PendingPracticeStep?>((ref) async {
  final enrollments = await ref.watch(practiceEnrollmentsProvider.future);
  final active = enrollments.where((e) => e.completedAt == null).toList();
  if (active.isEmpty) return null;

  final themes = await ref.watch(practiceThemesProvider.future);
  final entitlement = await ref.watch(wrEntitlementProvider.future);
  final themeById = {for (final t in themes) t.themeId: t};

  // Gần đích nhất trước; hoà thì chủ đề bắt đầu sớm hơn. Ghi danh chưa có
  // `startedAt` xếp cuối — không có mốc thời gian thì không thể coi là sớm.
  active.sort((a, b) {
    final byProgress =
        b.completedSteps.length.compareTo(a.completedSteps.length);
    if (byProgress != 0) return byProgress;
    final sa = a.startedAt;
    final sb = b.startedAt;
    if (sa == null && sb == null) return 0;
    if (sa == null) return 1;
    if (sb == null) return -1;
    return sa.compareTo(sb);
  });

  for (final enrollment in active) {
    final theme = themeById[enrollment.themeId];
    if (theme == null) continue;

    final steps =
        (await ref.watch(practiceStepsProvider(theme.themeId).future)).toList()
          ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    final next = steps
        .where((s) =>
            !enrollment.completedSteps.contains(s.stepId) &&
            !(s.isPremium &&
                !entitlement.canAccessPracticeStep(isPremiumStep: true)))
        .firstOrNull;
    if (next != null) return PendingPracticeStep(theme: theme, step: next);
  }

  // Mọi chủ đề đang theo đều hết bước mở được. Home vẫn giữ khối "Tiếp tục hôm
  // nay" và đổi sang lời mời chọn chủ đề khác.
  return null;
});

/// Nhu cầu chủ đạo của người dùng — nguồn NÀO MỚI HƠN thì nguồn đó thắng.
///
/// Hai hướng khách chốt 2026-07-31: tích luỹ hàng ngày, hoặc làm bộ 15 câu.
///
/// Bản trước luôn ưu tiên hành vi, self-check chỉ là dự phòng khi chưa nhìn lại
/// lần nào. Hệ quả: người đã nhìn lại vài lần rồi mới ngồi trả lời 15 câu thì
/// kết quả bộ đó không đổi được gì — họ vừa nói thẳng mình đang vướng ở đâu mà
/// phần mềm vẫn đọc theo hành vi cũ (khách chỉ ra 2026-08-04).
///
/// Giờ so mốc thời gian: bộ tự đánh giá làm sau lần nhìn lại gần nhất thì nó là
/// tiếng nói mới nhất và nó thắng; nhìn lại tiếp sau đó thì hành vi thắng lại.
final wrDominantNeedProvider = Provider<HumanNeed?>((ref) {
  final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
  final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
  final history =
      ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];

  final behaviour =
      dominantNeedFromBehaviour(recentSituationIds(episodes), situations);
  final latest = history.isNotEmpty ? history.first : null;
  if (latest == null) return behaviour;

  final fromSelfCheck = dominantNeedFromSelfCheck(latest);
  if (behaviour == null) return fromSelfCheck;

  // Mốc của hành vi = lần nhìn lại gần nhất. Không tin thứ tự danh sách, tự lấy
  // mốc lớn nhất: Episode bỏ dở vẫn đếm nên thứ tự không phải lúc nào cũng theo
  // thời gian.
  DateTime? lastReflectionAt;
  for (final e in episodes) {
    final at = e.closedAt ?? e.updatedAt ?? e.openedAt;
    if (at == null) continue;
    if (lastReflectionAt == null || at.isAfter(lastReflectionAt)) {
      lastReflectionAt = at;
    }
  }

  // Không biết mốc hành vi thì nhường cho self-check: nó có mốc rõ ràng.
  if (lastReflectionAt == null) return fromSelfCheck;
  return latest.takenAt.isAfter(lastReflectionAt) ? fromSelfCheck : behaviour;
});

/// Chủ đề hệ thống đề xuất tiếp theo, kèm lý do — MỘT nguồn cho mọi màn.
///
/// null = chưa đủ dữ liệu để nói gì (chưa được hưởng chủ đề nào theo
/// [earnedPracticeThemes], chưa suy được nhu cầu chủ đạo), hoặc đã ghi danh hết
/// chủ đề trong thư viện.
/// Lúc đó màn hình phải nói thẳng là chưa có, KHÔNG được bày một danh sách chủ
/// đề trần ra cho người dùng tự chọn: chủ đề là thứ phần mềm chuẩn bị dựa trên
/// những gì họ đã nhìn lại, không phải một thực đơn (yêu cầu khách 2026-08-04).
final wrPracticeSuggestionProvider = Provider<PracticeSuggestion?>((ref) {
  final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
  final enrollments =
      ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];
  final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
  final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
  final history =
      ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];

  final recent = recentSituationIds(episodes);
  final need = ref.watch(wrDominantNeedProvider);

  // Chủ đề đã ngưng đề xuất không nằm trong danh sách mời; đã ghi danh (kể cả
  // đã hoàn thành) cũng vậy — mời lại là mời làm lại việc đã làm.
  final enrolledIds = enrollments.map((e) => e.themeId).toSet();
  final candidates = themes
      .where((t) => !enrolledIds.contains(t.themeId) && !t.isRetired)
      .toList();

  final earned = earnedPracticeThemes(
    reflectionCount: episodes.length,
    selfCheckCount: history.length,
  );
  if (earned < 1 || need == null || candidates.isEmpty) return null;

  return suggestPracticeTheme(
    candidates: candidates,
    recent: recent,
    situations: situations,
    need: need,
    jobPillars:
        ref.watch(wrSkillJdMatchProvider).valueOrNull?.matchedPillars ??
            const [],
  );
});

/// Career Memory events — nguồn để đếm số lần đã thực hành.
final practiceMemoryEventsProvider =
    FutureProvider<List<CareerMemoryEvent>>((ref) async {
  final repo = ref.watch(wrContentRepositoryProvider);
  try {
    return await repo.fetchMemoryEvents(limit: 200);
  } catch (_) {
    return const [];
  }
});

/// Ngưỡng số lần thực hành để một chủ đề thành kỹ năng.
///
/// Đi qua provider chứ không đọc thẳng hằng số ở màn hình: spec yêu cầu ngưỡng
/// phải chỉnh được. Hôm nay nguồn là build flag `WR_SKILL_THRESHOLD`; mai đổi
/// sang remote config thì chỉ sửa đúng chỗ này, và test vẫn override được.
final wrSkillThresholdProvider = Provider<int>((ref) => kSkillThreshold);

/// Trạng thái hình thành kỹ năng của mọi chủ đề đang theo.
///
/// Một nguồn duy nhất cho màn Kỹ năng, màn chủ đề và khoảnh khắc ăn mừng — ba
/// nơi này mà tự đếm riêng thì sẽ có ngày nói ba con số khác nhau.
final wrSkillFormationsProvider = Provider<List<SkillFormation>>((ref) {
  final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
  final enrollments =
      ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];
  final events = ref.watch(practiceMemoryEventsProvider).valueOrNull ?? const [];
  return skillFormations(
    themes: themes,
    enrollments: enrollments,
    events: events,
    threshold: ref.watch(wrSkillThresholdProvider),
  );
});

/// Đối chiếu kỹ năng đã hình thành với mô tả công việc (Premium).
///
/// Null = chưa có mô tả vai trò, hoặc mô tả không đủ để nói gì chắc chắn.
/// Nguồn chữ là [wrJobContextTextProvider]: JD/CV đã được AI đọc nếu có, cộng
/// mô tả vai trò người dùng tự viết. Trước 2026-08-04 chỉ có `role_text`, vì
/// tài liệu tải lên chưa ai đọc.
final wrSkillJdMatchProvider = FutureProvider<SkillJdMatch?>((ref) async {
  final contextText = await ref.watch(wrJobContextTextProvider.future);
  final themes = await ref.watch(practiceThemesProvider.future);
  return matchSkillsToContext(
    contextText: contextText,
    formations: ref.watch(wrSkillFormationsProvider),
    allThemes: themes,
  );
});
