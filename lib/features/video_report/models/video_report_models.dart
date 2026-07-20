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
