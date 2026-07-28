// Hôm nay — bố cục theo giao diện chính (`giao-dien-chinh.html` §screen-home).
//
// Bốn khối, đúng thứ tự của bản thiết kế:
//   1. lời chào + ngày
//   2. "Bạn đang trải qua điều gì?" + lưới check-in 2×2
//   3. thẻ navy "Hệ thống nhận ra"  → dẫn sang màn chi tiết điều lặp lại
//   4. "Gợi ý khi …" + thẻ Thư viện Nội dung Cảm xúc → dẫn sang màn đọc/nghe
//   5. "Insight gần nhất"
//
// Bốn khối này khớp đúng danh sách nội dung tab Home ở Kiến trúc Dữ liệu v1.6
// §9.1. Thẻ ở khối 4 trước đây gợi ý một Story; từ v1.6 nó là Thư viện Nội dung
// Cảm xúc (§VIII) — hai mạch khác nhau: Story giờ là nguồn nội dung cho tình
// huống trong luồng phản tư, còn thư viện này là nội dung chăm sóc cảm xúc.
//
// Toàn bộ nội dung ba khối dưới đến từ dữ liệu thật của người dùng
// (`lib/core/logic/wr_home_surface.dart`). Chưa đủ dữ liệu thì khối biến mất
// hẳn — WXS Orch. Inv.5: im lặng là lựa chọn hợp lệ, không bịa nội dung mẫu.
//
// Chọn một ô check-in là đã trả lời: luồng đi thẳng sang màn khoảnh khắc rồi
// tới các câu hỏi dẫn dắt của khoảnh khắc đó (HXA §2.5, §3.6). Không có nút
// "Bắt đầu" trung gian.
//
// Ngoại lệ: còn phiên đang dở thì Journey Continuity được ưu tiên hơn novelty
// (WXS Orch. Inv.3) — Home mời tiếp tục trước.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/logic/wr_experience_state.dart';
import '../../../core/logic/wr_home_surface.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/mobile_profile.dart';
import '../../../core/models/wr_episode.dart';
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/wr_card.dart';
import '../episode_flow_controller.dart';
import '../mood_content_providers.dart';
import '../wr_providers.dart';
import 'wr_mood_library_screen.dart' show WrDraftBadge;

final _mobileProfileProvider = FutureProvider<MobileProfile?>((ref) async {
  final repo = ref.watch(wrRepositoryProvider);
  return repo.getMobileProfile();
});

// ---------------------------------------------------------------------------
// Lưới check-in — bốn ô như bản thiết kế, mỗi ô là một mức năng lượng.
//
// Khách yêu cầu bỏ bước "trạng thái" tách rời khỏi "năng lượng"; ở đây chỉ còn
// MỘT câu hỏi, bốn cách nói của cùng một thang năng lượng.
// ---------------------------------------------------------------------------

typedef CheckinOption = ({
  String id,
  String label,
  CheckinEnergy energy,
  Mood mood,
});

/// Bốn ô check-in. [mood] KHÔNG suy được từ [energy]: "căng thẳng" và "mệt mỏi"
/// dùng chung `CheckinEnergy.low`, nhưng Kiến trúc Dữ liệu v1.6 §III lọc tình
/// huống theo hai cụm chiều khác nhau cho hai cảm xúc đó. Giữ cả hai trường.
const List<CheckinOption> kCheckinOptions = [
  (
    id: 'stress',
    label: 'Tôi đang\ncăng thẳng',
    energy: CheckinEnergy.low,
    mood: Mood.stressed,
  ),
  (
    id: 'tired',
    label: 'Tôi mệt mỏi\ncần nghỉ ngơi',
    energy: CheckinEnergy.low,
    mood: Mood.tired,
  ),
  (id: 'ok', label: 'Tôi\nkhá ổn', energy: CheckinEnergy.ok, mood: Mood.okay),
  (
    id: 'happy',
    label: 'Tôi\nđang vui',
    energy: CheckinEnergy.good,
    mood: Mood.happy,
  ),
];

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

    return Scaffold(
      backgroundColor: WrColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── top-area ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
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
                        const SizedBox(height: 2),
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
                  WrProfileAvatar(
                    key: const Key('wr_home_profile_button'),
                    displayName: displayName,
                  ),
                ],
              ),
            ),

            // ── screen-body ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                children: [
                  if (openEpisode != null)
                    _ResumeInvite(episode: openEpisode)
                  else
                    const _CheckinQuestion(),
                  const SizedBox(height: 28),
                  const WrSectionDivider(),
                  const SizedBox(height: 28),
                  const _SystemNoticeCard(),
                  const _MoodContentSection(),
                  const _LatestInsightSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 · "Bạn đang trải qua điều gì?" + lưới 2×2
// ---------------------------------------------------------------------------

