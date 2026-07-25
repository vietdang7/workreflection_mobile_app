import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/router/app_router.dart';
import 'package:workreflection_mobile/core/router/auth_change_notifier.dart';

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

    // Workshop/coaching/organization tools are web-only in the mobile product.
    test('has session + on /workshops → /home', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: true,
          location: '/workshops',
        ),
        '/home',
      );
    });

    test('has session + on /coaching → /home', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: true,
          location: '/coaching',
        ),
        '/home',
      );
    });

    test('has session + on /my-workshops → /home', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: true,
          location: '/my-workshops',
        ),
        '/home',
      );
    });

    test('has session + on /coaching/sessions → /home', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: true,
          location: '/coaching/sessions',
        ),
        '/home',
      );
    });

    test('has session + on /workshops/checkin → /home', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: true,
          location: '/workshops/checkin',
        ),
        '/home',
      );
    });

    // New: /profile/setup must not be redirected when user has session
    test('has session + on /profile/setup → null', () {
      expect(
        computeRedirect(
          hasSession: true,
          seenOnboarding: true,
          location: '/profile/setup',
        ),
        isNull,
      );
    });
  });

  group('route configuration', () {
    // Regression: the video report route must be registered so
    // context.push('/survey/report/:id/video') resolves the VideoReportScreen.
    test('has a /survey/report/:id/video route', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      final paths = <String>[];
      void collect(List<RouteBase> routes) {
        for (final r in routes) {
          if (r is GoRoute) paths.add(r.path);
          collect(r.routes);
        }
      }

      collect(router.configuration.routes);

      expect(paths, contains('/survey/report/:id/video'));
    });
  });

  group('AuthChangeNotifier', () {
    test('notifies listeners when notify() is called', () {
      final notifier = AuthChangeNotifier();
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      notifier.notify();

      expect(notifyCount, 1);
    });

    test('notifies multiple times on multiple calls', () {
      final notifier = AuthChangeNotifier();
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      notifier.notify();
      notifier.notify();

      expect(notifyCount, 2);
    });

    test('does not notify after dispose', () {
      final notifier = AuthChangeNotifier();
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);
      notifier.dispose();

      // After dispose the notifier is gone; the listener must not be called.
      expect(notifyCount, 0);
    });
  });
}
