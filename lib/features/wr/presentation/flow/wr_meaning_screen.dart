// Bước 3/4 — Nhìn lại cùng nhau (mockup v47, `screenReflectFlow` i===2).
//
// WXS §4.3 State 4→5 và WIA Invariant 2: hệ thống chỉ đề xuất (Propose), người
// dùng là người duy nhất xác nhận (Confirm).
//
// Khách 06/10: bấm "Tôi đã kể xong" là thấy Insight NGAY. Bản 24/08 chen một lớp
// ô trống "Với tôi, điều này…" trước câu aha; v47 bỏ lớp đó. Màn giờ có hai
// trạng thái:
//
//   Insight   thẻ "Có một điều hiện lên trong câu chuyện của bạn" với câu dựng
//             từ tình huống + câu kể (`reflectionAhaFor`).
//             · "Ừ, tôi cũng thấy vậy"     → lưu câu đó làm Insight.
//   Nói lại   "Vậy điều gì gần với bạn hơn?" + ô "Thật ra, điều chạm vào tôi
//             là..." → "Giữ lại cách hiểu của tôi" → lưu CÂU NGƯỜI DÙNG làm
//             Insight.
//
// Khác bản trước ở nhánh không đồng ý: trước đây bấm "Không đồng ý" thì KHÔNG
// có Insight nào được ghi. Khách muốn cách hiểu người dùng tự viết lại mới là
// thứ được giữ, nên giờ nó đi vào `wr_reflection_insights` như mọi Insight.
// Phản hồi đồng ý / không đồng ý vẫn ghi riêng vào `wr_insight_feedback`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/wr_tr.dart';
import '../../../../core/logic/wr_flow_error.dart';
import '../../../../core/logic/wr_reflect_v47.dart';
import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../../../core/theme/wr_text.dart';
import '../../../../core/widgets/wr_paragraph.dart';
import '../../../../core/widgets/wr_voice_field.dart';
import '../../episode_flow_controller.dart';
import '../../wr_providers.dart';
import 'wr_flow_scaffold.dart';

class WrMeaningScreen extends ConsumerStatefulWidget {
  const WrMeaningScreen({super.key});

  @override
  ConsumerState<WrMeaningScreen> createState() => _WrMeaningScreenState();
}

