// Màn 4 — Ý nghĩa, HAI LỚP trong một màn (changelog 24/08/2026 §1.2).
//
// WXS §4.3 State 4→5 và WIA Invariant 2: hệ thống chỉ đề xuất (Propose), người
// dùng là người duy nhất xác nhận (Confirm).
//
// ---------------------------------------------------------------------------
// Vì sao màn này đổi hẳn cơ chế
// ---------------------------------------------------------------------------
//
// Bản trước mở màn bằng một ô chữ ĐÃ ĐIỀN SẴN câu aha của tình huống, ở ngôi
// "tôi", và mời người dùng "chấp nhận hoặc chỉnh sửa". Đúng chữ của §V, nhưng
// hệ quả là câu trả lời có mặt trước khi câu hỏi kịp đọng lại — sửa một câu đã
// viết sẵn tốn công hơn bấm qua, nên phần lớn phiên đi qua bước này mà không có
// một chữ nào của chính người dùng.
//
// Từ 24/08 màn chia hai lớp, đi theo thứ tự:
//
//   Lớp 1  ô chữ TRỐNG nối tiếp câu mở dở "Với tôi, điều này xảy ra vì…",
//          kèm lối thoát "Chưa muốn viết, bỏ qua bước này".
//   Lớp 2  mới hiện câu aha, dưới nhãn "Nhiều người khác cũng từng thấy điều
//          này" thay cho khung trích dẫn ngôi "tôi".
//
// Cái được không nằm ở câu chữ mà ở thứ tự: đặt trước, câu aha là đáp án cho
// sẵn; đặt sau, nó là góc nhìn để đối chiếu với điều người dùng vừa tự nghĩ.
//
// Chữ người dùng viết ở Lớp 1 ghi vào `notes['reframe']` — đúng tên Pattern của
// việc đang làm (WXS: Reframe là bước tự đặt lại cách hiểu), và nhờ vậy mở lại
// phiên còn dở thì ô chữ hiện lại nguyên vẹn. `draft_meaning` nhận bản GỘP hai
// vế ở Lớp 2, theo đúng `acceptInsight()` của mockup.
//
// Màn vẫn đọc lại đủ cặp hỏi–đáp đã đi qua, và mỗi câu sửa được ngay tại chỗ
// (WPA Inv.4): đọc lại rồi thấy mình viết cụt thì không phải lùi qua từng màn.
// Khối đó nằm ở Lớp 1 vì nó là bối cảnh để viết, không phải thứ để duyệt lại ở
// phút chót.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/logic/wr_reflect_flow.dart';
import '../../../../core/models/wr_episode.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../../../core/widgets/wr_voice_field.dart';
import '../../episode_flow_controller.dart';
import '../../wr_providers.dart';
import '../../../../core/logic/wr_flow_error.dart';
import 'wr_flow_scaffold.dart';
import '../../../../core/widgets/wr_paragraph.dart';

class WrMeaningScreen extends ConsumerStatefulWidget {
  const WrMeaningScreen({super.key});

  @override
  ConsumerState<WrMeaningScreen> createState() => _WrMeaningScreenState();
}

class _WrMeaningScreenState extends ConsumerState<WrMeaningScreen> {
  /// Ô chữ của Lớp 1 — phần người dùng viết TIẾP sau chữ "vì".
  final _controller = TextEditingController();
  bool _prefilled = false;
  bool _busy = false;
  String? _error;

