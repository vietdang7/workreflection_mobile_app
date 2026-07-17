# Phase 2 Research — Web Survey/Report parity (source: /home/duythong/Documents/DuyThong/workreflection)

Findings from a very-thorough Explore of the React web app. Mobile MUST match these exactly for data/scoring parity (shared Supabase backend `sukpcxevcjnhiuyaoqxi`).

## 1. Survey flow

- **Survey creation** (`src/lib/survey-save.ts:147-254`): `cc_surveys` insert fields: `user_id` (text, auth user id), `survey_type` ("FREE"|"PREMIUM"), `status` (default "COMPLETED"), `user_email`, `user_full_name`, `user_position`, `user_work_experience`, `user_company_tenure`, `user_company_size`, `user_department`, `started_at`, `completed_at` (ISO at save), `campaign_id` (null for personal).
- **Survey type decision** (`src/pages/Index.tsx:25`): `userRole in ("premium","admin")` → PREMIUM else FREE. Role from `user_roles` table first, fallback `cc_profiles.role`.
- **Question fetching** (`src/pages/survey/Questions.tsx:114-203`):
  1. If active `cc_question_set_config` exists with `question_ids` array → use those.
  2. Else `cc_questions` WHERE `is_active = true` AND `survey_type IN (target, "BOTH")` AND `scale_type IN (LIKERT_5)` for FREE / `(LIKERT_5, ESI_5, ENPS_10)` for PREMIUM, ORDER BY `question_order`.
  3. Dedup by `question_order`.
- **Answer saving**: bulk insert `cc_responses` `{survey_id, question_id, answer_value}` in ONE batch at the end. NO mid-survey persistence (navigation away = lost).
- **Auto-advance** (`src/hooks/useSurveyAudio.ts:134-142`): after voice answer, 2000ms countdown then advance; cancellable.
- **Completion**: `cc_surveys.status = "COMPLETED"`, `completed_at = now ISO`; then Thank You page.

## 2. Scale types

- `LIKERT_5`: values 1–5 (layers STRUCTURE/CULTURE/ACTIVITY). Labels from `cc_likert_options` (per scale_type + value + display_order); fallback numeric.
- `ESI_5`: values 1–5 (PREMIUM only, layer ESI).
- `ENPS_10`: values 0–10, labels are numeric strings (PREMIUM only, layer ENPS). Migration `031_enps_likert_1_10.sql`.
- Question columns: `layer` ("STRUCTURE"|"CULTURE"|"ACTIVITY"|"ESI"|"ENPS"), `sub_component`, `scale_type`, `question_order` (1-based).

## 3. Scoring (CLIENT-SIDE, then insert `cc_reports`)

```
scoreStructure = avg(answers where layer=STRUCTURE)
scoreCulture   = avg(answers where layer=CULTURE)
scoreActivity  = avg(answers where layer=ACTIVITY)
scoreESI       = avg(answers where layer=ESI)          // PREMIUM only
scoreTotal     = S*0.5 + C*0.3 + A*0.2                 // ESI NOT in total
// all rounded to 1 decimal: Math.round(v*10)/10
```

- **eNPS** (PREMIUM): over ENPS answers: promoter `>=9`, passive `>=7 && <9`, detractor `<7`; `eNPS = round((promoters% - detractors%) * 100)`.
- **Bottleneck layer**: min(S, C, A); ties resolve S → C → A.
- **Score level**: `HIGH >= 4.2`; `GOOD >= 3.5`; `WARNING >= 2.8`; `CRITICAL < 2.8` (on scoreTotal).
- **`cc_reports` insert fields**: `survey_id` (unique FK), `user_id`, `score_total`, `score_structure`, `score_culture`, `score_activity`, `score_esi` (null FREE), `score_enps` (null if no ENPS), `bottleneck_layer`, `score_level`, `sub_scores` (jsonb, null personal), `selected_narrative_variants` (jsonb).

## 4. Narratives (`src/pages/results/Free.tsx:252-279`)

