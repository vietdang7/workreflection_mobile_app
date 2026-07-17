/// Maps to the public.cc_reports table.
/// Columns: id, user_id, score_structure, score_culture, score_activity (numeric), created_at.
class ScaReport {
  const ScaReport({
    required this.id,
    required this.userId,
    required this.scoreStructure,
    required this.scoreCulture,
    required this.scoreActivity,
    required this.createdAt,
  });

  final String id;
  final String userId;

  /// Numeric 0–5 from cc_reports.score_structure
  final double scoreStructure;

  /// Numeric 0–5 from cc_reports.score_culture
  final double scoreCulture;

  /// Numeric 0–5 from cc_reports.score_activity
  final double scoreActivity;

  final DateTime createdAt;

  factory ScaReport.fromJson(Map<String, dynamic> json) {
    return ScaReport(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      // Supabase numeric columns may come as int or double.
      scoreStructure: (json['score_structure'] as num).toDouble(),
      scoreCulture: (json['score_culture'] as num).toDouble(),
      scoreActivity: (json['score_activity'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
