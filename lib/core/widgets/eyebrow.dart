import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

class WrEyebrow extends StatelessWidget {
  const WrEyebrow(this.text, {super.key, this.color, this.center = false});

  final String text;
  final Color? color;

  /// Canh giữa — dùng cho khối mở đầu canh giữa của màn Hiểu mình.
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: center ? TextAlign.center : null,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.55,
        color: color ?? WrColors.muted,
      ),
    );
  }
}
