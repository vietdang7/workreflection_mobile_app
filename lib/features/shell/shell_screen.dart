import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/wr_tr.dart';
import '../../core/theme/wr_colors.dart';
import '../../core/widgets/wr_app_background.dart';
import '../../l10n/app_localizations.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

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
    return WrAppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Bong bóng trò chuyện, BẬT LẠI 2026-08-03.
        //
        // Khách tắt nó ngày 2026-07-30 ("bỏ cái ô chatbot giúp tôi, chúng ta sẽ
        // làm cái này sau") vì lúc đó chạm vào chỉ ra một ô hỏi một chiều, câu
        // trả lời hẹn gửi qua email. Giờ phía sau đã là hội thoại thật nên lối
        // vào có lý do tồn tại.
        //
        // Yêu cầu gốc họp 2026-07-29, giữ nguyên: nổi trên MỌI tab, "nó sẽ hiển
        // thị trên mọi trang luôn chứ không riêng trang hành trình".
        body: navigationShell,
        // `.fab-chat { right: 18px; bottom: 54px }` trên thanh tab cao 72: đáy
        // bong bóng đè lên mép trên thanh tab 18px. Đặt trong Stack của body thì
        // phần đè đó bị cắt và không bấm được, nên đi đường FAB của Scaffold
        // (vẽ trên thanh tab, nhận chạm) với một vị trí cố định riêng.
        floatingActionButton: const WrAskBubble(),
        floatingActionButtonLocation: const _AskBubbleLocation(),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        bottomNavigationBar: WrTabBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}

/// Vị trí bong bóng: cách mép phải 18, đáy chạm mép trên thanh tab.
///
/// Script đè 18px xuống thanh tab, nhưng trên máy thật (cỡ chữ 1.15, 13/10)
/// phần đè che mất icon tab Hành trình, nên không đè nữa.
///
/// `contentBottom` là mép trên thanh tab (đã gồm thanh cử chỉ của máy), nên
/// bong bóng không bao giờ nằm dưới vùng cử chỉ.
class _AskBubbleLocation extends FloatingActionButtonLocation {
  const _AskBubbleLocation();

  static const double _right = 18;
  static const double _overlap = 0;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry g) {
    final size = g.floatingActionButtonSize;
    return Offset(
      g.scaffoldSize.width - _right - size.width,
      g.contentBottom + _overlap - size.height,
    );
  }
}

// ---------------------------------------------------------------------------
// Bong bóng hỏi — lối vào ô hỏi tự do về hành trình nghề nghiệp.
//
// Là `floatingActionButton` của shell với vị trí riêng [_AskBubbleLocation]:
// luôn ở đúng một chỗ trên cả bốn tab, đè mép trên thanh tab như mockup.
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
      label: tr(
        'Trò chuyện với trợ lý phản chiếu',
        'Chat with the reflection assistant',
      ),
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
                // `.fab-chat`: 0 10px 22px -6px rgba(255,104,89,.55).
                color: WrColors.coral.withValues(alpha: 0.55),
                blurRadius: 22,
                spreadRadius: -6,
                offset: const Offset(0, 10),
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
  _TabDef(icon: Icons.visibility_outlined, semanticsLabel: tr('Home', 'Home')),
  _TabDef(
    icon: Icons.lightbulb_outline,
    semanticsLabel: tr('Hiểu', 'Understand'),
  ),
  _TabDef(icon: Icons.bolt_outlined, semanticsLabel: l10n.tabDevelop),
  _TabDef(icon: Icons.show_chart, semanticsLabel: l10n.tabJourney),
];

class WrTabBar extends StatelessWidget {
  const WrTabBar({super.key, required this.currentIndex, required this.onTap});

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
            // Co chữ lại thay vì cắt: "Understand" ở cỡ chữ hệ thống lớn bị
            // cắt thành "Understa…" (chạy máy thật 06/10).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  wrKeepCompounds(semanticsLabel),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.09,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
