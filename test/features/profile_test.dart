import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/insight.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/models/timeline_event.dart';
import 'package:workreflection_mobile/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_premium_override.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/profile/presentation/profile_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';
import '../support/fake_wr_intelligence_repository.dart';

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

Widget _wrap(
  Widget child,
  WrRepository repo, {
  AuthRepository? authRepo,
  String? signedInEmail,
  FakeWrIntelligenceRepository? intel,
}) {
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(repo),
      if (authRepo != null) authRepositoryProvider.overrideWithValue(authRepo),
      // Không override thì provider hỏi Supabase, chưa khởi tạo nên trả null —
      // tức công tắc ẩn. Đó cũng là điều mọi test cũ đang trông đợi.
      if (signedInEmail != null) ...[
        currentUserEmailProvider.overrideWithValue(signedInEmail),
        // Thiếu cái này thì wrEntitlementProvider thoát sớm ở nhánh
        // `userId == null` và luôn trả về miễn phí — công tắc sẽ đọc sai
        // trạng thái ban đầu mà test vẫn xanh vì lý do khác.
        currentUserIdProvider.overrideWithValue('u1'),
        wrIntelligenceRepositoryProvider
            .overrideWithValue(intel ?? FakeWrIntelligenceRepository()),
      ],
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

    // Khách chốt 2026-08-01: Premium web và Premium app là MỘT. Nhãn gói ở màn
    // này đọc `cc_profiles.role` — đúng cột mà trang quản trị của web cấp
    // Premium bằng nó — chứ không còn tự suy ra từ `subscription_expires_at`.
    testWidgets('hiện nhãn PREMIUM khi role trên web là premium', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'role': 'premium',
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.textContaining('PREMIUM'), findsOneWidget);
    });

    testWidgets('role admin cũng là Premium', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'role': 'admin',
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.textContaining('PREMIUM'), findsOneWidget);
    });

    testWidgets('shows member (not premium) when role is empty', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'role': null,
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.textContaining('PREMIUM'), findsNothing);
      expect(find.textContaining('Thành viên'), findsOneWidget);
    });

    // Chốt chặn hồi quy: `subscription_expires_at` KHÔNG còn quyết định gói
    // nữa. Hạn còn dài mà role là 'user' thì vẫn là thành viên thường — nếu ai
    // đó nối lại cột cũ, test này đổ.
    testWidgets('subscription_expires_at còn hạn nhưng role thường vẫn không Premium',
        (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'role': 'user',
        'subscription_expires_at':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
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

    // Trước đây chỉ mỗi icon 16px bên phải là vùng bấm, nên các mục ở màn này
    // gần như không ấn được. Cả dòng phải nhận cú chạm.
    testWidgets('bấm vào nhãn cũng bật/tắt được nhắc nhở', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile(reminder: true));
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      await tester.tap(find.text('Nhắc nhở hằng ngày'));
      await tester.pumpAndSettle();

      expect(repo.updateReminderCalls, isNotEmpty);
    });

    testWidgets('mỗi mục cài đặt đều có vùng bấm', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      for (final key in const [
        'profile_language_row',
        'profile_edit_profile_btn',
        'profile_work_info_btn',
        'profile_paywall_btn',
        'profile_change_password_btn',
        'profile_export_btn',
        'profile_logout_btn',
      ]) {
        final row = find.byKey(Key(key));
        expect(row, findsOneWidget, reason: 'thiếu dòng $key');
        expect(
          tester.widget<InkWell>(
            find.descendant(of: row, matching: find.byType(InkWell)),
          ).onTap,
          isNotNull,
          reason: 'dòng $key không bấm được',
        );
      }
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

    // Legacy items must NOT appear after pivot
    testWidgets('legacy items removed — workshops/coaching/vouchers/invitations/survey/roadmap not in UI', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.byKey(const Key('profile_my_workshops_btn')), findsNothing);
      expect(find.byKey(const Key('profile_my_coaching_btn')), findsNothing);
      expect(find.byKey(const Key('profile_vouchers_btn')), findsNothing);
      expect(find.byKey(const Key('profile_invitations_btn')), findsNothing);
      expect(find.byKey(const Key('profile_survey_history_btn')), findsNothing);
      expect(find.byKey(const Key('profile_roadmap_btn')), findsNothing);
    });

    testWidgets('check-in history section not shown after pivot', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.byKey(const Key('profile_checkin_history')), findsNothing);
    });

    testWidgets('settings has exactly 6 items in order: reminder/language/edit/password/export/logout', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.textContaining('Nhắc nhở hằng ngày'), findsOneWidget);
      expect(find.textContaining('Ngôn ngữ'), findsOneWidget);
      expect(find.textContaining('Chỉnh sửa hồ sơ'), findsOneWidget);
      expect(find.textContaining('Đổi mật khẩu'), findsOneWidget);
      expect(find.textContaining('Xuất dữ liệu'), findsOneWidget);
      expect(find.textContaining('Đăng xuất'), findsOneWidget);
    });

    testWidgets('logout text uses destructive color 0xFFFF3B30', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      // Find the logout GestureDetector by key, then verify text color
      final logoutBtn = find.byKey(const Key('profile_logout_btn'));
      expect(logoutBtn, findsOneWidget);
      final textWidget = tester.widget<Text>(
        find.descendant(of: logoutBtn, matching: find.byType(Text)),
      );
      expect(textWidget.style?.color, const Color(0xFFFF3B30));
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

    // ─────────────────────────────────────────────────────────────────────────
    // Bố cục theo giao diện mẫu Sprint 2 (screenProfile)
    // ─────────────────────────────────────────────────────────────────────────

    testWidgets('khối nhận diện có tên, email và nhãn gói — mỗi thứ một lần', (
      tester,
    ) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'subscription_expires_at': null,
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      // Tên in đúng một lần: trước đây header và khối nhận diện in hai lần.
      expect(find.text('Yumi Trần'), findsOneWidget);
      expect(find.text('yumi@workreflection.app'), findsOneWidget);
      expect(find.byKey(const Key('profile_plan_pill')), findsOneWidget);
    });

    testWidgets('bản miễn phí thấy thẻ mời nâng cấp', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'subscription_expires_at': null,
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.byKey(const Key('profile_premium_card')), findsOneWidget);
      expect(find.text('Mở khoá bản đầy đủ'), findsOneWidget);
    });

    testWidgets('Premium bên web không bị mời nâng cấp thêm lần nữa', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'yumi@workreflection.app',
        'role': 'premium',
      });
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      expect(find.byKey(const Key('profile_premium_card')), findsNothing);
    });

    testWidgets('mọi lối vào tài khoản vẫn nằm trên màn này', (tester) async {
      final repo = FakeWrRepository();
      repo.seedProfile(_profile());
      repo.seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});
      await _pumpLarge(tester, _wrap(const ProfileScreen(), repo));

      // Đây là màn "Tôi" duy nhất — sửa hồ sơ, đổi mật khẩu, đăng xuất đều ở
      // đây, không tan vào tab Hành trình.
      for (final key in [
        'profile_edit_profile_btn',
        'profile_change_password_btn',
        'profile_work_info_btn',
        'profile_export_btn',
        'profile_logout_btn',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: 'thiếu $key');
      }
    });

  });

  // -------------------------------------------------------------------------
  // Công tắc Premium thử nghiệm — chỉ tài khoản nội bộ. Xem
  // `lib/core/logic/wr_premium_override.dart` để hiểu vì sao nó nằm ở máy chứ
  // không ghi vào `wr_entitlements` (RLS bảng đó chỉ cho SELECT).
  // -------------------------------------------------------------------------
  group('ProfileScreen — công tắc Premium riêng tài khoản nội bộ', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    FakeWrRepository seeded() => FakeWrRepository()
      ..seedProfile(_profile())
      ..seedCcProfile({
        'full_name': 'The Dang',
        'email': kPremiumTogglePermittedEmails.first,
        // Gói THẬT là miễn phí — để chứng minh công tắc tự nó đổi được nhãn.
        'subscription_expires_at': null,
      });

    testWidgets('tài khoản khác không thấy công tắc', (tester) async {
      final repo = FakeWrRepository()
        ..seedProfile(_profile())
        ..seedCcProfile({'full_name': 'Y', 'email': 'y@y.com'});

      await _pumpLarge(
        tester,
        _wrap(const ProfileScreen(), repo, signedInEmail: 'y@y.com'),
      );

      expect(
        find.byKey(const Key('profile_premium_override_row')),
        findsNothing,
      );
      // Dòng "Bản Premium" thường thì vẫn còn — công tắc không thay nó.
      expect(find.byKey(const Key('profile_paywall_btn')), findsOneWidget);
    });

    testWidgets('đúng tài khoản thì thấy công tắc', (tester) async {
      await _pumpLarge(
        tester,
        _wrap(const ProfileScreen(), seeded(),
            signedInEmail: kPremiumTogglePermittedEmails.first),
      );

      expect(
        find.byKey(const Key('profile_premium_override_row')),
        findsOneWidget,
      );
      // Chưa chạm thì không có dòng nhắc "đang ép" — mặc định là gói thật.
      expect(
        find.byKey(const Key('profile_premium_override_reset')),
        findsNothing,
      );
    });

    testWidgets('bật công tắc thì nhãn gói đổi theo, dù gói thật là miễn phí',
        (tester) async {
      await _pumpLarge(
        tester,
        _wrap(const ProfileScreen(), seeded(),
            signedInEmail: kPremiumTogglePermittedEmails.first),
      );

      expect(find.text('Thành viên'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_premium_override_row')));
      await tester.pumpAndSettle();

      // Nhãn gói và các cổng Premium phải nói cùng một điều — để lệch thì
      // người thử nghiệm không biết tin cái nào.
      expect(find.text('PREMIUM MEMBER'), findsOneWidget);
      expect(
        find.byKey(const Key('profile_premium_override_reset')),
        findsOneWidget,
      );
      // Thẻ mời nâng cấp phải biến mất, đúng như người Premium thật thấy.
      expect(find.byKey(const Key('profile_premium_card')), findsNothing);
    });

    testWidgets('chạm dòng nhắc thì quay về gói thật', (tester) async {
      await _pumpLarge(
        tester,
        _wrap(const ProfileScreen(), seeded(),
            signedInEmail: kPremiumTogglePermittedEmails.first),
      );

      await tester.tap(find.byKey(const Key('profile_premium_override_row')));
      await tester.pumpAndSettle();
      expect(find.text('PREMIUM MEMBER'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_premium_override_reset')));
      await tester.pumpAndSettle();

      expect(find.text('Thành viên'), findsOneWidget);
      expect(
        find.byKey(const Key('profile_premium_override_reset')),
        findsNothing,
      );
    });

    testWidgets('tắt được cả chiều ngược lại: Premium thật xem bản miễn phí',
        (tester) async {
      final repo = FakeWrRepository()
        ..seedProfile(_profile())
        ..seedCcProfile({
          'full_name': 'The Dang',
          'email': kPremiumTogglePermittedEmails.first,
          'subscription_expires_at':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        });
      // Phải gieo CẢ HAI nguồn. Màn này đọc `cc_profiles` cho nhãn gói, còn
      // mọi cổng tính năng đọc `wr_entitlements` — công tắc lấy trạng thái ban
      // đầu từ nguồn thứ hai vì đó mới là thứ thật sự mở khoá.
      final intel = FakeWrIntelligenceRepository()
        ..seedEntitlement(const WrEntitlementRecord(
          userId: 'u1',
          plan: WrPlan.premium,
        ));

      await _pumpLarge(
        tester,
        _wrap(const ProfileScreen(), repo,
            signedInEmail: kPremiumTogglePermittedEmails.first, intel: intel),
      );

      expect(find.text('PREMIUM MEMBER'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_premium_override_row')));
      await tester.pumpAndSettle();

      expect(find.text('Thành viên'), findsOneWidget);
      expect(find.byKey(const Key('profile_premium_card')), findsOneWidget);
    });
  });
}
