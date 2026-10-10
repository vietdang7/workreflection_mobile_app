// Hoàn tất — khép Episode (mockup v47, `screenReflectFlow` sau bước 4).
//
// Đây là nơi duy nhất Meaning được đưa vào Career Memory (WDA Invariant 6:
// chỉ những trải nghiệm đã được chuyển hóa mới được lưu).
//
// Hai tiêu đề như mockup: "Đã ghi nhận một cột mốc" khi lần này là một "lần
// đầu" theo luật Cột mốc của Career Memory (`milestoneTextForStory` — cột mốc là
// cờ trên STORY, không phải bản ghi riêng), còn lại "Đã lưu vào Career Memory".
// Bên dưới là "Điều được giữ lại": Insight người dùng vừa giữ ở bước 3.
//
// Nội dung hiển thị ở đây là GHI NHẬN, không phải diễn giải — nên bản miễn phí
// vẫn thấy đủ (yêu cầu khách #4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/wr_tr.dart';
import '../../../auth/guest_session.dart';
import '../../../auth/presentation/wr_save_journey_sheet.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../episode_flow_controller.dart';
import '../../wr_providers.dart';
import '../../../../core/logic/wr_flow_error.dart';
import '../../../../core/logic/wr_career_memory_rules.dart'
    show closedStories, milestoneTextForStory;
import '../../../../core/logic/wr_reflect_v47.dart';
import '../../../../core/logic/wr_repeated_situations.dart';
import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_text.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/wr_paragraph.dart';

/// Mockup v47: sheet lưu hành trình hiện sau màn Xong 1100ms.
const kSaveSheetDelay = Duration(milliseconds: 1100);

class WrDoneScreen extends ConsumerStatefulWidget {
  const WrDoneScreen({super.key});

  @override
  ConsumerState<WrDoneScreen> createState() => _WrDoneScreenState();
}

class _WrDoneScreenState extends ConsumerState<WrDoneScreen> {
  bool _integrating = true;
  String? _meaning;
  String? _situationCode;

  /// Episode vừa khép, để xét Cột mốc.
  ReflectionEpisode? _closed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _integrate());
  }

  Future<void> _integrate() async {
    final episode = ref.read(episodeFlowProvider);
    _meaning = episode?.draftMeaning;
    _situationCode = episode?.situationCode;
    _closed = episode;
    try {
      await ref.read(episodeFlowProvider.notifier).integrate();
    } catch (e, s) {
      logFlowError('integrate', e, s);
      /* best-effort: nội dung đã được ghi ở từng bước */
    }
    if (mounted) setState(() => _integrating = false);
    await _inviteGuestToSave();
  }

  /// Khách vừa xong lần nhìn lại đầu tiên: mời lưu hành trình (mockup v47,
  /// `saveSheetHTML`). Trễ 1,1 giây như mockup, để người dùng kịp đọc màn
  /// Xong trước khi bị hỏi. Mỗi khách chỉ được mời tự động một lần; "Để sau"
  /// thì lối lưu vẫn nằm ở màn Tài khoản.
  Future<void> _inviteGuestToSave() async {
    if (!ref.read(isGuestProvider)) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || await saveSheetSeen(uid)) return;
    await Future<void>.delayed(kSaveSheetDelay);
    if (!mounted || !ref.read(isGuestProvider)) return;
    await markSaveSheetSeen(uid);
    if (!mounted) return;
    await showSaveJourneySheet(context);
  }

  /// Số lần đã gặp tình huống này — thuần ghi nhận, không diễn giải.
  ///
  /// Đếm từ Episode chứ không từ `wr_pattern_counts` (v2.0 §4.3): bảng kia cộng
  /// thêm một lần nữa mỗi khi người dùng mở lại một Episode đã khép và xác nhận
  /// Ý nghĩa lần hai, nên "lần thứ N" ở đây sẽ vượt số lần ghi ở màn chi tiết.
  int? _occurrenceCount(List<ReflectionEpisode>? episodes) {
    final code = _situationCode;
    if (code == null || episodes == null) return null;
    return countSituation(episodes, code);
  }

  /// Câu Cột mốc nếu lần nhìn lại vừa khép là một "lần đầu".
  String? _milestone(List<ReflectionEpisode>? episodes) {
    final episode = _closed;
    if (episode == null || episodes == null) return null;
    final previous = closedStories([
      for (final e in episodes)
        if (e.id != episode.id) e,
    ]);
    return milestoneTextForStory(story: episode, previousStories: previous);
  }

  void _home() {
    ref.read(episodeFlowProvider.notifier).leave();
    ref.read(pendingEnergyProvider.notifier).state = null;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final history = _integrating
        ? null
        : ref.watch(wrEpisodeHistoryProvider).valueOrNull;
    final milestone = _milestone(history);
    final count = _occurrenceCount(history);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 18, 0),
                child: TextButton(
                  key: const Key('wr_flow_close'),
                  onPressed: _integrating ? null : _home,
                  style: TextButton.styleFrom(foregroundColor: WrColors.text2),
                  child: Text(
                    tr('Đóng', 'Close'),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _integrating
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              tr('Đang lưu lại…', 'Saving…'),
                              style: const TextStyle(
                                fontSize: 15,
                                color: WrColors.text2,
                              ),
                            ),
                          ],
                        )
                      : _doneBody(milestone: milestone, count: count),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneBody({String? milestone, int? count}) {
    final kept = _meaning?.trim();
    return Column(
      key: const Key('wr_done_body'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: WrColors.teal.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 28,
            color: WrColors.teal,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          milestone != null ? kDoneMilestoneTitle : kDoneSavedTitle,
          key: const Key('wr_done_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: WrColors.navy,
            height: 1.32,
          ),
        ),
        const SizedBox(height: 8),
        WrParagraph(
          milestone != null ? kDoneMilestoneNote : kDoneSavedNote,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: WrColors.text2,
            height: 1.65,
          ),
        ),
        if (kept != null && kept.isNotEmpty)
          _MemoryNote(
            key: const Key('wr_done_kept'),
            eyebrow: kDoneKept,
            child: WrParagraph(
              '“$kept”',
              style: WrText.serifQuote(
                fontSize: 14,
                color: WrColors.navy,
                height: 1.6,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        if (milestone != null)
          _MemoryNote(
            key: const Key('wr_done_milestone'),
            eyebrow: tr('Career Memory · Cột mốc', 'Career Memory · Milestone'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrParagraph(
                  milestone,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 5),
                Text(
                  tr('Được ghi nhận hôm nay', 'Recorded today'),
                  style: const TextStyle(fontSize: 12.5, color: WrColors.text3),
                ),
              ],
            ),
          ),
        if (count != null && count >= 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              tr(
                'Bạn đã ghi lại tình huống này $count lần',
                'You have recorded this situation $count times',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: WrColors.text3),
            ),
          ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('wr_flow_primary'),
            onPressed: _home,
            style: FilledButton.styleFrom(
              backgroundColor: WrColors.navy,
              foregroundColor: WrColors.cream,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              kDoneHome,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

/// `.completion-memory`: nền ửng coral, bo đều bốn góc. Mockup có vạch coral
/// bên trái; khách 10/10 bảo bỏ vì nhìn lệch cả màn (mọi khối khác đều căn
/// giữa).
class _MemoryNote extends StatelessWidget {
  const _MemoryNote({super.key, required this.eyebrow, required this.child});

  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: WrColors.coral.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(eyebrow, color: WrColors.pillCoralText),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}
