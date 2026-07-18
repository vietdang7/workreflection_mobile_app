// Notification model — Phase 4 Task 4.
// Maps to public.cc_notifications (source of truth: web types.ts + useNotifications.ts).
// NOTE: the table has NO user_id column. Rows are targeted by target_type
// ("admin" | "enterprise") and org_id. Read state is tracked via read_by: string[].

/// Immutable. No Flutter dependencies.
class CcNotification {
  const CcNotification({
    required this.id,
    required this.targetType,
    this.orgId,
    required this.type,
    required this.title,
    this.description,
    this.icon,
    this.referenceId,
    this.referenceUrl,
    this.readBy,
    this.createdAt,
  });

  final String id;

  /// "admin" | "enterprise"
  final String targetType;
  final String? orgId;

  /// e.g. "survey_completed", "report_generated", "new_order", …
  final String type;
  final String title;
  final String? description;
  final String? icon;
  final String? referenceId;
  final String? referenceUrl;

  /// Array of user IDs who have read this notification (nullable in DB).
  final List<String>? readBy;

  final DateTime? createdAt;

  /// Returns true if [userId] has read this notification.
  bool isReadBy(String userId) => (readBy ?? []).contains(userId);

  factory CcNotification.fromJson(Map<String, dynamic> json) {
    final readByRaw = json['read_by'];
    final List<String>? parsedReadBy;
    if (readByRaw == null) {
      parsedReadBy = null;
    } else {
      parsedReadBy = (readByRaw as List).cast<String>();
    }

    final createdAtRaw = json['created_at'];

    return CcNotification(
      id: json['id'] as String,
      targetType: json['target_type'] as String,
      orgId: json['org_id'] as String?,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      referenceId: json['reference_id'] as String?,
      referenceUrl: json['reference_url'] as String?,
      readBy: parsedReadBy,
      createdAt: createdAtRaw != null
          ? DateTime.parse(createdAtRaw as String)
          : null,
    );
  }

  CcNotification copyWith({List<String>? readBy}) {
    return CcNotification(
      id: id,
      targetType: targetType,
      orgId: orgId,
      type: type,
      title: title,
      description: description,
      icon: icon,
      referenceId: referenceId,
      referenceUrl: referenceUrl,
      readBy: readBy ?? this.readBy,
      createdAt: createdAt,
    );
  }
}
