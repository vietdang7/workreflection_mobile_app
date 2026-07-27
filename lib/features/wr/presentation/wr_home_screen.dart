// Home — WXS §8.7 (Balanced Surface) + HXA §6.4 (Empty Screen Test).
//
// Câu hỏi của Empty Screen Test: "Điều duy nhất người dùng cần ngay lúc này là
// gì?" Câu trả lời: một lời mời dừng lại. Vì vậy màn này chỉ có:
//   1. lời chào + ngày
//   2. một lời mời phản tư (hoặc lời mời tiếp tục phiên đang mở)
//   3. một dòng ý nghĩa gần nhất — nếu có
//
// Mọi thứ khác (tình huống lặp lại, SCA, story, thực hành) sống ở tab của nó.
// Home không xổ nội dung.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/logic/wr_experience_state.dart';
import '../../../core/models/mobile_profile.dart';
import '../../../core/models/wr_episode.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../episode_flow_controller.dart';
import '../wr_providers.dart';

final _mobileProfileProvider = FutureProvider<MobileProfile?>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  return repo.getMobileProfile();
});

class WrHomeScreen extends ConsumerWidget {
  const WrHomeScreen({super.key});

  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  String _dateLabel() {
    final now = todayVn();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    return '${_weekdays[now.weekday - 1]}, $day/$month';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName =
        ref.watch(_mobileProfileProvider).valueOrNull?.displayName ?? '';
    final openEpisode = ref.watch(wrOpenEpisodeProvider).valueOrNull;
    final latestInsight = ref.watch(wrLatestInsightProvider).valueOrNull;

    return Scaffold(
      backgroundColor: WrColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── lời chào ────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isNotEmpty
                              ? 'Chào $displayName'
                              : 'Chào bạn',
                          style: const TextStyle(
                            fontSize: 14,
                            color: WrColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateLabel(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: WrColors.navy,
                            letterSpacing: -0.96,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ProfileAvatarButton(displayName: displayName),
                ],
              ),

              const Spacer(),

              // ── lời mời duy nhất ────────────────────────────────────────
              if (openEpisode != null)
                _ResumeInvite(episode: openEpisode)
              else
                const _StartInvite(),

              const Spacer(),

              // ── một dòng ý nghĩa gần nhất ───────────────────────────────
              if (latestInsight != null) ...[
                const WrEyebrow('LẦN GẦN NHẤT BẠN NHẬN RA'),
                const SizedBox(height: 10),
                Text(
                  '"${latestInsight.content}"',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    color: WrColors.navy,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lời mời bắt đầu — HXA §2.4 bước Pause: làm cho việc dừng lại thành tự nhiên.
// ---------------------------------------------------------------------------

class _StartInvite extends StatelessWidget {
  const _StartInvite();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dừng lại một chút?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
            height: 1.25,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Vài phút nhìn lại, để hôm nay không trôi qua như mọi ngày.',
          style: TextStyle(fontSize: 15, color: WrColors.muted, height: 1.6),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('wr_home_start_reflection'),
            onPressed: () => context.push('/wr/flow/energy'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WrColors.navy,
              foregroundColor: WrColors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Bắt đầu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Lời mời tiếp tục — WXS §5.11: không "Chào mừng trở lại", mà hỏi phiên nào
// đang chờ. Experience luôn tiếp tục, không khởi động lại.
// ---------------------------------------------------------------------------

class _ResumeInvite extends ConsumerWidget {
  const _ResumeInvite({required this.episode});

  final ReflectionEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WrEyebrow('ĐANG CHỜ BẠN'),
        const SizedBox(height: 12),
        Text(
          episode.humanMoment.tension,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
            height: 1.3,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('wr_home_resume_reflection'),
            onPressed: () {
              ref.read(episodeFlowProvider.notifier).resume(episode);
              context.push(_routeForState(episode));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WrColors.navy,
              foregroundColor: WrColors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Tiếp tục',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          key: const Key('wr_home_start_new_reflection'),
          onPressed: () => context.push('/wr/flow/energy'),
          child: const Text(
            'Bắt đầu một lần nhìn lại mới',
            style: TextStyle(fontSize: 14, color: WrColors.muted),
          ),
        ),
      ],
    );
  }

  /// Màn tương ứng với trạng thái nhận thức hiện tại — phục hồi Experience,
  /// không phục hồi Screen (WXS §4.5).
  static String _routeForState(ReflectionEpisode episode) {
    return switch (episode.state) {
      ExperienceState.meaningConfirmed => '/wr/flow/commit',
      ExperienceState.committed => '/wr/flow/done',
      ExperienceState.meaningForming => '/wr/flow/meaning',
      // Đã đi hết chuỗi phản tư nhưng chưa đặt tên ý nghĩa.
      _ when nextPattern(episode.humanMoment, episode.patternsDone) == null =>
        '/wr/flow/meaning',
      _ => '/wr/flow/step',
    };
  }
}

// ---------------------------------------------------------------------------
// Lối vào hồ sơ
// ---------------------------------------------------------------------------

class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton({required this.displayName});

  final String displayName;

  String get _initials {
    final parts = displayName.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return 'WR';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('wr_home_profile_button'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/profile'),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: WrColors.cream,
          shape: BoxShape.circle,
        ),
        child: Text(
          _initials,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
      ),
    );
  }
}
