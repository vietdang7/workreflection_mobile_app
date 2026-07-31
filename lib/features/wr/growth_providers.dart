// Providers dùng chung cho nhóm màn Phát triển.
//
// Trước đây tất cả nằm private trong `wr_growth_screen.dart`. Sau khi tách
// "Thực hành khác", "Kỹ năng đã hình thành" và "Chặng đường phát triển" ra
// những màn riêng (một màn – một hành động), các màn này cần đọc chung nguồn.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_content_repository.dart';
import '../../core/data/wr_intelligence_repository.dart';
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
