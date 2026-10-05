// Video hướng dẫn toàn màn: cảnh hình động (`IntroSceneView`) + phụ đề + giọng
// đọc AI đã đóng gói sẵn trong app (`assets/intro/intro_<lang>.mp3`).
//
// ĐỒNG HỒ: một `AnimationController` chạy từ 0 tới hết thời lượng. Hình và
// phụ đề luôn đi theo đồng hồ này; tiếng chỉ là thứ phát kèm. Nhờ vậy:
//   • chưa có giọng đọc thì video vẫn chạy y hệt, chỉ không tiếng;
//   • web bắt đầu tắt tiếng (trình duyệt chặn tự phát có tiếng) mà hình vẫn
//     chạy; bấm "Bật tiếng" thì tiếng vào đúng chỗ hình đang tới;
//   • tiếng lệch đồng hồ quá [_kResyncMs] thì kéo đồng hồ theo tiếng.
//
// KHÔNG BAO GIỜ TREO: tải tiếng lỗi hoặc quá [kIntroLoadTimeout] thì hiện câu
// chưa tải được kèm nút đóng. Nút đóng có mặt từ khung hình đầu, kể cả lúc
// đang tải.
//
// Audio dùng lại `videoAudioControllerProvider` của video báo cáo (một
// controller mỗi màn, tự huỷ khi đóng), nên test thay bằng controller giả.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/theme/wr_colors.dart';
import '../../video_report/data/video_audio_controller.dart';
import '../../video_report/presentation/video_subtitle_overlay.dart';
import '../intro_video_providers.dart';
import '../intro_video_script.dart';
import '../intro_video_timeline.dart';
import 'intro_scene_view.dart';

/// Quá thời gian này mà tiếng chưa sẵn sàng thì coi như không tải được.
const Duration kIntroLoadTimeout = Duration(seconds: 8);

/// Tiếng lệch hình quá mức này thì kéo hình theo tiếng.
const int _kResyncMs = 300;

