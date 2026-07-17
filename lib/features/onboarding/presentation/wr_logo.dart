import 'package:flutter/material.dart';
import '../../../core/theme/wr_colors.dart';

/// WorkReflection logo: CustomPaint icon mark + styled wordmark text.
///
/// The icon mark draws two interlocking rounded-corner brackets and two circles
/// (navy upper bracket / coral lower bracket) inspired by the SVG logo.
class WrLogo extends StatelessWidget {
  const WrLogo({super.key, this.width = 160});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width * 0.22,
          height: width * 0.22,
          child: CustomPaint(
            painter: _WrIconPainter(),
          ),
        ),
        const SizedBox(width: 8),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Work',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: WrColors.navy,
                  letterSpacing: -0.3,
                ),
              ),
              TextSpan(
                text: 'Reflection',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: WrColors.coral,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Draws two overlapping rounded-corner bracket shapes:
/// top-left bracket (navy) and bottom-right bracket (coral),
/// plus two small circles to mirror the SVG icon mark.
class _WrIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width * 0.2;
    final double strokeW = size.width * 0.12;

    // Navy bracket (top-left area)
    final navyPaint = Paint()
      ..color = WrColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final coralPaint = Paint()
      ..color = WrColors.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final navyFill = Paint()
      ..color = WrColors.navy
      ..style = PaintingStyle.fill;

    final coralFill = Paint()
      ..color = WrColors.coral
      ..style = PaintingStyle.fill;

    // Top bracket (navy) — upper-left quadrant
    final topBracket = Path()
      ..moveTo(size.width * 0.15, size.height * 0.55)
      ..lineTo(size.width * 0.15, size.height * 0.15 + r)
      ..arcToPoint(
        Offset(size.width * 0.15 + r, size.height * 0.15),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(size.width * 0.6, size.height * 0.15);
    canvas.drawPath(topBracket, navyPaint);

    // Bottom bracket (coral) — lower-right quadrant
    final bottomBracket = Path()
      ..moveTo(size.width * 0.85, size.height * 0.45)
      ..lineTo(size.width * 0.85, size.height * 0.85 - r)
      ..arcToPoint(
        Offset(size.width * 0.85 - r, size.height * 0.85),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(size.width * 0.4, size.height * 0.85);
    canvas.drawPath(bottomBracket, coralPaint);

    // Navy circle (upper area)
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.28),
      size.width * 0.08,
      navyFill,
    );

    // Coral circle (lower area)
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.72),
      size.width * 0.08,
      coralFill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
