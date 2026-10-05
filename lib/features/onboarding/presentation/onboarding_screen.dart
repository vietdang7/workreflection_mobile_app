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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          const Center(child: WrLogo(width: 220)),
                          const SizedBox(height: 24),
                          WrTitleText(
                            tr(
                              'Chào mừng bạn đến với WorkReflection',
                              'Welcome to WorkReflection',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: WrColors.navy,
                              height: 1.3,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr(
                              'Thấu hiểu bản thân • Nâng tầm sự nghiệp',
                              'Discover yourself • Elevate your career',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: WrColors.text2,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _IntroVideoCard(
                            onTap: () => showIntroVideo(context),
                          ),
                          const SizedBox(height: 20),
                          const _ValueHighlightsCard(),
                          const SizedBox(height: 16),
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
                  Text(
                    tr(
                      'Bảo mật dữ liệu cá nhân • Bắt đầu ngay hôm nay',
                      'Personal data protected • Start today',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WrColors.text3,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C093774),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/thumb_intro_overview.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [WrColors.navy, Color(0xFF1B4E92)],
                          ),
                        ),
                      ),
                    ),
                    // Badge thời lượng ở góc trên
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: WrColors.navy.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: WrColors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: WrColors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr('1 phút', '1 min'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: WrColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: WrColors.pageBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.smart_display_outlined,
                        size: 20,
                        color: WrColors.navy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Xem video hướng dẫn', 'Watch the intro video'),
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: WrColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr('Khoảng 1 phút', 'About 1 minute'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: WrColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: WrColors.text3,
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

/// Thẻ hiển thị 3 giá trị cốt lõi của ứng dụng.
class _ValueHighlightsCard extends StatelessWidget {
  const _ValueHighlightsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WrColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08093774),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _FeatureHighlightItem(
            icon: Icons.schedule_rounded,
            iconBg: WrColors.coral.withValues(alpha: 0.12),
            iconColor: WrColors.pillCoralText,
            title: tr('3 phút mỗi ngày', '3 minutes daily'),
            description: tr(
              'Ghi nhận sự kiện, cảm xúc và bài học công việc nhanh chóng',
              'Capture events, emotions and career lessons effortlessly',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              height: 1,
              color: WrColors.lineSoft,
            ),
          ),
          _FeatureHighlightItem(
            icon: Icons.auto_awesome_outlined,
            iconBg: WrColors.teal.withValues(alpha: 0.14),
            iconColor: WrColors.pillTealText,
            title: tr('Trợ lý AI thấu hiểu', 'Insightful AI Assistant'),
            description: tr(
              'Phân tích điểm mạnh, rào cản và mở rộng góc nhìn',
              'Identify strengths, bottlenecks and expand your perspective',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              height: 1,
              color: WrColors.lineSoft,
            ),
          ),
          _FeatureHighlightItem(
            icon: Icons.verified_user_outlined,
            iconBg: WrColors.navy.withValues(alpha: 0.08),
            iconColor: WrColors.navy,
            title: tr('Riêng tư & An toàn', 'Private & Secure'),
            description: tr(
              'Dữ liệu cá nhân được bảo mật, thuộc về riêng bạn',
              'Personal data is protected, strictly belonging to you',
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureHighlightItem extends StatelessWidget {
  const _FeatureHighlightItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.iconBg,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: WrColors.text2,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
