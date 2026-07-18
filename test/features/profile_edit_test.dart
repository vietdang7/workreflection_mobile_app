import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/features/profile/presentation/profile_edit_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';

// ---------------------------------------------------------------------------
// Task 1: Repository contract tests
// ---------------------------------------------------------------------------

Widget _wrapEdit(Widget child, WrRepository repo) {
  return ProviderScope(
    overrides: [wrRepositoryProvider.overrideWithValue(repo)],
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

Future<void> _pumpEdit(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

FakeWrRepository _seedRepo() {
  final repo = FakeWrRepository();
  repo.seedProfile(MobileProfile(
    userId: 'u1',
    displayName: 'Yumi Trần',
    reminderEnabled: true,
    language: 'vi',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 6, 1),
  ));
  repo.seedCcProfile({
    'full_name': 'Yumi Trần',
    'email': 'yumi@workreflection.app',
    'subscription_expires_at': null,
    'phone': '0901234567',
    'company_name': 'Acme Corp',
    'position': 'manager',
    'company_size': '51_200',
    'total_work_experience': '5_10',
    'company_tenure': '2_5',
    'department': 'hr',
  });
  return repo;
}

void main() {
  group('WrRepository profile-edit contract', () {
    test('getCcProfile returns extended fields', () async {
      final repo = FakeWrRepository();
      repo.seedCcProfile({
        'full_name': 'Yumi Trần',
        'email': 'y@y.com',
        'subscription_expires_at': null,
        'phone': '0901234567',
        'company_name': 'Acme',
        'position': 'manager',
        'company_size': '51_200',
        'total_work_experience': '5_10',
        'company_tenure': '2_5',
        'department': 'hr',
      });
      final data = await repo.getCcProfile();
      expect(data['phone'], '0901234567');
      expect(data['company_name'], 'Acme');
      expect(data['position'], 'manager');
    });

    test('updateCcProfile records call', () async {
      final repo = FakeWrRepository();
      await repo.updateCcProfile({
        'full_name': 'New Name',
        'phone': '0900000000',
        'company_name': 'Corp',
        'position': 'staff',
        'company_size': '1_10',
        'total_work_experience': 'less_1',
        'company_tenure': 'less_6m',
        'department': 'it',
      });
      expect(repo.updateCcProfileCalls, hasLength(1));
      expect(repo.updateCcProfileCalls.first['position'], 'staff');
    });

    test('updateDisplayName records call', () async {
      final repo = FakeWrRepository();
      await repo.updateDisplayName('New Display');
      expect(repo.updateDisplayNameCalls, contains('New Display'));
    });
  });

  // ---------------------------------------------------------------------------
  // Task 3: ProfileEditScreen widget tests
  // ---------------------------------------------------------------------------

  group('ProfileEditScreen', () {
    testWidgets('renders all text fields with seeded values', (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(tester, _wrapEdit(const ProfileEditScreen(), repo));

      expect(find.byKey(const Key('profile_edit_display_name')), findsOneWidget);
      expect(find.byKey(const Key('profile_edit_full_name')), findsOneWidget);
      expect(find.byKey(const Key('profile_edit_phone')), findsOneWidget);
      expect(find.byKey(const Key('profile_edit_company_name')), findsOneWidget);
      // Check one pre-filled value
      expect(find.widgetWithText(TextFormField, 'Yumi Trần'), findsWidgets);
    });

    testWidgets('save button calls updateCcProfile and updateDisplayName',
        (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(tester, _wrapEdit(const ProfileEditScreen(), repo));

      // Clear and re-enter display name
      await tester.enterText(
        find.byKey(const Key('profile_edit_display_name')),
        'New Name',
      );
      // Tap save
      await tester.tap(find.byKey(const Key('profile_edit_save_btn')));
      await tester.pumpAndSettle();

      expect(repo.updateDisplayNameCalls, contains('New Name'));
      expect(repo.updateCcProfileCalls, hasLength(1));
    });

    testWidgets('shows success snackbar after save', (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(tester, _wrapEdit(const ProfileEditScreen(), repo));

      await tester.tap(find.byKey(const Key('profile_edit_save_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã cập nhật'), findsOneWidget);
    });

    testWidgets('position dropdown shows options', (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(tester, _wrapEdit(const ProfileEditScreen(), repo));

      // Tap the position dropdown
      await tester.tap(find.byKey(const Key('profile_edit_position')));
      await tester.pumpAndSettle();

      // Should see at least one option label
      expect(find.textContaining('Nhân viên'), findsOneWidget);
    });

    testWidgets('avatar section shows initials and tap target', (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(tester, _wrapEdit(const ProfileEditScreen(), repo));

      expect(find.textContaining('YT'), findsOneWidget);
      // Avatar is now tappable for upload — verify the tap target exists.
      expect(find.byKey(const Key('profile_edit_avatar_tap')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Setup mode
  // ---------------------------------------------------------------------------
  group('ProfileEditScreen setup mode', () {
    testWidgets('shows setup title "Hoàn thiện hồ sơ" in setupMode', (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(
        tester,
        _wrapEdit(const ProfileEditScreen(setupMode: true), repo),
      );
      expect(find.text('Hoàn thiện hồ sơ'), findsOneWidget);
    });

    testWidgets('shows skip button in setupMode', (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(
        tester,
        _wrapEdit(const ProfileEditScreen(setupMode: true), repo),
      );
      expect(find.byKey(const Key('profile_setup_skip_btn')), findsOneWidget);
      expect(find.text('Bỏ qua'), findsOneWidget);
    });

    testWidgets('shows "Hoàn tất" label on save button in setupMode', (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(
        tester,
        _wrapEdit(const ProfileEditScreen(setupMode: true), repo),
      );
      expect(find.text('Hoàn tất'), findsOneWidget);
      expect(find.text('Lưu thay đổi'), findsNothing);
    });

    testWidgets('no back button in setupMode', (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(
        tester,
        _wrapEdit(const ProfileEditScreen(setupMode: true), repo),
      );
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('normal mode still shows back button', (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(
        tester,
        _wrapEdit(const ProfileEditScreen(), repo),
      );
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('normal mode shows "Lưu thay đổi" label', (tester) async {
      final repo = _seedRepo();
      await _pumpEdit(
        tester,
        _wrapEdit(const ProfileEditScreen(), repo),
      );
      expect(find.text('Lưu thay đổi'), findsOneWidget);
      expect(find.text('Hoàn tất'), findsNothing);
    });
  });
}
