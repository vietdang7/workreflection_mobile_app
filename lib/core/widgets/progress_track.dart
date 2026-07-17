import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

class WrProgressTrack extends StatelessWidget {
  const WrProgressTrack({
    super.key,
    required this.value,
    required this.color,
    this.trackColor,
    this.height = 3,
  });

  final double value;
  final Color color;
  final Color? trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final bg = trackColor ?? WrColors.navy.withValues(alpha: 0.1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            Container(
              height: height,
              width: width,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            Container(
              height: height,
              width: width * clamped,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ],
        );
      },
    );
  }
}
