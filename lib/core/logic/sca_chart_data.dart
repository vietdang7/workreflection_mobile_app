// Pure data-mapping helper for the SCA radar chart.
// No Flutter/Supabase dependencies — fully unit-testable.

const _kMaxScore = 5.0;

/// Holds the normalized (0.0–1.0) ratios for each S-C-A axis,
/// computed from raw 0–5 scores.
class ScaChartData {
  const ScaChartData({
    required this.structureRatio,
    required this.cultureRatio,
    required this.activityRatio,
  });

  final double structureRatio;
  final double cultureRatio;
  final double activityRatio;

  /// Returns true when at least one score is non-zero (data worth rendering).
  bool get hasData =>
      structureRatio > 0 || cultureRatio > 0 || activityRatio > 0;

  factory ScaChartData.fromScores({
    required double structure,
    required double culture,
    required double activity,
  }) {
    double clamp(double v) => (v / _kMaxScore).clamp(0.0, 1.0);
    return ScaChartData(
      structureRatio: clamp(structure),
      cultureRatio: clamp(culture),
      activityRatio: clamp(activity),
    );
  }
}
