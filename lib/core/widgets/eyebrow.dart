import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

class WrEyebrow extends StatelessWidget {
  const WrEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.55,
        color: WrColors.muted,
      ),
    );
  }
}
