# WorkReflection Mobile (Flutter) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans / superpowers:subagent-driven-development to implement this plan task-by-task. Follow superpowers:test-driven-development for every logic task.

**Goal:** Build the WorkReflection Flutter app (Android+iOS) reproducing `complete-flow-fixed (4).html` with real Supabase-backed functionality.

**Architecture:** Feature-first Flutter app. Riverpod `AsyncNotifier`s over repository classes that wrap `supabase_flutter` queries. `go_router` with a session-aware redirect. Shared design-system widgets in `core/`. Vietnamese-first i18n via ARB.

**Tech Stack:** Flutter 3.41 / Dart 3.11, supabase_flutter, flutter_riverpod, go_router, google_fonts, shared_preferences, intl, flutter_localizations.

**Design doc:** `docs/plans/2026-07-17-workreflection-mobile-design.md` — read it first.
**Reference HTML:** `/home/duythong/Desktop/FileTam/workreflection/complete-flow-fixed (4).html` — the visual source of truth. All copy text is in Appendix A.

**Rules for the executor:**
- TDD for all logic (streak, repositories, providers). Widget tests per screen.
- After every task: `flutter analyze` must be clean; run the tests written; commit with a conventional message.
- Never hardcode colors/text inline in screens — use `WrColors`/`WrTextStyles` from core theme and the copy constants/l10n.
- All UI text in Vietnamese exactly as Appendix A (l10n keys, vi default; en translations may be literal for now).
- Supabase network calls are NOT exercised in tests — repositories take a `SupabaseClient` and tests use fakes at the repository-consumer boundary (fake repositories injected via Riverpod overrides).

---

## Task 0 (DONE BY ORCHESTRATOR, NOT SONNET): Supabase migration

The orchestrator (Fable) applies migration `create_wr_mobile_tables` via Supabase MCP: 7 tables `wr_mobile_profiles, wr_checkins, wr_insights, wr_recurring_situations, wr_development_themes, wr_practices, wr_timeline_events` per the design doc, all with RLS owner-only (`auth.uid() = user_id`) for select/insert/update/delete, plus a `seed_wr_sample_data()` SECURITY DEFINER function that inserts sample rows for `auth.uid()` if that user has no data yet (idempotent). Sonnet may assume these tables exist.

## Task 1: Scaffold Flutter project

**Files:** whole project at repo root (`/home/duythong/Documents/DuyThong/appmobileworkreflection`).

1. Run: `flutter create . --org app.workreflection --project-name workreflection_mobile --platforms android,ios`
2. Delete the counter test `test/widget_test.dart`.
3. Replace `pubspec.yaml` dependencies section:
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     flutter_localizations:
       sdk: flutter
     supabase_flutter: ^2.8.0
     flutter_riverpod: ^2.6.1
     go_router: ^14.6.0
     google_fonts: ^6.2.1
     shared_preferences: ^2.3.0
     intl: any
   dev_dependencies:
     flutter_test:
       sdk: flutter
     flutter_lints: ^5.0.0
   flutter:
     uses-material-design: true
     generate: true
   ```
4. Add `l10n.yaml` at root:
   ```yaml
   arb-dir: lib/l10n
   template-arb-file: app_vi.arb
   output-localization-file: app_localizations.dart
   ```
5. `flutter pub get` → resolves. `flutter analyze` → clean. Commit `chore: scaffold flutter project`.

Android note: set `minSdkVersion 23` (required by supabase auth deep links) in `android/app/build.gradle.kts` if lower. Add INTERNET permission is default in debug; add to main manifest: `<uses-permission android:name="android.permission.INTERNET"/>`.

## Task 2: Core theme + design tokens

**Files:** Create `lib/core/theme/wr_colors.dart`, `lib/core/theme/wr_theme.dart`. Test: `test/core/theme_test.dart`.

`wr_colors.dart` (complete):
```dart
import 'package:flutter/material.dart';

