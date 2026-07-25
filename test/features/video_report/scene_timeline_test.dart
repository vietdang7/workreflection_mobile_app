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
      const NarrationScene(id: VideoSceneId.intro, text: 'aa'),    // len 2
      const NarrationScene(id: VideoSceneId.overall, text: 'aaaa'), // len 4
    ];
    final timed = assignSceneTimings(scenes: scenes, cues: const [], audioDurationMs: 6000);
    expect(timed.first.startMs, 0);
    expect(timed.first.endMs, 2000);
    expect(timed.last.endMs, 6000);
  });

  test('single scene spans full audio duration', () {
    final scenes = [
      const NarrationScene(id: VideoSceneId.intro, text: 'hello'),
    ];
    final timed = assignSceneTimings(scenes: scenes, cues: const [], audioDurationMs: 4000);
    expect(timed.length, 1);
    expect(timed.first.startMs, 0);
    expect(timed.first.endMs, 4000);
  });

  test('parseSrt ignores malformed blocks gracefully', () {
    const srt = '''
1
not a timestamp line
Bad block

2
00:00:01,000 --> 00:00:03,500
Good block
''';
    final cues = parseSrt(srt);
    expect(cues.length, 1);
    expect(cues.first.startMs, 1000);
    expect(cues.first.endMs, 3500);
    expect(cues.first.text, 'Good block');
  });

  test('empty scenes returns empty list', () {
    final timed = assignSceneTimings(scenes: const [], cues: const [], audioDurationMs: 5000);
    expect(timed, isEmpty);
  });

  test('interior boundary snaps to a nearby cue boundary', () {
    // Three equal-weight scenes over 9000ms → proportional interior boundaries
    // at 3000 and 6000. Provide a cue whose boundary at 3100 is distinct from
    // the proportional 3000 but is the nearest cue boundary to it, so the first
    // interior boundary should snap to 3100 (proving the snap happened).
    final scenes = [
      const NarrationScene(id: VideoSceneId.intro, text: 'aaa'),
      const NarrationScene(id: VideoSceneId.overall, text: 'aaa'),
      const NarrationScene(id: VideoSceneId.structure, text: 'aaa'),
    ];
    const cues = [
      SubtitleCue(text: 'one', startMs: 0, endMs: 3100),
      SubtitleCue(text: 'two', startMs: 3100, endMs: 6000),
      SubtitleCue(text: 'three', startMs: 6000, endMs: 9000),
    ];
    final timed =
        assignSceneTimings(scenes: scenes, cues: cues, audioDurationMs: 9000);
    // First interior boundary (end of scene 0 / start of scene 1) snapped.
    expect(timed[0].endMs, 3100);
    expect(timed[1].startMs, 3100);
    // Invariants preserved.
    expect(timed.first.startMs, 0);
    expect(timed.last.endMs, 9000);
  });

  test('zero-duration guard: many scenes with sparse cues stay positive', () {
    // Many scenes but only one interior cue boundary (2500). Naive snapping
    // would collapse several scenes onto 2500; the guard must keep every scene
    // strictly positive.
    final scenes = [
      const NarrationScene(id: VideoSceneId.intro, text: 'a'),
      const NarrationScene(id: VideoSceneId.overall, text: 'a'),
      const NarrationScene(id: VideoSceneId.structure, text: 'a'),
      const NarrationScene(id: VideoSceneId.culture, text: 'a'),
      const NarrationScene(id: VideoSceneId.activity, text: 'a'),
    ];
    const cues = [
      SubtitleCue(text: 'only', startMs: 2500, endMs: 2500),
    ];
    final timed =
        assignSceneTimings(scenes: scenes, cues: cues, audioDurationMs: 10000);
    expect(timed.length, 5);
    for (final s in timed) {
      expect(s.endMs > s.startMs, isTrue,
          reason: 'scene ${s.id} has non-positive duration '
              '(${s.startMs}..${s.endMs})');
    }
    expect(timed.first.startMs, 0);
    expect(timed.last.endMs, 10000);
  });
}
