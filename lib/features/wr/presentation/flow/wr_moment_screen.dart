// Màn 2 — sáu Human Moment Archetype (HXA §2.5).
//
// Người dùng chọn khoảnh khắc, KHÔNG chọn kiểu phản tư (HXA Invariant 5).
// Chọn xong là Episode được mở (state Captured) và luồng đi tiếp.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../episode_flow_controller.dart';
import '../../../../core/logic/wr_flow_error.dart';
import 'wr_flow_scaffold.dart';

class WrMomentScreen extends ConsumerStatefulWidget {
  const WrMomentScreen({super.key});

  @override
  ConsumerState<WrMomentScreen> createState() => _WrMomentScreenState();
}

class _WrMomentScreenState extends ConsumerState<WrMomentScreen> {
  HumanMoment? _selected;
  bool _busy = false;
  String? _error;

  /// Chọn khoảnh khắc là đã trả lời — Episode mở ngay và luồng đi tiếp.
  /// Không có nút xác nhận: mỗi màn chỉ một hành động.
  Future<void> _pick(HumanMoment moment) async {
    final energy = ref.read(pendingEnergyProvider);
    if (energy == null || _busy) return;

    setState(() {
      _selected = moment;
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(episodeFlowProvider.notifier)
          .start(energy: energy, moment: moment);
      if (mounted) context.push('/wr/flow/step');
    } catch (e, s) {
      logFlowError('openEpisode', e, s);
      if (mounted) {
        setState(() => _error = 'Không mở được phiên phản tư. Thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WrFlowScaffold(
      eyebrow: 'Khoảnh khắc',
      title: 'Điều gì đang diễn ra với bạn?',
      progress: 0.4,
      onBack: () => context.pop(),
      onClose: () => context.go('/home'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < HumanMoment.values.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _momentTile(HumanMoment.values[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < HumanMoment.values.length
                      ? _momentTile(HumanMoment.values[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: WrColors.coral),
            ),
          ],
        ],
      ),
    );
  }

  Widget _momentTile(HumanMoment moment) {
    return WrBigChoiceTile(
      key: Key('wr_moment_${moment.dbValue}'),
      label: moment.label,
      selected: _selected == moment,
      height: 104,
      onTap: _busy ? () {} : () => _pick(moment),
    );
  }
}