abstract final class WrColors {
  static const navy = Color(0xFF093774);
  static const coral = Color(0xFFFF6859);
  static const teal = Color(0xFF15B5B0);
  static const cream = Color(0xFFFFF3E6);
  static const dark = Color(0xFF2C335D);
  static const muted = Color(0xFF8A95A3);
  static const white = Color(0xFFFFFFFF);
  static const destructive = Color(0xFFFF3B30);
}
```

`wr_theme.dart`: `ThemeData wrTheme()` — Material3, scaffoldBackground white, `GoogleFonts.beVietnamProTextTheme()`, colorScheme seeded but with primary navy / secondary coral / tertiary teal. Text styles helper `WrTextStyles`: `eyebrow` (11, w700, letterSpacing .55, muted, uppercase applied by widget), `hLarge` (22, w700, navy), `hMedium` (16, w600, dark), `body` (14, dark, height 1.5, 80% opacity), `insightQuote` (20, italic, navy, height 1.45), `dateTitle` (32, w800, navy), `greeting` (14, muted).

Test asserts token values and that `wrTheme()` uses navy primary. Commit `feat: add design tokens and theme`.

## Task 3: Shared widgets

**Files:** `lib/core/widgets/` → `eyebrow.dart`, `wr_card.dart` (`WrCardMinimal` cream r20 p20; `WrCardDark` navy r20 p20 with decorative circle top-right like `.card-system::before`), `progress_track.dart` (3px track 10% navy bg, rounded, fill color param), `pill_button.dart` (full-width, padding v18, radius 100, colors navy/coral/teal variants, white 15 w600 label), `action_link.dart` (coral 13 w600/700 text + arrow icon), `section_divider.dart` (1px, coral 10%). Test: `test/core/widgets_test.dart` — pump each, assert basic structure/colors.

Commit `feat: add shared design-system widgets`.

## Task 4: Supabase bootstrap + env

**Files:** `lib/core/supabase/supabase_config.dart`, modify `lib/main.dart`.

```dart
abstract final class SupabaseConfig {
  static const url = 'https://sukpcxevcjnhiuyaoqxi.supabase.co';
  static const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1a3BjeGV2Y2puaGl1eWFvcXhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwOTEzNzgsImV4cCI6MjA4NTY2NzM3OH0.ty_jO27EX22OHMXzZT1Du28BXBFq-dcaNJqKkqfvlRE';
}
```

`main.dart`: `WidgetsFlutterBinding.ensureInitialized(); await Supabase.initialize(url:..., anonKey:...); runApp(ProviderScope(child: WrApp()));`. `lib/app.dart` holds `WrApp` (MaterialApp.router with theme + router + localization delegates). Commit.

## Task 5: l10n scaffolding + copy

**Files:** `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`.

Put ALL strings from Appendix A into `app_vi.arb` with the listed keys; `app_en.arb` with reasonable English. Run `flutter gen-l10n` (happens on build). Widgets access via `context.l10n` extension (`lib/core/l10n/l10n_ext.dart`). Commit.

## Task 6: Router + splash redirect

**Files:** `lib/core/router/app_router.dart`, `lib/features/splash/splash_screen.dart`. Test: `test/core/router_test.dart`.

Routes: `/splash`, `/onboarding`, `/auth` (login/register in one screen with toggle), `/home` (StatefulShellRoute with 5 branches: `/home`, `/understand`, `/develop`, `/journey`, `/profile`). Redirect logic in a testable pure function:
```dart
String? computeRedirect({required bool hasSession, required bool seenOnboarding, required String location}) { ... }
```
Rules: no session & !seenOnboarding & not on /onboarding → /onboarding; no session & seenOnboarding & not on /auth → /auth; session & location in {/splash,/onboarding,/auth} → /home. `seenOnboarding` persisted in SharedPreferences. TDD the pure function (≥6 cases). Commit.

## Task 7: Onboarding feature

**Files:** `lib/features/onboarding/presentation/onboarding_screen.dart` (+ step widgets), `lib/features/onboarding/onboarding_state.dart` (Riverpod: current step, selected situation). Test: `test/features/onboarding_test.dart`.

3 steps per HTML: logo image (export the SVG logo — recreate as a simple `CustomPaint` OR bundle `assets/logo.svg`? Use **flutter_svg NOT needed**: create `assets/images/logo.png` is not available — instead implement `WrLogo` as a `CustomPaint` drawing only the icon mark (the two interlocking rounded squares + circles, first 6 paths of the SVG) plus wordmark as styled text "WorkReflection" in navy/coral. Keep it simple and consistent.)
- Step 1 tag `Reflection` navy; Step 2 tag `Understand` coral with 4 selectable situation rows (selection highlights coral border/bg); Step 3 tag `Grow` teal with 3 promise cards.
- Dots: 8px circles, active = 24px pill coral, done = navy 25%.
- CTAs: navy "Tiếp tục", coral "Bắt đầu ngay", teal "Vào WorkReflection". Step 3 CTA → set `seenOnboarding=true`, stash selected situation in state, go `/auth`.
Widget tests: renders step 1, taps through to step 3, situation selection toggles. Commit.

## Task 8: Auth feature

**Files:** `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/presentation/auth_screen.dart`, providers. Test: `test/features/auth_test.dart`.

`AuthRepository(SupabaseClient)`: `signIn(email, password)`, `signUp(email, password, displayName)`, `signInWithGoogle()` (uses `supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: 'app.workreflection.mobile://login-callback')`), `signOut()`, `currentSession`. After successful signUp/signIn: upsert `wr_mobile_profiles` (display_name, onboarding_situation from onboarding state) and RPC `seed_wr_sample_data`.
Screen: toggle login/register, email+password fields (+name on register), pill button coral submit, text button switch mode, "hoặc" divider, outlined Google button, error text inline, loading state. On success → `/home`.
Android deep link: add intent-filter scheme `app.workreflection.mobile` in AndroidManifest; iOS CFBundleURLTypes in Info.plist.
Widget tests with a fake repository via provider override: renders login, switches to register, shows error on failure, calls signIn with typed values. Commit.

## Task 9: Shell + tab bar

**Files:** `lib/features/shell/shell_screen.dart` + `wr_tab_bar.dart`. Test: `test/features/shell_test.dart`.

Custom bottom bar (NOT Material BottomNavigationBar look): height 64 + safe-area, white 95% with top hairline navy 8%, 5 items with icons (use Icons.home_outlined/person_outline/trending_up/menu/settings_outlined equivalents to HTML tabler icons), active = coral icon + 4px coral dot below, inactive muted. Each screen has `top-area` header pattern: greeting (14 muted) + big title (32 w800 navy). Tests: 5 tabs render, tapping switches branch. Commit.

## Task 10: Domain models + fake data layer

**Files:** `lib/features/*/data/models.dart` per feature or `lib/core/models/` (choose one: `lib/core/models/` with `checkin.dart`, `insight.dart`, `recurring_situation.dart`, `development_theme.dart`, `practice.dart`, `timeline_event.dart`, `sca_report.dart`, `workshop.dart`, `mobile_profile.dart`). Each: immutable class + `fromJson`. TDD `fromJson` for each (dates, enums). `Mood` enum (stressed/tired/okay/happy) with `dbValue` + label key; `PracticeStatus` enum; `TimelineEventType` enum. Commit.

## Task 11: Streak logic (pure, TDD hard)

**Files:** `lib/core/logic/streak.dart`. Test: `test/core/streak_test.dart`.

```dart
int computeStreak(List<DateTime> checkinDates, DateTime today)
```
Rules: consecutive calendar days ending today OR yesterday (streak not broken until a full day missed); duplicates ignored; empty → 0. Test cases: empty; only today→1; today+yesterday→2; gap breaks; ends-yesterday counts; unordered input; duplicates. Commit.

## Task 12: Repositories (Supabase)

**Files:** `lib/core/data/wr_repository.dart` (or split per feature): methods —
- `getTodayCheckin()` / `upsertCheckin(Mood mood)` → upsert on (user_id, checkin_date=today, mood)
- `getCheckinDates({int limit = 60})`
- `getLatestInsight()`, `getInsights()`, `countInsights()`
- `getRecurringSituations()` (order occurrence_count desc)
- `getActiveTheme()`, `getTodayPractices()`, `updatePracticeStatus(id, PracticeStatus)`
- `getTimelineEvents()` (order occurred_at desc), `countMilestones()`
- `getMobileProfile()`, `updateReminder(bool)`, `updateLanguage(String)`
- `getLatestScaReport()` → from `cc_reports` (score_structure, score_culture, score_activity, created_at) latest by user
- `getUpcomingWorkshop()` → `cc_workshops` where is_active, next by date
- `getCcProfile()` → `cc_profiles` (full_name, email, subscription_expires_at)
- `exportUserData()` → Map of all wr_ rows for user

Constructor takes `SupabaseClient`. No unit tests hitting network; instead define abstract interface `WrRepository` and `SupabaseWrRepository` impl; a `FakeWrRepository` in `test/support/fake_repository.dart` used by all screen tests. Commit.

## Task 13: Home screen (Hôm nay)

**Files:** `lib/features/home/home_providers.dart`, `lib/features/home/presentation/home_screen.dart` + widgets (`checkin_grid.dart`, `system_notice_card.dart`, `suggestion_card.dart`, `insight_section.dart`). Test: `test/features/home_test.dart`.

- Header: greeting `Chào {displayName}` + date `EEEE, dd/MM` in Vietnamese via `intl` (e.g. "Thứ Ba, 24/06" — capitalize first letter).
- Check-in grid 2×2, cream buttons r16, selected → coral bg white text; tap → provider `upsertCheckin`, optimistic update.
- "Hệ thống nhận ra" `WrCardDark` with eyebrow + italic quote built from top recurring situation: `"Đây là lần thứ {n} bạn gặp tình huống {label}."` + action link "Tìm hiểu thêm".
- Suggestion card (cream): static content from l10n (title, "VOICE · 5 phút đọc", progress 35%, "3/8 phút", "Đang đọc").
- Insight section: eyebrow "Insight gần nhất" + latest insight quote + saved date `Lưu ngày dd/MM`.
- Handle loading (spinner), empty (friendly copy), error (retry button) per provider.
Widget tests with FakeWrRepository: renders greeting/date, mood tap persists selection, insight shows, empty state renders. Commit.

## Task 14: Understand screen (Hiểu mình)

**Files:** `lib/features/understand/...`. Test: `test/features/understand_test.dart`.

- Centered dominant-need block (eyebrow, 26 italic quote, caption "VOICE · Nhu cầu chủ đạo").
- Recurring situations list: name + `{n} lần` (top item coral count + coral fill; widths proportional to max count).
- SCA card (cream): rows S/C/A with circular badges (S teal 12%, C coral 12%, A navy 8%) + status label mapped from latest `cc_reports` scores: ≥4 → "Ổn định" teal; ≥2.5 → "Đang cải thiện" coral; else "Cần chú ý"; null report → all "Chưa đánh giá" muted.
- Career Health Check block: reflection count (checkins+insights) with copy "Bạn đã có đủ {n} reflection." + action link "Bắt đầu kiểm tra".
Widget tests incl. SCA mapping and empty-report state. Commit.

## Task 15: Develop screen (Phát triển)

**Files:** `lib/features/develop/...`. Test: `test/features/develop_test.dart`.

- `WrCardDark`: eyebrow "Trọng tâm hiện tại", theme code 40 w800 white, subtitle 70% white, light progress track (white 20% bg / white 80% fill), "Giai đoạn {stage} / {total}".
- Practices list: done → teal check icon, strikethrough, 45% opacity, status "Hoàn thành" teal; doing → coral play icon, "Đang thực hiện" coral; todo → muted circle, "Chưa bắt đầu" muted. Tap advances todo→doing→done (persist via repository; done not reversible in UI this phase).
- Opportunity card (cream, icon tile white): tag "WORKSHOP" teal, workshop title, link "Tại sao bây giờ?". Empty → hide section.
Widget tests: status rendering ×3, tap advances and calls repo, no-theme empty state. Commit.

## Task 16: Journey screen (Hành trình)

**Files:** `lib/features/journey/...`. Test: `test/features/journey_test.dart`.

- Story quote block (eyebrow "Câu chuyện của bạn", insight-quote style, caption "Career Companion · Tháng {M}, {yyyy}").
- Timeline grouped by month (eyebrow "Tháng {M}"): dot color by type (MILESTONE teal, STORY coral, THEME navy), connector line 1px navy 10%, date `d/M`, title hMedium, description body, type label 11 w700 colored.
Widget tests: renders groups, dot colors by type, empty state. Commit.

## Task 17: Profile screen (Tôi)

**Files:** `lib/features/profile/...`. Test: `test/features/profile_test.dart`.

- Header greeting "Tài khoản" + name title. Avatar circle with initials (navy 8% bg, navy text); email; "PREMIUM MEMBER" coral uppercase if `subscription_expires_at > now`, else "Thành viên".
- Stats row (36 w800 navy numbers, dividers): streak (Task 11 over checkin dates), insights count, milestones count.
- Settings list: "Nhắc nhở hằng ngày" custom toggle (teal, persists reminder_enabled); "Ngôn ngữ" → dialog vi/en, persists to prefs + `wr_mobile_profiles.language`, app locale switches live (Riverpod locale provider consumed by `WrApp`); "Xuất dữ liệu" → repository export → save JSON to app documents dir + SnackBar with path; "Đăng xuất" red → signOut → router redirects to /auth.
Widget tests: stats render from fake, premium badge logic ×2, toggle calls repo, logout calls repo. Commit.

## Task 18: Wire seed + polish pass

- Ensure `seed_wr_sample_data` RPC is called once after first login (guard: only when `getMobileProfile()` was absent).
- Verify every screen against the HTML side by side (paddings: content horizontal 24, section gap 28, bottom pad 80 for tab bar clearance; scroll physics; text sizes).
- `flutter gen-l10n`, `flutter analyze` clean, all tests green.
- Commit `polish: layout parity pass`.

## Task 19: Final verification gate (evidence required)

1. `flutter analyze` → 0 issues (paste output).
2. `flutter test` → all pass (paste summary).
3. `flutter build apk --debug` → succeeds (paste last lines).
4. `flutter build web` NOT required.
5. Report: per-screen checklist vs HTML + any deviations.

---

## Appendix A — Copy (Vietnamese, verbatim from HTML)

**Onboarding 1:** tag `Reflection`; title `Hành trình bắt đầu\ntừ một câu hỏi nhỏ.`; body `Mỗi ngày một khoảnh khắc dừng lại.\nĐể nhìn rõ hơn — không phán xét.`; CTA `Tiếp tục`.
**Onboarding 2:** tag `Understand`; title `Điều gì đang khiến\nbạn trăn trở nhất?`; body `Hãy gọi tên nó.\nSự rõ ràng là bước đầu tiên\nđể thay đổi.`; options: `Mệt nhưng không biết tại sao` / `Cố gắng nhưng không thấy tiến` / `Muốn thay đổi, chưa biết bắt đầu từ đâu` / `Đang khá ổn, muốn hiểu mình hơn` (last one teal dot, others coral); CTA `Bắt đầu ngay`.
**Onboarding 3:** tag `Grow`; title `Đồng hành cùng\nsự nghiệp của bạn.`; body `WorkReflection ghi nhớ hành trình,\ntích lũy insight thành\ncareer intelligence của riêng bạn.`; promises: (`5–15 phút mỗi ngày`, `Đủ để tạo ra sự khác biệt`), (`Riêng tư hoàn toàn`, `Chỉ bạn mới thấy hành trình của mình`), (`Không phán xét`, `Chỉ lắng nghe và phản chiếu`); CTA `Vào WorkReflection`.
**Home:** greeting `Chào {name}`; question `Bạn đang trải qua điều gì?`; moods `Tôi đang căng thẳng` / `Tôi mệt mỏi cần nghỉ ngơi` / `Tôi khá ổn` / `Tôi đang vui` (line-broken as in HTML); eyebrows `Hệ thống nhận ra`, `Gợi ý khi mệt mỏi`, `Insight gần nhất`; links `Tìm hiểu thêm`; suggestion `Khi bạn muốn nói nhưng chọn im lặng`, `VOICE · 5 phút đọc`, `3/8 phút`, `Đang đọc`; insight date `Lưu ngày {date}`.
**Understand:** greeting `Career Snapshot`; title `Hiểu mình`; eyebrows `Điều bạn đang tìm kiếm`, `Tình huống lặp lại`, `Trải nghiệm hiện tại (SCA)`, `Career Health Check`; SCA rows `Minh bạch vai trò` / `An toàn khi lên tiếng` / `Định hướng ý nghĩa`; statuses `Ổn định` / `Đang cải thiện` / `Chưa đánh giá`; health `Bạn đã có đủ {n} reflection.`, `Sẵn sàng xem bức tranh tổng thể chưa?`, `Bắt đầu kiểm tra`; count suffix `{n} lần`.
**Develop:** greeting `Development Map`; title `Phát triển`; eyebrows `Trọng tâm hiện tại`, `Practices hôm nay`, `Cơ hội phát triển`; stage `Giai đoạn {x} / {y}`; statuses `Hoàn thành` / `Đang thực hiện` / `Chưa bắt đầu`; workshop tag `Workshop`; link `Tại sao bây giờ?`.
**Journey:** greeting `Career Memory`; title `Hành trình`; eyebrows `Câu chuyện của bạn`, `Tháng {M}`; caption `Career Companion · Tháng {M}, {yyyy}`; type labels `MILESTONE` / `STORY` / `THEME`.
**Profile:** greeting `Tài khoản`; badge `Premium Member`; stats labels `Ngày streak` / `Insight lưu` / `Milestone`; eyebrow `Cài đặt`; items `Nhắc nhở hằng ngày` / `Ngôn ngữ` / `Xuất dữ liệu` / `Đăng xuất`; language value `Tiếng Việt`.
**Auth (new, follow design system):** title đăng nhập `Chào mừng trở lại`, đăng ký `Tạo tài khoản`; fields `Email`, `Mật khẩu`, `Tên của bạn`; buttons `Đăng nhập` / `Đăng ký`; switch `Chưa có tài khoản? Đăng ký` / `Đã có tài khoản? Đăng nhập`; divider `hoặc`; Google `Tiếp tục với Google`.

## Appendix B — Seed data (inserted by seed_wr_sample_data)

- 1 theme: code `VOICE`, title `Khả năng lên tiếng & phản biện`, stage 2/4, progress 0.55.
- 3 practices today: `Quan sát lúc muốn im lặng` (done), `Đặt một câu hỏi trong họp` (doing), `Chia sẻ một quan điểm` (todo).
- 3 recurring situations: `Ngại phản biện` (5), `Tránh đối thoại khó` (4), `Thiếu phản hồi từ sếp` (2).
- 2 insights: `Tôi thường im lặng không phải vì không có ý kiến, mà vì sợ phán xét.` (nguồn VOICE), `Tôi ngại nói thật vì lo bị đánh giá.`
- 3 timeline events (this month): MILESTONE `Insight đầu tiên` / STORY `Hoàn thành Story #3 — Khi im lặng trở thành thói quen` / THEME `Voice Journey bắt đầu — Trọng tâm phát triển được xác định`.
