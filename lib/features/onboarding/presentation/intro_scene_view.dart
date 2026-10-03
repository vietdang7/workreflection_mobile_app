// Video hướng dẫn: hình động của từng cảnh, dựng bằng widget Flutter (không
// phải file video). Mỗi cảnh nhận `progress` 0..1 trong thời gian của nó và
// cho từng phần hiện ra lần lượt theo lời đọc.
//
// Khung chuyển cảnh dùng lại `VideoSceneFrame` của video báo cáo. Nền sáng theo
// nhận diện app (xám #F4F4F6 → trắng, chữ navy), khác video báo cáo nền tối.
//
// Nội dung được dựng ở bề ngang cố định rồi thu nhỏ cho vừa khung
// (`FittedBox`), nên màn hẹp chỉ nhỏ đi chứ không tràn.

import 'package:flutter/material.dart';

import '../../../core/logic/wr_skill_formation.dart';
import '../../../core/theme/wr_colors.dart';
import '../../video_report/presentation/scenes/video_scene_frame.dart';
import '../intro_video_script.dart';
import 'wr_logo.dart';

/// Bề ngang thiết kế của nội dung cảnh trước khi thu cho vừa khung.
const double _kDesignWidth = 340;

class IntroSceneView extends StatelessWidget {
  const IntroSceneView({
    super.key,
    required this.sceneId,
    required this.progress,
  });

  final IntroSceneId sceneId;

  /// 0..1 trong thời gian của cảnh.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return VideoSceneFrame(
      progress: progress,
      colors: const [WrColors.pageBg, WrColors.white],
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 72),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: _kDesignWidth, child: _content()),
      ),
    );
  }

  Widget _content() {
    switch (sceneId) {
      case IntroSceneId.welcome:
        return _Welcome(progress: progress);
      case IntroSceneId.reflect:
        return _Reflect(progress: progress);
      case IntroSceneId.understand:
        return _Understand(progress: progress);
      case IntroSceneId.grow:
        return _Grow(progress: progress);
      case IntroSceneId.assistant:
        return _Assistant(progress: progress);
      case IntroSceneId.closing:
        return _Closing(progress: progress);
    }
  }
}

// ---------------------------------------------------------------------------
// Nhịp hiện lần lượt
// ---------------------------------------------------------------------------

/// 0..1: phần này đã hiện được bao nhiêu, khi cảnh chạy từ [from] tới [to].
double _phase(double progress, double from, double to) {
  if (progress <= from) return 0;
  if (progress >= to) return 1;
  return Curves.easeOut.transform((progress - from) / (to - from));
}

