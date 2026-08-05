import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

/// Nới cỡ chữ toàn app theo đường cong, không nhân đều.
///
/// Giao diện đang đặt phần lớn chữ ở 11–14px — vừa mắt trên máy thiết kế,
/// nhỏ trên máy thật. Nếu nhân đều mọi cỡ (`TextScaler.linear(1.2)`) thì con số
/// lớn ở Home (32–56px) phình theo và vỡ bố cục, trong khi chữ 11px vẫn chỉ
/// nhích được hơn 2px.
///
/// Nên: chữ nhỏ được CỘNG thêm nhiều nhất (+3px ở cỡ ≤10), phần cộng giảm dần
/// tới +1px ở cỡ 24, còn chữ tiêu đề lớn chỉ nhân nhẹ 1.04. Kết quả: 11→14,
/// 13→15.6, 16→18.1, 32→33.3 — chữ thân bài dễ đọc hẳn mà khung số liệu và
/// tiêu đề gần như giữ nguyên chiều cao.
@immutable
class WrTextScaler implements TextScaler {
  const WrTextScaler({this.systemScale = 1.0});

  /// Hệ số cỡ chữ người dùng đặt trong Cài đặt hệ điều hành, đã được nhân
  /// chồng lên đường cong ở [scale].
  final double systemScale;

  /// Chặn trên cho [systemScale]. Hệ điều hành cho kéo tới 2.0–3.0; ở mức đó
  /// các hàng ngang (chip tình huống, thanh tab) tràn viền. 1.3 là mức cao nhất
  /// mà các màn hiện tại còn xếp gọn.
  static const double maxSystemScale = 1.3;

  /// Chặn dưới — vẫn tôn trọng người cố ý chọn chữ nhỏ hơn mặc định, chỉ không
  /// cho nhỏ tới mức phá mục đích của đường cong này.
  static const double minSystemScale = 0.85;

  /// Đọc hệ số hệ thống từ [MediaQuery] rồi bọc lại bằng đường cong.
  factory WrTextScaler.of(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // TextScaler không phơi ra hệ số trực tiếp (bản nonlinear cũng hợp lệ), nên
    // suy ngược từ một cỡ chữ mẫu.
    final systemScale = scaler.scale(14) / 14;
    return WrTextScaler(systemScale: systemScale);
  }

  @override
  double scale(double fontSize) {
    final double bonus;
    if (fontSize <= 10) {
      bonus = 3;
    } else if (fontSize <= 24) {
      // +3px ở cỡ 10, giảm tuyến tính xuống +1px ở cỡ 24.
      bonus = 3 - 2 * (fontSize - 10) / 14;
    } else {
      bonus = fontSize * 0.04;
    }
    final scaled = fontSize + bonus;
    return scaled * clampDouble(systemScale, minSystemScale, maxSystemScale);
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => scale(14) / 14;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = double.infinity}) {
    return WrTextScaler(
      systemScale: clampDouble(systemScale, minScaleFactor, maxScaleFactor),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WrTextScaler && other.systemScale == systemScale;

  @override
  int get hashCode => systemScale.hashCode;

  @override
  String toString() => 'WrTextScaler(system: $systemScale)';
}

/// Bọc cây widget của app bằng [WrTextScaler]. Đặt ở `MaterialApp.builder` để
/// mọi màn — kể cả dialog và bottom sheet mở qua Navigator gốc — đều nhận.
Widget wrTextScaleBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: WrTextScaler.of(context),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
