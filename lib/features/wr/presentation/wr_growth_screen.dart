import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
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
          error: (_, __) => _buildEmpty(context),
          data: (themes) {
            if (themes.isEmpty) return _buildEmpty(context);
            final enrollments = enrollmentsAsync.valueOrNull ?? const [];
            final entitlement = entitlementAsync.valueOrNull ??
                WrEntitlement(plan: WrPlan.free);
            return _buildThemes(context, ref, themes, enrollments, entitlement);
          },
        ),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) {
    return CustomScrollView(
      slivers: const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 12, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thực hành',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFA3A3A3),
                    letterSpacing: 0.02,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Chưa có chủ đề',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: WrColors.dark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Đọc story và nhận Insight — WorkReflection sẽ đề xuất thực hành phù hợp.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF737373),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Theme list view ──────────────────────────────────────────────────────

  Widget _buildThemes(
    BuildContext context,
    WidgetRef ref,
    List<PracticeTheme> themes,
    List<PracticeEnrollment> enrollments,
    WrEntitlement entitlement,
  ) {
    final activeCount =
        enrollments.where((e) => e.completedAt == null).length;

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 12, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thực hành',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFA3A3A3),
                    letterSpacing: 0.02,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Chủ đề của bạn',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: WrColors.dark,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final theme = themes[i];
              final enrollment = enrollments
                  .where((e) => e.themeId == theme.themeId)
                  .firstOrNull;
              return Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: _ThemeCard(
                  theme: theme,
                  enrollment: enrollment,
                  entitlement: entitlement,
                  activeEnrollmentCount: activeCount,
                  onEnroll: () async {
                    if (!entitlement.canEnrollPracticeTheme(activeCount)) {
                      context.push('/wr/paywall');
                      return;
                    }
                    final userId = ref.read(currentUserIdProvider);
                    if (userId == null) return;
                    final repo = ref.read(wrIntelligenceRepositoryProvider);
                    await repo.enrollTheme(
                      PracticeEnrollment(
                        userId: userId,
                        themeId: theme.themeId,
                      ),
                    );
                    ref.invalidate(_practiceEnrollmentsProvider);
                  },
                  onStepDone: (stepId, steps, allStepsForTheme) async {
                    final userId = ref.read(currentUserIdProvider);
                    if (userId == null) return;
                    final repo = ref.read(wrIntelligenceRepositoryProvider);
                    final contentRepo = ref.read(wrContentRepositoryProvider);

                    final newCompleted = [...steps, stepId];
                    await repo.updateEnrollmentSteps(
                      userId: userId,
                      themeId: theme.themeId,
                      completedSteps: newCompleted,
                    );

                    // Insert memory event
                    final stepTitle = allStepsForTheme
                        .where((s) => s.stepId == stepId)
                        .map((s) => s.title)
                        .firstOrNull;
                    await contentRepo.insertMemoryEvent(
                      CareerMemoryEvent(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        userId: userId,
                        behavior: 'practice_step_done',
                        reflectionText:
                            '${theme.title} — ${stepTitle ?? stepId}',
                      ),
                    );

                    // Only complete theme if all steps (including premium) are done
                    final allStepIds =
                        allStepsForTheme.map((s) => s.stepId).toSet();
                    final hasCompletedAll =
                        allStepIds.every((id) => newCompleted.contains(id));

                    if (hasCompletedAll) {
                      await repo.completeTheme(
                        userId: userId,
                        themeId: theme.themeId,
                      );
                      await contentRepo.insertMemoryEvent(
                        CareerMemoryEvent(
                          id: '${DateTime.now().millisecondsSinceEpoch}t',
                          userId: userId,
                          behavior: 'practice_theme_done',
                          reflectionText: theme.title,
                        ),
                      );
                    }

                    ref.invalidate(_practiceEnrollmentsProvider);
                  },
                ),
              );
            },
            childCount: themes.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ThemeCard — shows one practice theme with its steps
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard({
    required this.theme,
    required this.enrollment,
    required this.entitlement,
    required this.activeEnrollmentCount,
    required this.onEnroll,
    required this.onStepDone,
  });

  final PracticeTheme theme;
  final PracticeEnrollment? enrollment;
  final WrEntitlement entitlement;
  final int activeEnrollmentCount;
  final VoidCallback onEnroll;
  final Future<void> Function(
    String stepId,
    List<String> currentCompleted,
    List<PracticeStep> allSteps,
  ) onStepDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(_practiceStepsProvider(theme.themeId));

    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Theme header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  theme.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: WrColors.dark,
                  ),
                ),
                if (theme.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    theme.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF737373),
                      height: 1.55,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Steps
          stepsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (steps) {
              final completed = enrollment?.completedSteps ?? const [];
              return Column(
                children: steps.map((step) {
                  final isDone = completed.contains(step.stepId);
                  final isPremiumLocked = step.isPremium &&
                      !entitlement.canAccessPracticeStep(
                          isPremiumStep: true);
                  // Next step = first non-done, non-premium-locked step
                  final isNext = !isDone &&
                      !isPremiumLocked &&
                      completed.length == step.stepOrder - 1;

                  return _StepRow(
                    step: step,
                    isDone: isDone,
                    isPremiumLocked: isPremiumLocked,
                    isNext: isNext,
                    onDone: enrollment == null
                        ? null
                        : () => onStepDone(
                              step.stepId,
                              completed,
                              steps,
                            ),
                    onPremiumTap: isPremiumLocked
                        ? () => context.push('/wr/paywall')
                        : null,
                  );
                }).toList(),
              );
            },
          ),

          // Enroll / status button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: enrollment == null
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onEnroll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WrColors.dark,
                        foregroundColor: WrColors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Bắt đầu chủ đề',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : enrollment!.completedAt != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F7F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 14, color: WrColors.teal),
                            SizedBox(width: 6),
                            Text(
                              'Hoàn thành',
                              style: TextStyle(
                                  fontSize: 12, color: WrColors.teal),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StepRow
// ─────────────────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isDone,
    required this.isPremiumLocked,
    required this.isNext,
    this.onDone,
    this.onPremiumTap,
  });

  final PracticeStep step;
  final bool isDone;
  final bool isPremiumLocked;
  final bool isNext;
  final VoidCallback? onDone;
  final VoidCallback? onPremiumTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isPremiumLocked ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: isPremiumLocked ? onPremiumTap : null,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x0D000000))),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              // Step indicator
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDone
                      ? WrColors.teal
                      : const Color(0x0D000000),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check,
                          size: 12, color: WrColors.white)
                      : Text(
                          '${step.stepOrder}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA3A3A3),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? const Color(0xFF737373)
                            : WrColors.dark,
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (isPremiumLocked)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          '⭐ Premium',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFD4A017),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // "Xong" button for next step
              if (isNext && onDone != null && !isPremiumLocked)
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
