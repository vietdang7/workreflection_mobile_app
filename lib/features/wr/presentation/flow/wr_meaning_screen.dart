// Màn 4 — Ý nghĩa.
//
// WXS §4.3 State 4→5 và WIA Invariant 2: hệ thống chỉ đề xuất (Propose), người
// dùng là người duy nhất xác nhận (Confirm).
//
// Màn đọc lại đủ cặp hỏi–đáp đã đi qua. Mỗi câu sửa được ngay tại chỗ
// (WPA Inv.4): đọc lại rồi thấy mình viết cụt thì không phải lùi qua từng màn.

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

class WrMeaningScreen extends ConsumerStatefulWidget {
  const WrMeaningScreen({super.key});

  @override
  ConsumerState<WrMeaningScreen> createState() => _WrMeaningScreenState();
}

class _WrMeaningScreenState extends ConsumerState<WrMeaningScreen> {
  final _controller = TextEditingController();
  bool _prefilled = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final text = _controller.text.trim();
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

  @override
  Widget build(BuildContext context) {
    final episode = ref.watch(episodeFlowProvider);
    if (episode == null) {
      return WrFlowGone(onHome: () => context.go('/home'));
    }

    final story = ref.watch(wrEpisodeStoryProvider);

    // Thư viện tình huống và story nạp bất đồng bộ. Lần dựng đầu tiên chúng
    // thường CHƯA về, nên `story` còn null. Nếu chốt _prefilled ngay lúc đó, ô
    // nhập vĩnh viễn trống và câu Aha không bao giờ xuất hiện.
    final contentReady = !ref.watch(wrSituationsProvider).isLoading &&
        !ref.watch(wrStoriesProvider).isLoading;

    // Thứ tự ưu tiên khi điền sẵn ô nhập:
    //   1. bản nháp CHÍNH người dùng đã lưu — không được đè lên,
    //   2. câu Aha của tình huống đã chọn (v2.0 §V, bước Insight: "chấp nhận
    //      hoặc chỉnh sửa Aha"),
    //   3. câu Aha mặc định của nhánh "Điều khác" (§V).
    //
    // Không nạp lại câu trả lời của bước trước: nó là đáp án cho một câu hỏi
    // khác, đặt vào đây thì người dùng không biết chữ đó ở đâu ra.
    //
    // Aha chỉ là ĐỀ XUẤT — WIA Inv.2: hệ thống propose, người dùng confirm.
    // Ô nhập vẫn sửa được nguyên vẹn, và nút xác nhận vẫn phải bấm.
    if (!_prefilled) {
      final draft = episode.draftMeaning?.trim();
      if (draft != null && draft.isNotEmpty) {
        _controller.text = draft;
        _prefilled = true;
      } else if (episode.situationCode == null || contentReady) {
        // Chỉ chốt khi đã biết chắc: hoặc phiên này không gắn tình huống nào
        // (nhánh "Điều khác"), hoặc thư viện đã nạp xong và ta biết có Aha hay
        // không. Chốt sớm hơn là mất câu gợi ý.
        //
        // [ahaFor] không bao giờ trả chuỗi rỗng: §V bảo bước này luôn mở bằng
        // một câu đã viết sẵn để sửa, không bao giờ mở bằng ô trống.
        _controller.text = ahaFor(story?.ahaMessage);
        _prefilled = true;
      }
    }

    final recap = ref
        .read(episodeFlowProvider.notifier)
        .recap(detailPrompt: detailPrompt(story?.reflectionQuestion));
    final selfReflection = story?.selfReflection?.trim();

    return WrFlowScaffold(
      eyebrow: 'Điều bạn nhận ra',
      title: 'Nếu giữ lại một điều từ lần nhìn lại này, đó là gì?',
      subtitle: recap.isEmpty
          ? 'Chỉ điều bạn thấy đúng với mình.'
          : 'Bấm vào một câu bên dưới nếu bạn muốn viết lại.',
      progress: reflectProgress(2),
      onBack: () => context.pop(),
      onClose: _leave,
      primaryLabel: 'Đây là điều tôi muốn giữ',
      busy: _busy,
      onPrimary: _controller.text.trim().isEmpty ? null : _confirm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // §V bước Insight: đọc câu Self Reflection để đào sâu, TRƯỚC khi
          // nhìn thấy gợi ý Aha. Đảo thứ tự thì Aha trở thành đáp án cho sẵn
          // và câu hỏi mất tác dụng.
          if (selfReflection != null && selfReflection.isNotEmpty) ...[
            Container(
              key: const Key('wr_meaning_self_reflection'),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: WrColors.cream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                selfReflection,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontStyle: FontStyle.italic,
                  color: WrColors.navy,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (recap.isNotEmpty) ...[
            const Text(
              'BẠN VỪA VIẾT',
              key: Key('wr_meaning_recap'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.55,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in recap) ...[
              _RecapItem(
                key: Key('wr_meaning_recap_${item.pattern.dbValue}'),
                item: item,
                onSave: (text) => _saveNote(item.pattern, text),
              ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 10),
          ],
          // §V: câu Aha là ĐỀ XUẤT, người dùng "chấp nhận hoặc chỉnh sửa". Nút
          // mic để việc chỉnh sửa không phải gõ lại cả câu trên điện thoại.
          WrVoiceField(
            fieldKey: const Key('wr_meaning_field'),
            controller: _controller,
            hintText: 'Tôi nhận ra…',
            italic: true,
            minLines: 4,
            maxLines: 6,
            onChanged: () => setState(() {}),
          ),
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

  Future<void> _saveNote(ReflectionPattern pattern, String text) async {
    try {
      await ref
          .read(episodeFlowProvider.notifier)
          .editNote(pattern: pattern, note: text);
    } catch (e, s) {
      logFlowError('editNote', e, s);
      if (mounted) {
        setState(() =>
            _error = flowErrorMessage('Không sửa được câu này. Thử lại.', e));
      }
    }
  }

  Future<void> _leave() async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      // Giữ bản nháp: quay lại vẫn còn nguyên (WXS §4.5).
      try {
        await ref.read(episodeFlowProvider.notifier).saveDraft(text);
      } catch (_) {
        /* best-effort */
      }
    }
    await ref.read(episodeFlowProvider.notifier).pause();
    if (mounted) context.go('/home');
  }
}

/// Một cặp hỏi–đáp đã đi qua: câu hỏi ở trên, chữ của người dùng ở dưới.
///
/// Bấm vào là sửa được ngay tại chỗ. Chỉ đọc thôi thì vô ích: người dùng nhìn
/// lại mới thấy mình vừa trả lời cụt, mà lúc đó lại không làm gì được.
class _RecapItem extends StatefulWidget {
  const _RecapItem({
    super.key,
    required this.item,
    required this.onSave,
  });

  final ReflectionRecapItem item;
  final Future<void> Function(String text) onSave;

  @override
  State<_RecapItem> createState() => _RecapItemState();
}

class _RecapItemState extends State<_RecapItem> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.item.answer);
  final _focus = FocusNode();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _controller.text = widget.item.answer;
    });
    _focus.requestFocus();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    await widget.onSave(text);
    if (mounted) {
      setState(() {
        _saving = false;
        _editing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.prompt,
          style: const TextStyle(
            fontSize: 13,
            color: WrColors.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 4),
        if (_editing) _buildEditor() else _buildAnswer(),
      ],
    );
  }

  Widget _buildAnswer() {
    return InkWell(
      onTap: _startEditing,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.item.answer,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: WrColors.navy,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(
                Icons.edit_outlined,
                size: 15,
                color: WrColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: WrColors.cream,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            key: Key('wr_meaning_recap_field_${widget.item.pattern.dbValue}'),
            controller: _controller,
            focusNode: _focus,
            maxLines: 4,
            minLines: 1,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: WrColors.navy,
              height: 1.45,
            ),
            decoration: const InputDecoration(border: InputBorder.none),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _saving ? null : () => setState(() => _editing = false),
              child: const Text(
                'Bỏ qua',
                style: TextStyle(fontSize: 13, color: WrColors.muted),
              ),
            ),
            TextButton(
              key: Key('wr_meaning_recap_save_${widget.item.pattern.dbValue}'),
              onPressed: _saving ? null : _save,
              child: const Text(
                'Lưu',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WrColors.coral,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
