import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/wr_colors.dart';
import '../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Shell — hosts the 5-tab StatefulShellRoute.indexedStack
// Final HTML mockup: Hôm nay / Hiểu mình / Phát triển / Hành trình / Tôi
// Tab bar: icon-only (no text label), 24px icon, 4px coral dot, 64px height.
// ---------------------------------------------------------------------------

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.white,
      body: navigationShell,
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
// Tab bar — 64px + safe-area, white/95%, top hairline 0.5px navy 8%, 5 items.
// Each item: icon 24px + 4px coral dot below (NO text label).
// ---------------------------------------------------------------------------

class _TabDef {
  const _TabDef({required this.icon, required this.semanticsLabel});
  final IconData icon;
  final String semanticsLabel;
}

List<_TabDef> _buildTabs(AppLocalizations l10n) => [
  _TabDef(icon: Icons.home_outlined,     semanticsLabel: l10n.tabToday),
  _TabDef(icon: Icons.person_outline,    semanticsLabel: l10n.tabUnderstand),
  _TabDef(icon: Icons.trending_up,       semanticsLabel: l10n.tabDevelop),
  _TabDef(icon: Icons.subject,           semanticsLabel: l10n.tabJourney),
  _TabDef(icon: Icons.settings_outlined, semanticsLabel: l10n.tabProfile),
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
      height: 64 + bottomPadding,
      decoration: BoxDecoration(
        color: WrColors.white.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(
            color: Color(0x14093774), // navy 8% — matches HTML rgba(9,55,116,.08)
            width: 0.5,
          ),
        ),
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
    final color = isActive ? WrColors.coral : WrColors.muted;

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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 5),
            // Active dot — 4px coral, hidden when inactive
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? WrColors.coral : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