class _WrMeaningScreenState extends ConsumerState<WrMeaningScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Đang ở trạng thái "Chưa đúng, để tôi nói lại".
  bool _retelling = false;

  /// Đã đọc lại câu nói lại còn dở (`notes['reframe']`) chưa.
  bool _prefilled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Câu Insight hệ thống đề xuất cho phiên này.
  String _insight(ReflectionEpisode episode) {
    final code = episode.situationCode;
    String? title;
    if (code != null) {
      final all = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
      for (final s in all) {
        if (s.code == code) title = s.text;
      }
    }
    title ??= episode.notes[ReflectionPattern.notice.dbValue];
    return reflectionAhaFor(
      code: code,
      title: title,
      detail: episode.notes[ReflectionPattern.explore.dbValue],
      situationAha: ref.watch(wrEpisodeStoryProvider)?.ahaMessage,
    );
  }

  /// Ghi phản hồi + Insight rồi sang bước 4.
  Future<void> _keep(String insight, {required bool agreed}) async {
    if (_busy) return;
    final text = insight.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(episodeFlowProvider.notifier);
      // Quay lại bấm lần nữa sau khi đã giữ: không ghi thêm một dòng phản hồi.
      final settled =
          ref.read(episodeFlowProvider)?.state.meaningAlreadySettled ?? false;
      if (!settled) await notifier.recordInsightFeedback(agreed: agreed);
      await notifier.confirmMeaning(text);
      if (mounted) context.push('/wr/flow/commit');
    } catch (e, s) {
      logFlowError('confirmMeaning', e, s);
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
    if (!_prefilled) {
      _prefilled = true;
      // Rời màn giữa lúc nói lại thì câu đó nằm ở `notes['reframe']`; mở lại
      // phiên chưa giữ ý nghĩa nào thì đưa người dùng về đúng chỗ đang viết.
      final reframe = episode.notes[ReflectionPattern.reframe.dbValue]?.trim();
      final saved = episode.draftMeaning?.trim();
      if (reframe != null &&
          reframe.isNotEmpty &&
          (saved == null || saved.isEmpty)) {
        _controller.text = reframe;
        _retelling = true;
      }
    }
    return _retelling ? _retellView() : _insightView(episode);
  }

  Widget _insightView(ReflectionEpisode episode) {
    // Phiên mở lại sau khi đã xác lập ý nghĩa: hiện đúng câu đã giữ.
    final saved = episode.draftMeaning?.trim();
    final hasSaved = saved != null && saved.isNotEmpty;
    // Câu Insight dựa trên câu chuyện của tình huống. Thư viện còn đang tải
    // thì CHỜ: tính sớm là rơi vào câu chung của nhánh "Điều khác", và người
    // dùng bấm "Ừ, tôi cũng thấy vậy" ngay lúc đó là giữ nhầm câu chung.
    final loading =
        !hasSaved &&
        episode.situationCode != null &&
        (ref.watch(wrSituationsProvider).isLoading ||
            ref.watch(wrStoriesProvider).isLoading);
    final insight = hasSaved ? saved : _insight(episode);
    return WrFlowScaffold(
      eyebrow: reflectStepEyebrow(2),
      title: kInsightTitle,
      step: 2,
      onBack: () => context.pop(),
      onClose: _leave,
      primaryLabel: kInsightAgree,
      busy: _busy,
      onPrimary: loading ? null : () => _keep(insight, agreed: true),
      secondaryLabel: kInsightRetell,
      onSecondary: loading
          ? null
          : () => setState(() {
              _retelling = true;
              _error = null;
            }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading)
            const Padding(
              key: Key('wr_meaning_loading'),
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Container(
              key: const Key('wr_meaning_aha'),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: WrColors.teal.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
              ),
              child: WrParagraph(
                '“$insight”',
                style: WrText.serifQuote(
                  fontSize: 16.5,
                  color: WrColors.navy,
                  height: 1.72,
                ),
                textAlign: TextAlign.start,
              ),
            ),
          const SizedBox(height: 16),
          WrParagraph(
            kInsightNote,
            key: const Key('wr_meaning_note'),
            style: const TextStyle(
              fontSize: 14,
              color: WrColors.text2,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          ..._errorText(),
        ],
      ),
    );
  }

  Widget _retellView() {
    final hasText = _controller.text.trim().isNotEmpty;
    return WrFlowScaffold(
      eyebrow: kCorrectionEyebrow,
      title: kCorrectionTitle,
      subtitle: kCorrectionNote,
      step: 2,
      onBack: () => setState(() => _retelling = false),
      onClose: _leave,
      primaryLabel: kCorrectionKeep,
      busy: _busy,
      onPrimary: hasText ? () => _keep(_controller.text, agreed: false) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WrVoiceField(
            fieldKey: const Key('wr_meaning_field'),
            controller: _controller,
            hintText: kCorrectionHint,
            italic: true,
            minLines: 5,
            maxLines: 8,
            onChanged: () => setState(() {}),
          ),
          ..._errorText(),
        ],
      ),
    );
  }

  List<Widget> _errorText() => [
    if (_error != null) ...[
      const SizedBox(height: 16),
      Text(
        _error!,
        style: const TextStyle(fontSize: 14.5, color: WrColors.coral),
      ),
    ],
  ];

  Future<void> _leave() async {
    // Câu đang viết lại thì giữ ở `notes['reframe']` để quay lại còn nguyên.
    // KHÔNG ghi vào `draft_meaning`: rời giữa chừng chưa phải đã xác lập ý
    // nghĩa, và Home sẽ hiện "Insight gần nhất" cho một phiên chưa xong.
    final text = _controller.text.trim();
    if (_retelling && text.isNotEmpty) {
      try {
        await ref
            .read(episodeFlowProvider.notifier)
            .submitStep(pattern: ReflectionPattern.reframe, note: text);
      } catch (_) {
        /* best-effort */
      }
    }
    await ref.read(episodeFlowProvider.notifier).pause();
    if (mounted) context.go('/home');
  }
}
