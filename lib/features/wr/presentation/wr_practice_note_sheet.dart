// Ghi chú tùy chọn khi đánh dấu xong một bước Thực hành (Hai Lớp v1.6 §VII).
//
// §VII: "việc chia sẻ là phần thưởng ghi nhận thêm, không phải điều kiện bắt
// buộc để hoàn thành." Nên tấm này có hai lối ra ngang hàng nhau — viết rồi
// lưu, hoặc bỏ qua chỉ đánh dấu xong — và bỏ qua KHÔNG sinh thêm gì cả.
//
// Vuốt xuống đóng tấm là huỷ hẳn: bước vẫn chưa xong. Ba kết quả khác nhau nên
// không gộp được vào một `String?`.

import 'package:flutter/material.dart';

import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_voice_field.dart';
import '../../../core/widgets/wr_paragraph.dart';

/// Kết quả người dùng chọn trên tấm ghi chú.
enum PracticeNoteAction {
  /// Lưu ghi chú và đánh dấu xong — sinh thêm một mục Career Memory.
  saveWithNote,

  /// Chỉ đánh dấu xong, không ghi gì thêm.
  skip,
}

class PracticeNoteResult {
  const PracticeNoteResult({required this.action, this.note});

  final PracticeNoteAction action;

  /// Chỉ có giá trị khi [action] là [PracticeNoteAction.saveWithNote].
  final String? note;
}

/// Mở tấm ghi chú cho [stepTitle]. Trả về null khi người dùng huỷ (vuốt xuống
/// hoặc bấm nền) — lúc đó bước KHÔNG được đánh dấu xong.
Future<PracticeNoteResult?> showPracticeNoteSheet(
  BuildContext context, {
  required String stepTitle,
}) {
  return showModalBottomSheet<PracticeNoteResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PracticeNoteSheet(stepTitle: stepTitle),
  );
}

class _PracticeNoteSheet extends StatefulWidget {
  const _PracticeNoteSheet({required this.stepTitle});

  final String stepTitle;

  @override
  State<_PracticeNoteSheet> createState() => _PracticeNoteSheetState();
}

class _PracticeNoteSheetState extends State<_PracticeNoteSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = _controller.text.trim();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: WrColors.navy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'BẠN VỪA HOÀN THÀNH',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.stepTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            const WrParagraph(
              'Có điều gì đáng nhớ khi bạn làm bước này không? '
              'Không viết cũng không sao.',
              style: TextStyle(
                fontSize: 15,
                color: WrColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            WrVoiceField(
              fieldKey: const Key('wr_practice_note_field'),
              controller: _controller,
              hintText: 'Điều mình nhận ra khi thử…',
              minLines: 3,
              maxLines: 5,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                key: const Key('wr_practice_note_save'),
                behavior: HitTestBehavior.opaque,
                // Ô trống thì nút lưu không có gì để lưu — để nó vô hiệu thay vì
                // ghi một mục Career Memory rỗng.
                onTap: note.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          PracticeNoteResult(
                            action: PracticeNoteAction.saveWithNote,
                            note: note,
                          ),
                        ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: note.isEmpty
                        ? WrColors.dark.withValues(alpha: 0.25)
                        : WrColors.dark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Lưu và hoàn thành',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: WrColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: GestureDetector(
                key: const Key('wr_practice_note_skip'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(
                  const PracticeNoteResult(action: PracticeNoteAction.skip),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Bỏ qua, chỉ đánh dấu xong',
                    style: TextStyle(fontSize: 14.5, color: WrColors.muted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
