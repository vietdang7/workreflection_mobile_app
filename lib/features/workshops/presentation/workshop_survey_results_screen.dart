// Workshop survey results screen — Phase 5 Task 7.
//
// Shows the current user's own score summary from a completed workshop survey.
// Route: /workshops/:id/survey-results
//
// What the user sees (matching web SurveyResults.tsx):
//   - Overall weighted average score (1–5, one decimal)
//   - Engagement percentage (score/5 × 100)
//   - Per-layer scores (STRUCTURE / CULTURE / ACTIVITY / ESI / eNPS)
//   - Response count
//
// This is a read-only display screen — no actions beyond navigation back.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/workshop_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../workshops_providers.dart';

class WorkshopSurveyResultsScreen extends ConsumerWidget {
  const WorkshopSurveyResultsScreen({
    super.key,
    required this.workshopId,
  });

  final String workshopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final resultsAsync =
        ref.watch(workshopSurveyResultsProvider(workshopId));

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.wsSurveyResultsTitle, style: WrTextStyles.hMedium),
      ),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            l10n.wsSurveyResultsNotFound,
            key: const Key('ws_results_not_found'),
            style: WrTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ),
        data: (results) {
          if (results == null) {
            return Center(
              child: Text(
                l10n.wsSurveyResultsNotFound,
                key: const Key('ws_results_not_found'),
                style: WrTextStyles.body,
                textAlign: TextAlign.center,
              ),
            );
          }
          return _ResultsBody(results: results, l10n: l10n);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.results, required this.l10n});

  final WorkshopSurveyResults results;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final engagementPct = (results.total / 5.0 * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall score card
          WrCardMinimal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrEyebrow(l10n.wsSurveyResultsScore),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      results.total.toStringAsFixed(1),
                      key: const Key('ws_results_total'),
                      style: WrTextStyles.hLarge.copyWith(
                        fontSize: 48,
                        color: WrColors.navy,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        ' /5.0',
                        style: WrTextStyles.body.copyWith(
                          color: WrColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Engagement bar
                _EngagementBar(percentage: engagementPct),
                const SizedBox(height: 8),
                Text(
                  l10n.wsSurveyResultsResponses(results.responseCount),
                  style: WrTextStyles.body.copyWith(color: WrColors.muted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Per-layer scores
          if (results.layerScores.isNotEmpty) ...[
            WrCardMinimal(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in _orderedLayers(results.layerScores)) ...[
                    _LayerRow(
                      layer: entry.key,
                      score: entry.value,
                      l10n: l10n,
                    ),
                    if (entry.key !=
                        _orderedLayers(results.layerScores).last.key)
                      const Divider(height: 24),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Returns layer entries in canonical display order: SCA first, then ESI/eNPS.
  List<MapEntry<String, double>> _orderedLayers(
      Map<String, double> layerScores) {
    const order = [
      'STRUCTURE',
      'CULTURE',
      'ACTIVITY',
      'ESI',
      'ENPS',
    ];
    final result = <MapEntry<String, double>>[];
    for (final key in order) {
      final val = layerScores[key];
      if (val != null && val > 0) result.add(MapEntry(key, val));
    }
    // Any unexpected layers at the end.
    for (final e in layerScores.entries) {
      if (!order.contains(e.key) && e.value > 0) result.add(e);
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Engagement bar
// ---------------------------------------------------------------------------

class _EngagementBar extends StatelessWidget {
  const _EngagementBar({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 70 ? WrColors.teal : WrColors.coral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            key: const Key('ws_results_engagement_bar'),
            value: percentage / 100.0,
            minHeight: 8,
            backgroundColor: WrColors.muted.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Engagement: $percentage%',
          style: WrTextStyles.body.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Layer row
// ---------------------------------------------------------------------------

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.layer,
    required this.score,
    required this.l10n,
  });

  final String layer;
  final double score;
  final AppLocalizations l10n;

  Color get _scoreColor {
    if (score >= 4.2) return WrColors.teal;
    if (score >= 3.5) return WrColors.navy;
    if (score >= 2.8) return WrColors.amber; // amber
    return WrColors.coral;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                layer,
                style: WrTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: WrColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 5.0,
                  minHeight: 6,
                  backgroundColor: WrColors.muted.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(_scoreColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          score.toStringAsFixed(1),
          style: WrTextStyles.hMedium.copyWith(color: _scoreColor),
        ),
      ],
    );
  }
}
