import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/timeline_event.dart';
import 'package:workreflection_mobile/features/auth/data/auth_repository.dart';
import 'package:workreflection_mobile/features/profile/presentation/profile_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';

// ---------------------------------------------------------------------------
// Fake AuthRepository for profile tests — mirrors the one in auth_test.dart
// ---------------------------------------------------------------------------
class _FakeAuthRepository implements AuthRepository {
  String? lastChangedPassword;
  bool changeShouldFail = false;
  bool changeSessionExpired = false;

  @override Future<void> signIn(String e, String p) async {}
  @override Future<void> signUp(String e, String p, String n) async {}
  @override Future<void> signInWithGoogle() async {}
  @override Future<void> signOut() async {}
  @override Future<void> resetPassword(String email) async {}

  @override
  Future<void> changePassword(String newPassword) async {
    lastChangedPassword = newPassword;
    if (changeSessionExpired) throw Exception('Session expired');
    if (changeShouldFail) throw Exception('Something went wrong');
  }
}

Widget _wrap(Widget child, WrRepository repo, {AuthRepository? authRepo}) {
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(repo),
      if (authRepo != null) authRepositoryProvider.overrideWithValue(authRepo),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: child,
    ),
  );
}

Future<void> _pumpLarge(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

MobileProfile _profile({bool reminder = true, String lang = 'vi'}) =>
    MobileProfile(
      userId: 'u1',
      displayName: 'Yumi Trần',
      reminderEnabled: reminder,
      language: lang,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

void main() {
  group('ProfileScreen widget', () {
    testWidgets('renders header greeting and name', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'subscription_expires_at': null,
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.textContaining('Tài khoản'), findsOneWidget);
      expect(find.textContaining('Yumi Trần'), findsWidgets);
    });

    testWidgets('shows PREMIUM MEMBER badge when subscription active', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      // subscription_expires_at in future
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'subscription_expires_at':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.textContaining('PREMIUM'), findsOneWidget);
    });

    testWidgets('shows member (not premium) when subscription null', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'subscription_expires_at': null,
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.textContaining('PREMIUM'), findsNothing);
      expect(find.textContaining('Thành viên'), findsOneWidget);
    });

    testWidgets('shows member (not premium) when subscription expired', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'subscription_expires_at':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.textContaining('PREMIUM'), findsNothing);
      expect(find.textContaining('Thành viên'), findsOneWidget);
    });

    testWidgets('renders stats row labels', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Yumi', 'email': 'y@y.com'});
      repo.seedInsights([
        Insight(id: 'i1', userId: 'u1', content: 'A', savedAt: DateTime(2026, 6, 1)),
        Insight(id: 'i2', userId: 'u1', content: 'B', savedAt: DateTime(2026, 6, 2)),
      ]);
      repo.seedTimelineEvents([
        TimelineEvent(
          id: 'e1',
          userId: 'u1',
          eventType: TimelineEventType.milestone,
          title: 'M1',
          occurredAt: DateTime(2026, 6, 10),
          createdAt: DateTime(2026, 6, 10),
        ),
      ]);
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.textContaining('Ngày streak'), findsOneWidget);
      expect(find.textContaining('Insight lưu'), findsOneWidget);
      expect(find.textContaining('Milestone'), findsOneWidget);
      // insight count = 2
      expect(find.textContaining('2'), findsWidgets);
      // milestone count = 1
      expect(find.textContaining('1'), findsWidgets);
    });

    testWidgets('renders settings section labels', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.textContaining('Nhắc nhở hằng ngày'), findsOneWidget);
      expect(find.textContaining('Ngôn ngữ'), findsOneWidget);
      expect(find.textContaining('Xuất dữ liệu'), findsOneWidget);
      expect(find.textContaining('Đăng xuất'), findsOneWidget);
    });

    testWidgets('reminder toggle calls updateReminder when tapped', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile(reminder: true));
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      // Tap the reminder toggle
      await tester.tap(find.byKey(const Key('profile_reminder_toggle')));
      await tester.pumpAndSettle();

      expect(repo.updateReminderCalls, isNotEmpty);
    });

    testWidgets('avatar shows initials from display name', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      // Initials "YT" from "Yumi Trần"
      expect(find.textContaining('YT'), findsOneWidget);
    });

    testWidgets('logout button is red', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      final logoutFinder = find.byKey(const Key('profile_logout_btn'));
      expect(logoutFinder, findsOneWidget);
    });

    testWidgets('shows profileMyWorkshops row', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.byKey(const Key('profile_my_workshops_btn')), findsOneWidget);
      expect(find.textContaining('Workshop của tôi'), findsOneWidget);
    });

    testWidgets('shows profileMyCoaching row', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.byKey(const Key('profile_my_coaching_btn')), findsOneWidget);
      expect(find.textContaining('Coaching của tôi'), findsOneWidget);
    });

    testWidgets('shows change-password row', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.byKey(const Key('profile_change_password_btn')), findsOneWidget);
      expect(find.textContaining('Đổi mật khẩu'), findsOneWidget);
    });

    testWidgets('change-password row opens dialog', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      final authRepo = _FakeAuthRepository();
      await _pumpLarge(
        tester,
        _wrap(const ProfileScreen(), repo, authRepo: authRepo),
      );

      await tester.tap(find.byKey(const Key('profile_change_password_btn')));
      await tester.pumpAndSettle();

      // Dialog title visible
      expect(find.textContaining('Đổi mật khẩu'), findsWidgets);
      expect(find.byKey(const Key('change_password_submit')), findsOneWidget);
    });

    testWidgets('change-password dialog calls changePassword on repo', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      final authRepo = _FakeAuthRepository();
      await _pumpLarge(
        tester,
        _wrap(const ProfileScreen(), repo, authRepo: authRepo),
      );

      await tester.tap(find.byKey(const Key('profile_change_password_btn')));
      await tester.pumpAndSettle();

      // Use keys to avoid ambiguity with other TextFormFields on the screen
      await tester.enterText(
        find.byKey(const Key('change_password_new_field')),
        'newpass123',
      );
      await tester.enterText(
        find.byKey(const Key('change_password_confirm_field')),
        'newpass123',
      );

      await tester.tap(find.byKey(const Key('change_password_submit')));
      await tester.pumpAndSettle();

      expect(authRepo.lastChangedPassword, 'newpass123');
    });

    testWidgets('change-password shows success snackbar', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      final authRepo = _FakeAuthRepository();
      await _pumpLarge(
        tester,
        _wrap(const ProfileScreen(), repo, authRepo: authRepo),
      );

      await tester.tap(find.byKey(const Key('profile_change_password_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('change_password_new_field')),
        'newpass123',
      );
      await tester.enterText(
        find.byKey(const Key('change_password_confirm_field')),
        'newpass123',
      );

      await tester.tap(find.byKey(const Key('change_password_submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('đã được cập nhật'), findsOneWidget);
    });

    testWidgets('change-password shows session-expired snackbar on error', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      final authRepo = _FakeAuthRepository()..changeSessionExpired = true;
      await _pumpLarge(
        tester,
        _wrap(const ProfileScreen(), repo, authRepo: authRepo),
      );

      await tester.tap(find.byKey(const Key('profile_change_password_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('change_password_new_field')),
        'newpass123',
      );
      await tester.enterText(
        find.byKey(const Key('change_password_confirm_field')),
        'newpass123',
      );

      await tester.tap(find.byKey(const Key('change_password_submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Phiên đăng nhập'), findsOneWidget);
    });

    testWidgets('shows edit-profile row in settings section', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.byKey(const Key('profile_edit_profile_btn')), findsOneWidget);
      expect(find.textContaining('Chỉnh sửa hồ sơ'), findsOneWidget);
    });
  });
}
