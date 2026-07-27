// Màn 3 — các bước phản tư, mỗi lần đúng một câu hỏi.
//
// Pattern hiện tại do hệ thống suy ra từ Human Moment (HXA §3.2), người dùng
// không thấy tên Pattern. Trả lời xong một bước, màn tự nạp câu hỏi kế tiếp;
// hết chuỗi thì sang bước Ý nghĩa.
//
// Riêng bước Name: nếu thư viện tình huống có mục hợp với nhu cầu của khoảnh
// khắc, hiện tối đa sáu thẻ to để chọn — vẫn có thể tự viết.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/logic/wr_experience_state.dart';
import '../../../../core/models/wr_content.dart';
import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../episode_flow_controller.dart';
import '../../wr_providers.dart';
import 'wr_flow_scaffold.dart';

class WrStepScreen extends ConsumerStatefulWidget {
  const WrStepScreen({super.key});

  @override
  ConsumerState<WrStepScreen> createState() => _WrStepScreenState();
}

class _WrStepScreenState extends ConsumerState<WrStepScreen> {
  final _controller = TextEditingController();
  WrSituation? _pickedSituation;
  bool _writing = false; // true = đang tự viết thay vì chọn thẻ
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sáu tình huống hợp với nhu cầu của khoảnh khắc — HXA: gợi ý, không ép.
  List<WrSituation> _situationsFor(ReflectionEpisode episode) {
    final all = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    if (all.isEmpty) return const [];
    final need = episode.humanNeed ?? episode.humanMoment.relatedNeed;
    final matching = all.where((s) => s.humanNeed == need).toList();
    final pool = matching.isNotEmpty ? matching : all;
    return pool.take(6).toList();
  }

  Future<void> _submit(ReflectionPattern pattern) async {
    if (_busy) return;
    final note = _controller.text.trim();
    if (_pickedSituation == null && note.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(episodeFlowProvider.notifier).submitStep(
            pattern: pattern,
            note: note.isEmpty ? null : note,
            situation: _pickedSituation,
          );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _pickedSituation = null;
        _writing = false;
      });
      final remaining = ref.read(episodeFlowProvider.notifier).currentPattern;
      if (remaining == null && mounted) {
        context.push('/wr/flow/meaning');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được. Thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final episode = ref.watch(episodeFlowProvider);
    if (episode == null) {
      // Người dùng vào thẳng route mà không có phiên nào — quay về Home.
      return WrFlowGone(onHome: () => context.go('/home'));
    }

    final remaining = nextPattern(episode.humanMoment, episode.patternsDone);
    if (remaining == null) {
      // Chuỗi phản tư đã xong — không có gì để hỏi thêm, sang bước Ý nghĩa.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('/wr/flow/meaning');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final pattern = remaining;
    final total = patternCount(episode.humanMoment);
    final done = episode.patternsDone.length;

    final showSituations = pattern == ReflectionPattern.name &&
        !_writing &&
        _situationsFor(episode).isNotEmpty;

    final canSubmit =
        _pickedSituation != null || _controller.text.trim().isNotEmpty;

    return WrFlowScaffold(
      eyebrow: 'Bước ${done + 1}/$total',
      title: promptFor(episode.humanMoment, pattern),
      progress: 0.4 + 0.4 * (done / (total == 0 ? 1 : total)),
      onBack: () => context.pop(),
      onClose: _leave,
      primaryLabel: 'Tiếp',
      busy: _busy,
      onPrimary: canSubmit ? () => _submit(pattern) : null,
      secondaryLabel: showSituations ? 'Tự viết' : null,
      onSecondary: showSituations
          ? () => setState(() {
                _writing = true;
                _pickedSituation = null;
              })
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSituations)
            ..._situationTiles(episode)
          else
            _noteField(),
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

  List<Widget> _situationTiles(ReflectionEpisode episode) {
    final situations = _situationsFor(episode);
    return [
      for (final sit in situations) ...[
        if (sit != situations.first) const SizedBox(height: 10),
        WrBigChoiceTile(
          key: Key('wr_situation_${sit.code}'),
          label: sit.text,
          height: 76,
          selected: _pickedSituation?.code == sit.code,
          onTap: () => setState(() => _pickedSituation = sit),
        ),
      ],
    ];
  }

  Widget _noteField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: WrColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        key: const Key('wr_step_note'),
        controller: _controller,
        autofocus: false,
        maxLines: 6,
        minLines: 4,
        style: const TextStyle(
          fontSize: 16,
          color: WrColors.navy,
          height: 1.6,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Viết vài dòng cho riêng bạn…',
          hintStyle: TextStyle(fontSize: 15, color: WrColors.muted),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Future<void> _leave() async {
    await ref.read(episodeFlowProvider.notifier).pause();
    if (mounted) context.go('/home');
  }
}
