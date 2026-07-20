// Video Report — mid-fidelity animated scene widgets.
//
// A single self-contained widget renders one of the 10 VideoSceneId scenes for
// a CcReportFull. It takes a `progress` (0..1 within its own time span) and
// animates content (fade + slide-up + slight scale) and any progress bars.
//
// SELF-CONTAINED: imports only models, theme colors, and Flutter widgets — no
// screen files — so it stays decoupled from report_screen.dart.

import 'package:flutter/material.dart';

import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/video_report/models/video_report_models.dart';

// Colors mirroring the web video renderer, keyed off `.toJson()` strings.
const _kScoreLevelColors = <String, Color>{
  'HIGH': Color(0xFF22C55E),
  'GOOD': Color(0xFF3B82F6),
  'WARNING': Color(0xFFF59E0B),
  'CRITICAL': Color(0xFFEF4444),
};
const _kLayerColors = <String, Color>{
  'STRUCTURE': Color(0xFF6366F1),
  'CULTURE': Color(0xFFEC4899),
  'ACTIVITY': Color(0xFFF59E0B),
};

const _kBgTop = Color(0xFF0B1121);
const _kBgBottom = Color(0xFF151F36);
const _kInk = Color(0xFFF8FAFC);
const _kInkMuted = Color(0xFF94A3B8);
const _kTrack = Color(0x1AFFFFFF);

class VideoSceneView extends StatelessWidget {
  const VideoSceneView({
    super.key,
    required this.sceneId,
    required this.report,
    required this.progress,
    required this.locale,
    this.userName = '',
  });

  final VideoSceneId sceneId;
  final CcReportFull report;
  final double progress; // 0..1 within this scene
  final String locale; // 'vi' | 'en'
  final String userName;

  bool get _isEn => locale == 'en';

  @override
  Widget build(BuildContext context) {
    // Fade in quickly over the first third of the scene.
    final t = (progress * 3).clamp(0.0, 1.0);
    final opacity = Curves.easeOut.transform(t);
    final dy = (1 - Curves.easeOut.transform(t)) * 24.0; // settles to 0
    final scale = 0.96 + 0.04 * Curves.easeOut.transform(t);

    return Container(
      constraints: const BoxConstraints.expand(),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBgTop, _kBgBottom],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(
                scale: scale,
                child: _content(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (sceneId) {
      case VideoSceneId.intro:
        return _intro();
      case VideoSceneId.overall:
        return _overall();
      case VideoSceneId.structure:
        return _layer('STRUCTURE', report.scoreStructure);
      case VideoSceneId.culture:
        return _layer('CULTURE', report.scoreCulture);
      case VideoSceneId.activity:
        return _layer('ACTIVITY', report.scoreActivity);
      case VideoSceneId.esi:
        return _esi();
      case VideoSceneId.enps:
        return _enps();
      case VideoSceneId.bottleneck:
        return _bottleneck();
      case VideoSceneId.recommendations:
        return _recommendations();
      case VideoSceneId.closing:
        return _closing();
    }
  }

  // ---- Scenes -------------------------------------------------------------

  Widget _intro() {
    final greeting = _isEn
        ? (userName.isEmpty ? 'Hello!' : 'Hello, $userName!')
        : (userName.isEmpty ? 'Xin chào!' : 'Xin chào, $userName!');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AppTitle(),
        const SizedBox(height: 20),
        Text(
          greeting,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kInkMuted, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          _isEn
              ? 'Here is your team snapshot.'
              : 'Đây là bức tranh nhanh về đội nhóm của bạn.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kInkMuted, fontSize: 15),
        ),
      ],
    );
  }

