import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/wr_colors.dart';
import '../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Shell — hosts the 4-tab StatefulShellRoute.indexedStack
// Kiến trúc Dữ liệu Hai Lớp v1.6 §9.1: Hôm nay / Hiểu mình / Phát triển /
// Hành trình. "Tôi" không còn là tab — nó là avatar ở góc trên mỗi màn
// (`WrProfileAvatar`), mở /profile dưới dạng màn đẩy toàn màn hình.
// Tab bar: icon-only (no text label), 24px icon, 4px coral dot, 64px height.
// ---------------------------------------------------------------------------

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      // Bong bóng trò chuyện, BẬT LẠI 2026-08-03.
      //
      // Khách tắt nó ngày 2026-07-30 ("bỏ cái ô chatbot giúp tôi, chúng ta sẽ
      // làm cái này sau") vì lúc đó chạm vào chỉ ra một ô hỏi một chiều, câu
      // trả lời hẹn gửi qua email. Giờ phía sau đã là hội thoại thật nên lối
      // vào có lý do tồn tại.
      //
      // Yêu cầu gốc họp 2026-07-29, giữ nguyên: nổi trên MỌI tab, "nó sẽ hiển
      // thị trên mọi trang luôn chứ không riêng trang hành trình".
      body: Stack(
        children: [
          navigationShell,
          // Không dùng `bottom: 18` trần: máy có thanh cử chỉ dưới đáy sẽ đè
          // lên bong bóng. `viewPadding` chứ không phải `padding` — Scaffold đã
          // trừ phần thanh tab khỏi `padding`, đọc nhầm cái đó thì bong bóng
          // tụt xuống đúng chỗ vừa trừ.
          Positioned(
            right: 18,
            bottom: 18 + MediaQuery.of(context).viewPadding.bottom,
            child: const WrAskBubble(),
          ),
        ],
      ),
      bottomNavigationBar: WrTabBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bong bóng hỏi — lối vào ô hỏi tự do về hành trình nghề nghiệp.
//
// Nằm ở Stack của shell chứ không phải `floatingActionButton`: FAB của Scaffold
// sẽ bị thanh tab đẩy lên và đổi chỗ theo bàn phím, còn đây phải luôn ở đúng
// một chỗ trên cả bốn tab.
//
// Cố tình nhỏ và không có nhãn chữ. Trước 2026-08-05 bong bóng còn là nền navy
// vì được xem là lối vào phụ; khách chốt đổi sang Human Coral để trợ lý phản
// chiếu nổi lên như một lối vào chính.
//
// ⚠ Chữ và icon trên nền Coral phải là NAVY, không phải trắng hay cream. Đặc tả
//   UX/UI §01 và §03 nói thẳng: "Chữ trên nút này là Navy, không phải trắng" và
//   gọi trắng-trên-coral là "lỗi dễ mắc nhất vì trực giác thường mặc định nút
//   màu là chữ trắng" — nó biến nút ấm của thương hiệu thành một nút cảnh báo
//   kiểu hệ thống.
// ---------------------------------------------------------------------------

class WrAskBubble extends StatelessWidget {
  const WrAskBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Trò chuyện với trợ lý phản chiếu',
      child: GestureDetector(
        key: const Key('wr_ask_bubble'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/wr/ask'),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: WrColors.coral,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                // Bóng đổ theo đúng màu nền bong bóng. Giữ bóng navy dưới một
                // khối coral sẽ ra một quầng tím bẩn ở rìa.
                color: WrColors.coral.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 22,
            color: WrColors.navy,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab bar — 64px + safe-area, white/95%, top hairline 0.5px navy 8%, 5 items.
// Each item: icon 24px + 4px coral dot below (NO text label).
// ---------------------------------------------------------------------------

class _TabDef {
  const _TabDef({required this.icon, required this.semanticsLabel});
  final IconData icon;
  final String semanticsLabel;
}

List<_TabDef> _buildTabs(AppLocalizations l10n) => [
  // Bốn icon của mockup: con mắt (quan sát) · bóng đèn (hiểu) · tia chớp
  // (hành động) · nhịp sóng (hành trình).
  _TabDef(icon: Icons.visibility_outlined, semanticsLabel: l10n.tabToday),
  _TabDef(icon: Icons.lightbulb_outline,   semanticsLabel: l10n.tabUnderstand),
  _TabDef(icon: Icons.bolt_outlined,       semanticsLabel: l10n.tabDevelop),
  _TabDef(icon: Icons.show_chart,          semanticsLabel: l10n.tabJourney),
];

class WrTabBar extends StatelessWidget {
  const WrTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = _buildTabs(l10n);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      // `.tabbar { height: 72px; background: white; border-top: 1px --line }`
      height: 72 + bottomPadding,
      decoration: const BoxDecoration(
        color: WrColors.white,
        border: Border(top: BorderSide(color: WrColors.line)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Row(
          children: List.generate(
            tabs.length,
            (i) => Expanded(
              child: WrTabItem(
                icon: tabs[i].icon,
                semanticsLabel: tabs[i].semanticsLabel,
                isActive: i == currentIndex,
                onTap: () => onTap(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single tab item: icon 24px + 4px coral dot (NO text label).
/// Uses [semanticsLabel] for accessibility (Semantics widget).
class WrTabItem extends StatelessWidget {
  const WrTabItem({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String semanticsLabel;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `.tab` của mockup: icon 21 + nhãn chữ 9px; tab đang mở đổi sang navy và
    // nhãn đậm hơn. Bản cũ giấu nhãn và chấm coral dưới icon — người mới mở app
    // phải đoán bốn cái icon nghĩa là gì.
    final color = isActive ? WrColors.navy : WrColors.text3;

    return Semantics(
      label: semanticsLabel,
      selected: isActive,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 4),
            Text(
              semanticsLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.09,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
