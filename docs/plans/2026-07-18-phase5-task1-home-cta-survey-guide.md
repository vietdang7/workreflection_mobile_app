# Phase 5 Task 1 — Home Survey CTA + Survey Guide Screen

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a state-aware survey CTA card on HomeScreen (below check-in, above system notice) and insert a SurveyGuideScreen step between SurveyIntroScreen and SurveyQuestionsScreen.

**Architecture:**
- Home CTA: new `_SurveyCta` widget in `home_screen.dart`, powered by `latestReportProvider` imported from `survey_providers.dart`. No new providers needed — `latestReportProvider` already exists and returns `CcReportFull?`. Loading/error → `SizedBox.shrink()`.
- Survey Guide: new `SurveyGuideScreen` in `lib/features/survey/presentation/survey_guide_screen.dart`. Route `/survey/guide` added to `app_router.dart`. SurveyIntroScreen CTA retargeted from `/survey/questions` → `/survey/guide`. Guide CTA goes to `/survey/questions` (preserving the same provider resets).
- All strings in VI+EN `.arb` files then `flutter gen-l10n`.

**Tech Stack:** Flutter 3, Riverpod FutureProvider, GoRouter, flutter gen-l10n, WrCard design system (`WrCardDark`, `WrCardMinimal`, `WrPillButton`, `WrActionLink`, `WrEyebrow`).

---

### Task 1: Add l10n keys for Home CTA + Survey Guide

**Files:**
- Modify: `lib/l10n/app_vi.arb` (after `"homeRetry"` key block, around line 153)
- Modify: `lib/l10n/app_en.arb` (same region)

**Step 1: Add VI keys for Home CTA + Survey Guide**

Open `lib/l10n/app_vi.arb`. After the line:

```
  "homeRetry": "Thử lại",
```

Insert (before `"homeSystemNoticeQuote"` — it should be the next key after the insert):

```json
  "homeCtaSurveyEyebrow": "Phản chiếu công việc",
  "homeCtaSurveyTitle": "Làm bài phản chiếu",
  "homeCtaSurveySubtitle": "Nhìn lại trải nghiệm công việc của bạn để hiểu rõ hơn.",
  "homeCtaSurveyButton": "Bắt đầu ngay",
  "homeCtaReportTitle": "Xem báo cáo mới nhất",
  "homeCtaReportSubtitle": "Bạn đã hoàn thành bài phản chiếu. Xem kết quả của mình.",
  "homeCtaReportButton": "Xem báo cáo",
  "homeCtaRetakeSurvey": "Làm lại bài phản chiếu",
```

**Step 2: Add EN keys for Home CTA + Survey Guide**

Open `lib/l10n/app_en.arb`. After:

```
  "homeRetry": "Retry",
```

Insert:

```json
  "homeCtaSurveyEyebrow": "Work Reflection",
  "homeCtaSurveyTitle": "Take reflection survey",
  "homeCtaSurveySubtitle": "Look back at your work experience to understand yourself better.",
  "homeCtaSurveyButton": "Start now",
  "homeCtaReportTitle": "View latest report",
  "homeCtaReportSubtitle": "You have completed the reflection survey. View your results.",
  "homeCtaReportButton": "View report",
  "homeCtaRetakeSurvey": "Retake survey",
```

**Step 3: Add Survey Guide VI keys**

In `app_vi.arb`, after the `"profileCheckinHistory"` key (the last key before closing `}`), add:

