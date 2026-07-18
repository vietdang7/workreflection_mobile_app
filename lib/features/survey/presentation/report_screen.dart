import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/sca_chart_data.dart';
import '../../../core/logic/survey_scoring.dart';
import '../../../core/models/ai_personalization_models.dart';
import '../../../core/models/survey_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/profile_providers.dart';
import '../survey_providers.dart';

// Provider family for a specific report
final _reportProvider =
    FutureProvider.family<CcReportFull?, String>((ref, reportId) async {
  final repo = ref.watch(surveyRepositoryProvider);
  return repo.getReport(reportId);
});

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportAsync = ref.watch(_reportProvider(reportId));
    final narrativesAsync = ref.watch(narrativesProvider);

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: WrColors.navy),
          onPressed: () => context.go('/understand'),
        ),
        title: Text(l10n.reportTitle, style: WrTextStyles.hMedium),
      ),
      body: reportAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppLocalizations.of(context)!.surveyProcessingError)),
        data: (report) {
          if (report == null) {
            return Center(
                child: Text(l10n.surveyProcessingError,
                    style: WrTextStyles.body));
          }
          return narrativesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.surveyProcessingError,
                    style: WrTextStyles.body, textAlign: TextAlign.center),
              ),
            ),
            data: (narratives) => _ReportBody(
              report: report,
              narratives: narratives,
            ),
          );
        },
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({
    required this.report,
    required this.narratives,
  });

  final CcReportFull report;
  final List<CcNarrative> narratives;

  CcNarrative? _narrative(String type, {String? layer, required String language}) {
    return selectNarrative(
      narratives,
      type: type,
      layer: layer,
      score: type == 'TOTAL'
          ? report.scoreTotal
          : type == 'BOTTLENECK'
              ? _layerScore(report.bottleneckLayer)
              : _layerScore(
                  layer != null ? SurveyLayer.fromJson(layer) : SurveyLayer.structure),
      language: language,
    );
  }

  double _layerScore(SurveyLayer layer) => switch (layer) {
        SurveyLayer.structure => report.scoreStructure,
        SurveyLayer.culture => report.scoreCulture,
        SurveyLayer.activity => report.scoreActivity,
        _ => 0,
      };

  String _narrativeText(CcNarrative n, String language) {
    if (language == 'en' && n.narrativeTextEn != null) {
      return n.narrativeTextEn!;
    }
    return n.narrativeText;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final localeCode = ref.watch(appLocaleProvider);
    final totalNarrative = _narrative('TOTAL', language: localeCode);
    final isPremium =
        report.scoreEsi != null || report.scoreEnps != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Total score header
          Center(
            child: Column(
              children: [
                Text(
                  report.scoreTotal.toStringAsFixed(1),
                  style: WrTextStyles.dateTitle.copyWith(fontSize: 48),
                ),
                const SizedBox(height: 8),
                _ScoreLevelBadge(level: report.scoreLevel),
                if (totalNarrative != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _narrativeText(totalNarrative, localeCode),
                    textAlign: TextAlign.center,
                    style: WrTextStyles.body,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // SCA Radar Chart (above per-layer cards)
          ScaRadarChart(
            structure: report.scoreStructure,
            culture: report.scoreCulture,
            activity: report.scoreActivity,
            l10n: l10n,
          ),
          const SizedBox(height: 16),

          // S / C / A layer cards
          _LayerCard(
            label: l10n.reportLayerStructure,
            score: report.scoreStructure,
            layer: 'STRUCTURE',
            reportId: report.id,
            narrative: _narrative('LAYER', layer: 'STRUCTURE', language: localeCode),
            localeCode: localeCode,
          ),
          const SizedBox(height: 16),
          _LayerCard(
            label: l10n.reportLayerCulture,
            score: report.scoreCulture,
            layer: 'CULTURE',
            reportId: report.id,
            narrative: _narrative('LAYER', layer: 'CULTURE', language: localeCode),
            localeCode: localeCode,
          ),
          const SizedBox(height: 16),
          _LayerCard(
            label: l10n.reportLayerActivity,
            score: report.scoreActivity,
            layer: 'ACTIVITY',
            reportId: report.id,
            narrative: _narrative('LAYER', layer: 'ACTIVITY', language: localeCode),
            localeCode: localeCode,
          ),
          const SizedBox(height: 16),

          // Bottleneck card
          _BottleneckCard(
            report: report,
            narrative: _narrative('BOTTLENECK',
                layer: report.bottleneckLayer.toJson(), language: localeCode),
            l10n: l10n,
            localeCode: localeCode,
          ),
          const SizedBox(height: 16),

          // Premium / Free sections
          if (isPremium) ...[
            _EsiCard(report: report, l10n: l10n),
            const SizedBox(height: 16),
            _EnpsCard(report: report, l10n: l10n),
            const SizedBox(height: 16),
            // AI-personalized narratives (VI only; static fallback on any error)
            _AiPersonalizedPremiumSection(
              report: report,
              localeCode: localeCode,
            ),
          ] else
            _PremiumUpsellCard(l10n: l10n),

          const SizedBox(height: 28),

          // CTA
          WrPillButton(
            label: l10n.reportActionPlanCta,
            onPressed: () =>
                context.push('/survey/action-plan/${report.id}'),
            variant: WrPillVariant.coral,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score level badge
// ---------------------------------------------------------------------------

class _ScoreLevelBadge extends StatelessWidget {
  const _ScoreLevelBadge({required this.level});
  final ScoreLevel level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (level) {
      ScoreLevel.high => (l10n.reportScoreLevelHigh, WrColors.teal),
      ScoreLevel.good => (l10n.reportScoreLevelGood, WrColors.navy),
      ScoreLevel.warning => (l10n.reportScoreLevelWarning, WrColors.coral),
      ScoreLevel.critical => (l10n.reportScoreLevelCritical, WrColors.destructive),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layer card
// ---------------------------------------------------------------------------

class _LayerCard extends StatelessWidget {
  const _LayerCard({
    required this.label,
    required this.score,
    required this.layer,
    required this.reportId,
    this.narrative,
    required this.localeCode,
  });
  final String label;
  final double score;
  final String layer; // 'STRUCTURE' | 'CULTURE' | 'ACTIVITY'
  final String reportId;
  final CcNarrative? narrative;
  final String localeCode;

  String? get _narrativeText {
    if (narrative == null) return null;
    if (localeCode == 'en' && narrative!.narrativeTextEn != null) {
      return narrative!.narrativeTextEn;
    }
    return narrative!.narrativeText;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: WrTextStyles.hMedium),
              Text(
                score.toStringAsFixed(1),
                style: WrTextStyles.hLarge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          WrProgressTrack(value: score / 5.0, color: WrColors.coral),
          if (_narrativeText != null) ...[
            const SizedBox(height: 10),
            Text(_narrativeText!, style: WrTextStyles.body),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(
                  '/survey/report/$reportId/layer/$layer'),
              child: Text(l10n.layerDetailViewDetail),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottleneck card (WrCardDark)
// ---------------------------------------------------------------------------

class _BottleneckCard extends StatelessWidget {
  const _BottleneckCard({
    required this.report,
    required this.l10n,
    this.narrative,
    required this.localeCode,
  });
  final CcReportFull report;
  final AppLocalizations l10n;
  final CcNarrative? narrative;
  final String localeCode;

  String _layerLabel(SurveyLayer layer) => switch (layer) {
        SurveyLayer.structure => l10n.reportLayerStructure,
        SurveyLayer.culture => l10n.reportLayerCulture,
        SurveyLayer.activity => l10n.reportLayerActivity,
        _ => '',
      };

  String? get _narrativeText {
    if (narrative == null) return null;
    if (localeCode == 'en' && narrative!.narrativeTextEn != null) {
      return narrative!.narrativeTextEn;
    }
    return narrative!.narrativeText;
  }

  @override
  Widget build(BuildContext context) {
    return WrCardDark(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reportBottleneckTitle.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.55, color: WrColors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 12),
          Text(
            _layerLabel(report.bottleneckLayer),
            style: WrTextStyles.hLarge.copyWith(color: WrColors.white),
          ),
          if (_narrativeText != null) ...[
            const SizedBox(height: 10),
            Text(
              _narrativeText!,
              style: WrTextStyles.body
                  .copyWith(color: WrColors.white.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ESI card (Premium)
// ---------------------------------------------------------------------------

class _EsiCard extends StatelessWidget {
  const _EsiCard({required this.report, required this.l10n});
  final CcReportFull report;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final esi = report.scoreEsi;
    if (esi == null) return const SizedBox.shrink();
    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(l10n.reportEsiTitle),
          const SizedBox(height: 12),
          Text(
            esi.toStringAsFixed(1),
            style: WrTextStyles.hLarge,
          ),
          const SizedBox(height: 8),
          WrProgressTrack(value: esi / 5.0, color: WrColors.teal),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  context.push('/survey/report/${report.id}/esi'),
              child: Text(l10n.layerDetailViewDetail),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// eNPS card (Premium)
// ---------------------------------------------------------------------------

class _EnpsCard extends StatelessWidget {
  const _EnpsCard({required this.report, required this.l10n});
  final CcReportFull report;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final enps = report.scoreEnps;
    if (enps == null) return const SizedBox.shrink();
    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(l10n.reportEnpsTitle),
          const SizedBox(height: 12),
          Text(
            '$enps',
            style: WrTextStyles.hLarge,
          ),
          const SizedBox(height: 8),
          if (report.enpsPromoters != null)
            Text(
              '${l10n.reportEnpsPromoter}: ${report.enpsPromoters} · '
              '${l10n.reportEnpsPassive}: ${report.enpsPassives ?? 0} · '
              '${l10n.reportEnpsDetractor}: ${report.enpsDetractors ?? 0}',
              style: WrTextStyles.body,
            )
          else
            Text(
              '${l10n.reportEnpsPromoter} · ${l10n.reportEnpsPassive} · ${l10n.reportEnpsDetractor}',
              style: WrTextStyles.body,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium upsell card (Free)
// ---------------------------------------------------------------------------

class _PremiumUpsellCard extends StatelessWidget {
  const _PremiumUpsellCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WrColors.cream,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(l10n.reportPremiumUpsell, style: WrTextStyles.body),
    );
  }
}

// ---------------------------------------------------------------------------
// SCA Radar Chart
// ---------------------------------------------------------------------------

/// CustomPainter that draws a 3-axis triangular radar chart for S-C-A scores.
/// Matches the web Premium.tsx radar geometry: Structure=top, Culture=bottom-right,
/// Activity=bottom-left. Scale 0–5. Grid at levels 1–5.
class _ScaRadarPainter extends CustomPainter {
  const _ScaRadarPainter({required this.data});

  final ScaChartData data;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // maxR: 40% of the shorter dimension, leaving room for labels.
    final maxR = math.min(size.width, size.height) * 0.40;

    // Axis angles: Structure=top (-π/2), Culture=bottom-right, Activity=bottom-left
    const angles = [
      -math.pi / 2,
      -math.pi / 2 + 2 * math.pi / 3,
      -math.pi / 2 + 4 * math.pi / 3,
    ];

    Offset axisPoint(int axis, double ratio) => Offset(
          cx + math.cos(angles[axis]) * maxR * ratio,
          cy + math.sin(angles[axis]) * maxR * ratio,
        );

    // --- Grid triangles (5 levels) ---
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFE5E5E5);

    for (int level = 1; level <= 5; level++) {
      final r = level / 5.0;
      final p0 = axisPoint(0, r);
      final p1 = axisPoint(1, r);
      final p2 = axisPoint(2, r);
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      gridPaint.strokeWidth = level == 5 ? 1.5 : 0.8;
      canvas.drawPath(path, gridPaint);
    }

    // --- Axis lines ---
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFE5E5E5);

    for (int i = 0; i < 3; i++) {
      final tip = axisPoint(i, 1.0);
      canvas.drawLine(Offset(cx, cy), tip, axisPaint);
    }

    // --- Data polygon ---
    final sP = axisPoint(0, data.structureRatio);
    final cP = axisPoint(1, data.cultureRatio);
    final aP = axisPoint(2, data.activityRatio);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = WrColors.coral.withValues(alpha: 0.15);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..color = WrColors.coral;

    final dataPath = Path()
      ..moveTo(sP.dx, sP.dy)
      ..lineTo(cP.dx, cP.dy)
      ..lineTo(aP.dx, aP.dy)
      ..close();

    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    // --- Data point circles ---
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = WrColors.coral;

    for (final pt in [sP, cP, aP]) {
      canvas.drawCircle(pt, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ScaRadarPainter old) => old.data != data;
}

// ---------------------------------------------------------------------------
// AI-personalized premium narrative section (Phase 5 Task 4)
// ---------------------------------------------------------------------------
// Mirrors web's usePersonalizedContent pattern:
//   1. Read cc_ai_personalization_cache (via provider).
//   2. On cache miss, call ai-personalize edge function.
//   3. On ANY error / EN locale → show static default narratives silently.
// All three sections (model, reflection, relationship) are fetched in parallel.
// ---------------------------------------------------------------------------

class _AiPersonalizedPremiumSection extends ConsumerWidget {
  const _AiPersonalizedPremiumSection({
    required this.report,
    required this.localeCode,
  });

  final CcReportFull report;
  final String localeCode;

  AiPersonalizationScoreContext _scoreContext() {
    final bottleneck = switch (report.bottleneckLayer) {
      SurveyLayer.structure => 'STRUCTURE',
      SurveyLayer.culture => 'CULTURE',
      SurveyLayer.activity => 'ACTIVITY',
      _ => 'STRUCTURE',
    };
    final scoreLevel = switch (report.scoreLevel) {
      ScoreLevel.high => 'HIGH',
      ScoreLevel.good => 'GOOD',
      ScoreLevel.warning => 'WARNING',
      ScoreLevel.critical => 'CRITICAL',
    };
    return AiPersonalizationScoreContext(
      structure: report.scoreStructure,
      culture: report.scoreCulture,
      activity: report.scoreActivity,
      total: report.scoreTotal,
      esi: report.scoreEsi ?? 0,
      bottleneck: bottleneck,
      scoreLevel: scoreLevel,
    );
  }

  // Minimal static defaults (plain strings — not localized here because the
  // AI section is VI-only; EN locale skips this widget entirely via provider).
  static const _defaultModel = <String, String>{
    'quote': '',
    'intro': '',
    'structure_desc': '',
    'culture_desc': '',
    'activity_desc': '',
  };

  static const _defaultReflection = <String, String>{
    'intro': '',
    'item1_desc': '',
    'item2_desc': '',
    'item3_desc': '',
    'pauses_intro': '',
    'pause1': '',
    'pause2': '',
    'pause3': '',
  };

  static const _defaultRelationship = <String, String>{
    'header_quote': '',
    'misconception_text': '',
    'misconception_quote': '',
    'asset1_desc': '',
    'asset2_desc': '',
    'asset3_desc': '',
    'asset4_desc': '',
    'asset5_desc': '',
    'closing_quote': '',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // EN locale → skip AI section entirely (matches web behavior).
    if (localeCode != 'vi') return const SizedBox.shrink();

    final userCtx = const AiPersonalizationUserContext();
    final scoreCtx = _scoreContext();

    final modelArgs = (
      reportId: report.id,
      section: 'model',
      userContext: userCtx,
      scoreContext: scoreCtx,
      defaultContent: _defaultModel,
      locale: localeCode,
    );
    final reflectionArgs = (
      reportId: report.id,
      section: 'reflection',
      userContext: userCtx,
      scoreContext: scoreCtx,
      defaultContent: _defaultReflection,
      locale: localeCode,
    );
    final relationshipArgs = (
      reportId: report.id,
      section: 'relationship',
      userContext: userCtx,
      scoreContext: scoreCtx,
      defaultContent: _defaultRelationship,
      locale: localeCode,
    );

    final modelAsync = ref.watch(aiPersonalizationProvider(modelArgs));
    final reflectionAsync = ref.watch(aiPersonalizationProvider(reflectionArgs));
    final relationshipAsync = ref.watch(aiPersonalizationProvider(relationshipArgs));

    // Show a single loading indicator while any section is still resolving.
    final anyLoading = modelAsync.isLoading ||
        reflectionAsync.isLoading ||
        relationshipAsync.isLoading;

    if (anyLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: WrColors.coral,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.reportAiPersonalizingLabel,
              style: WrTextStyles.body
                  .copyWith(color: WrColors.dark.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    // Extract data — null on error or EN locale (already guarded above).
    final modelData = modelAsync.valueOrNull;
    final reflectionData = reflectionAsync.valueOrNull;
    final relationshipData = relationshipAsync.valueOrNull;

    // If all three returned null (AI unavailable / all errors) → nothing to show.
    if (modelData == null && reflectionData == null && relationshipData == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (modelData != null) ...[
          _AiSectionCard(
            title: l10n.reportAiModelSectionTitle,
            content: _buildModelContent(modelData),
          ),
          const SizedBox(height: 16),
        ],
        if (reflectionData != null) ...[
          _AiSectionCard(
            title: l10n.reportAiReflectionSectionTitle,
            content: _buildReflectionContent(reflectionData),
          ),
          const SizedBox(height: 16),
        ],
        if (relationshipData != null) ...[
          _AiSectionCard(
            title: l10n.reportAiRelationshipSectionTitle,
            content: _buildRelationshipContent(relationshipData),
          ),
        ],
      ],
    );
  }

  List<String> _buildModelContent(Map<String, dynamic> data) {
    final c = AiModelContent.fromJson(data);
    return [
      if (c.quote.isNotEmpty) c.quote,
      if (c.intro.isNotEmpty) c.intro,
      if (c.structureDesc.isNotEmpty) c.structureDesc,
      if (c.cultureDesc.isNotEmpty) c.cultureDesc,
      if (c.activityDesc.isNotEmpty) c.activityDesc,
    ];
  }

  List<String> _buildReflectionContent(Map<String, dynamic> data) {
    final c = AiReflectionContent.fromJson(data);
    return [
      if (c.intro.isNotEmpty) c.intro,
      if (c.item1Desc.isNotEmpty) c.item1Desc,
      if (c.item2Desc.isNotEmpty) c.item2Desc,
      if (c.item3Desc.isNotEmpty) c.item3Desc,
      if (c.pausesIntro.isNotEmpty) c.pausesIntro,
      if (c.pause1.isNotEmpty) c.pause1,
      if (c.pause2.isNotEmpty) c.pause2,
      if (c.pause3.isNotEmpty) c.pause3,
    ];
  }

  List<String> _buildRelationshipContent(Map<String, dynamic> data) {
    final c = AiRelationshipContent.fromJson(data);
    return [
      if (c.headerQuote.isNotEmpty) c.headerQuote,
      if (c.misconceptionText.isNotEmpty) c.misconceptionText,
      if (c.misconceptionQuote.isNotEmpty) c.misconceptionQuote,
      if (c.asset1Desc.isNotEmpty) c.asset1Desc,
      if (c.asset2Desc.isNotEmpty) c.asset2Desc,
      if (c.asset3Desc.isNotEmpty) c.asset3Desc,
      if (c.asset4Desc.isNotEmpty) c.asset4Desc,
      if (c.asset5Desc.isNotEmpty) c.asset5Desc,
      if (c.closingQuote.isNotEmpty) c.closingQuote,
    ];
  }
}

/// Simple card that renders an AI section title + a list of text paragraphs.
class _AiSectionCard extends StatelessWidget {
  const _AiSectionCard({required this.title, required this.content});

  final String title;
  final List<String> content;

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();
    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(title),
          const SizedBox(height: 12),
          ...content.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(text, style: WrTextStyles.body),
            ),
          ),
        ],
      ),
    );
  }
}

/// Radar chart CustomPainter — draws a 3-axis triangular radar chart for S-C-A scores.
class ScaRadarChart extends StatelessWidget {
  const ScaRadarChart({
    super.key,
    required this.structure,
    required this.culture,
    required this.activity,
    required this.l10n,
  });

  final double structure;
  final double culture;
  final double activity;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final data = ScaChartData.fromScores(
      structure: structure,
      culture: culture,
      activity: activity,
    );

    if (!data.hasData) return const SizedBox.shrink();

    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(l10n.reportScaChartTitle),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  painter: _ScaRadarPainter(data: data),
                  size: const Size(double.infinity, 260),
                  child: const SizedBox.expand(),
                ),
                // Structure label: top center
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        l10n.reportLayerStructure,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WrColors.dark,
                        ),
                      ),
                      Text(
                        structure.toStringAsFixed(1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: WrColors.coral,
                        ),
                      ),
                    ],
                  ),
                ),
                // Culture label: bottom-right
                Positioned(
                  bottom: 4,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.reportLayerCulture,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WrColors.dark,
                        ),
                      ),
                      Text(
                        culture.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: WrColors.coral,
                        ),
                      ),
                    ],
                  ),
                ),
                // Activity label: bottom-left
                Positioned(
                  bottom: 4,
                  left: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reportLayerActivity,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WrColors.dark,
                        ),
                      ),
                      Text(
                        activity.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: WrColors.coral,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
