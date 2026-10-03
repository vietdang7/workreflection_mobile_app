// Khung chung của một cảnh video: nền chuyển màu + nội dung hiện dần (mờ →
// rõ, trượt lên, phóng nhẹ) trong một phần ba đầu của cảnh.
//
// Tách ra từ `VideoSceneView` để video hướng dẫn ở màn chào dùng lại đúng
// nhịp chuyển cảnh của video báo cáo.

import 'package:flutter/material.dart';

class VideoSceneFrame extends StatelessWidget {
  const VideoSceneFrame({
    super.key,
    required this.progress,
    required this.child,
    this.colors = const [Color(0xFF0B1121), Color(0xFF151F36)],
    this.padding = const EdgeInsets.all(28),
  });

  /// 0..1 trong thời gian của cảnh.
  final double progress;
  final Widget child;

  /// Hai màu nền từ trên xuống dưới.
  final List<Color> colors;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Fade in quickly over the first third of the scene.
    final t = (progress * 3).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);
    final dy = (1 - eased) * 24.0; // settles to 0
    final scale = 0.96 + 0.04 * eased;

    return Container(
      constraints: const BoxConstraints.expand(),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Center(
        child: Padding(
          padding: padding,
          child: Opacity(
            opacity: eased,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
