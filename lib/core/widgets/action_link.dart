import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

class WrActionLink extends StatelessWidget {
  const WrActionLink({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WrColors.coral,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_forward,
            size: 14,
            color: WrColors.coral,
          ),
        ],
      ),
    );
  }
}
