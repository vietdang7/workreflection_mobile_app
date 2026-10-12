import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/wr_colors.dart';

enum AppBackgroundMode {
  plain,
  watercolor,
}

const String _kBgPrefKey = 'wr_app_background_mode';

class AppBackgroundNotifier extends StateNotifier<AppBackgroundMode> {
  AppBackgroundNotifier() : super(AppBackgroundMode.plain) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_kBgPrefKey);
    if (val == 'watercolor') {
      state = AppBackgroundMode.watercolor;
    } else {
      state = AppBackgroundMode.plain;
    }
  }

  Future<void> setMode(AppBackgroundMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBgPrefKey, mode.name);
  }
}

final appBackgroundModeProvider =
    StateNotifierProvider<AppBackgroundNotifier, AppBackgroundMode>((ref) {
  return AppBackgroundNotifier();
});

/// Widget bọc nền ứng dụng, hỗ trợ chuyển đổi giữa Nền giấy trơn và Nền giấy màu nước.
class WrAppBackground extends StatelessWidget {
  const WrAppBackground({
    super.key,
    required this.child,
    this.mode = AppBackgroundMode.plain,
    this.backgroundColor,
  });

  final Widget child;
  final AppBackgroundMode mode;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (mode == AppBackgroundMode.watercolor) {
      return Container(
        decoration: const BoxDecoration(
          color: WrColors.pageBg,
          image: DecorationImage(
            image: AssetImage('assets/images/bg_watercolor_paper.webp'),
            fit: BoxFit.cover,
            opacity: 0.85,
          ),
        ),
        child: child,
      );
    }

    return Container(
      color: backgroundColor ?? WrColors.pageBg,
      child: child,
    );
  }
}
