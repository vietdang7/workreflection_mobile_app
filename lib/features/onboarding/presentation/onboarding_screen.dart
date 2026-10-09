// Onboarding năm bước — mockup v47 (`screenOnboarding`, 06/10/2026), ảnh
// theo v55 Watercolor (09/10): dùng đúng bộ ảnh của các tab để phong cách liền
// mạch từ màn giới thiệu sang màn dùng thật.
//
//   0 Dừng lại một chút   ảnh tab Hôm nay
//   1 Thấy rõ hơn         ảnh tab Hiểu mình
//   2 Hành trình          ảnh tab Hành trình
//   3 Riêng tư            dải ảnh tab Phát triển (v47 bỏ giờ nhắc và điều khoản)
//      → video hướng dẫn (khách 06/10: "video HDSD để sau landing page")
//   4 Bắt đầu             dải ảnh tab Hôm nay · chọn cảm xúc → vào thẳng lần nhìn lại đầu tiên
//
// Không bắt đăng ký trước. Chọn cảm xúc (hoặc Bỏ qua) mở một phiên KHÁCH
// (Supabase ẩn danh, `guest_session.dart`); sau lần nhìn lại đầu tiên, màn Xong
// mời lưu hành trình bằng email.
//
// Người đã có tài khoản (cài lại app, đổi máy) vào bằng dòng "Đã có tài khoản?
// Đăng nhập" ở bước đầu — mockup không vẽ dòng này, nhưng thiếu nó thì họ chỉ
// còn cách tạo một phiên khách rỗng.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../auth/guest_session.dart';
import '../../wr/presentation/wr_home_screen.dart'
    show CheckinOption, kCheckinOptions, startReflectionFromCheckin;
import '../intro_video_providers.dart';
import 'wr_intro_video_sheet.dart';

/// Ba bước có hero (`ONB_STEPS` của mockup v47).
typedef _HeroStep = ({String eyebrow, String title, String text});

List<_HeroStep> get _heroSteps => [
  (
    eyebrow: tr('Dừng lại một chút', 'Pause for a moment'),
    title: tr(
      'Có những ngày làm việc trôi qua rất vội.',
      'Some workdays rush by.',
    ),
    text: tr(
      'Giữa những ngày như vậy, dành một phút để xem mình đang thấy thế nào '
          'cũng đã là một việc đáng làm.',
      'On days like that, taking one minute to notice how you feel is already '
          'worth doing.',
    ),
  ),
  (
    eyebrow: tr('Thấy rõ hơn', 'See more clearly'),
    title: tr(
      'Nhận ra những điều đang âm thầm lặp lại.',
      'Notice what keeps quietly repeating.',
    ),
    text: tr(
      'Khi bạn quay lại đủ nhiều, những điều tưởng rời rạc sẽ dần hiện thành '
          'một mẫu hình quen thuộc. Nhìn thấy được nó thường là bước đầu tiên.',
      'When you come back often enough, things that seemed scattered start to '
          'form a familiar pattern. Seeing it is usually the first step.',
    ),
  ),
  (
    eyebrow: tr('Hành trình', 'Journey'),
    title: tr(
      'Những điều bạn ghi lại sẽ ở lại.',
      'What you write down stays with you.',
    ),
    text: tr(
      'Một niềm vui nhỏ, một quyết định khó, hay một ngày cạn năng lượng, tất '
          'cả được nối lại thành hành trình của riêng bạn.',
      'A small joy, a hard decision, or a drained day, all of it is joined '
          'into a journey of your own.',
    ),
  ),
];

