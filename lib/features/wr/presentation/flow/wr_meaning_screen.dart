// Màn 4 — Ý nghĩa.
//
// WXS §4.3 State 4→5 và WIA Invariant 2: hệ thống chỉ đề xuất (Propose), người
// dùng là người duy nhất xác nhận (Confirm). Vì vậy ô chữ ở đây được nạp sẵn
// bằng chính lời người dùng đã viết, và họ được sửa trước khi xác nhận.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../episode_flow_controller.dart';
import '../../../../core/logic/wr_flow_error.dart';
import 'wr_flow_scaffold.dart';

class WrMeaningScreen extends ConsumerStatefulWidget {
  const WrMeaningScreen({super.key});

  @override
  ConsumerState<WrMeaningScreen> createState() => _WrMeaningScreenState();
}

class _WrMeaningScreenState extends ConsumerState<WrMeaningScreen> {
  final _controller = TextEditingController();
  bool _prefilled = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(episodeFlowProvider.notifier);
      await notifier.confirmMeaning(text);
      if (!mounted) return;
      final moment = ref.read(episodeFlowProvider)?.humanMoment;
      // Chuỗi của Decision và Growth kết thúc bằng Commit — mời đặt bước nhỏ.
      final wantsCommit =
          moment == HumanMoment.decision || moment == HumanMoment.growth;
      context.push(wantsCommit ? '/wr/flow/commit' : '/wr/flow/done');
    } catch (e, s) {
      logFlowError('confirmMeaning', e, s);
      if (mounted) setState(() => _error = flowErrorMessage('Không lưu được. Thử lại.', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final episode = ref.watch(episodeFlowProvider);
    if (episode == null) {
      return WrFlowGone(onHome: () => context.go('/home'));
    }

    // Chỉ khôi phục bản nháp CHÍNH người dùng đã lưu. Không nạp lại câu trả
    // lời của bước trước: nó là đáp án cho một câu hỏi khác, đặt vào đây thì
    // người dùng không biết chữ đó ở đâu ra.
    if (!_prefilled) {
      _controller.text = episode.draftMeaning ?? '';
      _prefilled = true;
    }

    final recap = ref.read(episodeFlowProvider.notifier).recap();

    return WrFlowScaffold(
      eyebrow: 'Điều bạn nhận ra',
      title: 'Nếu giữ lại một điều từ lần nhìn lại này, đó là gì?',
      subtitle: 'Chỉ điều bạn thấy đúng với mình. Sửa lại thoải mái.',
      progress: 0.85,
      onBack: () => context.pop(),
      onClose: _leave,
      primaryLabel: 'Đây là điều tôi muốn giữ',
      busy: _busy,
      onPrimary: _controller.text.trim().isEmpty ? null : _confirm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recap.isNotEmpty) ...[
            const Text(
              'BẠN VỪA VIẾT',
              key: Key('wr_meaning_recap'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.55,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in recap) ...[
              _RecapItem(prompt: item.prompt, answer: item.answer),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: WrColors.cream,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              key: const Key('wr_meaning_field'),
              controller: _controller,
              maxLines: 6,
              minLines: 4,
              style: const TextStyle(
                fontSize: 17,
                color: WrColors.navy,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Tôi nhận ra…',
                hintStyle: TextStyle(fontSize: 15, color: WrColors.muted),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
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

  Future<void> _leave() async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      // Giữ bản nháp: quay lại vẫn còn nguyên (WXS §4.5).
      try {
        await ref.read(episodeFlowProvider.notifier).saveDraft(text);
      } catch (_) {
        /* best-effort */
      }
    }
    await ref.read(episodeFlowProvider.notifier).pause();
    if (mounted) context.go('/home');
  }
}

/// Một cặp hỏi–đáp đã đi qua: câu hỏi ở trên, chữ của người dùng ở dưới.
///
/// Đọc là biết ngay chữ mình viết thuộc về câu nào — trước đây chỉ hiện mỗi
/// câu trả lời nên nó lơ lửng, không rõ đang nói về chuyện gì.
class _RecapItem extends StatelessWidget {
  const _RecapItem({required this.prompt, required this.answer});

  final String prompt;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prompt,
          style: const TextStyle(
            fontSize: 13,
            color: WrColors.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: WrColors.navy,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