```json
  "surveyGuideEyebrow": "Hướng dẫn",
  "surveyGuideFreeTitle": "Work Reflection – Phản chiếu trải nghiệm công việc cá nhân",
  "surveyGuideFreeIntro": "Chào mừng bạn đến với hành trình nhìn lại trải nghiệm công việc cá nhân.",
  "surveyGuideFreeDescription": "Work Reflection là công cụ giúp người đi làm nhìn lại môi trường và trải nghiệm công việc của mình một cách có hệ thống.",
  "surveyGuideFreeDetails": "Phiên bản miễn phí gồm 15 câu hỏi cho phép bạn thực hiện khảo sát nhanh. Sau khi hoàn thành, bạn sẽ nhận được một báo cáo phản chiếu tổng quan, giúp bạn:",
  "surveyGuideFreeBenefit1": "Nhìn thấy bức tranh chung.",
  "surveyGuideFreeBenefit2": "Nhận diện những điểm cần điều chỉnh.",
  "surveyGuideFreeBenefit3": "Có cơ sở rõ ràng hơn để suy nghĩ về bước đi tiếp theo trong công việc.",
  "surveyGuideFreeNote": "Work Reflection không nhằm đánh giá con người, mà giúp bạn hiểu cách hệ thống công việc đang vận hành xung quanh mình.",
  "surveyGuideFreeClosing": "Phiên bản miễn phí phù hợp khi bạn muốn bắt đầu nhìn lại công việc một cách nhẹ nhàng, trước khi đi sâu hơn với các phân tích nâng cao.",
  "surveyGuidePremiumTitle": "Work Reflection Premium – Phản chiếu sâu để định hướng rõ",
  "surveyGuidePremiumIntro": "Work Reflection Premium là phiên bản phân tích nâng cao dành cho người đi làm muốn nhìn lại công việc một cách toàn diện và có chiều sâu hơn.",
  "surveyGuidePremiumDetails": "Phiên bản Premium giúp bạn:",
  "surveyGuidePremiumBenefit1": "Phân tích chi tiết mức độ rõ ràng trong vai trò, kỳ vọng và cơ chế phối hợp",
  "surveyGuidePremiumBenefit2": "Nhận diện chất lượng đối thoại, phản hồi và an toàn tâm lý trong môi trường làm việc",
  "surveyGuidePremiumBenefit3": "Đánh giá mức độ phát triển, động lực và sự phù hợp giữa cá nhân – công việc – tổ chức",
  "surveyGuidePremiumBenefit4": "Xác định các điểm nghẽn cốt lõi thay vì chỉ thấy triệu chứng bề mặt",
  "surveyGuidePremiumClosing": "Work Reflection Premium giúp bạn có một khung nhìn rõ ràng hơn để tự đưa ra quyết định.",
  "surveyGuidePremiumReportDesc": "Sau khi hoàn thành, bạn nhận được báo cáo phản chiếu chuyên sâu với:",
  "surveyGuidePremiumReport1": "Điểm số theo từng nhóm yếu tố",
  "surveyGuidePremiumReport2": "Diễn giải ý nghĩa từng khu vực",
  "surveyGuidePremiumReport3": "Gợi ý định hướng suy nghĩ và hành động cho giai đoạn tiếp theo",
  "surveyGuideCta": "Bắt đầu"
```

**Step 4: Add Survey Guide EN keys**

In `app_en.arb`, after `"profileCheckinHistory"` (last key before `}`):

```json
  "surveyGuideEyebrow": "Guide",
  "surveyGuideFreeTitle": "Work Reflection – Reflect on your personal work experience",
  "surveyGuideFreeIntro": "Welcome to the journey of looking back at your personal work experience.",
  "surveyGuideFreeDescription": "Work Reflection is a tool that helps professionals systematically look back at their work environment and experience.",
  "surveyGuideFreeDetails": "The free version includes 15 questions for a quick survey. Upon completion, you will receive an overview reflection report, helping you:",
  "surveyGuideFreeBenefit1": "See the big picture.",
  "surveyGuideFreeBenefit2": "Identify areas for adjustment.",
  "surveyGuideFreeBenefit3": "Have a clearer basis for thinking about the next step in your career.",
  "surveyGuideFreeNote": "Work Reflection is not intended to evaluate people, but to help you understand how the work system operates around you.",
  "surveyGuideFreeClosing": "The free version is suitable when you want to start looking back at your work gently, before going deeper with advanced analysis.",
  "surveyGuidePremiumTitle": "Work Reflection Premium – Deep reflection for clear orientation",
  "surveyGuidePremiumIntro": "Work Reflection Premium is an advanced analysis version for professionals who want to look back at their work comprehensively and in depth.",
  "surveyGuidePremiumDetails": "The Premium version helps you:",
  "surveyGuidePremiumBenefit1": "Analyze in detail the clarity of roles, expectations, and coordination mechanisms",
  "surveyGuidePremiumBenefit2": "Identify the quality of dialogue, feedback, and psychological safety in the work environment",
  "surveyGuidePremiumBenefit3": "Evaluate the level of development, motivation, and fit between individual – work – organization",
  "surveyGuidePremiumBenefit4": "Identify core bottlenecks rather than just seeing surface symptoms",
  "surveyGuidePremiumClosing": "Work Reflection Premium gives you a clearer framework to make your own decisions.",
  "surveyGuidePremiumReportDesc": "Upon completion, you will receive an in-depth reflection report with:",
  "surveyGuidePremiumReport1": "Scores for each group of factors",
  "surveyGuidePremiumReport2": "Interpretation of the meaning of each area",
  "surveyGuidePremiumReport3": "Suggestions for thinking and action orientation for the next phase",
  "surveyGuideCta": "Start"
```

