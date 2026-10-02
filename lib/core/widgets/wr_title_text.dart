import 'package:flutter/widgets.dart';

const String _nbsp = ' ';

/// Nối hai tiếng CUỐI của tiêu đề bằng U+00A0 để tiếng cuối không rớt
/// xuống dòng một mình. Chỉ nối khi: có từ 3 tiếng trở lên, đuôi
/// (`tiếng_áp_chót + 1 + tiếng_cuối`) không dài quá [maxTailChars], và câu
/// chưa chứa U+00A0 (idempotent). Khoảng trắng cuối câu được giữ nguyên và
/// không tính là tiếng cuối. Khác `WrParagraph`: không nối cả câu, không justify.
String wrKeepTitleTail(String text, {int maxTailChars = 14}) {
  if (text.contains(_nbsp)) return text;
  final end = text.trimRight().length;
  final body = text.substring(0, end);
  final trailing = text.substring(end);
  final words = body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length < 3) return text;
  final last = words[words.length - 1];
  final prev = words[words.length - 2];
  if (prev.length + 1 + last.length > maxTailChars) return text;
  final head = body.substring(0, body.length - last.length);
  final headTrimmed = head.trimRight();
  return '$headTrimmed$_nbsp$last$trailing';
}

/// Thay thế trực tiếp cho `Text` ở các tiêu đề: giữ đuôi không rớt dòng.
/// Không đổi `textAlign` (mặc định start), không bao giờ justify.
class WrTitleText extends StatelessWidget {
  const WrTitleText(this.text,
      {super.key, this.style, this.textAlign, this.maxLines});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
        wrKeepTitleTail(text),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
      );
}
