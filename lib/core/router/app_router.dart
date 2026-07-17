import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/develop/presentation/develop_screen.dart';
import '../../features/journey/presentation/journey_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/understand/presentation/understand_screen.dart';
import 'auth_change_notifier.dart';

// ---------------------------------------------------------------------------
// Pure redirect logic — no Flutter/Supabase dependencies, fully testable.
// ---------------------------------------------------------------------------

/// Returns the redirect path, or null if no redirect is needed.
String? computeRedirect({
  required bool hasSession,
  required bool seenOnboarding,
  required String location,
}) {
  const authScreens = {'/splash', '/onboarding', '/auth'};

  if (hasSession) {
    // Logged-in users must not linger on auth/onboarding screens.
    if (authScreens.contains(location)) return '/home';
    return null;
  }

  // No session:
  if (!seenOnboarding) {
    // Must go through onboarding first.
    if (location == '/onboarding') return null;
    return '/onboarding';
  }

  // Onboarding seen but not authenticated.
  if (location == '/auth') return null;
  return '/auth';
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

const _kSeenOnboarding = 'seen_onboarding';

final _seenOnboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kSeenOnboarding) ?? false;
});

/// Call this after the user completes onboarding.
Future<void> setSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kSeenOnboarding, true);
}

/// Singleton notifier: call [AuthChangeNotifier.notify] on every auth event
/// so GoRouter's redirect guard re-runs immediately.
final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  final notifier = AuthChangeNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final appRouterProvider = Provider<GoRouter>((ref) {
  final seenOnboardingAsync = ref.watch(_seenOnboardingProvider);
  final authNotifier = ref.watch(authChangeNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final hasSession =
          Supabase.instance.client.auth.currentSession != null;
      final seenOnboarding = seenOnboardingAsync.valueOrNull ?? false;
      final location = state.uri.toString();

      return computeRedirect(
        hasSession: hasSession,
        seenOnboarding: seenOnboarding,
        location: location,
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // Shell with 5 indexed branches
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/understand',
                builder: (context, state) => const UnderstandScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/develop',
                builder: (context, state) => const DevelopScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/journey',
                builder: (context, state) => const JourneyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