/// Hiện [child] (mờ → rõ, trượt lên) trong khoảng [from]..[from]+0.12 của cảnh.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.progress,
    required this.from,
    required this.child,
  });

  final double progress;
  final double from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = _phase(progress, from, from + 0.12);
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// Mảnh dùng chung
// ---------------------------------------------------------------------------

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: WrColors.navy,
        height: 1.25,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.highlight = false});
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? WrColors.coral : WrColors.line,
          width: highlight ? 1.6 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F093774),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Bốn tab của app: icon giống thanh tab dưới đáy (mắt · bóng đèn · tia chớp
/// · nhịp sóng).
List<(IconData, String)> get _tabs => [
  (Icons.visibility_outlined, kIntroTabToday),
  (Icons.lightbulb_outline, kIntroTabUnderstand),
  (Icons.bolt_outlined, kIntroTabDevelop),
  (Icons.show_chart, kIntroTabJourney),
];

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.icon,
    required this.label,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? WrColors.navy : WrColors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: active ? WrColors.navy : WrColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: active ? WrColors.white : WrColors.navy),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? WrColors.white : WrColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberDot extends StatelessWidget {
  const _NumberDot(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: WrColors.navy,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$n',
        style: const TextStyle(
          color: WrColors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Chào mừng
// ---------------------------------------------------------------------------

class _Welcome extends StatelessWidget {
  const _Welcome({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const WrLogo(width: 240),
        const SizedBox(height: 22),
        _Reveal(
          progress: progress,
          from: 0.15,
          child: Text(
            kIntroWelcomeTagline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              color: WrColors.navy,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 10,
          children: [
            for (var i = 0; i < tabs.length; i++)
              _Reveal(
                progress: progress,
                from: 0.35 + i * 0.1,
                child: _TabChip(icon: tabs[i].$1, label: tabs[i].$2),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Nhìn lại một khoảnh khắc trong bốn bước
// ---------------------------------------------------------------------------

class _Reflect extends StatelessWidget {
  const _Reflect({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final moods = kIntroMoods;
    final steps = kIntroReflectSteps;
    // Một cảm xúc được "chạm" ngay khi lời đọc nói "chạm chọn cảm xúc".
    final picked = progress >= 0.22;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TabChip(icon: _tabs[0].$1, label: _tabs[0].$2, active: true),
        const SizedBox(height: 14),
        _Title(kIntroReflectTitle),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < moods.length; i++)
              _Reveal(
                progress: progress,
                from: 0.02 + i * 0.025,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: picked && i == 1
                        ? WrColors.coral.withValues(alpha: 0.12)
                        : WrColors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: picked && i == 1 ? WrColors.coral : WrColors.line,
                      width: picked && i == 1 ? 1.6 : 1,
                    ),
                  ),
                  child: Text(
                    moods[i],
                    style: const TextStyle(fontSize: 14, color: WrColors.dark),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Reveal(
              progress: progress,
              from: 0.4 + i * 0.13,
              child: _Card(
                highlight:
                    _phase(progress, 0.4 + i * 0.13, 0.53 + i * 0.13) > 0 &&
                    progress < 0.53 + i * 0.13,
                child: Row(
                  children: [
                    _NumberDot(i + 1),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Hiểu mình: những vòng lặp quen thuộc
// ---------------------------------------------------------------------------

class _Understand extends StatelessWidget {
  const _Understand({required this.progress});
  final double progress;

  static const _counts = [4, 3, 3];

  @override
  Widget build(BuildContext context) {
    final loops = kIntroLoopExamples;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TabChip(icon: _tabs[1].$1, label: _tabs[1].$2, active: true),
        const SizedBox(height: 14),
        _Title(kIntroUnderstandTitle),
        const SizedBox(height: 6),
        Text(
          kIntroExampleLabel,
          style: const TextStyle(fontSize: 13, color: WrColors.text3),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < loops.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Reveal(
              progress: progress,
              from: 0.15 + i * 0.15,
              child: _Card(
                child: Row(
                  children: [
                    const Icon(Icons.loop, size: 20, color: WrColors.teal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loops[i],
                        style: const TextStyle(
                          fontSize: 15,
                          color: WrColors.dark,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Số lần đếm dần lên như đang gom từ các lần nhìn lại.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: WrColors.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '×${(1 + (_counts[i] - 1) * _phase(progress, 0.2 + i * 0.15, 0.75)).round()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Phát triển: chủ đề thực hành
// ---------------------------------------------------------------------------

class _Grow extends StatelessWidget {
  const _Grow({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Số chấm = ngưỡng thật của app, đổi ngưỡng thì hình đổi theo.
    const dots = kSkillThreshold;
    final filled = (_phase(progress, 0.3, 0.8) * dots).floor();
    final formed = progress >= 0.82;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TabChip(icon: _tabs[2].$1, label: _tabs[2].$2, active: true),
        const SizedBox(height: 14),
        _Title(kIntroGrowTitle),
        const SizedBox(height: 18),
        _Reveal(
          progress: progress,
          from: 0.1,
          child: _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kIntroGrowTheme,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < dots; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < filled ? WrColors.teal : WrColors.white,
                            border: Border.all(
                              color: i < filled ? WrColors.teal : WrColors.line,
                              width: 1.5,
                            ),
                          ),
                          child: i < filled
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: WrColors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Opacity(
          opacity: formed ? _phase(progress, 0.82, 0.92) : 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: WrColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: WrColors.pillTealText,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    kIntroGrowSkill,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: WrColors.pillTealText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Trợ lý AI
// ---------------------------------------------------------------------------

class _Assistant extends StatelessWidget {
  const _Assistant({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final typing = progress >= 0.35 && progress < 0.55;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: WrColors.coral,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 19,
                color: WrColors.white,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(child: _Title(kIntroAssistantTitle)),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: WrColors.pageBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WrColors.line),
          ),
          child: Column(
            children: [
              _Reveal(
                progress: progress,
                from: 0.12,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _Bubble(text: kIntroAssistantQuestion, mine: true),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: typing
                      ? const _Bubble(text: '• • •', mine: false)
                      : _Reveal(
                          progress: progress,
                          from: 0.55,
                          child: _Bubble(
                            text: kIntroAssistantAnswer,
                            mine: false,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              // Nút trò chuyện nổi ở góc dưới bên phải, đúng chỗ của app.
              Align(
                alignment: Alignment.centerRight,
                child: Transform.scale(
                  scale: 1 + 0.12 * _pulse(progress),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: WrColors.coral,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 21,
                      color: WrColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Nhịp phồng nhẹ của nút trò chuyện lúc lời đọc nhắc tới nó.
  double _pulse(double p) {
    if (p < 0.05 || p > 0.35) return 0;
    final t = (p - 0.05) / 0.3;
    return (t < 0.5 ? t : 1 - t) * 2;
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});
  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? WrColors.navy : WrColors.white,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: WrColors.line),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.35,
            color: mine ? WrColors.white : WrColors.dark,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Lời kết
// ---------------------------------------------------------------------------

class _Closing extends StatelessWidget {
  const _Closing({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    // "Hành trình" sáng lên trước (mọi lần nhìn lại được lưu ở đó), rồi tới
    // "Hôm nay" (chỗ bắt đầu).
    final active = progress < 0.5 ? 3 : 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const WrLogo(width: 220),
        const SizedBox(height: 26),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 10,
          children: [
            for (var i = 0; i < tabs.length; i++)
              _TabChip(
                icon: tabs[i].$1,
                label: tabs[i].$2,
                active: progress > 0.1 && i == active,
              ),
          ],
        ),
        const SizedBox(height: 26),
        _Reveal(
          progress: progress,
          from: 0.5,
          child: Text(
            kIntroClosingLine,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}
