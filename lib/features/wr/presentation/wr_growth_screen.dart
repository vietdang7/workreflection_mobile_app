import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Phát triển — Practice Surface (WXS §8.6).
//
// Màn này chỉ giữ đúng một việc: chủ đề đang thực hành và bước kế tiếp.
// "Thực hành khác", "Kỹ năng đã hình thành" và "Chặng đường phát triển" đã
// tách thành màn riêng — bấm vào dòng mới mở, không xổ tại chỗ.

import '../../../core/data/wr_content_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_dominant_need.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_skill_certification.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_link_row.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WrGrowthScreen — ConsumerStatefulWidget for enroll double-tap guard
// ─────────────────────────────────────────────────────────────────────────────

class WrGrowthScreen extends ConsumerStatefulWidget {
  const WrGrowthScreen({super.key});

  @override
  ConsumerState<WrGrowthScreen> createState() => _WrGrowthScreenState();
}

class _WrGrowthScreenState extends ConsumerState<WrGrowthScreen> {
  // Guard chống double-tap khi đang enroll
  final Set<String> _enrollingThemeIds = {};

  Future<void> _enroll(String themeId) async {
    if (_enrollingThemeIds.contains(themeId)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _enrollingThemeIds.add(themeId));
    try {
      final repo = ref.read(wrIntelligenceRepositoryProvider);
      await repo.enrollTheme(PracticeEnrollment(
        userId: userId,
        themeId: themeId,
        completedSteps: const [],
      ));
      ref.invalidate(practiceEnrollmentsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không bắt đầu được. Thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _enrollingThemeIds.remove(themeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themesAsync = ref.watch(practiceThemesProvider);
    final enrollmentsAsync = ref.watch(practiceEnrollmentsProvider);
    final entitlementAsync = ref.watch(wrEntitlementProvider);
    final patternsAsync = ref.watch(wrPatternCountsProvider);
    final situationsAsync = ref.watch(wrSituationsProvider);
    final selfCheckAsync = ref.watch(wrSelfCheckHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: themesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildContent(
            context,
            themes: const [],
            enrollments: const [],
            entitlement: WrEntitlement(plan: WrPlan.free),
            patterns: const [],
            situations: const [],
            latestSelfCheck: null,
          ),
          data: (themes) {
            final enrollments = enrollmentsAsync.valueOrNull ?? const [];
            final entitlement = entitlementAsync.valueOrNull ??
                WrEntitlement(plan: WrPlan.free);
            final patterns = patternsAsync.valueOrNull ?? const [];
            final situations = situationsAsync.valueOrNull ?? const [];
            final history = selfCheckAsync.valueOrNull ?? const [];
            final latestSelfCheck = history.isNotEmpty ? history.first : null;
            return _buildContent(
              context,
              themes: themes,
              enrollments: enrollments,
              entitlement: entitlement,
              patterns: patterns,
              situations: situations,
              latestSelfCheck: latestSelfCheck,
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<PracticeTheme> themes,
    required List<PracticeEnrollment> enrollments,
    required WrEntitlement entitlement,
    required List<PatternCount> patterns,
    required List<WrSituation> situations,
    required ScaSelfCheckResponse? latestSelfCheck,
  }) {
    // Find the first active (non-completed) enrollment
    final activeEnrollment =
        enrollments.where((e) => e.completedAt == null).firstOrNull;
    final activeTheme = activeEnrollment != null
        ? themes.where((t) => t.themeId == activeEnrollment.themeId).firstOrNull
        : null;

    // Themes chưa enroll (loại bỏ MỌI enrollment, kể cả completed)
    final enrolledThemeIds = enrollments.map((e) => e.themeId).toSet();
    final unenrolledThemes =
        themes.where((t) => !enrolledThemeIds.contains(t.themeId)).toList();

    // Dominant need tính từ behaviour hoặc self-check
    final behaviourNeed = dominantNeedFromBehaviour(patterns, situations);
    final dominantNeed = behaviourNeed ??
        (latestSelfCheck != null
            ? dominantNeedFromSelfCheck(latestSelfCheck)
            : null);

    // WXS §3.12 Inv.6 — Development Flow chỉ mở khi Pattern đủ mạnh (≥ 2 lần
    // lặp cùng chủ đề). Một lần gặp chưa phải Pattern, không được vội đẩy
    // người dùng vào thực hành. Tự đánh giá SCA không thay thế được điều này.
    final canSuggestPractice = developmentFlowUnlocked(
      need: behaviourNeed,
      patterns: patterns,
      situations: situations,
    );

    // Theme gợi ý: match trụ từ dominantNeed
    PracticeTheme? suggestedTheme;
    bool hasPillarReason = false;
    if (canSuggestPractice && dominantNeed != null && unenrolledThemes.isNotEmpty) {
      final pillar = needPillarLetter(dominantNeed);
      suggestedTheme = unenrolledThemes
          .where(
            (t) =>
                t.scaDimension != null &&
                t.scaDimension!.dbValue.startsWith(pillar),
          )
          .firstOrNull;
      if (suggestedTheme != null) {
        hasPillarReason = true;
      } else {
        // Fallback: theme chưa enroll đầu tiên bất kỳ
        suggestedTheme = unenrolledThemes.first;
        hasPillarReason = false;
      }
    }

    // Quota
    final activeCount = enrollments.where((e) => e.completedAt == null).length;

    // ── Shared onStepDone handler
    Future<void> onStepDone(
      String stepId,
      List<String> currentCompleted,
      List<PracticeStep> allSteps,
    ) async {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;
      final repo = ref.read(wrIntelligenceRepositoryProvider);
      final contentRepo = ref.read(wrContentRepositoryProvider);

      final newCompleted = [...currentCompleted, stepId];
      await repo.updateEnrollmentSteps(
        userId: userId,
        themeId: activeTheme!.themeId,
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
          reflectionText: '${activeTheme.title} — ${stepTitle ?? stepId}',
        ),
      );

      // Chứng nhận kỹ năng: lặp lại đủ nhiều thì ghi một dấu mốc, đúng một lần.
      try {
        final events = await contentRepo.fetchMemoryEvents(limit: 200);
        final certified = certifiedSkills(
          themes: [activeTheme],
          enrollments: [activeEnrollment!.copyWith(completedSteps: newCompleted)],
          events: events,
        );
        for (final skill
            in newlyCertified(certified: certified, events: events)) {
          await contentRepo.insertMemoryEvent(
            CareerMemoryEvent(
              id: '',
              userId: userId,
              behavior: kSkillCertifiedBehavior,
              reflectionText: skill.title,
            ),
          );
        }
      } catch (_) {
        /* best-effort: dấu mốc sẽ được ghi ở lần thực hành sau */
      }

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

      ref.invalidate(practiceEnrollmentsProvider);
    }

    return CustomScrollView(
      slivers: [
        // ── Top area ────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WrTabBackLink(currentTab: WrTab.growth),
                const Text(
                  'Development Map',
                  style: TextStyle(
                    fontSize: 14,
                    color: WrColors.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
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

        // ── Task C: Card "Bước đang chờ bạn" (khi có active theme) ─────────
        if (activeTheme != null)
          _NextStepCardSliver(
            theme: activeTheme,
            enrollment: activeEnrollment!,
            entitlement: entitlement,
          ),

        // ── Active theme card (card-dark) or suggestion/empty invite ────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: activeTheme != null
                ? _ActiveThemeCardDark(
                    theme: activeTheme,
                    enrollment: activeEnrollment!,
                    entitlement: entitlement,
                    onStepDone: onStepDone,
                    onPremiumTap: () => context.push('/wr/paywall'),
                  )
                : _buildNoActiveThemeCard(
                    context,
                    suggestedTheme: suggestedTheme,
                    dominantNeed: dominantNeed,
                    hasPillarReason: hasPillarReason,
                    canEnroll:
                        entitlement.canEnrollPracticeTheme(activeCount),
                  ),
          ),
        ),

        // ── Practices hôm nay (chỉ hiện khi có active theme) ────────────
        if (activeTheme != null)
          _PracticesSectionSliver(
            theme: activeTheme,
            enrollment: activeEnrollment!,
            entitlement: entitlement,
            onStepDone: onStepDone,
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

        // ── Ba lối rẽ, mỗi lối một màn riêng ────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeTheme == null) const WrSectionDivider(),
                WrLinkRow(
                  key: const Key('wr_growth_other_themes_row'),
                  label: 'Thực hành khác',
                  hint: unenrolledThemes.isEmpty
                      ? null
                      : '${unenrolledThemes.length} chủ đề',
                  onTap: () => context.push('/wr/growth/themes'),
                ),
                WrLinkRow(
                  key: const Key('wr_growth_skills_row'),
                  label: 'Kỹ năng đã hình thành',
                  onTap: () => context.push('/wr/growth/skills'),
                ),
                WrLinkRow(
                  key: const Key('wr_growth_journey_row'),
                  label: 'Chặng đường phát triển',
                  onTap: () => context.push('/wr/growth/journey'),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ── Task B: Card khi không có active enrollment ───────────────────────────

  Widget _buildNoActiveThemeCard(
    BuildContext context, {
    required PracticeTheme? suggestedTheme,
    required HumanNeed? dominantNeed,
    required bool hasPillarReason,
    required bool canEnroll,
  }) {
    if (suggestedTheme == null) {
      // Fallback cũ: không có theme hoặc themes rỗng
      return WrCardMinimal(
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
      );
    }

    // Card gợi ý
    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WrEyebrow('GỢI Ý TỪ HIỂU MÌNH'),
          const SizedBox(height: 10),
          Text(
            suggestedTheme.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.3,
            ),
          ),
          if (suggestedTheme.description != null) ...[
            const SizedBox(height: 6),
            Text(
              suggestedTheme.description!,
              style: const TextStyle(
                fontSize: 13,
                color: WrColors.muted,
                height: 1.5,
              ),
            ),
          ],
          if (hasPillarReason && dominantNeed != null) ...[
            const SizedBox(height: 6),
            Text(
              'Vì bạn đang tìm kiếm ${needSeekingLabel(dominantNeed)}.',
              style: const TextStyle(
                fontSize: 12,
                color: WrColors.muted,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: canEnroll
                  ? () => _enroll(suggestedTheme.themeId)
                  : () => context.push('/wr/paywall'),
              style: TextButton.styleFrom(
                backgroundColor: WrColors.navy,
                foregroundColor: WrColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Bắt đầu thực hành',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          WrActionLink(
            label: 'Xem trong Hiểu mình',
            onTap: () => context.go('/wr/discover?from=growth'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task C: _NextStepCardSliver — card "BƯỚC ĐANG CHỜ BẠN"
// ─────────────────────────────────────────────────────────────────────────────

class _NextStepCardSliver extends ConsumerWidget {
  const _NextStepCardSliver({
    required this.theme,
    required this.enrollment,
    required this.entitlement,
  });

  final PracticeTheme theme;
  final PracticeEnrollment enrollment;
  final WrEntitlement entitlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(practiceStepsProvider(theme.themeId));

    return SliverToBoxAdapter(
      child: stepsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (rawSteps) {
          final steps = List.of(rawSteps)
            ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
          final completed = enrollment.completedSteps;

          // Bước tiếp theo: chưa xong, không bị premium lock
          final nextStep = steps
              .where(
                (s) =>
                    !completed.contains(s.stepId) &&
                    !(s.isPremium &&
                        !entitlement.canAccessPracticeStep(isPremiumStep: true)),
              )
              .firstOrNull;

          if (nextStep == null) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Container(
              decoration: BoxDecoration(
                color: WrColors.white,
                border: Border.all(
                  color: WrColors.navy.withValues(alpha: 0.12),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Ô vuông coral nhạt với icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: WrColors.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        '◎',
                        style: TextStyle(
                          fontSize: 16,
                          color: WrColors.coral,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BƯỚC ĐANG CHỜ BẠN',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: WrColors.coral,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '"${theme.title}" — ${nextStep.title}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: WrColors.navy,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
    final stepsAsync = ref.watch(practiceStepsProvider(theme.themeId));
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
                completedCount >= totalSteps
                    ? 'Hoàn thành'
                    : 'Giai đoạn ${min(completedCount + 1, totalSteps)} / $totalSteps',
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
    final stepsAsync = ref.watch(practiceStepsProvider(theme.themeId));

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
              data: (rawSteps) {
                final steps = List.of(rawSteps)
                  ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
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

  // Task E: Tag theo stepOrder
  Widget? _buildStepTag() {
    final order = step.stepOrder;
    if (order == 1) {
      return _StepTag(label: 'NHẬN DIỆN', color: const Color(0xFF5B8CC9));
    } else if (order == 2) {
      return _StepTag(label: 'THỬ NGHIỆM', color: WrColors.navy);
    } else if (order == 3) {
      return _StepTag(label: 'CHUYỂN HÓA', color: const Color(0xFF5E7A5A));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tag = _buildStepTag();

    return AnimatedOpacity(
      opacity: isDone ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 200),
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

              // ── Title + tag + status ─────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task E: tag trên title
                    if (tag != null) ...[
                      tag,
                      const SizedBox(height: 3),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// _StepTag — Task E: tag nhỏ trên title bước
// ─────────────────────────────────────────────────────────────────────────────

class _StepTag extends StatelessWidget {
  const _StepTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.07 * 8,
      ),
    );
  }
}
