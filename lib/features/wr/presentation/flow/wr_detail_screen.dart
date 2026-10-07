// Bước 2/4 — Một khoảnh khắc cụ thể (mockup v47, `screenReflectFlow` i===1).
//
// v47 bỏ phần đọc Story và câu Reflection riêng của tình huống. Màn chỉ còn:
// câu hỏi cố định "Điều gì xuất hiện trong khoảnh khắc đó làm bạn suy nghĩ?",
// thẻ "Bạn chọn" nhắc lại tình huống vừa chọn, và MỘT ô kể. Ô này BẮT BUỘC —
// câu kể là nguyên liệu của Insight ở bước sau (`reflectionAhaFor` đọc từ khoá
// trong đó), nên "Tôi đã kể xong" khoá cho tới khi có chữ.
//
// Nhánh "Điều khác" KHÔNG hỏi thêm gì (khách 06/10, "build theo script"):
// trước đây màn này bày thêm ba chip "Gần nhất với điều nào?" để Episode tự
// mô tả vẫn có `situation_code`. Script v47 tối giản câu hỏi nên bỏ; lần nhìn
// lại đó vẫn được đếm vào tổng số lần, chỉ không vào phần "lặp lại".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/wr_tr.dart';
import '../../../../core/logic/wr_flow_error.dart';
import '../../../../core/logic/wr_reflect_v47.dart';
import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/wr_voice_field.dart';
import '../../episode_flow_controller.dart';
import '../../wr_providers.dart';
import 'wr_flow_scaffold.dart';
import '../../../../core/widgets/wr_paragraph.dart';

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

  /// Đi tiếp sang bước Insight. Ô kể bắt buộc (v47, khách 06/10): Insight ở
  /// bước sau được dựng từ chính câu kể này.
  Future<void> _continue() async {
    if (_busy) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(episodeFlowProvider.notifier)
          .submitStep(pattern: ReflectionPattern.explore, note: text);
      if (mounted) context.push('/wr/flow/meaning');
    } catch (e, s) {
      logFlowError('submitDetail', e, s);
      if (mounted) {
        setState(
          () => _error = flowErrorMessage(
            tr('Không lưu được. Thử lại.', 'Could not save. Try again.'),
            e,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Câu tình huống vừa chọn, cho thẻ "Bạn chọn".
  String? _chosenTitle(ReflectionEpisode episode) {
    final code = episode.situationCode;
    if (code != null) {
      final all = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
      for (final s in all) {
        if (s.code == code) return s.text;
      }
    }
    final note = episode.notes[ReflectionPattern.notice.dbValue]?.trim();
    return (note == null || note.isEmpty) ? null : note;
  }

  @override
  Widget build(BuildContext context) {
    final episode = ref.watch(episodeFlowProvider);
    if (episode == null) {
      return WrFlowGone(onHome: () => context.go('/home'));
    }

    if (!_prefilled) {
      final saved = episode.notes[ReflectionPattern.explore.dbValue]?.trim();
      if (saved != null && saved.isNotEmpty) _controller.text = saved;
      _prefilled = true;
    }

    final hasText = _controller.text.trim().isNotEmpty;

    return WrFlowScaffold(
      eyebrow: reflectStepEyebrow(1),
      title: kMomentTitle,
      subtitle: kMomentSubtitle,
      step: 1,
      onBack: () => context.pop(),
      onClose: _leave,
      primaryLabel: kMomentDone,
      busy: _busy,
      onPrimary: hasText ? _continue : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('wr_detail_chosen'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: WrColors.navy.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrEyebrow(tr('Bạn chọn', 'You picked')),
                const SizedBox(height: 7),
                WrParagraph(
                  _chosenTitle(episode) ??
                      tr('Điều bạn vừa chọn', 'What you just picked'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.start,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WrVoiceField(
            fieldKey: const Key('wr_detail_field'),
            controller: _controller,
            hintText: kMomentHint,
            minLines: 5,
            maxLines: 8,
            onChanged: () => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 14.5, color: WrColors.coral),
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
        await ref
            .read(episodeFlowProvider.notifier)
            .submitStep(pattern: ReflectionPattern.explore, note: text);
      } catch (_) {
        /* best-effort */
      }
    }
    await ref.read(episodeFlowProvider.notifier).pause();
    if (mounted) context.go('/home');
  }
}
