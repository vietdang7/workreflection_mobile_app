// Layer Detail Screen — Phase 5 Task 3.
// Shows per-sub-component score breakdown for STRUCTURE, CULTURE, or ACTIVITY.
// Available to all users who completed a survey (no premium gating).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/survey_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../survey_providers.dart';

// ---------------------------------------------------------------------------
// Sub-component label resolver
// ---------------------------------------------------------------------------

String _subCompLabel(String subComponent, AppLocalizations l10n) =>
    switch (subComponent) {
      'role_expect' => l10n.subCompRoleExpect,
      'collab_rules' => l10n.subCompCollabRules,
      'comm_channels' => l10n.subCompCommChannels,
      'trust' => l10n.subCompTrust,
      'psych_safety' => l10n.subCompPsychSafety,
      'feedback_dialogue' => l10n.subCompFeedbackDialogue,
      'goal_alignment' => l10n.subCompGoalAlignment,
      'execution_rhythm' => l10n.subCompExecutionRhythm,
      'retrospective' => l10n.subCompRetrospective,
      'continuous_improve' => l10n.subCompContinuousImprove,
      // ESI sub-components also reachable here if needed
      'compensation_income' => l10n.subCompCompensationIncome,
      'compensation_benefits' => l10n.subCompCompensationBenefits,
      'growth_career' => l10n.subCompGrowthCareer,
      'fairness_evaluation' => l10n.subCompFairnessEvaluation,
      'support_management' => l10n.subCompSupportManagement,
      'support_feedback' => l10n.subCompSupportFeedback,
      'support_collaboration' => l10n.subCompSupportCollaboration,
      'support_leadership' => l10n.subCompSupportLeadership,
      _ => subComponent,
    };

// ---------------------------------------------------------------------------
// Score status helpers  (≥4.0 → good, ≥3.0 → warning, else critical)
// ---------------------------------------------------------------------------

enum _ScoreStatus { good, warning, critical }

_ScoreStatus _status(double score) {
  if (score >= 4.0) return _ScoreStatus.good;
  if (score >= 3.0) return _ScoreStatus.warning;
  return _ScoreStatus.critical;
}

(String, Color) _statusLabel(_ScoreStatus status, AppLocalizations l10n) =>
    switch (status) {
      _ScoreStatus.good => (l10n.layerDetailScoreGood, WrColors.teal),
      _ScoreStatus.warning => (l10n.layerDetailScoreWarning, WrColors.coral),
      _ScoreStatus.critical =>
        (l10n.layerDetailScoreCritical, WrColors.destructive),
    };

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

// Provider family for a specific report (local to this file to avoid duplication)
final _reportForLayerDetailProvider =
    FutureProvider.family<CcReportFull?, String>((ref, reportId) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getReport(reportId);
});

class LayerDetailScreen extends ConsumerWidget {
  const LayerDetailScreen({
    super.key,
    required this.reportId,
    required this.layer,
  });

  final String reportId;

  /// One of: 'STRUCTURE', 'CULTURE', 'ACTIVITY'
  final String layer;

  String _layerTitle(AppLocalizations l10n) => switch (layer) {
        'STRUCTURE' => l10n.reportLayerStructure,
        'CULTURE' => l10n.reportLayerCulture,
        'ACTIVITY' => l10n.reportLayerActivity,
        _ => layer,
      };

  double _overallScore(CcReportFull report) => switch (layer) {
        'STRUCTURE' => report.scoreStructure,
        'CULTURE' => report.scoreCulture,
        'ACTIVITY' => report.scoreActivity,
        _ => 0.0,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportAsync = ref.watch(_reportForLayerDetailProvider(reportId));

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_layerTitle(l10n), style: WrTextStyles.hMedium),
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(l10n.surveyProcessingError, style: WrTextStyles.body),
        ),
        data: (report) {
          if (report == null) {
            return Center(
              child: Text(l10n.surveyProcessingError, style: WrTextStyles.body),
            );
          }
          final subScoresAsync =
              ref.watch(layerSubScoresProvider((report.surveyId, layer)));
          return subScoresAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(l10n.surveyProcessingError, style: WrTextStyles.body),
            ),
            data: (subScores) => _LayerDetailBody(
              report: report,
              layer: layer,
              overallScore: _overallScore(report),
              subScores: subScores,
              layerTitle: _layerTitle(l10n),
              l10n: l10n,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _LayerDetailBody extends StatelessWidget {
  const _LayerDetailBody({
    required this.report,
    required this.layer,
    required this.overallScore,
    required this.subScores,
    required this.layerTitle,
    required this.l10n,
  });

  final CcReportFull report;
  final String layer;
  final double overallScore;
  final List<SubComponentScore> subScores;
  final String layerTitle;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Overall score header card
          WrCardMinimal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.layerDetailOverallScore,
                    style: WrTextStyles.eyebrow
                        .copyWith(color: WrColors.text3, letterSpacing: 0.55)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      overallScore.toStringAsFixed(1),
                      style: WrTextStyles.hLarge,
                    ),
                    _StatusBadge(score: overallScore, l10n: l10n),
                  ],
                ),
                const SizedBox(height: 10),
                WrProgressTrack(
                    value: overallScore / 5.0, color: WrColors.coral),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sub-component cards or empty state
          if (subScores.isEmpty) ...[
            WrCardMinimal(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.layerDetailNoData, style: WrTextStyles.hMedium),
                  const SizedBox(height: 8),
                  Text(l10n.layerDetailNoDataBody, style: WrTextStyles.body),
                ],
              ),
            ),
          ] else ...[
            ...subScores.map((sc) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubComponentCard(
                    subScore: sc,
                    l10n: l10n,
                  ),
                )),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-component card
// ---------------------------------------------------------------------------

class _SubComponentCard extends StatelessWidget {
  const _SubComponentCard({required this.subScore, required this.l10n});

  final SubComponentScore subScore;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = _subCompLabel(subScore.subComponent, l10n);
    final status = _status(subScore.score);
    final (statusLabel, statusColor) = _statusLabel(status, l10n);

    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: WrTextStyles.hMedium),
              ),
              const SizedBox(width: 8),
              Text(
                subScore.score.toStringAsFixed(1),
                style: WrTextStyles.hLarge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          WrProgressTrack(value: subScore.score / 5.0, color: WrColors.coral),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InlineBadge(label: statusLabel, color: statusColor),
              Text(
                l10n.layerDetailResponses(subScore.count),
                style: WrTextStyles.body.copyWith(color: WrColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge (inline)
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.score, required this.l10n});
  final double score;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final status = _status(score);
    final (label, color) = _statusLabel(status, l10n);
    return _InlineBadge(label: label, color: color);
  }
}

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
