// Ô nhập có nút thu âm — họp khách 2026-07-29.
//
// "Người dùng app thì họ ít có gõ lắm, hoặc là họ sẽ voice nhưng mà họ cũng
// lười voice nữa… nếu mà họ cần add thông tin gì vào thì có cái voice để cho họ
// nói là dễ nhất."
//
// Nên nút mic đứng NGAY TRONG ô, không phải một màn riêng: bấm là nói, nói xong
// chữ hiện ra tại chỗ và sửa được như chữ tự gõ. Mọi ô tự viết trong luồng phản
// tư đều dùng widget này để hành vi giống hệt nhau ở mọi bước.
//
// Thu âm là TÙY CHỌN, không thay thế bàn phím: máy không có nhận dạng giọng nói
// hoặc người dùng từ chối quyền mic thì ô vẫn gõ được bình thường, chỉ mất nút.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/stt_service.dart';
import '../theme/wr_colors.dart';

class WrVoiceField extends ConsumerStatefulWidget {
  const WrVoiceField({
    super.key,
    required this.controller,
    required this.hintText,
    this.fieldKey,
    this.minLines = 4,
    this.maxLines = 6,
    this.italic = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;

  /// Key gắn lên chính [TextField] — để test cũ trỏ vào ô vẫn tìm thấy.
  final Key? fieldKey;

  final int minLines;
  final int maxLines;
  final bool italic;

  /// Gọi mỗi khi nội dung đổi, kể cả khi chữ đến từ giọng nói.
  final VoidCallback? onChanged;

  @override
  ConsumerState<WrVoiceField> createState() => _WrVoiceFieldState();
}

class _WrVoiceFieldState extends ConsumerState<WrVoiceField> {
  bool _listening = false;

  /// Chữ đã có TRƯỚC khi bấm mic.
  ///
  /// Cần giữ lại vì `speech_to_text` trả bản chép DẦN: mỗi kết quả là toàn bộ
  /// câu tính từ lúc bắt đầu nghe, không phải phần thêm. Cộng thẳng vào ô sẽ
  /// nhân đôi chữ theo từng nhịp partial.
  String _base = '';

  bool? _available;

  @override
  void initState() {
    super.initState();
    // Hỏi khả năng nhận dạng một lần, ngay khi dựng: biết trước thì nút mic chỉ
    // xuất hiện khi nó thật sự bấm được.
    _probe();
  }

  Future<void> _probe() async {
    try {
      final ok = await ref.read(sttServiceProvider).isAvailable;
      if (mounted) setState(() => _available = ok);
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  Future<void> _toggle() async {
    final stt = ref.read(sttServiceProvider);
    if (_listening) {
      await stt.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }

    _base = widget.controller.text.trimRight();
    setState(() => _listening = true);
    try {
      await stt.startListening(
        localeId: 'vi-VN',
        listenFor: const Duration(seconds: 60),
        onResult: (transcript, {required bool isFinal}) {
          if (!mounted) return;
          final spoken = transcript.trim();
          widget.controller.text =
              _base.isEmpty ? spoken : '$_base $spoken';
          widget.controller.selection = TextSelection.collapsed(
            offset: widget.controller.text.length,
          );
          widget.onChanged?.call();
          if (isFinal) setState(() => _listening = false);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WrColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: widget.fieldKey,
              controller: widget.controller,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              style: TextStyle(
                fontSize: 16,
                color: WrColors.navy,
                height: 1.6,
                fontStyle:
                    widget.italic ? FontStyle.italic : FontStyle.normal,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle:
                    const TextStyle(fontSize: 16.5, color: WrColors.muted),
              ),
              onChanged: (_) => widget.onChanged?.call(),
            ),
          ),
          // Chưa dò xong hoặc máy không hỗ trợ thì không chừa chỗ trống: ô nhập
          // vẫn dùng được đủ chiều ngang.
          if (_available == true) ...[
            const SizedBox(width: 4),
            _MicButton(listening: _listening, onTap: _toggle),
          ],
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? 'Dừng thu âm' : 'Nói thay vì gõ',
      child: GestureDetector(
        key: const Key('wr_voice_mic'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening
                ? WrColors.coral
                : WrColors.navy.withValues(alpha: 0.06),
          ),
          child: Icon(
            listening ? Icons.stop_rounded : Icons.mic_none_rounded,
            size: 20,
            color: WrColors.navy,
          ),
        ),
      ),
    );
  }
}
