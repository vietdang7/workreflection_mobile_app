# Video Report (mobile) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Use superpowers:test-driven-development for every code task.

**Goal:** Add an inline animated "Video Report" player to the Flutter app that plays a scene sequence synced to a TTS voiceover + subtitles, reaching parity with the web Remotion video report.

**Architecture:** New feature module `lib/features/video_report/`. Pure logic (narration script builder, SRT parser, scene timeline) is separated from I/O (repository over `cc_video_jobs` + `tts-proxy`) and UI (player screen + scene widgets). The player uses "audio-as-clock" (Approach A): `just_audio` plays the audio and its `positionStream` drives the current scene, per-scene progress, and subtitle cue. Narration script is built deterministically on-device; the `cc_video_jobs` table is reused as a cache keyed by `report_id`.

**Tech Stack:** Flutter, Riverpod, go_router, `just_audio` ^0.9.40 (already a dep), Supabase (`supabase_flutter`), shared backend `sukpcxevcjnhiuyaoqxi` (NO DB migration needed — `cc_video_jobs` + `tts-proxy` already exist).

## Backend contract (verified from web repo — do not change backend)

- Table `cc_video_jobs`: `id, report_id, user_id, status('pending'|'processing'|'completed'|'failed'), narration_script(jsonb), audio_url(text, RAW ausynclab/azure url), audio_id(text), subtitle_data(jsonb = {srt: string, duration: number|null}), error_message, created_at, updated_at`. RLS: user reads/inserts/updates own rows.
- `tts-proxy` edge function actions:
  - POST `{action:'create', report_id, user_id, text, voice_id, narration_script, language, speed}` → inserts a job row (status `processing`), calls Ausynclab with a server callback → returns `{job_id, audio_id}`. Completion is async (Ausynclab → edge callback sets `status='completed'`, `audio_url`, `subtitle_data`).
  - POST `{action:'poll', job_id}` → `{id, status, audio_url, subtitle_data, error_message}`.
  - GET `?audio_url=<encoded raw url>` (headers: `Authorization: Bearer <access_token>`, `apikey: <anon>`) → streams `audio/wav`. Ownership-checked. **Mobile must play through this proxy URL** (raw `audio_url` in the job is un-persisted/ephemeral).
- Voice IDs (from `survey_repository.dart`): vi = `1619321`, en = `1914576`.

## Existing pieces to reuse (already in repo — read before coding)

- `lib/core/models/survey_models.dart`: `CcReportFull` (fields `id, surveyId, userId, scoreTotal, scoreStructure, scoreCulture, scoreActivity, scoreEsi(double?), scoreEnps(int?), bottleneckLayer(SurveyLayer), scoreLevel(ScoreLevel), subScores(Map<String,dynamic>?)`), `SurveyLayer`, `ScoreLevel`, `SurveyType`, `CcNarrative`, `SubComponentScore`, `TtsResult`.
- `lib/features/survey/survey_providers.dart`: `narrativesProvider`, `layerSubScoresProvider`, `surveyRepositoryProvider`. Report-by-id fetch: see `report_screen.dart` private `_reportProvider(reportId)` — replicate its repository call in a new PUBLIC provider (Task 4).
- `lib/features/survey/presentation/report_screen.dart`: helper `selectNarrative(narratives, type:, layer:, score:, language:)`; radar widget `ScaRadarChart`; `ccProfileProvider`, `appLocaleProvider`.
- `lib/core/supabase/supabase_config.dart`: `SupabaseConfig.url`, `SupabaseConfig.anonKey`.
- `lib/core/theme/wr_colors.dart`, `wr_theme.dart` for styling.

## Scene colors (mirror web `scene-planner.ts`)

```dart
// Score-level accent colors
const kScoreLevelColors = {
  'HIGH': Color(0xFF22C55E), 'GOOD': Color(0xFF3B82F6),
  'WARNING': Color(0xFFF59E0B), 'CRITICAL': Color(0xFFEF4444),
};
// Layer colors
const kLayerColors = {
  'STRUCTURE': Color(0xFF6366F1), 'CULTURE': Color(0xFFEC4899), 'ACTIVITY': Color(0xFFF59E0B),
};
```

Test runner for the whole plan: `flutter test <path>` (single file/test) and `flutter analyze` + `flutter test` for gates.

---

### Task 1: Models

