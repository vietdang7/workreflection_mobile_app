import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Phát triển — Practice Surface (WXS §8.6).
//
// Màn này chỉ giữ đúng một việc: chủ đề đang thực hành và bước kế tiếp.
// "Thực hành khác", "Kỹ năng đã hình thành" và "Chặng đường phát triển" đã
// tách thành màn riêng — bấm vào dòng mới mở, không xổ tại chỗ.

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_dominant_need.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_link_row.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../../workshops/workshops_providers.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'wr_practice_theme_screen.dart';

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

    // Thẻ chủ đề: đang thực hành trước, đã hoàn thành xếp sau. Ghi danh trỏ
    // tới một chủ đề không còn trong thư viện thì bỏ qua — không dựng thẻ rỗng.
    final enrolledCards = <(PracticeTheme, PracticeEnrollment)>[
      for (final e in enrollments.where((e) => e.completedAt == null))
        if (themes.where((t) => t.themeId == e.themeId).firstOrNull
            case final t?)
          (t, e),
      for (final e in enrollments.where((e) => e.completedAt != null))
        if (themes.where((t) => t.themeId == e.themeId).firstOrNull
            case final t?)
          (t, e),
    ];


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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phát triển',
                            style: TextStyle(
                              fontSize: 14,
                              color: WrColors.muted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Thực hành',
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
                    // v1.6 §9.1: "Tôi" là avatar ở mọi màn tab.
                    const WrProfileAvatar(),
                  ],
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

        // ── Danh sách chủ đề, hoặc lời mời khi chưa có chủ đề nào ──────────
        //
        // Giao diện mẫu Sprint 2: màn này liệt kê CHỦ ĐỀ, không liệt kê bước.
        // Mỗi thẻ nói đủ ba điều — chủ đề nào, đang ở giai đoạn nào, còn mấy
        // bước — rồi bấm vào mới mở chuỗi bước ở màn riêng.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: enrolledCards.isEmpty
                ? _buildNoActiveThemeCard(
                    context,
                    suggestedTheme: suggestedTheme,
                    dominantNeed: dominantNeed,
                    hasPillarReason: hasPillarReason,
                    canEnroll:
                        entitlement.canEnrollPracticeTheme(activeCount),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WrEyebrow('CHỦ ĐỀ CỦA BẠN'),
                      const SizedBox(height: 12),
                      for (final pair in enrolledCards)
                        WrPracticeThemeCard(
                          key: Key('wr_growth_theme_card_${pair.$1.themeId}'),
                          theme: pair.$1,
                          enrollment: pair.$2,
                        ),
                      _QuotaCard(
                        quota: entitlement.maxActivePracticeThemes,
                        activeCount: activeCount,
                      ),
                    ],
                  ),
          ),
        ),

        // ── Divider ──────────────────────────────────────────────────────
        if (enrolledCards.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 4, 22, 16),
              child: WrSectionDivider(),
            ),
          ),

        // ── Cơ hội phát triển — workshop gần nhất sắp diễn ra ────────────
        const _OpportunitySliver(),

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
// _OpportunitySliver — "MỞ RỘNG OFFLINE" (opp-card của giao diện mẫu)
//
// Hai Lớp v1.6 §11.6 đổi nhãn thẻ workshop cross-sell này từ "Cơ hội phát
// triển" sang "Mở rộng offline": từ v1.6, "Cơ hội phát triển" chỉ còn một
// nghĩa duy nhất là Domain Concept ở tab Hành trình.
//
// Workshop chưa có trường gắn với trụ SCA hay nhu cầu, nên đây là buổi gần
// nhất sắp diễn ra chứ không phải buổi "hợp với bạn". Nói đúng điều mình biết:
// dòng phụ là ngày diễn ra, không phải một lý do bịa ra.
// ─────────────────────────────────────────────────────────────────────────────

class _OpportunitySliver extends ConsumerWidget {
  const _OpportunitySliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshops = ref.watch(activeWorkshopsProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final upcoming = workshops
        .where((w) => !w.date.isBefore(DateTime(now.year, now.month, now.day)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final next = upcoming.firstOrNull;
    if (next == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WrEyebrow('MỞ RỘNG OFFLINE'),
            const SizedBox(height: 12),
            InkWell(
              key: const Key('wr_growth_opportunity'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/workshops/${next.id}'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WrColors.cream,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: WrColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.mic_none_rounded,
                        size: 22,
                        color: WrColors.navy,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (next.category ?? 'Workshop').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: WrColors.teal,
                              letterSpacing: 0.44,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            next.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: WrColors.navy,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Ngày ${next.date.day.toString().padLeft(2, '0')}'
                                '/${next.date.month.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: WrColors.coral,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.arrow_forward,
                                size: 12,
                                color: WrColors.coral,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
            child: GestureDetector(
              key: const Key('wr_growth_next_step_card'),
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  context.push('/wr/growth/theme/${theme.themeId}'),
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
            ),
          );
        },
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// WrPracticeThemeCard — một chủ đề trên tab Phát triển (giao diện mẫu Sprint 2)
//
// Thẻ nói ba điều và chỉ ba điều: chủ đề nào, đang ở giai đoạn nào, còn mấy
// bước. Nội dung từng bước nằm ở màn chủ đề — một màn một việc.
// ─────────────────────────────────────────────────────────────────────────────

class WrPracticeThemeCard extends ConsumerWidget {
  const WrPracticeThemeCard({
    super.key,
    required this.theme,
    required this.enrollment,
  });

  final PracticeTheme theme;
  final PracticeEnrollment enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps =
        ref.watch(practiceStepsProvider(theme.themeId)).valueOrNull ?? const [];
    final total = steps.length;
    final done =
        steps.where((s) => enrollment.completedSteps.contains(s.stepId)).length;
    final finished = enrollment.completedAt != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/wr/growth/theme/${theme.themeId}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WrColors.white,
            border: Border.all(color: WrColors.navy.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      finished ? 'Đã hoàn thành' : 'Đang thực hành',
                      style: const TextStyle(
                        fontSize: 12,
                        color: WrColors.muted,
                      ),
                    ),
                  ),
                  if (total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: WrColors.navy.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        finished
                            ? 'Trọn chuỗi'
                            : 'Giai đoạn ${min(done + 1, total)}/$total',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                theme.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: WrColors.navy,
                  height: 1.25,
                ),
              ),
              if (total > 0) ...[
                const SizedBox(height: 12),
                WrPracticeProgressDots(total: total, done: done),
                const SizedBox(height: 10),
                Text(
                  '$done/$total bước hoàn thành',
                  style: const TextStyle(fontSize: 12.5, color: WrColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuotaCard — "Free: tối đa 2 chủ đề cùng lúc" (giao diện mẫu Sprint 2)
//
// Chỉ hiện với bản miễn phí: Premium không có trần nên nói ra là nói thừa.
// ─────────────────────────────────────────────────────────────────────────────

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota, required this.activeCount});

  final int? quota;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final max = quota;
    if (max == null) return const SizedBox.shrink();

    return GestureDetector(
      key: const Key('wr_growth_quota_card'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/wr/paywall?trigger=practice_limit'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: WrColors.navy.withValues(alpha: 0.16),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Text(
              'Bản miễn phí mở tối đa $max chủ đề cùng lúc '
              '(đang mở $activeCount/$max).',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: WrColors.muted,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Premium: không giới hạn',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: WrColors.coral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
