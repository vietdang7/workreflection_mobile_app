// Bước 1 — Meaning: đọc Story, đọc câu hỏi Reflection, viết chi tiết cụ thể.
// Kiến trúc Dữ liệu v2.0 §V, mockup `screenReflectFlow` i===1.
//
// Đây là chỗ DUY NHẤT trong luồng có ô chữ ở dạng câu hỏi mở, và §V ghi rõ nó
// "không bắt buộc". Bỏ trống vẫn đi tiếp được — nút "Tiếp tục" không bao giờ bị
// khoá. Trước bản 2026-07-31 luồng có tới bốn năm ô chữ như thế này và mọi ô
// đều bắt buộc; xem `wr_reflect_flow.dart` để biết vì sao điều đó làm hỏng cả
// phần thống kê.
//
// Hai nhánh, đúng §V:
//   · Có tình huống → đọc Story (khối in nghiêng) rồi tới câu Reflection riêng
//     của tình huống đó.
//   · "Điều khác"   → bỏ qua Story/Reflection, hỏi thẳng "Chuyện gì cụ thể đã
//     xảy ra?".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/logic/wr_flow_error.dart';
import '../../../../core/logic/wr_reflect_flow.dart';
import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../../../core/widgets/wr_voice_field.dart';
import '../../episode_flow_controller.dart';
import '../../wr_providers.dart';
import 'wr_flow_scaffold.dart';

class WrDetailScreen extends ConsumerStatefulWidget {
  const WrDetailScreen({super.key});

  @override
  ConsumerState<WrDetailScreen> createState() => _WrDetailScreenState();
}

class _WrDetailScreenState extends ConsumerState<WrDetailScreen> {
  final _controller = TextEditingController();
  bool _prefilled = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Đi tiếp sang bước Insight. Ô trống vẫn đi được (§V: không bắt buộc) —
  /// lúc đó không ghi Pattern nào, phiên vẫn ở Exploring và bước sau vẫn hợp lệ.
  Future<void> _continue() async {
    if (_busy) return;
    final text = _controller.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (text.isNotEmpty) {
        await ref.read(episodeFlowProvider.notifier).submitStep(
              pattern: ReflectionPattern.explore,
              note: text,
            );
      }
      if (mounted) context.push('/wr/flow/meaning');
    } catch (e, s) {
      logFlowError('submitDetail', e, s);
      if (mounted) {
        setState(() => _error = flowErrorMessage('Không lưu được. Thử lại.', e));
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

    final story = ref.watch(wrEpisodeStoryProvider);

    // Quay lại màn này thì phải thấy nguyên chữ mình đã viết. Chỉ điền một lần:
    // điền lại ở mỗi lần dựng sẽ nuốt mất ký tự đang gõ dở.
    if (!_prefilled) {
      final saved = episode.notes[ReflectionPattern.explore.dbValue]?.trim();
      if (saved != null && saved.isNotEmpty) _controller.text = saved;
      _prefilled = true;
    }

    final storyText = story?.storyContent.trim();
    final hasStory = episode.situationCode != null &&
        storyText != null &&
        storyText.isNotEmpty;

    return WrFlowScaffold(
      eyebrow: hasStory ? 'Một câu chuyện quen thuộc' : 'Chi tiết cụ thể',
      title: detailPrompt(story?.reflectionQuestion),
      subtitle: kDetailOptionalNote,
      progress: reflectProgress(1),
      onBack: () => context.pop(),
      onClose: _leave,
      // Luôn bật. §V: bước này không bắt buộc, nên khoá nút khi ô trống là biến
      // một bước tuỳ chọn thành bắt buộc.
      primaryLabel: 'Tiếp tục',
      busy: _busy,
      onPrimary: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasStory) ...[
            Container(
              key: const Key('wr_detail_story'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: WrColors.cream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                storyText,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontStyle: FontStyle.italic,
                  color: WrColors.navy,
                  height: 1.7,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Nút mic ngay trong ô (họp khách 2026-07-29): trên điện thoại, bắt
          // gõ là cách chắc chắn nhất để không ai viết gì.
          WrVoiceField(
            fieldKey: const Key('wr_detail_field'),
            controller: _controller,
            hintText: hasStory
                ? 'Viết nếu muốn, bỏ trống cũng không sao…'
                : 'Ví dụ: trong cuộc họp sáng nay…',
            minLines: 4,
            maxLines: 6,
            onChanged: () {},
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
      // Giữ lại chữ đã viết trước khi phiên ngủ (WXS §4.5).
      try {
        await ref.read(episodeFlowProvider.notifier).submitStep(
              pattern: ReflectionPattern.explore,
              note: text,
            );
      } catch (_) {
        /* best-effort */
      }
    }
    await ref.read(episodeFlowProvider.notifier).pause();
    if (mounted) context.go('/home');
  }
}
