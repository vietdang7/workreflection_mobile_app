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

import '../../../core/logic/wr_chat_starters.dart';
import '../../../core/models/wr_chat.dart';
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_voice_field.dart';
import '../chat_providers.dart';
import '../wr_providers.dart';

/// Câu người dùng thấy cho những câu hỏi gửi theo cách cũ, chưa được trả lời.
///
/// Giữ nguyên hằng số và nguyên văn: nó là lời hứa đã đưa ra với những người đã
/// gửi câu hỏi trước khi có màn chat này.
const String kAskPendingMessage =
    'Hệ thống đã ghi nhận câu hỏi của bạn. Phần gợi ý chi tiết sẽ được gửi vào '
    'email của bạn.';

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
const List<String> kChatStarters = kDefaultChatStarters;

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

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        surfaceTintColor: WrColors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('wr_detail_back'),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: WrColors.navy,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Trò chuyện',
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
            tooltip: 'Cuộc trò chuyện mới',
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
              const PopupMenuItem(
                value: 'conversations',
                child: Text('Lịch sử trò chuyện'),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Text('Câu hỏi đã gửi trước đây'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Xoá cuộc trò chuyện này'),
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
                            for (final m in state.messages) _Bubble(message: m),
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
        title: const Text('Xoá cuộc trò chuyện?'),
        content: const Text(
          'Toàn bộ lượt trò chuyện sẽ bị xoá và không lấy lại được. '
          'Những gì bạn đã ghi trong Hành trình không bị ảnh hưởng.',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            key: const Key('wr_chat_clear_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá', style: TextStyle(color: WrColors.coral)),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final WrChatMessage message;

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
        if (!isUser && action != null) _ActionButton(action: action),
      ],
    );
  }

  Widget _bubble(BuildContext context, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.65,
                  color: isUser ? WrColors.white : WrColors.dark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút mở luồng Reflection hoặc Thư viện Nội dung Cảm xúc.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final WrChatAction action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: OutlinedButton.icon(
        key: Key('wr_chat_action_${action.name}'),
        // `push` chứ không phải `go`: người dùng phải quay lại được đúng cuộc
        // trò chuyện đang dở sau khi ghi xong hoặc đọc xong.
        onPressed: () => context.push(action.route),
        icon: Icon(
          action == WrChatAction.reflect
              ? Icons.edit_note_outlined
              : Icons.spa_outlined,
          size: 17,
        ),
        label: Text(
          action.label,
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
              borderRadius: BorderRadius.only(
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
                children: [
                  _Dot(),
                  _Dot(),
                  _Dot(),
                ],
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
        const Text(
          'Kể mình nghe một chuyện trong công việc',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
            height: 1.35,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Một tình huống vừa xảy ra, một cảm giác khó gọi tên, hay một điều '
          'bạn muốn hiểu thêm về chính mình. Viết một câu là đủ.',
          style: TextStyle(fontSize: 15.5, color: WrColors.muted, height: 1.75),
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
                        s,
                        style: const TextStyle(
                          fontSize: 15.5,
                          color: WrColors.dark,
                          height: 1.55,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.north_west,
                        size: 15, color: WrColors.muted),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        // Mục 4.9 của system prompt: minh bạch về bản thân. Nói trước một lần ở
        // đây thay vì để trợ lý phải tự nhắc giữa cuộc trò chuyện.
        const Text(
          'Mình là trợ lý AI hỗ trợ bạn nhìn lại công việc, không thay thế '
          'chuyên gia tâm lý hay tư vấn nghề nghiệp.',
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
            message,
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
              child: const Text(
                'Xem gói Premium',
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
                  hintText: 'Viết điều bạn đang nghĩ…',
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
              remaining == 0
                  ? 'Hôm nay bạn đã dùng hết lượt trò chuyện miễn phí.'
                  : 'Còn $remaining lượt trò chuyện miễn phí hôm nay.',
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
    return SizedBox(
      width: 46,
      height: 46,
      child: Material(
        color: enabled ? WrColors.navy : WrColors.navy.withValues(alpha: 0.25),
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
                : const Icon(Icons.arrow_upward,
                    size: 19, color: WrColors.white),
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
            const Text(
              'LỊCH SỬ TRÒ CHUYỆN',
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
              error: (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Chưa đọc được lịch sử. Bạn thử lại sau nhé.',
                  style: TextStyle(fontSize: 15.5, color: WrColors.muted),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      key: Key('wr_chat_conversations_empty'),
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Chưa có cuộc trò chuyện nào được lưu.',
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
                    conversation.displayTitle,
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
                    '${at.day.toString().padLeft(2, '0')}/'
                    '${at.month.toString().padLeft(2, '0')}/${at.year}'
                    '${isCurrent ? '  ·  đang mở' : ''}',
                    style: const TextStyle(fontSize: 13.5, color: WrColors.muted),
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
            const Text(
              'BẠN ĐÃ HỎI',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.55,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            if (history.isEmpty)
              const Padding(
                key: Key('wr_ask_history_empty'),
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Bạn chưa gửi câu hỏi nào theo cách cũ.',
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
                '${at.day.toString().padLeft(2, '0')}/'
                '${at.month.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 13.5, color: WrColors.muted),
              ),
            ),
          Text(
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
            question.isAnswered ? question.answer! : kAskPendingMessage,
            style: TextStyle(
              fontSize: 15,
              height: 1.7,
              color: question.isAnswered ? WrColors.dark : WrColors.muted,
              fontStyle:
                  question.isAnswered ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
