// Video Report — audio playback controller abstraction.
//
// The player screen uses audio playback position as its master clock. This thin
// abstraction wraps just_audio's AudioPlayer behind an interface so screens can
// be tested with a fake (no platform channels). One controller per screen,
// created and disposed by [videoAudioControllerProvider] (autoDispose).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Minimal audio-playback surface the player screen depends on.
abstract class VideoAudioController {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  bool get playing;
  Future<void> load(String url, Map<String, String> headers);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

/// Live implementation backed by a just_audio [AudioPlayer].
class JustAudioController implements VideoAudioController {
  JustAudioController() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  bool get playing => _player.playing;

  @override
  Future<void> load(String url, Map<String, String> headers) async {
    await _player.setUrl(url, headers: headers);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}

/// One audio controller per screen (NOT a singleton). The player screen holds a
/// manual subscription for its entire lifetime, so this autoDispose provider
/// creates a fresh controller when the screen mounts and disposes it (via
/// [ref.onDispose]) exactly once, when that subscription closes on unmount.
final videoAudioControllerProvider =
    Provider.autoDispose<VideoAudioController>((ref) {
  final c = JustAudioController();
  ref.onDispose(c.dispose);
  return c;
});
