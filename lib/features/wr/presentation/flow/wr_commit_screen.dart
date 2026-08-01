// Màn 5 — Lựa chọn (HXA Pattern Commit · Hai Lớp v1.6 §VI).
//
// "Không tạo Goal lớn. Chỉ tạo Tiny Next Step." Bỏ qua được: Reflection kết
// thúc khi đủ ý nghĩa, không phải khi đủ bước (HXA §3.8).
//
// v1.6 §VI đưa vào bể Lựa chọn: bốn lựa chọn có sẵn để CHẠM, thay vì một ô
// trống bắt gõ. Lựa chọn đầu tiên là Practice riêng của tình huống vừa phản tư
// (gắn nhãn "Gợi ý"), cộng ba câu ngẫu nhiên từ bể 8 câu dùng chung. Tình huống
// tự mô tả không có Practice riêng nên lấy đủ bốn câu từ bể.
//
// Ô tự viết vẫn còn, chỉ là không còn bắt buộc: người dùng nào muốn viết thì
// bấm "Tự viết".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/logic/wr_reflect_flow.dart';
import '../../../../core/logic/wr_situation_picker.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../../../core/widgets/wr_voice_field.dart';
import '../../episode_flow_controller.dart';
import '../../mood_content_providers.dart';
import '../../wr_providers.dart';
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
  bool _writing = false; // true = tự viết thay vì chọn từ bể
  String? _error;
  String? _picked;

  /// Bốn lựa chọn của lần vào này. Giữ ở state để không bị trộn lại mỗi lần
  /// widget dựng lại — chọn xong một câu rồi thấy danh sách đổi là rối.
  List<String>? _options;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _buildOptions() {
    final pool = ref.watch(wrChoicePoolProvider).valueOrNull ?? const [];
    if (pool.isEmpty) return const [];
    final practice =
        ref.watch(wrEpisodeStoryProvider)?.practiceAction?.trim();
    return _options ??= pickChoiceOptions(practice: practice, pool: pool);
  }

  /// [choice] chỉ có khi câu này được chạm từ bể Lựa chọn (v1.6 §V · §VI).
  Future<void> _save(String action, {String? choice}) async {
    if (_busy) return;
    final text = action.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(episodeFlowProvider.notifier).commit(text, choice: choice);
      if (mounted) context.push('/wr/flow/done');
    } catch (e, s) {
      logFlowError('commitAction', e, s);
      if (mounted) {
        setState(() =>
            _error = flowErrorMessage('Không lưu được. Thử lại.', e));
      }
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

    final options = _buildOptions();
    // Không đọc được bể thì lùi về ô tự viết — thà bắt gõ còn hơn hiện một màn
    // không có lựa chọn nào.
    final showChoices = options.isNotEmpty && !_writing;
    final hasPractice =
        (ref.watch(wrEpisodeStoryProvider)?.practiceAction?.trim() ?? '')
            .isNotEmpty;

    final canSave = showChoices
        ? _picked != null
        : _controller.text.trim().isNotEmpty;

    return WrFlowScaffold(
      eyebrow: 'Lựa chọn',
      title: 'Nếu hiểu như vậy, bạn sẽ chọn điều gì?',
      subtitle: 'Reflection luôn mở ra một lựa chọn khác.',
      progress: reflectProgress(3),
      onBack: () => context.pop(),
      onClose: () => context.push('/wr/flow/done'),
      primaryLabel: 'Lưu lựa chọn này',
      busy: _busy,
      onPrimary: canSave
          ? () => showChoices
              // Chạm từ bể: câu này vừa là Choice vừa là Tiny Next Step.
              ? _save(_picked!, choice: _picked)
              // Tự viết: có cam kết, nhưng không có lựa chọn nào được chọn.
              : _save(_controller.text)
          : null,
      // Hai lối ra phụ, tuỳ đang ở chế độ nào.
      secondaryLabel: showChoices ? 'Tự viết' : 'Chưa cần bước nào',
      onSecondary: showChoices
          ? () => setState(() {
                _writing = true;
                _picked = null;
              })
          : () => context.push('/wr/flow/done'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showChoices) ...[
            for (final option in options) ...[
              if (option != options.first) const SizedBox(height: 9),
              _ChoiceTile(
                key: Key('wr_choice_${options.indexOf(option)}'),
                label: option,
                // §VI: chỉ lựa chọn ĐẦU TIÊN mang nhãn "Gợi ý", và chỉ khi nó
                // thật sự là Practice của tình huống — không phải một câu chung
                // bốc từ bể.
                suggested: hasPractice && option == options.first,
                selected: _picked == option,
                onTap: () => setState(() => _picked = option),
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                key: const Key('wr_commit_skip'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/wr/flow/done'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Chưa cần bước nào',
                    style: TextStyle(fontSize: 12, color: WrColors.muted),
                  ),
                ),
              ),
            ),
          ] else
            WrVoiceField(
              fieldKey: const Key('wr_commit_field'),
              controller: _controller,
              hintText: 'Mình sẽ thử…',
              minLines: 3,
              maxLines: 4,
              onChanged: () => setState(() {}),
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

/// Một dòng lựa chọn. Nhãn "Gợi ý" chỉ gắn cho Practice của chính tình huống.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.suggested,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? WrColors.coral.withValues(alpha: 0.07)
              : WrColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? WrColors.coral
                : WrColors.navy.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: WrColors.navy,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (suggested) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: WrColors.teal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Gợi ý',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E7A76),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
