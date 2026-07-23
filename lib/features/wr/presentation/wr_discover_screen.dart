import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_self_check_questions.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Score 1.0–5.0 → percent 0–100.
double _scoreToPercent(double score) =>
    ((score - 1) / 4).clamp(0.0, 1.0) * 100;

/// Label for dominant need based on top SCA pillar.
String _dominantNeedLabel(ScaSelfCheckResponse r) {
  final s = r.structureScore ?? 0;
  final c = r.cultureScore ?? 0;
  final a = r.activityScore ?? 0;
  if (s >= c && s >= a) return 'Minh bạch vai trò';
  if (c >= s && c >= a) return 'An toàn khi lên tiếng';
  return 'Định hướng ý nghĩa';
}

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

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── top-area ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    WrEyebrow('Career Snapshot'),
                    SizedBox(height: 4),
                    Text(
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
                child: latest == null
                    ? _buildEmptyNeed(context)
                    : _buildDominantNeed(latest),
              ),
            ),

            // ── divider ─────────────────────────────────────────────────
            if (latest != null) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: WrSectionDivider(),
                ),
              ),

              // ── tình huống lặp lại ────────────────────────────────────
              if (patterns.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: _buildRecurringSituations(patterns, sitMap),
                  ),
                ),

              // ── SCA card ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: _buildScaCard(latest),
                ),
              ),

              // ── career health check ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: _buildHealthCheck(context, history.length),
                ),
              ),

              // ── premium gating ────────────────────────────────────────
              if (!isPremium) ...[
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

  // ── Dominant need ───────────────────────────────────────────────────────

  Widget _buildDominantNeed(ScaSelfCheckResponse latest) {
    final needLabel = _dominantNeedLabel(latest);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WrEyebrow('ĐIỀU BẠN ĐANG TÌM KIẾM'),
        const SizedBox(height: 10),
        WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"$needLabel"',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: WrColors.navy,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$needLabel · Nhu cầu chủ đạo',
                style: const TextStyle(
                  fontSize: 13,
                  color: WrColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Recurring situations ─────────────────────────────────────────────────

  Widget _buildRecurringSituations(
    List<PatternCount> patterns,
    Map<String, String> sitMap,
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
          final isTop = i == 0;
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
                        fontWeight: FontWeight.w700,
                        color: isTop ? WrColors.coral : WrColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                WrProgressTrack(
                  value: maxCount > 0
                      ? p.occurrenceCount / maxCount
                      : 0,
                  color: isTop ? WrColors.coral : WrColors.muted,
                ),
              ],
            ),
          );
        }),
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
