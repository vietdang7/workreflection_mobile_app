// Regression test: tapping onb3Cta ("Vào WorkReflection") trên thiết bị thật
// không chuyển màn hình — silent failure.
//
// Root cause đã xác định:
//   `_seenOnboardingProvider` (private FutureProvider) không có cách nào bị
//   invalidate từ bên ngoài `app_router.dart`. Sau khi `setSeenOnboarding()`
//   ghi SharedPreferences, FutureProvider vẫn cache kết quả cũ (false). GoRouter
//   redirect guard đọc `seenOnboardingAsync.valueOrNull ?? false` → false →
//   `computeRedirect(seenOnboarding: false, location: '/auth')` → '/onboarding' →
//   router bounce ngược về `/onboarding`, không chuyển màn hình.
//
// Fix: expose `_seenOnboardingProvider` thành `seenOnboardingProvider` (public)
// để `onboarding_screen.dart` có thể gọi:
//   ref.invalidate(seenOnboardingProvider);
//   await ref.read(seenOnboardingProvider.future);
// Cơ chế: appRouterProvider watches seenOnboardingProvider → invalidate làm
// router rebuild với giá trị mới → router mới redirect /splash → /auth.
// Không cần context.go — router mới tự điều hướng.
//
// Tests trong file này:
// 1. BUG_CHAIN: chứng minh logic redirect loop (đây là pure logic test, luôn fail
//    với expect(null) vì computeRedirect đúng khi trả về '/onboarding' với
//    seenOnboarding=false — nhưng CONTEXT là seenOnboarding NÊN là true sau set).
//    → Test này được đánh dấu là "expected behavior" bởi vì nó chứng minh
//      rằng router đúng, vấn đề là DATA sai (stale cache).
// 2. PROVIDER_EXPOSURE: chứng minh `seenOnboardingProvider` đã được export,
//    cho phép caller invalidate nó.
// 3. CONTROL tests: flow đúng khi seenOnboarding=true.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/router/app_router.dart';

void main() {
  group('onb3Cta regression — router stale-cache silent failure', () {
    /// Tái hiện lỗi logic: nếu seenOnboarding vẫn false trong bộ nhớ sau khi
    /// user tap onb3Cta, router sẽ redirect về /onboarding (loop).
    ///
    /// Đây là BẰNG CHỨNG rằng `computeRedirect` đúng — data sai (stale cache).
    test(
      'BUG CONFIRMED: computeRedirect(seenOnboarding=false, /auth) → /onboarding (stale cache loop)',
      () {
        // Đây là điều xảy ra khi FutureProvider chưa được invalidate:
        // seenOnboarding vẫn là false dù prefs đã ghi true
        final redirect = computeRedirect(
          hasSession: false,
          seenOnboarding: false, // stale cached value — root cause
          location: '/auth',
        );
        // computeRedirect ĐÚNG khi trả về '/onboarding' với seenOnboarding=false.
        // Bug không nằm ở đây — bug nằm ở việc seenOnboarding bị stale.
        expect(redirect, '/onboarding');
      },
    );

    /// Xác nhận: với seenOnboarding=true (fresh), redirect đúng → null.
    test(
      'CORRECT: computeRedirect(seenOnboarding=true, /auth) → null (auth screen allowed)',
      () {
        final redirect = computeRedirect(
          hasSession: false,
          seenOnboarding: true, // fresh value after invalidate + re-fetch
          location: '/auth',
        );
        expect(redirect, isNull);
      },
    );

    /// KEY TEST: `seenOnboardingProvider` phải được export (public) để caller có
    /// thể gọi `ref.invalidate(seenOnboardingProvider)`.
    ///
    /// Trước fix: provider là `_seenOnboardingProvider` (private) → compile error
    ///   nếu ai cố import từ screen khác.
    /// Sau fix: provider là `seenOnboardingProvider` (public) → caller có thể invalidate.
    ///
    /// TEST NÀY FAIL trước fix (compile error vì symbol không tồn tại),
    /// PASS sau fix (symbol tồn tại và hoạt động đúng).
    test(
      'FIX VERIFIED: seenOnboardingProvider (public) có thể bị invalidate bởi caller',
      () async {
        SharedPreferences.setMockInitialValues({});

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Đọc giá trị ban đầu (false vì SharedPreferences trống)
        final initial = await container.read(seenOnboardingProvider.future);
        expect(initial, false, reason: 'Chưa ghi prefs');

        // Simulate setSeenOnboarding() ghi prefs
        await setSeenOnboarding();

        // Trước fix: không thể invalidate vì provider là private.
        // Sau fix: invalidate được phép và re-fetch đọc giá trị mới.
        container.invalidate(seenOnboardingProvider);

        // Re-read sau invalidate: phải trả về true
        final afterInvalidate =
            await container.read(seenOnboardingProvider.future);
        expect(
          afterInvalidate,
          true,
          reason:
              'Sau invalidate, FutureProvider phải re-fetch từ SharedPreferences '
              'và trả về true. Đây là điều GoRouter redirect guard sẽ thấy.',
        );
      },
    );

    /// Xác nhận chuỗi đầy đủ: computeRedirect với fresh value sau invalidate → null.
    test(
      'END-TO-END: sau invalidate, router sẽ thấy seenOnboarding=true → redirect null',
      () async {
        SharedPreferences.setMockInitialValues({});
        await setSeenOnboarding(); // ghi prefs

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Invalidate để re-fetch
        container.invalidate(seenOnboardingProvider);
        final seenOnboarding =
            await container.read(seenOnboardingProvider.future);

        // Router sẽ thấy:
        final redirect = computeRedirect(
          hasSession: false,
          seenOnboarding: seenOnboarding, // true sau invalidate
          location: '/auth', // user navigate tới /auth
        );

        // Không redirect về /onboarding nữa — user đến được /auth
        expect(redirect, isNull);
      },
    );
  });
}
