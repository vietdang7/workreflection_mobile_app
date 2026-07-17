/// Mood enum matching the wr_checkins.mood check constraint in the migration.
enum Mood {
  stressed,
  tired,
  okay,
  happy;

  String get dbValue => name; // 'stressed' | 'tired' | 'okay' | 'happy'

  static Mood fromDb(String value) {
    return switch (value) {
      'stressed' => Mood.stressed,
      'tired' => Mood.tired,
      'okay' => Mood.okay,
      'happy' => Mood.happy,
      _ => throw ArgumentError('Unknown mood db value: $value'),
    };
  }
}

/// Maps to the public.wr_checkins table.
class Checkin {
  const Checkin({
    required this.id,
    required this.userId,
    required this.mood,
    required this.checkinDate,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final Mood mood;

  /// The calendar date of the check-in (time component stripped).
  final DateTime checkinDate;
  final DateTime createdAt;

  factory Checkin.fromJson(Map<String, dynamic> json) {
    return Checkin(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mood: Mood.fromDb(json['mood'] as String),
      checkinDate: DateTime.parse(json['checkin_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