**Files:**
- Create: `lib/features/video_report/models/video_report_models.dart`
- Test: `test/features/video_report/video_report_models_test.dart`

**Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/features/video_report/models/video_report_models.dart';

void main() {
  test('SubtitleCue holds timing', () {
    const c = SubtitleCue(text: 'xin chào', startMs: 0, endMs: 1200);
    expect(c.endMs - c.startMs, 1200);
  });

  test('TimedScene exposes duration', () {
    const s = TimedScene(id: VideoSceneId.intro, text: 't', startMs: 0, endMs: 3000);
    expect(s.durationMs, 3000);
  });

  test('VideoSceneId has 10 canonical scenes', () {
    expect(VideoSceneId.values.length, 10);
  });
}
```

**Step 2:** Run `flutter test test/features/video_report/video_report_models_test.dart` — Expected: FAIL (file/types missing).

**Step 3: Implement**

```dart
import 'package:flutter/foundation.dart';

enum VideoSceneId {
  intro, overall, structure, culture, activity,
  bottleneck, esi, enps, recommendations, closing,
}

@immutable
class NarrationScene {
  const NarrationScene({required this.id, required this.text});
  final VideoSceneId id;
  final String text;
}

@immutable
class SubtitleCue {
  const SubtitleCue({required this.text, required this.startMs, required this.endMs});
  final String text;
  final int startMs;
  final int endMs;
}

@immutable
class TimedScene {
  const TimedScene({required this.id, required this.text, required this.startMs, required this.endMs});
  final VideoSceneId id;
  final String text;
  final int startMs;
  final int endMs;
  int get durationMs => endMs - startMs;
}

/// Fully assembled data the player needs.
@immutable
class VideoReportData {
  const VideoReportData({
    required this.scenes,
    required this.cues,
    required this.audioUrl,
    required this.audioDurationMs,
  });
  final List<TimedScene> scenes;
  final List<SubtitleCue> cues;
  final String audioUrl; // proxied, playable
  final int audioDurationMs;
}
```

**Step 4:** Run the test — Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/video_report/models/video_report_models.dart test/features/video_report/video_report_models_test.dart
git commit -m "feat(video-report): scene + subtitle models"
```

---

### Task 2: Narration script builder (pure)

Builds the ordered `List<NarrationScene>` from a report. Free reports → no sub-scores/ESI/eNPS scenes. Premium → include ESI scene only if `scoreEsi != null && > 0`, eNPS scene only if `scoreEnps != null`.

**Files:**
- Create: `lib/features/video_report/logic/narration_script_builder.dart`
- Test: `test/features/video_report/narration_script_builder_test.dart`

**Step 1: Write failing test** (covers scene-set variants — the highest-value behavior)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/video_report/logic/narration_script_builder.dart';
import 'package:workreflection_mobile/features/video_report/models/video_report_models.dart';

CcReportFull _report({
  double esi = 0, int? enps, SurveyType type = SurveyType.premium,
}) => CcReportFull(
  id: 'r1', surveyId: 's1', userId: 'u1',
  scoreTotal: 3.4, scoreStructure: 3.2, scoreCulture: 3.6, scoreActivity: 3.1,
  scoreEsi: esi == 0 ? null : esi, scoreEnps: enps,
  bottleneckLayer: SurveyLayer.activity, scoreLevel: ScoreLevel.warning,
  subScores: const {}, selectedNarrativeVariants: null,
  createdAt: DateTime(2026, 7, 20),
);

