import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/wr_colors.dart';

/// Tab identity for WrTabBackLink — which shell tab the host screen is.
enum WrTab {
  home('/home'),
  discover('/wr/discover'),
  growth('/wr/growth'),
  journey('/wr/journey');

  const WrTab(this.path);
  final String path;

  static WrTab? fromKey(String? key) => switch (key) {
        'home' => WrTab.home,
        'discover' => WrTab.discover,
        'growth' => WrTab.growth,
        'journey' => WrTab.journey,
        _ => null,
      };
}

/// "Quay lại" link shown on a shell tab when reached via a cross-tab
/// link carrying `?from=<tabKey>`. Renders nothing for direct tab entry,
/// unknown keys, no-router contexts, or when `from` equals the current tab.
class WrTabBackLink extends StatelessWidget {
  const WrTabBackLink({super.key, required this.currentTab});
  final WrTab currentTab;

  @override
  Widget build(BuildContext context) {
    if (GoRouter.maybeOf(context) == null) return const SizedBox.shrink();
    final fromKey = GoRouterState.of(context).uri.queryParameters['from'];
    final fromTab = WrTab.fromKey(fromKey);
    if (fromTab == null || fromTab == currentTab) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => context.go(fromTab.path),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_ios_new, size: 14, color: WrColors.muted),
            SizedBox(width: 6),
            Text(
              'Quay lại',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: WrColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
