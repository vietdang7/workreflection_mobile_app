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
    this.recentSituationIds = const [],
    this.roleText,
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

  /// Mã tình huống đã chọn gần đây, mới nhất đứng đầu, tối đa 30.
  ///
  /// Kiến trúc Dữ liệu v1.6 §4.1 + §XII.2: lưu theo Person chứ không theo phiên,
  /// để xoay vòng chống lặp còn hoạt động qua nhiều ngày và nhiều thiết bị.
  final List<String> recentSituationIds;

  /// Mô tả tự do về vai trò hiện tại (§11.3).
  ///
  /// Khác [CareerSnapshot.currentRole] vốn là một trong sáu lựa chọn cứng:
  /// trường này chứa được "phụ trách mảng B2C, quản lý một nhóm 4 người" —
  /// chính loại chi tiết làm Cơ hội phát triển bám sát công việc thật.
  /// Hoàn toàn tùy chọn.
  final String? roleText;

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
      recentSituationIds:
          (json['recent_situation_ids'] as List?)?.cast<String>() ?? const [],
      roleText: json['role_text'] as String?,
    );
  }

  MobileProfile copyWith({
    String? displayName,
    String? onboardingSituation,
    bool? reminderEnabled,
    String? language,
    DateTime? updatedAt,
    CareerSnapshot? careerSnapshot,
    List<String>? recentSituationIds,
    String? roleText,
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
      recentSituationIds: recentSituationIds ?? this.recentSituationIds,
      roleText: roleText ?? this.roleText,
    );
  }
}
