import '../logic/wr_career_profile.dart';

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
    this.careerSnapshot = const CareerSnapshot(),
  });

  final String userId;
  final String? displayName;
  final String? onboardingSituation;
  final bool reminderEnabled;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Career Snapshot (vai trò · mục tiêu · trăn trở). Rỗng khi người dùng
  /// chưa thiết lập hồ sơ.
  final CareerSnapshot careerSnapshot;

  factory MobileProfile.fromJson(Map<String, dynamic> json) {
    return MobileProfile(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      onboardingSituation: json['onboarding_situation'] as String?,
      reminderEnabled: json['reminder_enabled'] as bool,
      language: json['language'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      careerSnapshot: CareerSnapshot.fromJson(json),
    );
  }

  MobileProfile copyWith({
    String? displayName,
    String? onboardingSituation,
    bool? reminderEnabled,
    String? language,
    DateTime? updatedAt,
    CareerSnapshot? careerSnapshot,
  }) {
    return MobileProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      onboardingSituation: onboardingSituation ?? this.onboardingSituation,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      language: language ?? this.language,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      careerSnapshot: careerSnapshot ?? this.careerSnapshot,
    );
  }
}
