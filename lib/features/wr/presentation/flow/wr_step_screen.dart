// Bước 0 — Notice: CHỌN một tình huống (Kiến trúc Dữ liệu v2.0 §V).
//
// Đây là màn đầu tiên sau khi chạm một ô cảm xúc ở Home. Người dùng chạm một
// trong năm chip (đã lọc theo cảm xúc, §III; xoay vòng chống lặp, §IV) hoặc
// "Điều khác, để tôi tự mô tả". Chạm là xong — không có nút xác nhận, đúng
// mockup `pickSituation()`.
//
// ---------------------------------------------------------------------------
// Vì sao màn này thay hẳn chuỗi câu hỏi cũ
// ---------------------------------------------------------------------------
//
// Bản trước: màn này chạy hết chuỗi Pattern của archetype, mỗi Pattern một câu
// hỏi. Bước ĐẦU là `notice` — một ô chữ trống; chip tình huống nằm ở `name`, mà
// `name` chỉ có trong 4 trên 6 archetype. Người check-in "mệt mỏi" (→ Recovery)
// hay chọn "muốn tiến bộ" (→ Growth) đi hết phiên mà không được đưa ra một lựa
// chọn nào, và Episode khép lại với `situation_code = NULL`.
//
// Mà `situation_code` chính là nguyên liệu của recentSituationIds — nguồn duy
// nhất của "Tình huống lặp lại", "Nhu cầu chủ đạo" và gợi ý Practice Theme
// (§4.3). Mất nó là mất cả ba. Xem ghi chú đầy đủ ở `wr_reflect_flow.dart`.
//
// §V chỉ giữ MỘT chỗ được phép viết tay: ô chi tiết không bắt buộc ở bước sau
// (`wr_detail_screen.dart`). Ở đây thì không có ô chữ nào.
//
// ---------------------------------------------------------------------------
// Episode được mở Ở ĐÂY, không phải ở Home
// ---------------------------------------------------------------------------
//
// Home chỉ ghi check-in rồi đẩy sang màn này. Episode chỉ sinh ra khi người
// dùng thật sự chạm một tình huống — ai mở lên rồi thoát ngay không để lại một
// phiên rỗng nào trong `wr_reflection_episodes`, và con số Career Health Check
// (đếm Episode) không bị thổi phồng bởi những lần chỉ ghé qua.
//
// Đi kèm điều đó là một luật ở đầu kia (khách 2026-08-24): mỗi lần chạm ô cảm
// xúc ở Home đều gọi `leave()`, nên màn này LUÔN bắt đầu với controller rỗng và
// luôn mở một Episode mới. Trước đó, một phiên bỏ dở còn nằm trong controller
// sẽ hút lần check-in kế tiếp về bước dở của nó (khối chuyển tiếp cuối
// `build`), và lần ấy không được đếm. Từ nay chỉ hai đường được phép nạp sẵn
// một phiên vào controller: thẻ "Còn dở" ở Home và nút "Hiểu lại chuyện này" ở
// chi tiết Episode — cả hai đều là lời mời quay lại có chủ đích của người dùng.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/wr_repository.dart';
import '../../../../core/logic/wr_flow_error.dart';
import '../../../../core/logic/wr_reflect_flow.dart';
import '../../../../core/logic/wr_situation_picker.dart';
import '../../../../core/models/checkin.dart';
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
  /// Chip đang sáng. Null cho tới khi người dùng chạm.
  String? _selectedCode;
  bool _busy = false;
  String? _error;

  /// Danh sách tình huống đang hiện. Giữ ở state để "Xem tình huống khác" đổi
  /// được, và để danh sách không bị trộn lại mỗi lần widget dựng lại.
  List<WrSituation>? _choices;

  /// true khi người dùng đã bấm "Xem tất cả, không chỉ theo cảm xúc" (§III).
  bool _ignoreMoodFilter = false;

  /// Cảm xúc dùng để lọc chip.
  ///
  /// Ưu tiên cảm xúc vừa chạm ở Home; chưa có thì đọc check-in hôm nay. Đọc
  /// check-in chứ không suy từ `energy` của Episode: "căng thẳng" và "mệt mỏi"
  /// cùng là năng lượng thấp nhưng §III lọc theo hai cụm chiều khác nhau.
  Mood? get _mood =>
      ref.read(pendingMoodProvider) ??
      ref.read(todayCheckinProvider).valueOrNull?.mood;

  List<String> get _recentIds =>
      ref.read(wrRecentSituationIdsProvider).valueOrNull ?? const [];

  /// Năm tình huống cho bước Notice, đã lọc theo cảm xúc và tránh lặp (§III, §IV).
  List<WrSituation> _situationChoices() {
    final all = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    if (all.isEmpty) return const [];

    // Phải ĐỢI lịch sử xoay vòng tải xong mới chốt danh sách. `_choices` chỉ
    // tính đúng một lần (`??=`), nên nếu khung hình đầu chạy khi provider còn
    // đang tải thì `recentIds` là rỗng và danh sách sai đó nằm lại vĩnh viễn:
    // mất ô neo, mất luôn cả cơ chế chống lặp. Chờ một khung hình rẻ hơn nhiều
    // so với việc người dùng không bao giờ chạm lại được điều mình đang gặp.
    final recent = ref.watch(wrRecentSituationIdsProvider);
    if (recent.isLoading) return const [];

    return _choices ??= pickSituationChoices(
      all: all,
      mood: _ignoreMoodFilter ? null : _mood,
      recentIds: recent.valueOrNull ?? const [],
    );
  }

  /// Trộn lại danh sách — "Xem tình huống khác" (§III).
  void _reshuffle({required bool dropMoodFilter}) {
    setState(() {
      if (dropMoodFilter) _ignoreMoodFilter = true;
      _choices = null;
      _selectedCode = null;
    });
  }

  /// Ghi mã tình huống vừa chọn vào lịch sử chống lặp (§4.1).
  Future<void> _rememberChosen(String code) async {
    try {
      final updated = rememberSituation(code, _recentIds);
      await ref.read(wrRepositoryProvider).saveRecentSituationIds(updated);
      ref.invalidate(wrRecentSituationIdsProvider);
    } catch (_) {
      /* best-effort: xoay vòng kém đi một nhịp, không mất dữ liệu phản tư */
    }
  }

  /// Phiên đang thật sự chạy, không phải xác một phiên đã khép.
  ///
  /// `integrated` nghĩa là phiên đã vào Career Memory. Nó vẫn nằm trong
  /// controller khi người dùng rời màn Đóng bằng thanh tab hoặc nút Back của hệ
  /// thống thay vì nút "Xong" — nút đó mới gọi `leave()`. Không lọc ở đây thì
  /// lần check-in kế tiếp bị kéo ngược vào phiên cũ thay vì mở phiên mới.
  ReflectionEpisode? _liveEpisode(ReflectionEpisode? episode) =>
      (episode == null || episode.state == ExperienceState.integrated)
          ? null
          : episode;

  /// Chạm một chip là đã trả lời — mở Episode nếu chưa có, ghi bước Notice, đi
  /// tiếp. [situation] null nghĩa là nhánh "Điều khác".
  Future<void> _pick(WrSituation? situation) async {
    if (_busy) return;
    setState(() {
      _selectedCode = situation?.code ?? 'other';
      _busy = true;
      _error = null;
    });

    try {
      final notifier = ref.read(episodeFlowProvider.notifier);

      // Chưa có Episode nào thì mở tại đây. Archetype suy từ cảm xúc check-in
      // (§9.1: Home chỉ có bốn ô cảm xúc, không có màn chọn khoảnh khắc).
      if (_liveEpisode(ref.read(episodeFlowProvider)) == null) {
        final mood = _mood;
        final energy = ref.read(pendingEnergyProvider) ??
            ref.read(todayCheckinProvider).valueOrNull?.energy;
        if (energy == null || mood == null) {
          // Vào thẳng route mà không qua check-in — không đủ dữ kiện để mở
          // phiên. Đưa về Home thay vì mở một Episode thiếu cảm xúc.
          if (mounted) context.go('/home');
          return;
        }
        await notifier.start(
          energy: energy,
          moment: momentForMood(mood),
          mood: mood,
        );
      }

      await notifier.submitStep(
        pattern: ReflectionPattern.notice,
        note: noticeNoteFor(situation),
        situation: situation,
      );

      if (situation != null) await _rememberChosen(situation.code);

      if (mounted) context.pushReplacement('/wr/flow/detail');
    } catch (e, s) {
      logFlowError('pickSituation', e, s);
      if (mounted) {
        setState(() => _error = flowErrorMessage(
              'Không mở được phiên phản tư. Thử lại.',
              e,
            ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final episode = _liveEpisode(ref.watch(episodeFlowProvider));

    // Phiên đang dở được nạp lại (nút "Tiếp tục" ở Home, hoặc mở lại từ Hành
    // trình) mà đã qua bước Notice rồi thì không hỏi lại tình huống — đi thẳng
    // tới bước còn dở. `isCurrent` là chốt an toàn: chỉ màn đang đứng trên cùng
    // mới được điều hướng, nếu không một bản dựng lại của màn này khi nó đã nằm
    // dưới đáy stack sẽ đè mất màn người dùng đang xem.
    if (episode != null &&
        (episode.situationCode != null ||
            episode.patternsDone.contains(ReflectionPattern.notice))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent != true) return;
        context.pushReplacement('/wr/flow/detail');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final choices = _situationChoices();
    final anchor = anchorSituation(choices, _recentIds);
    final filtered = !_ignoreMoodFilter && _mood != null;
    final moodLabel = filtered ? moodCheckinLabel(_mood!) : null;

    return WrFlowScaffold(
      eyebrow: 'Bắt đầu',
      title: kNoticePrompt,
      subtitle: noticeSubtitle(moodLabel),
      progress: reflectProgress(0),
      onBack: () => context.pop(),
      onClose: _leave,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ô neo — điều gần nhất người dùng đã chọn trong cụm này, luôn có mặt
          // và luôn đứng đầu (xem `pickSituationChoices`). Không gắn nhãn thì
          // nó trông y hệt bốn gợi ý mới, và người dùng không biết rằng chọn
          // lại chính nó mới là cách để "Tình huống lặp lại" đếm lên.
          for (final sit in choices) ...[
            WrBigChoiceTile(
              key: Key('wr_situation_${sit.code}'),
              label: sit.text,
              badge: sit.code == anchor?.code ? kAnchorBadge : null,
              height: sit.code == anchor?.code ? 92 : 76,
              selected: _selectedCode == sit.code,
              onTap: () => _pick(sit),
            ),
            const SizedBox(height: 10),
          ],

          // §III: "Điều khác" LUÔN có mặt và không thuộc cơ chế lọc. Đây là lối
          // duy nhất để tự viết — và cũng là lý do không cần ô chữ nào ở màn
          // này.
          WrBigChoiceTile(
            key: const Key('wr_situation_other'),
            label: kOtherSituationLabel,
            height: 76,
            selected: _selectedCode == 'other',
            onTap: () => _pick(null),
          ),

          // §III: hai lối thoát khỏi bộ lọc khi năm gợi ý đầu chưa đúng. Không
          // có chúng thì người dùng bị kẹt trong đúng một cụm chiều, và bộ lọc
          // từ chỗ giúp ích thành ra cản đường.
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              key: const Key('wr_step_reshuffle'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _reshuffle(dropMoodFilter: false),
              // Mũi tên dùng Icon, không dùng ký tự "→" — font chữ của app
              // không chắc có glyph U+2192.
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flexible: cỡ chữ đã tăng theo brand identity mới, dòng
                    // này chạm mép ở màn hẹp nếu để Text tự do.
                    Flexible(
                      child: Text(
                        'Xem tình huống khác',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: WrColors.navy),
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
                    style: TextStyle(fontSize: 13.5, color: WrColors.muted),
                  ),
                ),
              ),
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
    await ref.read(episodeFlowProvider.notifier).pause();
    if (mounted) context.go('/home');
  }
}
