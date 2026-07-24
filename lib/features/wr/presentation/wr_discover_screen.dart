import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_dominant_need.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_card.dart';
import '../wr_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Score 1.0–5.0 → percent 0–100.
double _scoreToPercent(double score) =>
    ((score - 1) / 4).clamp(0.0, 1.0) * 100;

/// Quote and caption for each HumanNeed (4 nhu cầu cốt lõi).
({String quote, String caption}) _needDisplay(HumanNeed need) => switch (need) {
      HumanNeed.roRang => (
          quote: '"Được rõ ràng về vai trò và điều mình cần đạt tới."',
          caption: 'Rõ ràng · Nhu cầu chủ đạo',
        ),
      HumanNeed.ketNoi => (
          quote: '"Được lắng nghe, tin tưởng và kết nối thật với đồng đội."',
          caption: 'Kết nối · Nhu cầu chủ đạo',
        ),
      HumanNeed.thichNghi => (
          quote: '"Được một nhịp làm việc ổn định để đi vào chiều sâu."',
          caption: 'Thích nghi · Nhu cầu chủ đạo',
        ),
      HumanNeed.phatTrien => (
          quote: '"Được làm công việc có ý nghĩa và ngày càng tiến bộ."',
          caption: 'Phát triển · Nhu cầu chủ đạo',
        ),
    };

// ── SCA helpers (unchanged) ────────────────────────────────────────────────

/// SCA pillar label mapping.
String _scaLabel(SelfCheckPillar p) => switch (p) {
      SelfCheckPillar.s => 'Minh bạch vai trò',
      SelfCheckPillar.c => 'An toàn khi lên tiếng',
      SelfCheckPillar.a => 'Định hướng ý nghĩa',
    };

/// Score → status string.
String _scaStatus(double? score) {
  if (score == null) return 'Chưa đánh giá';
  return _scoreToPercent(score) >= 70 ? 'Ổn định' : 'Đang cải thiện';
}

/// Score → status color.
Color _scaStatusColor(double? score) {
  if (score == null) return WrColors.muted;
  return _scoreToPercent(score) >= 70 ? WrColors.teal : WrColors.coral;
}

// ─────────────────────────────────────────────────────────────────────────────
// WrDiscoverScreen
// ─────────────────────────────────────────────────────────────────────────────

class WrDiscoverScreen extends ConsumerWidget {
  const WrDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(wrSelfCheckHistoryProvider);
    final patternsAsync = ref.watch(wrPatternCountsProvider);
    final situationsAsync = ref.watch(wrSituationsProvider);
    final entitlementAsync = ref.watch(wrEntitlementProvider);

    final history = historyAsync.valueOrNull ?? const [];
    final patterns = patternsAsync.valueOrNull ?? const [];
    final situations = situationsAsync.valueOrNull ?? const [];
    final entitlement =
        entitlementAsync.valueOrNull ?? WrEntitlement(plan: WrPlan.free);

    final sitMap = {for (final s in situations) s.code: s.text};
    final latest = history.isNotEmpty ? history.first : null;
    final isPremium = entitlement.isPremium;

    // Compute dominant need:
    // 1. From behaviour (patterns × situations humanNeed)
    // 2. Fallback from self-check lowest pillar (if has self-check but no patterns)
    final behaviourNeed = dominantNeedFromBehaviour(patterns, situations);
    final dominantNeed = behaviourNeed ??
        (latest != null ? dominantNeedFromSelfCheck(latest) : null);

    // Visibility rules:
    // - "Điều bạn đang tìm kiếm" + "Tình huống lặp lại": show when has patterns OR has self-check
    // - SCA card + health-check: show only when has self-check
    final hasPatterns = patterns.isNotEmpty;
    final hasSelfCheck = latest != null;
    final showNeedSection = hasPatterns || hasSelfCheck;

    return Scaffold(
      backgroundColor: WrColors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── top-area ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WrTabBackLink(currentTab: WrTab.discover),
                    const WrEyebrow('Career Snapshot'),
                    const SizedBox(height: 4),
                    const Text(
                      'Hiểu mình',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: WrColors.navy,
                        letterSpacing: -0.03 * 32, // -3% em tracking per mockup
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── divider ─────────────────────────────────────────────────
            const SliverToBoxAdapter(child: WrSectionDivider()),

            // ── nhu cầu chủ đạo ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: showNeedSection && dominantNeed != null
                    ? _buildDominantNeed(dominantNeed, context)
                    : _buildEmptyNeed(context),
              ),
            ),

