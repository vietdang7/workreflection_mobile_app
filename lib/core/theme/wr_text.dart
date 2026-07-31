import 'package:flutter/material.dart';

/// Kiểu chữ lấy từ mockup Sprint 2 — phần không nằm trong `textTheme` chung.
///
/// Mockup nạp hai họ chữ: `Be Vietnam Pro` cho toàn bộ giao diện (đã đặt ở
/// `wr_theme.dart`) và `Lora` cho lớp `.serif`. Lớp `.serif` chỉ dùng cho những
/// câu TRÍCH của chính người dùng hoặc của hệ thống nói về người dùng — Insight
/// gần nhất, "Hệ thống nhận ra". Đó là chỗ duy nhất giao diện chuyển giọng từ
/// "ứng dụng đang nói" sang "một câu đáng đọc chậm".
abstract final class WrText {
  /// Tên họ chữ khai báo ở `pubspec.yaml`.
  static const serifFamily = 'Lora';

  /// `.muted.serif` + `font-style:italic` của mockup.
  ///
  /// Lora được NHÚNG trong assets, không gọi `GoogleFonts.lora()`: google_fonts
  /// tải font qua mạng lúc chạy, nên máy đang offline sẽ mất chữ serif và bộ
  /// test thì ném lỗi tải font. Chỉ nhúng bản italic vì đây là chỗ duy nhất
  /// dùng tới nó — thêm bản đứng là thêm 130KB không ai đọc.
  static TextStyle serifQuote({
    required double fontSize,
    required Color color,
    double height = 1.6,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontStyle: FontStyle.italic,
      fontSize: fontSize,
      color: color,
      height: height,
    );
  }
}
