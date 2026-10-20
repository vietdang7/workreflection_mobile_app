// Trò chuyện với trợ lý phản chiếu — AI Chatbox System Prompt v1.0.
//
// ---------------------------------------------------------------------------
// LỊCH SỬ MÀN NÀY
//
// Họp khách 2026-07-29: "Bạn muốn hỏi điều gì đó, bạn ghi vô đây rồi bạn gửi
// thôi… Nó không phải theo dạng là nói chuyện qua nói chuyện lại, cái đó chị
// nghĩ sẽ chờ sau." Nên bản đầu là một ô, một nút gửi, và câu trả lời tới qua
// email do người vận hành soạn.
//
// "Sau" là bây giờ. Màn này thành khung chat thật, AI trả lời tại chỗ.
//
// Những câu đã gửi theo cách cũ KHÔNG mất: bảng `wr_career_questions` giữ
// nguyên, đọc lại được qua menu góc trên. Người ta đã được hứa một câu trả lời
// qua email, xoá lối vào phần đó đi là nuốt lời hứa đó.
//
// ---------------------------------------------------------------------------
// RANH GIỚI
//
// Màn này KHÔNG tự ghi gì vào Career Memory. Mục 2 của system prompt: trợ lý
// mời người dùng vào luồng Reflection có cấu trúc, chứ không tóm tắt và lưu
// thay họ. Ở đây điều đó có nghĩa là màn chat không có đường ghi dữ liệu nào
// ngoài chính bảng `wr_chat_messages`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_chat_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_chat_starters.dart';
import '../../../core/logic/wr_chat_offer.dart' show calmMoodFor;
import '../../../core/models/wr_chat.dart';
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_app_background.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_ai_consent_sheet.dart';
import '../../../core/widgets/wr_voice_field.dart';
import '../chat_providers.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../../../core/widgets/wr_title_text.dart';
import 'package:workreflection_mobile/core/widgets/wr_back_circle.dart';

/// Câu người dùng thấy cho những câu hỏi gửi theo cách cũ, chưa được trả lời.
///
/// Giữ nguyên hằng số và nguyên văn: nó là lời hứa đã đưa ra với những người đã
/// gửi câu hỏi trước khi có màn chat này.
String get kAskPendingMessage => tr(
  'Hệ thống đã ghi nhận câu hỏi của bạn. Phần gợi ý chi tiết sẽ được gửi vào '
      'email của bạn.',
  'We have recorded your question. The detailed suggestions will be sent to '
      'your email.',
);

/// Gợi ý mở lời cho màn trống, bản DỰ PHÒNG.
///
/// ⚠ ĐÂY KHÔNG CÒN LÀ THỨ NGƯỜI DÙNG THẤY trong đa số trường hợp. Từ 2026-08-04
/// gợi ý được dựng từ chính những tình huống họ hay chọn khi nhìn lại, qua
/// [wrChatStartersProvider]. Danh sách này chỉ còn là phần bù khi họ chưa chọn
/// tình huống nào, hoặc khi hai nguồn dữ liệu kia còn đang tải.
///
/// Giữ tên cũ vì đây là điểm neo của test màn trống. Nội dung nằm ở
/// `wr_chat_starters.dart` cùng chỗ với phần logic, để không có hai danh sách
/// dự phòng ở hai nơi rồi trôi khỏi nhau.
List<String> get kChatStarters => kDefaultChatStarters;

class WrAskScreen extends ConsumerStatefulWidget {
  const WrAskScreen({super.key});

  @override
  ConsumerState<WrAskScreen> createState() => _WrAskScreenState();
}

