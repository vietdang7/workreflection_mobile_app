import 'package:flutter/material.dart';

abstract final class WrColors {
  static const navy = Color(0xFF093774);
  static const coral = Color(0xFFFF6859);
  static const teal = Color(0xFF15B5B0);
  static const cream = Color(0xFFFFF3E6);
  static const dark = Color(0xFF2C335D);
  static const muted = Color(0xFF8A95A3);
  static const white = Color(0xFFFFFFFF);

  // Token lấy nguyên từ `:root` của mockup Sprint 2 — đừng đoán lại bằng mắt.
  //   --cream-bg:#FBF9F5 · --line:rgba(9,55,116,0.10)
  //   --text-2:rgba(44,51,93,0.72) · --text-3:rgba(44,51,93,0.45)
  /// Nền màn hình (`--cream-bg`). Thẻ trắng nổi lên được là nhờ nền này.
  static const pageBg = Color(0xFFFBF9F5);

  /// Viền thẻ (`--line`).
  static const line = Color(0x1A093774);

  /// Viền mảnh (`--line-soft`).
  static const lineSoft = Color(0x0F093774);

  /// Chữ phụ (`--text-2`).
  static const text2 = Color(0xB82C335D);

  /// Chữ mờ, nhãn eyebrow (`--text-3`).
  static const text3 = Color(0x732C335D);
  static const destructive = Color(0xFFFF3B30);
  // Success badge (check-in saved state)
  static const successBg = Color(0xFFE6F4EA);
  static const success = Color(0xFF2E7D32);
  // Amber (premium label)
  static const amber = Color(0xFFD4A017);
}