void main() {
  const builder = NarrationScriptBuilder();

  test('premium with esi+enps produces all 10 scenes in order', () {
    final scenes = builder.build(
      report: _report(esi: 3.5, enps: 20),
      narratives: const [], userName: 'An', locale: 'vi', surveyType: SurveyType.premium,
    );
    expect(scenes.map((s) => s.id).toList(), [
      VideoSceneId.intro, VideoSceneId.overall, VideoSceneId.structure,
      VideoSceneId.culture, VideoSceneId.activity, VideoSceneId.esi,
      VideoSceneId.enps, VideoSceneId.bottleneck, VideoSceneId.recommendations,
      VideoSceneId.closing,
    ]);
  });

  test('premium without esi/enps omits those two scenes', () {
    final scenes = builder.build(
      report: _report(), narratives: const [], userName: 'An', locale: 'vi',
      surveyType: SurveyType.premium,
    );
    expect(scenes.any((s) => s.id == VideoSceneId.esi), isFalse);
    expect(scenes.any((s) => s.id == VideoSceneId.enps), isFalse);
    expect(scenes.length, 8);
  });

  test('free report omits layer-detail scenes', () {
    final scenes = builder.build(
      report: _report(type: SurveyType.free), narratives: const [],
      userName: 'An', locale: 'vi', surveyType: SurveyType.free,
    );
    // free: intro, overall, bottleneck, recommendations, closing
    expect(scenes.map((s) => s.id).toList(), [
      VideoSceneId.intro, VideoSceneId.overall, VideoSceneId.bottleneck,
      VideoSceneId.recommendations, VideoSceneId.closing,
    ]);
  });

  test('every scene has non-empty text', () {
    final scenes = builder.build(
      report: _report(esi: 3.5, enps: 20), narratives: const [],
      userName: 'An', locale: 'vi', surveyType: SurveyType.premium,
    );
    expect(scenes.every((s) => s.text.trim().isNotEmpty), isTrue);
  });
}
```

**Step 2:** Run test — Expected: FAIL.

**Step 3: Implement** (deterministic Vietnamese/English templates; use `selectNarrative` output when available, else score-based sentence). Keep text short — 1–2 sentences per scene.

```dart
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/video_report/models/video_report_models.dart';

class NarrationScriptBuilder {
  const NarrationScriptBuilder();

  List<NarrationScene> build({
    required CcReportFull report,
    required List<CcNarrative> narratives,
    required String userName,
    required String locale,
    required SurveyType surveyType,
  }) {
    final vi = locale != 'en';
    final scenes = <NarrationScene>[];
    String n1(String v'text', String enText) => vi ? v'text : enText; // see note

    // intro
    scenes.add(NarrationScene(
      id: VideoSceneId.intro,
      text: vi
        ? 'Xin chào ${userName.isEmpty ? 'bạn' : userName}, đây là báo cáo phản chiếu của bạn.'
        : 'Hello ${userName.isEmpty ? 'there' : userName}, here is your reflection report.',
    ));
    // overall
    scenes.add(NarrationScene(
      id: VideoSceneId.overall,
      text: vi
        ? 'Điểm tổng của bạn là ${report.scoreTotal.toStringAsFixed(1)} trên 5, ở mức ${report.scoreLevel.toJson()}.'
        : 'Your overall score is ${report.scoreTotal.toStringAsFixed(1)} out of 5, level ${report.scoreLevel.toJson()}.',
    ));

    if (surveyType == SurveyType.premium) {
      scenes.add(_layerScene(VideoSceneId.structure, 'STRUCTURE', report.scoreStructure, narratives, report, locale, vi));
      scenes.add(_layerScene(VideoSceneId.culture, 'CULTURE', report.scoreCulture, narratives, report, locale, vi));
      scenes.add(_layerScene(VideoSceneId.activity, 'ACTIVITY', report.scoreActivity, narratives, report, locale, vi));
      if (report.scoreEsi != null && report.scoreEsi! > 0) {
        scenes.add(NarrationScene(id: VideoSceneId.esi, text: vi
          ? 'Chỉ số hài lòng nhân viên đạt ${report.scoreEsi!.toStringAsFixed(1)} trên 5.'
          : 'Employee satisfaction index is ${report.scoreEsi!.toStringAsFixed(1)} out of 5.'));
      }
      if (report.scoreEnps != null) {
        scenes.add(NarrationScene(id: VideoSceneId.enps, text: vi
          ? 'Chỉ số eNPS của bạn là ${report.scoreEnps}.'
          : 'Your eNPS score is ${report.scoreEnps}.'));
      }
    }

    // bottleneck
    final bnLayer = report.bottleneckLayer.toJson();
    scenes.add(NarrationScene(id: VideoSceneId.bottleneck, text: vi
      ? 'Điểm nghẽn lớn nhất nằm ở lớp ${_layerVi(bnLayer)}. Đây là nơi nên tập trung cải thiện.'
      : 'The biggest bottleneck is the $bnLayer layer. Focus your improvement here.'));
    // recommendations
    scenes.add(NarrationScene(id: VideoSceneId.recommendations, text: vi
      ? 'Ba hành động gợi ý sẽ giúp bạn cải thiện lớp ${_layerVi(bnLayer)} trong 30 ngày tới.'
      : 'Three suggested actions will help you improve the $bnLayer layer over the next 30 days.'));
    // closing
    scenes.add(NarrationScene(id: VideoSceneId.closing, text: vi
      ? 'Cảm ơn bạn đã lắng nghe. Hãy bắt đầu hành trình phát triển của mình.'
      : 'Thank you for watching. Start your development journey today.'));

    return scenes;
  }

