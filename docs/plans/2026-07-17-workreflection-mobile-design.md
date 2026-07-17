# WorkReflection Mobile — Design Document

**Date:** 2026-07-17
**Status:** Approved by user
**Reference layout:** `/home/duythong/Desktop/FileTam/workreflection/complete-flow-fixed (4).html`
**Backend:** Existing Supabase project `sukpcxevcjnhiuyaoqxi` (shared with the web app at `/home/duythong/Documents/DuyThong/workreflection`)

## Goal

Build a Flutter mobile app (Android + iOS, developed/tested on Linux + Android) that reproduces the layout of `complete-flow-fixed (4).html` with real functionality backed by the existing WorkReflection Supabase project.

## Key decisions (confirmed with user)

1. **Connect Supabase immediately** — no mock-only phase.
2. **Real functionality** — check-ins persist per day, streak computed for real, settings work, practices tickable.
3. **Cross-platform code** — nothing Android-only; iOS must work later without rework.
4. **New tables** with `wr_` prefix added to the existing Supabase project for mobile-first features (check-ins, insights, practices, themes, timeline). RLS owner-only.
5. **Auth screens added** (the HTML has none): email/password + Google OAuth after onboarding.
6. Project lives at `/home/duythong/Documents/DuyThong/appmobileworkreflection`.

## Stack

- Flutter 3.41 / Dart 3.11
- `supabase_flutter` — auth + Postgrest + realtime
- `flutter_riverpod` — state management
- `go_router` — navigation
- `google_fonts` — Be Vietnam Pro
- `shared_preferences` — language/local prefs
- `intl` + Flutter ARB localization (vi default, en)

## Design tokens (from the HTML)

| Token | Value |
|---|---|
| navy | `#093774` |
| coral | `#FF6859` |
| teal | `#15B5B0` |
| cream | `#FFF3E6` |
| dark | `#2C335D` |
| muted | `#8A95A3` |

Font: Be Vietnam Pro. Cards radius 20, minimal cards use cream bg, dark cards navy. Pill buttons radius 100, padding 18. Bottom tab bar: 64px, blur/95% white, coral active state with 4px dot. Eyebrow labels: 11px/700/uppercase/muted. Section titles `h-large` 22/700 navy. Insight quotes italic 20px navy.

## Navigation flow

```
Splash (session check)
 ├─ no session → Onboarding (3 steps: Reflect → Understand → Grow) → Auth (login/register) → Shell
 └─ session    → Shell

Shell = 5 tabs (Hôm nay / Hiểu mình / Phát triển / Hành trình / Tôi)
```

Onboarding step 2 records the selected "situation" and saves it to `wr_mobile_profiles.onboarding_situation` after signup.

## Screens (mirroring the HTML exactly)

1. **Hôm nay (home)** — greeting with real display name + Vietnamese date title ("Thứ Ba, 24/06" style); mood check-in grid (4 options: căng thẳng / mệt mỏi / khá ổn / đang vui) persisted to `wr_checkins` (one row per user per day, updatable same-day); "Hệ thống nhận ra" navy card from top `wr_recurring_situations`; "Gợi ý" cream card (content suggestion, static content OK); "Insight gần nhất" quote from latest `wr_insights`.
2. **Hiểu mình (understand)** — dominant need quote; recurring situations with progress bars (`wr_recurring_situations`); SCA card mapping latest `cc_reports` (score_structure/culture/activity → status labels; empty state if none); Career Health Check teaser (reflection count from check-ins/insights).
3. **Phát triển (develop)** — navy focus card from `wr_development_themes` (code e.g. VOICE, stage x/y, progress bar); today's practices list from `wr_practices` (tap to advance todo→doing→done, persists, updates theme progress); "Cơ hội phát triển" card from active `cc_workshops`.
4. **Hành trình (journey)** — narrative summary quote; month-grouped timeline from `wr_timeline_events` (dot color by type: MILESTONE=teal, STORY=coral, THEME=navy).
5. **Tôi (profile)** — avatar initials, name/email from `cc_profiles` + auth; Premium badge if `subscription_expires_at` in future; stats row: streak (consecutive days with check-ins ending today/yesterday), saved insights count, milestone count; settings: daily reminder toggle (persists to `wr_mobile_profiles`), language vi/en switcher, export data (JSON of user's wr_ rows via share/save), logout (red).
6. **Onboarding ×3** — logo SVG (bundle as asset), tag/title/body per step, progress dots (active=coral 24px pill), CTA buttons navy/coral/teal, step 2 selectable situation list, step 3 promise cards.
7. **Auth** — login + register (email/password), Google OAuth button, matching design system.

## New database tables (`wr_` prefix, RLS owner-only via `auth.uid() = user_id`)

| Table | Columns |
|---|---|
| `wr_mobile_profiles` | user_id uuid PK → auth.users, display_name text, onboarding_situation text, reminder_enabled bool default true, language text default 'vi', created_at, updated_at |
| `wr_checkins` | id uuid PK, user_id, mood text check in (stressed, tired, okay, happy), checkin_date date, unique(user_id, checkin_date), created_at |
| `wr_insights` | id uuid PK, user_id, content text, source text, saved_at timestamptz |
| `wr_recurring_situations` | id uuid PK, user_id, label text, occurrence_count int, updated_at |
| `wr_development_themes` | id uuid PK, user_id, code text, title text, subtitle text, stage int, total_stages int, progress numeric (0–1), is_active bool |
| `wr_practices` | id uuid PK, user_id, theme_id uuid FK, title text, status text check in (todo, doing, done), practice_date date, completed_at |
| `wr_timeline_events` | id uuid PK, user_id, event_type text check in (MILESTONE, STORY, THEME), title text, description text, occurred_at date |

Migrations applied via Supabase MCP `apply_migration`. A seed script populates sample data for the signed-in test user so screens aren't empty (a `seed_wr_sample_data(uuid)` SQL function or client-side first-run seeding — plan decides; prefer a DB function invoked after first sign-up).

Reused existing tables (read-only from mobile): `cc_profiles`, `cc_reports`, `cc_workshops`.

## Architecture

Feature-first layout:

```
lib/
  main.dart, app.dart
  core/ (theme, router, supabase client, l10n helpers, widgets shared: eyebrow, cards, progress track, pill button)
  features/
    onboarding/  auth/  home/  understand/  develop/  journey/  profile/
      (each: data/ repository, providers, presentation/ screen + widgets)
l10n/ (app_vi.arb default, app_en.arb)
```

Repositories wrap Supabase queries; Riverpod `AsyncNotifier`s expose state; widgets render loading/empty/error states (empty states designed, not blank).

## Error handling

- All Supabase calls wrapped; failures surface as inline retry states, not crashes.
- Offline: show cached-last or friendly error; no hard requirement for offline sync this phase.
- Same-day duplicate check-in handled by upsert on (user_id, checkin_date).

## Testing

- Unit tests: streak calculation, repositories (with mocked Supabase or fake data layer), mood mapping.
- Widget tests: each of the 5 tabs + onboarding + auth render with fake providers (loading/empty/data states), tab switching, check-in selection.
- `flutter analyze` clean, `flutter test` green, `flutter build apk --debug` succeeds as final gate.

## Execution process

1. Fable (Claude Fable 5): design (this doc) + detailed implementation plan.
2. Sonnet subagent implements per plan using superpowers skills (TDD).
3. Sonnet self-verifies: analyze, tests, build; reports evidence.
4. Fable reviews (code review + independently re-running checks). Loop until pass.
