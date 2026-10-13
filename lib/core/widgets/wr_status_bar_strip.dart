import 'package:flutter/material.dart';

import '../theme/wr_colors.dart';
import 'wr_app_background.dart';

/// Dải nền cố định dưới thanh trạng thái của máy, như `.statusbar` của script
/// Sprint 2: giờ và pin luôn nằm trên nền giấy, nội dung cuộn lên thì trôi
/// XUỐNG DƯỚI dải này chứ không lẫn vào giờ và pin (máy thật 13/10).
///
/// Đặt một lần ở `MaterialApp.builder` nên phủ mọi màn. Màn nền navy toàn
/// màn (splash, thiết lập nghề nghiệp) truyền qua [hiddenPaths] để không bị
/// một dải sáng cắt ngang mép trên.
///
/// Vân giấy neo `topLeft` giống [WrAppBackground], nên dải và nền bên dưới
/// liền một tấm, không thấy đường nối.
class WrStatusBarStrip extends StatelessWidget {
  const WrStatusBarStrip({
    super.key,
    required this.child,
    required this.routeChanges,
    required this.currentPath,
    required this.isPaper,
    this.hiddenPaths = const {'/splash', '/wr/career-setup'},
  });

  final Widget child;

  /// Báo mỗi khi router đổi màn (vd `GoRouter.routerDelegate`).
  final Listenable? routeChanges;

  /// Đường dẫn màn hiện tại; dải ẩn khi nó nằm trong [hiddenPaths].
  final String Function()? currentPath;

  /// Nền giấy màu nước hay nền trơn — dải phải cùng loại nền với màn.
  final bool isPaper;

  final Set<String> hiddenPaths;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top <= 0) return child;

    final strip = IgnorePointer(
      child: DecoratedBox(
        key: const Key('wr_status_bar_strip'),
        decoration: BoxDecoration(
          color: isPaper ? WrColors.creamBg : WrColors.pageBg,
          image: isPaper
              ? const DecorationImage(
                  image: AssetImage('assets/images/paper_screen.webp'),
                  repeat: ImageRepeat.repeat,
                  scale: 2.0,
                  alignment: Alignment.topLeft,
                )
              : null,
        ),
        child: SizedBox(height: top, width: double.infinity),
      ),
    );

    return Stack(
      alignment: Alignment.topLeft,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: top,
          child: routeChanges == null || currentPath == null
              ? strip
              : ListenableBuilder(
                  listenable: routeChanges!,
                  builder: (context, _) => hiddenPaths.contains(currentPath!())
                      ? const SizedBox.shrink()
                      : strip,
                ),
        ),
      ],
    );
  }
}