class _WrAskScreenState extends ConsumerState<WrAskScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Xin phép TRƯỚC khi xoá ô nhập. Xoá trước rồi mới hỏi, mà người dùng bấm
    // "để sau", thì câu họ vừa gõ biến mất không lý do.
    if (!await ensureAiConsent(context, ref)) return;

    _controller.clear();
    setState(() {});
    _scrollToEnd();
    await ref.read(wrChatControllerProvider.notifier).send(text);
    _scrollToEnd();
  }

  /// Cuộn xuống lượt mới nhất.
  ///
  /// Hoãn tới sau khung hình kế tiếp: gọi ngay thì danh sách chưa dựng xong
  /// dòng vừa thêm, và `maxScrollExtent` vẫn là giá trị cũ.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wrChatControllerProvider);

    // Có lượt mới thì cuộn theo, kể cả lượt đến từ lần tải lịch sử đầu tiên.
    ref.listen(wrChatControllerProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) != next.messages.length) _scrollToEnd();
    });

    return WrAppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: WrColors.white,
          elevation: 0,
          leading: IconButton(
            key: const Key('wr_detail_back'),
            tooltip: tr('Quay lại', 'Back'),
            icon: const WrNavCircle.back(),
            color: WrColors.navy,
            onPressed: () => context.pop(),
          ),
          title: Text(
            wrKeepCompounds(tr('Trò chuyện', 'Chat')),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
            ),
          ),
          actions: [
            // Nút cuộc mới đứng RIÊNG ngoài menu, không nằm trong ba chấm: đây là
            // hành động thường xuyên thứ hai ở màn này, sau việc gõ và gửi.
            IconButton(
              key: const Key('wr_chat_new'),
              tooltip: tr('Cuộc trò chuyện mới', 'New conversation'),
              icon: const Icon(Icons.add_comment_outlined, size: 20),
              color: WrColors.navy,
              onPressed: state.sending
                  ? null
                  : () {
                      ref.read(wrChatControllerProvider.notifier).startNew();
                      _controller.clear();
                      setState(() {});
                    },
            ),
            PopupMenuButton<String>(
              key: const Key('wr_chat_menu'),
              icon: const Icon(Icons.more_horiz, color: WrColors.navy),
              onSelected: (value) {
                if (value == 'conversations') _showConversations();
                if (value == 'history') _showOldQuestions();
                if (value == 'clear') _confirmClear();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'conversations',
                  child: Text(
                    wrKeepCompounds(tr('Lịch sử trò chuyện', 'Chat history')),
                  ),
                ),
                PopupMenuItem(
                  value: 'history',
                  child: Text(
                    wrKeepCompounds(
                      tr(
                        'Câu hỏi đã gửi trước đây',
                        'Questions you sent before',
                      ),
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Text(
                    wrKeepCompounds(
                      tr('Xoá cuộc trò chuyện này', 'Delete this conversation'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: state.loading
                    ? const Center(
                        key: Key('wr_chat_loading'),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        ),
                      )
                    : state.isEmpty && !state.sending
                    ? _EmptyState(
                        starters: ref.watch(wrChatStartersProvider),
                        onPick: (text) {
                          _controller.text = text;
                          setState(() {});
                        },
                      )
                    : ListView(
                        key: const Key('wr_chat_list'),
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        children: [
                          for (final (i, m) in state.messages.indexed)
                            _Bubble(
                              message: m,
                              lastUserText: _lastUserTextBefore(
                                state.messages,
                                i,
                              ),
                            ),
                          if (state.sending) const _TypingBubble(),
                        ],
                      ),
              ),
              if (state.error != null)
                _ErrorBar(
                  message: state.error!,
                  quotaExhausted: state.quotaExhausted,
                ),
              _Composer(
                controller: _controller,
                sending: state.sending,
                remaining: state.isPremium ? null : state.remaining,
                onChanged: () {
                  ref.read(wrChatControllerProvider.notifier).dismissError();
                  setState(() {});
                },
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Danh sách cuộc trò chuyện đã có.
  void _showConversations() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WrColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ConversationsSheet(
        currentId: ref.read(wrChatControllerProvider).conversationId,
        onPick: (id) {
          Navigator.of(context).pop();
          ref.read(wrChatControllerProvider.notifier).open(id);
          _controller.clear();
          setState(() {});
        },
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WrColors.white,
        title: Text(
          wrKeepCompounds(
            tr('Xoá cuộc trò chuyện?', 'Delete this conversation?'),
          ),
        ),
        content: WrParagraph(
          tr(
            'Toàn bộ lượt trò chuyện sẽ bị xoá và không lấy lại được. '
                'Những gì bạn đã ghi trong Hành trình không bị ảnh hưởng.',
            'Every turn in it will be deleted and cannot be recovered. '
                'Nothing you saved in your Journey is affected.',
          ),
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(wrKeepCompounds(tr('Giữ lại', 'Keep it'))),
          ),
          TextButton(
            key: const Key('wr_chat_clear_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              wrKeepCompounds(tr('Xoá', 'Delete')),
              style: TextStyle(color: WrColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(wrChatControllerProvider.notifier).clear();
    }
  }

  /// Những câu đã gửi qua ô hỏi cũ, mở trong một tấm trượt.
  ///
  /// Không phải một màn riêng có đường dẫn: đây là phần lưu trữ để đọc lại, số
  /// người mở nó sẽ giảm dần về không khi những câu cuối cùng đã được trả lời.
  void _showOldQuestions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WrColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _OldQuestionsSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Bong bóng
// ---------------------------------------------------------------------------

/// Lời người dùng gần nhất đứng trước lượt thứ [index].
String? _lastUserTextBefore(List<WrChatMessage> messages, int index) {
  for (var i = index - 1; i >= 0; i--) {
    if (messages[i].role.isUser) return messages[i].content;
  }
  return null;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.lastUserText});

  final WrChatMessage message;

  /// Lời người dùng ngay trước lượt này, để nút dịu lại đoán cảm xúc khi hôm
  /// nay chưa check-in.
  final String? lastUserText;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role.isUser;
    final action = message.action;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bubble(context, isUser),
        // Nút mở đúng việc trợ lý vừa mời. Mục 5 và bước 3 của mục 8 đều yêu cầu
        // lời mời này; trước 2026-08-03 trợ lý nói được nhưng không có đường đi
        // tới, nên người dùng gật đầu xong phải tự thoát ra tự tìm.
        if (!isUser && action != null)
          _ActionButton(action: action, lastUserText: lastUserText),
        // Chính sách Nội dung do AI tạo của Google Play: người dùng phải báo cáo
        // được câu trả lời xúc phạm ngay trong app.
        if (!isUser && !message.pending) _ReportLink(message: message),
      ],
    );
  }

  Widget _bubble(BuildContext context, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              key: Key(isUser ? 'wr_chat_user_bubble' : 'wr_chat_ai_bubble'),
              constraints: BoxConstraints(
                // Chừa lề bên đối diện để mắt luôn thấy được bên nào đang nói,
                // kể cả với một đoạn dài.
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? WrColors.navy : WrColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 18),
                ),
                border: Border.all(color: WrColors.line),
              ),
              child: WrParagraph(
                message.content,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.65,
                  color: isUser ? WrColors.white : WrColors.dark,
                ),
                // Bong bóng chỉ rộng 78% màn: căn đều ở đây giãn chữ thành khe
                // hở, rõ nhất ở tiếng Anh với cỡ chữ hệ thống lớn ("question
                // feel safe" mỗi từ cách nhau cả ô, máy thật 07/10).
                textAlign: TextAlign.start,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liên kết nhỏ "Báo cáo" dưới mỗi câu trả lời của trợ lý.
class _ReportLink extends StatelessWidget {
  const _ReportLink({required this.message});

  final WrChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextButton.icon(
        key: const Key('wr_chat_report'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: WrColors.white,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (_) => _ReportSheet(message: message),
        ),
        icon: const Icon(Icons.outlined_flag, size: 16),
        label: Text(
          wrKeepCompounds(tr('Báo cáo', 'Report')),
          style: const TextStyle(fontSize: 14),
        ),
        style: TextButton.styleFrom(
          foregroundColor: WrColors.text3,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// Tấm trượt chọn lý do báo cáo một câu trả lời của trợ lý.
class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.message});

  final WrChatMessage message;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _note = TextEditingController();
  WrAiReportReason? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(wrChatRepositoryProvider)
          .reportMessage(
            content: widget.message.content,
            reason: reason,
            note: _note.text,
            conversationId: ref.read(wrChatControllerProvider).conversationId,
            messageId: widget.message.id,
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Cảm ơn bạn. Báo cáo đã được ghi nhận để đội ngũ xem lại.',
              'Thank you. Your report has been recorded for our team to review.',
            ),
          ),
        ),
      );
    } on WrChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                wrKeepCompounds(
                  tr('Báo cáo câu trả lời này', 'Report this answer'),
                ),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              WrParagraph(
                tr(
                  'Câu trả lời do AI tạo ra. Nếu thấy không phù hợp, bạn chọn '
                      'lý do để đội ngũ xem lại.',
                  'This answer was generated by AI. If it seems inappropriate, '
                      'pick a reason so our team can review it.',
                ),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: WrColors.text2,
                ),
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 8),
              RadioGroup<WrAiReportReason>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(
                  children: [
                    for (final r in WrAiReportReason.values)
                      RadioListTile<WrAiReportReason>(
                        key: Key('wr_chat_report_${r.name}'),
                        value: r,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: WrColors.navy,
                        title: Text(
                          wrKeepCompounds(r.label),
                          style: const TextStyle(
                            fontSize: 16,
                            color: WrColors.dark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                key: const Key('wr_chat_report_note'),
                controller: _note,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: tr(
                    'Ghi thêm (không bắt buộc)',
                    'Add details (optional)',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: WrColors.destructive),
                  ),
                ),
              FilledButton(
                key: const Key('wr_chat_report_submit'),
                onPressed: _reason == null || _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: WrColors.coral,
                  foregroundColor: WrColors.navy,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        wrKeepCompounds(tr('Gửi báo cáo', 'Send report')),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút mở luồng Reflection hoặc Thư viện Nội dung Cảm xúc.
class _ActionButton extends ConsumerWidget {
  const _ActionButton({required this.action, this.lastUserText});

  final WrChatAction action;
  final String? lastUserText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Đã check-in thì Thư viện tự mở đúng cảm xúc hôm nay; chưa thì gửi kèm
    // cảm xúc đọc từ lời người dùng, đừng để nó rơi về "Khá ổn".
    final hasCheckin = ref.watch(todayCheckinProvider).valueOrNull != null;
    final route = action == WrChatAction.calm && !hasCheckin
        ? '${action.route}?mood=${calmMoodFor(lastUserText).moodContentKey}'
        : action.route;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: OutlinedButton.icon(
        key: Key('wr_chat_action_${action.name}'),
        // `push` chứ không phải `go`: người dùng phải quay lại được đúng cuộc
        // trò chuyện đang dở sau khi ghi xong hoặc đọc xong.
        onPressed: () => context.push(route),
        icon: Icon(
          action == WrChatAction.reflect
              ? Icons.edit_note_outlined
              : Icons.spa_outlined,
          size: 17,
        ),
        label: Text(
          wrKeepCompounds(action.label),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: WrColors.navy,
          side: const BorderSide(color: WrColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

/// Ba chấm trong lúc chờ trả lời.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            key: const Key('wr_chat_typing'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: WrColors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: WrColors.line),
            ),
            child: const SizedBox(
              width: 18,
              height: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_Dot(), _Dot(), _Dot()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 4,
    height: 4,
    decoration: const BoxDecoration(
      color: WrColors.muted,
      shape: BoxShape.circle,
    ),
  );
}

// ---------------------------------------------------------------------------
// Màn trống
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.starters, required this.onPick});

  /// Gợi ý mở lời, dựng từ tình huống người dùng hay chọn khi nhìn lại.
  ///
  /// Truyền VÀO chứ không tự đọc provider: widget này thuần hiển thị, và nhận
  /// danh sách từ ngoài thì test dựng được đúng từng trường hợp (có dữ liệu,
  /// chưa có dữ liệu) mà không phải dựng cả tầng dữ liệu phía sau.
  final List<String> starters;

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('wr_chat_empty'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      children: [
        Text(
          wrKeepCompounds(
            tr(
              'Kể mình nghe một chuyện trong công việc',
              'Tell me something from work',
            ),
          ),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
            height: 1.35,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 12),
        WrParagraph(
          tr(
            'Một tình huống vừa xảy ra, một cảm giác khó gọi tên, hay một điều '
                'bạn muốn hiểu thêm về chính mình. Viết một câu là đủ.',
            'Something that just happened, a feeling you cannot quite name, or '
                'something you want to understand about yourself. One line is enough.',
          ),
          style: TextStyle(fontSize: 15.5, color: WrColors.muted, height: 1.75),
          // Câu phụ ngắn: căn đều làm giãn chữ thành khe hở. Bản tiếng Anh ở
          // cỡ chữ hệ thống lớn chỉ còn hai ba từ một dòng, hở thấy rõ (máy
          // thật 07/10).
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 24),
        for (final (i, s) in starters.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              // Khoá theo VỊ TRÍ, không theo `indexOf`. Gợi ý giờ dựng từ dữ
              // liệu thật nên hai ô hoàn toàn có thể trùng chữ; `indexOf` trả
              // về vị trí đầu tiên và hai ô sẽ mang cùng một khoá.
              key: Key('wr_chat_starter_$i'),
              onTap: () => onPick(s),
              borderRadius: BorderRadius.circular(14),
              child: WrCardMinimal(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        wrKeepCompounds(s),
                        style: const TextStyle(
                          fontSize: 15.5,
                          color: WrColors.dark,
                          height: 1.55,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.north_west,
                      size: 15,
                      color: WrColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        // Mục 4.9 của system prompt: minh bạch về bản thân. Nói trước một lần ở
        // đây thay vì để trợ lý phải tự nhắc giữa cuộc trò chuyện.
        WrParagraph(
          tr(
            'Mình là trợ lý AI hỗ trợ bạn nhìn lại công việc, không thay thế '
                'chuyên gia tâm lý hay tư vấn nghề nghiệp.',
            'I am an AI assistant that helps you look back at work. I am not a '
                'replacement for a therapist or a career adviser.',
          ),
          style: TextStyle(fontSize: 14, color: WrColors.muted, height: 1.65),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thanh lỗi
// ---------------------------------------------------------------------------

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message, required this.quotaExhausted});

  final String message;
  final bool quotaExhausted;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_chat_error'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: WrColors.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wrKeepCompounds(message),
            style: const TextStyle(
              fontSize: 14.5,
              color: WrColors.dark,
              height: 1.6,
            ),
          ),
          // Hết lượt là chuyện về gói, không phải trục trặc kỹ thuật. Mời đúng
          // việc tiếp theo làm được, thay vì mời gửi lại một câu chắc chắn hỏng.
          if (quotaExhausted) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('wr_chat_paywall_link'),
              onPressed: () => context.push('/wr/paywall'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                wrKeepCompounds(tr('Xem gói Premium', 'See Premium')),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: WrColors.navy,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ô soạn
// ---------------------------------------------------------------------------

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.remaining,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;

  /// Số lượt còn lại của gói miễn phí. Null = Premium hoặc chưa biết.
  final int? remaining;

  final VoidCallback onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = controller.text.trim().isNotEmpty && !sending;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        // Đẩy lên trên bàn phím khi bàn phím mở, để ô soạn không bị che.
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: WrColors.white,
        border: Border(top: BorderSide(color: WrColors.line, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: WrVoiceField(
                  fieldKey: const Key('wr_ask_field'),
                  controller: controller,
                  hintText: tr(
                    'Viết điều bạn đang nghĩ…',
                    'Write what is on your mind…',
                  ),
                  minLines: 1,
                  maxLines: 5,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              _SendButton(enabled: canSend, sending: sending, onTap: onSend),
            ],
          ),
          if (remaining != null) ...[
            const SizedBox(height: 8),
            Text(
              wrKeepCompounds(
                remaining == 0
                    ? tr(
                        'Hôm nay bạn đã dùng hết lượt trò chuyện miễn phí.',
                        'You have used up your free chats for today.',
                      )
                    : tr(
                        'Còn $remaining lượt trò chuyện miễn phí hôm nay.',
                        '$remaining free chats left today.',
                      ),
              ),
              key: const Key('wr_chat_quota_hint'),
              style: const TextStyle(fontSize: 13, color: WrColors.text3),
            ),
          ],
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.sending,
    required this.onTap,
  });

  final bool enabled;
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: tr('Gửi', 'Send'),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Material(
          color: enabled
              ? WrColors.navy
              : WrColors.navy.withValues(alpha: 0.25),
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('wr_ask_send'),
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: Center(
              child: sending
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        color: WrColors.white,
                        strokeWidth: 1.6,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward,
                      size: 19,
                      color: WrColors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Câu hỏi đã gửi theo cách cũ
// ---------------------------------------------------------------------------

class _ConversationsSheet extends ConsumerWidget {
  const _ConversationsSheet({required this.currentId, required this.onPick});

  final String? currentId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wrConversationsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wrKeepCompounds(tr('LỊCH SỬ TRÒ CHUYỆN', 'CHAT HISTORY')),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.55,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
                ),
              ),
              error: (_, __) => Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  wrKeepCompounds(
                    tr(
                      'Chưa đọc được lịch sử. Bạn thử lại sau nhé.',
                      'Could not load the history. Please try again later.',
                    ),
                  ),
                  style: TextStyle(fontSize: 15.5, color: WrColors.muted),
                ),
              ),
              data: (items) => items.isEmpty
                  ? Padding(
                      key: Key('wr_chat_conversations_empty'),
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        wrKeepCompounds(
                          tr(
                            'Chưa có cuộc trò chuyện nào được lưu.',
                            'No conversations saved yet.',
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 15.5,
                          color: WrColors.muted,
                          height: 1.65,
                        ),
                      ),
                    )
                  : Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final c = items[i];
                          return _ConversationRow(
                            conversation: c,
                            isCurrent: c.id == currentId,
                            onTap: () => onPick(c.id),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.isCurrent,
    required this.onTap,
  });

  final WrConversation conversation;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final at = conversation.lastMessageAt;
    return InkWell(
      key: Key('wr_chat_conversation_${conversation.id}'),
      // Cuộc đang mở thì không cho chạm: chạm vào sẽ tải lại đúng thứ đang xem
      // và nháy màn hình một cái vì không lý do gì.
      onTap: isCurrent ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: WrCardMinimal(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wrKeepCompounds(conversation.displayTitle),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? WrColors.muted : WrColors.navy,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    wrKeepCompounds(
                      tr(
                        '${at.day.toString().padLeft(2, '0')}/'
                            '${at.month.toString().padLeft(2, '0')}/${at.year}'
                            '${isCurrent ? '  ·  đang mở' : ''}',
                        '${at.day.toString().padLeft(2, '0')}/'
                            '${at.month.toString().padLeft(2, '0')}/${at.year}'
                            '${isCurrent ? '  ·  open' : ''}',
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: WrColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (!isCurrent) ...[
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, size: 18, color: WrColors.muted),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Câu hỏi đã gửi theo cách cũ
// ---------------------------------------------------------------------------

class _OldQuestionsSheet extends ConsumerWidget {
  const _OldQuestionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(wrCareerQuestionsProvider).valueOrNull ?? const [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wrKeepCompounds(tr('BẠN ĐÃ HỎI', 'YOU ASKED')),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.55,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            if (history.isEmpty)
              Padding(
                key: Key('wr_ask_history_empty'),
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  wrKeepCompounds(
                    tr(
                      'Bạn chưa gửi câu hỏi nào theo cách cũ.',
                      'You have not sent any questions the old way.',
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 15.5,
                    color: WrColors.muted,
                    height: 1.65,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final q in history) ...[
                      _QuestionRow(question: q),
                      if (q != history.last) const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.question});

  final CareerQuestion question;

  @override
  Widget build(BuildContext context) {
    final at = question.createdAt;
    return WrCardMinimal(
      key: Key('wr_ask_history_${question.id ?? question.question.hashCode}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (at != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                wrKeepCompounds(
                  '${at.day.toString().padLeft(2, '0')}/'
                  '${at.month.toString().padLeft(2, '0')}',
                ),
                style: const TextStyle(fontSize: 13.5, color: WrColors.muted),
              ),
            ),
          WrTitleText(
            question.question,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
              color: WrColors.navy,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            wrKeepCompounds(
              question.isAnswered ? question.answer! : kAskPendingMessage,
            ),
            style: TextStyle(
              fontSize: 15,
              height: 1.7,
              color: question.isAnswered ? WrColors.dark : WrColors.muted,
              fontStyle: question.isAnswered
                  ? FontStyle.normal
                  : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