**Step 5: Regenerate l10n**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter gen-l10n
```

Expected: exits 0 with no errors. New getter methods become available in `AppLocalizations`.

**Step 6: Verify new getters exist**

```bash
grep -c "surveyGuide\|homeCtaSurvey\|homeCtaReport" /home/duythong/Documents/DuyThong/appmobileworkreflection/lib/l10n/app_localizations_vi.dart
```

Expected: count ≥ 20.

**Step 7: Commit**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection
git add lib/l10n/app_vi.arb lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_vi.dart lib/l10n/app_localizations_en.dart
git commit -m "feat(p5): add l10n keys for home survey CTA and survey guide screen"
```

---

### Task 2: Create SurveyGuideScreen

**Files:**
- Create: `lib/features/survey/presentation/survey_guide_screen.dart`

**Background:** The web Guide.tsx shows type-aware content: FREE (title, intro, description, details, 3 benefits, note, closing) or PREMIUM (title, intro, details, 4 benefits, premiumReportDesc, 3 premiumReport items, closing). Mobile mirrors this with `surveyTypeProvider` (already exists in `survey_providers.dart`). The guide CTA button goes to `/survey/questions` — same target as intro previously used. The guide does NOT reset survey state (that already happened in SurveyIntroScreen CTA). No TTS in mobile version (skip audio).

**Step 1: Write failing test first**

Open `test/features/survey_test.dart` and add a new group at the end (before the last `}`):

```dart
// ---------------------------------------------------------------------------
// SurveyGuideScreen tests
// ---------------------------------------------------------------------------

group('SurveyGuideScreen', () {
  late FakeSurveyRepository repo;

  setUp(() {
    repo = FakeSurveyRepository();
    repo.seedRole('user'); // FREE
  });

  testWidgets('FREE: shows free title', (tester) async {
    await tester.pumpWidget(_wrap(const SurveyGuideScreen(), repo: repo));
    await tester.pumpAndSettle();

    // surveyGuideFreeTitle contains "Work Reflection"
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data?.contains('Work Reflection') ?? false),
      ),
      findsAtLeast(1),
    );
  });

  testWidgets('FREE: shows guide eyebrow', (tester) async {
    await tester.pumpWidget(_wrap(const SurveyGuideScreen(), repo: repo));
    await tester.pumpAndSettle();

    // WrEyebrow uppercases → "HƯỚNG DẪN"
    expect(find.textContaining('HƯỚNG DẪN'), findsOneWidget);
  });

  testWidgets('FREE: shows 3 benefit items', (tester) async {
    await tester.pumpWidget(_wrap(const SurveyGuideScreen(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guide_benefit_0')), findsOneWidget);
    expect(find.byKey(const Key('guide_benefit_1')), findsOneWidget);
    expect(find.byKey(const Key('guide_benefit_2')), findsOneWidget);
  });

  testWidgets('FREE: CTA button navigates to /survey/questions', (tester) async {
    final navigated = <String>[];
    final router = GoRouter(
      initialLocation: '/survey/guide',
      routes: [
        GoRoute(
          path: '/survey/guide',
          builder: (_, __) => const SurveyGuideScreen(),
        ),
        GoRoute(
          path: '/survey/questions',
          builder: (_, __) {
            navigated.add('/survey/questions');
            return const Scaffold(body: Text('questions'));
          },
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [surveyRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('vi')],
        locale: const Locale('vi'),
      ),
    ));
    await tester.pumpAndSettle();

    // Tap the CTA (ElevatedButton rendered by WrPillButton)
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();

    expect(navigated, contains('/survey/questions'));
  });

  testWidgets('PREMIUM: shows 4 benefit items', (tester) async {
    repo.seedRole('premium');
    await tester.pumpWidget(_wrap(const SurveyGuideScreen(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guide_benefit_0')), findsOneWidget);
    expect(find.byKey(const Key('guide_benefit_1')), findsOneWidget);
    expect(find.byKey(const Key('guide_benefit_2')), findsOneWidget);
    expect(find.byKey(const Key('guide_benefit_3')), findsOneWidget);
  });
});
```

