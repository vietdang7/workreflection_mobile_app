import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/recurring_situation.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../survey/survey_providers.dart';
import '../understand_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

class UnderstandScreen extends ConsumerWidget {
  const UnderstandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _UnderstandHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DominantNeedBlock(),
                  const SizedBox(height: 28),
                  _SituationsList(),
                  const SizedBox(height: 28),
                  _ScaCard(),
                  const SizedBox(height: 28),
                  _CareerHealthCheck(),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _UnderstandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.understandGreeting, style: WrTextStyles.greeting),
          const SizedBox(height: 4),
          Text(l10n.understandTitle, style: WrTextStyles.dateTitle),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dominant need (centred quote block)
// ---------------------------------------------------------------------------

class _DominantNeedBlock extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final insightAsync = ref.watch(understandLatestInsightProvider);

    return insightAsync.when(
      loading: () => const _LoadingCard(),
      error: (e, _) =>
          _ErrorCard(onRetry: () => ref.invalidate(understandLatestInsightProvider)),
      data: (insight) {
        final quote = insight != null
            ? '"${insight.content}"'
            : '"Đang tải hành trình của bạn..."';
        final source = insight?.source ?? 'VOICE';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              WrEyebrow(l10n.understandEyebrowNeed),
              const SizedBox(height: 16),
              WrParagraph(
                quote,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: WrColors.navy,
                  height: 1.35,
                  letterSpacing: -0.02 * 26,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$source ${l10n.understandNeedSuffix}',
                style: WrTextStyles.body.copyWith(fontSize: 14.5),
              ),
              const SizedBox(height: 12),
              _ViewAllInsightsLink(hasInsight: insight != null),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Recurring situations list with proportional progress bars
// ---------------------------------------------------------------------------

class _SituationsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final situationsAsync = ref.watch(understandSituationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.understandEyebrowSituations),
        const SizedBox(height: 12),
        situationsAsync.when(
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(
              onRetry: () => ref.invalidate(understandSituationsProvider)),
          data: (situations) {
            if (situations.isEmpty) {
              return Text(l10n.understandNoSituations,
                  style: WrTextStyles.body);
            }
            final maxCount = situations
                .map((s) => s.occurrenceCount)
                .reduce((a, b) => a > b ? a : b);
            return Column(
              children: situations.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SituationRow(
                    situation: s,
                    maxCount: maxCount,
                    isTop: i == 0,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _SituationRow extends StatelessWidget {
  const _SituationRow({
    required this.situation,
    required this.maxCount,
    required this.isTop,
  });

  final RecurringSituation situation;
  final int maxCount;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ratio = maxCount > 0 ? situation.occurrenceCount / maxCount : 0.0;
    final countColor = isTop ? WrColors.coral : WrColors.navy;
    final fillColor = isTop ? WrColors.coral : WrColors.navy;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(situation.label, style: WrTextStyles.hMedium),
            Text(
              l10n.understandSituationCount(situation.occurrenceCount),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: isTop ? FontWeight.w700 : FontWeight.w600,
                color: countColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        WrProgressTrack(value: ratio, color: fillColor),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SCA card
// ---------------------------------------------------------------------------

/// Maps a numeric SCA score to a status label + color.
/// Returns null when report is null (→ "Chưa đánh giá" muted).
({String label, Color color}) _scaStatus(double? score, AppLocalizations l10n) {
  if (score == null) {
    return (label: l10n.understandStatusUnrated, color: WrColors.muted);
  }
  if (score >= 4) {
    return (label: l10n.understandStatusStable, color: WrColors.teal);
  }
  if (score >= 2.5) {
    return (label: l10n.understandStatusImproving, color: WrColors.coral);
  }
  return (label: l10n.understandStatusNeedsAttention, color: WrColors.coral);
}

class _ScaCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scaAsync = ref.watch(understandScaReportProvider);

    return scaAsync.when(
      loading: () => const _LoadingCard(),
      error: (e, _) =>
          _ErrorCard(onRetry: () => ref.invalidate(understandScaReportProvider)),
      data: (report) {
        final sStatus = _scaStatus(report?.scoreStructure, l10n);
        final cStatus = _scaStatus(report?.scoreCulture, l10n);
        final aStatus = _scaStatus(report?.scoreActivity, l10n);

        return WrCardMinimal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WrEyebrow(l10n.understandEyebrowSca),
              const SizedBox(height: 16),
              _ScaRow(
                badge: 'S',
                badgeColor: WrColors.teal,
                label: l10n.understandScaRole,
                status: sStatus.label,
                statusColor: sStatus.color,
              ),
              const SizedBox(height: 12),
              _ScaRow(
                badge: 'C',
                badgeColor: WrColors.coral,
                label: l10n.understandScaVoice,
                status: cStatus.label,
                statusColor: cStatus.color,
              ),
              const SizedBox(height: 12),
              _ScaRow(
                badge: 'A',
                badgeColor: WrColors.navy,
                label: l10n.understandScaMeaning,
                status: aStatus.label,
                statusColor: aStatus.color,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScaRow extends StatelessWidget {
  const _ScaRow({
    required this.badge,
    required this.badgeColor,
    required this.label,
    required this.status,
    required this.statusColor,
  });

  final String badge;
  final Color badgeColor;
  final String label;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: WrTextStyles.hMedium),
        ),
        Text(
          status,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Career Health Check
// ---------------------------------------------------------------------------

class _CareerHealthCheck extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final countAsync = ref.watch(understandInsightCountProvider);
    final latestReportAsync = ref.watch(latestReportProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.understandEyebrowHealth),
        const SizedBox(height: 12),
        countAsync.when(
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(
              onRetry: () => ref.invalidate(understandInsightCountProvider)),
          data: (count) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.understandHealthReady(count),
                style: WrTextStyles.hMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.understandHealthPrompt, style: WrTextStyles.body),
              const SizedBox(height: 12),
              WrActionLink(
                label: l10n.understandHealthCta,
                onTap: () => context.push('/survey'),
              ),
              // Show "Xem báo cáo gần nhất" if a report exists
              latestReportAsync.when(
                data: (report) => report != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: WrActionLink(
                          label: l10n.reportViewLatest,
                          onTap: () =>
                              context.push('/survey/report/${report.id}'),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              // "Xem lịch sử khảo sát" — visible when at least one report exists
              latestReportAsync.when(
                data: (report) => report != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: WrActionLink(
                          label: l10n.reportViewHistory,
                          onTap: () => context.push('/survey/history'),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// View-all insights link (only shown when at least one insight exists)
// ---------------------------------------------------------------------------

class _ViewAllInsightsLink extends StatelessWidget {
  const _ViewAllInsightsLink({required this.hasInsight});

  /// True when the latest-insight provider returned a non-null value,
  /// meaning at least one insight exists for this user.
  final bool hasInsight;

  @override
  Widget build(BuildContext context) {
    if (!hasInsight) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return WrActionLink(
      key: const Key('understand_view_all_insights'),
      label: l10n.understandViewAllInsights,
      onTap: () => context.push('/insights'),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(l10n.homeErrorLoadData, style: WrTextStyles.body),
        const SizedBox(width: 8),
        TextButton(onPressed: onRetry, child: Text(l10n.homeRetry)),
      ],
    );
  }
}
