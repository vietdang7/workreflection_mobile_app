import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/wr_colors.dart';
import '../../core/theme/wr_theme.dart';

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

/// The tab items definition.
const _kTabs = [
  _TabDef(icon: Icons.home_outlined, label: 'Hôm nay'),
  _TabDef(icon: Icons.self_improvement_outlined, label: 'Hiểu mình'),
  _TabDef(icon: Icons.trending_up_outlined, label: 'Phát triển'),
  _TabDef(icon: Icons.route_outlined, label: 'Hành trình'),
  _TabDef(icon: Icons.person_outline, label: 'Tôi'),
];

class _TabDef {
  const _TabDef({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

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
            _kTabs.length,
            (i) => Expanded(
              child: WrTabItem(
                icon: _kTabs[i].icon,
                label: _kTabs[i].label,
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

// ---------------------------------------------------------------------------
// Placeholder tab screens with header pattern (greeting + big title)
// Used for tabs whose full content is implemented in later tasks.
// ---------------------------------------------------------------------------

class _TabHeaderScreen extends StatelessWidget {
  const _TabHeaderScreen({
    required this.greeting,
    required this.title,
  });

  final String greeting;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(greeting, style: WrTextStyles.greeting),
              const SizedBox(height: 4),
              Text(title, style: WrTextStyles.dateTitle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home tab placeholder (replaced in Task 13).
class HomeTabScreen extends StatelessWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TabHeaderScreen(
      greeting: 'Chào bạn',
      title: 'Hôm nay',
    );
  }
}

/// Understand tab placeholder (replaced in Task 14).
class UnderstandTabScreen extends StatelessWidget {
  const UnderstandTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TabHeaderScreen(
      greeting: 'Career Snapshot',
      title: 'Hiểu mình',
    );
  }
}

/// Develop tab placeholder (replaced in Task 15).
class DevelopTabScreen extends StatelessWidget {
  const DevelopTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TabHeaderScreen(
      greeting: 'Development Map',
      title: 'Phát triển',
    );
  }
}

/// Journey tab placeholder (replaced in Task 16).
class JourneyTabScreen extends StatelessWidget {
  const JourneyTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TabHeaderScreen(
      greeting: 'Career Memory',
      title: 'Hành trình',
    );
  }
}

/// Profile tab placeholder (replaced in Task 17).
class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TabHeaderScreen(
      greeting: 'Tài khoản',
      title: 'Tôi',
    );
  }
}
