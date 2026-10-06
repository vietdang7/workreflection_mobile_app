// Bước 2/4 — Một khoảnh khắc cụ thể (mockup v47, `screenReflectFlow` i===1).
//
// v47 bỏ phần đọc Story và câu Reflection riêng của tình huống. Màn chỉ còn:
// câu hỏi cố định "Điều gì xuất hiện trong khoảnh khắc đó làm bạn suy nghĩ?",
// thẻ "Bạn chọn" nhắc lại tình huống vừa chọn, và MỘT ô kể. Ô này BẮT BUỘC —
// câu kể là nguyên liệu của Insight ở bước sau (`reflectionAhaFor` đọc từ khoá
// trong đó), nên "Tôi đã kể xong" khoá cho tới khi có chữ.
//
// Nhánh "Điều khác" vẫn giữ ba chip "Gần nhất với điều nào?": thiếu nó thì
// Episode khép với `situation_code = NULL` và lần nhìn lại không được đếm vào
// phần lặp lại (xem `wr_reflect_flow.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/wr_repository.dart';
import '../../../../core/l10n/wr_tr.dart';
import '../../../../core/logic/wr_flow_error.dart';
import '../../../../core/logic/wr_reflect_v47.dart';
import '../../../../core/logic/wr_situation_picker.dart';
import '../../../../core/models/wr_content.dart';
import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/wr_voice_field.dart';
import '../../episode_flow_controller.dart';
import '../../wr_providers.dart';
import 'wr_flow_scaffold.dart';
import '../../../../core/widgets/wr_paragraph.dart';

/// Số chip hỏi lại ở nhánh "Điều khác".
///
/// Ba, không phải năm như bước Notice: người dùng vừa từ chối năm chip ở màn
/// trước để tự viết, nên bày lại một danh sách dài đúng bằng cái họ vừa bỏ qua
/// đọc ra như phần mềm không nghe. Ba chip là một câu hỏi phụ, không phải hỏi
/// lại từ đầu.
const int kFallbackSituationCount = 3;

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

  /// Ba chip hỏi lại ở nhánh "Điều khác". Chốt một lần để danh sách không trộn
  /// lại mỗi khi màn dựng lại — người dùng đang cân nhắc thì chữ không được nhảy.
  List<WrSituation>? _fallbackChoices;

  /// Mã người dùng chọn trong ba chip đó. Null = chưa chọn, và bỏ trống vẫn đi
  /// tiếp được: đây là câu hỏi phụ, không phải điều kiện.
  String? _linkedCode;

  WrSituation? get _linked {
    final code = _linkedCode;
    if (code == null) return null;
    for (final s in _fallbackChoices ?? const <WrSituation>[]) {
      if (s.code == code) return s;
    }
    return null;
  }

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
      await _saveLink();
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

  /// Vá `situation_code` cho phiên tự mô tả, nếu người dùng đã chọn một chip.
  ///
  /// VÌ SAO CẦN. Nhánh "Điều khác" truyền `situation = null` xuống
  /// `recordPattern`, nên Episode khép lại KHÔNG có mã tình huống — và
  /// `recentSituationIds` chỉ nhận Episode có mã. Phiên đó vẫn được đếm vào
  /// tổng số lần nhìn lại và vẫn hiện đủ trên Hành trình, nhưng biến mất khỏi
  /// mọi thứ đọc theo tình huống: tình huống lặp lại, nhu cầu chủ đạo, tỉ trọng
  /// ba trụ, gợi ý Practice. Đo trên DB thật 2026-08-22: 14/59 Episode (24%)
  /// đang ở tình trạng này.
  ///
  /// Ghi bằng bước `notice` chứ không phải một cột riêng: đây đúng là câu trả
  /// lời cho bước Notice, chỉ đến muộn hơn một màn. `recordPattern` nhận
  /// [WrSituation] nên nó vá luôn cả `sca_dimension` và `human_need` — thiếu hai
  /// trường đó thì mã có mà tỉ trọng trụ vẫn trống.
  ///
  /// Best-effort: hỏng thì phiên vẫn đi tiếp bình thường, đúng như mọi bước ghi
  /// phụ khác trong luồng.
  Future<void> _saveLink() async {
    final situation = _linked;
    if (situation == null) return;
    try {
      await ref
          .read(episodeFlowProvider.notifier)
          .submitStep(pattern: ReflectionPattern.notice, situation: situation);
      final recent =
          ref.read(wrRecentSituationIdsProvider).valueOrNull ??
          const <String>[];
      await ref
          .read(wrRepositoryProvider)
          .saveRecentSituationIds(rememberSituation(situation.code, recent));
      ref.invalidate(wrRecentSituationIdsProvider);
    } catch (e, s) {
      logFlowError('linkCustomSituation', e, s);
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

    // Nhánh "Điều khác": hỏi thêm ba chip để lần này vẫn được đếm.
    final needsLink = episode.situationCode == null;
    if (needsLink) {
      final all = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
      final recent = ref.watch(wrRecentSituationIdsProvider);
      if (all.isNotEmpty && !recent.isLoading) {
        _fallbackChoices ??= pickSituationChoices(
          all: all,
          mood:
              ref.read(pendingMoodProvider) ??
              ref.read(todayCheckinProvider).valueOrNull?.mood,
          recentIds: recent.valueOrNull ?? const [],
          count: kFallbackSituationCount,
        );
      }
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
          if (needsLink && (_fallbackChoices?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 24),
            WrEyebrow(tr('GẦN NHẤT VỚI ĐIỀU NÀO?', 'CLOSEST TO WHICH ONE?')),
            const SizedBox(height: 6),
            WrParagraph(
              tr(
                'Chọn một điều để lần này được tính vào phần lặp lại của bạn. '
                    'Bỏ qua cũng không sao.',
                'Pick one so this time counts towards what repeats for you. '
                    'Skipping is fine too.',
              ),
              style: const TextStyle(
                fontSize: 13.5,
                color: WrColors.text3,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            for (final s in _fallbackChoices!) ...[
              WrRadioOption(
                key: Key('wr_detail_link_${s.code}'),
                label: s.text,
                selected: _linkedCode == s.code,
                onTap: () => setState(
                  () => _linkedCode = _linkedCode == s.code ? null : s.code,
                ),
              ),
              const SizedBox(height: 8),
            ],
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
    await _saveLink();
    await ref.read(episodeFlowProvider.notifier).pause();
    if (mounted) context.go('/home');
  }
}
