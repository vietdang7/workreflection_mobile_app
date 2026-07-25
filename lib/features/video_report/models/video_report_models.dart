// Video Report — foundation data models (scenes, subtitle cues, assembled player data).

enum VideoSceneId {
  intro, overall, structure, culture, activity,
  bottleneck, esi, enps, recommendations, closing,
}

class NarrationScene {
  const NarrationScene({required this.id, required this.text});
  final VideoSceneId id;
  final String text;
}

class SubtitleCue {
  const SubtitleCue({required this.text, required this.startMs, required this.endMs});
  final String text;
  final int startMs;
  final int endMs;
}

class TimedScene {
  const TimedScene({required this.id, required this.text, required this.startMs, required this.endMs});
  final VideoSceneId id;
  final String text;
  final int startMs;
  final int endMs;
  int get durationMs => endMs - startMs;
}

/// Fully assembled data the player needs.
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
