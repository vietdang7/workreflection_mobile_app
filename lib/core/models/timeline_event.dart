/// Event type enum matching wr_timeline_events.event_type check constraint.
enum TimelineEventType {
  milestone,
  story,
  theme;

  String get dbValue => name.toUpperCase(); // 'MILESTONE' | 'STORY' | 'THEME'

  static TimelineEventType fromDb(String value) {
    return switch (value) {
      'MILESTONE' => TimelineEventType.milestone,
      'STORY' => TimelineEventType.story,
      'THEME' => TimelineEventType.theme,
      _ => throw ArgumentError('Unknown timeline event type: $value'),
    };
  }
}

/// Maps to the public.wr_timeline_events table.
class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.title,
    this.description,
    required this.occurredAt,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final TimelineEventType eventType;
  final String title;
  final String? description;

  /// The calendar date the event occurred (time component stripped).
  final DateTime occurredAt;
  final DateTime createdAt;

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventType: TimelineEventType.fromDb(json['event_type'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
