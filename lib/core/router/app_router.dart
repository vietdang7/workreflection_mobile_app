import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/splash/splash_screen.dart';

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

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final appRouterProvider = Provider<GoRouter>((ref) {
  final seenOnboardingAsync = ref.watch(_seenOnboardingProvider);

  return GoRouter(
    initialLocation: '/splash',
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
        builder: (context, state) => const _PlaceholderScreen('Auth'),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const _PlaceholderScreen('Home'),
      ),
      GoRoute(
        path: '/understand',
        builder: (context, state) => const _PlaceholderScreen('Understand'),
      ),
      GoRoute(
        path: '/develop',
        builder: (context, state) => const _PlaceholderScreen('Develop'),
      ),
      GoRoute(
        path: '/journey',
        builder: (context, state) => const _PlaceholderScreen('Journey'),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const _PlaceholderScreen('Profile'),
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Temporary placeholder — replaced in Task 9 with real screens.
// ---------------------------------------------------------------------------

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(name)),
    );
  }
}
