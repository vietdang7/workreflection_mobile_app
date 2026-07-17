/// Maps to the public.wr_recurring_situations table.
class RecurringSituation {
  const RecurringSituation({
    required this.id,
    required this.userId,
    required this.label,
    required this.occurrenceCount,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String label;
  final int occurrenceCount;
  final DateTime updatedAt;

  factory RecurringSituation.fromJson(Map<String, dynamic> json) {
    return RecurringSituation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: json['label'] as String,
      occurrenceCount: json['occurrence_count'] as int,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
