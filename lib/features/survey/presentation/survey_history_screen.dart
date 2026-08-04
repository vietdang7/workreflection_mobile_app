import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/survey_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../survey_providers.dart';

// ---------------------------------------------------------------------------
// Score-level badge color — mirrors ReportScreen._ScoreLevelBadge
// ---------------------------------------------------------------------------

Color _levelColor(ScoreLevel level) => switch (level) {
      ScoreLevel.high => WrColors.teal,
      ScoreLevel.good => WrColors.navy,
      ScoreLevel.warning => WrColors.coral,
      ScoreLevel.critical => WrColors.destructive,
    };

String _levelLabel(ScoreLevel level, AppLocalizations l10n) => switch (level) {
      ScoreLevel.high => l10n.reportScoreLevelHigh,
      ScoreLevel.good => l10n.reportScoreLevelGood,
      ScoreLevel.warning => l10n.reportScoreLevelWarning,
      ScoreLevel.critical => l10n.reportScoreLevelCritical,
    };

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SurveyHistoryScreen extends ConsumerWidget {
  const SurveyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportsAsync = ref.watch(myReportsProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: WrColors.navy),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/understand');
            }
          },
        ),
        title: Text(l10n.surveyHistoryTitle, style: WrTextStyles.hMedium),
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(myReportsProvider),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ReportRow(
              report: reports[i],
              onTap: () => context.push('/survey/report/${reports[i].id}'),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Report row
// ---------------------------------------------------------------------------

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report, required this.onTap});

  final CcReportSummary report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final dateStr = DateFormat('dd/MM/yyyy', locale).format(report.createdAt.toLocal());
    final color = _levelColor(report.scoreLevel);
    final levelLabel = _levelLabel(report.scoreLevel, l10n);

    return GestureDetector(
      key: Key('survey_history_row_${report.id}'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: WrColors.cream,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr,
                      style: WrTextStyles.hMedium.copyWith(fontSize: 14)),
                  const SizedBox(height: 4),
                  // Free / Premium chip
                  _TypeChip(isPremium: report.isPremium, l10n: l10n),
                ],
              ),
            ),
            // Score
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    report.scoreTotal.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: WrColors.navy,
                    ),
                  ),
                  Text(
                    l10n.surveyHistoryScoreLabel,
                    style: WrTextStyles.body.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            // Level badge
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        levelLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Icon(Icons.chevron_right,
                        size: 16, color: WrColors.muted),
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

// ---------------------------------------------------------------------------
// Free / Premium chip
// ---------------------------------------------------------------------------

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.isPremium, required this.l10n});

  final bool isPremium;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = isPremium
        ? l10n.surveyHistoryTypePremium
        : l10n.surveyHistoryTypeFree;
    final color = isPremium ? WrColors.coral : WrColors.muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded,
                size: 56, color: WrColors.muted),
            const SizedBox(height: 20),
            Text(
              l10n.surveyHistoryEmptyTitle,
              style: WrTextStyles.hMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.surveyHistoryEmptyBody,
              style: WrTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            WrPillButton(
              label: l10n.surveyHistoryEmptyCta,
              onPressed: () => context.push('/survey'),
              variant: WrPillVariant.coral,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: WrColors.coral, size: 40),
          const SizedBox(height: 12),
          Text(l10n.homeErrorLoadData, style: WrTextStyles.body),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(l10n.homeRetry),
          ),
        ],
      ),
    );
  }
}
