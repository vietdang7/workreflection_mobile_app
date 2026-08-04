import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/auth_screen.dart';
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
import '../../features/video_report/presentation/video_report_screen.dart';
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
import '../models/wr_content.dart';
import '../../features/wr/presentation/wr_ask_screen.dart';
import '../../features/wr/presentation/wr_home_screen.dart';
import '../../features/wr/presentation/wr_career_setup_screen.dart';
import '../../features/wr/presentation/wr_context_doc_screen.dart';
import '../../features/wr/presentation/wr_story_flow_screen.dart';
import '../../features/wr/presentation/wr_mood_library_screen.dart';
import '../../features/wr/presentation/wr_mood_reader_screen.dart';
import '../../features/wr/presentation/wr_story_screen.dart';
import '../../features/wr/presentation/wr_discover_screen.dart';
import '../../features/wr/presentation/wr_growth_screen.dart';
import '../../features/wr/presentation/wr_journey_screen.dart';
import '../../features/wr/presentation/wr_episode_detail_screen.dart';
import '../../features/wr/presentation/wr_growth_journey_screen.dart';
import '../../features/wr/presentation/wr_growth_skills_screen.dart';
import '../../features/wr/presentation/wr_growth_themes_screen.dart';
import '../../features/wr/presentation/wr_practice_theme_screen.dart';
import '../../features/wr/presentation/wr_journey_narrative_screen.dart';
import '../../features/wr/presentation/wr_pattern_detail_screen.dart';
import '../../features/wr/presentation/wr_patterns_screen.dart';
import '../../features/wr/presentation/wr_payment_screen.dart';
import '../logic/wr_pricing.dart';
import '../../features/wr/presentation/wr_paywall_screen.dart';
import '../../features/wr/presentation/wr_self_check_screen.dart';
import '../../features/wr/presentation/wr_tra_chieu_screen.dart';
import '../../features/wr/presentation/wr_work_info_screen.dart';
import '../../features/wr/presentation/flow/wr_commit_screen.dart';
import '../../features/wr/presentation/flow/wr_done_screen.dart';
import '../../features/wr/presentation/flow/wr_energy_screen.dart';
import '../../features/wr/presentation/flow/wr_detail_screen.dart';
import '../../features/wr/presentation/flow/wr_meaning_screen.dart';
import '../../features/wr/presentation/flow/wr_moment_screen.dart';
import '../../features/wr/presentation/flow/wr_step_screen.dart';
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
        path: '/survey/report/:id/video',
        builder: (context, state) =>
            VideoReportScreen(reportId: state.pathParameters['id']!),
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
        path: '/profile/setup',
        builder: (context, state) => const ProfileEditScreen(setupMode: true),
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

      // Legacy tab screens — preserved as fullscreen routes (not in shell anymore)
      GoRoute(
        path: '/understand',
        builder: (context, state) => const UnderstandScreen(),
      ),
      GoRoute(
        path: '/develop',
        builder: (context, state) => const DevelopScreen(),
      ),
      GoRoute(
        path: '/journey',
        builder: (context, state) => const JourneyScreen(),
      ),
      // NOTE: /profile is now a shell branch (Tab 4). Removed standalone route
      // to avoid GoRouter duplicate-path error.

      GoRoute(
        path: '/wr/self-check',
        builder: (context, state) => const WrSelfCheckScreen(),
      ),

      GoRoute(
        path: '/wr/career-setup',
        builder: (context, state) => const WrCareerSetupScreen(),
      ),

      GoRoute(
        path: '/wr/context-docs',
        builder: (context, state) => const WrContextDocScreen(),
      ),

      // Luồng Reflect 5 bước — Kiến trúc Dữ liệu v2.0 §V, một bước một màn
      // (WXS §8.7 Focused Surface):
      //
      //   0 Notice  → /wr/flow/step    chọn 1 trong 5 chip tình huống
      //   1 Meaning → /wr/flow/detail  đọc Story, viết chi tiết (tuỳ chọn)
      //   2 Insight → /wr/flow/meaning nhận hoặc sửa câu Aha
      //   3 Choice  → /wr/flow/commit  chọn 1 trong 4 lựa chọn
      //   4 Action  → /wr/flow/done    đã lưu vào Career Memory
      //
      // Hai route `energy` và `moment` KHÔNG nằm trong luồng của §V. Home đi
      // thẳng vào `step`; chúng chỉ còn là lối vào phụ cho phiên mở ngoài
      // check-in, và cũng dẫn về `step`.
      GoRoute(
        path: '/wr/flow/energy',
        builder: (context, state) => const WrEnergyScreen(),
      ),
      GoRoute(
        path: '/wr/flow/moment',
        builder: (context, state) => const WrMomentScreen(),
      ),
      GoRoute(
        path: '/wr/flow/step',
        builder: (context, state) => const WrStepScreen(),
      ),
      GoRoute(
        path: '/wr/flow/detail',
        builder: (context, state) => const WrDetailScreen(),
      ),
      GoRoute(
        path: '/wr/flow/meaning',
        builder: (context, state) => const WrMeaningScreen(),
      ),
      GoRoute(
        path: '/wr/flow/commit',
        builder: (context, state) => const WrCommitScreen(),
      ),
      GoRoute(
        path: '/wr/flow/done',
        builder: (context, state) => const WrDoneScreen(),
      ),

      GoRoute(
        path: '/wr/patterns',
        builder: (context, state) => const WrPatternsScreen(),
      ),

      GoRoute(
        path: '/wr/pattern/:code',
        builder: (context, state) => WrPatternDetailScreen(
          situationCode: state.pathParameters['code'] ?? '',
        ),
      ),

      // ── Màn đọc tách khỏi tab (một màn – một hành động) ────────────────
      GoRoute(
        path: '/wr/episode/:id',
        builder: (context, state) => WrEpisodeDetailScreen(
          episodeId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/wr/journey/narrative',
        builder: (context, state) => const WrJourneyNarrativeScreen(),
      ),
      // Career Memory đầy đủ — tab Hành trình chỉ hiện vài mảnh gần nhất.
      GoRoute(
        path: '/wr/career-memory',
        builder: (context, state) => const WrCareerMemoryScreen(),
      ),
      GoRoute(
        path: '/wr/growth/themes',
        builder: (context, state) => const WrGrowthThemesScreen(),
      ),
      // Một chủ đề thực hành và toàn bộ chuỗi bước của nó.
      // Đặt SAU /wr/growth/themes để đường tĩnh không bị nuốt bởi :id.
      GoRoute(
        path: '/wr/growth/theme/:id',
        builder: (context, state) => WrPracticeThemeScreen(
          themeId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/wr/growth/skills',
        builder: (context, state) => const WrGrowthSkillsScreen(),
      ),

      // Ô hỏi về hành trình nghề nghiệp (họp khách 2026-07-29). Mở từ bong
      // bóng nổi ở mọi tab và từ một dòng dẫn trong tab Hành trình.
      GoRoute(
        path: '/wr/ask',
        builder: (context, state) => const WrAskScreen(),
      ),

      // Trà Chiều Nghề Nghiệp — chương trình offline riêng (họp khách
      // 2026-07-29). Đường tĩnh '/lich' đặt trước để không đụng route khác.
      GoRoute(
        path: '/wr/tra-chieu',
        builder: (context, state) => const WrTraChieuScreen(),
      ),
      GoRoute(
        path: '/wr/tra-chieu/lich',
        builder: (context, state) => const WrTraChieuCalendarScreen(),
      ),
      GoRoute(
        path: '/wr/growth/journey',
        builder: (context, state) => const WrGrowthJourneyScreen(),
      ),

      // `/wr/situation` (WrSituationFlowScreen, Sprint 1) đã bỏ 2026-07-31.
      //
      // Không màn nào trong app dẫn tới nó — Kiến trúc v2.0 §IX: "Không còn tab
      // Reflect độc lập. Luồng Reflect chỉ khởi động từ Home qua check-in cảm
      // xúc", và việc chọn tình huống là bước 0 của luồng đó (§V), không phải
      // một màn riêng.
      //
      // Nhưng nó vẫn cộng thẳng vào `wr_pattern_counts` mà KHÔNG tạo Episode
      // nào, nên mỗi lần mở bằng deep link là một lần làm lệch con số của mọi
      // khối đọc recentSituationIds. Đây là nguồn ghi thứ ba trong ba nguồn
      // §4.3 cấm — xoá route là cách duy nhất đóng nó lại.
      GoRoute(
        path: '/wr/story/flow',
        builder: (context, state) {
          final dimStr = state.uri.queryParameters['dimension'];
          ScaDimension? dim;
          if (dimStr != null) {
            try {
              dim = ScaDimension.fromDb(dimStr);
            } catch (_) {
              dim = null;
            }
          }
          return WrStoryFlowScreen(initialDimension: dim);
        },
      ),

      GoRoute(
        path: '/wr/payment',
        // Paywall đẩy kèm gói người dùng vừa chọn (năm hay tháng). Mở thẳng
        // đường dẫn này thì không có `extra` — màn tự lấy gói chọn sẵn.
        builder: (context, state) =>
            WrPaymentScreen(plan: state.extra as WrPremiumPricing?),
      ),

      GoRoute(
        path: '/wr/paywall',
        builder: (context, state) {
          final triggerStr = state.uri.queryParameters['trigger'];
          final trigger = switch (triggerStr) {
            'ai_insight' => PaywallTrigger.aiInsight,
            'report' => PaywallTrigger.report,
            'trial_end' => PaywallTrigger.trialEnd,
            'benchmark' => PaywallTrigger.benchmark,
            'growth_opportunity' => PaywallTrigger.growthOpportunity,
            'need_reading' => PaywallTrigger.needReading,
            'career_memory' => PaywallTrigger.careerMemory,
            'sca_deep' => PaywallTrigger.selfCheckDeep,
            _ => PaywallTrigger.defaultTrigger,
          };
          return WrPaywallScreen(trigger: trigger);
        },
      ),

      // Shell with 4 indexed branches — Hai Lớp v1.6 §9.1
      // Tab 0: /home       — Hôm nay
      // Tab 1: /wr/discover — Hiểu mình (path kept; label/icon changed — low risk)
      // Tab 2: /wr/growth  — Phát triển
      // Tab 3: /wr/journey — Hành trình
      //
      // /profile không còn là tab: v1.6 §9.1 chỉ có bốn tab, "Tôi" thành avatar
      // góc trên mỗi màn. Route vẫn là /profile, chỉ chuyển thành màn đẩy toàn
      // màn hình bên dưới — mọi `context.push('/profile')` cũ vẫn chạy.
      //
      // /wr/story is NOT a shell branch anymore — it is a fullscreen route below.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const WrHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wr/discover',
                builder: (context, state) => const WrDiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wr/growth',
                builder: (context, state) => const WrGrowthScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wr/journey',
                builder: (context, state) => const WrJourneyScreen(),
              ),
            ],
          ),
        ],
      ),

      // /profile — màn đẩy toàn màn hình, mở từ avatar (v1.6 §9.1).
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // /wr/story — fullscreen push, uses root navigator implicitly (not nested in shell).
      GoRoute(
        path: '/wr/story',
        builder: (context, state) => const WrStoryScreen(),
      ),

      // Thông tin công việc hiện tại — Hai Lớp v1.6 §XI.
      GoRoute(
        path: '/wr/work-info',
        builder: (context, state) => const WrWorkInfoScreen(),
      ),

      // Thư viện Nội dung Cảm xúc — Hai Lớp v1.6 §VIII.
      // §8.3: miễn phí cho mọi người dùng, không phân lớp Free/Paid.
      GoRoute(
        path: '/wr/mood-library',
        builder: (context, state) => const WrMoodLibraryScreen(),
      ),
      GoRoute(
        path: '/wr/mood-content/:id',
        builder: (context, state) => WrMoodReaderScreen(
          contentId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
