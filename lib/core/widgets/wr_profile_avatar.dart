// Avatar dẫn sang màn Tôi — Kiến trúc Dữ liệu Hai Lớp v1.6 §9.1.
//
// v1.6 rút thanh tab từ năm xuống bốn: Hôm nay · Hiểu mình · Phát triển ·
// Hành trình. "Tôi" không còn là một tab mà thành avatar ở góc trên mỗi màn.
//
// Đặt avatar trên CẢ BỐN màn tab chứ không riêng Hôm nay: bỏ một tab đi mà chỉ
// để một lối vào thì từ ba màn còn lại người dùng không ra được phần cài đặt.
//
// Widget này gộp từ `_ProfileAvatarButton` vốn chỉ nằm trong màn Hôm nay, nên
// giữ nguyên hình thức cũ (tròn 44px nền cream) — bốn màn phải giống hệt nhau,
// người dùng cần nhận ra cùng một lối vào ở cùng một góc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../features/profile/profile_providers.dart';
import '../theme/wr_colors.dart';

/// Chữ cái đầu của tên, tối đa hai ký tự. Rỗng thì trả 'WR'.
String profileInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return 'WR';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

class WrProfileAvatar extends ConsumerWidget {
  const WrProfileAvatar({
    super.key,
    this.displayName,
    this.size = 36,
  });

  /// Tên hiển thị để lấy chữ cái đầu.
  ///
  /// Bỏ trống — mặc định ở cả bốn màn tab — thì widget tự đọc hồ sơ qua
  /// [mobileProfileProvider]. Trước 2026-08-22 tham số này bắt buộc phải được
  /// truyền vào, và chỉ màn Hôm nay truyền: ba màn còn lại gọi
  /// `const WrProfileAvatar()` nên luôn hiện 'WR' trong khi Hôm nay hiện chữ
  /// cái đầu của người dùng. Cùng một lối vào, cùng một góc màn, hai mặt chữ
  /// khác nhau — khách báo lỗi này 2026-08-22.
  ///
  /// Vẫn giữ tham số để test dựng được avatar mà không cần cả tầng repository.
  final String? displayName;

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = displayName ??
        ref.watch(mobileProfileProvider).valueOrNull?.displayName ??
        '';

    return Semantics(
      label: 'Tôi',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/profile'),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          // `.avatar { width:36; background: var(--trust); color: var(--cream) }`
          decoration: const BoxDecoration(
            color: WrColors.navy,
            shape: BoxShape.circle,
          ),
          child: Text(
            profileInitials(name),
            style: TextStyle(
              fontSize: size * 0.39,
              fontWeight: FontWeight.w700,
              color: WrColors.cream,
            ),
          ),
        ),
      ),
    );
  }
}
