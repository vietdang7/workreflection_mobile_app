/// Maps to the public.wr_development_themes table.
class DevelopmentTheme {
  const DevelopmentTheme({
    required this.id,
    required this.userId,
    required this.code,
    required this.title,
    this.subtitle,
    required this.stage,
    required this.totalStages,
    required this.progress,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String code;
  final String title;
  final String? subtitle;
  final int stage;
  final int totalStages;

  /// 0.0 – 1.0; Supabase numeric may come as int or double.
  final double progress;
  final bool isActive;
  final DateTime createdAt;

  factory DevelopmentTheme.fromJson(Map<String, dynamic> json) {
    return DevelopmentTheme(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      stage: json['stage'] as int,
      totalStages: json['total_stages'] as int,
      // Supabase numeric columns may deserialize as int or double.
      progress: (json['progress'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
