import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/wr_card.dart';
import '../wr_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local providers
// ─────────────────────────────────────────────────────────────────────────────

final _practiceThemesProvider =
    FutureProvider<List<PracticeTheme>>((ref) async {
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchPracticeThemes();
});

final _practiceEnrollmentsProvider =
    FutureProvider<List<PracticeEnrollment>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchEnrollments(userId);
});

final _practiceStepsProvider =
    FutureProvider.family<List<PracticeStep>, String>((ref, themeId) async {
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchPracticeSteps(themeId);
});

// ─────────────────────────────────────────────────────────────────────────────
// WrGrowthScreen
// ─────────────────────────────────────────────────────────────────────────────

class WrGrowthScreen extends ConsumerWidget {
  const WrGrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(_practiceThemesProvider);
    final enrollmentsAsync = ref.watch(_practiceEnrollmentsProvider);
    final entitlementAsync = ref.watch(wrEntitlementProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: themesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildContent(
            context,
            ref,
            themes: const [],
            enrollments: const [],
            entitlement: WrEntitlement(plan: WrPlan.free),
          ),
          data: (themes) {
            final enrollments = enrollmentsAsync.valueOrNull ?? const [];
            final entitlement = entitlementAsync.valueOrNull ??
                WrEntitlement(plan: WrPlan.free);
            return _buildContent(
              context,
              ref,
              themes: themes,
              enrollments: enrollments,
              entitlement: entitlement,
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref, {
    required List<PracticeTheme> themes,
    required List<PracticeEnrollment> enrollments,
    required WrEntitlement entitlement,
  }) {
    // Find the first active (non-completed) enrollment
    final activeEnrollment =
        enrollments.where((e) => e.completedAt == null).firstOrNull;
    final activeTheme = activeEnrollment != null
        ? themes.where((t) => t.themeId == activeEnrollment.themeId).firstOrNull
        : null;

    return CustomScrollView(
      slivers: [
        // ── Top area ────────────────────────────────────────────────────────
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Development Map',
                  style: TextStyle(
                    fontSize: 14,
                    color: WrColors.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Phát triển',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: WrColors.navy,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Active theme card (card-dark) or empty invite ────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: activeTheme != null
                ? _ActiveThemeCardDark(
                    theme: activeTheme,
                    enrollment: activeEnrollment!,
                    entitlement: entitlement,
                    onStepDone: (stepId, steps, allSteps) async {
                      final userId = ref.read(currentUserIdProvider);
                      if (userId == null) return;
                      final repo = ref.read(wrIntelligenceRepositoryProvider);
                      final contentRepo = ref.read(wrContentRepositoryProvider);

                      final newCompleted = [...steps, stepId];
                      await repo.updateEnrollmentSteps(
                        userId: userId,
                        themeId: activeTheme.themeId,
                        completedSteps: newCompleted,
                      );

                      final stepTitle = allSteps
                          .where((s) => s.stepId == stepId)
                          .map((s) => s.title)
                          .firstOrNull;
                      await contentRepo.insertMemoryEvent(
                        CareerMemoryEvent(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          userId: userId,
                          behavior: 'practice_step_done',
                          reflectionText:
                              '${activeTheme.title} — ${stepTitle ?? stepId}',
                        ),
                      );

                      final allStepIds =
                          allSteps.map((s) => s.stepId).toSet();
                      final hasCompletedAll =
                          allStepIds.every((id) => newCompleted.contains(id));

                      if (hasCompletedAll) {
                        await repo.completeTheme(
                          userId: userId,
                          themeId: activeTheme.themeId,
                        );
                        await contentRepo.insertMemoryEvent(
                          CareerMemoryEvent(
                            id: '${DateTime.now().millisecondsSinceEpoch}t',
                            userId: userId,
                            behavior: 'practice_theme_done',
                            reflectionText: activeTheme.title,
                          ),
                        );
                      }

                      ref.invalidate(_practiceEnrollmentsProvider);
                    },
                    onPremiumTap: () => context.push('/wr/paywall'),
                  )
                : WrCardMinimal(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const WrEyebrow(
                          'TRỌNG TÂM HIỆN TẠI',
                          color: WrColors.muted,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Chưa có chủ đề nào đang thực hành',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: WrColors.dark,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Đọc story và nhận Insight — WorkReflection sẽ đề xuất thực hành phù hợp với bạn.',
                          style: TextStyle(
                            fontSize: 13,
                            color: WrColors.muted,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        WrActionLink(
                          label: 'Khám phá story',
                          onTap: () => context.push('/wr/story'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // ── Practices hôm nay (chỉ hiện khi có active theme) ────────────
        if (activeTheme != null)
          _PracticesSectionSliver(
            theme: activeTheme,
            enrollment: activeEnrollment!,
            entitlement: entitlement,
            onStepDone: (stepId, steps, allSteps) async {
              final userId = ref.read(currentUserIdProvider);
              if (userId == null) return;
              final repo = ref.read(wrIntelligenceRepositoryProvider);
              final contentRepo = ref.read(wrContentRepositoryProvider);

              final newCompleted = [...steps, stepId];
              await repo.updateEnrollmentSteps(
                userId: userId,
                themeId: activeTheme.themeId,
                completedSteps: newCompleted,
              );

              final stepTitle = allSteps
                  .where((s) => s.stepId == stepId)
                  .map((s) => s.title)
                  .firstOrNull;
              await contentRepo.insertMemoryEvent(
                CareerMemoryEvent(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: userId,
                  behavior: 'practice_step_done',
                  reflectionText:
                      '${activeTheme.title} — ${stepTitle ?? stepId}',
                ),
              );

              final allStepIds = allSteps.map((s) => s.stepId).toSet();
              final hasCompletedAll =
                  allStepIds.every((id) => newCompleted.contains(id));

              if (hasCompletedAll) {
                await repo.completeTheme(
                  userId: userId,
                  themeId: activeTheme.themeId,
                );
                await contentRepo.insertMemoryEvent(
                  CareerMemoryEvent(
                    id: '${DateTime.now().millisecondsSinceEpoch}t',
                    userId: userId,
                    behavior: 'practice_theme_done',
                    reflectionText: activeTheme.title,
                  ),
                );
              }

              ref.invalidate(_practiceEnrollmentsProvider);
            },
            onPremiumTap: () => context.push('/wr/paywall'),
          ),

        // ── Divider ──────────────────────────────────────────────────────
        if (activeTheme != null)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 4, 22, 16),
              child: WrSectionDivider(),
            ),
          ),

        // NOTE: "Cơ hội phát triển" / opp-card section intentionally omitted.
        // No real workshop/opportunity data source exists in the current
        // codebase. Re-enable when a workshop data provider is wired up.

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActiveThemeCardDark — navy card-dark showing active theme + progress
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveThemeCardDark extends ConsumerWidget {
  const _ActiveThemeCardDark({
    required this.theme,
    required this.enrollment,
    required this.entitlement,
    required this.onStepDone,
    required this.onPremiumTap,
  });

  final PracticeTheme theme;
  final PracticeEnrollment enrollment;
  final WrEntitlement entitlement;
  final Future<void> Function(
    String stepId,
    List<String> currentCompleted,
    List<PracticeStep> allSteps,
  ) onStepDone;
  final VoidCallback onPremiumTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(_practiceStepsProvider(theme.themeId));
    final completed = enrollment.completedSteps;

    return WrCardDark(
      child: stepsAsync.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(
            child: CircularProgressIndicator(
              color: WrColors.white,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (steps) {
          final totalSteps = steps.length;
          final completedCount = completed.length;
          final progress =
              totalSteps > 0 ? completedCount / totalSteps : 0.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WrEyebrow(
                'TRỌNG TÂM HIỆN TẠI',
                color: WrColors.white.withValues(alpha: 0.50),
              ),
              const SizedBox(height: 10),
              Text(
                theme.title,
                maxLines: 2,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: WrColors.white,
                  height: 1.05,
                ),
              ),
              if (theme.description != null) ...[
                const SizedBox(height: 10),
                Text(
                  theme.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: WrColors.white.withValues(alpha: 0.70),
                    height: 1.55,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              WrProgressTrack(
                value: progress,
                color: WrColors.white.withValues(alpha: 0.80),
                trackColor: WrColors.white.withValues(alpha: 0.20),
                height: 3,
              ),
              const SizedBox(height: 8),
              Text(
                'Giai đoạn ${completedCount + 1} / $totalSteps',
                style: TextStyle(
                  fontSize: 12,
                  color: WrColors.white.withValues(alpha: 0.50),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PracticesSectionSliver — "PRACTICES HÔM NAY" list as a sliver
// ─────────────────────────────────────────────────────────────────────────────

class _PracticesSectionSliver extends ConsumerWidget {
  const _PracticesSectionSliver({
    required this.theme,
    required this.enrollment,
    required this.entitlement,
    required this.onStepDone,
    required this.onPremiumTap,
  });

  final PracticeTheme theme;
  final PracticeEnrollment enrollment;
  final WrEntitlement entitlement;
  final Future<void> Function(
    String stepId,
    List<String> currentCompleted,
    List<PracticeStep> allSteps,
  ) onStepDone;
  final VoidCallback onPremiumTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(_practiceStepsProvider(theme.themeId));

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WrEyebrow('PRACTICES HÔM NAY'),
            const SizedBox(height: 12),
            stepsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (steps) {
                final completed = enrollment.completedSteps;
                return Column(
                  children: steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    final isDone = completed.contains(step.stepId);
                    final isPremiumLocked = step.isPremium &&
                        !entitlement.canAccessPracticeStep(
                            isPremiumStep: true);
                    final isNext = !isDone &&
                        !isPremiumLocked &&
                        completed.length == step.stepOrder - 1;

                    return _PracticeListItem(
                      step: step,
                      isDone: isDone,
                      isPremiumLocked: isPremiumLocked,
                      isNext: isNext,
                      isFirst: index == 0,
                      onDone: isNext && !isPremiumLocked
                          ? () => onStepDone(step.stepId, completed, steps)
                          : null,
                      onPremiumTap:
                          isPremiumLocked ? onPremiumTap : null,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PracticeListItem — một bước trong danh sách practices
// ─────────────────────────────────────────────────────────────────────────────

class _PracticeListItem extends StatelessWidget {
  const _PracticeListItem({
    required this.step,
    required this.isDone,
    required this.isPremiumLocked,
    required this.isNext,
    required this.isFirst,
    this.onDone,
    this.onPremiumTap,
  });

  final PracticeStep step;
  final bool isDone;
  final bool isPremiumLocked;
  final bool isNext;
  final bool isFirst;
  final VoidCallback? onDone;
  final VoidCallback? onPremiumTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDone ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: isPremiumLocked ? onPremiumTap : null,
        child: Container(
          decoration: BoxDecoration(
            border: isFirst
                ? null
                : const Border(
                    top: BorderSide(
                      color: Color(0x0D093774), // rgba(9,55,116,0.05)
                    ),
                  ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Left icon (22px area) ────────────────────────────────
              SizedBox(
                width: 22,
                height: 22,
                child: Center(child: _buildIcon()),
              ),
              const SizedBox(width: 14),

              // ── Title + status ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? const Color(0xFF737373)
                            : WrColors.navy,
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                        decorationColor: const Color(0xFF737373),
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildStatusText(),
                  ],
                ),
              ),

              // ── Trailing action ──────────────────────────────────────
              if (isNext && onDone != null)
                GestureDetector(
                  onTap: onDone,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: WrColors.dark,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      'Xong',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: WrColors.white,
                      ),
                    ),
                  ),
                )
              else if (isPremiumLocked && onPremiumTap != null)
                GestureDetector(
                  onTap: onPremiumTap,
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: WrColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (isDone) {
      return const Icon(Icons.check_circle, color: WrColors.teal, size: 20);
    }
    if (isNext && !isPremiumLocked) {
      return const Icon(Icons.play_arrow, color: WrColors.coral, size: 16);
    }
    if (isPremiumLocked) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: WrColors.muted, width: 1.5),
        ),
      );
    }
    // Chưa bắt đầu
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: WrColors.muted.withValues(alpha: 0.40),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    if (isPremiumLocked) {
      return const Text(
        '⭐ Premium',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFFD4A017), // amber
        ),
      );
    }
    if (isDone) {
      return const Text(
        'Hoàn thành',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: WrColors.teal,
        ),
      );
    }
    if (isNext) {
      return const Text(
        'Đang thực hiện',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: WrColors.coral,
        ),
      );
    }
    return const Text(
      'Chưa bắt đầu',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: WrColors.muted,
      ),
    );
  }
}
