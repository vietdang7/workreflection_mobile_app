// Unit tests for FakeNotificationRepository and NotificationsNotifier
// — Phase 4 Task 4.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/notification_repository.dart';
import 'package:workreflection_mobile/core/models/notification_model.dart';
import 'package:workreflection_mobile/features/notifications/notification_providers.dart';

import '../support/fake_notification_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CcNotification _makeNotification({
  String id = 'n1',
  String title = 'Test Title',
  String? description,
  List<String>? readBy,
  DateTime? createdAt,
}) {
  return CcNotification(
    id: id,
    targetType: 'admin',
    type: 'survey_completed',
    title: title,
    description: description,
    readBy: readBy,
    createdAt: createdAt ?? DateTime(2026, 7, 18),
  );
}

ProviderContainer _container(FakeNotificationRepository repo,
    {String uid = 'fake-user'}) {
  return ProviderContainer(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue(uid),
    ],
  );
}

// ---------------------------------------------------------------------------
// FakeNotificationRepository contracts
// ---------------------------------------------------------------------------

void main() {
  group('FakeNotificationRepository', () {
    test('getMyNotifications returns seeded items', () async {
      final repo = FakeNotificationRepository();
      repo.seedNotifications([
        _makeNotification(id: 'n1'),
        _makeNotification(id: 'n2'),
      ]);
      final result = await repo.getMyNotifications();
      expect(result.length, 2);
      expect(result.map((n) => n.id), containsAll(['n1', 'n2']));
    });

    test('getMyNotifications returns empty list by default', () async {
      final repo = FakeNotificationRepository();
      final result = await repo.getMyNotifications();
      expect(result, isEmpty);
    });

    test('markRead records call and updates read_by', () async {
      final repo = FakeNotificationRepository();
      repo.seedNotifications([_makeNotification(id: 'n1', readBy: [])]);

      await repo.markRead('n1');

      expect(repo.markReadCalls, ['n1']);
      final updated = await repo.getMyNotifications();
      expect(updated.first.isReadBy('fake-user'), isTrue);
    });

    test('markAllRead updates all unread', () async {
      final repo = FakeNotificationRepository();
      final items = [
        _makeNotification(id: 'n1', readBy: []),
        _makeNotification(id: 'n2', readBy: ['fake-user']), // already read
        _makeNotification(id: 'n3', readBy: []),
      ];
      repo.seedNotifications(items);

      await repo.markAllRead(items);

      expect(repo.markAllReadCallCount, 1);
      final updated = await repo.getMyNotifications();
      expect(updated.every((n) => n.isReadBy('fake-user')), isTrue);
    });

    test('nextError throws once then clears', () async {
      final repo = FakeNotificationRepository();
      repo.nextError = Exception('forced error');

      expect(() => repo.getMyNotifications(), throwsException);
      expect(() => repo.getMyNotifications(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // CcNotification.isReadBy
  // ---------------------------------------------------------------------------

  group('CcNotification.isReadBy', () {
    test('returns false when readBy is null', () {
      final n = _makeNotification(readBy: null);
      expect(n.isReadBy('user-1'), isFalse);
    });

    test('returns false when user not in readBy', () {
      final n = _makeNotification(readBy: ['other-user']);
      expect(n.isReadBy('user-1'), isFalse);
    });

    test('returns true when user is in readBy', () {
      final n = _makeNotification(readBy: ['user-1', 'user-2']);
      expect(n.isReadBy('user-1'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // CcNotification.fromJson
  // ---------------------------------------------------------------------------

  group('CcNotification.fromJson', () {
    test('parses full row correctly', () {
      final json = {
        'id': 'abc',
        'target_type': 'admin',
        'org_id': null,
        'type': 'survey_completed',
        'title': 'My Title',
        'description': 'Some desc',
        'icon': 'survey',
        'reference_id': 'ref-1',
        'reference_url': '/admin/reports',
        'read_by': ['u1', 'u2'],
        'created_at': '2026-07-18T10:00:00.000Z',
      };
      final n = CcNotification.fromJson(json);
      expect(n.id, 'abc');
      expect(n.targetType, 'admin');
      expect(n.type, 'survey_completed');
      expect(n.title, 'My Title');
      expect(n.description, 'Some desc');
      expect(n.readBy, ['u1', 'u2']);
      expect(n.createdAt, isNotNull);
      expect(n.isReadBy('u1'), isTrue);
      expect(n.isReadBy('u3'), isFalse);
    });

    test('handles null optional fields', () {
      final json = {
        'id': 'xyz',
        'target_type': 'enterprise',
        'type': 'member_joined',
        'title': 'Member joined',
        'description': null,
        'icon': null,
        'org_id': null,
        'reference_id': null,
        'reference_url': null,
        'read_by': null,
        'created_at': null,
      };
      final n = CcNotification.fromJson(json);
      expect(n.id, 'xyz');
      expect(n.description, isNull);
      expect(n.readBy, isNull);
      expect(n.createdAt, isNull);
      expect(n.isReadBy('anyone'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // NotificationsNotifier — provider tests
  // ---------------------------------------------------------------------------

  group('NotificationsNotifier', () {
    test('loads notifications from repository', () async {
      final repo = FakeNotificationRepository();
      repo.seedNotifications([
        _makeNotification(id: 'n1'),
        _makeNotification(id: 'n2'),
      ]);
      final container = _container(repo);
      addTearDown(container.dispose);

      final result = await container.read(notificationsProvider.future);
      expect(result.length, 2);
    });

    test('markRead optimistically marks as read then calls repo', () async {
      final repo = FakeNotificationRepository();
      repo.seedNotifications([_makeNotification(id: 'n1', readBy: [])]);
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(notificationsProvider.future);
      await container.read(notificationsProvider.notifier).markRead('n1');

      // repo was called
      expect(repo.markReadCalls, contains('n1'));
    });

    test('markAllRead calls repo.markAllRead', () async {
      final repo = FakeNotificationRepository();
      repo.seedNotifications([
        _makeNotification(id: 'n1', readBy: []),
        _makeNotification(id: 'n2', readBy: []),
      ]);
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(notificationsProvider.future);
      await container.read(notificationsProvider.notifier).markAllRead();

      expect(repo.markAllReadCallCount, 1);
    });

    test('unreadNotificationCountProvider returns 0 when empty', () async {
      final repo = FakeNotificationRepository();
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(notificationsProvider.future);
      final count = container.read(unreadNotificationCountProvider);
      expect(count, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Failing markRead rolls back
  // ---------------------------------------------------------------------------

  group('NotificationsNotifier — rollback on markRead failure', () {
    test('rolls back optimistic state when markRead throws', () async {
      final repo = _FailingMarkReadRepo();
      repo.seedNotifications([_makeNotification(id: 'n1', readBy: [])]);
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(notificationsProvider.future);

      // Before: unread
      final before = container.read(notificationsProvider).valueOrNull!;
      expect(before.first.isReadBy('fake-user'), isFalse);

      await container.read(notificationsProvider.notifier).markRead('n1');

      // After failure: rolled back to unread
      final afterState = container.read(notificationsProvider);
      expect(afterState.hasError, isFalse);
      final after = afterState.valueOrNull!;
      expect(after.first.isReadBy('fake-user'), isFalse,
          reason: 'must roll back to prior unread state');
    });
  });
}

// ---------------------------------------------------------------------------
// Helper: repo that always throws on markRead
// ---------------------------------------------------------------------------

class _FailingMarkReadRepo extends FakeNotificationRepository {
  @override
  Future<void> markRead(String notificationId) async {
    throw Exception('network error');
  }
}
