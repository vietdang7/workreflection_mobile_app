# Phase 2 Plan — Khảo sát phản chiếu + Báo cáo cá nhân (mobile)

> **For Claude:** REQUIRED SUB-SKILL: superpowers:executing-plans / subagent-driven-development, TDD for all logic. Same rules as v1 plan (`2026-07-17-workreflection-mobile-plan.md`): analyze clean + tests green + conventional commit after every task; no hardcoded colors/copy; VI-first l10n.

**Goal:** Port the web app's personal survey flow (FREE/PREMIUM) and personal report (scores, narratives, action plan 30 ngày) to the Flutter app with EXACT data/scoring parity, sharing the same Supabase backend.

**Source of truth:** `docs/plans/2026-07-17-phase2-survey-report-research.md` (formulas, tables, thresholds — follow it verbatim). When ambiguous, read the referenced web files in `/home/duythong/Documents/DuyThong/workreflection`.

**Scope decisions (Fable):**
- ✅ Survey flow, client-side scoring, `cc_reports` insert, Free/Premium report screens, narratives, action plan 30 ngày + progress toggle, premium gating, TTS playback (tts-proxy) with simple karaoke highlight.
- ✅ Best-effort `send-email` invoke on completion (fire-and-forget, never blocks UX).
- ❌ Voice input (Whisper WASM 152MB is web-only; native STT deferred to Phase 2.1).
- ❌ Mid-survey resume (web doesn't have it either — parity).

**New dependency:** `just_audio` (TTS playback). No other new deps.

---

## Task 1: Models + enums (`lib/core/models/`)

`survey_models.dart`: enums `SurveyType` (free/premium ↔ "FREE"/"PREMIUM"), `ScaleType` (likert5/esi5/enps10 ↔ "LIKERT_5"/"ESI_5"/"ENPS_10"), `SurveyLayer` (structure/culture/activity/esi/enps), `ScoreLevel` (high/good/warning/critical). Immutable models with `fromJson`: `CcQuestion` (id, layer, subComponent, scaleType, questionText, questionTextEn, questionOrder, isActive), `CcLikertOption` (scaleType, value, label, labelEn, displayOrder), `CcNarrative` (id, type, layer, scope, scoreMin, scoreMax, narrativeText, narrativeTextEn, narrativeVariants, isActive), `CcReportFull` (all report columns incl. scoreTotal/Esi/Enps, bottleneckLayer, scoreLevel), `ActionPlanPhase` (day, titleVi, titleEn, description, reflectionQuestion, surveyType, tasks), `ActionPlanTask` (id, phaseId, label, displayOrder, completed). TDD fromJson (dates, enums, nulls). Commit.

## Task 2: Scoring engine (pure, TDD hard) — `lib/core/logic/survey_scoring.dart`

```dart
SurveyScores computeSurveyScores({required Map<String, int> answers, required List<CcQuestion> questions})
```
Implements research §3 exactly: layer averages, 1-decimal rounding `(v*10).round()/10`, weighted total S*0.5+C*0.3+A*0.2, ESI avg, eNPS (promoter>=9, passive>=7, detractor<7, `((promoters-detractors)/total*100).round()`), bottleneck min S→C→A tie order, level thresholds 4.2/3.5/2.8. Also `selectNarrative(List<CcNarrative>, {type, layer, score, language})` — highest `score_min <= score`, EN fallback rules. ≥15 test cases incl. edge: empty layer, ties, boundary scores 4.2/3.5/2.8, eNPS all-promoters/all-detractors/rounding, narrative overlap + language fallback. Commit.

## Task 3: SurveyRepository — `lib/core/data/survey_repository.dart`

Abstract `SurveyRepository` + `SupabaseSurveyRepository` + `FakeSurveyRepository` (test/support). Methods:
- `getUserRole()` → `user_roles` first, fallback `cc_profiles.role` (research §6); `SurveyType surveyTypeForRole(role)`.
- `getQuestions(SurveyType)` → question_set_config priority, else filters + dedup per research §1.
- `getLikertOptions()` → all `cc_likert_options` grouped by scaleType.
- `submitSurvey({required SurveyType type, required Map<String,int> answers, required List<CcQuestion> questions, profile fields})` → insert `cc_surveys` (status COMPLETED, completed_at now) → bulk insert `cc_responses` → compute scores → insert `cc_reports` → best-effort `functions.invoke('send-email', ...)` in try/catch ignore → returns `CcReportFull`.
- `getReport(reportId)` / `getLatestReportFull()`, `getNarratives()` (scope=personal, is_active), `getActionPlan(SurveyType)` (phases+tasks ordered), `getActionProgress(reportId)`, `toggleTask(taskId, reportId, bool)` (upsert `cc_user_action_progress`).
- `tts(String text, String language)` → invoke `tts-proxy` `{action: generate_and_wait, text, language}` → `TtsResult(audioUrl, durationMs, fromCache)`.
No network in tests; fake covers all screens' needs. Commit.

## Task 4: Survey flow UI — `lib/features/survey/`

Routes (outside shell, fullscreen): `/survey` (intro/info), `/survey/questions`, `/survey/processing`, `/survey/report/:id`, `/survey/action-plan/:id`.
- **Intro screen**: design-system styled (WrCardDark hero, eyebrow "Career Health Check"), shows survey type theo role (badge PREMIUM nếu premium/admin), optional info fields (chức danh, thâm niên, quy mô công ty, phòng ban — prefill từ profile nếu có), CTA coral "Bắt đầu khảo sát".
- **Questions screen**: one question per view; progress track top (`{i}/{n}` + fill); eyebrow = layer label VI (Cấu trúc/Văn hoá/Hoạt động/ESI/eNPS); question hLarge; answer options from likert options for scaleType (LIKERT/ESI: 5 pill rows; ENPS: 0–10 grid chips); selecting answers → auto-advance after 300ms; back button giữ đáp án; last question → "Hoàn thành" CTA.
- **TTS**: speaker icon toggles playback (just_audio, tts-proxy URL); karaoke highlight = word index estimated evenly over durationMs; auto-play OFF by default (setting toggle in screen).
- **Processing screen**: submit qua repository, spinner + copy "Đang tạo báo cáo của bạn…", on success → `/survey/report/:id`; error → retry.
Widget tests với FakeSurveyRepository: renders question + options, answer advances, progress updates, ENPS grid renders 11 chips, completion calls submitSurvey với answers đúng. Commit.

## Task 5: Report screen — `lib/features/survey/presentation/report_screen.dart`

- Header: score_total lớn (dateTitle style) + `ScoreLevel` label màu (HIGH teal / GOOD navy / WARNING coral / CRITICAL destructive) + narrative TOTAL.
- 3 layer cards S/C/A: score, progress track (fill /5), narrative LAYER theo score; bottleneck card (WrCardDark) với narrative BOTTLENECK.
- PREMIUM extra: ESI card + eNPS card (score −100..100, phân loại promoter/passive/detractor counts); FREE: upsell card cream giới thiệu Premium.
- CTA "Kế hoạch 30 ngày" → action plan screen. Link vào report từ tab Hiểu mình ("Bắt đầu kiểm tra" → `/survey`; nếu đã có report gần nhất thêm link "Xem báo cáo gần nhất").
- Action plan screen: 30 ngày grouped (list theo `day`), mỗi phase: title VI, reflection question, tasks checkbox toggle qua repository (optimistic).
Widget tests: score/level mapping ×4, premium vs free sections, bottleneck hiển thị đúng layer min, action plan toggle calls repo. Commit.

## Task 6: Gating + l10n + wiring

- Premium gate provider (role); Understand tab: thay action link tĩnh bằng điều hướng thật.
- Toàn bộ copy mới vào `app_vi.arb`/`app_en.arb`.
- `flutter analyze` clean, all tests green. Commit.

## Task 7: Verification gate (evidence required)

1. `flutter analyze` → 0 issues. 2. `flutter test` → all pass (báo số test). 3. `flutter build apk --debug` → OK. 4. Checklist parity vs research doc (từng công thức/threshold) + deviations.
