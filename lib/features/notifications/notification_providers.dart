// Notification providers — Phase 4 Task 4.
//
// notificationsProvider: AsyncNotifierProvider holding List<CcNotification>.
//   - loads from repository
//   - markRead / markAllRead do optimistic local updates (flip read_by),
//     then call repository; on failure roll back (same pattern as
//     CheckinNotifier and PracticesNotifier).
// unreadNotificationCountProvider: derived count (no RPC roundtrip required).
//
// currentUserIdProvider: thin wrapper over Supabase.instance so tests can
// override it without initializing Supabase (mirrors how repos are overridden).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/notification_repository.dart';
import '../../core/models/notification_model.dart';

// ---------------------------------------------------------------------------
// Current user ID provider (overridable in tests)
// ---------------------------------------------------------------------------

/// Returns the current authenticated user's ID, or '' if unauthenticated.
/// Override this provider in tests to avoid touching Supabase.instance.
final currentUserIdProvider = Provider<String>((ref) {
  return Supabase.instance.client.auth.currentUser?.id ?? '';
});

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NotificationsNotifier
    extends AsyncNotifier<List<CcNotification>> {
  NotificationRepository get _repo =>
      ref.read(notificationRepositoryProvider);

  String get _uid => ref.read(currentUserIdProvider);

  @override
  Future<List<CcNotification>> build() async {
    return _repo.getMyNotifications();
  }

  /// Optimistically marks one notification read; rolls back on error.
  Future<void> markRead(String notificationId) async {
    final uid = _uid;
    final prior = state;
    // Optimistic update — add uid to read_by locally
    state = AsyncData(
      (prior.valueOrNull ?? []).map((n) {
        if (n.id != notificationId) return n;
        return n.copyWith(readBy: [...(n.readBy ?? []), uid]);
      }).toList(),
    );

    try {
      await _repo.markRead(notificationId);
    } catch (_) {
      state = prior; // roll back
    }
  }

  /// Optimistically marks all notifications read; rolls back on error.
  Future<void> markAllRead() async {
    final uid = _uid;
    final prior = state;
    final current = prior.valueOrNull ?? [];
    // Optimistic update
    state = AsyncData(
      current.map((n) {
        if (n.isReadBy(uid)) return n;
        return n.copyWith(readBy: [...(n.readBy ?? []), uid]);
      }).toList(),
    );

    try {
      await _repo.markAllRead(current);
    } catch (_) {
      state = prior; // roll back
    }
  }

  /// Force-refresh from remote.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getMyNotifications());
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<CcNotification>>(
  NotificationsNotifier.new,
);

/// Derived provider: count of unread notifications for the current user.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? [];
  return notifications.where((n) => !n.isReadBy(uid)).length;
});
