import 'package:flutter/material.dart';
import '../theme/wr_colors.dart';

enum WrPillVariant { navy, coral, teal }

class WrPillButton extends StatelessWidget {
  const WrPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = WrPillVariant.navy,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final WrPillVariant variant;
  final bool isLoading;

  Color get _bgColor {
    return switch (variant) {
      WrPillVariant.navy => WrColors.navy,
      WrPillVariant.coral => WrColors.coral,
      WrPillVariant.teal => WrColors.teal,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _bgColor,
          foregroundColor: WrColors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: WrColors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(label),
      ),
    );
  }
}
