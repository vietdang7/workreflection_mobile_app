// Bảng route.
//
// ---------------------------------------------------------------------------
// VÌ SAO MỌI ROUTE DÙNG `wrRoute(...)` CHỨ KHÔNG DÙNG `GoRoute(...)`
// ---------------------------------------------------------------------------
//
// Phần WorkReflection lấy chữ qua `tr()`, đọc biến toàn cục `wrEnglish` (lý do
// ở `core/l10n/wr_tr.dart`). Đổi biến toàn cục không báo cho Flutter, nên một
// màn chỉ đổi chữ khi có ai đó gọi lại `build` của nó — và trong go_router,
// KHÔNG có ai làm việc đó.
//
// go_router giữ danh sách `Page` đã dựng trong `_CustomNavigatorState._pages`
// và chỉ vứt đi khi đường dẫn đổi. Cha dựng lại bao nhiêu lần cũng vậy: cùng
// một `Page`, cùng một widget màn hình, `Element.updateChild` trả về ngay. Với
// bốn tab (`StatefulShellRoute.indexedStack`) còn nặng hơn — nhánh không hoạt
// động được giữ nguyên widget đã dựng từ trước lúc đổi ngôn ngữ.
//
// Đó là toàn bộ nguyên nhân khách báo 10/09: "chuyển đổi ngôn ngữ rất chậm,
// thậm chí không chuyển đổi hoàn toàn, cứ xen kẽ tiếng Anh với tiếng Việt".
// Không có gì hỏng — chỉ là không có gì ra lệnh dựng lại.
//
// [wrRoute] bọc `builder` bằng `wrLocaleAware`, thứ đăng ký route làm bên phụ
// thuộc của `WrLocaleScope`. Đó là đường DUY NHẤT đi xuyên qua cache của
// go_router: `Builder` bọc mỗi route dựng lại khi InheritedWidget đổi, kể cả
// khi `Page` bọc ngoài vẫn là `Page` cũ và kể cả khi nhánh tab đang nằm ngoài
// màn hình. Chi tiết đầy đủ ở `core/l10n/wr_locale_scope.dart`.
//
// ⚠ Thêm route mới thì dùng `wrRoute(...)`. Một `GoRoute(...)` trần sẽ đứng yên
//   ở ngôn ngữ của lần dựng đầu tiên — lỗi chỉ lộ khi có người đổi ngôn ngữ rồi
//   đi qua đúng màn đó.
//
// ---------------------------------------------------------------------------
// VÌ SAO KHÔNG MÀN NÀO Ở ĐÂY ĐƯỢC DỰNG BẰNG `const`
// ---------------------------------------------------------------------------
//
// Đây là chỗ duy nhất trong repo cố ý đi ngược `prefer_const_constructors`.
// `wrLocaleAware` đã đủ để mọi màn dựng lại, nhưng `const` thì thừa ra một cái
// bẫy: `const WrHomeScreen()` là MỘT thực thể duy nhất, nên nếu ai đó gỡ
// `wrRoute` đi thì lỗi cũ quay lại im lặng. Bỏ `const` là hàng phòng thủ thứ
// hai, giá phải trả chỉ là một phép cấp phát mỗi lần dựng.
//
// ⚠ Đừng thêm `const` lại vào các builder dưới đây. Trình phân tích sẽ gợi ý
//   làm vậy — nó không biết chuyện `tr()`.
//
// ignore_for_file: prefer_const_constructors

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/wr_locale_scope.dart';
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
import '../../features/profile/presentation/guide_screen.dart';
import '../../features/profile/presentation/my_info_screen.dart';
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
import '../../features/wr/presentation/wr_org_survey_flow_screen.dart';
import '../../features/wr/presentation/wr_org_survey_intro_screen.dart';
import '../../features/wr/presentation/wr_org_survey_result_screen.dart';
import '../models/wr_org_survey.dart';
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
import '../../features/wr/presentation/wr_ai_consent_screen.dart';
import '../logic/wr_ai_disclosure.dart';
import '../../features/wr/presentation/wr_journey_narrative_screen.dart';
import '../../features/wr/presentation/wr_pattern_detail_screen.dart';
import '../../features/wr/presentation/wr_patterns_screen.dart';
import '../../features/wr/presentation/wr_payment_screen.dart';
import '../logic/wr_pricing.dart';
import '../../features/wr/wr_providers.dart' show wrStorePolicyProvider;
import '../../features/wr/presentation/wr_paywall_screen.dart';
import '../../features/wr/presentation/wr_self_check_screen.dart';
import '../../features/wr/presentation/wr_tra_chieu_screen.dart';
import '../../features/wr/presentation/wr_jd_builder_screen.dart';
import '../../features/wr/presentation/wr_sca_deep_dive_screen.dart';
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
// wrRoute — GoRoute có gắn cầu dao ngôn ngữ
// ---------------------------------------------------------------------------

