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

import '../../../../core/data/wr_repository.dart';
import '../../../../core/logic/wr_flow_error.dart';
import '../../../../core/logic/wr_reflect_flow.dart';
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
      await _saveLink();
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
      await ref.read(episodeFlowProvider.notifier).submitStep(
            pattern: ReflectionPattern.notice,
            situation: situation,
          );
      final recent =
          ref.read(wrRecentSituationIdsProvider).valueOrNull ?? const <String>[];
      await ref
          .read(wrRepositoryProvider)
          .saveRecentSituationIds(rememberSituation(situation.code, recent));
      ref.invalidate(wrRecentSituationIdsProvider);
    } catch (e, s) {
      logFlowError('linkCustomSituation', e, s);
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

    // Nhánh "Điều khác": phiên chưa có mã nào, nên hỏi thêm một chạm ở cuối màn.
    final needsLink = episode.situationCode == null;
    if (needsLink) {
      final all = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
      final recent = ref.watch(wrRecentSituationIdsProvider);
      // Chỉ chốt danh sách khi dữ liệu đã về. Chốt sớm trên tập rỗng thì màn
      // này vĩnh viễn không có chip nào — đúng cái bẫy đã mắc ở bước Notice.
      if (all.isNotEmpty && !recent.isLoading) {
        _fallbackChoices ??= pickSituationChoices(
          all: all,
          mood: ref.read(pendingMoodProvider) ??
              ref.read(todayCheckinProvider).valueOrNull?.mood,
          recentIds: recent.valueOrNull ?? const [],
          count: kFallbackSituationCount,
        );
      }
    }

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
                color: WrColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: WrColors.line),
              ),
              child: WrParagraph(
                storyText,
                style: const TextStyle(
                  fontSize: 16,
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
          if (needsLink && (_fallbackChoices?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 24),
            const WrEyebrow('GẦN NHẤT VỚI ĐIỀU NÀO?'),
            const SizedBox(height: 6),
            const WrParagraph(
              // Nói thẳng chọn để làm gì. Một câu hỏi không có lý do thì đọc ra
              // như phần mềm đang ép phân loại điều vừa kể.
              'Chọn một điều để lần này được tính vào phần lặp lại của bạn. '
              'Bỏ qua cũng không sao.',
              style: TextStyle(
                fontSize: 13.5,
                color: WrColors.text3,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            for (final s in _fallbackChoices!) ...[
              _LinkChip(
                key: Key('wr_detail_link_${s.code}'),
                label: s.text,
                selected: _linkedCode == s.code,
                // Chạm lần nữa là bỏ chọn — người dùng đổi ý không cần rời màn.
                onTap: () => setState(
                  () => _linkedCode = _linkedCode == s.code ? null : s.code,
                ),
              ),
              const SizedBox(height: 10),
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
        await ref.read(episodeFlowProvider.notifier).submitStep(
              pattern: ReflectionPattern.explore,
              note: text,
            );
      } catch (_) {
        /* best-effort */
      }
    }
    await _saveLink();
    await ref.read(episodeFlowProvider.notifier).pause();
    if (mounted) context.go('/home');
  }
}

/// Chip "gần nhất với điều nào" — cùng hình thức với chip ở bước Notice, vì nó
/// trả lời cùng một câu hỏi.
class _LinkChip extends StatelessWidget {
  const _LinkChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? WrColors.coral.withValues(alpha: 0.07) : WrColors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? WrColors.coral : WrColors.line,
            width: 1.5,
          ),
        ),
        child: WrParagraph(
          label,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: WrColors.navy,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