class _CheckinQuestion extends ConsumerWidget {
  const _CheckinQuestion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tô theo cảm xúc đã ghi, không theo năng lượng: "căng thẳng" và "mệt mỏi"
    // cùng là năng lượng thấp, nên khớp bằng energy sẽ luôn sáng ô đầu tiên dù
    // người dùng chạm ô thứ hai.
    final todayMood = ref.watch(todayCheckinProvider).valueOrNull?.mood;
    final selectedId = todayMood == null
        ? null
        : kCheckinOptions
              .where((o) => o.mood == todayMood)
              .map((o) => o.id)
              .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bạn đang trải qua điều gì?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
            height: 1.2,
            letterSpacing: -0.44,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < kCheckinOptions.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CheckinTile(
                  option: kCheckinOptions[i],
                  selected: kCheckinOptions[i].id == selectedId,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < kCheckinOptions.length
                    ? _CheckinTile(
                        option: kCheckinOptions[i + 1],
                        selected: kCheckinOptions[i + 1].id == selectedId,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CheckinTile extends ConsumerWidget {
  const _CheckinTile({required this.option, required this.selected});

  final CheckinOption option;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      key: Key('wr_home_checkin_${option.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(pendingEnergyProvider.notifier).state = option.energy;
        ref.read(pendingMoodProvider.notifier).state = option.mood;
        context.push('/wr/flow/moment');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? WrColors.coral : WrColors.cream,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          option.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: selected ? WrColors.white : WrColors.navy,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · Thẻ navy "Hệ thống nhận ra" — đọc lại chính con số của người dùng.
// ---------------------------------------------------------------------------

class _SystemNoticeCard extends ConsumerWidget {
  const _SystemNoticeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patterns = ref.watch(wrPatternCountsProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final notice = systemNotice(patterns: patterns, situations: situations);

    // Chưa lặp lại lần nào thì hệ thống chưa có gì để nhận ra — im lặng.
    if (notice == null) return const SizedBox.shrink();

    return Padding(
      key: const Key('wr_home_system_notice'),
      padding: const EdgeInsets.only(bottom: 28),
      child: WrCardDark(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WrEyebrow(
              'HỆ THỐNG NHẬN RA',
              color: WrColors.cream.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              '"${notice.sentence}"',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: WrColors.cream,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              key: const Key('wr_home_notice_link'),
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/wr/pattern/${notice.situationCode}'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tìm hiểu thêm',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WrColors.coral,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: WrColors.coral),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · "Gợi ý khi …" — Thư viện Nội dung Cảm xúc.
//
// Kiến trúc Dữ liệu v1.6 §8.3: Home hiện đúng MỘT mục, là mục đầu tiên của
// nhóm theo cảm xúc vừa check-in. Không xoay vòng ở đây — xoay vòng làm thẻ
// đổi nội dung mỗi lần mở app, người dùng không quay lại được bài đang đọc dở.
//
// §8.3: miễn phí cho mọi người dùng, không phân lớp Free/Paid, vì đây là nội
// dung chăm sóc cảm xúc chứ không phải trí tuệ rút từ dữ liệu cá nhân.
// ---------------------------------------------------------------------------

class _MoodContentSection extends ConsumerWidget {
  const _MoodContentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(todayCheckinProvider).valueOrNull?.mood;
    final items = ref.watch(wrTodayMoodContentProvider).valueOrNull ?? const [];

    // Chưa check-in hoặc chưa có nội dung thì khối biến mất hẳn —
    // WXS Orch. Inv.5: im lặng là lựa chọn hợp lệ, không bịa nội dung mẫu.
    if (mood == null || items.isEmpty) return const SizedBox.shrink();

    final item = items.first;

    return Padding(
      key: const Key('wr_home_mood_content'),
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(moodSuggestionTitle(mood)),
          const SizedBox(height: 8),
          GestureDetector(
            key: const Key('wr_home_mood_content_card'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/wr/mood-content/${item.id}'),
            child: WrCardMinimal(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: WrColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.type == MoodContentType.audio
                          ? Icons.mic_none_outlined
                          : Icons.menu_book_outlined,
                      size: 26,
                      color: WrColors.navy,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: WrColors.dark,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (item.placeholder) ...[
                              const SizedBox(width: 6),
                              const WrDraftBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.kind} · ${item.duration}',
                          style: TextStyle(
                            fontSize: 13,
                            color: WrColors.dark.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: WrColors.muted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              key: const Key('wr_home_mood_library_link'),
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/wr/mood-library'),
              // Mũi tên dùng Icon chứ không dùng ký tự "→": font chữ của app
              // không chắc có glyph U+2192, thiếu là ra ô vuông rỗng.
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem thêm gợi ý trong thư viện',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: WrColors.teal,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 13, color: WrColors.teal),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5 · "Insight gần nhất" — câu chính người dùng đã xác nhận.
// ---------------------------------------------------------------------------

class _LatestInsightSection extends ConsumerWidget {
  const _LatestInsightSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(wrLatestInsightProvider).valueOrNull;
    if (insight == null) return const SizedBox.shrink();

    final at = insight.createdAt;
    final saved = at == null
        ? null
        : 'Lưu ngày ${at.day.toString().padLeft(2, '0')}/'
              '${at.month.toString().padLeft(2, '0')}';

    return Column(
      key: const Key('wr_home_latest_insight'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WrEyebrow('INSIGHT GẦN NHẤT'),
        const SizedBox(height: 8),
        Text(
          '"${insight.content}"',
          style: const TextStyle(
            fontSize: 20,
            fontStyle: FontStyle.italic,
            color: WrColors.navy,
            height: 1.45,
            letterSpacing: -0.3,
          ),
        ),
        if (saved != null) ...[
          const SizedBox(height: 10),
          Text(
            saved,
            style: TextStyle(
              fontSize: 12,
              color: WrColors.dark.withValues(alpha: 0.8),
            ),
          ),
        ],
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
        const SizedBox(height: 10),
        Text(
          episode.humanMoment.tension,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
            height: 1.2,
            letterSpacing: -0.44,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('wr_home_resume_reflection'),
            onPressed: () async {
              final route = _routeForState(episode);
              await ref.read(episodeFlowProvider.notifier).resume(episode);
              if (context.mounted) context.push(route);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WrColors.navy,
              foregroundColor: WrColors.white,
              minimumSize: const Size.fromHeight(52),
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
