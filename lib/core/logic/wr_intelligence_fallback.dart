import '../models/wr_content.dart';
import '../models/wr_intelligence.dart';

/// Tạo bản tường thuật có căn cứ từ Career Memory khi backend AI chưa ghi
/// snapshot. Đây là fallback minh bạch, không giả danh nội dung AI.
List<PatternNarrative> buildPatternNarrativeFallback({
  required String userId,
  required List<CareerMemoryEvent> events,
  required List<WrSituation> situations,
  DateTime? now,
}) {
  final dated = events.where((e) => e.createdAt != null).toList();
  if (dated.length < 2) return const [];

  final anchor = now ?? DateTime.now();
  final recentStart = anchor.subtract(const Duration(days: 30));
  final previousStart = anchor.subtract(const Duration(days: 60));
  final recent = dated
      .where((e) => !e.createdAt!.isBefore(recentStart))
      .toList();
  final previous = dated
      .where(
        (e) =>
            !e.createdAt!.isBefore(previousStart) &&
            e.createdAt!.isBefore(recentStart),
      )
      .toList();

  String keyFor(CareerMemoryEvent event) =>
      event.situationCode ?? event.scaDimension?.dbValue ?? '';

  final recentCounts = <String, int>{};
  for (final event in recent) {
    final key = keyFor(event);
    if (key.isNotEmpty) recentCounts[key] = (recentCounts[key] ?? 0) + 1;
  }
  if (recentCounts.isEmpty) return const [];

  final sorted = recentCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted.first;
  if (top.value < 2) return const [];

  final previousCount = previous
      .where((event) => keyFor(event) == top.key)
      .length;
  final situationMap = {
    for (final situation in situations) situation.code: situation.text,
  };
  final label = situationMap[top.key] ?? top.key;
  final trend = switch ((top.value - previousCount).sign) {
    1 when previousCount == 0 => 'Đây là mô thức mới đang bắt đầu hiện rõ.',
    1 => 'Mô thức này xuất hiện nhiều hơn giai đoạn 30 ngày trước.',
    -1 => 'Mô thức này đang dịu đi so với giai đoạn 30 ngày trước.',
    _ => 'Mức độ lặp lại đang khá ổn định so với giai đoạn trước.',
  };

  return [
    PatternNarrative(
      userId: userId,
      periodStart: previousStart,
      periodEnd: anchor,
      narrative:
          'Trong 30 ngày gần đây, “$label” xuất hiện ${top.value} lần trong '
          'Career Memory của bạn. $trend Lần tới, hãy để ý điều gì xảy ra '
          'ngay trước tình huống này và lựa chọn nào giúp bạn tiến gần điều '
          'mình cần.',
    ),
  ];
}

/// Tóm tắt tiến độ thực hành khi backend chưa có Growth Journey snapshot.
List<GrowthJourneySnapshot> buildGrowthSnapshotFallback({
  required String userId,
  required List<PracticeEnrollment> enrollments,
  required List<PracticeTheme> themes,
  required Map<String, List<PracticeStep>> stepsByTheme,
  DateTime? now,
}) {
  if (enrollments.isEmpty) return const [];
  final themeMap = {for (final theme in themes) theme.themeId: theme};
  var totalSteps = 0;
  var completedSteps = 0;
  var completedThemes = 0;
  for (final enrollment in enrollments) {
    totalSteps += stepsByTheme[enrollment.themeId]?.length ?? 0;
    completedSteps += enrollment.completedSteps.length;
    if (enrollment.completedAt != null) completedThemes++;
  }

  final active = enrollments
      .where((enrollment) => enrollment.completedAt == null)
      .toList();
  final currentTheme = active.isEmpty
      ? null
      : themeMap[active.first.themeId]?.title;
  final direction = switch ((completedSteps, totalSteps, currentTheme)) {
    (0, _, final String title) =>
      'Bạn đã chọn “$title”. Hướng tiếp theo là hoàn thành bước Nhận diện đầu tiên.',
    (final done, final total, final String title) when done < total =>
      'Bạn đang đi tiếp với “$title”. Giữ nhịp bằng một hành động nhỏ kế tiếp, thay vì tăng độ khó quá sớm.',
    (_, _, _) =>
      'Bạn đã khép lại một chặng thực hành. Hãy nhìn lại điều gì đã thay đổi trước khi chọn hướng mới.',
  };

  final anchor = now ?? DateTime.now();
  return [
    GrowthJourneySnapshot(
      userId: userId,
      periodLabel: 'Tháng ${anchor.month}/${anchor.year}',
      progress: {
        'Bước hoàn thành': '$completedSteps/$totalSteps',
        'Chủ đề hoàn thành': completedThemes,
        'Chủ đề đang thực hành': active.length,
      },
      direction: direction,
    ),
  ];
}
