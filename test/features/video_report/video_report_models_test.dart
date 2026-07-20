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