Also add the import at the top of the file with the other survey imports:

```dart
import 'package:workreflection_mobile/features/survey/presentation/survey_guide_screen.dart';
```

**Step 2: Run test to verify it fails**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/survey_test.dart --name "SurveyGuideScreen" 2>&1 | tail -20
```

Expected: FAIL with "Target of URI doesn't exist" or similar — `survey_guide_screen.dart` doesn't exist yet.

**Step 3: Write minimal implementation**

Create `lib/features/survey/presentation/survey_guide_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/survey_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../l10n/app_localizations.dart';
import '../survey_providers.dart';

class SurveyGuideScreen extends ConsumerWidget {
  const SurveyGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final typeAsync = ref.watch(surveyTypeProvider);

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: typeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (type) => _GuideBody(type: type),
      ),
    );
  }
}

class _GuideBody extends StatelessWidget {
  const _GuideBody({required this.type});

  final SurveyType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = type == SurveyType.premium;

    final title = isPremium
        ? l10n.surveyGuidePremiumTitle
        : l10n.surveyGuideFreeTitle;
    final intro = isPremium
        ? l10n.surveyGuidePremiumIntro
        : l10n.surveyGuideFreeIntro;
    final details = isPremium
        ? l10n.surveyGuidePremiumDetails
        : l10n.surveyGuideFreeDetails;
    final benefits = isPremium
        ? [
            l10n.surveyGuidePremiumBenefit1,
            l10n.surveyGuidePremiumBenefit2,
            l10n.surveyGuidePremiumBenefit3,
            l10n.surveyGuidePremiumBenefit4,
          ]
        : [
            l10n.surveyGuideFreeBenefit1,
            l10n.surveyGuideFreeBenefit2,
            l10n.surveyGuideFreeBenefit3,
          ];
    final closing = isPremium
        ? l10n.surveyGuidePremiumClosing
        : l10n.surveyGuideFreeClosing;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          WrEyebrow(l10n.surveyGuideEyebrow),
          const SizedBox(height: 12),
          Text(title, style: WrTextStyles.hLarge),
          const SizedBox(height: 16),
          Text(intro, style: WrTextStyles.body),
          if (!isPremium) ...[
            const SizedBox(height: 8),
            Text(l10n.surveyGuideFreeDescription, style: WrTextStyles.body),
          ],
          const SizedBox(height: 8),
          Text(details, style: WrTextStyles.body),
          const SizedBox(height: 16),
          ...benefits.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  key: Key('guide_benefit_${e.key}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 18, color: WrColors.teal),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(e.value, style: WrTextStyles.body)),
                  ],
                ),
              )),
          if (isPremium) ...[
            const SizedBox(height: 8),
            Text(l10n.surveyGuidePremiumReportDesc,
                style: WrTextStyles.body),
            const SizedBox(height: 10),
            ...[
              l10n.surveyGuidePremiumReport1,
              l10n.surveyGuidePremiumReport2,
              l10n.surveyGuidePremiumReport3,
            ].asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 18, color: WrColors.coral),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(e.value, style: WrTextStyles.body)),
                    ],
                  ),
                )),
          ],
          if (!isPremium) ...[
            const SizedBox(height: 8),
            Text(
              l10n.surveyGuideFreeNote,
              style: WrTextStyles.body.copyWith(
                fontStyle: FontStyle.italic,
                color: WrColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(closing, style: WrTextStyles.body),
          const SizedBox(height: 32),
          WrPillButton(
            label: l10n.surveyGuideCta,
            onPressed: () => context.push('/survey/questions'),
            variant: WrPillVariant.coral,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
```

**Step 4: Run test to verify it passes**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/survey_test.dart --name "SurveyGuideScreen" 2>&1 | tail -20
```

Expected: all SurveyGuideScreen tests PASS.

**Step 5: Commit**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection
git add lib/features/survey/presentation/survey_guide_screen.dart test/features/survey_test.dart
git commit -m "feat(p5): add SurveyGuideScreen with FREE/PREMIUM content + widget tests"
```

---

### Task 3: Register /survey/guide route + retarget SurveyIntroScreen CTA

**Files:**
- Modify: `lib/core/router/app_router.dart` (add route around line 130)
- Modify: `lib/features/survey/presentation/survey_intro_screen.dart` (line 120: `context.push('/survey/questions')` → `context.push('/survey/guide')`)

**Step 1: Add navigation test for intro→guide→questions flow**

In `test/features/survey_test.dart`, inside the `SurveyIntroScreen — surveyIdInProgress reset` group, add a second test after the first:

```dart
testWidgets(
    'tapping CTA navigates to /survey/guide (not /survey/questions)',
    (tester) async {
  final repo = FakeSurveyRepository();
  repo.seedRole('user');
  repo.seedQuestions([]);
  repo.seedLikertOptions({});

  final navigated = <String>[];
  final router = GoRouter(
    initialLocation: '/survey/intro',
    routes: [
      GoRoute(
        path: '/survey/intro',
        builder: (_, __) => const SurveyIntroScreen(),
      ),
      GoRoute(
        path: '/survey/guide',
        builder: (_, __) {
          navigated.add('/survey/guide');
          return const Scaffold(body: Text('guide'));
        },
      ),
      GoRoute(
        path: '/survey/questions',
        builder: (_, __) {
          navigated.add('/survey/questions');
          return const Scaffold(body: Text('questions'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        surveyRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('vi')],
        locale: const Locale('vi'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final ctaFinder = find.byType(ElevatedButton);
  await tester.tap(ctaFinder.first);
  await tester.pumpAndSettle();

  expect(navigated, contains('/survey/guide'));
  expect(navigated, isNot(contains('/survey/questions')));
});
```

**Step 2: Run test to verify it fails**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/survey_test.dart --name "navigates to /survey/guide" 2>&1 | tail -20
```

Expected: FAIL — currently navigates to `/survey/questions`.

**Step 3: Register the route in app_router.dart**

In `lib/core/router/app_router.dart`, add the import at the top:

```dart
import '../../features/survey/presentation/survey_guide_screen.dart';
```

Then, after the `/survey` route block (around line 130), add the `/survey/guide` route. It MUST be declared before `/survey/questions` (to avoid any prefix conflicts):

```dart
GoRoute(
  path: '/survey/guide',
  builder: (context, state) => const SurveyGuideScreen(),
),
```

The full survey section should now read:

```dart
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
// ... rest unchanged
```

**Step 4: Retarget SurveyIntroScreen CTA**

In `lib/features/survey/presentation/survey_intro_screen.dart`, change line 120:

```dart
// Before:
context.push('/survey/questions');
// After:
context.push('/survey/guide');
```

The full CTA `onPressed` block stays identical otherwise — the state resets (`surveyAnswersProvider`, `currentQuestionIndexProvider`, `surveyIdInProgressProvider`) all still happen before the push, just the destination changes.

**Step 5: Run test to verify it passes**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/survey_test.dart --name "navigates to /survey/guide" 2>&1 | tail -20
```

Expected: PASS. Also verify the existing `surveyIdInProgress reset` test still passes:

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/survey_test.dart --name "SurveyIntroScreen" 2>&1 | tail -20
```

**Step 6: Commit**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection
git add lib/core/router/app_router.dart lib/features/survey/presentation/survey_intro_screen.dart test/features/survey_test.dart
git commit -m "feat(p5): register /survey/guide route, retarget intro CTA intro→guide→questions"
```

---

### Task 4: Add _SurveyCta widget to HomeScreen

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`

**Background:**
- Layout order (reading existing code): Header → `_CheckinSection` (mood grid) → `_SystemNoticeCard` (dark card, recurring situation) → `_SuggestionSection` → `_InsightSection`.
- New CTA placement: between `_CheckinSection` and `_SystemNoticeCard`. This satisfies "below greeting/mood check-in, above recurring-situation card."
- Provider: import `latestReportProvider` and `myReportsProvider` from `survey_providers.dart`. Use `myReportsProvider` to determine "has report" (non-empty list). The `latestReportProvider` gives the full report to extract the ID for the view-latest link.
- State:
  - Loading → `SizedBox.shrink()`
  - Error → `SizedBox.shrink()`
  - Data with empty reports list → Big coral/dark CTA: "Làm bài phản chiếu" → `context.push('/survey')`
  - Data with ≥1 report → Smaller card: "Xem báo cáo mới nhất" button → `/survey/report/<latestReportId>` + secondary link "Làm lại bài phản chiếu" → `context.push('/survey')`
- Keys: `home_survey_cta_no_report` (big card), `home_survey_cta_has_report` (small card), `home_survey_cta_start_btn`, `home_survey_cta_view_report_btn`, `home_survey_cta_retake_link`.

**Step 1: Write failing tests in test/features/home_test.dart**

Add a new import at the top of the file (after existing imports):

```dart
import 'package:workreflection_mobile/core/data/survey_repository.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
```

Change `_wrap` to also accept an optional survey repo override:

```dart
Widget _wrap(Widget child, WrRepository repo, {SurveyRepository? surveyRepo}) {
  return ProviderScope(
    overrides: [
      wrRepositoryProvider.overrideWithValue(repo),
      if (surveyRepo != null)
        surveyRepositoryProvider.overrideWithValue(surveyRepo),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: child,
    ),
  );
}
```

Then add imports at the top of the test file:

```dart
import 'package:workreflection_mobile/core/data/survey_repository.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import '../support/fake_survey_repository.dart';
```

Add new test group inside `group('HomeScreen widget', ...)`, after the last existing test:

```dart
group('Survey CTA card', () {
  CcReportSummary _summary({String id = 'r1'}) => CcReportSummary(
        id: id,
        surveyId: 'sv1',
        userId: 'u1',
        scoreTotal: 3.8,
        scoreLevel: ScoreLevel.good,
        surveyType: SurveyType.free,
        createdAt: DateTime(2026, 7, 18),
      );

  testWidgets('shows big CTA card when user has no reports', (tester) async {
    final wr = FakeWrRepository();
    final survey = FakeSurveyRepository();
    survey.seedRole('user');
    survey.seedReportSummaries([]);

    await _pumpLarge(tester, _wrap(const HomeScreen(), wr, surveyRepo: survey));

    expect(find.byKey(const Key('home_survey_cta_no_report')), findsOneWidget);
    expect(find.byKey(const Key('home_survey_cta_has_report')), findsNothing);
  });

  testWidgets('shows view-latest card when user has reports', (tester) async {
    final wr = FakeWrRepository();
    final survey = FakeSurveyRepository();
    survey.seedRole('user');
    survey.seedReportSummaries([_summary(id: 'r1')]);
    survey.seedLatestReport(CcReportFull(
      id: 'r1',
      surveyId: 'sv1',
      userId: 'u1',
      scoreTotal: 3.8,
      scoreStructure: 4.0,
      scoreCulture: 3.5,
      scoreActivity: 3.9,
      bottleneckLayer: SurveyLayer.culture,
      scoreLevel: ScoreLevel.good,
      createdAt: DateTime(2026, 7, 18),
    ));

    await _pumpLarge(tester, _wrap(const HomeScreen(), wr, surveyRepo: survey));

    expect(find.byKey(const Key('home_survey_cta_has_report')), findsOneWidget);
    expect(find.byKey(const Key('home_survey_cta_no_report')), findsNothing);
  });

  testWidgets('CTA card hidden on error (no crash)', (tester) async {
    final wr = FakeWrRepository();
    final survey = FakeSurveyRepository();
    survey.seedRole('user');
    survey.setMyReportsError(Exception('network error'));

    await _pumpLarge(tester, _wrap(const HomeScreen(), wr, surveyRepo: survey));

    expect(find.byKey(const Key('home_survey_cta_no_report')), findsNothing);
    expect(find.byKey(const Key('home_survey_cta_has_report')), findsNothing);
  });

  testWidgets('start button key present in no-report state', (tester) async {
    final wr = FakeWrRepository();
    final survey = FakeSurveyRepository();
    survey.seedRole('user');
    survey.seedReportSummaries([]);

    await _pumpLarge(tester, _wrap(const HomeScreen(), wr, surveyRepo: survey));

    expect(find.byKey(const Key('home_survey_cta_start_btn')), findsOneWidget);
  });

  testWidgets('retake link present when user has reports', (tester) async {
    final wr = FakeWrRepository();
    final survey = FakeSurveyRepository();
    survey.seedRole('user');
    survey.seedReportSummaries([_summary(id: 'r1')]);
    survey.seedLatestReport(CcReportFull(
      id: 'r1',
      surveyId: 'sv1',
      userId: 'u1',
      scoreTotal: 3.8,
      scoreStructure: 4.0,
      scoreCulture: 3.5,
      scoreActivity: 3.9,
      bottleneckLayer: SurveyLayer.culture,
      scoreLevel: ScoreLevel.good,
      createdAt: DateTime(2026, 7, 18),
    ));

    await _pumpLarge(tester, _wrap(const HomeScreen(), wr, surveyRepo: survey));

    expect(find.byKey(const Key('home_survey_cta_retake_link')), findsOneWidget);
  });
});
```

**Step 2: Run tests to verify they fail**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/home_test.dart --name "Survey CTA" 2>&1 | tail -30
```

Expected: FAIL — `CcReportSummary` constructor args may not match (check actual model), and the widget keys don't exist yet.

**IMPORTANT — Check CcReportSummary constructor before writing test code.** Run:

```bash
grep -n "class CcReportSummary\|CcReportSummary(" /home/duythong/Documents/DuyThong/appmobileworkreflection/lib/core/models/survey_models.dart | head -10
```

Adjust the `_summary()` helper in the test to match the actual constructor. Typically check `survey_history_screen.dart` or `fake_survey_repository.dart` for usage patterns.

**Step 3: Write minimal implementation**

In `lib/features/home/presentation/home_screen.dart`:

1. Add import at the top with other imports:

```dart
import '../../../features/survey/survey_providers.dart';
```

2. In the `build` method of `HomeScreen`, add `_SurveyCta()` to the `SliverChildListDelegate` list **between** `_CheckinSection()` and `_SystemNoticeCard()`:

```dart
delegate: SliverChildListDelegate([
  _CheckinSection(),
  const SizedBox(height: 28),
  _SurveyCta(),           // NEW — between check-in and system notice
  const SizedBox(height: 28),
  _SystemNoticeCard(),
  const SizedBox(height: 28),
  _SuggestionSection(),
  const SizedBox(height: 28),
  _InsightSection(),
  const SizedBox(height: 80),
]),
```

3. Add the `_SurveyCta` widget class after the `_SystemNoticeCard` class:

```dart
// ---------------------------------------------------------------------------
// Survey CTA card — state-aware: no report → prominent; has report → compact
// ---------------------------------------------------------------------------

class _SurveyCta extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reportsAsync = ref.watch(myReportsProvider);
    final latestAsync = ref.watch(latestReportProvider);

    return reportsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (reports) {
        if (reports.isEmpty) {
          // No report yet — prominent dark CTA
          return WrCardDark(
            key: const Key('home_survey_cta_no_report'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrEyebrow(l10n.homeCtaSurveyEyebrow),
                const SizedBox(height: 12),
                Text(
                  l10n.homeCtaSurveyTitle,
                  style: WrTextStyles.hLarge.copyWith(color: WrColors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.homeCtaSurveySubtitle,
                  style: WrTextStyles.body.copyWith(
                    color: WrColors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 20),
                WrPillButton(
                  key: const Key('home_survey_cta_start_btn'),
                  label: l10n.homeCtaSurveyButton,
                  onPressed: () => context.push('/survey'),
                  variant: WrPillVariant.coral,
                ),
              ],
            ),
          );
        }

        // Has reports — compact card
        return latestAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (latest) {
            if (latest == null) return const SizedBox.shrink();
            return WrCardMinimal(
              key: const Key('home_survey_cta_has_report'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WrEyebrow(l10n.homeCtaSurveyEyebrow),
                  const SizedBox(height: 12),
                  Text(
                    l10n.homeCtaReportTitle,
                    style: WrTextStyles.hMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.homeCtaReportSubtitle,
                    style: WrTextStyles.body.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  WrPillButton(
                    key: const Key('home_survey_cta_view_report_btn'),
                    label: l10n.homeCtaReportButton,
                    onPressed: () =>
                        context.push('/survey/report/${latest.id}'),
                    variant: WrPillVariant.navy,
                  ),
                  const SizedBox(height: 12),
                  WrActionLink(
                    key: const Key('home_survey_cta_retake_link'),
                    label: l10n.homeCtaRetakeSurvey,
                    onTap: () => context.push('/survey'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
```

**Step 4: Run tests to verify they pass**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test test/features/home_test.dart --name "Survey CTA" 2>&1 | tail -30
```

Expected: all 5 Survey CTA tests PASS.

**Step 5: Commit**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection
git add lib/features/home/presentation/home_screen.dart test/features/home_test.dart
git commit -m "feat(p5): add state-aware survey CTA card to HomeScreen"
```

---

### Task 5: Gate checks — analyze + full test suite

**Step 1: Run flutter analyze**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter analyze 2>&1 | tail -10
```

Expected: `No issues found!` (0 issues). Fix any issues before proceeding.

**Step 2: Run full test suite**

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection && flutter test 2>&1 | tail -20
```

Expected: all tests pass (≥497 + newly added tests). Fix any failures before proceeding.

**Step 3: Run gitnexus detect_changes (if MCP available)**

The Claude CLAUDE.md instructions say: MUST run `gitnexus_detect_changes()` before committing. Use the MCP tool if available. Verify the changed files match: `lib/l10n/`, `lib/features/home/`, `lib/features/survey/`, `lib/core/router/`, `test/features/`.

**Step 4: Final commit**

If all gates are green, make a final commit combining the gate-verified state:

```bash
cd /home/duythong/Documents/DuyThong/appmobileworkreflection
git add -p  # review what's left unstaged
git commit -m "feat(p5): home survey CTA + survey guide step (task 1)"
```

**Step 5: Paste gate output for Fable**

Paste the full output of both `flutter analyze` and `flutter test` tails into the report.

---

## Key Decisions Documented

1. **Placement of CTA**: Below `_CheckinSection`, above `_SystemNoticeCard`. Reading `home_screen.dart:36-45`, the list order is: check-in → system notice → suggestion → insight. The CTA goes between check-in and system notice — most prominent position after the greeting/mood interaction.

2. **Provider reuse**: `myReportsProvider` (already in `survey_providers.dart:106`) used to detect "has report" state. `latestReportProvider` (line 97) used to get the ID for view-latest navigation. No new providers created.

3. **Guide content source**: `workreflection/src/i18n/translations/vi.ts:439-472` and `en.ts:439-472`. All keys reused exactly. Mobile adds `surveyGuideFreeDescription` (mapped from `free.description`) which is a FREE-only paragraph. Premium content omits `description` (matches web).

4. **Guide placement**: SurveyIntroScreen CTA → `/survey/guide` (not `/survey/questions`). Guide CTA → `/survey/questions`. Provider resets (answers, questionIndex, surveyIdInProgress) stay in SurveyIntroScreen's CTA handler — guide just navigates forward.

5. **Big card style**: `WrCardDark` (navy dark card with circle decoration) for no-report state (coral button inside). `WrCardMinimal` (cream card) for has-report state (navy button + coral action link).
