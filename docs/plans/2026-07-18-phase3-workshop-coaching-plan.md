# Phase 3 Implementation Plan — Workshop + QR Check-in + Coaching

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement this plan task-by-task. Every task: TDD (test first), run tests, commit. Design doc: `docs/plans/2026-07-18-phase3-workshop-coaching-design.md` (read it first).

**Goal:** Port BBNT sections E (Workshops + QR check-in) and F (Coaching, browse + my-sessions) to the Flutter mobile app; free flows fully work, paid flows show "Thanh toán trên web" notice.

**Architecture:** Same layering as Phase 1/2 — abstract repository + Supabase impl + Riverpod provider in `lib/core/data/`, pure logic in `lib/core/logic/`, feature screens under `lib/features/`, fakes in `test/support/`. No DB migrations (all `cc_*` tables exist on shared backend `sukpcxevcjnhiuyaoqxi`).

**Tech Stack:** Flutter 3.41, Riverpod 2, go_router 14, supabase_flutter 2, `mobile_scanner` (NEW dep), l10n gen (VI/EN arb).

**Hard rules for the executor (Sonnet):**
- TDD: write failing test → run (`flutter test <file>`) → implement → green → commit. Match existing test style (`test/features/*_test.dart` use fakes + `ProviderScope(overrides:)`).
- NEVER use the MCP supabase server (points at wrong project). Read-only backend checks via `supabase` CLI only; do NOT push migrations.
- Per project CLAUDE.md: run `gitnexus_impact` before modifying existing symbols; `gitnexus_detect_changes` before each commit. New files/symbols: impact check not needed.
- l10n: every user-visible string goes in `lib/l10n/app_vi.arb` + `app_en.arb`, then `flutter gen-l10n` (runs automatically with build/test via `generate: true`).
- After final commit: `gitnexus analyze` (global binary — `npx gitnexus` fails here).

---

## Task 0: Research — post-workshop survey schema + RLS verification

**Files:** Create `docs/plans/2026-07-18-phase3-research-notes.md`

1. Read in web repo `/home/duythong/Documents/DuyThong/workreflection`:
   - `src/pages/admin/WorkshopQuestionSets.tsx`, `src/integrations/supabase/types.ts` (search `cc_workshop_surveys`, `cc_workshop_question_set_assignments`), and any user-facing post-workshop survey submission page (grep `cc_workshop_surveys` in `src/`).
   - Document: exact columns of `cc_workshop_surveys`, how questions are assigned to a workshop, what a submission row looks like, and whether questions reuse `cc_questions`.
   - Also grep web `src/pages/services/Coaching.tsx` for the **free package claim** logic (what exactly gets inserted into `cc_orders` and `cc_coaching_bookings`) and copy the field list into the notes.
2. RLS check (read-only, supabase CLI): confirm authenticated users can `select` on `cc_workshops`, `cc_workshop_registrations` (own), `cc_workshop_attachments/resources`, `cc_coaching_packages`, `cc_coaches`, `cc_coaching_bookings` (own), and `insert` own rows into `cc_workshop_registrations`, `cc_orders`, `cc_coaching_bookings`, `cc_workshop_surveys`, and `update` own registration (`checked_in_at`, `image_consent`). Method: `supabase db dump --schema public -f /tmp/schema.sql` (or `db pull` dry-run) and grep policies; do NOT modify anything.
3. Write findings to the research notes file. **If any RLS gap is found, STOP and report to Fable before continuing** (a migration on the shared backend needs user approval).
4. Commit: `docs: phase 3 research notes — workshop survey schema, coaching claim, RLS`.

## Task 1: Workshop models

**Files:** Create `lib/core/models/workshop_models.dart`, `test/core/workshop_models_test.dart`

Models (plain classes + `fromJson`, follow `lib/core/models/survey_models.dart` style; do NOT touch existing `workshop.dart` — it stays for the Develop card):

```dart
class WorkshopDetail {
  // id, title, description?, category?, date (DateTime), startsAt?, endsAt?,
  // location?, price (num, default 0), currency ('VND' default), maxParticipants?,
  // currentParticipants (default 0), imageUrl?, videoUrl?, status, isActive,
  // checkinCode?, orgId?
  bool get isFree => price == 0;
  bool get isFull => maxParticipants != null && currentParticipants >= maxParticipants!;
}
class WorkshopRegistration {
  // id, workshopId, userId, status ('registered'|'attended'|'cancelled'),
  // checkedInAt?, attended (default false), imageConsent?, createdAt?
}
class WorkshopResource {
  // id, workshopId, name/title, url, type?  — exact fields per Task 0 notes
}
```

