// Đổi tài khoản thì app phải quên sạch người trước.
//
// Lỗi gốc (khách báo 2026-08-05): đăng nhập A → đăng xuất → đăng nhập B, màn
// Home vẫn chào tên A cho tới khi tải lại màn. Nguyên nhân là Riverpod giữ
// nguyên cache của A vì `ProviderScope` không bị dựng lại giữa hai lần đăng
// nhập. Xem `lib/core/data/user_session_scope.dart`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/user_session_scope.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/features/home/home_providers.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import '../support/fake_repository.dart';

MobileProfile _profile(String userId, String name) => MobileProfile(
      userId: userId,
      displayName: name,
      reminderEnabled: true,
      language: 'vi',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('isUserSwitch', () {
    test('đăng nhập tài khoản khác là đổi người', () {
      expect(isUserSwitch(previous: 'user-a', next: 'user-b'), isTrue);
    });

    test('đăng xuất là đổi người', () {
      expect(isUserSwitch(previous: 'user-a', next: null), isTrue);
    });

    test('đăng nhập từ trạng thái chưa ai là đổi người', () {
      expect(isUserSwitch(previous: null, next: 'user-a'), isTrue);
    });

    test('làm mới token của cùng người thì KHÔNG đổi', () {
      expect(isUserSwitch(previous: 'user-a', next: 'user-a'), isFalse);
    });
  });

  group('userScopedProviders', () {
    test('gồm định danh người dùng — nguồn của mọi truy vấn theo user', () {
      expect(userScopedProviders, contains(currentUserIdProvider));
      expect(userScopedProviders, contains(currentUserEmailProvider));
    });

    test('gồm cửa đọc/ghi dữ liệu chính', () {
      expect(userScopedProviders, contains(wrRepositoryProvider));
    });

    test('không sót repository nào của lib/core/data', () {
      // Chốt số lượng để việc thêm một repository mới mà quên khai báo ở đây
      // làm test đỏ, thay vì lặng lẽ rò dữ liệu sang tài khoản kế tiếp.
      expect(userDataProviders, hasLength(13));
    });
  });

  group('reset khi đổi tài khoản', () {
    test('hồ sơ của người cũ không còn sau khi reset', () async {
      final repo = FakeWrRepository()
        ..seedProfile(_profile('user-a', 'Thedangs'));
      final container = ProviderContainer(
        overrides: [wrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final first = await container.read(mobileProfileProvider.future);
      expect(first?.displayName, 'Thedangs');

      // Người B đăng nhập: cùng một cửa dữ liệu, nhưng phiên đã khác.
      repo.seedProfile(_profile('user-b', 'Duy Thong'));

      // Chưa reset thì vẫn là giá trị cũ — đúng bằng lỗi khách gặp.
      expect(
        container.read(mobileProfileProvider).valueOrNull?.displayName,
        'Thedangs',
      );

      resetUserScopedProviders(container.invalidate);

      final second = await container.read(mobileProfileProvider.future);
      expect(second?.displayName, 'Duy Thong');
    });

    test('reset kéo theo cả provider chỉ đọc gián tiếp qua repository',
        () async {
      final repo = FakeWrRepository()
        ..seedProfile(_profile('user-a', 'Thedangs'));
      final container = ProviderContainer(
        overrides: [wrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(insightCountProvider.future);
      await container.read(latestInsightProvider.future);

      resetUserScopedProviders(container.invalidate);

      // Sau reset, hai provider này phải ở trạng thái đang tải lại chứ không
      // giữ nguyên con số đã đọc bằng phiên của người cũ.
      expect(container.read(insightCountProvider), isA<AsyncLoading<int>>());
      expect(container.read(latestInsightProvider).isLoading, isTrue);
    });
  });
}
