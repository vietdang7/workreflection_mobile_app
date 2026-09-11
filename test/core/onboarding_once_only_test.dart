// Onboarding 3 trang chỉ hiện MỘT LẦN — mục 17.3 (khách 09/09/2026).
//
// Khách hỏi lại: onboarding có hiện đè lên mỗi lần mở app không, đăng nhập lại
// có phải xem lại không. Đọc mã thì đã đúng: cờ `seen_onboarding` lưu trên máy,
// và `computeRedirect` chỉ đưa vào onboarding khi CHƯA đăng nhập và CHƯA từng
// xem. Nhưng đúng mà không có gì khoá thì lần sửa sau làm hỏng không ai biết.
//
// `router_test.dart` đã khoá phần LOGIC THUẦN của `computeRedirect`. Cái còn
// hở là mắt xích giữa hai đầu:
//
//   1. Trang 3 có thật sự GHI cờ xuống máy không.
//   2. Cờ đã ghi có được provider ĐỌC RA không.
//   3. Hai thứ đó ghép với computeRedirect có thật sự đóng cửa onboarding
//      không — kể cả khi người dùng đăng xuất rồi mở lại.
//
// Run: flutter test test/core/onboarding_once_only_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/router/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('máy mới: chưa có cờ thì provider trả false', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(seenOnboardingProvider.future), isFalse);
  });

  test('setSeenOnboarding ghi cờ, provider đọc lại ra true', () async {
    await setSeenOnboarding();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(seenOnboardingProvider.future), isTrue);
  });

  test('cờ sống qua lần mở app sau', () async {
    await setSeenOnboarding();

    // Mở app lần sau = một ProviderContainer mới đọc lại cùng SharedPreferences.
    final again = ProviderContainer();
    addTearDown(again.dispose);
    expect(await again.read(seenOnboardingProvider.future), isTrue);
  });

  test('xem xong rồi thì mọi màn đều KHÔNG quay về onboarding', () async {
    await setSeenOnboarding();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final seen = await container.read(seenOnboardingProvider.future);

    for (final where in ['/splash', '/auth', '/home', '/wr/discover']) {
      expect(
        computeRedirect(
          hasSession: false,
          seenOnboarding: seen,
          location: where,
        ),
        isNot('/onboarding'),
        reason: 'từ $where không được rơi lại vào onboarding',
      );
    }
  });

  test('đăng nhập rồi thì không thấy onboarding, kể cả khi cờ chưa ghi',
      () async {
    // Hai lớp bảo vệ độc lập. Nhánh `hasSession` chặn trước cả khi cờ bị mất —
    // gỡ app rồi cài lại mà phiên đăng nhập còn thì cũng không bắt xem lại.
    expect(
      computeRedirect(
        hasSession: true,
        seenOnboarding: false,
        location: '/onboarding',
      ),
      '/home',
    );
  });

  test('CHƯA xem thì vẫn phải đi qua onboarding', () async {
    // Vế ngược lại của cùng một luật. Thiếu bài này thì một lần sửa làm
    // `seenOnboarding` luôn true sẽ đi lọt: bốn bài trên vẫn xanh, mà người
    // dùng mới không bao giờ thấy onboarding nữa.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final seen = await container.read(seenOnboardingProvider.future);

    expect(
      computeRedirect(
        hasSession: false,
        seenOnboarding: seen,
        location: '/auth',
      ),
      '/onboarding',
    );
  });
}