/// [GoRoute] mà màn hình bên trong dựng lại khi người dùng đổi ngôn ngữ.
///
/// Chỉ khác `GoRoute` đúng một chỗ: `builder` được bọc bằng `wrLocaleAware`.
/// Lý do vì sao cần bọc — và vì sao mọi cách hiển nhiên hơn đều không tới được
/// màn hình — nằm ở đầu file này và ở `core/l10n/wr_locale_scope.dart`.
///
/// Route chỉ để chuyển hướng (`redirect` mà không có `builder`) đi qua đây
/// nguyên vẹn: không có màn nào để dựng thì không có gì để bọc.
GoRoute wrRoute({
  required String path,
  String? name,
  GoRouterWidgetBuilder? builder,
  GlobalKey<NavigatorState>? parentNavigatorKey,
  GoRouterRedirect? redirect,
  ExitCallback? onExit,
  List<RouteBase> routes = const <RouteBase>[],
}) {
  return GoRoute(
    path: path,
    name: name,
    parentNavigatorKey: parentNavigatorKey,
    redirect: redirect,
    onExit: onExit,
    routes: routes,
    builder: builder == null
        ? null
        : (context, state) => wrLocaleAware(context, builder(context, state)),
  );
}

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
      wrRoute(
        path: '/splash',
        builder: (context, state) => SplashScreen(),
      ),
      wrRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(),
      ),
      wrRoute(
        path: '/auth',
        builder: (context, state) => AuthScreen(),
      ),

      // Survey flow (fullscreen, outside shell)
      wrRoute(
        path: '/survey',
        builder: (context, state) => SurveyIntroScreen(),
      ),
      wrRoute(
        path: '/survey/guide',
        builder: (context, state) => SurveyGuideScreen(),
      ),
      wrRoute(
        path: '/survey/questions',
        builder: (context, state) => SurveyQuestionsScreen(),
      ),
      wrRoute(
        path: '/survey/processing',
        builder: (context, state) => SurveyProcessingScreen(),
      ),
      wrRoute(
        path: '/survey/report/:id',
        builder: (context, state) =>
            ReportScreen(reportId: state.pathParameters['id']!),
      ),
      wrRoute(
        path: '/survey/action-plan/:id',
        builder: (context, state) =>
            ActionPlanScreen(reportId: state.pathParameters['id']!),
      ),
      wrRoute(
        path: '/survey/report/:id/layer/:layer',
        builder: (context, state) => LayerDetailScreen(
          reportId: state.pathParameters['id']!,
          layer: state.pathParameters['layer']!,
        ),
      ),
      wrRoute(
        path: '/survey/report/:id/esi',
        builder: (context, state) =>
            EsiAnalysisScreen(reportId: state.pathParameters['id']!),
      ),
      wrRoute(
        path: '/survey/report/:id/video',
        builder: (context, state) =>
            VideoReportScreen(reportId: state.pathParameters['id']!),
      ),
      wrRoute(
        path: '/survey/history',
        builder: (context, state) => SurveyHistoryScreen(),
      ),

      // Workshop + coaching routes (fullscreen, outside shell)
      // IMPORTANT: '/workshops/checkin' MUST be declared before '/workshops/:id'
      // so the literal segment 'checkin' is not captured as the :id parameter.
      // Similarly, '/coaching/sessions' and '/coaching/schedule/:id' MUST precede
      // any future generic '/coaching/:id' route.
      wrRoute(
        path: '/workshops',
        builder: (context, state) => WorkshopsScreen(),
      ),
      wrRoute(
        path: '/workshops/checkin',
        builder: (context, state) => CheckinScreen(),
      ),
      wrRoute(
        path: '/workshops/:id',
        builder: (context, state) =>
            WorkshopDetailScreen(workshopId: state.pathParameters['id']!),
      ),
      wrRoute(
        path: '/workshops/:id/survey',
        builder: (context, state) =>
            WorkshopSurveyScreen(workshopId: state.pathParameters['id']!),
      ),
      wrRoute(
        path: '/workshops/:id/survey-results',
        builder: (context, state) => WorkshopSurveyResultsScreen(
          workshopId: state.pathParameters['id']!,
        ),
      ),
      wrRoute(
        path: '/my-workshops',
        builder: (context, state) => MyWorkshopsScreen(),
      ),
      wrRoute(
        path: '/coaching',
        builder: (context, state) => CoachingScreen(),
      ),
      wrRoute(
        path: '/coaching/sessions',
        builder: (context, state) => CoachingSessionsScreen(),
      ),
      wrRoute(
        path: '/coaching/schedule/:bookingId',
        builder: (context, state) => CoachingScheduleScreen(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
      wrRoute(
        path: '/profile/edit',
        builder: (context, state) => ProfileEditScreen(),
      ),
      wrRoute(
        path: '/profile/setup',
        builder: (context, state) => ProfileEditScreen(setupMode: true),
      ),
      // "Thông tin của bạn" — mockup Sprint 2 bản (4), `screenMyInfo`.
      wrRoute(
        path: '/profile/my-info',
        builder: (context, state) => MyInfoScreen(),
      ),
      // "Hướng dẫn sử dụng" — yêu cầu §4 họp 26_1. Route riêng chứ không phải
      // hộp thoại: nội dung dài hơn một màn, và người dùng cần quay lại đọc
      // tiếp mà không mất chỗ đang đứng trong Hồ sơ.
      wrRoute(
        path: '/profile/guide',
        builder: (context, state) => GuideScreen(),
      ),
      wrRoute(
        path: '/vouchers',
        builder: (context, state) => VouchersScreen(),
      ),
      wrRoute(
        path: '/invitations',
        builder: (context, state) => InvitationsScreen(),
      ),
      wrRoute(
        path: '/insights',
        builder: (context, state) => InsightsScreen(),
      ),
      wrRoute(
        path: '/roadmap',
        builder: (context, state) => RoadmapScreen(
          initialReportId: state.uri.queryParameters['report'],
        ),
      ),

      // Legacy tab screens — preserved as fullscreen routes (not in shell anymore)
      wrRoute(
        path: '/understand',
        builder: (context, state) => UnderstandScreen(),
      ),
      wrRoute(
        path: '/develop',
        builder: (context, state) => DevelopScreen(),
      ),
      wrRoute(
        path: '/journey',
        builder: (context, state) => JourneyScreen(),
      ),
      // NOTE: /profile is now a shell branch (Tab 4). Removed standalone route
      // to avoid GoRouter duplicate-path error.

      wrRoute(
        path: '/wr/self-check',
        builder: (context, state) => WrSelfCheckScreen(),
      ),

      wrRoute(
        path: '/wr/career-setup',
        builder: (context, state) => WrCareerSetupScreen(),
      ),

      wrRoute(
        path: '/wr/context-docs',
        builder: (context, state) => WrContextDocScreen(),
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
      wrRoute(
        path: '/wr/flow/energy',
        builder: (context, state) => WrEnergyScreen(),
      ),
      wrRoute(
        path: '/wr/flow/moment',
        builder: (context, state) => WrMomentScreen(),
      ),
      wrRoute(
        path: '/wr/flow/step',
        builder: (context, state) => WrStepScreen(),
      ),
      wrRoute(
        path: '/wr/flow/detail',
        builder: (context, state) => WrDetailScreen(),
      ),
      wrRoute(
        path: '/wr/flow/meaning',
        builder: (context, state) => WrMeaningScreen(),
      ),
      wrRoute(
        path: '/wr/flow/commit',
        builder: (context, state) => WrCommitScreen(),
      ),
      wrRoute(
        path: '/wr/flow/done',
        builder: (context, state) => WrDoneScreen(),
      ),

      wrRoute(
        path: '/wr/patterns',
        builder: (context, state) => WrPatternsScreen(),
      ),

      wrRoute(
        path: '/wr/pattern/:code',
        builder: (context, state) => WrPatternDetailScreen(
          situationCode: state.pathParameters['code'] ?? '',
        ),
      ),

      // ── Màn đọc tách khỏi tab (một màn – một hành động) ────────────────
      wrRoute(
        path: '/wr/episode/:id',
        builder: (context, state) => WrEpisodeDetailScreen(
          episodeId: state.pathParameters['id'] ?? '',
        ),
      ),
      wrRoute(
        path: '/wr/journey/narrative',
        builder: (context, state) => WrJourneyNarrativeScreen(),
      ),
      // Xử lý dữ liệu bằng AI — xem lại bản công bố và bật/tắt.
      //
      // Đường dẫn phải khớp `kWrAiRevokePath` trong `wr_ai_disclosure.dart`:
      // bản công bố nói với người dùng chỗ này nằm ở đâu, và Apple đọc chính
      // câu đó khi duyệt Guideline 5.1.1(i).
      GoRoute(
        path: kWrAiRevokePath,
        builder: (context, state) => const WrAiConsentScreen(),
      ),
      // Career Memory đầy đủ — tab Hành trình chỉ hiện vài mảnh gần nhất.
      wrRoute(
        path: '/wr/career-memory',
        builder: (context, state) => WrCareerMemoryScreen(),
      ),
      wrRoute(
        path: '/wr/growth/themes',
        builder: (context, state) => WrGrowthThemesScreen(),
      ),
      // Một chủ đề thực hành và toàn bộ chuỗi bước của nó.
      // Đặt SAU /wr/growth/themes để đường tĩnh không bị nuốt bởi :id.
      wrRoute(
        path: '/wr/growth/theme/:id',
        builder: (context, state) => WrPracticeThemeScreen(
          themeId: state.pathParameters['id']!,
        ),
      ),
      wrRoute(
        path: '/wr/growth/skills',
        builder: (context, state) => WrGrowthSkillsScreen(),
      ),

      // Ô hỏi về hành trình nghề nghiệp (họp khách 2026-07-29). Mở từ bong
      // bóng nổi ở mọi tab và từ một dòng dẫn trong tab Hành trình.
      wrRoute(
        path: '/wr/ask',
        builder: (context, state) => WrAskScreen(),
      ),

      // Trà Chiều Nghề Nghiệp — chương trình offline riêng (họp khách
      // 2026-07-29). Đường tĩnh '/lich' đặt trước để không đụng route khác.
      wrRoute(
        path: '/wr/tra-chieu',
        builder: (context, state) => WrTraChieuScreen(),
      ),
      wrRoute(
        path: '/wr/tra-chieu/lich',
        builder: (context, state) => WrTraChieuCalendarScreen(),
      ),
      wrRoute(
        path: '/wr/growth/journey',
        builder: (context, state) => WrGrowthJourneyScreen(),
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
      wrRoute(
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

      wrRoute(
        path: '/wr/payment',
        // Paywall đẩy kèm gói người dùng vừa chọn (năm hay tháng). Mở thẳng
        // đường dẫn này thì không có `extra` — màn tự lấy gói chọn sẵn.
        //
        // Bản iOS chặn ngay ở đây chứ không chỉ ẩn nút: màn QR là thứ Apple
        // cấm (Guideline 3.1.1), mà deep link `workreflection://wr/payment`
        // hay một `push` sót lại ở đâu đó vẫn tới được nếu chỉ ẩn nút.
        redirect: (context, state) =>
            ref.read(wrStorePolicyProvider).allowsVietQrCheckout
                ? null
                : '/wr/paywall',
        builder: (context, state) =>
            WrPaymentScreen(plan: state.extra as WrPremiumPricing?),
      ),

      wrRoute(
        path: '/wr/paywall',
        builder: (context, state) {
          final triggerStr = state.uri.queryParameters['trigger'];
          final trigger = switch (triggerStr) {
            'ai_insight' => PaywallTrigger.aiInsight,
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
        // Vỏ bốn tab cũng phải qua cầu dao: nhãn tab ("Hôm nay", "Hành trình")
        // cũng là `tr()`, và vỏ này nằm ở navigator gốc chứ không nằm trong
        // nhánh nào nên `wrRoute` bên dưới không với tới.
        builder: (context, state, navigationShell) => wrLocaleAware(
          context,
          ShellScreen(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              wrRoute(
                path: '/home',
                builder: (context, state) => WrHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              wrRoute(
                path: '/wr/discover',
                builder: (context, state) => WrDiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              wrRoute(
                path: '/wr/growth',
                builder: (context, state) => WrGrowthScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              wrRoute(
                path: '/wr/journey',
                builder: (context, state) => WrJourneyScreen(),
              ),
            ],
          ),
        ],
      ),

      // /profile — màn đẩy toàn màn hình, mở từ avatar (v1.6 §9.1).
      wrRoute(
        path: '/profile',
        builder: (context, state) => ProfileScreen(),
      ),

      // /wr/story — fullscreen push, uses root navigator implicitly (not nested in shell).
      wrRoute(
        path: '/wr/story',
        builder: (context, state) => WrStoryScreen(),
      ),

      // Thông tin công việc hiện tại — Hai Lớp v1.6 §XI.
      wrRoute(
        path: '/wr/work-info',
        builder: (context, state) => WrWorkInfoScreen(),
      ),
      // "Cùng tạo JD của bạn" — 5 bước ngắn (changelog 24/08 §6). Mở từ thẻ dẫn
      // ở màn Thông tin công việc, không có lối vào nào khác.
      wrRoute(
        path: '/wr/jd-builder',
        builder: (context, state) => WrJdBuilderScreen(),
      ),

      // Diễn giải sâu & xu hướng (changelog 24/08 §7). Trước bản này, nút "Mở
      // khoá" của tính năng chỉ dẫn tới Paywall chung — mua xong không có màn
      // đích nào. Đây là màn đích đó.
      wrRoute(
        path: '/wr/sca-deep-dive',
        builder: (context, state) => WrScaDeepDiveScreen(),
      ),

      // Khảo sát tổ chức (ESI + eNPS) — mockup Sprint 2, mở từ màn Hồ sơ.
      //
      // Ba màn tách rời chứ không một màn nhiều bước: màn kết quả phải mở lại
      // được từ Hồ sơ mà không phải đi qua bài khảo sát.
      wrRoute(
        path: '/wr/org-survey',
        builder: (context, state) => WrOrgSurveyIntroScreen(),
      ),
      wrRoute(
        path: '/wr/org-survey/flow',
        builder: (context, state) => WrOrgSurveyFlowScreen(),
      ),
      wrRoute(
        path: '/wr/org-survey/result',
        // `extra` là bản vừa gửi xong, để không phải chờ một vòng đọc lại. Mở
        // từ Hồ sơ thì không có extra và màn tự đọc bản gần nhất.
        builder: (context, state) => WrOrgSurveyResultScreen(
          response: state.extra is OrgSurveyResponse
              ? state.extra! as OrgSurveyResponse
              : null,
        ),
      ),

      // Thư viện Nội dung Cảm xúc — Hai Lớp v1.6 §VIII.
      // §8.3: miễn phí cho mọi người dùng, không phân lớp Free/Paid.
      wrRoute(
        path: '/wr/mood-library',
        builder: (context, state) => WrMoodLibraryScreen(),
      ),
      wrRoute(
        path: '/wr/mood-content/:id',
        builder: (context, state) => WrMoodReaderScreen(
          contentId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
