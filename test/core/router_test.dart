import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/router/app_router.dart';

void main() {
  group('computeRedirect', () {
    // Case 1: no session, no onboarding seen, on /splash → go to /onboarding
    test('no session + not seen onboarding + on /splash → /onboarding', () {
      expect(
        computeRedirect(
          hasSession: false,
          seenOnboarding: false,
          location: '/splash',
        ),
        '/onboarding',
      );
    });

    // Case 2: no session, no onboarding seen, on /home → go to /onboarding
    test('no session + not seen onboarding + on /home → /onboarding', () {
      expect(
        computeRedirect(
          hasSession: false,
          seenOnboarding: false,
          location: '/home',
        ),
        '/onboarding',
      );
    });

    // Case 3: no session, no onboarding seen, already on /onboarding → no redirect
    test('no session + not seen onboarding + on /onboarding → null', () {
      expect(
        computeRedirect(
          hasSession: false,
          seenOnboarding: false,
          location: '/onboarding',
        ),
        isNull,
      );
    });

    // Case 4: no session, onboarding seen, on /splash → go to /auth
    test('no session + seen onboarding + on /splash → /auth', () {
      expect(
        computeRedirect(
          hasSession: false,
          seenOnboarding: true,
          location: '/splash',
        ),
        '/auth',
      );
    });

    // Case 5: no session, onboarding seen, already on /auth → no redirect
    test('no session + seen onboarding + on /auth → null', () {
      expect(
        computeRedirect(
          hasSession: false,
          seenOnboarding: true,
          location: '/auth',
        ),
        isNull,
      );
    });

    // Case 6: has session, on /splash → go to /home
    test('has session + on /splash → /home', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: true,
          location: '/splash',
        ),
        '/home',
      );
    });

    // Case 7: has session, on /onboarding → go to /home
    test('has session + on /onboarding → /home', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: true,
          location: '/onboarding',
        ),
        '/home',
      );
    });

    // Case 8: has session, on /auth → go to /home
    test('has session + on /auth → /home', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: false,
          location: '/auth',
        ),
        '/home',
      );
    });

    // Case 9: has session, already on /home → no redirect
    test('has session + on /home → null', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: true,
          location: '/home',
        ),
        isNull,
      );
    });

    // Case 10: has session, on a deep route /profile → no redirect
    test('has session + on /profile → null', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: true,
          location: '/profile',
        ),
        isNull,
      );
    });
  });
}
