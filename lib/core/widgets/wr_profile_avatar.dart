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
import '../../features/wr/wr_providers.dart' show wrEntitlementProvider;
import '../l10n/wr_tr.dart';
import '../theme/wr_colors.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

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
  const WrProfileAvatar({super.key, this.displayName, this.size = 36});

  /// Tên hiển thị để lấy chữ cái đầu.
  ///
  /// Bỏ trống — mặc định ở cả bốn màn tab — thì widget tự đọc hồ sơ qua
  /// [greetingNameProvider]. Trước 2026-08-22 tham số này bắt buộc phải được
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
    // Đọc cùng `greetingNameProvider` với lời chào ở Hôm nay. Trước 07/10 nhánh
    // này đọc thẳng `wr_mobile_profiles.display_name`, còn Hôm nay đọc tên qua
    // provider (ưu tiên `cc_profiles.full_name`) — nên cùng một tài khoản hiện
    // "TD" ở Hôm nay mà chỉ "T" ở ba tab còn lại.
    final name = displayName ?? ref.watch(greetingNameProvider) ?? '';

    // `.avatar.premium` (mockup Sprint 2): người Premium thấy "★" trên nền
    // chuyển navy → teal thay cho chữ cái đầu. Chưa biết quyền thì coi như
    // miễn phí, không nháy ngôi sao rồi rút lại.
    final premium =
        ref.watch(wrEntitlementProvider).valueOrNull?.isPremium ?? false;

    // Ảnh người dùng tự cài ở màn Tài khoản (`cc_profiles.avatar_url`) luôn
    // đứng trước: script không có ảnh đại diện nên "★" của `.avatar.premium`
    // chỉ thay cho CHỮ VIẾT TẮT, không bao giờ đè lên ảnh thật (máy thật 13/10).
    final avatarUrl =
        ref.watch(ccProfileProvider).valueOrNull?['avatar_url'] as String?;
    final hasPhoto = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    final fallback = Text(
      wrKeepCompounds(premium ? '★' : profileInitials(name)),
      key: premium ? const Key('wr_avatar_premium') : null,
      style: TextStyle(
        fontSize: size * 0.39,
        fontWeight: FontWeight.w700,
        color: WrColors.cream,
      ),
    );

    return Semantics(
      label: tr('Tôi', 'Me'),
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/profile'),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          // `.avatar { width:36; background: var(--trust); color: var(--cream) }`
          decoration: BoxDecoration(
            color: WrColors.navy,
            gradient: premium
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [WrColors.navy, WrColors.teal],
                  )
                : null,
            shape: BoxShape.circle,
          ),
          clipBehavior: hasPhoto ? Clip.antiAlias : Clip.none,
          child: hasPhoto
              ? Image.network(
                  avatarUrl.trim(),
                  key: const Key('wr_avatar_photo'),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  // Ảnh hỏng hoặc mất mạng: quay về chữ viết tắt / "★".
                  errorBuilder: (_, __, ___) => Center(child: fallback),
                )
              : fallback,
        ),
      ),
    );
  }
}
