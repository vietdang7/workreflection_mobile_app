// Ô hỏi về hành trình nghề nghiệp — họp khách 2026-07-29.
//
// "Bạn muốn hỏi điều gì đó, bạn ghi vô đây rồi bạn gửi thôi, chứ không phải
// theo dạng checkbox. Nó không phải theo dạng là nói chuyện qua nói chuyện lại
// — cái đó chị nghĩ sẽ chờ sau."
//
// Vì vậy màn này KHÔNG phải khung chat. Một ô, một nút gửi, và một danh sách
// những câu đã hỏi kèm câu trả lời khi đã có. Không bong bóng trái phải, không
// ô "đang gõ", không lịch sử hội thoại.
//
// Chưa có AI trả lời thì nói thẳng điều sẽ xảy ra: câu hỏi được ghi nhận, và
// phần gợi ý chi tiết sẽ tới qua email. Đây là lời hứa với người dùng, nên nó
// phải khớp đúng với việc bảng `wr_career_questions` giữ lại nguyên văn câu hỏi
// cho người vận hành đọc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_voice_field.dart';
import '../wr_providers.dart';

/// Câu người dùng thấy sau khi gửi, khi hệ thống chưa tự trả lời được.
const String kAskPendingMessage =
    'Hệ thống đã ghi nhận câu hỏi của bạn. Phần gợi ý chi tiết sẽ được gửi vào '
    'email của bạn.';

class WrAskScreen extends ConsumerStatefulWidget {
  const WrAskScreen({super.key});

  @override
  ConsumerState<WrAskScreen> createState() => _WrAskScreenState();
}

class _WrAskScreenState extends ConsumerState<WrAskScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _error = 'Cần đăng nhập để gửi câu hỏi.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(wrIntelligenceRepositoryProvider)
          .insertCareerQuestion(
            CareerQuestion(userId: userId, question: text),
          );
      ref.invalidate(wrCareerQuestionsProvider);
      if (!mounted) return;
      _controller.clear();
      setState(() => _sent = true);
    } catch (_) {
      // Gửi hỏng thì phải nói ra và GIỮ NGUYÊN chữ trong ô: xoá ô lúc này là
      // làm mất câu người ta vừa gõ mà chẳng lưu được ở đâu.
      if (mounted) {
        setState(() => _error = 'Chưa gửi được câu hỏi. Thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history =
        ref.watch(wrCareerQuestionsProvider).valueOrNull ?? const [];
    final canSend = _controller.text.trim().isNotEmpty && !_busy;

    return WrDetailScaffold(
      eyebrow: 'HỎI VỀ HÀNH TRÌNH CỦA BẠN',
      title: 'Bạn muốn hiểu thêm điều gì?',
      children: [
        const Text(
          'Ví dụ: với những gì tôi đã ghi lại, tôi có phù hợp với một vai trò '
          'thiên về điều phối không? Viết một câu là đủ.',
          style: TextStyle(fontSize: 14, color: WrColors.muted, height: 1.7),
        ),
        const SizedBox(height: 18),

        WrVoiceField(
          fieldKey: const Key('wr_ask_field'),
          controller: _controller,
          hintText: 'Điều tôi muốn hiểu thêm về mình là…',
          minLines: 4,
          maxLines: 7,
          onChanged: () => setState(() {}),
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            key: const Key('wr_ask_error'),
            style: const TextStyle(fontSize: 13, color: WrColors.coral),
          ),
        ],

        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('wr_ask_send'),
            onPressed: canSend ? _send : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: WrColors.navy,
              foregroundColor: WrColors.white,
              disabledBackgroundColor: WrColors.navy.withValues(alpha: 0.25),
              disabledForegroundColor: WrColors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: WrColors.white,
                      strokeWidth: 1.6,
                    ),
                  )
                : const Text(
                    'Gửi câu hỏi',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),

        if (_sent) ...[
          const SizedBox(height: 18),
          WrCardMinimal(
            key: const Key('wr_ask_sent_notice'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle_outline,
                      size: 18, color: WrColors.teal),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kAskPendingMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: WrColors.navy,
                      height: 1.65,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Những câu đã hỏi ──────────────────────────────────────────
        if (history.isNotEmpty) ...[
          const SizedBox(height: 32),
          const Text(
            'BẠN ĐÃ HỎI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.55,
              color: WrColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          for (final q in history) ...[
            _QuestionRow(question: q),
            if (q != history.last) const SizedBox(height: 16),
          ],
        ],
      ],
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
                style: const TextStyle(fontSize: 12, color: WrColors.muted),
              ),
            ),
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: WrColors.navy,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            question.isAnswered ? question.answer! : kAskPendingMessage,
            style: TextStyle(
              fontSize: 13.5,
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
