/// Status enum matching wr_practices.status check constraint.
enum PracticeStatus {
  todo,
  doing,
  done;

  String get dbValue => name; // 'todo' | 'doing' | 'done'

  static PracticeStatus fromDb(String value) {
    return switch (value) {
      'todo' => PracticeStatus.todo,
      'doing' => PracticeStatus.doing,
      'done' => PracticeStatus.done,
      _ => throw ArgumentError('Unknown practice status: $value'),
    };
  }
}

/// Maps to the public.wr_practices table.
class Practice {
  const Practice({
    required this.id,
    required this.userId,
    this.themeId,
    required this.title,
    required this.status,
    required this.practiceDate,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? themeId;
  final String title;
  final PracticeStatus status;
  final DateTime practiceDate;
  final DateTime? completedAt;
  final DateTime createdAt;

  factory Practice.fromJson(Map<String, dynamic> json) {
    return Practice(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      themeId: json['theme_id'] as String?,
      title: json['title'] as String,
      status: PracticeStatus.fromDb(json['status'] as String),
      practiceDate: DateTime.parse(json['practice_date'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Practice copyWith({PracticeStatus? status, DateTime? completedAt}) {
    return Practice(
      id: id,
      userId: userId,
      themeId: themeId,
      title: title,
      status: status ?? this.status,
      practiceDate: practiceDate,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
    );
  }
}
