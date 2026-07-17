import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

class WrCardMinimal extends StatelessWidget {
  const WrCardMinimal({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.cream,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }
}

class WrCardDark extends StatelessWidget {
  const WrCardDark({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: WrColors.navy,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: padding ?? const EdgeInsets.all(20),
        child: Stack(
          children: [
            // Decorative circle top-right (mirrors .card-system::before)
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WrColors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