  Widget _overall() {
    final levelKey = report.scoreLevel.toJson();
    final chipColor = _kScoreLevelColors[levelKey] ?? _kInkMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _isEn ? 'Overall score' : 'Điểm tổng quan',
          style: const TextStyle(color: _kInkMuted, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              report.scoreTotal.toStringAsFixed(1),
              style: const TextStyle(
                color: _kInk,
                fontSize: 76,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const Text(
              ' /5',
              style: TextStyle(color: _kInkMuted, fontSize: 28),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Chip(label: _levelWord(report.scoreLevel), color: chipColor),
        const SizedBox(height: 28),
        _LayerBar(
          label: _layerName('STRUCTURE'),
          value: report.scoreStructure,
          color: _kLayerColors['STRUCTURE']!,
          progress: progress,
        ),
        const SizedBox(height: 12),
        _LayerBar(
          label: _layerName('CULTURE'),
          value: report.scoreCulture,
          color: _kLayerColors['CULTURE']!,
          progress: progress,
        ),
        const SizedBox(height: 12),
        _LayerBar(
          label: _layerName('ACTIVITY'),
          value: report.scoreActivity,
          color: _kLayerColors['ACTIVITY']!,
          progress: progress,
        ),
      ],
    );
  }

  Widget _layer(String layerKey, double value) {
    final color = _kLayerColors[layerKey] ?? _kInkMuted;
    final subs = _subRows(layerKey);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _layerName(layerKey),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(
              color: _kInk,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _LayerBar(
          label: _isEn ? 'Score' : 'Điểm',
          value: value,
          color: color,
          progress: progress,
        ),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (final s in subs) ...[
            _LayerBar(
              label: s.key,
              value: s.value,
              color: color,
              progress: progress,
              compact: true,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _esi() {
    final esi = report.scoreEsi;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Text(
            'ESI',
            style: TextStyle(
              color: _kInk,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            esi == null ? '—' : esi.toStringAsFixed(1),
            style: const TextStyle(
              color: _kInk,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _LayerBar(
          label: _isEn ? 'Engagement' : 'Gắn kết',
          value: esi ?? 0,
          color: const Color(0xFF14B8A6),
          progress: progress,
        ),
      ],
    );
  }

  Widget _enps() {
    final enps = report.scoreEnps;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Text(
            'eNPS',
            style: TextStyle(
              color: _kInk,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            enps == null ? '—' : '$enps',
            style: const TextStyle(
              color: _kInk,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _GradientBar(
          // eNPS ranges -100..100; map to 0..1 for the bar fill.
          fill: (((enps ?? -100) + 100) / 200).clamp(0.0, 1.0) * progress,
        ),
      ],
    );
  }

  Widget _bottleneck() {
    final key = report.bottleneckLayer.toJson();
    final color = _kLayerColors[key] ?? const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 40),
          const SizedBox(height: 10),
          Text(
            _isEn ? 'Bottleneck' : 'Điểm nghẽn',
            style: const TextStyle(color: _kInkMuted, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            _layerName(key),
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendations() {
    final key = report.bottleneckLayer.toJson();
    final color = _kLayerColors[key] ?? _kInkMuted;
    final tips = _tipsFor(key);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEn ? 'Recommendations' : 'Khuyến nghị',
          style: const TextStyle(
            color: _kInk,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        for (final tip in tips) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(Icons.check_circle, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tip,
                  style: const TextStyle(color: _kInk, fontSize: 15, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _closing() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _isEn ? 'Thank you!' : 'Cảm ơn!',
          style: const TextStyle(
            color: _kInk,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        const _AppTitle(),
      ],
    );
  }

  // ---- Helpers ------------------------------------------------------------

  /// Up to 3 sub-component rows for the given layer, read defensively.
  List<MapEntry<String, double>> _subRows(String layerKey) {
    final ss = report.subScores;
    if (ss == null) return const [];
    final out = <MapEntry<String, double>>[];
    for (final e in ss.entries) {
      final val = e.value;
      if (val is! Map) continue;
      final l = (val['layer'] as String?)?.toUpperCase();
      final s = (val['score'] as num?)?.toDouble();
      if (l == layerKey && s != null) {
        out.add(MapEntry(_prettyKey(e.key), s));
      }
      if (out.length >= 3) break;
    }
    return out;
  }

  String _prettyKey(String key) => key
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  String _layerName(String key) {
    switch (key) {
      case 'STRUCTURE':
        return _isEn ? 'Structure' : 'Cấu trúc';
      case 'CULTURE':
        return _isEn ? 'Culture' : 'Văn hóa';
      case 'ACTIVITY':
        return _isEn ? 'Activity' : 'Hoạt động';
      case 'ESI':
        return _isEn ? 'Engagement' : 'Gắn kết';
      case 'ENPS':
        return 'eNPS';
      default:
        return key;
    }
  }

  String _levelWord(ScoreLevel level) {
    switch (level) {
      case ScoreLevel.high:
        return _isEn ? 'High' : 'Cao';
      case ScoreLevel.good:
        return _isEn ? 'Good' : 'Tốt';
      case ScoreLevel.warning:
        return _isEn ? 'Warning' : 'Cảnh báo';
      case ScoreLevel.critical:
        return _isEn ? 'Critical' : 'Nghiêm trọng';
    }
  }

  List<String> _tipsFor(String key) {
    if (_isEn) {
      switch (key) {
        case 'STRUCTURE':
          return const [
            'Clarify roles and decision rights.',
            'Simplify overlapping workflows.',
            'Set clear communication channels.',
          ];
        case 'CULTURE':
          return const [
            'Build psychological safety in meetings.',
            'Recognize contributions regularly.',
            'Invite open, honest feedback.',
          ];
        default:
          return const [
            'Align goals with clear priorities.',
            'Keep a steady execution rhythm.',
            'Review progress in short cycles.',
          ];
      }
    }
    switch (key) {
      case 'STRUCTURE':
        return const [
          'Làm rõ vai trò và quyền quyết định.',
          'Tinh gọn các quy trình chồng chéo.',
          'Thiết lập kênh giao tiếp rõ ràng.',
        ];
      case 'CULTURE':
        return const [
          'Xây dựng an toàn tâm lý trong họp.',
          'Ghi nhận đóng góp thường xuyên.',
          'Khuyến khích phản hồi cởi mở.',
        ];
      default:
        return const [
          'Gắn mục tiêu với ưu tiên rõ ràng.',
          'Duy trì nhịp thực thi ổn định.',
          'Rà soát tiến độ theo chu kỳ ngắn.',
        ];
    }
  }
}

// ---- Small building blocks -----------------------------------------------

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'WorkReflection',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _kInk,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// A thin labelled horizontal bar whose fill = (value/5) * progress.
class _LayerBar extends StatelessWidget {
  const _LayerBar({
    required this.label,
    required this.value,
    required this.color,
    required this.progress,
    this.compact = false,
  });

  final String label;
  final double value;
  final Color color;
  final double progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fill = ((value / 5).clamp(0.0, 1.0)) * progress.clamp(0.0, 1.0);
    final barHeight = compact ? 6.0 : 10.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _kInkMuted,
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                color: _kInk,
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(height: barHeight, color: _kTrack),
              FractionallySizedBox(
                widthFactor: fill,
                child: Container(height: barHeight, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A horizontal gradient bar with a `fill` fraction (0..1).
class _GradientBar extends StatelessWidget {
  const _GradientBar({required this.fill});
  final double fill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(height: 12, color: _kTrack),
          FractionallySizedBox(
            widthFactor: fill.clamp(0.0, 1.0),
            child: Container(
              height: 12,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFF22C55E)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
