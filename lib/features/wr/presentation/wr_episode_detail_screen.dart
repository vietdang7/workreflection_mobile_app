// Một lần nhìn lại — màn đọc riêng, mở từ tab Hành trình.
//
// Đây là màn ĐỌC: dựng lại đúng những gì người dùng đã viết trong Episode,
// theo thứ tự Pattern đã đi qua (HXA §3). Không có ô nhập ở đây — muốn ghi
// thêm thì bắt đầu một lần nhìn lại mới.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_experience_state.dart';
import '../../../core/logic/wr_reflect_v47.dart'
    show
        kMomentTitle,
        kPickStoryTitle,
        ReflectNextOption,
        reflectionNextOptions,
        relocaliseEpisodeInsight;
import '../../../core/logic/wr_situation_picker.dart' show resolveStoryFor;
import '../../../core/models/wr_episode.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../episode_flow_controller.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

class WrEpisodeDetailScreen extends ConsumerWidget {
  const WrEpisodeDetailScreen({super.key, required this.episodeId});

  final String episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wrEpisodeByIdProvider(episodeId));
    final episode = async.valueOrNull;

    if (episode == null) {
      return WrDetailScaffold(
        eyebrow: tr('MỘT LẦN NHÌN LẠI', 'ONE LOOK BACK'),
        title: tr(
          'Không mở được lần nhìn lại này',
          'Could not open this look back',
        ),
        children: [
          WrParagraph(
            tr(
              'Có thể nó đã bị xoá, hoặc thiết bị đang mất kết nối.',
              'It may have been deleted, or the device is offline.',
            ),
            key: Key('wr_episode_detail_missing'),
            style: TextStyle(
              fontSize: 16.5,
              color: WrColors.muted,
              height: 1.65,
            ),
          ),
        ],
      );
    }

    final at = (episode.closedAt ?? episode.updatedAt ?? episode.openedAt)
        ?.toLocal();
    final dateStr = at == null
        ? ''
        : '${at.day.toString().padLeft(2, '0')}/'
              '${at.month.toString().padLeft(2, '0')}/${at.year}';

    final chosen = _chosenOption(ref, episode);

    return WrDetailScaffold(
      eyebrow: tr('MỘT LẦN NHÌN LẠI', 'ONE LOOK BACK'),
      title: episode.humanMoment.label,
      children: [
        if (dateStr.isNotEmpty)
          Text(
            dateStr,
            style: const TextStyle(fontSize: 15.5, color: WrColors.muted),
          ),
        const SizedBox(height: 24),

        // ── Điều bạn nhận ra ─────────────────────────────────────────────
        if (episode.draftMeaning?.trim().isNotEmpty == true) ...[
          _Label(tr('ĐIỀU BẠN NHẬN RA', 'WHAT YOU NOTICED')),
          Text(
            // Câu Insight lưu bằng ngôn ngữ lúc bấm giữ; dựng lại theo ngôn
            // ngữ đang bật. Câu người dùng tự viết thì giữ nguyên.
            relocaliseEpisodeInsight(
              episode.draftMeaning!,
              episode: episode,
              situations:
                  ref.watch(wrSituationsProvider).valueOrNull ?? const [],
              stories: ref.watch(wrStoriesProvider).valueOrNull ?? const [],
            ).trim(),
            key: const Key('wr_episode_detail_meaning'),
            style: const TextStyle(
              fontSize: 19,
              color: WrColors.navy,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          const WrSectionDivider(),
          const SizedBox(height: 20),
        ],

        // ── Từng bước đã đi qua ──────────────────────────────────────────
        _Label(tr('BẠN ĐÃ VIẾT', 'WHAT YOU WROTE')),
        if (episode.patternsDone.isEmpty)
          Text(
            tr(
              'Lần này bạn chưa ghi lại gì.',
              'You did not write anything that time.',
            ),
            style: TextStyle(
              fontSize: 16.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          )
        else
          ...episode.patternsDone.map((p) {
            final note = episode.notes[p.dbValue];
            if (note == null || note.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _promptOf(episode, p),
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: WrColors.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  WrParagraph(
                    note.trim(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: WrColors.navy,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            );
          }),

        // ── Bước nhỏ ─────────────────────────────────────────────────────
        if (episode.tinyAction?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          const WrSectionDivider(),
          const SizedBox(height: 20),
          _Label(tr('BƯỚC NHỎ BẠN CHỌN', 'THE SMALL STEP YOU CHOSE')),
          Text(
            chosen?.title ?? episode.tinyAction!.trim(),
            key: const Key('wr_episode_detail_action'),
            style: const TextStyle(
              fontSize: 16,
              color: WrColors.navy,
              height: 1.6,
            ),
          ),
          if (chosen != null) ...[
            const SizedBox(height: 4),
            WrParagraph(
              chosen.desc,
              key: const Key('wr_episode_detail_action_desc'),
              style: const TextStyle(
                fontSize: 15,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
          ],
        ],

        // ── Mở lại ───────────────────────────────────────────────────────
        // WPA Inv.4 · WXS Inv.7: không có trạng thái khoá vĩnh viễn. Hiểu lại
        // một chuyện cũ là quyền của người dùng, không phải ngoại lệ.
        if (canTransition(episode.state, ExperienceState.reactivated)) ...[
          const SizedBox(height: 32),
          _ReopenButton(episode: episode),
        ],
      ],
    );
  }
}

class _ReopenButton extends ConsumerWidget {
  const _ReopenButton({required this.episode});

  final ReflectionEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        key: const Key('wr_episode_reopen'),
        onPressed: () async {
          final reopened = await ref
              .read(episodeFlowProvider.notifier)
              .reopen(episode);
          if (!context.mounted || reopened == null) return;
          context.go('/wr/flow/step');
        },
        style: TextButton.styleFrom(
          backgroundColor: WrColors.navy,
          foregroundColor: WrColors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          tr('Hiểu lại chuyện này', 'Look at this again'),
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: WrColors.muted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Câu hỏi của bước [p] đúng như lúc người dùng trả lời.
///
/// Lượt v47 (không có ghi chú bước reframe) đi bốn bước: chọn một câu kể rồi
/// viết khoảnh khắc. [promptFor] là câu hỏi của luồng năm bước cũ ("Điều gì
/// đang làm bạn mất năng lượng?"), đặt cạnh câu trả lời v47 là lệch nghĩa.
String _promptOf(ReflectionEpisode e, ReflectionPattern p) {
  final isV47 =
      e.notes[ReflectionPattern.reframe.dbValue]?.trim().isNotEmpty != true;
  if (isV47) {
    if (p == ReflectionPattern.notice) return kPickStoryTitle;
    if (p == ReflectionPattern.explore) return kMomentTitle;
  }
  return promptFor(e.humanMoment, p);
}

/// Thẻ phép thử người dùng đã chọn ở bước cuối, theo ngôn ngữ ĐANG bật.
///
/// `tiny_action` chỉ lưu TÊN thẻ ("Thử một bước nhỏ"), bằng ngôn ngữ lúc bấm
/// lưu, nên dựng lại bộ thẻ của tình huống đó ở cả hai ngôn ngữ rồi khớp theo
/// tên. Câu tự viết không khớp thẻ nào thì trả null, giữ nguyên chữ của họ.
ReflectNextOption? _chosenOption(WidgetRef ref, ReflectionEpisode e) {
  final action = e.tinyAction?.trim();
  if (action == null || action.isEmpty) return null;
  final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
  final stories = ref.watch(wrStoriesProvider).valueOrNull ?? const [];
  final situation = situations
      .where((s) => s.code == e.situationCode)
      .firstOrNull;
  final story = situation == null ? null : resolveStoryFor(situation, stories);
  // Getter `tr` / `practiceAction` đọc `wrEnglish` lúc gọi, nên dựng trong hàm.
  List<ReflectNextOption> build() => reflectionNextOptions(
    code: e.situationCode,
    practice: story?.practiceAction,
  );

  final current = build();
  final was = wrEnglish;
  wrEnglish = !was;
  final List<ReflectNextOption> other;
  try {
    other = build();
  } finally {
    wrEnglish = was;
  }
  for (final o in [...current, ...other]) {
    if (o.title == action) {
      return current.where((c) => c.id == o.id).firstOrNull;
    }
  }
  return null;
}
