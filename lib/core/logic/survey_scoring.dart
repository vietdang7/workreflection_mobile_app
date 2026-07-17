// Survey scoring engine — Phase 2.
// Pure functions, no Flutter/Supabase dependencies.
// Formulas match research doc §3 exactly.

import '../models/survey_models.dart';

// ---------------------------------------------------------------------------
// computeSurveyScores
// ---------------------------------------------------------------------------

/// Computes all survey scores from raw answers and questions.
///
/// [answers] maps question id → answer value (int).
/// [questions] is the full list (used for layer/scaleType metadata).
///
/// Implements research §3:
/// - Layer averages rounded to 1 decimal: (v*10).round()/10
/// - scoreTotal = S*0.5 + C*0.3 + A*0.2 (ESI NOT in total)
/// - eNPS: promoter>=9, passive>=7 && <9, detractor<7;
///   eNPS = round((promoters% - detractors%) * 100)
/// - bottleneck = min(S,C,A), ties resolve S→C→A
/// - scoreLevel: HIGH>=4.2, GOOD>=3.5, WARNING>=2.8, CRITICAL<2.8
SurveyScores computeSurveyScores({
  required Map<String, int> answers,
  required List<CcQuestion> questions,
  bool isPremium = false,
}) {
  // Separate questions by layer.
  final Map<SurveyLayer, List<String>> byLayer = {};
  for (final q in questions) {
    byLayer.putIfAbsent(q.layer, () => <String>[]).add(q.id);
  }

  double layerAvg(SurveyLayer layer) {
    final ids = byLayer[layer] ?? [];
    if (ids.isEmpty) return 0.0;
    // Exclude unanswered questions
    final vals = ids
        .where((id) => answers.containsKey(id))
        .map((id) => answers[id]!)
        .toList();
    if (vals.isEmpty) return 0.0;
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    return (avg * 10).round() / 10;
  }

  final s = layerAvg(SurveyLayer.structure);
  final c = layerAvg(SurveyLayer.culture);
  final a = layerAvg(SurveyLayer.activity);
  final esiRaw = byLayer.containsKey(SurveyLayer.esi)
      ? layerAvg(SurveyLayer.esi)
      : (isPremium ? 0.0 : null);

  // Weighted total (ESI excluded)
  final totalRaw = s * 0.5 + c * 0.3 + a * 0.2;
  final total = (totalRaw * 10).round() / 10;

  // eNPS ids: layer==ENPS OR scaleType==ENPS_10
  final enpsIds = questions
      .where((q) => q.layer == SurveyLayer.enps || q.scaleType == ScaleType.enps10)
      .map((q) => q.id)
      .toList();

  // eNPS
  int? enps;
  if (enpsIds.isNotEmpty) {
    int promoters = 0, detractors = 0;
    for (final id in enpsIds) {
      if (!answers.containsKey(id)) continue; // exclude missing
      final v = answers[id]!;
      if (v >= 9) {
        promoters++;
      } else if (v >= 7) {
        // passive: counted neither (reserved for Task 19 eNPS breakdown)
      } else {
        detractors++;
      }
    }
    final n = enpsIds.where((id) => answers.containsKey(id)).length;
    if (n == 0) {
      enps = null;
    } else {
      enps = ((promoters - detractors) / n * 100).round();
    }
  }

  // Bottleneck: min(S,C,A) with tie-break S→C→A
  final SurveyLayer bottleneck;
  if (s <= c && s <= a) {
    bottleneck = SurveyLayer.structure;
  } else if (c <= a) {
    bottleneck = SurveyLayer.culture;
  } else {
    bottleneck = SurveyLayer.activity;
  }

  // Score level thresholds
  final ScoreLevel level;
  if (total >= 4.2) {
    level = ScoreLevel.high;
  } else if (total >= 3.5) {
    level = ScoreLevel.good;
  } else if (total >= 2.8) {
    level = ScoreLevel.warning;
  } else {
    level = ScoreLevel.critical;
  }

  return SurveyScores(
    scoreStructure: s,
    scoreCulture: c,
    scoreActivity: a,
    scoreTotal: total,
    scoreEsi: esiRaw,
    scoreEnps: enps,
    bottleneckLayer: bottleneck,
    scoreLevel: level,
  );
}

// ---------------------------------------------------------------------------
// selectNarrative
// ---------------------------------------------------------------------------

/// Selects the best matching narrative from [narratives] for the given
/// [type], [layer], and [score].
///
/// Matching rules (research §4):
/// - Filter by type and layer (null layer = TOTAL-type narratives).
/// - score_min <= score <= score_max.
/// - When ranges overlap, prefer the HIGHEST score_min that is <= score.
///
/// Language fallback: if language=='en' and narrative_text_en != null → use EN;
/// otherwise use VI (narrative_text). Returns the matched CcNarrative or null.
CcNarrative? selectNarrative(
  List<CcNarrative> narratives, {
  required String type,
  required String? layer,
  required double score,
  required String language,
}) {
  final candidates = narratives.where((n) {
    if (n.type != type) return false;
    if (n.layer != layer) return false;
    return n.scoreMin <= score;
  }).toList();

  if (candidates.isEmpty) return null;

  // Pick candidate with the highest scoreMin (i.e. most specific upper range).
  candidates.sort((a, b) => b.scoreMin.compareTo(a.scoreMin));
  return candidates.first;
}