Tests: fromJson happy path, null/absent optionals, `isFree`, `isFull` edge (`current == max`). ~8 tests.
Commit: `feat(p3): workshop models`.

## Task 2: Coaching models

**Files:** Create `lib/core/models/coaching_models.dart`, `test/core/coaching_models_test.dart`

```dart
class CoachingPackage { // id, name, description?, price, currency, sessionsCount,
  // durationMinutes?, features List<String> (json array), targetAudience?, isActive, displayOrder
  bool get isFree => price == 0; }
class Coach { // id, fullName, title?, bio?, avatarUrl?, specializations List<String>,
  // experienceYears?, isActive }
class CoachingBooking { // id, packageId, coachId?, status, sessionNumber?, totalSessions?,
  // scheduledAt?, durationMinutes?, meetingLink? }
```

Tests ~6. Commit: `feat(p3): coaching models`.

## Task 3: Check-in rules (pure logic)

**Files:** Create `lib/core/logic/checkin_rules.dart`, `test/core/checkin_rules_test.dart`

```dart
/// Extracts an 8-char uppercase alphanumeric check-in code from a scanned
/// QR value: either the bare code ("AB12CD34") or a URL whose last path
/// segment is the code (".../workshop/checkin/AB12CD34"). Returns null if invalid.
String? parseCheckinCode(String raw) {
  final v = raw.trim();
  final codeRe = RegExp(r'^[A-Z0-9]{8}$');
  if (codeRe.hasMatch(v.toUpperCase())) return v.toUpperCase();
  final uri = Uri.tryParse(v);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    final last = uri.pathSegments.last.toUpperCase();
    if (codeRe.hasMatch(last)) return last;
  }
  return null;
}

enum CheckinWindow { tooEarly, open, closed, unknown }

/// Web parity: open from startsAt−2h to startsAt+4h. Null startsAt → unknown
/// (treat as open — server data incomplete should not block attendees).
CheckinWindow checkinWindow(DateTime? startsAt, DateTime now) { ... }
```

Tests (~12): bare code lower/upper, code with spaces, URL form, 7/9-char reject, garbage reject; window before/-2h boundary/inside/+4h boundary/after/null.
Commit: `feat(p3): check-in parsing + time window rules (pure)`.

## Task 4: WorkshopRepository

**Files:** Create `lib/core/data/workshop_repository.dart`; Test `test/support/fake_workshop_repository.dart` (Task 5 covers fake; here interface + Supabase impl compile only)

```dart
abstract class WorkshopRepository {
  Future<List<WorkshopDetail>> getActiveWorkshops();       // is_active=true, status='active', org_id IS NULL, order by date asc
  Future<WorkshopDetail?> getWorkshop(String id);
  Future<WorkshopRegistration?> getMyRegistration(String workshopId);
  Future<List<WorkshopRegistration>> getMyRegistrations(); // for My Workshops (join-fetch workshops separately)
  Future<void> registerFree(String workshopId);            // insert status='registered'; throw if already registered
  Future<WorkshopDetail?> getWorkshopByCheckinCode(String code);
  Future<void> checkIn(String registrationId);             // update checked_in_at=now, attended=true, status='attended'
  Future<void> setImageConsent(String registrationId, bool consent);
  Future<List<WorkshopResource>> getResources(String workshopId);
  // Post-workshop survey — signatures finalized from Task 0 notes:
  Future<bool> hasSubmittedWorkshopSurvey(String workshopId);
  Future<void> submitWorkshopSurvey(String workshopId, Map<String, dynamic> payload);
}
final workshopRepositoryProvider = Provider<WorkshopRepository>(
  (ref) => SupabaseWorkshopRepository(Supabase.instance.client));
```

Supabase impl mirrors `SupabaseSurveyRepository` conventions (`_uid` getter, `.eq('user_id', _uid)` scoping). `registerFree` must NOT increment `current_participants` client-side unless Task 0 research shows the web does it client-side — match web exactly.
Commit: `feat(p3): WorkshopRepository + Supabase impl`.

## Task 5: FakeWorkshopRepository + repo unit tests

**Files:** Create `test/support/fake_workshop_repository.dart`, `test/core/workshop_repository_test.dart`

Follow `FakeWrRepository` style: internal state, `seed*` helpers (`seedWorkshops`, `seedRegistration`), call recorders (`registerFreeCalls`, `checkInCalls`, `setImageConsentCalls`), plus `failNextCall` flag for error-path widget tests. Unit-test the fake's contract (register → getMyRegistration returns row; checkIn sets checkedInAt/attended). ~8 tests.
Commit: `test(p3): FakeWorkshopRepository`.

