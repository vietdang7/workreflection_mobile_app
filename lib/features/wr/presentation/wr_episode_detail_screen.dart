// Một lần nhìn lại — màn đọc riêng, mở từ tab Hành trình.
//
// Đây là màn ĐỌC: dựng lại đúng những gì người dùng đã viết trong Episode,
// theo thứ tự Pattern đã đi qua (HXA §3). Không có ô nhập ở đây — muốn ghi
// thêm thì bắt đầu một lần nhìn lại mới.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_experience_state.dart';
import '../../../core/models/wr_episode.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../episode_flow_controller.dart';
import '../wr_providers.dart';

class WrEpisodeDetailScreen extends ConsumerWidget {
  const WrEpisodeDetailScreen({super.key, required this.episodeId});

  final String episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wrEpisodeByIdProvider(episodeId));
    final episode = async.valueOrNull;

    if (episode == null) {
      return WrDetailScaffold(
        eyebrow: 'MỘT LẦN NHÌN LẠI',
        title: 'Không mở được lần nhìn lại này',
        children: const [
          Text(
            'Có thể nó đã bị xoá, hoặc thiết bị đang mất kết nối.',
            key: Key('wr_episode_detail_missing'),
            style: TextStyle(fontSize: 16.5, color: WrColors.muted, height: 1.65),
          ),
        ],
      );
    }

    final at = episode.closedAt ?? episode.updatedAt ?? episode.openedAt;
    final dateStr = at == null
        ? ''
        : '${at.day.toString().padLeft(2, '0')}/'
            '${at.month.toString().padLeft(2, '0')}/${at.year}';

    return WrDetailScaffold(
      eyebrow: 'MỘT LẦN NHÌN LẠI',
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
          const _Label('ĐIỀU BẠN NHẬN RA'),
          Text(
            episode.draftMeaning!.trim(),
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
        const _Label('BẠN ĐÃ VIẾT'),
        if (episode.patternsDone.isEmpty)
          const Text(
            'Lần này bạn chưa ghi lại gì.',
            style: TextStyle(fontSize: 16.5, color: WrColors.muted, height: 1.6),
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
                    promptFor(episode.humanMoment, p),
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: WrColors.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
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
          const _Label('BƯỚC NHỎ BẠN CHỌN'),
          Text(
            episode.tinyAction!.trim(),
            key: const Key('wr_episode_detail_action'),
            style: const TextStyle(
              fontSize: 16,
              color: WrColors.navy,
              height: 1.6,
            ),
          ),
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
          final reopened =
              await ref.read(episodeFlowProvider.notifier).reopen(episode);
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
        child: const Text(
          'Hiểu lại chuyện này',
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
