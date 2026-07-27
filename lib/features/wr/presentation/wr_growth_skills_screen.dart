// Kỹ năng đã hình thành — màn riêng, mở từ tab Phát triển.
//
// Đây là GHI NHẬN, không phải diễn giải: hệ thống chỉ đếm số lần bạn đã lặp
// lại một hành vi. Vì vậy bản miễn phí cũng xem được (yêu cầu khách #4/#5).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/wr_skill_certification.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../growth_providers.dart';

class WrGrowthSkillsScreen extends ConsumerWidget {
  const WrGrowthSkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final enrollments =
        ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];
    final events =
        ref.watch(practiceMemoryEventsProvider).valueOrNull ?? const [];

    final skills = certifiedSkills(
      themes: themes,
      enrollments: enrollments,
      events: events,
    );

    // Chủ đề đang thực hành nhưng chưa đủ ngưỡng — cho biết còn bao xa.
    final enrolledIds = {
      for (final e in enrollments)
        if (e.completedAt == null) e.themeId,
    };
    final inProgress = [
      for (final t in themes)
        if (enrolledIds.contains(t.themeId) &&
            !skills.any((s) => s.themeId == t.themeId))
          (
            title: t.title,
            remaining: practicesUntilSkill(theme: t, events: events),
          ),
    ];

    return WrDetailScaffold(
      eyebrow: 'KỸ NĂNG ĐÃ HÌNH THÀNH',
      title: skills.isEmpty
          ? 'Chưa có kỹ năng nào được chứng nhận'
          : 'Bạn đã hình thành ${skills.length} kỹ năng',
      children: [
        if (skills.isEmpty)
          Text(
            'Khi bạn lặp lại một hành vi đủ $kSkillPracticeThreshold lần, '
            'WorkReflection ghi nhận nó đã trở thành kỹ năng của bạn.',
            key: const Key('wr_skills_empty'),
            style: const TextStyle(
              fontSize: 15,
              color: WrColors.muted,
              height: 1.65,
            ),
          )
        else
          ...skills.map(
            (s) => Padding(
              key: Key('wr_skill_${s.themeId}'),
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    size: 19,
                    color: WrColors.teal,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: WrColors.navy,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          s.completed
                              ? 'Bạn đã đi hết chặng thực hành này.'
                              : 'Bạn đã lặp lại ${s.practiceCount} lần — '
                                  'đủ để trở thành kỹ năng.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: WrColors.muted,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (inProgress.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'ĐANG TRÊN ĐƯỜNG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: WrColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          ...inProgress.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: WrColors.navy,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Còn ${p.remaining} lần thực hành nữa.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: WrColors.muted,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