  NarrationScene _layerScene(VideoSceneId id, String layer, double score,
      List<CcNarrative> narratives, CcReportFull report, String locale, bool vi) {
    return NarrationScene(id: id, text: vi
      ? 'Lớp ${_layerVi(layer)} đạt ${score.toStringAsFixed(1)} trên 5.'
      : 'The $layer layer scored ${score.toStringAsFixed(1)} out of 5.');
  }

  String _layerVi(String layer) => switch (layer) {
    'STRUCTURE' => 'Cấu trúc', 'CULTURE' => 'Văn hoá', 'ACTIVITY' => 'Hoạt động', _ => layer,
  };
}
```

> NOTE: remove the placeholder `n1` helper line — it is illustrative only. Confirm `ScoreLevel.toJson()` and `SurveyLayer.toJson()` return the expected uppercase strings by reading `survey_models.dart`; adjust if the enum API differs.

**Step 4:** Run test — Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/video_report/logic/narration_script_builder.dart test/features/video_report/narration_script_builder_test.dart
git commit -m "feat(video-report): deterministic narration script builder"
```

---

### Task 3: SRT parser + scene timeline (pure)

**Files:**
- Create: `lib/features/video_report/logic/scene_timeline.dart`
- Test: `test/features/video_report/scene_timeline_test.dart`

**Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/features/video_report/logic/scene_timeline.dart';
import 'package:workreflection_mobile/features/video_report/models/video_report_models.dart';

const _srt = '''
1
00:00:00,000 --> 00:00:02,000
Xin chào

2
00:00:02,000 --> 00:00:05,000
Điểm tổng của bạn
''';

void main() {
  test('parseSrt reads cues with ms timing', () {
    final cues = parseSrt(_srt);
    expect(cues.length, 2);
    expect(cues.first.startMs, 0);
    expect(cues.first.endMs, 2000);
    expect(cues[1].endMs, 5000);
  });

  test('assignSceneTimings covers full audio without gaps', () {
    final scenes = [
      const NarrationScene(id: VideoSceneId.intro, text: 'a'),
      const NarrationScene(id: VideoSceneId.overall, text: 'bb'),
    ];
    final timed = assignSceneTimings(scenes: scenes, cues: parseSrt(_srt), audioDurationMs: 5000);
    expect(timed.first.startMs, 0);
    expect(timed.last.endMs, 5000);
  });

  test('assignSceneTimings falls back to proportional split when no cues', () {
    final scenes = [
      const NarrationScene(id: VideoSceneId.intro, text: 'aa'),   // len 2
      const NarrationScene(id: VideoSceneId.overall, text: 'aaaa'), // len 4
    ];
    final timed = assignSceneTimings(scenes: scenes, cues: const [], audioDurationMs: 6000);
    // 2:4 ratio → 2000ms / 4000ms
    expect(timed.first.startMs, 0);
    expect(timed.first.endMs, 2000);
    expect(timed.last.endMs, 6000);
  });
}
```

**Step 2:** Run — Expected: FAIL.

**Step 3: Implement** — `parseSrt` (handles `HH:MM:SS,mmm` timestamps), `assignSceneTimings` (map each scene to the cue whose text best matches its narration by normalized-prefix; when cues empty, split `audioDurationMs` proportionally to `text.length`; always clamp first scene start=0 and last scene end=audioDurationMs). Mirror the intent of web `subtitle-timing.ts` but simplified.

**Step 4:** Run — Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/video_report/logic/scene_timeline.dart test/features/video_report/scene_timeline_test.dart
git commit -m "feat(video-report): SRT parser + scene timeline with proportional fallback"
```

---

### Task 4: Repository + orchestration provider

**Files:**
- Create: `lib/features/video_report/data/video_report_repository.dart`
- Create: `lib/features/video_report/video_report_providers.dart`
- Modify: `lib/features/survey/survey_providers.dart` (add PUBLIC `reportByIdProvider` family if not present — mirror `report_screen.dart` `_reportProvider`)
- Test: `test/features/video_report/video_report_providers_test.dart`