/// Mở video hướng dẫn toàn màn.
///
/// [startMuted] mặc định tắt tiếng trên web, bật tiếng trên điện thoại.
/// [startScene] nhảy thẳng tới cảnh chỉ định (vd khi chọn từ danh sách hướng dẫn).
Future<void> showIntroVideo(
  BuildContext context, {
  bool autoplay = true,
  bool? startMuted,
  IntroSceneId? startScene,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => WrIntroVideoSheet(
        autoplay: autoplay,
        startMuted: startMuted ?? false,
        startScene: startScene,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

enum _Phase { loading, ready, error }

class WrIntroVideoSheet extends ConsumerStatefulWidget {
  const WrIntroVideoSheet({
    super.key,
    this.autoplay = true,
    this.startMuted = false,
    this.startScene,
  });

  final bool autoplay;
  final bool startMuted;
  final IntroSceneId? startScene;

  @override
  ConsumerState<WrIntroVideoSheet> createState() => _WrIntroVideoSheetState();
}

class _WrIntroVideoSheetState extends ConsumerState<WrIntroVideoSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this)
    ..addStatusListener(_onClockStatus);

  _Phase _phase = _Phase.loading;
  IntroTimeline? _timeline;
  late bool _muted = widget.startMuted;
  bool _ended = false;

  ProviderSubscription<VideoAudioController>? _audioSub;
  VideoAudioController? _audio;
  StreamSubscription<Duration>? _audioPosSub;

  /// Bị huỷ (đóng sheet) thì mọi bước async còn dở dừng lại.
  bool _disposed = false;

  bool get _hasAudio => _audio != null && _timeline?.audioAsset != null;
  int get _totalMs => _timeline?.durationMs ?? 0;
  int get _posMs => (_clock.value * _totalMs).round();

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final lang = wrEnglish ? 'en' : 'vi';
    Map<String, dynamic>? recorded;
    try {
      final raw = await ref.read(introTimingSourceProvider)(lang);
      if (raw != null) recorded = _decode(raw);
    } catch (_) {
      recorded = null; // không đọc được file thời lượng → chạy không tiếng
    }
    if (_disposed) return;

    final timeline = buildIntroTimeline(
      introNarrationScenes,
      recorded: recorded,
    );
    _timeline = timeline;
    _clock.duration = Duration(milliseconds: timeline.durationMs);

    final asset = timeline.audioAsset;
    if (asset != null) {
      _audioSub = ref.listenManual(videoAudioControllerProvider, (_, __) {});
      final audio = _audioSub!.read();
      _audio = audio;
      try {
        await audio
            .load('asset:///$asset', const {})
            .timeout(kIntroLoadTimeout);
      } catch (_) {
        if (_disposed) return;
        setState(() => _phase = _Phase.error);
        return;
      }
      if (_disposed) return;
      _audioPosSub = audio.positionStream.listen(_onAudioPosition);
    }

    if (widget.startScene != null && _totalMs > 0) {
      final target = timeline.scenes.firstWhere(
        (s) => s.id == widget.startScene,
        orElse: () => timeline.scenes.first,
      );
      _clock.value = (target.startMs / _totalMs).clamp(0.0, 1.0);
    }

    setState(() => _phase = _Phase.ready);
    if (widget.autoplay) _play();
  }

  static Map<String, dynamic>? _decode(String raw) {
    final v = jsonDecode(raw);
    return v is Map<String, dynamic> ? v : null;
  }

  // ---- Điều khiển ----------------------------------------------------------

  void _play() {
    if (_ended || _clock.value >= 1) {
      _clock.value = 0;
      _ended = false;
    }
    _clock.forward();
    _startAudioAtClock();
    setState(() {});
  }

  void _pause() {
    _clock.stop();
    _audio?.pause();
    setState(() {});
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (_muted) {
      _audio?.pause();
    } else if (_clock.isAnimating) {
      _startAudioAtClock();
    }
  }

  void _startAudioAtClock() {
    if (!_hasAudio || _muted) return;
    final audio = _audio!;
    // play() của just_audio chỉ xong khi dừng phát, nên không await. Lỗi phát
    // (vd trình duyệt chặn) thì quay về chế độ tắt tiếng, hình vẫn chạy.
    audio
        .seek(Duration(milliseconds: _posMs))
        .then((_) => audio.play())
        .catchError((Object _) {
          if (!_disposed && mounted) setState(() => _muted = true);
        });
  }

  void _onAudioPosition(Duration pos) {
    if (_disposed || _muted || !_clock.isAnimating || _totalMs <= 0) return;
    if (!(_audio?.playing ?? false)) return;
    final diff = (pos.inMilliseconds - _posMs).abs();
    if (diff > _kResyncMs) {
      _clock.value = (pos.inMilliseconds / _totalMs).clamp(0.0, 1.0);
      _clock.forward();
    }
  }

  void _onClockStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _audio?.pause();
      if (mounted) setState(() => _ended = true);
    }
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  void dispose() {
    _disposed = true;
    _audioPosSub?.cancel();
    _audio?.pause();
    // Đóng subscription thì provider autoDispose tự huỷ controller, đúng một
    // lần (như màn video báo cáo). Không gọi _audio.dispose() ở đây.
    _audioSub?.close();
    _clock.dispose();
    super.dispose();
  }

  // ---- Giao diện -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('intro_video_sheet'),
      backgroundColor: WrColors.navy,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: _stage(),
                        ),
                      ),
                    ),
                  ),
                ),
                _bottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final showMute = _phase == _Phase.ready && _timeline?.audioAsset != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('intro_video_close'),
            tooltip: tr('Đóng', 'Close'),
            icon: const Icon(Icons.close, color: WrColors.white),
            onPressed: _close,
          ),
          const Spacer(),
          if (showMute)
            TextButton.icon(
              key: Key(_muted ? 'intro_video_unmute' : 'intro_video_mute'),
              onPressed: _toggleMute,
              style: TextButton.styleFrom(
                foregroundColor: WrColors.navy,
                backgroundColor: _muted ? WrColors.coral : WrColors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: Icon(
                _muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                size: 18,
              ),
              label: Text(
                _muted ? tr('Bật tiếng', 'Sound on') : tr('Tắt tiếng', 'Mute'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stage() {
    switch (_phase) {
      case _Phase.loading:
        return const ColoredBox(
          color: WrColors.pageBg,
          child: Center(child: CircularProgressIndicator(color: WrColors.navy)),
        );
      case _Phase.error:
        return ColoredBox(
          color: WrColors.pageBg,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_off_outlined,
                    size: 40,
                    color: WrColors.text3,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(
                      'Chưa tải được video. Bạn có thể xem lại trong phần '
                          'Hướng dẫn.',
                      'The video could not load. You can watch it later in '
                          'the Guide.',
                    ),
                    key: const Key('intro_video_error'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: WrColors.dark,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: _close,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WrColors.navy,
                      side: const BorderSide(color: WrColors.navy),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(tr('Đóng', 'Close')),
                  ),
                ],
              ),
            ),
          ),
        );
      case _Phase.ready:
        final timeline = _timeline!;
        return AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final pos = _posMs;
            final scene = timeline.sceneAt(pos)!;
            final cue = timeline.cueAt(pos);
            return Stack(
              fit: StackFit.expand,
              children: [
                IntroSceneView(
                  sceneId: scene.id,
                  progress: timeline.sceneProgressAt(pos),
                ),
                if (cue != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: VideoSubtitleOverlay(text: cue.text),
                  ),
              ],
            );
          },
        );
    }
  }

  Widget _bottomBar() {
    final ready = _phase == _Phase.ready;
    final playing = _clock.isAnimating;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          IconButton(
            key: const Key('intro_video_play'),
            iconSize: 40,
            color: WrColors.white,
            tooltip: playing
                ? tr('Tạm dừng', 'Pause')
                : (_ended ? tr('Xem lại', 'Replay') : tr('Phát', 'Play')),
            onPressed: !ready ? null : (playing ? _pause : _play),
            icon: Icon(
              playing
                  ? Icons.pause_circle_outline
                  : (_ended
                        ? Icons.replay_circle_filled_outlined
                        : Icons.play_circle_outline),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => _SceneProgress(
                timeline: _timeline,
                positionMs: ready ? _posMs : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh tiến độ chia đoạn theo cảnh.
class _SceneProgress extends StatelessWidget {
  const _SceneProgress({required this.timeline, required this.positionMs});
  final IntroTimeline? timeline;
  final int positionMs;

  @override
  Widget build(BuildContext context) {
    final t = timeline;
    if (t == null || t.durationMs <= 0) {
      return const SizedBox(height: 4);
    }
    return Row(
      children: [
        for (var i = 0; i < t.scenes.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            flex: t.scenes[i].durationMs.clamp(1, 1 << 30),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                value:
                    ((positionMs - t.scenes[i].startMs) /
                            t.scenes[i].durationMs)
                        .clamp(0.0, 1.0),
                backgroundColor: WrColors.white.withValues(alpha: 0.25),
                color: WrColors.coral,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
