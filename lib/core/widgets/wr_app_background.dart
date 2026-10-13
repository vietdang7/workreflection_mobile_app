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
  AppBackgroundNotifier() : super(AppBackgroundMode.watercolor) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_kBgPrefKey);
    if (val == 'plain') {
      state = AppBackgroundMode.plain;
    } else {
      state = AppBackgroundMode.watercolor;
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

/// Scope truyền trạng thái nền giấy vẽ xuống cây widget con (để các thẻ WrCard phủ vân giấy).
class WrBackgroundScope extends InheritedWidget {
  const WrBackgroundScope({
    super.key,
    required this.isPaper,
    required super.child,
  });

  final bool isPaper;

  static bool of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<WrBackgroundScope>();
    return scope?.isPaper ?? false;
  }

  @override
  bool updateShouldNotify(WrBackgroundScope oldWidget) =>
      isPaper != oldWidget.isPaper;
}

/// Widget bọc nền ứng dụng, hỗ trợ chuyển đổi giữa Nền giấy trơn và Nền giấy vẽ màu nước.
class WrAppBackground extends ConsumerWidget {
  const WrAppBackground({
    super.key,
    required this.child,
    this.mode,
    this.backgroundColor,
  });

  final Widget child;
  final AppBackgroundMode? mode;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppBackgroundMode effectiveMode = mode ?? AppBackgroundMode.watercolor;
    if (mode == null) {
      try {
        effectiveMode = ref.watch(appBackgroundModeProvider);
      } catch (_) {
        effectiveMode = AppBackgroundMode.watercolor;
      }
    }
    final isPaper = effectiveMode == AppBackgroundMode.watercolor;
    final defaultBg = isPaper ? WrColors.creamBg : WrColors.pageBg;
    return WrBackgroundScope(
      isPaper: isPaper,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? defaultBg,
          image: isPaper
              ? const DecorationImage(
                  image: AssetImage('assets/images/paper_screen.webp'),
                  repeat: ImageRepeat.repeat,
                  scale: 2.0,
                  alignment: Alignment.topLeft,
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}
