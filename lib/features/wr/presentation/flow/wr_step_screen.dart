// Màn 3 — các bước phản tư, mỗi lần đúng một câu hỏi.
//
// Pattern hiện tại do hệ thống suy ra từ Human Moment (HXA §3.2), người dùng
// không thấy tên Pattern. Trả lời xong một bước, màn tự nạp câu hỏi kế tiếp;
// hết chuỗi thì sang bước Ý nghĩa.
//
// Riêng bước Name: hiện năm thẻ tình huống để chọn — vẫn có thể tự viết.
//
// Năm thẻ đó đã lọc theo cảm xúc check-in và tránh những mã vừa xem gần đây
// (Kiến trúc Dữ liệu v1.6 §III, §IV). Kèm hai lối thoát khỏi bộ lọc: "Xem tình
// huống khác" trộn lại trong cùng cụm, "Xem tất cả" bỏ lọc dùng toàn thư viện.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/logic/wr_experience_state.dart';
import '../../../../core/data/wr_repository.dart';
import '../../../../core/logic/wr_situation_picker.dart';
import '../../../../core/models/checkin.dart';
import '../../../../core/models/wr_content.dart';
import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../episode_flow_controller.dart';
import '../../wr_providers.dart';
import '../../../../core/logic/wr_flow_error.dart';
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

  /// Danh sách tình huống đang hiện. Giữ ở state để "Xem tình huống khác" đổi
  /// được, và để danh sách không bị trộn lại mỗi lần widget dựng lại.
  List<WrSituation>? _choices;

  /// true khi người dùng đã bấm "Xem tất cả, không chỉ theo cảm xúc" (§III).
  bool _ignoreMoodFilter = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Cảm xúc đã check-in hôm nay — nguồn cho bộ lọc §III.
  ///
  /// Đọc từ check-in chứ không từ Episode: Episode chỉ giữ `energy` (3 mức),
  /// mà "căng thẳng" và "mệt mỏi" cùng là năng lượng thấp nhưng lọc theo hai
  /// cụm chiều khác nhau.
  Mood? get _todayMood =>
      ref.read(todayCheckinProvider).valueOrNull?.mood;

  List<String> get _recentIds =>
      ref.read(wrRecentSituationIdsProvider).valueOrNull ?? const [];

  /// Năm tình huống cho bước chọn, đã lọc theo cảm xúc và tránh lặp (§III, §IV).
  ///
  /// Khác bản trước: trước đây lọc theo `humanNeed` của khoảnh khắc rồi lấy 6
  /// mục ĐẦU danh sách, nên người dùng gặp đúng sáu tình huống đó mãi. Giờ lọc
  /// theo cụm chiều của cảm xúc, bỏ những mã vừa xem, rồi lấy ngẫu nhiên 5.
  List<WrSituation> _situationsFor(ReflectionEpisode episode) {
    final all = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    if (all.isEmpty) return const [];
    return _choices ??= pickSituationChoices(
      all: all,
      mood: _ignoreMoodFilter ? null : _todayMood,
      recentIds: _recentIds,
    );
  }

  /// Trộn lại danh sách trong cùng cụm — "Xem tình huống khác" (§III).
  void _reshuffle({required bool dropMoodFilter}) {
    setState(() {
      if (dropMoodFilter) _ignoreMoodFilter = true;
      _choices = null;
      _pickedSituation = null;
    });
  }

  /// Ghi mã tình huống vừa chọn vào lịch sử chống lặp (§4.1).
  Future<void> _rememberChosen(WrSituation sit) async {
    try {
      final updated = rememberSituation(sit.code, _recentIds);
      await ref.read(wrRepositoryProvider).saveRecentSituationIds(updated);
      ref.invalidate(wrRecentSituationIdsProvider);
    } catch (_) {
      /* best-effort: xoay vòng kém đi một nhịp, không mất dữ liệu phản tư */
    }
  }

  Future<void> _submit(ReflectionPattern pattern) async {
    if (_busy) return;
    final note = _controller.text.trim();
    if (_pickedSituation == null && note.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final chosen = _pickedSituation;
    try {
      await ref.read(episodeFlowProvider.notifier).submitStep(
            pattern: pattern,
            note: note.isEmpty ? null : note,
            situation: chosen,
          );

      // §4.1: ghi mã vừa chọn vào lịch sử để lần sau không gợi lại ngay.
      // Best-effort — hỏng bước này chỉ làm xoay vòng kém đi, không được phép
      // chặn một phiên phản tư đã ghi xong.
      if (chosen != null) await _rememberChosen(chosen);

      if (!mounted) return;
      _controller.clear();
      setState(() {
        _pickedSituation = null;
        _writing = false;
        _choices = null;
      });
      final remaining = ref.read(episodeFlowProvider.notifier).currentPattern;
      if (remaining == null && mounted) {
        context.push('/wr/flow/meaning');
      }
    } catch (e, s) {
      logFlowError('recordPattern', e, s);
      if (mounted) setState(() => _error = flowErrorMessage('Không lưu được. Thử lại.', e));
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
            _noteField(promptHintFor(episode.humanMoment, pattern)),
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
    final filtered = !_ignoreMoodFilter && _todayMood != null;

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

      // §III: hai lối thoát khỏi bộ lọc khi năm gợi ý đầu chưa đúng. Không có
      // chúng thì người dùng bị kẹt trong đúng một cụm chiều, và bộ lọc từ chỗ
      // giúp ích thành ra cản đường.
      const SizedBox(height: 16),
      Center(
        child: GestureDetector(
          key: const Key('wr_step_reshuffle'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _reshuffle(dropMoodFilter: false),
          // Mũi tên dùng Icon, không dùng ký tự "→" — font chữ của app không
          // chắc có glyph U+2192.
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Xem tình huống khác',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.teal,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: WrColors.teal),
              ],
            ),
          ),
        ),
      ),
      if (filtered)
        Center(
          child: GestureDetector(
            key: const Key('wr_step_show_all'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _reshuffle(dropMoodFilter: true),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Xem tất cả, không chỉ theo cảm xúc',
                style: TextStyle(fontSize: 12, color: WrColors.muted),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _noteField(String hint) {
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
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 15, color: WrColors.muted),
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
