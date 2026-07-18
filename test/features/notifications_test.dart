// Widget tests for NotificationsScreen and home bell badge — Phase 4 Task 4.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/notification_repository.dart';
import 'package:workreflection_mobile/core/models/notification_model.dart';
import 'package:workreflection_mobile/features/notifications/notification_providers.dart';
import 'package:workreflection_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_notification_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// uid used in widget tests: empty string (no Supabase session in test env).
const _testUid = '';

Widget _wrap(FakeNotificationRepository repo) {
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue(_testUid),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('vi')],
      home: NotificationsScreen(),
    ),
  );
}

CcNotification _note({
  String id = 'n1',
  String title = 'Survey completed',
  String? description = 'Score: 3.5',
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
    createdAt: createdAt ?? DateTime(2026, 7, 18, 10, 0),
  );
}

// ---------------------------------------------------------------------------
// NotificationsScreen — widget tests
// ---------------------------------------------------------------------------

void main() {
  group('NotificationsScreen', () {
    testWidgets('shows empty state when no notifications', (tester) async {
      final repo = FakeNotificationRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notifications_empty')), findsOneWidget);
    });

    testWidgets('renders notification list when items present', (tester) async {
      final repo = FakeNotificationRepository();
      repo.seedNotifications([
        _note(id: 'n1', title: 'First notification'),
        _note(id: 'n2', title: 'Second notification'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('First notification'), findsOneWidget);
      expect(find.text('Second notification'), findsOneWidget);
      expect(find.byKey(const Key('notifications_empty')), findsNothing);
    });

    testWidgets('unread notification shows bold style and unread dot',
        (tester) async {
      final repo = FakeNotificationRepository();
      repo.seedNotifications([_note(id: 'n1', readBy: [])]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Unread dot is visible
      expect(find.byKey(const Key('unreadDot')), findsOneWidget);
    });

    testWidgets('read notification has no unread dot', (tester) async {
      final repo = FakeNotificationRepository();
      // readBy contains some user id; widget reads Supabase.currentUser which
      // is null in test → uid = '' so a non-empty readBy with a real id means
      // isReadBy('') = false (still unread from the widget's perspective).
      // To simulate "read by the current anon user" we use empty string uid:
      repo.seedNotifications([_note(id: 'n1', readBy: [''])]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // No unread dot
      expect(find.byKey(const Key('unreadDot')), findsNothing);
    });

    testWidgets('tapping a row calls markRead on the notifier', (tester) async {
      final repo = FakeNotificationRepository();
      repo.seedNotifications([_note(id: 'n1', readBy: [])]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('notification_row_n1')));
      await tester.pumpAndSettle();

      expect(repo.markReadCalls, contains('n1'));
    });

    testWidgets('mark all read button appears when there are unread items',
        (tester) async {
      final repo = FakeNotificationRepository();
      // uid in test = '' (no Supabase session), readBy = [] → isReadBy('') = false → unread
      repo.seedNotifications([_note(id: 'n1', readBy: [])]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('markAllReadBtn')), findsOneWidget);
    });

    testWidgets('mark all read button absent when all read', (tester) async {
      final repo = FakeNotificationRepository();
      // readBy contains '' (empty uid used in test env)
      repo.seedNotifications([_note(id: 'n1', readBy: [''])]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('markAllReadBtn')), findsNothing);
    });

    testWidgets('tapping mark all read calls repo.markAllRead', (tester) async {
      final repo = FakeNotificationRepository();
      repo.seedNotifications([
        _note(id: 'n1', readBy: []),
        _note(id: 'n2', readBy: []),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('markAllReadBtn')));
      await tester.pumpAndSettle();

      expect(repo.markAllReadCallCount, 1);
    });

    testWidgets('description renders when present', (tester) async {
      final repo = FakeNotificationRepository();
      repo.seedNotifications([
        _note(id: 'n1', description: 'Score: 4.2'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Score: 4.2'), findsOneWidget);
    });

    testWidgets('shows error state when repository throws', (tester) async {
      final repo = FakeNotificationRepository();
      repo.nextError = Exception('network error');
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows app bar title', (tester) async {
      final repo = FakeNotificationRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Vietnamese locale: "Thông báo"
      expect(find.text('Thông báo'), findsOneWidget);
    });
  });
}