**Repository responsibilities:**
- `Future<Map<String,dynamic>?> findCompletedJob(String reportId)` → `client.from('cc_video_jobs').select().eq('report_id',reportId).eq('status','completed').order('created_at',ascending:false).limit(1).maybeSingle()`.
- `Future<String> createJob({reportId, userId, text, voiceId, narrationScriptJson, language})` → `functions.invoke('tts-proxy', body:{action:'create', report_id, user_id, text, voice_id, narration_script, language, speed:1.0})` → return `job_id`.
- `Future<Map<String,dynamic>> pollJob(String jobId)` → `functions.invoke('tts-proxy', body:{action:'poll', job_id})` → `.data`.
- `Future<VideoReportData> waitForCompletion(jobId, scenes)` → poll every 3s up to 60 times; on `completed` extract `audio_url` + `subtitle_data['srt']` + duration; throw on `failed`/timeout.
- `String proxiedAudioUrl(String rawUrl)` → `'${SupabaseConfig.url}/functions/v1/tts-proxy?audio_url=${Uri.encodeComponent(rawUrl)}'`.
- `Map<String,String> audioHeaders()` → `{'Authorization': 'Bearer ${session.accessToken}', 'apikey': SupabaseConfig.anonKey}` (session from `Supabase.instance.client.auth.currentSession`).

Define an abstract `VideoReportRepository` interface so tests can inject a fake. Concrete `SupabaseVideoReportRepository`.

**Provider** `videoReportDataProvider = FutureProvider.family<VideoReportData, String>((ref, reportId) async {...})`:
1. Read report (`reportByIdProvider(reportId)`), `narrativesProvider`, `appLocaleProvider`, `ccProfileProvider` (for userName), surveyType from report.
2. `final job = await repo.findCompletedJob(reportId);`
3. If job != null with `audio_url`: build scenes from stored `narration_script` (fallback: rebuild deterministically), parse `subtitle_data['srt']`, assign timings → return `VideoReportData` (audio = proxiedAudioUrl).
4. Else: build script via `NarrationScriptBuilder`, `createJob`, `waitForCompletion` → `VideoReportData`.

**Step 1: Write failing test** (inject a fake repo through Riverpod overrides; assert the provider returns assembled data with a cache hit, and that a cache miss calls `createJob`). Fake repo records calls.

```dart
// Pseudocode skeleton — flesh out with ProviderContainer + overrides.
// Cache-hit case: fake.findCompletedJob returns a completed row with srt → provider returns
//   VideoReportData whose scenes.last.endMs == audioDurationMs and createJob NOT called.
// Cache-miss case: findCompletedJob returns null → provider calls createJob + waitForCompletion.
```

**Step 2–4:** Run the provider test file, implement until green. Command: `flutter test test/features/video_report/video_report_providers_test.dart`.

**Step 5: Commit**

```bash
git add lib/features/video_report/data/video_report_repository.dart lib/features/video_report/video_report_providers.dart lib/features/survey/survey_providers.dart test/features/video_report/video_report_providers_test.dart
git commit -m "feat(video-report): repository + cache-aware orchestration provider"
```

---

### Task 5: Scene widgets (mid-fidelity)

**Files:**
- Create: `lib/features/video_report/presentation/scenes/video_scene.dart` (abstract `VideoScene` widget taking `double progress` 0..1 + payload)
- Create: `lib/features/video_report/presentation/scenes/scene_widgets.dart` (one builder mapping `VideoSceneId` + report → a scene widget; reuse `ScaRadarChart` for `overall`; reuse layer/bottleneck/esi/enps card visuals adapted to dark background; simple fade/scale/progress-bar animations driven by `progress`)
- Test: `test/features/video_report/scene_widgets_test.dart` (widget test: each scene builds without throwing at progress 0.0/0.5/1.0)

**Steps:** TDD — write widget test that pumps each scene at 3 progress values and expects `find.byType` of the scene widget; implement scenes minimally (dark gradient bg + title + number + progress bar; radar for overall). Colors from `kScoreLevelColors`/`kLayerColors`. Commit.

```bash
git commit -m "feat(video-report): mid-fidelity scene widgets"
```

---

### Task 6: Player screen (audio-as-clock)

**Files:**
- Create: `lib/features/video_report/presentation/video_report_screen.dart`
- Test: `test/features/video_report/video_report_screen_test.dart`

