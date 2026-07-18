// Notification repository — Phase 4 Task 4.
//
// Schema reality (web types.ts + useNotifications.ts):
//   cc_notifications columns: id, target_type, org_id, type, title,
//     description, icon, reference_id, reference_url, metadata, read_by, created_at.
//   NO user_id column. Rows are targeted to "admin" or "enterprise" audiences.
//   Read state: read_by string[] — updated via mark_notification_read(p_notification_id, p_user_id) RPC.
//
// Mobile users receive notifications inserted by the app (survey_completed, report_generated)
// with target_type='admin'. RLS may or may not expose those rows to regular users;
// we query without filter and surface whatever the DB returns. If RLS returns nothing,
// the user sees an empty inbox (graceful).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class NotificationRepository {
  /// Returns the current user's visible notifications, newest first.
  /// Limit 50.
  Future<List<CcNotification>> getMyNotifications();

  /// Marks a single notification as read by the current user.
  /// Uses the mark_notification_read(p_notification_id, p_user_id) RPC
  /// (same as web useMarkAsRead).
  Future<void> markRead(String notificationId);

  /// Marks all provided notifications as read by the current user.
  /// Parallel RPCs — same behaviour as web useMarkAllAsRead.
  Future<void> markAllRead(List<CcNotification> notifications);
}

// ---------------------------------------------------------------------------
// Riverpod provider (overridable in tests)
// ---------------------------------------------------------------------------

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Live Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseNotificationRepository implements NotificationRepository {
  const SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  @override
  Future<List<CcNotification>> getMyNotifications() async {
    final rows = await _client
        .from('cc_notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((r) => CcNotification.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _client.rpc('mark_notification_read', params: {
      'p_notification_id': notificationId,
      'p_user_id': _uid,
    });
  }

  @override
  Future<void> markAllRead(List<CcNotification> notifications) async {
    final uid = _uid;
    final unread = notifications.where((n) => !n.isReadBy(uid)).toList();
    if (unread.isEmpty) return;
    await Future.wait(
      unread.map(
        (n) => _client.rpc('mark_notification_read', params: {
          'p_notification_id': n.id,
          'p_user_id': uid,
        }),
      ),
    );
  }
}
