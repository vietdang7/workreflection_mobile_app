import 'package:flutter/material.dart';

import '../theme/wr_colors.dart';

/// Kiểu của [WrSmallButton] — `.btn-primary` / `.btn-ghost` / `.btn-dark` của
/// mockup, cỡ `.btn-sm`.
enum WrSmallButtonKind { primary, ghost, dark }

/// Nút nhỏ `.btn.btn-sm` (mockup v47): đệm 9/14, bo 10, chữ 11.5px (+1.5 theo
/// quy ước cỡ chữ của app), rộng theo nội dung.
class WrSmallButton extends StatelessWidget {
  const WrSmallButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = WrSmallButtonKind.primary,
    this.arrow = false,
  });

  final String label;
  final VoidCallback? onTap;
  final WrSmallButtonKind kind;

  /// Mũi tên "→" ở cuối nhãn. Vẽ bằng Icon chứ không bằng ký tự: font của app
  /// không chắc có glyph U+2192, thiếu là ra ô vuông rỗng.
  final bool arrow;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final Widget text = arrow
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, size: 14),
            ],
          )
        : Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          );
    return switch (kind) {
      WrSmallButtonKind.ghost => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: WrColors.navy,
          padding: padding,
          minimumSize: Size.zero,
          side: const BorderSide(color: Color(0x40093774), width: 1.5),
          shape: shape,
        ),
        child: text,
      ),
      _ => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kind == WrSmallButtonKind.dark
              ? WrColors.navy
              : WrColors.coral,
          foregroundColor: kind == WrSmallButtonKind.dark
              ? WrColors.cream
              : WrColors.navy,
          padding: padding,
          minimumSize: Size.zero,
          shape: shape,
        ),
        child: text,
      ),
    };
  }
}