  /// false = Lớp 1 (mời tự viết), true = Lớp 2 (đã hiện câu aha).
  ///
  /// Một biến của MÀN chứ không phải của Episode: nó chỉ nói người dùng đang
  /// đứng ở nửa nào của bước, không phải một trạng thái nhận thức cần lưu.
  bool _showAha = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Lớp 1 → Lớp 2. [skip] true là người dùng chọn "Chưa muốn viết".
  ///
  /// Ghi chữ vừa viết xuống ngay tại đây thay vì đợi tới lúc xác nhận: rời màn
  /// giữa hai lớp là chuyện thường (đọc xong câu aha rồi đóng app), và chữ của
  /// người dùng không được phụ thuộc vào việc họ đi hết bước.
  Future<void> _revealAha({bool skip = false}) async {
    if (_busy) return;
    if (skip) {
      setState(() {
        _controller.clear();
        _showAha = true;
        _error = null;
      });
      return;
    }
    final stem = _controller.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (stem.isNotEmpty) {
        await ref.read(episodeFlowProvider.notifier).submitStep(
              pattern: ReflectionPattern.reframe,
              note: insightStemSentence(stem),
            );
      }
      if (mounted) setState(() => _showAha = true);
    } catch (e, s) {
      logFlowError('saveInsightStem', e, s);
      if (mounted) {
        setState(() => _error = flowErrorMessage('Không lưu được. Thử lại.', e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final text = _mergedMeaning();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(episodeFlowProvider.notifier);
      await notifier.confirmMeaning(text);
      if (!mounted) return;
      // Hai Lớp v1.6 §V: MỌI phiên đều đi qua bước Lựa chọn, không riêng
      // Decision và Growth như trước. Lý do đổi: từ v1.6 bước này không còn bắt
      // gõ một bước nhỏ, mà đưa sẵn bốn lựa chọn để chạm (§VI) — chi phí gần
      // như bằng không, trong khi "Reflection luôn mở ra một lựa chọn khác" là
      // đúng với cả sáu khoảnh khắc.
      //
      // Bỏ qua vẫn được: HXA §3.8 giữ nguyên — Reflection kết thúc khi đủ ý
      // nghĩa, không phải khi đủ bước.
      context.push('/wr/flow/commit');
    } catch (e, s) {
      logFlowError('confirmMeaning', e, s);
      if (mounted) setState(() => _error = flowErrorMessage('Không lưu được. Thử lại.', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Câu aha đang dùng cho phiên này. Không bao giờ rỗng ([ahaFor]).
  String _aha() => ahaFor(ref.read(wrEpisodeStoryProvider)?.ahaMessage);

  /// Nội dung ghi vào `draft_meaning` — bản gộp hai vế.
  String _mergedMeaning() =>
      mergeInsight(stem: _controller.text, aha: _aha());

  /// Chạm một gợi ý: ĐIỀN vào ô và đặt con trỏ ở cuối để viết tiếp ngay.
  ///
  /// Ghi đè chứ không nối thêm. Nối thêm thì chạm hai gợi ý ra một câu không ai
  /// đọc được, mà người dùng lại không thấy chuyện đó xảy ra vì ô đang cuộn.
  void _useSuggestion(String text) {
    setState(() {
      _controller.text = text;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final episode = ref.watch(episodeFlowProvider);
    if (episode == null) {
      return WrFlowGone(onHome: () => context.go('/home'));
    }

    final story = ref.watch(wrEpisodeStoryProvider);

    // Mở lại một phiên còn dở: ô chữ phải hiện đúng chữ cũ.
    //
    // Chỉ đọc `notes['reframe']` chứ KHÔNG đọc `draft_meaning`: draft là bản đã
    // GỘP với câu aha, đổ nguyên nó vào ô chữ thì người dùng thấy chữ của mình
    // dính liền một câu họ chưa từng viết, ngay sau vế mở dở "…xảy ra vì".
    //
    // Chốt ngay lần dựng đầu, không chờ thư viện story: notes đến cùng Episode.
    if (!_prefilled) {
      _controller.text =
          stemFromNote(episode.notes[ReflectionPattern.reframe.dbValue]);
      // Đã có ý nghĩa chốt từ trước (quay lại bằng nút Back từ màn Lựa chọn)
      // thì mở thẳng ở Lớp 2 — bắt viết lại câu mở dở là hỏi lại một câu đã
      // được trả lời.
      _showAha = episode.draftMeaning?.trim().isNotEmpty ?? false;
      _prefilled = true;
    }

    final recap = ref
        .read(episodeFlowProvider.notifier)
        .recap(detailPrompt: detailPrompt(story?.reflectionQuestion));
    final selfReflection = story?.selfReflection?.trim();

    return _showAha
        ? _buildAhaLayer(context)
        : _buildStemLayer(context, recap, selfReflection);
  }

  // ── Lớp 1 — mời tự hoàn thành câu mở dở ──────────────────────────────────

  Widget _buildStemLayer(
    BuildContext context,
    List<ReflectionRecapItem> recap,
    String? selfReflection,
  ) {
    return WrFlowScaffold(
      eyebrow: kInsightStemEyebrow,
      title: 'Nếu giữ lại một điều từ lần nhìn lại này, đó là gì?',
      subtitle: kInsightStemNote,
      progress: reflectProgress(2),
      onBack: () => context.pop(),
      onClose: _leave,
      primaryLabel: kInsightRevealLabel,
      busy: _busy,
      // KHÔNG khoá khi ô trống: lối thoát ngay dưới đã lo trường hợp đó, và
      // khoá nút chính chỉ làm người dùng tưởng mình buộc phải viết.
      onPrimary: () => _revealAha(),
      secondaryLabel: kInsightSkipLabel,
      onSecondary: () => _revealAha(skip: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ô CHỮ ĐỨNG ĐẦU (họp 26_1: "đẩy ô trắng nhập liệu lên phía trên
          // cùng, sau đó mới đến các câu hỏi gợi ý bên dưới").
          //
          // Vế mở dở nằm ngay trên ô, trong cùng một thẻ: người dùng phải đọc
          // được mình đang viết tiếp cho câu nào.
          Container(
            key: const Key('wr_meaning_stem_card'),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            decoration: BoxDecoration(
              color: WrColors.navy.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WrParagraph(
                  kInsightStemPrompt,
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: WrColors.navy,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 10),
                // Nút mic ngay trong ô: trên điện thoại, bắt gõ là cách chắc
                // chắn nhất để không ai viết gì (họp khách 2026-07-29).
                WrVoiceField(
                  fieldKey: const Key('wr_meaning_field'),
                  controller: _controller,
                  hintText: kInsightStemHint,
                  italic: true,
                  minLines: 3,
                  maxLines: 6,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),

          // KHỐI GỢI Ý, nằm dưới ô chữ.
          //
          // Chỗ này trước đây là khối "BẠN VỪA VIẾT" đọc lại câu hỏi và câu trả
          // lời của bước Notice. Khách bỏ ở họp 26_1: "đoạn văn bị lặp và dư
          // thừa … gây rối mắt và khó hiểu logic" — người dùng vừa trả lời câu
          // đó hai màn trước, thấy lại nguyên văn thì tưởng mình bị hỏi lại.
          const SizedBox(height: 24),
          if (selfReflection != null && selfReflection.isNotEmpty) ...[
            // §V bước Insight: câu Self Reflection để đào sâu, và nó phải được
            // đọc TRƯỚC câu aha. Cấu trúc hai lớp đã bảo đảm điều đó, nên ở đây
            // nó xuống dưới ô chữ được mà không mất thứ tự.
            Container(
              key: const Key('wr_meaning_self_reflection'),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: WrColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: WrColors.line),
              ),
              child: WrParagraph(
                selfReflection,
                style: const TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: WrColors.navy,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            kInsightSuggestionsLabel,
            key: Key('wr_meaning_suggestions'),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.55,
              color: WrColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          for (final s in kInsightStemSuggestions) ...[
            _StemSuggestion(
              key: Key('wr_meaning_suggestion_${kInsightStemSuggestions.indexOf(s)}'),
              text: s,
              onTap: () => _useSuggestion(s),
            ),
            const SizedBox(height: 9),
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

  // ── Lớp 2 — góc nhìn chung, đặt SAU ──────────────────────────────────────

  Widget _buildAhaLayer(BuildContext context) {
    final yours = insightStemSentence(_controller.text);

    return WrFlowScaffold(
      eyebrow: kInsightAhaEyebrow,
      title: 'Nhiều người cũng dừng lại ở đúng chỗ này',
      subtitle: kInsightAhaNote,
      progress: reflectProgress(2),
      // Back về Lớp 1, không rời màn: hai lớp là một bước, nên nút lùi phải lùi
      // trong bước trước đã.
      onBack: () => setState(() => _showAha = false),
      onClose: _leave,
      primaryLabel: 'Tiếp tục',
      busy: _busy,
      onPrimary: _confirm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (yours != null) ...[
            const Text(
              'ĐIỀU BẠN VỪA VIẾT',
              key: Key('wr_meaning_your_words_label'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.55,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              key: const Key('wr_meaning_your_words'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: WrColors.navy.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: WrParagraph(
                yours,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontStyle: FontStyle.italic,
                  color: WrColors.navy,
                  height: 1.6,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(height: 22),
          ],
          const Text(
            'NHIỀU NGƯỜI KHÁC CŨNG TỪNG THẤY ĐIỀU NÀY',
            key: Key('wr_meaning_normalizing_label'),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.55,
              color: WrColors.teal,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('wr_meaning_aha'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: WrColors.teal.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: WrParagraph(
              _aha(),
              style: const TextStyle(
                fontSize: 16.5,
                fontStyle: FontStyle.italic,
                color: WrColors.navy,
                height: 1.65,
              ),
              textAlign: TextAlign.start,
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

  // ĐÃ BỎ `_saveNote` cùng khối "BẠN VỪA VIẾT" (họp 26_1).
  //
  // Nó cho phép sửa tại chỗ câu trả lời của bước trước — WPA Inv.4. Khả năng đó
  // KHÔNG mất: `editNote` vẫn còn ở controller, và người dùng lùi một màn là
  // sửa được chính ô mình đã viết. Cái mất là lối tắt sửa mà không rời màn, đổi
  // lấy việc màn này thôi hỏi lại một câu vừa được trả lời hai màn trước.

  Future<void> _leave() async {
    final stem = _controller.text.trim();
    if (stem.isNotEmpty) {
      // Giữ chữ người dùng đã viết: quay lại vẫn còn nguyên (WXS §4.5).
      //
      // Ghi vào `notes['reframe']`, KHÔNG ghi vào `draft_meaning`. Rời màn giữa
      // chừng không phải là đã xác lập ý nghĩa — đổ bản gộp vào draft lúc này
      // sẽ làm Home hiện "Insight gần nhất" cho một phiên người dùng còn chưa
      // xem xong, và lần quay lại sau ô chữ nhận về cả câu aha họ chưa viết.
      try {
        await ref.read(episodeFlowProvider.notifier).submitStep(
              pattern: ReflectionPattern.reframe,
              note: insightStemSentence(stem),
            );
      } catch (_) {
        /* best-effort */
      }
    }
    await ref.read(episodeFlowProvider.notifier).pause();
    if (mounted) context.go('/home');
  }
}

/// Một vế viết tiếp có thể chạm để điền thẳng vào ô chữ (họp 26_1).
///
/// Dáng nhẹ hơn chip ở bước Notice — viền mảnh, không nền đặc: đây là gợi ý để
/// mượn chữ, không phải một lựa chọn được ghi lại.
class _StemSuggestion extends StatelessWidget {
  const _StemSuggestion({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WrColors.line),
        ),
        child: WrParagraph(
          // Hiện cả vế mở dở để người dùng đọc ra câu hoàn chỉnh mình sắp nhận,
          // chứ không phải một mẩu chữ lơ lửng.
          '$kInsightStemPrefix $text',
          style: const TextStyle(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: WrColors.navy,
            height: 1.5,
          ),
          textAlign: TextAlign.start,
        ),
      ),
    );
  }
}
