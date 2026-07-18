# Phase 3 Design — Workshop + QR Check-in (BBNT E) + Coaching (BBNT F)

**Date:** 2026-07-18 · **Status:** APPROVED by user · **Predecessor:** Phase 2 (survey + report, CLOSED)

## Scope decisions (user-confirmed)

| Question | Decision |
|---|---|
| Paid flows (SePay deferred to Phase 4) | **Option A** — mobile shows full workshops/coaching incl. price; paid register button opens notice "Thanh toán trên web"; free registration fully works. No WebView. |
| Coaching depth | **Browse + My Sessions** — browse packages + coach profiles, claim free package, view own sessions/schedule read-only. Slot booking, material upload, reviews stay web-only. |
| Workshop extras | **All four**: image consent on check-in, workshop resources tab, post-workshop survey, My Workshops screen. |
| QR check-in | **Camera scan (`mobile_scanner`) + manual 8-char code entry fallback.** |

## Backend facts (shared Supabase `sukpcxevcjnhiuyaoqxi`)

All tables already exist (created by web app). **No new migrations expected.**

- `cc_workshops`: title, description, category, date, starts_at, ends_at, location, price, currency, max_participants, current_participants, image_url, video_url, status('draft'|'active'|'completed'|'cancelled'), is_active, checkin_code (8-char uppercase, unique), org_id (null = public).
- `cc_workshop_registrations`: user_id, workshop_id, status('registered'|'attended'|'cancelled'), checked_in_at, attended, attended_at, payment_status, total_price, image_consent, image_consent_at, order_id.
- `cc_workshop_attachments`, `cc_workshop_resources`: resources shown to registered users.
- `cc_workshop_surveys` + `cc_workshop_question_set_assignments`: post-workshop feedback. **Schema must be researched from web repo before implementing (see plan).**
- `cc_coaching_packages`: name, description, price, currency, sessions_count, duration_minutes, features(json), target_audience('young'|'manager'), is_active, display_order.
- `cc_coaches`: full_name, title, bio, avatar_url, specializations[], experience_years, is_active, display_order.
- `cc_coaching_bookings`: user_id, package_id, coach_id, order_id, status('pending'|'scheduled'|'completed'|'cancelled'), session_number, total_sessions, scheduled_date/time/at, duration_minutes, meeting_link.
- `cc_orders`: product_type('workshop'|'coaching'|...), product_id, status('pending'|'paid'|...), final_amount.

Web reference implementation: `/home/duythong/Documents/DuyThong/workreflection` — key files:
`src/pages/services/Workshops.tsx`, `WorkshopDetail.tsx`, `src/pages/user/MyWorkshops.tsx`,
`src/pages/user/QRScanner.tsx`, `src/pages/workshop/CheckIn.tsx`,
`src/pages/services/Coaching.tsx`, `src/pages/user/CoachingSessions.tsx`, `CoachingSchedule.tsx`.

## Architecture (follow existing repo pattern)

```
lib/core/data/workshop_repository.dart    WorkshopRepository (abstract) + SupabaseWorkshopRepository + provider
lib/core/data/coaching_repository.dart    CoachingRepository (abstract) + SupabaseCoachingRepository + provider
lib/core/logic/checkin_rules.dart         PURE: parse scanned value (8-char code or URL containing code),
                                          time-window check (starts_at −2h .. starts_at +4h), no Flutter/Supabase deps
lib/core/models/workshop_models.dart      Workshop detail/registration/resource models (extend existing workshop.dart or new file)
lib/core/models/coaching_models.dart      CoachingPackage, Coach, CoachingBooking
lib/features/workshops/                   providers + presentation/: list, detail (info + resources tabs),
                                          my_workshops, checkin_screen (scanner + manual entry + consent modal),
                                          post_survey_screen
lib/features/coaching/                    providers + presentation/: packages_screen, my_sessions_screen
```

New dependency: `mobile_scanner` (+ CAMERA permission in AndroidManifest.xml / Info.plist).

## Key flows

1. **Free workshop registration** (`price == 0`): Register button → insert `cc_workshop_registrations(status='registered')` → optimistic UI, error rollback (same pattern as Phase 1 optimistic updates).
2. **Paid workshop/coaching**: button → dialog "Thanh toán trên web workreflection" (l10n VI/EN). No WebView, no deep link required.
3. **QR check-in**: scan (or manual entry) → `checkin_rules` parses code → lookup `cc_workshops` by `checkin_code` → verify user registration exists + time window OK → update `checked_in_at=now(), attended=true` → image-consent modal → on accept update `image_consent=true, image_consent_at`.
4. **Free coaching claim**: create `cc_orders(product_type='coaching', status='paid', final_amount=0)` + `total_sessions` bookings with `status='pending'` (mirror web behaviour — verify exact web logic during implementation).
5. **Post-workshop survey**: visible when own registration has `checked_in_at != null` and survey not yet submitted; reuse Phase 2 question widgets; write to `cc_workshop_surveys`. Requires schema research task first.

## Navigation

Fullscreen routes outside shell (same pattern as `/survey`):
`/workshops`, `/workshops/:id`, `/workshops/checkin`, `/my-workshops`, `/coaching`, `/coaching/sessions`.

Entry points: Home "upcoming workshop" card (getUpcomingWorkshop already exists) → `/workshops/:id`; new section in Develop tab; "Workshop của tôi" / "Coaching của tôi" rows in Profile.

## Testing & gates (same bar as Phase 2)

- `FakeWorkshopRepository`, `FakeCoachingRepository` in `test/support/`.
- Unit tests for `checkin_rules` (pure). Widget tests per screen.
- Gates: `flutter analyze` 0 issues · all tests green (300 existing + new) · `flutter build apk --debug` OK.
- RLS verification: confirm mobile (authenticated user) can insert `cc_workshop_registrations`, `cc_orders`, `cc_coaching_bookings`, `cc_workshop_surveys` and update own registration. Use **supabase CLI** (repo linked to `sukpcxevcjnhiuyaoqxi`) — the session MCP supabase server points to an unrelated project, never use it for this.
- Workflow: Fable plans/reviews → Sonnet subagents implement with superpowers TDD → Sonnet runs gates → Fable adversarial review, loop until pass.

## Out of scope (deferred)

SePay payment / WebView (Phase 4) · slot booking, material upload, coach reviews (web-only) · enterprise/org workshops (`org_id != null` filtered out) · admin features.
