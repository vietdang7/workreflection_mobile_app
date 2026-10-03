// Dòng thời gian của video hướng dẫn: cảnh nào chạy từ mili giây nào tới mili
// giây nào, phụ đề nào hiện lúc nào, và có giọng đọc hay không.
//
// Hai nguồn:
//   • CÓ giọng đọc: file `assets/intro/intro_<lang>.json` do
//     `tool/gen_intro_narration.dart` ghi, với thời điểm đo thật từ mp3. Chỉ
//     dùng khi câu trong file khớp TỪNG CHỮ với lời đọc hiện tại.
//   • KHÔNG có giọng đọc (chưa sinh, hoặc lời đọc đã sửa mà chưa sinh lại):
//     ước tính thời lượng theo độ dài câu. Video vẫn chạy, chỉ là không tiếng.
//
// Dart thuần, không Flutter, để test thẳng được.

import '../video_report/models/video_report_models.dart' show SubtitleCue;
import 'intro_video_script.dart';

/// Tốc độ đọc dùng để ước tính khi không có giọng đọc (ký tự mỗi giây). Đủ
/// chậm để đọc kịp phụ đề và xem hết hình động của cảnh.
const double kIntroCharsPerSecond = 15;

/// Một cảnh không ngắn hơn mức này, kể cả khi lời đọc rất ngắn.
const int kIntroMinSceneMs = 4500;

/// Khoảng lặng sau mỗi cảnh (trừ cảnh cuối). Cùng con số với script sinh
/// giọng đọc, để hai chế độ có nhịp giống nhau.
const int kIntroSceneGapMs = 600;

class IntroTimedScene {
  const IntroTimedScene({
    required this.id,
    required this.text,
    required this.startMs,
    required this.endMs,
  });
  final IntroSceneId id;
  final String text;
  final int startMs;
  final int endMs;
  int get durationMs => endMs - startMs;
}

class IntroTimeline {
  const IntroTimeline({
    required this.scenes,
    required this.cues,
    required this.durationMs,
    this.audioAsset,
  });

  final List<IntroTimedScene> scenes;
  final List<SubtitleCue> cues;
  final int durationMs;

  /// Đường dẫn asset mp3 (vd `assets/intro/intro_vi.mp3`), hoặc null khi
  /// video chạy không tiếng.
  final String? audioAsset;

  /// Cảnh đang chạy ở [ms]; quá cuối thì là cảnh cuối.
  IntroTimedScene? sceneAt(int ms) {
    if (scenes.isEmpty) return null;
    for (final s in scenes) {
      if (ms >= s.startMs && ms < s.endMs) return s;
    }
    return ms < 0 ? scenes.first : scenes.last;
  }

  /// Phụ đề đang hiện ở [ms], hoặc null (khoảng lặng giữa hai cảnh).
  SubtitleCue? cueAt(int ms) {
    for (final c in cues) {
      if (ms >= c.startMs && ms < c.endMs) return c;
    }
    return null;
  }

  /// Tiến độ 0..1 trong cảnh đang chạy.
  double sceneProgressAt(int ms) {
    final s = sceneAt(ms);
    if (s == null || s.durationMs <= 0) return 1;
    return ((ms - s.startMs) / s.durationMs).clamp(0.0, 1.0);
  }
}

/// True khi file ghi giọng đọc [recorded] đọc ĐÚNG lời đọc [scenes] hiện tại:
/// cùng số cảnh, cùng thứ tự, cùng từng chữ, và thời điểm hợp lệ.
bool introRecordingMatches(
  List<IntroNarrationScene> scenes,
  Map<String, dynamic> recorded,
) {
  final list = recorded['scenes'];
  if (list is! List || list.length != scenes.length) return false;
  if (recorded['audio'] is! String) return false;
  var prevEnd = 0;
  for (var i = 0; i < scenes.length; i++) {
    final r = list[i];
    if (r is! Map) return false;
    if (r['id'] != scenes[i].id.name || r['text'] != scenes[i].text) {
      return false;
    }
    final start = r['startMs'];
    final end = r['endMs'];
    if (start is! int || end is! int) return false;
    if (start != prevEnd || end <= start) return false;
    prevEnd = end;
  }
  return true;
}

/// Dựng dòng thời gian cho [scenes]. Có [recorded] khớp thì dùng giọng đọc,
/// không thì ước tính.
IntroTimeline buildIntroTimeline(
  List<IntroNarrationScene> scenes, {
  Map<String, dynamic>? recorded,
}) {
  final useAudio = recorded != null && introRecordingMatches(scenes, recorded);

  final timed = <IntroTimedScene>[];
  if (useAudio) {
    final list = recorded['scenes'] as List;
    for (var i = 0; i < scenes.length; i++) {
      final r = list[i] as Map;
      timed.add(
        IntroTimedScene(
          id: scenes[i].id,
          text: scenes[i].text,
          startMs: r['startMs'] as int,
          endMs: r['endMs'] as int,
        ),
      );
    }
  } else {
    var t = 0;
    for (var i = 0; i < scenes.length; i++) {
      final speech = _estimateSpeechMs(scenes[i].text);
      final isLast = i == scenes.length - 1;
      final end = t + speech + (isLast ? 0 : kIntroSceneGapMs);
      timed.add(
        IntroTimedScene(
          id: scenes[i].id,
          text: scenes[i].text,
          startMs: t,
          endMs: end,
        ),
      );
      t = end;
    }
  }

  final cues = <SubtitleCue>[];
  for (var i = 0; i < timed.length; i++) {
    final s = timed[i];
    final isLast = i == timed.length - 1;
    // Phụ đề tắt trong khoảng lặng cuối cảnh.
    final speechEnd = isLast
        ? s.endMs
        : (s.endMs - kIntroSceneGapMs).clamp(s.startMs + 1, s.endMs);
    cues.addAll(_splitCues(s.text, s.startMs, speechEnd));
  }

  return IntroTimeline(
    scenes: timed,
    cues: cues,
    durationMs: timed.isEmpty ? 0 : timed.last.endMs,
    audioAsset: useAudio ? recorded['audio'] as String : null,
  );
}

int _estimateSpeechMs(String text) {
  final ms = (text.length / kIntroCharsPerSecond * 1000).round();
  return ms < kIntroMinSceneMs ? kIntroMinSceneMs : ms;
}

/// Chia lời đọc của một cảnh thành từng câu (sau dấu . ? ! :), chia thời gian
/// theo độ dài câu. Câu dài hai dòng phụ đề vẫn đọc kịp; cắt nhỏ hơn thì mắt
/// phải đuổi theo chữ.
List<SubtitleCue> _splitCues(String text, int startMs, int endMs) {
  final parts = text
      .split(RegExp(r'(?<=[.!?:])\s+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return const [];
  final total = parts.fold<int>(0, (a, p) => a + p.length);
  final span = endMs - startMs;
  final out = <SubtitleCue>[];
  var acc = 0;
  var cueStart = startMs;
  for (var i = 0; i < parts.length; i++) {
    acc += parts[i].length;
    final cueEnd = i == parts.length - 1
        ? endMs
        : startMs + (span * acc / total).round();
    out.add(SubtitleCue(text: parts[i], startMs: cueStart, endMs: cueEnd));
    cueStart = cueEnd;
  }
  return out;
}
