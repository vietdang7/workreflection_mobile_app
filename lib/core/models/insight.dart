/// Maps to the public.wr_insights table.
class Insight {
  const Insight({
    required this.id,
    required this.userId,
    required this.content,
    this.source,
    required this.savedAt,
  });

  final String id;
  final String userId;
  final String content;

  /// Nullable — e.g. 'VOICE', or null when not from a specific source.
  final String? source;
  final DateTime savedAt;

  factory Insight.fromJson(Map<String, dynamic> json) {
    return Insight(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      source: json['source'] as String?,
      savedAt: DateTime.parse(json['saved_at'] as String),
    );
  }
}
