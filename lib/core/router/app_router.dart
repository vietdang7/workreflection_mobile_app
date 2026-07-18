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
import '../../features/survey/presentation/survey_intro_screen.dart';
import '../../features/survey/presentation/survey_questions_screen.dart';
import '../../features/survey/presentation/survey_processing_screen.dart';
import '../../features/survey/presentation/report_screen.dart';
import '../../features/survey/presentation/action_plan_screen.dart';
import '../../features/survey/presentation/layer_detail_screen.dart';
import '../../features/survey/presentation/esi_analysis_screen.dart';
import '../../features/workshops/presentation/workshops_screen.dart';
import '../../features/workshops/presentation/workshop_detail_screen.dart';
import '../../features/workshops/presentation/workshop_survey_screen.dart';
import '../../features/workshops/presentation/workshop_survey_results_screen.dart';
import '../../features/workshops/presentation/checkin_screen.dart';
import '../../features/workshops/presentation/my_workshops_screen.dart';
import '../../features/coaching/presentation/coaching_schedule_screen.dart';
import '../../features/coaching/presentation/coaching_screen.dart';
import '../../features/coaching/presentation/coaching_sessions_screen.dart';
import '../../features/profile/presentation/profile_edit_screen.dart';
import '../../features/profile/presentation/vouchers_screen.dart';
import '../../features/profile/presentation/invitations_screen.dart';
import '../../features/roadmap/presentation/roadmap_screen.dart';
import '../../features/survey/presentation/survey_history_screen.dart';
import '../../features/understand/presentation/insights_screen.dart';
import '../../features/survey/presentation/survey_guide_screen.dart';
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

/// Exposed so callers can invalidate after [setSeenOnboarding] to force
/// a fresh read and trigger GoRouter redirect re-evaluation.
final seenOnboardingProvider = FutureProvider<bool>((ref) async {
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
  final seenOnboardingAsync = ref.watch(seenOnboardingProvider);
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

      // Survey flow (fullscreen, outside shell)
      GoRoute(
        path: '/survey',
        builder: (context, state) => const SurveyIntroScreen(),
      ),
      GoRoute(
        path: '/survey/guide',
        builder: (context, state) => const SurveyGuideScreen(),
      ),
      GoRoute(
        path: '/survey/questions',
        builder: (context, state) => const SurveyQuestionsScreen(),
      ),
      GoRoute(
        path: '/survey/processing',
        builder: (context, state) => const SurveyProcessingScreen(),
      ),
      GoRoute(
        path: '/survey/report/:id',
        builder: (context, state) =>
            ReportScreen(reportId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/survey/action-plan/:id',
        builder: (context, state) =>
            ActionPlanScreen(reportId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/survey/report/:id/layer/:layer',
        builder: (context, state) => LayerDetailScreen(
          reportId: state.pathParameters['id']!,
          layer: state.pathParameters['layer']!,
        ),
      ),
      GoRoute(
        path: '/survey/report/:id/esi',
        builder: (context, state) =>
            EsiAnalysisScreen(reportId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/survey/history',
        builder: (context, state) => const SurveyHistoryScreen(),
      ),

      // Workshop + coaching routes (fullscreen, outside shell)
      // IMPORTANT: '/workshops/checkin' MUST be declared before '/workshops/:id'
      // so the literal segment 'checkin' is not captured as the :id parameter.
      // Similarly, '/coaching/sessions' and '/coaching/schedule/:id' MUST precede
      // any future generic '/coaching/:id' route.
      GoRoute(
        path: '/workshops',
        builder: (context, state) => const WorkshopsScreen(),
      ),
      GoRoute(
        path: '/workshops/checkin',
        builder: (context, state) => const CheckinScreen(),
      ),
      GoRoute(
        path: '/workshops/:id',
        builder: (context, state) =>
            WorkshopDetailScreen(workshopId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/workshops/:id/survey',
        builder: (context, state) =>
            WorkshopSurveyScreen(workshopId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/workshops/:id/survey-results',
        builder: (context, state) => WorkshopSurveyResultsScreen(
          workshopId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/my-workshops',
        builder: (context, state) => const MyWorkshopsScreen(),
      ),
      GoRoute(
        path: '/coaching',
        builder: (context, state) => const CoachingScreen(),
      ),
      GoRoute(
        path: '/coaching/sessions',
        builder: (context, state) => const CoachingSessionsScreen(),
      ),
      GoRoute(
        path: '/coaching/schedule/:bookingId',
        builder: (context, state) => CoachingScheduleScreen(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/vouchers',
        builder: (context, state) => const VouchersScreen(),
      ),
      GoRoute(
        path: '/invitations',
        builder: (context, state) => const InvitationsScreen(),
      ),
      GoRoute(
        path: '/insights',
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: '/roadmap',
        builder: (context, state) => RoadmapScreen(
          initialReportId: state.uri.queryParameters['report'],
        ),
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
