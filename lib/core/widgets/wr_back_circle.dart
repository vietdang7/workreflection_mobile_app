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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: WrColors.white,
            border: Border.all(
              color: WrColors.navy.withValues(alpha: 0.16),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18093774),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
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
