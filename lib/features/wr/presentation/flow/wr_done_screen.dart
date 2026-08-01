// Màn 6 — khép Episode.
//
// Đây là nơi duy nhất Meaning được đưa vào Career Memory (WDA Invariant 6:
// chỉ những trải nghiệm đã được chuyển hóa mới được lưu).
//
// Nội dung hiển thị ở đây là GHI NHẬN, không phải diễn giải — nên bản miễn phí
// vẫn thấy đủ (yêu cầu khách #4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/wr_colors.dart';
import '../../episode_flow_controller.dart';
import '../../wr_providers.dart';
import '../../../../core/logic/wr_flow_error.dart';
import '../../../../core/logic/wr_repeated_situations.dart';
import 'wr_flow_scaffold.dart';

class WrDoneScreen extends ConsumerStatefulWidget {
  const WrDoneScreen({super.key});

  @override
  ConsumerState<WrDoneScreen> createState() => _WrDoneScreenState();
}

class _WrDoneScreenState extends ConsumerState<WrDoneScreen> {
  bool _integrating = true;
  String? _meaning;
  String? _situationCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _integrate());
  }

  Future<void> _integrate() async {
    final episode = ref.read(episodeFlowProvider);
    _meaning = episode?.draftMeaning;
    _situationCode = episode?.situationCode;
    try {
      await ref.read(episodeFlowProvider.notifier).integrate();
    } catch (e, s) {
      logFlowError('integrate', e, s);
      /* best-effort: nội dung đã được ghi ở từng bước */
    }
    if (mounted) setState(() => _integrating = false);
  }

  /// Số lần đã gặp tình huống này — thuần ghi nhận, không diễn giải.
  ///
  /// Đếm từ Episode chứ không từ `wr_pattern_counts` (v2.0 §4.3): bảng kia cộng
  /// thêm một lần nữa mỗi khi người dùng mở lại một Episode đã khép và xác nhận
  /// Ý nghĩa lần hai, nên "lần thứ N" ở đây sẽ vượt số lần ghi ở màn chi tiết.
  int? _occurrenceCount() {
    final code = _situationCode;
    if (code == null) return null;
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull;
    if (episodes == null) return null;
    return countSituation(episodes, code);
  }

  @override
  Widget build(BuildContext context) {
    final count = _occurrenceCount();

    return WrFlowScaffold(
      eyebrow: 'Đã lưu',
      title: _integrating ? 'Đang lưu lại…' : 'Điều này đã thuộc về bạn.',
      progress: 1,
      primaryLabel: 'Xong',
      busy: _integrating,
      onPrimary: () {
        ref.read(episodeFlowProvider.notifier).leave();
        ref.read(pendingEnergyProvider.notifier).state = null;
        context.go('/home');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_meaning != null && _meaning!.isNotEmpty)
            Text(
              '"${_meaning!}"',
              style: const TextStyle(
                fontSize: 19,
                fontStyle: FontStyle.italic,
                color: WrColors.navy,
                height: 1.5,
              ),
            ),
          if (count != null && count >= 2) ...[
            const SizedBox(height: 28),
            Text(
              'Đây là lần thứ $count bạn ghi lại tình huống này.',
              style: const TextStyle(
                fontSize: 14,
                color: WrColors.muted,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
