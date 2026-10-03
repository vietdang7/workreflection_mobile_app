// Màn chào: MỘT màn thay cho ba slide Reflect · Understand · Grow (họp khách
// 01/10, đợt E).
//
// Chỉ gồm: logo, tiêu đề chào mừng, thẻ video hướng dẫn, nút "Bắt đầu".
//
// Lần đầu mở trên một máy, video hướng dẫn tự bật toàn màn (sau khung hình
// đầu) và cờ `wr_intro_video_shown` được ghi NGAY lúc mở. Nút "Bắt đầu" không
// bao giờ phụ thuộc video: video lỗi, đang tải hay đã đóng thì vẫn bấm được.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_title_text.dart';
import '../intro_video_providers.dart';
import 'wr_intro_video_sheet.dart';
import 'wr_logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoOpen());
  }

  /// Tự bật video đúng một lần trên máy này. Cờ còn `null` (chưa đọc xong bộ
  /// nhớ máy) thì chờ: `ref.listen` trong [build] gọi lại khi có giá trị.
  void _maybeAutoOpen() {
    if (_autoOpened || !mounted) return;
    if (ref.read(introVideoShownProvider) != false) return;
    _autoOpened = true;
    ref.read(introVideoShownProvider.notifier).markShown();
    showIntroVideo(context);
  }

  Future<void> _start() async {
    await setSeenOnboarding();
    // appRouterProvider watches seenOnboardingProvider → invalidate làm router
    // rebuild với giá trị mới → router mới redirect /splash → /auth. Không cần
    // context.go. invalidate + await future đảm bảo AsyncData(true) sẵn sàng
    // trước frame rebuild kế tiếp, đóng cửa sổ race.
    ref.invalidate(seenOnboardingProvider);
    await ref.read(seenOnboardingProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool?>(introVideoShownProvider, (_, next) {
      if (next == false) _maybeAutoOpen();
    });

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      const WrLogo(width: 200),
                      const SizedBox(height: 36),
                      WrTitleText(
                        tr(
                          'Chào mừng bạn đến với WorkReflection',
                          'Welcome to WorkReflection',
                        ),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w300,
                          color: WrColors.navy,
                          height: 1.25,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _IntroVideoCard(onTap: () => showIntroVideo(context)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Nút Coral chữ Navy (spec §01).
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('onboarding_start'),
                  onPressed: _start,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WrColors.coral,
                    foregroundColor: WrColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: const StadiumBorder(),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(tr('Bắt đầu', 'Get started')),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ video: ảnh bìa dựng bằng widget (bốn icon tab + nút phát) và một dòng
/// chữ. Chạm để mở video toàn màn.
class _IntroVideoCard extends StatelessWidget {
  const _IntroVideoCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('Xem video hướng dẫn', 'Watch the intro video'),
      child: GestureDetector(
        key: const Key('intro_video_card'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: WrColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WrColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [WrColors.navy, Color(0xFF1B4E92)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 14,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final icon in const [
                              Icons.visibility_outlined,
                              Icons.lightbulb_outline,
                              Icons.bolt_outlined,
                              Icons.show_chart,
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Icon(
                                  icon,
                                  size: 20,
                                  color: WrColors.white.withValues(alpha: 0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: WrColors.coral,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 36,
                            color: WrColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('Xem video hướng dẫn', 'Watch the intro video'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                    Text(
                      tr('Khoảng 1 phút', 'About 1 minute'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: WrColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