**Behavior:**
- `ConsumerStatefulWidget` with `reportId`. Watches `videoReportDataProvider(reportId)`.
- Loading → progress + "Đang tạo video..." message. Error → message + retry (`ref.invalidate`).
- Ready → `just_audio` `AudioPlayer`; `setUrl(data.audioUrl, headers: repo.audioHeaders())`; play.
- Listen to `player.positionStream`; compute `currentScene = scenes.firstWhere(pos in [start,end))`; `localProgress = (pos-start)/duration`; `currentCue = cues.firstWhere(pos in [start,end))`.
- Render 16:9 `AspectRatio` stage with the current scene widget + subtitle overlay (bottom). Controls: play/pause, seek slider, close (dispose player).
- Dispose the player in `dispose()`.

**Step 1: Write failing widget test** — override `videoReportDataProvider` with a canned `VideoReportData` (tiny silent/fake audio or stub the player behind an injectable factory). Assert the screen renders the first scene and a play/pause control. Prefer injecting an `AudioPlayer` factory via provider so the test can pass a fake that exposes a controllable `positionStream`.

**Steps 2–4:** implement until green (`flutter test test/features/video_report/video_report_screen_test.dart`).

**Step 5: Commit**

```bash
git commit -m "feat(video-report): audio-synced player screen"
```

---

### Task 7: Route + launch button + l10n

**Files:**
- Modify: `lib/core/router/app_router.dart` — add `GoRoute(path: '/survey/report/:id/video', builder: (c,s) => VideoReportScreen(reportId: s.pathParameters['id']!))` alongside the existing report routes (outside the shell).
- Modify: `lib/features/survey/presentation/report_screen.dart` — add a "Xem video báo cáo" button (in the report body, near the PDF export action) → `context.push('/survey/report/${report.id}/video')`.
- Modify: `lib/l10n/app_en.arb` + `lib/l10n/app_vi.arb` — add keys: `videoReportButton`, `videoReportTitle`, `videoReportGenerating`, `videoReportError`, `videoReportRetry`. Run `flutter gen-l10n`.
- Test: `test/core/router_test.dart` — add a case asserting the new path resolves (mirror existing router tests).

**Steps:** TDD the router case first (FAIL → add route → PASS). Add button + l10n. Run `flutter gen-l10n`. Commit.

```bash
git commit -m "feat(video-report): route, report-screen launch button, l10n strings"
```

---

### Task 8: Impact analysis + gates

**Step 1:** GitNexus impact on touched symbols (per project CLAUDE.md):
`gitnexus_impact({target: "ReportScreen", direction: "upstream", repo: "appmobileworkreflection"})` and report blast radius before finalizing router/report-screen edits. Warn on HIGH/CRITICAL.

**Step 2:** `flutter analyze` — Expected: no new issues.

**Step 3:** `flutter test` — Expected: all green (existing 779 + new video-report tests).

**Step 4:** `gitnexus_detect_changes({repo: "appmobileworkreflection"})` — verify only expected symbols/flows changed.

**Step 5:** Build gate: `flutter build apk --debug` — Expected: BUILD SUCCESSFUL.

**Step 6: Commit** any lockfile/gen changes, then re-index: `npx gitnexus analyze` (PostToolUse hook may auto-run).

---

## Manual verification checklist (owner, on device)

- Open a Premium report → tap "Xem video báo cáo" → video generates (first time may take up to ~1–2 min for TTS), then plays with voice + subtitles + animated scenes; play/pause/seek/close work.
- Re-open the same report → loads instantly from `cc_video_jobs` cache (no regeneration).
- Open a Free report → shorter video (intro/overall/bottleneck/recommendations/closing), no ESI/eNPS/layer scenes.
- Switch app language to English → narration + subtitles in English.
- Airplane mode → graceful error + retry.

## Risks / notes

- TTS completion is async via Ausynclab→edge callback; `waitForCompletion` polls up to 3 min. Surface progress; treat timeout as a friendly error with retry.
- Raw `audio_url` in `cc_video_jobs` is un-persisted/ephemeral → ALWAYS play via the proxy URL with auth headers (do not use the raw url directly).
- Confirm `ScoreLevel.toJson()` / `SurveyLayer.toJson()` string outputs by reading `survey_models.dart`; adjust narration strings if different.
- No DB migration and no backend edits — all work is client-side Flutter on the shared backend.
```