/// Số bước, tính cả bước chọn cảm xúc.
const kOnboardingSteps = 5;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _busy = false;

  void _go(int step) =>
      setState(() => _step = step.clamp(0, kOnboardingSteps - 1));

  /// Hết bước Riêng tư: phát video hướng dẫn rồi mới sang chọn cảm xúc.
  Future<void> _afterPrivacy() async {
    ref.read(introVideoShownProvider.notifier).markShown();
    await showIntroVideo(context);
    if (mounted) _go(4);
  }

  /// Mở phiên khách rồi chạy [then]. Lỗi mạng thì ở lại màn này, báo một câu.
  Future<void> _asGuest(Future<void> Function(GoRouter router) then) async {
    if (_busy) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ensureGuestSession(ref);
      await setSeenOnboarding();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Chưa kết nối được. Kiểm tra mạng rồi thử lại.',
              'Could not connect. Check your network and try again.',
            ),
          ),
        ),
      );
      return;
    }
    await then(router);
  }

  Future<void> _pickMood(CheckinOption option) => _asGuest((router) async {
    if (!mounted) return;
    startReflectionFromCheckin(ref, option);
    // Home nằm dưới luồng nhìn lại, để nút quay lại của bước đầu (`pop`) có
    // chỗ về. `push` phải đợi một khung hình: go_router chưa dựng xong ngăn
    // xếp của `go` thì `push` sẽ chồng lên ngăn xếp cũ.
    router.go('/home');
    await WidgetsBinding.instance.endOfFrame;
    router.push('/wr/flow/step');
  });

  Future<void> _skip() => _asGuest((router) async => router.go('/home'));

  /// Người đã có tài khoản: đi đường cũ, đánh dấu đã xem rồi để router đưa
  /// sang `/auth`.
  Future<void> _signIn() async {
    await setSeenOnboarding();
    ref.invalidate(seenOnboardingProvider);
    await ref.read(seenOnboardingProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    // Ảnh v55 luôn sáng (đã bỏ hero tối theo khung giờ): biểu tượng thanh
    // trạng thái luôn màu tối.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: WrColors.pageBg,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey('onboarding_step_$_step'),
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_step <= 2) return _heroStep(_heroSteps[_step]);
    if (_step == 3) return _privacyStep();
    return _moodStep();
  }

  // ── Thanh đầu: nút lùi · năm vạch · Bỏ qua (`.onb-top`) ──────────────────

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.paddingOf(context).top + 16,
        22,
        0,
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Semantics(
              button: true,
              label: tr('Quay lại', 'Back'),
              child: InkResponse(
                key: const Key('onboarding_back'),
                onTap: _busy ? null : () => _go(_step - 1),
                radius: 22,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: WrColors.navy.withValues(alpha: 0.06),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: WrColors.navy,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Row(
              key: const Key('onboarding_segments'),
              children: [
                for (var k = 0; k < kOnboardingSteps; k++) ...[
                  if (k > 0) const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: k <= _step
                            ? WrColors.navy
                            : WrColors.navy.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            key: const Key('onboarding_skip'),
            onPressed: _busy ? null : _skip,
            style: TextButton.styleFrom(
              foregroundColor: WrColors.text2,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              tr('Bỏ qua', 'Skip'),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chữ (`.onb-copy`) ─────────────────────────────────────────────────────

  Widget _copy({
    required String eyebrow,
    required String title,
    String? text,
    double top = 6,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(26, top, 26, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: WrColors.eyebrow,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: WrColors.navy,
              height: 1.3,
            ),
          ),
          if (text != null) ...[
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xB82C335D),
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Nút dưới (`.onb-cta`) ─────────────────────────────────────────────────

  Widget _cta(String label, VoidCallback? onPressed, {Widget? below}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        16,
        22,
        18 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('onboarding_next'),
              onPressed: _busy ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(label),
            ),
          ),
          ?below,
        ],
      ),
    );
  }

  // ── Bước 0–2 ─────────────────────────────────────────────────────────────

  Widget _heroStep(_HeroStep s) {
    final asset = switch (_step) {
      0 => WrHeroArt.home.asset,
      1 => WrHeroArt.understand.asset,
      _ => WrHeroArt.grow.asset,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  // `.onb-hero { height: 292px }`, ảnh tràn lên thanh trạng
                  // thái.
                  height: 292 + MediaQuery.paddingOf(context).top,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: WrHeroBackdrop(
                          key: Key('onboarding_hero_$_step'),
                          asset: asset,
                          alignment: kWrOnboardingPhotoAlignment,
                          overlay: kWrOnboardingFade,
                        ),
                      ),
                      _topBar(),
                    ],
                  ),
                ),
                _copy(eyebrow: s.eyebrow, title: s.title, text: s.text),
              ],
            ),
          ),
        ),
        _cta(
          tr('Tiếp tục', 'Continue'),
          () => _go(_step + 1),
          below: _step == 0 ? _signInLink() : null,
        ),
      ],
    );
  }

  Widget _signInLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextButton(
        key: const Key('onboarding_sign_in'),
        onPressed: _busy ? null : _signIn,
        style: TextButton.styleFrom(foregroundColor: WrColors.text2),
        child: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 13.5),
            children: [
              TextSpan(text: tr('Đã có tài khoản? ', 'Have an account? ')),
              TextSpan(
                text: tr('Đăng nhập', 'Sign in'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bước 3: Riêng tư ─────────────────────────────────────────────────────

  Widget _privacyStep() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: WrReflectBand(mood: null, asset: WrHeroArt.act.asset),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                child: _copy(
                  top: 22,
                  eyebrow: tr('Riêng tư', 'Privacy'),
                  title: tr(
                    'Những gì bạn viết là của bạn',
                    'What you write is yours',
                  ),
                  text: tr(
                    'Nội dung bạn viết không hiển thị cho ai khác và không dùng '
                        'để nhận diện bạn. Số liệu dùng cho thống kê chung đều ở '
                        'dạng ẩn danh. Bạn có thể xoá bất cứ lúc nào.',
                    'What you write is never shown to anyone else and is not '
                        'used to identify you. Figures used for overall '
                        'statistics are anonymous. You can delete them at any '
                        'time.',
                  ),
                ),
              ),
            ),
            _cta(tr('Tiếp tục', 'Continue'), _afterPrivacy),
          ],
        ),
      ],
    );
  }

  // ── Bước 4: chọn cảm xúc ─────────────────────────────────────────────────

  Widget _moodStep() {
    final options = kCheckinOptions;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: WrReflectBand(mood: null, asset: WrHeroArt.home.asset),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _copy(
                      top: 22,
                      eyebrow: tr('Bắt đầu', 'Begin'),
                      title: tr(
                        'Ngày hôm nay của bạn như thế nào?',
                        'How has your day been?',
                      ),
                      text: tr(
                        'Chọn cảm xúc sát nhất với bạn lúc này để bắt đầu lần '
                            'nhìn lại đầu tiên.',
                        'Pick the feeling closest to you right now to begin '
                            'your first look back.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: Column(
                        children: [
                          for (var i = 0; i < options.length; i += 2) ...[
                            if (i > 0) const SizedBox(height: 8),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: _moodTile(options[i])),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: i + 1 < options.length
                                        ? _moodTile(options[i + 1])
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_busy)
                      const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      Text(
                        tr(
                          'Lần nhìn lại đầu tiên chỉ mất khoảng một phút.',
                          'Your first look back takes about a minute.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: WrColors.text3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _moodTile(CheckinOption option) {
    return Material(
      color: WrColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Color(0x24093774), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('onboarding_mood_${option.id}'),
        onTap: _busy ? null : () => _pickMood(option),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Center(
            child: Text(
              option.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WrColors.navy,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
