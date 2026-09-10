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

import '../../../../core/l10n/wr_tr.dart';
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

  /// true sau khi người dùng bấm **Không đồng ý** ở Lớp 2 (§10.2).
  ///
  /// Cũng là một biến của MÀN: Episode đã chốt xong ở thời điểm này, đây chỉ là
  /// nhịp dừng để nói cho người dùng biết điều họ vừa làm đã được ghi nhận.
  bool _disagreed = false;

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
        setState(() => _error = flowErrorMessage(tr('Không lưu được. Thử lại.', 'Could not save. Try again.'), e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Bấm **Đồng ý** hoặc **Không đồng ý** ở Lớp 2 (§10, khách 10/09).
  ///
  /// Khác nhau đúng một chỗ: câu được lưu.
  ///
  /// - Đồng ý → bản GỘP (chữ người dùng + câu aha), ghi thành Insight.
  /// - Không đồng ý → CHỈ chữ người dùng tự viết, không ghi Insight. Từ chối
  ///   một góc nhìn được đề xuất không có nghĩa là vứt bỏ chữ của chính mình.
  ///
  /// Cả hai đều đi tiếp sang bước Lựa chọn và đều chốt Episode: §10.1 —
  /// "Không bỏ luôn cả lần Reflection."
  Future<void> _confirm({required bool agreed}) async {
    if (_busy) return;
    final text = agreed
        ? _mergedMeaning()
        : (insightStemSentence(_controller.text) ?? '');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(episodeFlowProvider.notifier);
      // Ghi phản hồi TRƯỚC. Ghi sau thì lần bấm nào làm hỏng bước lưu là mất
      // luôn số liệu của chính lần đó — mà đó chính là lần đáng đếm nhất.
      await notifier.recordInsightFeedback(agreed: agreed);
      await notifier.confirmMeaning(text, recordInsight: agreed);
      if (!mounted) return;
      if (!agreed) {
        // §10.2: "Không nên im lặng chuyển sang bước sau như thể không có gì
        // xảy ra, vì người dùng vừa thực hiện một hành động có chủ đích và cần
        // được phản hồi." Nên DỪNG LẠI ở đây một nhịp: đổi màn thành lời xác
        // nhận, rồi để chính họ bấm đi tiếp. Không dùng thanh thông báo trôi
        // qua — nó bay mất trong lúc màn sau đang dựng.
        setState(() => _disagreed = true);
        return;
      }
      _goCommit();
    } catch (e, s) {
      logFlowError('confirmMeaning', e, s);
      if (mounted) setState(() => _error = flowErrorMessage(tr('Không lưu được. Thử lại.', 'Could not save. Try again.'), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Hai Lớp v1.6 §V: MỌI phiên đều đi qua bước Lựa chọn, không riêng Decision và
  // Growth như trước. Lý do đổi: từ v1.6 bước này không còn bắt gõ một bước nhỏ,
  // mà đưa sẵn bốn lựa chọn để chạm (§VI) — chi phí gần như bằng không, trong
  // khi "Reflection luôn mở ra một lựa chọn khác" là đúng với cả sáu khoảnh
  // khắc.
  //
  // Bỏ qua vẫn được: HXA §3.8 giữ nguyên — Reflection kết thúc khi đủ ý nghĩa,
  // không phải khi đủ bước.
  void _goCommit() => context.push('/wr/flow/commit');

  /// Câu aha đang dùng cho phiên này. Không bao giờ rỗng ([ahaFor]).
  String _aha() => ahaFor(ref.read(wrEpisodeStoryProvider)?.ahaMessage);

  /// Nội dung ghi vào `draft_meaning` — bản gộp hai vế.
  String _mergedMeaning() =>
      mergeInsight(stem: _controller.text, aha: _aha());

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
      title: tr('Nếu chọn ra một bài học cho lúc này, bạn sẽ viết gì?', 'If you picked one lesson for right now, what would you write?'),
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
                WrParagraph(
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

          // DƯỚI Ô CHỮ KHÔNG CÒN GÌ NỮA — mục 4.3 và 4.4 (khách 09/09).
          //
          // Chỗ này từng đứng ba khối liên tiếp, và mỗi lần khách xem lại là bỏ
          // thêm một khối:
          //   - "BẠN VỪA VIẾT" đọc lại câu bước Notice — bỏ ở họp 26_1 vì
          //     "đoạn văn bị lặp và dư thừa … gây rối mắt".
          //   - thẻ `selfReflection` "Bạn đang đo sự phát triển bằng điều gì?" —
          //     bỏ ở mục 4.3.
          //   - khối "CHƯA BIẾT VIẾT GÌ?" + 4 thẻ gợi ý — bỏ ở mục 4.4.
          //
          // Cả ba đều là chữ ĐẶT THÊM quanh một ô chữ đã có lời mời rõ ràng ở
          // `subtitle`. Bước này chỉ cần một việc: viết, hoặc bỏ qua.
          //
          // `story.selfReflection` và `kInsightStemSuggestions` vẫn còn trong dữ
          // liệu và trong mã — ngừng hiện, không xoá. Màn Đọc truyện
          // (`wr_story_flow_screen.dart:316`) vẫn dùng `selfReflection`.
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
      title: tr('Thêm một cách tiếp cận khác để bạn tham khảo', 'One more angle, in case it helps'),
      subtitle: kInsightAhaNote,
      progress: reflectProgress(2),
      // Back về Lớp 1, không rời màn: hai lớp là một bước, nên nút lùi phải lùi
      // trong bước trước đã.
      //
      // Đã bấm Không đồng ý thì Episode đã chốt — lùi về Lớp 1 sửa lại chữ lúc
      // này là mời người dùng làm một việc không còn tác dụng.
      onBack: _disagreed ? null : () => setState(() => _showAha = false),
      onClose: _leave,
      // Hai nút thay cho một nút "Tiếp tục" — §10, khách 10/09.
      //
      // Dùng đúng hai chỗ nút sẵn có của khung: "Đồng ý" là lối chính (nút đặc),
      // "Không đồng ý" là lối phụ. Không phải vì lối phụ kém giá trị hơn, mà vì
      // đồng ý là điều xảy ra ở phần lớn phiên, và hai nút đặc cạnh nhau thì
      // không nút nào dẫn mắt.
      primaryLabel: _disagreed ? tr('Tiếp tục', 'Continue') : kInsightAgreeLabel,
      busy: _busy,
      onPrimary: _disagreed ? _goCommit : () => _confirm(agreed: true),
      secondaryLabel: _disagreed ? null : kInsightDisagreeLabel,
      onSecondary: _disagreed ? null : () => _confirm(agreed: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (yours != null) ...[
            Text(
              tr('ĐIỀU BẠN VỪA VIẾT', 'WHAT YOU JUST WROTE'),
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
          // Mục 5.3 đổi nhãn này thành "Đúc kết phổ biến". Đợt 1 sửa đúng hằng
          // `kInsightNormalizingLabel` nhưng màn lại ghi cứng chuỗi cũ, nên câu
          // mới chưa bao giờ lên màn hình. Nay đọc từ hằng.
          Text(
            kInsightNormalizingLabel.toUpperCase(),
            key: const Key('wr_meaning_normalizing_label'),
            style: const TextStyle(
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
              style: TextStyle(
                fontSize: 16.5,
                fontStyle: FontStyle.italic,
                // Đã từ chối thì câu này mờ đi: nó vẫn ở đó để đọc lại, nhưng
                // không còn là điều sắp được lưu.
                color: _disagreed ? WrColors.muted : WrColors.navy,
                height: 1.65,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          // §10.2 — lời xác nhận sau khi bấm Không đồng ý.
          if (_disagreed) ...[
            const SizedBox(height: 18),
            Container(
              key: const Key('wr_meaning_disagree_ack'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: WrColors.navy.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: WrParagraph(
                kInsightDisagreeAck,
                style: TextStyle(
                  fontSize: 15.5,
                  color: WrColors.navy,
                  height: 1.6,
                ),
                textAlign: TextAlign.start,
              ),
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

// ĐÃ BỎ `_StemSuggestion` cùng khối "CHƯA BIẾT VIẾT GÌ?" (mục 4.4, khách 09/09).
