import 'package:flutter/material.dart';

/// Logo WorkReflection — dùng thẳng file logo chuẩn khách gửi
/// (`assets/images/wr_logo.png`, 1024×265, nền trong suốt).
///
/// Trước đây logo được vẽ tay bằng `CustomPaint`. Cách đó không bao giờ khớp
/// đúng bản chuẩn: khung ngắm, hai vòng lồng nhau và dáng chữ đều lệch, và mỗi
/// lần đối chiếu lại phải chỉnh tay từng toạ độ. Nay chỉ nhúng ảnh gốc.
class WrLogo extends StatelessWidget {
  const WrLogo({super.key, this.width = 240});

  final double width;

  /// Tỉ lệ của file logo gốc (1024×265).
  static const double _aspectRatio = 1024 / 265;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/wr_logo.png',
      width: width,
      height: width / _aspectRatio,
      fit: BoxFit.contain,
      semanticLabel: 'WorkReflection',
    );
  }
}