            // ── sections that need at least patterns or self-check ───────
            if (showNeedSection) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: WrSectionDivider(),
                ),
              ),

              // ── tình huống lặp lại ────────────────────────────────────
              if (hasPatterns)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: _buildRecurringSituations(patterns, sitMap, context),
                  ),
                ),

              // ── SCA card (only when has self-check) ──────────────────
              if (hasSelfCheck)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: _buildScaCard(latest),
                  ),
                ),

              // ── career health check (only when has self-check) ────────
              if (hasSelfCheck)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: _buildHealthCheck(context, history.length),
                  ),
                ),

              // ── premium gating ────────────────────────────────────────
              if (hasSelfCheck && !isPremium) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: WrEyebrow('MỞ KHOÁ VỚI PREMIUM'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: _LockedCard(
                      icon: '📈',
                      title: 'Diễn giải sâu & xu hướng theo thời gian',
                      onTap: () =>
                          context.push('/wr/paywall?trigger=report'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: _LockedCard(
                      icon: '📊',
                      title: 'Báo cáo chuyên sâu 49 câu',
                      onTap: () =>
                          context.push('/wr/paywall?trigger=report'),
                    ),
                  ),
                ),
              ],
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  // ── Empty need state ────────────────────────────────────────────────────

  Widget _buildEmptyNeed(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WrEyebrow('ĐIỀU BẠN ĐANG TÌM KIẾM'),
        const SizedBox(height: 10),
        WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chưa có đủ dữ liệu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sau khi hoàn thành 15 câu phản chiếu, bức tranh nhu cầu của bạn sẽ hiện ra tại đây.',
                style: TextStyle(
                  fontSize: 14,
                  color: WrColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              WrActionLink(
                label: 'Làm 15 câu phản chiếu',
                onTap: () => context.push('/wr/self-check'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Dominant need (from behaviour or self-check fallback) ───────────────

  Widget _buildDominantNeed(HumanNeed need, BuildContext context) {
    final display = _needDisplay(need);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Center(child: WrEyebrow('ĐIỀU BẠN ĐANG TÌM KIẾM')),
        const SizedBox(height: 16),
        Text(
          display.quote,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
            color: WrColors.navy,
            height: 1.35,
            letterSpacing: -0.52,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          display.caption,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: WrColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        WrActionLink(
          label: 'Bắt đầu thực hành',
          onTap: () => context.go('/wr/growth'),
        ),
      ],
    );
  }

  // ── Recurring situations ─────────────────────────────────────────────────

  Widget _buildRecurringSituations(
    List<PatternCount> patterns,
    Map<String, String> sitMap,
    BuildContext context,
  ) {
    final maxCount =
        patterns.isEmpty ? 1 : patterns.first.occurrenceCount.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WrEyebrow('TÌNH HUỐNG LẶP LẠI'),
        const SizedBox(height: 12),
        ...patterns.take(5).toList().asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final name = sitMap[p.situationCode] ?? p.situationCode ?? '?';
          final Color countColor;
          final FontWeight countWeight;
          final Color trackColor;
          if (i == 0) {
            countColor = WrColors.coral;
            countWeight = FontWeight.w700;
            trackColor = WrColors.coral;
          } else if (i == 1) {
            countColor = WrColors.teal;
            countWeight = FontWeight.w600;
            trackColor = WrColors.navy;
          } else {
            countColor = WrColors.muted;
            countWeight = FontWeight.w600;
            trackColor = WrColors.navy.withValues(alpha: 0.4);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                    Text(
                      '${p.occurrenceCount} lần',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: countWeight,
                        color: countColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                WrProgressTrack(
                  value: maxCount > 0
                      ? p.occurrenceCount / maxCount
                      : 0,
                  color: trackColor,
                ),
              ],
            ),
          );
        }),
        // Task E: Link chéo sang Journey
        const SizedBox(height: 4),
        WrActionLink(
          label: 'Xem toàn bộ hành trình',
          onTap: () => context.go('/wr/journey'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── SCA card ─────────────────────────────────────────────────────────────

  Widget _buildScaCard(ScaSelfCheckResponse latest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WrEyebrow('TRẢI NGHIỆM HIỆN TẠI (SCA)'),
        const SizedBox(height: 10),
        WrCardMinimal(
          child: Column(
            children: [
              _ScaItem(
                pillar: SelfCheckPillar.s,
                score: latest.structureScore,
                badgeColor: WrColors.teal.withValues(alpha: 0.12),
                badgeTextColor: WrColors.teal,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: Color.fromRGBO(9, 55, 116, 0.06),
              ),
              _ScaItem(
                pillar: SelfCheckPillar.c,
                score: latest.cultureScore,
                badgeColor: WrColors.coral.withValues(alpha: 0.12),
                badgeTextColor: WrColors.coral,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: Color.fromRGBO(9, 55, 116, 0.06),
              ),
              _ScaItem(
                pillar: SelfCheckPillar.a,
                score: latest.activityScore,
                badgeColor: WrColors.navy.withValues(alpha: 0.08),
                badgeTextColor: WrColors.muted,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Career health check ──────────────────────────────────────────────────

  Widget _buildHealthCheck(BuildContext context, int count) {
    final isReady = count >= 15;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WrEyebrow('CAREER HEALTH CHECK'),
        const SizedBox(height: 10),
        WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isReady) ...[
                const Text(
                  'Bạn đã có đủ 15 reflection.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: WrColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sẵn sàng xem bức tranh tổng thể chưa?',
                  style: TextStyle(
                    fontSize: 14,
                    color: WrColors.muted,
                    height: 1.5,
                  ),
                ),
              ] else ...[
                Text(
                  'Bạn đã có $count/15 reflection',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: WrColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
                WrProgressTrack(
                  value: count / 15,
                  color: WrColors.coral,
                ),
              ],
              const SizedBox(height: 12),
              WrActionLink(
                label: 'Bắt đầu kiểm tra',
                onTap: () => context.push('/wr/self-check'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScaItem
// ─────────────────────────────────────────────────────────────────────────────

class _ScaItem extends StatelessWidget {
  const _ScaItem({
    required this.pillar,
    required this.score,
    required this.badgeColor,
    required this.badgeTextColor,
  });

  final SelfCheckPillar pillar;
  final double? score;
  final Color badgeColor;
  final Color badgeTextColor;

  @override
  Widget build(BuildContext context) {
    final label = _scaLabel(pillar);
    final status = _scaStatus(score);
    final statusColor = _scaStatusColor(score);
    final badgeLetter = pillar.name.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                badgeLetter,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: badgeTextColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Label
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WrColors.dark,
              ),
            ),
          ),
          // Status
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LockedCard
// ─────────────────────────────────────────────────────────────────────────────

class _LockedCard extends StatelessWidget {
  const _LockedCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final String icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 0.6,
        child: WrCardMinimal(
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: WrColors.dark,
                  ),
                ),
              ),
              const Text(
                '⭐ Premium',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: WrColors.amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
