// Video Report — SRT parsing + scene timeline assignment.

import 'package:workreflection_mobile/features/video_report/models/video_report_models.dart';

/// Parses a standard SRT subtitle string into [SubtitleCue]s.
///
/// Each block is expected to be:
///   `index`
///   HH:MM:SS,mmm --> HH:MM:SS,mmm
///   `one or more text lines`
///
/// Malformed blocks (missing/unparseable timing line, no text) are skipped
/// gracefully rather than throwing.
List<SubtitleCue> parseSrt(String srt) {
  final cues = <SubtitleCue>[];
  // Blocks are separated by one or more blank lines. Normalize newlines first.
  final normalized = srt.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final blocks = normalized.split(RegExp(r'\n[ \t]*\n'));

  for (final block in blocks) {
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;

    // Find the timing line (contains '-->'). The index line may or may not be
    // present; we don't strictly require it.
    final timingIndex = lines.indexWhere((l) => l.contains('-->'));
    if (timingIndex < 0) continue;

    final timing = _parseTiming(lines[timingIndex]);
    if (timing == null) continue;

    final textLines = lines.sublist(timingIndex + 1);
    if (textLines.isEmpty) continue;

    cues.add(SubtitleCue(
      text: textLines.join('\n'),
      startMs: timing.$1,
      endMs: timing.$2,
    ));
  }

  return cues;
}

final _timeRe = RegExp(r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})');

/// Parses a `HH:MM:SS,mmm --> HH:MM:SS,mmm` line into (startMs, endMs).
(int, int)? _parseTiming(String line) {
  final parts = line.split('-->');
  if (parts.length != 2) return null;
  final start = _parseTimestamp(parts[0].trim());
  final end = _parseTimestamp(parts[1].trim());
  if (start == null || end == null) return null;
  return (start, end);
}

/// Parses a single `HH:MM:SS,mmm` timestamp into milliseconds.
int? _parseTimestamp(String value) {
  final m = _timeRe.firstMatch(value);
  if (m == null) return null;
  final hours = int.parse(m.group(1)!);
  final minutes = int.parse(m.group(2)!);
  final seconds = int.parse(m.group(3)!);
  // Pad fractional part to milliseconds (e.g. '5' -> 500, '50' -> 500? no).
  final fracRaw = m.group(4)!;
  final frac = int.parse(fracRaw.padRight(3, '0'));
  return ((hours * 3600 + minutes * 60 + seconds) * 1000) + frac;
}

/// Assigns start/end times (ms) to each narration [scene] so the scenes cover
/// `[0, audioDurationMs]` contiguously with no gaps.
///
/// - If [cues] is empty, splits `audioDurationMs` proportionally to each
///   scene's `text.length`.
/// - If [cues] are present, distributes cue count across scenes proportionally
///   to text length (deterministic, no fuzzy text matching) and derives the
///   boundaries from the assigned cues' timings.
/// - The first scene always starts at 0, and the last scene always ends exactly
///   at `audioDurationMs`.
List<TimedScene> assignSceneTimings({
  required List<NarrationScene> scenes,
  required List<SubtitleCue> cues,
  required int audioDurationMs,
}) {
  if (scenes.isEmpty) return const [];

  final duration = audioDurationMs > 0 ? audioDurationMs : 0;

  // Compute per-scene weights from text length; fall back to equal weights if
  // total text length is zero.
  final lengths = scenes.map((s) => s.text.length).toList();
  final totalLen = lengths.fold<int>(0, (a, b) => a + b);
  final weights = totalLen > 0
      ? lengths.map((l) => l / totalLen).toList()
      : List<double>.filled(scenes.length, 1 / scenes.length);

  // Build cumulative boundaries in ms. We always derive boundaries from the
  // weights so the split is deterministic; cues (when present) only refine the
  // total span we distribute over, but the proportional model is identical.
  //
  // boundaries[0] = 0, boundaries[n] = audioDurationMs.
  final boundaries = <int>[0];
  var acc = 0.0;
  for (var i = 0; i < scenes.length; i++) {
    acc += weights[i];
    // Guard the last boundary to land exactly on duration.
    final ms = i == scenes.length - 1 ? duration : (acc * duration).round();
    boundaries.add(ms);
  }

  // If cues are present, snap interior boundaries to the nearest cue boundary
  // so scene transitions align with subtitle transitions. Deterministic and
  // gap-free (each boundary is chosen independently, monotonic order preserved
  // by clamping to the previous boundary).
  if (cues.isNotEmpty) {
    final cueBoundaries = <int>{0, duration};
    for (final c in cues) {
      cueBoundaries.add(c.startMs.clamp(0, duration));
      cueBoundaries.add(c.endMs.clamp(0, duration));
    }
    final sortedCueBoundaries = cueBoundaries.toList()..sort();
    for (var i = 1; i < boundaries.length - 1; i++) {
      final target = boundaries[i];
      final snapped = _nearest(sortedCueBoundaries, target);
      // Keep monotonic (>= previous boundary).
      boundaries[i] = snapped < boundaries[i - 1] ? boundaries[i - 1] : snapped;
    }
    boundaries[0] = 0;
    boundaries[boundaries.length - 1] = duration;
  }

  final result = <TimedScene>[];
  for (var i = 0; i < scenes.length; i++) {
    result.add(TimedScene(
      id: scenes[i].id,
      text: scenes[i].text,
      startMs: boundaries[i],
      endMs: boundaries[i + 1],
    ));
  }
  return result;
}

/// Returns the value in [sorted] nearest to [target].
int _nearest(List<int> sorted, int target) {
  var best = sorted.first;
  var bestDist = (best - target).abs();
  for (final v in sorted) {
    final d = (v - target).abs();
    if (d < bestDist) {
      best = v;
      bestDist = d;
    }
  }
  return best;
}
