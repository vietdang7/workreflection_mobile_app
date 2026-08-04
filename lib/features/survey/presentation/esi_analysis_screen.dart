// ESI Analysis Screen — Phase 5 Task 3.
// Shows ESI score, eNPS score, and 5-pillar breakdown.
// Only meaningful when report.scoreEsi != null (premium reports).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/survey_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../survey_providers.dart';

// ---------------------------------------------------------------------------
// ESI pillar definitions
// ---------------------------------------------------------------------------

/// Each pillar groups one or more sub-components. The pillar score is the
/// average of all sub-component scores that belong to it.
class _EsiPillar {
  const _EsiPillar({
    required this.key,
    required this.subComponents,
  });
  final String key; // e.g. 'compensation'
  final List<String> subComponents;
}

const _esiPillars = [
  _EsiPillar(
      key: 'compensation',
      subComponents: ['compensation_income', 'compensation_benefits']),
  _EsiPillar(key: 'growth', subComponents: ['growth_career']),
  _EsiPillar(key: 'fairness', subComponents: ['fairness_evaluation']),
  _EsiPillar(key: 'support',
      subComponents: [
        'support_management',
        'support_feedback',
        'support_collaboration',
        'support_leadership',
      ]),
  _EsiPillar(key: 'colleagues',
      subComponents: ['support_collaboration', 'support_leadership']),
];

String _pillarLabel(String key, AppLocalizations l10n) => switch (key) {
      'compensation' => l10n.esiPillarCompensation,
      'growth' => l10n.esiPillarGrowth,
      'fairness' => l10n.esiPillarFairness,
      'support' => l10n.esiPillarSupport,
      'colleagues' => l10n.esiPillarColleagues,
      _ => key,
    };

// ---------------------------------------------------------------------------
// Provider (local — avoids collision with report_screen's private provider)
// ---------------------------------------------------------------------------

final _reportForEsiProvider =
    FutureProvider.family<CcReportFull?, String>((ref, reportId) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getReport(reportId);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class EsiAnalysisScreen extends ConsumerWidget {
  const EsiAnalysisScreen({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportAsync = ref.watch(_reportForEsiProvider(reportId));

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.esiAnalysisTitle, style: WrTextStyles.hMedium),
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

          // Premium gate: if no ESI score, show placeholder
          if (report.scoreEsi == null) {
            return _EsiNoDataBody(l10n: l10n);
          }

          final pillarScoresAsync =
              ref.watch(esiPillarScoresProvider(report.surveyId));
          return pillarScoresAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child:
                  Text(l10n.surveyProcessingError, style: WrTextStyles.body),
            ),
            data: (pillarScores) => _EsiAnalysisBody(
              report: report,
              pillarScores: pillarScores,
              l10n: l10n,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No-data body (non-premium)
// ---------------------------------------------------------------------------

class _EsiNoDataBody extends StatelessWidget {
  const _EsiNoDataBody({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: WrCardMinimal(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.esiAnalysisNoData, style: WrTextStyles.hMedium),
            const SizedBox(height: 8),
            Text(l10n.esiAnalysisNoDataBody, style: WrTextStyles.body),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full body
// ---------------------------------------------------------------------------

class _EsiAnalysisBody extends ConsumerWidget {
  const _EsiAnalysisBody({
    required this.report,
    required this.pillarScores,
    required this.l10n,
  });

  final CcReportFull report;
  final Map<String, double> pillarScores;
  final AppLocalizations l10n;

  /// Compute avg score for a pillar by averaging its sub-component scores.
  double? _pillarScore(_EsiPillar pillar) {
    final values = pillar.subComponents
        .where((sc) => pillarScores.containsKey(sc))
        .map((sc) => pillarScores[sc]!)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _enpsCategory(int enps) {
    if (enps >= 9) return l10n.esiAnalysisEnpsPromoter;
    if (enps >= 7) return l10n.esiAnalysisEnpsPassive;
    return l10n.esiAnalysisEnpsDetractor;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esi = report.scoreEsi!;
    final enps = report.scoreEnps;
    // Compute eNPS breakdown from responses at render time (web-canonical approach).
    final breakdown = enps != null
        ? ref.watch(enpsBreakdownProvider(report.surveyId)).valueOrNull
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // ESI score header card
          WrCardMinimal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrEyebrow(l10n.esiAnalysisEsiScore),
                const SizedBox(height: 12),
                Text(esi.toStringAsFixed(1), style: WrTextStyles.hLarge),
                const SizedBox(height: 8),
                WrProgressTrack(value: esi / 5.0, color: WrColors.teal),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // eNPS card (only if present)
          if (enps != null) ...[
            WrCardMinimal(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WrEyebrow(l10n.esiAnalysisEnpsScore),
                  const SizedBox(height: 12),
                  Text('$enps', style: WrTextStyles.hLarge),
                  const SizedBox(height: 8),
                  Text(_enpsCategory(enps), style: WrTextStyles.body),
                  if (breakdown != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.esiAnalysisEnpsPromoter}: ${breakdown.promoters} · '
                      '${l10n.esiAnalysisEnpsPassive}: ${breakdown.passives} · '
                      '${l10n.esiAnalysisEnpsDetractor}: ${breakdown.detractors}',
                      style:
                          WrTextStyles.body.copyWith(color: WrColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Pillars section
          Text(l10n.esiAnalysisPillarsTitle, style: WrTextStyles.hMedium),
          const SizedBox(height: 12),

          if (pillarScores.isEmpty) ...[
            WrCardMinimal(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.esiAnalysisNoData, style: WrTextStyles.hMedium),
                  const SizedBox(height: 8),
                  Text(l10n.esiAnalysisNoDataBody, style: WrTextStyles.body),
                ],
              ),
            ),
          ] else ...[
            ..._esiPillars.map((pillar) {
              final score = _pillarScore(pillar);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PillarCard(
                  pillarKey: pillar.key,
                  score: score,
                  l10n: l10n,
                ),
              );
            }),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pillar card
// ---------------------------------------------------------------------------

class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.pillarKey,
    required this.score,
    required this.l10n,
  });

  final String pillarKey;
  final double? score;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = _pillarLabel(pillarKey, l10n);
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
              if (score != null)
                Text(score!.toStringAsFixed(1), style: WrTextStyles.hLarge),
            ],
          ),
          const SizedBox(height: 10),
          if (score != null)
            WrProgressTrack(value: score! / 5.0, color: WrColors.teal)
          else
            Text(l10n.esiAnalysisNoData,
                style: WrTextStyles.body.copyWith(color: WrColors.muted)),
        ],
      ),
    );
  }
}
