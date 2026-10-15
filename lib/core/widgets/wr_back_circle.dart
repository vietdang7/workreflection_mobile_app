import 'package:flutter/material.dart';

import '../l10n/wr_tr.dart';
import '../theme/wr_colors.dart';

/// Vòng tròn của nút Quay lại / Đóng (họp khách 14/10: "nút thoát có vòng
/// tròn xanh đậm hoặc trắng sáng bao quanh để nổi trên nền").
///
/// Thông số theo README bộ ảnh v72: nền navy đặc `rgba(9,55,116,.82)`, icon
/// màu kem, viền sáng `rgba(255,243,230,.5)`. Nền 6% navy của bản cũ chỉ đạt
/// 1.03:1 trên ảnh, gần như vô hình.
///
/// Chỉ là phần vẽ, không bắt chạm: đặt làm `icon` của `IconButton` hoặc dùng
/// qua [WrBackCircle].
class WrNavCircle extends StatelessWidget {
  const WrNavCircle.back({super.key}) : icon = Icons.chevron_left_rounded;

  const WrNavCircle.close({super.key}) : icon = Icons.close_rounded;

  final IconData icon;

  static const _fill = Color(0xD1093774);
  static const _ring = Color(0x80FFF3E6);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _fill,
        border: Border.all(color: _ring, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29093774),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: icon == Icons.close_rounded ? 19 : 22,
        color: WrColors.cream,
      ),
    );
  }
}

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
        child: const WrNavCircle.back(),
      ),
    );
  }
}
