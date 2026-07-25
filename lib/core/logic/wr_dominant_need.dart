// Shared helpers for computing the dominant HumanNeed from behaviour or SCA self-check.
// Used by WrDiscoverScreen and WrGrowthScreen.
// Pure Dart — no Flutter dependencies.

import '../models/wr_content.dart';
import '../models/wr_intelligence.dart';

// ---------------------------------------------------------------------------
// dominantNeedFromBehaviour
// ---------------------------------------------------------------------------

/// Compute dominant [HumanNeed] from pattern counts + situation list.
/// Sums occurrenceCount per HumanNeed; need with highest total = nhu cầu chủ đạo.
/// Returns null when [patterns] is empty or no situation has a humanNeed.
HumanNeed? dominantNeedFromBehaviour(
  List<PatternCount> patterns,
  List<WrSituation> situations,
) {
  if (patterns.isEmpty) return null;
  final codeToNeed = <String, HumanNeed>{
    for (final s in situations)
      if (s.humanNeed != null) s.code: s.humanNeed!,
  };
  final tally = <HumanNeed, int>{};
  for (final p in patterns) {
    final code = p.situationCode;
    if (code == null) continue;
    final need = codeToNeed[code];
    if (need == null) continue;
    tally[need] = (tally[need] ?? 0) + p.occurrenceCount;
  }
  if (tally.isEmpty) return null;
  return tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

// ---------------------------------------------------------------------------
// dominantNeedFromSelfCheck
// ---------------------------------------------------------------------------

/// Map SCA lowest pillar → HumanNeed (fallback when no patterns yet).
/// S → roRang, C → ketNoi, A → phatTrien.
/// Tie-break: C > S > A.
/// Null scores treated as 5.0 (no problem in that pillar).
HumanNeed dominantNeedFromSelfCheck(ScaSelfCheckResponse r) {
  final s = r.structureScore ?? 5.0;
  final c = r.cultureScore ?? 5.0;
  final a = r.activityScore ?? 5.0;
  final minScore = [s, c, a].reduce((a, b) => a < b ? a : b);
  // Tie-break: C > S > A (C wins if tied)
  if (c == minScore) return HumanNeed.ketNoi;
  if (s == minScore) return HumanNeed.roRang;
  return HumanNeed.phatTrien;
}

// ---------------------------------------------------------------------------
// needPillarLetter
// ---------------------------------------------------------------------------

/// Returns the SCA pillar letter for matching [PracticeTheme.scaDimension.dbValue].
/// roRang → 'S', ketNoi → 'C', thichNghi → 'A', phatTrien → 'A'.
String needPillarLetter(HumanNeed need) => switch (need) {
      HumanNeed.roRang => 'S',
      HumanNeed.ketNoi => 'C',
      HumanNeed.thichNghi => 'A',
      HumanNeed.phatTrien => 'A',
    };

// ---------------------------------------------------------------------------
// needSeekingLabel
// ---------------------------------------------------------------------------

/// Vietnamese label for what the user is seeking, used in suggestion card reason.
String needSeekingLabel(HumanNeed need) => switch (need) {
      HumanNeed.roRang => 'sự rõ ràng',
      HumanNeed.ketNoi => 'sự kết nối',
      HumanNeed.thichNghi => 'sự thích nghi',
      HumanNeed.phatTrien => 'sự phát triển',
    };
