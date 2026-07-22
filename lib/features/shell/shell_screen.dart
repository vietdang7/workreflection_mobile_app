import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/wr_colors.dart';
import '../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Shell — hosts the 5-tab StatefulShellRoute.indexedStack
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
// Tab bar — 64px + safe-area, white/95%, top hairline, 5 items
// ---------------------------------------------------------------------------

class _TabDef {
  const _TabDef({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

List<_TabDef> _buildTabs(AppLocalizations l10n) => [
  _TabDef(icon: Icons.home_outlined, label: l10n.tabWrHome),
  _TabDef(icon: Icons.auto_stories_outlined, label: l10n.tabWrStory),
  _TabDef(icon: Icons.search_outlined, label: l10n.tabWrDiscover),
  _TabDef(icon: Icons.spa_outlined, label: l10n.tabWrGrowth),
  _TabDef(icon: Icons.timeline_outlined, label: l10n.tabWrJourney),
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
            color: Color(0x14093774), // navy 8%
            width: 1,
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
                label: tabs[i].label,
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

/// A single tab item: icon + label + 4px coral dot below when active.
class WrTabItem extends StatelessWidget {
  const WrTabItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? WrColors.coral : WrColors.muted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          // Active dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 4 : 0,
            height: isActive ? 4 : 0,
            decoration: const BoxDecoration(
              color: WrColors.coral,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

