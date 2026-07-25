import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

class WrEyebrow extends StatelessWidget {
  const WrEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.55,
        color: color ?? WrColors.muted,
      ),
    );
  }
}
