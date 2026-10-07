// Bước 4/4 — Mang theo (mockup v47, `screenReflectFlow` i===3).
//
// "Không tạo Goal lớn. Chỉ tạo Tiny Next Step." (HXA §3.8)
//
// Trên cùng là thẻ coral "Điều bạn vừa nhìn thấy" nhắc lại Insight vừa giữ ở
// bước 3, để phép thử bám vào đúng điều đó. Dưới là ba phép thử nhỏ theo luật
// của mockup (`reflectionNextOptions`: ba thẻ riêng cho C2-03/04/05, còn lại
// dùng bộ chung Quan sát · Thử một bước nhỏ · Nói ra điều mình cần — thẻ giữa
// lấy bước thực hành của chính tình huống làm mô tả).
//
// Khách 06/10: "chọn hoặc tự gõ, rồi Lưu". Mockup chạm là lưu luôn; ở đây chạm
// chỉ là chọn, nút Lưu mới ghi, để người dùng còn đổi ý hoặc chuyển sang tự
// viết.
//
// Bản trước lấy bốn câu từ bể `wr_choice_pool` (Hai Lớp v1.6 §VI). v47 thay bằng
// ba thẻ có tiêu đề + mô tả; bảng đó vẫn giữ nguyên trong DB.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/wr_tr.dart';
import '../../../../core/logic/wr_flow_error.dart';
import '../../../../core/logic/wr_reflect_v47.dart';
import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../../../core/theme/wr_text.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/wr_card.dart';
import '../../../../core/widgets/wr_paragraph.dart';
import '../../../../core/widgets/wr_voice_field.dart';
import '../../episode_flow_controller.dart';
import '../../wr_providers.dart';
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

  /// `id` của phép thử đang chọn.
  String? _picked;

  /// true = tự viết thay vì chọn một thẻ.
  bool _writing = false;

  /// Đã đọc lại lựa chọn đã lưu của phiên này chưa (mở lại phiên còn dở).
  Object? _restoredFor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ReflectNextOption> _options(ReflectionEpisode episode) =>
      reflectionNextOptions(
        code: episode.situationCode,
        practice: ref.watch(wrEpisodeStoryProvider)?.practiceAction,
      );

  /// Mở lại phiên đã có bước nhỏ: chọn sẵn thẻ trùng tên, không trùng thì
  /// đưa câu đó vào ô tự viết.
  void _restore(ReflectionEpisode episode, List<ReflectNextOption> options) {
    final key = episode.id ?? identityHashCode(episode);
    if (_restoredFor == key) return;
    _restoredFor = key;
    // Đổi sang phiên khác trong cùng màn thì xoá lựa chọn của phiên trước, kẻo
    // bấm Lưu ghi chữ của phiên cũ vào phiên mới.
    _picked = null;
    _writing = false;
    _controller.clear();
    final action = episode.tinyAction?.trim();
    if (action == null || action.isEmpty) return;
    for (final o in options) {
      if (o.title == action) {
        _picked = o.id;
        return;
      }
    }
    _writing = true;
    _controller.text = action;
  }

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

  @override
  Widget build(BuildContext context) {
    final episode = ref.watch(episodeFlowProvider);
    if (episode == null) {
      return WrFlowGone(onHome: () => context.go('/home'));
    }

    final options = _options(episode);
    _restore(episode, options);

    ReflectNextOption? picked;
    for (final o in options) {
      if (o.id == _picked) picked = o;
    }
    final canSave = _writing
        ? _controller.text.trim().isNotEmpty
        : picked != null;
    final seen = episode.draftMeaning?.trim();

    return WrFlowScaffold(
      eyebrow: reflectStepEyebrow(3),
      title: kTakeAwayTitle,
      subtitle: kTakeAwaySubtitle,
      step: 3,
      onBack: () => context.pop(),
      // Đóng ở bước cuối vẫn giữ lần nhìn lại: sang màn Xong, chỉ không có
      // bước nhỏ nào.
      onClose: () => context.push('/wr/flow/done'),
      primaryLabel: kTakeAwaySave,
      busy: _busy,
      onPrimary: canSave
          ? () => _writing
                ? _save(_controller.text)
                : _save(picked!.title, choice: picked.title)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (seen != null && seen.isNotEmpty) ...[
            Container(
              key: const Key('wr_commit_seen'),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: WrColors.coral.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WrEyebrow(kTakeAwaySeen, color: WrColors.pillCoralText),
                  const SizedBox(height: 6),
                  WrParagraph(
                    '“$seen”',
                    style: WrText.serifQuote(
                      fontSize: 15,
                      color: WrColors.navy,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            WrMentorCard(
              key: Key('wr_choice_$i'),
              selected: !_writing && _picked == options[i].id,
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _picked = options[i].id;
                      _writing = false;
                    }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WrParagraph(
                    options[i].title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                      height: 1.42,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 6),
                  WrParagraph(
                    options[i].desc,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WrColors.text2,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  // Mockup v47 `.rf-mentor-pick`: thẻ đang chọn nói rõ là
                  // đã chọn, và bấm Lưu là giữ lại.
                  if (!_writing && _picked == options[i].id) ...[
                    const SizedBox(height: 10),
                    Text(
                      tr('Đã chọn · lưu lại', 'Picked · save it'),
                      key: Key('wr_choice_picked_$i'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: WrColors.coral,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 9),
          WrRadioOption(
            key: const Key('wr_commit_write_own'),
            label: kTakeAwayWriteOwn,
            custom: true,
            selected: _writing,
            onTap: _busy
                ? null
                : () => setState(() {
                    _writing = true;
                    _picked = null;
                  }),
          ),
          if (_writing) ...[
            const SizedBox(height: 10),
            WrVoiceField(
              fieldKey: const Key('wr_commit_field'),
              controller: _controller,
              hintText: kTakeAwayHint,
              minLines: 3,
              maxLines: 5,
              onChanged: () => setState(() {}),
            ),
          ],
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
}