- Fetch: `cc_narratives WHERE scope='personal' AND is_active=true`.
- Match: by `type` (TOTAL, LAYER, BOTTLENECK…), `layer` (null for TOTAL), and **only** `score >= score_min` — there is deliberately NO upper-bound check (`Free.tsx:136-141`, avoids gaps between ranges); pick the HIGHEST `score_min` that is `<= score`. **(Corrected 2026-07-17 after review — earlier version wrongly said `score <= score_max`.)**
- Language: `language=='en' && narrative_text_en != null` → `narrative_text_en` else `narrative_text` (VI).
- Variants: `narrative_variants` jsonb array; chosen variant ids stored in `cc_reports.selected_narrative_variants`.

## 5. Action plan / roadmap 30 days

- `cc_action_plan_phases`: `day` (1–30), `title_vi`, `title_en`, `description`, `reflection_question`, `survey_type`, `display_order`.
- `cc_action_plan_tasks`: `phase_id`, `label`, `display_order`.
- **(Corrected 2026-07-17 after review, per `useActionPlanProgress.ts` + `migrations/002_fix_action_progress_rls.sql`):**
  - Phases: fetch ALL phases with **NO survey_type filter**, ORDER BY `day` (not display_order). Seed data only has FREE-typed phases.
  - Progress: read by `user_id` ONLY (no report_id filter). Upsert `{user_id, task_id, completed, completed_at}` with `onConflict: "user_id,task_id"` — **never write `report_id`** (DB unique constraint is `UNIQUE (user_id, task_id)`; including report_id in onConflict → Postgres 42P10 error).
  - Read-only for anonymous.

## 6. Premium gating

- `user_roles` table first (`SELECT role WHERE user_id = auth.uid()`), fallback `cc_profiles.role`; values `premium`/`admin`/`user`.
- FREE report: S/C/A + limited narratives. PREMIUM adds ESI, eNPS, extended narratives.

## 7. TTS + voice input

- Edge fn `tts-proxy` via `supabase.functions.invoke`: request `{action:"generate_and_wait", text, voiceId?, speed?, language:"vi"|"en"}` → response `{audioUrl, durationMs, fromCache}`. Voice ids: VI 1619321 (Anh Thư), EN 1914576. Cached to `tts-audio` bucket by SHA-256 of (text|voiceId|speed|language|model).
- Karaoke (`src/hooks/useKaraokeHighlight.ts`): split words, active word from currentTimeMs vs word start/end (estimated from durationMs).
- Voice input (`src/hooks/useVoiceInput.ts`): VI = Web Speech API + `vietnamese-number-parser`; EN = local Whisper WASM (152MB) + `english-number-parser`. Maps spoken number → answer; rejects > maxAnswerValue.

## 8. RPC/edge functions in flow

- `tts-proxy` (above). **(Corrected 2026-07-17 after review):** web's actual completion side-effect is two **`cc_notifications` inserts** (`notifyAdminSurveyCompleted`, `notifyAdminReportGenerated` — see `survey-save.ts:231-240` → `src/lib/notifications.ts`), NOT a direct send-email call from the survey flow. The `send-email` edge fn contract (`src/lib/email.ts:15-17`) is `{type, payload}` (not `{template, userId, surveyId}`). No scoring RPCs — all client-side.
- Question set config lookup filters BOTH `.eq('survey_type', target)` AND `.eq('is_active', true)`; when using config `question_ids`, also filter `cc_questions.is_active = true` and preserve the config's id order. Likert options: filter `is_active = true` and dedup by value.
- Missing/null answers are EXCLUDED from averages (not counted as 0); eNPS question filter is `layer=="ENPS" || scale_type=="ENPS_10"`. Premium reports always write `score_esi` (0 if no ESI questions), never null.

## Key web file paths

`src/pages/survey/Questions.tsx`, `src/lib/survey-save.ts`, `src/pages/survey/Info.tsx`, `src/pages/survey/ThankYou.tsx`, `src/lib/tts-client.ts`, `src/hooks/useTTS.ts`, `src/hooks/useVoiceInput.ts`, `src/hooks/useSurveyAudio.ts`, `src/pages/results/Free.tsx`, `src/pages/results/Premium.tsx`, `src/pages/ActionPlan.tsx`, `src/contexts/AuthContext.tsx`, `supabase/migrations/001_create_cc_tables.sql`, `supabase/functions/tts-proxy/index.ts`.
