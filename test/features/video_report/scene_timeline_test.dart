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
}
