/// Maps to the public.wr_mobile_profiles table.
class MobileProfile {
  const MobileProfile({
    required this.userId,
    this.displayName,
    this.onboardingSituation,
    required this.reminderEnabled,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String? displayName;
  final String? onboardingSituation;
  final bool reminderEnabled;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MobileProfile.fromJson(Map<String, dynamic> json) {
    return MobileProfile(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      onboardingSituation: json['onboarding_situation'] as String?,
      reminderEnabled: json['reminder_enabled'] as bool,
      language: json['language'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  MobileProfile copyWith({
    String? displayName,
    String? onboardingSituation,
    bool? reminderEnabled,
    String? language,
    DateTime? updatedAt,
  }) {
    return MobileProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      onboardingSituation: onboardingSituation ?? this.onboardingSituation,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      language: language ?? this.language,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