## Task 6: CoachingRepository + fake

**Files:** Create `lib/core/data/coaching_repository.dart`, `test/support/fake_coaching_repository.dart`, `test/core/coaching_repository_test.dart`

```dart
abstract class CoachingRepository {
  Future<List<CoachingPackage>> getPackages();   // is_active, order display_order
  Future<List<Coach>> getCoaches();              // is_active, order display_order
  Future<List<CoachingBooking>> getMyBookings(); // order scheduled_at desc nulls last
  Future<void> claimFreePackage(CoachingPackage pkg); // per Task 0 notes: cc_orders(paid, amount 0) + N pending bookings
}
```

Commit: `feat(p3): CoachingRepository + fake`.

## Task 7: l10n strings

**Files:** Modify `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`

Add ALL Phase 3 keys in one batch (prefix `ws`/`coach`): list titles, empty states, register CTA, "Miễn phí"/“Free”, price display, full badge, paid-dialog title/body (**"Thanh toán trên web"** / "Vui lòng hoàn tất thanh toán trên trang web WorkReflection"), check-in screen (scan hint, manual entry label, success, errors: invalid code, not registered, too early, closed), consent modal (title, body, accept, decline), My Workshops statuses, resources tab, post-survey CTA/thanks, coaching sections (audience tabs, sessions list, statuses pending/scheduled/completed/cancelled, claim-free CTA/success). Run `flutter gen-l10n`, `flutter analyze`.
Commit: `feat(p3): l10n strings for workshops + coaching`.

## Task 8: Routes + entry points

