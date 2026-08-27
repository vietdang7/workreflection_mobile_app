import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:image_picker/image_picker.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/features/profile/avatar_providers.dart';
import 'package:workreflection_mobile/features/profile/presentation/profile_edit_screen.dart';
import 'package:workreflection_mobile/features/profile/presentation/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';

// ---------------------------------------------------------------------------
// Fake picker — returns a pre-set file or null (simulates cancel).
// ---------------------------------------------------------------------------

/// Quyền kho ảnh giả — mặc định cho phép, giống hành vi trên máy thật khi
/// người dùng bấm "Cho phép".
class _FakePermissionService implements PhotoPermissionService {
  _FakePermissionService({this.granted = true});

  final bool granted;
  int askCount = 0;
  int openSettingsCount = 0;

  @override
  Future<bool> ensureGranted() async {
    askCount++;
    return granted;
  }

  @override
  Future<void> openSettings() async => openSettingsCount++;
}

class _FakePickerService implements AvatarPickerService {
  final XFile? result;
  int callCount = 0;

  _FakePickerService({this.result});

  @override
  Future<XFile?> pickFromGallery({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    callCount++;
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(
  Widget child,
  WrRepository repo,
  AvatarPickerService picker, {
  PhotoPermissionService? permission,
}) {
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(repo),
      avatarPickerServiceProvider.overrideWithValue(picker),
      photoPermissionServiceProvider
          .overrideWithValue(permission ?? _FakePermissionService()),
    ],
    child: MaterialApp(
      builder: wrTextScaleBuilder,
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

FakeWrRepository _seedRepo({String? avatarUrl}) {
  final repo = FakeWrRepository();
  repo.seedProfile(MobileProfile(
    userId: 'u1',
    displayName: 'Test User',
    reminderEnabled: true,
    language: 'vi',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 6, 1),
  ));
  repo.seedCcProfile({
    'full_name': 'Test User',
    'email': 'test@test.com',
    'subscription_expires_at': null,
    'phone': '',
    'company_name': '',
    'position': null,
    'company_size': null,
    'total_work_experience': null,
    'company_tenure': null,
    'department': null,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
  });
  return repo;
}

void main() {
  group('AvatarUploadNotifier', () {
    test('pickAndUpload calls uploadAvatar and returns URL', () async {
      final repo = _seedRepo();
      // Fake XFile with minimal bytes
      final fakeFile = XFile.fromData(
        Uint8List.fromList([0xFF, 0xD8, 0xFF]), // minimal JPEG header
        name: 'photo.jpg',
        mimeType: 'image/jpeg',
      );
      final picker = _FakePickerService(result: fakeFile);

      final container = ProviderContainer(
        overrides: [
          wrRepositoryProvider.overrideWithValue(repo),
          avatarPickerServiceProvider.overrideWithValue(picker),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(avatarUploadProvider.notifier);
      final url = await notifier.pickAndUpload();

      expect(url, isNotNull);
      expect(url, contains('avatar.jpg'));
      expect(repo.uploadAvatarCalls, hasLength(1));
      expect(repo.uploadAvatarCalls.first.$2, 'jpg');
      expect(picker.callCount, 1);
    });

    test('pickAndUpload dừng lại khi quyền kho ảnh bị từ chối', () async {
      final repo = _seedRepo();
      final picker = _FakePickerService(result: null);
      final permission = _FakePermissionService(granted: false);

      final container = ProviderContainer(
        overrides: [
          wrRepositoryProvider.overrideWithValue(repo),
          avatarPickerServiceProvider.overrideWithValue(picker),
          photoPermissionServiceProvider.overrideWithValue(permission),
        ],
      );
      addTearDown(container.dispose);

      final url =
          await container.read(avatarUploadProvider.notifier).pickAndUpload();

      expect(url, isNull);
      expect(picker.callCount, 0);
      expect(
        container.read(avatarUploadProvider).error,
        isA<AvatarPermissionDeniedException>(),
      );
    });

    test('pickAndUpload returns null when user cancels (picker returns null)',
        () async {
      final repo = _seedRepo();
      final picker = _FakePickerService(result: null);

      final container = ProviderContainer(
        overrides: [
          wrRepositoryProvider.overrideWithValue(repo),
          avatarPickerServiceProvider.overrideWithValue(picker),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(avatarUploadProvider.notifier);
      final url = await notifier.pickAndUpload();

      expect(url, isNull);
      expect(repo.uploadAvatarCalls, isEmpty);
    });
  });

  group('ProfileEditScreen — avatar section', () {
    testWidgets('shows avatar tap target', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = _seedRepo();
      final picker = _FakePickerService(result: null);

      await tester.pumpWidget(_wrap(const ProfileEditScreen(), repo, picker));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_edit_avatar_tap')), findsOneWidget);
    });

    testWidgets('tapping avatar calls picker', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = _seedRepo();
      final picker = _FakePickerService(result: null); // cancel

      await tester.pumpWidget(_wrap(const ProfileEditScreen(), repo, picker));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile_edit_avatar_tap')));
      await tester.pumpAndSettle();

      expect(picker.callCount, 1);
    });

    testWidgets('shows network image when avatar_url is set', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo =
          _seedRepo(avatarUrl: 'https://example.com/avatar.jpg');
      final picker = _FakePickerService(result: null);

      await tester.pumpWidget(_wrap(const ProfileEditScreen(), repo, picker));
      await tester.pumpAndSettle();

      // NetworkImage widget should be present
      expect(find.byType(Image), findsWidgets);
    });
  });

  group('FakeWrRepository — uploadAvatar contract', () {
    test('uploadAvatar records bytes and ext', () async {
      final repo = FakeWrRepository();
      final url = await repo.uploadAvatar([1, 2, 3], 'png');
      expect(url, contains('avatar.png'));
      expect(repo.uploadAvatarCalls, hasLength(1));
      expect(repo.uploadAvatarCalls.first.$1, [1, 2, 3]);
      expect(repo.uploadAvatarCalls.first.$2, 'png');
    });

    test('uploadAvatar updates cc_profile avatar_url', () async {
      final repo = FakeWrRepository();
      repo.seedCcProfile({'full_name': 'X'});
      await repo.uploadAvatar([0], 'jpg');
      final profile = await repo.getCcProfile();
      expect(profile['avatar_url'], contains('avatar.jpg'));
    });
  });

  // -------------------------------------------------------------------------
  // Lối vào từ màn Hồ sơ.
  //
  // Suốt một thời gian ô đổi ảnh CHỈ nằm trong `ProfileEditScreen`, mà màn đó
  // chỉ mở ra qua `/profile/setup` — ngay sau khi đăng ký. Route
  // `/profile/edit` có khai trong `app_router.dart` nhưng không widget nào gọi
  // tới, nên người đã có tài khoản không có đường nào đổi ảnh. Hai test dưới
  // đây khoá lại lối vào mới để lần sau sắp xếp lại màn Hồ sơ không làm rơi nó
  // lần nữa.
  // -------------------------------------------------------------------------
  group('ProfileScreen — lối đổi ảnh đại diện', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpProfile(
      WidgetTester tester,
      WrRepository repo,
      AvatarPickerService picker,
    ) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_wrap(const ProfileScreen(), repo, picker));
      await tester.pumpAndSettle();
    }

    testWidgets('có cả dòng thiết lập lẫn vòng tròn ảnh bấm được',
        (tester) async {
      await pumpProfile(
          tester, _seedRepo(), _FakePickerService(result: null));

      expect(find.byKey(const Key('profile_change_avatar_btn')), findsOneWidget);
      expect(find.byKey(const Key('profile_avatar_tap')), findsOneWidget);
    });

    testWidgets('từ chối quyền thì không mở bộ chọn, và mời mở Cài đặt',
        (tester) async {
      final repo = _seedRepo();
      final picker = _FakePickerService(result: null);
      final permission = _FakePermissionService(granted: false);

      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        _wrap(const ProfileScreen(), repo, picker, permission: permission),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile_change_avatar_btn')));
      await tester.pumpAndSettle();

      expect(permission.askCount, 1);
      // Chưa có quyền thì đừng mở bộ chọn: người dùng sẽ thấy một màn trống
      // rồi tự hỏi vì sao không có ảnh nào.
      expect(picker.callCount, 0);
      expect(repo.uploadAvatarCalls, isEmpty);

      expect(find.text('Cần quyền vào kho ảnh thì mới chọn được ảnh đại diện.'),
          findsOneWidget);
      await tester.tap(find.text('Mở Cài đặt'));
      await tester.pumpAndSettle();
      expect(permission.openSettingsCount, 1);
    });

    testWidgets('chạm dòng đổi ảnh thì mở bộ chọn và tải ảnh lên',
        (tester) async {
      final repo = _seedRepo();
      final picker = _FakePickerService(
        result: XFile.fromData(
          Uint8List.fromList([0xFF, 0xD8, 0xFF]),
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
        ),
      );
      await pumpProfile(tester, repo, picker);

      await tester.tap(find.byKey(const Key('profile_change_avatar_btn')));
      await tester.pumpAndSettle();

      expect(picker.callCount, 1);
      expect(repo.uploadAvatarCalls, hasLength(1));
    });
  });
}
