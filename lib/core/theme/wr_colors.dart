import 'package:flutter/material.dart';

abstract final class WrColors {
  static const navy = Color(0xFF093774);
  static const coral = Color(0xFFFF6859);
  static const teal = Color(0xFF15B5B0);
  static const cream = Color(0xFFFFF3E6);
  static const dark = Color(0xFF2C335D);

  /// Chữ phụ. Spec §01b cấm xám trung tính (#8A95A3 cũ, #999…): chữ phụ luôn là
  /// Deep Space pha alpha để giữ tông ấm cùng Navy. Bằng đúng [text2].
  static const muted = text2;
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
  // Chữ trên pill (§04). Pill luôn là nền màu gốc pha loãng 8–14% với CHỮ ĐẬM
  // HƠN, đã ngả tối — không phải chính hex gốc. Riêng pill navy thì chữ đúng
  // bằng [navy], spec ghi rõ như vậy.
  /// Chữ trên `pill-coral`.
  static const pillCoralText = Color(0xFFC6402F);

  /// Chữ trên `pill-teal`.
  static const pillTealText = Color(0xFF0E7A76);

  static const destructive = Color(0xFFFF3B30);
  // Success badge (check-in saved state)
  static const successBg = Color(0xFFE6F4EA);
  static const success = Color(0xFF2E7D32);
  // Amber (premium label)
  static const amber = Color(0xFFD4A017);
}