**Files:** Modify `lib/core/router/app_router.dart`, `lib/features/develop/presentation/develop_screen.dart` (wire `_OpportunityCard`'s `WrActionLink` onTap → `context.push('/workshops/${workshop.id}')` — currently empty closure at line ~340), `lib/features/profile/presentation/profile_screen.dart` (two rows: My Workshops, My Coaching); Test: extend `test/core/router_test.dart`

Run `gitnexus_impact` on `appRouterProvider`, `DevelopScreen`, `ProfileScreen` first. New fullscreen routes (outside shell, same style as `/survey`): `/workshops`, `/workshops/:id`, `/workshops/checkin`, `/my-workshops`, `/coaching`, `/coaching/sessions`. Screens can be placeholder `Scaffold`s in this task (replaced by Tasks 9–15) — keep the app compiling.
Commit: `feat(p3): routes + entry points`.

## Task 9: Workshops list screen

**Files:** Create `lib/features/workshops/workshops_providers.dart`, `lib/features/workshops/presentation/workshops_screen.dart`; Test `test/features/workshops_list_test.dart`

Providers: `activeWorkshopsProvider = FutureProvider.autoDispose`. UI: AppBar back, list of `WrCard`s — image (if any), category eyebrow (`WrEyebrow`), title, date/location line, price chip ("Miễn phí" green vs formatted `price currency`), full badge when `isFull`. Tap → detail. Empty + error states (match `_ErrorCard` pattern from home). Widget tests (~6): renders items, free vs paid chip, full badge, empty state, error state, tap navigates.
Commit: `feat(p3): workshops list screen`.

## Task 10: Workshop detail screen

**Files:** Create `lib/features/workshops/presentation/workshop_detail_screen.dart`; Test `test/features/workshop_detail_test.dart`

Sections: header (image/title/category/date/starts–ends/location/price), description, participants count, **Resources tab/section** visible ONLY when registered (from `getResources`, each row opens external link via `url_launcher`? — NO: avoid new dep; show URL row with copy via `Clipboard.setData`, matching YAGNI), CTA logic:
- not registered + free + not full → "Đăng ký" → `registerFree` (optimistic, rollback+SnackBar on error, pattern from `optimistic_update_test.dart`)
- not registered + paid → button opens **paid dialog** ("Thanh toán trên web")
- full → disabled button
- registered → status chip (registered/attended + checkedInAt time) + "Check-in" button → `/workshops/checkin`
- registered + checkedInAt != null + survey not submitted → post-survey CTA (Task 13 screen)
Widget tests (~10) cover every CTA branch + optimistic rollback.
Commit: `feat(p3): workshop detail + free registration + paid notice`.

## Task 11: My Workshops screen

**Files:** Create `lib/features/workshops/presentation/my_workshops_screen.dart`; Test `test/features/my_workshops_test.dart`

List my registrations joined with workshop info (provider combines `getMyRegistrations` + `getActiveWorkshops`/`getWorkshop`), status chips (registered / attended with check-in time / cancelled), tap → detail, empty state. ~5 tests.
Commit: `feat(p3): my workshops screen`.

## Task 12: QR check-in screen (mobile_scanner)

**Files:** Modify `pubspec.yaml` (add `mobile_scanner: ^5.2.3`), `android/app/src/main/AndroidManifest.xml` (`<uses-permission android:name="android.permission.CAMERA"/>`), `ios/Runner/Info.plist` (`NSCameraUsageDescription`); Create `lib/features/workshops/presentation/checkin_screen.dart`; Test `test/features/checkin_test.dart`

Structure: scanner area (**wrap `MobileScanner` behind a small provider/flag so widget tests can replace it with a stub** — tests can't run camera) + manual-entry `TextField` + submit. On code (scanned or typed): `parseCheckinCode` → invalid → error text; valid → `getWorkshopByCheckinCode` → null → "mã không hợp lệ"; found → `getMyRegistration` → null → "bạn chưa đăng ký workshop này"; `checkinWindow` tooEarly/closed → message; open/unknown → `checkIn()` → success view → **image consent modal** (accept → `setImageConsent(true)`, decline → `setImageConsent(false)`) → pop về detail. Widget tests (~8) via manual entry path + fake repo (scanner stubbed): invalid code, unknown code, not registered, too early, closed, success + consent accept, consent decline, repo error.
Commit: `feat(p3): QR check-in screen with camera scan + manual entry + consent`.

## Task 13: Post-workshop survey screen

**Files:** Create `lib/features/workshops/presentation/workshop_survey_screen.dart` (+ route `/workshops/:id/survey` in router); Test `test/features/workshop_survey_test.dart`

Implement per Task 0 research notes — reuse Phase 2 question-rendering widgets from `survey_questions_screen.dart` where sensible (extract shared widget ONLY if reuse is clean — otherwise duplicate minimally, note it). Guard: only reachable when checked-in and not yet submitted; after submit → thanks state, CTA hidden on detail. ~6 tests.
Commit: `feat(p3): post-workshop survey`.

## Task 14: Coaching packages screen

**Files:** Create `lib/features/coaching/coaching_providers.dart`, `lib/features/coaching/presentation/coaching_screen.dart`; Test `test/features/coaching_test.dart`

Sections: audience toggle/tabs (`young` vs `manager`), package cards (name, sessionsCount × durationMinutes, features bullets, price or "Miễn phí"), coaches strip (avatar/initials, name, title, specializations). CTA: free → confirm dialog → `claimFreePackage` → success SnackBar + refresh my-bookings; paid → paid dialog ("Thanh toán trên web"). ~8 tests incl. claim success + failure rollback.
Commit: `feat(p3): coaching packages + free claim`.

## Task 15: My coaching sessions screen

**Files:** Create `lib/features/coaching/presentation/coaching_sessions_screen.dart`; Test `test/features/coaching_sessions_test.dart`

Read-only list grouped by status: upcoming (scheduled, with date/time + meeting link copy row), pending ("chờ xếp lịch"), completed/cancelled history. Session `x/y` label. Note "Đặt lịch & đánh giá thực hiện trên web". Empty state. ~5 tests.
Commit: `feat(p3): my coaching sessions (read-only)`.

## Task 16: Final gates + index + handoff

1. `flutter analyze` → 0 issues.
2. `flutter test` → ALL green (expect ≈300 + ~80 new).
3. `flutter build apk --debug` → OK.
4. `gitnexus_detect_changes()` — verify scope = Phase 3 files only.
5. `gitnexus analyze` (global binary) to re-index.
6. Report to Fable: per-task commit list, test count, any deviations from plan (esp. Task 0 findings), known limitations.

---

## Verification checklist for Fable's adversarial review (do not delete)

- [ ] Paid flows: NO payment/WebView code anywhere; dialog text matches l10n; free `price == 0` boundary (what about null price? must default 0).
- [ ] `registerFree` idempotency: double-tap cannot double-insert (guard: check existing registration first or unique constraint handling).
- [ ] Check-in: time-window boundaries exactly −2h/+4h inclusive; unknown startsAt does not block; consent decline still recorded (`image_consent=false`).
- [ ] org workshops (`org_id != null`) excluded from list; draft/cancelled/completed statuses excluded.
- [ ] Free coaching claim matches web's insert shape exactly (orders + N bookings) — cross-check research notes vs web source.
- [ ] All new screens: loading/empty/error states; VI + EN strings both present; no hardcoded Vietnamese in widgets.
- [ ] No use of MCP supabase; no migrations pushed; RLS verified read-only.
- [ ] Providers `autoDispose` where screen-scoped (Phase 2 finding N18 precedent).
