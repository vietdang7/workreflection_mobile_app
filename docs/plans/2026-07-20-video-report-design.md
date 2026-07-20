# Video Report (mobile) — Design

**Date:** 2026-07-20
**Feature:** Port the web "Video Report" (Remotion) to the Flutter mobile app for end-user parity.
**Status:** Approved (design), pending implementation plan.

## Context

The web app (`workreflection`) has a "Video Report" built with Remotion. Investigation finding:
it is **not** an exported MP4 — it is an **inline animated player** (`@remotion/player`) that plays a
sequence of animated scenes synced to a TTS voiceover, with subtitles. No file is saved/downloaded.

Both apps share one Supabase backend (`sukpcxevcjnhiuyaoqxi`). Web pipeline:
Gemini summarizer → narration script → `tts-proxy` edge function (writes `cc_video_jobs`, returns
audio + SRT) → subtitle/scene timing → Remotion Player (1280×720, 30fps).

Web key files: `src/hooks/useVideoReport.ts`, `src/lib/video-report/*`
(`gemini-summarizer.ts`, `tts-client.ts`, `subtitle-timing.ts`, `scene-planner.ts`),
`src/components/video-report/*`, `src/types/video-report.ts`.

Mobile already has: `just_audio` ^0.9.40; `tts-proxy` calls in `survey_repository.dart`
(`tts()` via `action:'generate_and_wait'` → `TtsResult{audioUrl, durationMs}`, currently drops SRT);
`ScaRadarChart` CustomPainter (matches web radar geometry); report visual widgets
(`_LayerCard`, `_BottleneckCard`, `_EsiCard`, `_EnpsCard`, `_ScoreLevelBadge`) in `report_screen.dart`;
`ScaChartData` logic; `ai-personalize` edge function.

## Decisions (agreed with owner)

1. **Output:** Inline animated player, matching web. **No MP4 export.**
2. **Narration source:** Deterministic on-device script builder, **reusing `cc_video_jobs` cache by
   `report_id`**. If a completed job exists (from web/Gemini or a prior mobile run), reuse its
   audio + script + SRT. Otherwise build a deterministic script and call `tts-proxy` to create a new job.
3. **Visual fidelity:** Mid-fidelity. Keep the 8–10 scene structure + timing + colors (by
   `scoreLevel`/layer) like web. Reuse existing charts/report widgets. Drop complex character SVGs.
   Light fade/scale/progress-bar animations.
4. **Player engine:** Approach A — "audio as the clock". `just_audio` plays audio; `positionStream`
   drives current scene, per-scene `localProgress` (0→1), and subtitle cue selection.

## Architecture

New feature module `lib/features/video_report/`:

- `data/video_report_repository.dart` — `cc_video_jobs` cache lookup + `tts-proxy` create/poll; fetch audio.
- `logic/narration_script_builder.dart` — **pure**: `CcReport` + narratives → `List<VideoScene>`
  (id, narration text, scene payload). Testable, no I/O.
- `logic/scene_timeline.dart` — **pure**: SRT + audio duration → per-scene `startMs/endMs` + `SubtitleCue[]`.
  Fallback: proportional split by narration text length when SRT missing (mirrors web).
- `video_report_providers.dart` — Riverpod orchestration (equivalent to `useVideoReport.ts`):
  states `idle | loadingCache | generating | ready | error`.
- `presentation/video_report_screen.dart` — the player. New route `/survey/report/:id/video`.
- `presentation/scenes/*.dart` — scene widgets taking `localProgress`.

## Scenes (parity, conditional like web)

Intro → Overall (radar S/C/A, reuse `ScaRadarChart`) → Structure → Culture → Activity
→ *(ESI if `score_esi > 0`)* → *(eNPS if `score_enps != null`)* → Bottleneck
→ Recommendations (3 actions per bottleneck layer) → Closing.

Free reports have fewer scenes (no sub_scores / ESI / eNPS). Colors follow `scoreLevel` and layer
palette matching web.

## Data flow

1. Open screen → provider queries `cc_video_jobs` where `report_id = id AND status = 'completed'`
   (like web `findExistingJob`).
2. Cache hit → use stored `audio_url` + `narration_script` + `subtitle_data.srt` → build timeline.
3. Cache miss → `narration_script_builder` produces deterministic script (vi/en) →
   `tts-proxy` (`action:'create'` then poll, writing `cc_video_jobs`) → audio + SRT.
4. `scene_timeline` maps SRT to scenes → play via Approach A.

## Launch point

"Xem video báo cáo" button in `report_screen.dart` (both Free & Premium) → navigates to new route.

## Error handling

- TTS error/timeout → message + retry button.
- Offline → early guard.
- No SRT from `tts-proxy` → `scene_timeline` proportional fallback.

## Testing (TDD)

- Unit: `narration_script_builder` (scene count for Free / Premium / ESI / eNPS variants),
  `scene_timeline` (SRT parse + proportional fallback), cache-vs-create selection logic.
- Widget: `video_report_screen` (render, play/pause).

## To verify before/at planning

- Real schema of `cc_video_jobs`.
- Whether `tts-proxy` returns `subtitle_data.srt` for the mobile call path; extend `TtsResult`
  (currently only `audioUrl` + `durationMs`) to capture SRT + a job-aware create/poll path.

## Not doing (YAGNI)

- MP4 export / screen recording.
- Gemini dynamic narration on mobile (deterministic instead; cache still reuses web's Gemini output).
- Character SVG illustrations.
