// Fake NotificationRepository for tests — Phase 4 Task 4.

import 'package:workreflection_mobile/core/data/notification_repository.dart';
import 'package:workreflection_mobile/core/models/notification_model.dart';

class FakeNotificationRepository implements NotificationRepository {
  final List<CcNotification> _notifications = [];
  final List<String> markReadCalls = [];
  int markAllReadCallCount = 0;
  Exception? nextError;

  // --- Seed helpers ---

  void seedNotifications(List<CcNotification> items) {
    _notifications
      ..clear()
      ..addAll(items);
  }

  // --- NotificationRepository impl ---

  @override
  Future<List<CcNotification>> getMyNotifications() async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    return List.unmodifiable(_notifications);
  }

  @override
  Future<void> markRead(String notificationId) async {
    markReadCalls.add(notificationId);
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      final n = _notifications[idx];
      final existing = n.readBy ?? [];
      if (!existing.contains('fake-user')) {
        _notifications[idx] = n.copyWith(readBy: [...existing, 'fake-user']);
      }
    }
  }

  @override
  Future<void> markAllRead(List<CcNotification> notifications) async {
    markAllReadCallCount++;
    for (final n in notifications) {
      final idx = _notifications.indexWhere((x) => x.id == n.id);
      if (idx != -1) {
        final existing = _notifications[idx].readBy ?? [];
        if (!existing.contains('fake-user')) {
          _notifications[idx] = _notifications[idx]
              .copyWith(readBy: [...existing, 'fake-user']);
        }
      }
    }
  }
}
