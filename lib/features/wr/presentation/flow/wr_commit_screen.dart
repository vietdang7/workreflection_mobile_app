// Màn 5 — Bước nhỏ tiếp theo (HXA Pattern Commit).
//
// "Không tạo Goal lớn. Chỉ tạo Tiny Next Step." Bỏ qua được: Reflection kết
// thúc khi đủ ý nghĩa, không phải khi đủ bước (HXA §3.8).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/wr_colors.dart';
import '../../episode_flow_controller.dart';
import '../../../../core/logic/wr_flow_error.dart';
import 'wr_flow_scaffold.dart';

class WrCommitScreen extends ConsumerStatefulWidget {
  const WrCommitScreen({super.key});

  @override
  ConsumerState<WrCommitScreen> createState() => _WrCommitScreenState();
}

class _WrCommitScreenState extends ConsumerState<WrCommitScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(episodeFlowProvider.notifier).commit(text);
      if (mounted) context.push('/wr/flow/done');
    } catch (e, s) {
      logFlowError('commitAction', e, s);
      if (mounted) setState(() => _error = 'Không lưu được. Thử lại.');
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

    return WrFlowScaffold(
      eyebrow: 'Bước nhỏ',
      title: 'Ngày mai bạn muốn thử điều gì?',
      subtitle: 'Một điều nhỏ thôi, đủ nhỏ để làm được.',
      progress: 0.95,
      onBack: () => context.pop(),
      onClose: () => context.push('/wr/flow/done'),
      primaryLabel: 'Lưu bước này',
      busy: _busy,
      onPrimary: _controller.text.trim().isEmpty ? null : _save,
      secondaryLabel: 'Chưa cần bước nào',
      onSecondary: () => context.push('/wr/flow/done'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: WrColors.cream,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              key: const Key('wr_commit_field'),
              controller: _controller,
              maxLines: 4,
              minLines: 3,
              style: const TextStyle(
                fontSize: 16,
                color: WrColors.navy,
                height: 1.6,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Mình sẽ thử…',
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
}
