// Video Report — audio-synced player screen.
//
// Plays the report's TTS audio and uses the playback position as the master
// clock: the current animated scene (VideoSceneView) and a subtitle overlay are
// derived from the current position in milliseconds. Provides play/pause, a
// seek slider, and a close button.
//
// Strings are localized via AppLocalizations. No MP4 export (out of scope).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workreflection_mobile/l10n/app_localizations.dart';
import '../../../core/models/survey_models.dart';
import '../../profile/profile_providers.dart';
import '../../survey/survey_providers.dart';
import '../data/video_audio_controller.dart';
import '../data/video_report_repository.dart';
import '../models/video_report_models.dart';
import '../video_report_providers.dart';
import 'scenes/video_scene_view.dart';

const _kBg = Color(0xFF0B1121);

/// Fetches the [CcReportFull] the scene widgets render. Kept local to the
/// screen so we do not touch existing survey providers.
final _screenReportProvider =
    FutureProvider.family<CcReportFull?, String>((ref, reportId) async {
  return ref.watch(surveyRepositoryProvider).getReport(reportId);
});

/// Resolves the display name for the intro/closing scenes from the cc profile.
final _screenUserNameProvider = FutureProvider<String>((ref) async {
  final profile = await ref.watch(ccProfileProvider.future);
  return (profile['full_name'] as String?) ??
      (profile['email'] as String?) ??
      '';
});

class VideoReportScreen extends ConsumerStatefulWidget {
  const VideoReportScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<VideoReportScreen> createState() => _VideoReportScreenState();
}

class _VideoReportScreenState extends ConsumerState<VideoReportScreen> {
  StreamSubscription<Duration>? _positionSub;
  bool _loaded = false;

  int _posMs = 0;

  /// Manual subscription that keeps the autoDispose [videoAudioControllerProvider]
  /// alive for the whole screen lifetime. Closing it on [dispose] triggers the
  /// provider's autoDispose → `onDispose(controller.dispose)`, disposing the
  /// underlying player exactly once at unmount (never mid-load/playback).
  late final ProviderSubscription<VideoAudioController> _controllerSub;

  /// The single controller instance for this screen, obtained through
  /// [_controllerSub]. Do NOT read the provider again elsewhere.
  late final VideoAudioController _controller;

  @override
  void initState() {
    super.initState();
    _controllerSub = ref.listenManual(videoAudioControllerProvider, (_, __) {});
    _controller = _controllerSub.read();
  }

  /// Loads audio into the controller and starts playback exactly once.
  void _ensureLoaded(VideoReportData data) {
    if (_loaded) return;
    _loaded = true;

    final headers = ref.read(videoReportRepositoryProvider).audioHeaders();

    _positionSub = _controller.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _posMs = pos.inMilliseconds);
    });

    // Fire-and-forget: load then autoplay.
    () async {
      await _controller.load(data.audioUrl, headers);
      await _controller.play();
    }();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    // Closing the last subscription disposes the controller via the provider's
    // onDispose. Do NOT call _controller.dispose() here (avoid double-dispose).
    _controllerSub.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(videoReportDataProvider(widget.reportId));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.videoReportTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: async.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                l10n.videoReportGenerating,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.videoReportError,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref
                    .invalidate(videoReportDataProvider(widget.reportId)),
                child: Text(l10n.videoReportRetry),
              ),
            ],
          ),
        ),
        data: (data) {
          _ensureLoaded(data);
          return _player(data);
        },
      ),
    );
  }

  // ---- Player -------------------------------------------------------------

  Widget _player(VideoReportData data) {
    final scene = _currentScene(data.scenes, _posMs);
    final progress = _localProgress(scene, _posMs);
    final cue = _currentCue(data.cues, _posMs);

    final report = ref.watch(_screenReportProvider(widget.reportId));
    final locale = ref.watch(appLocaleProvider);
    final userName = ref.watch(_screenUserNameProvider).valueOrNull ?? '';

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (report.valueOrNull != null && scene != null)
                      VideoSceneView(
                        sceneId: scene.id,
                        report: report.value!,
                        progress: progress,
                        locale: locale,
                        userName: userName,
                      )
                    else
                      const ColoredBox(color: _kBg),
                    if (cue != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _SubtitleOverlay(text: cue.text),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _controls(data),
      ],
    );
  }

  Widget _controls(VideoReportData data) {
    final controller = _controller;
    final maxMs = data.audioDurationMs;
    final sliderMax = maxMs <= 0 ? 1.0 : maxMs.toDouble();
    final sliderValue = _posMs.clamp(0, maxMs).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<bool>(
            stream: controller.playingStream,
            initialData: controller.playing,
            builder: (context, snap) {
              final playing = snap.data ?? false;
              return IconButton(
                iconSize: 44,
                color: Colors.white,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: () =>
                    playing ? controller.pause() : controller.play(),
              );
            },
          ),
          Slider(
            value: sliderValue.clamp(0.0, sliderMax),
            max: sliderMax,
            onChanged: maxMs <= 0
                ? null
                : (v) =>
                    controller.seek(Duration(milliseconds: v.round())),
          ),
        ],
      ),
    );
  }

  // ---- Position → scene / cue mapping (robust) ----------------------------

  /// The scene whose [startMs, endMs) contains [posMs]; falls back to the last
  /// scene when past the end, or null when there are no scenes.
  TimedScene? _currentScene(List<TimedScene> scenes, int posMs) {
    if (scenes.isEmpty) return null;
    for (final s in scenes) {
      if (posMs >= s.startMs && posMs < s.endMs) return s;
    }
    return scenes.last;
  }

  double _localProgress(TimedScene? scene, int posMs) {
    if (scene == null || scene.durationMs <= 0) return 1.0;
    return ((posMs - scene.startMs) / scene.durationMs).clamp(0.0, 1.0);
  }

  SubtitleCue? _currentCue(List<SubtitleCue> cues, int posMs) {
    for (final c in cues) {
      if (posMs >= c.startMs && posMs < c.endMs) return c;
    }
    return null;
  }
}

class _SubtitleOverlay extends StatelessWidget {
  const _SubtitleOverlay({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black.withValues(alpha: 0.55),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 16.5, height: 1.3),
      ),
    );
  }
}
