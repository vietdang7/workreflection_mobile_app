import 'package:flutter/material.dart';

import '../l10n/wr_tr.dart';
import '../theme/wr_colors.dart';

/// Nút lùi tròn 30px của các màn con (mockup v47 `.backbtn`).
class WrBackCircle extends StatelessWidget {
  const WrBackCircle({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('Quay lại', 'Back'),
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: WrColors.navy.withValues(alpha: 0.06),
          ),
          child: const Icon(
            Icons.chevron_left_rounded,
            size: 20,
            color: WrColors.navy,
          ),
        ),
      ),
    );
  }
}
