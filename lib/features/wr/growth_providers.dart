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
