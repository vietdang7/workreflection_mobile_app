import 'package:flutter/material.dart';

import '../theme/wr_colors.dart';

/// Khoảng trắng KHÔNG cho ngắt dòng (U+00A0). Hai chữ nối bằng ký tự này luôn
/// nằm chung một dòng.
const String nbsp = '\u00A0';

/// Giữ hai tiếng cuối của mỗi câu đi liền nhau.
///
/// Tiếng Việt viết rời từng tiếng, nên chỗ ngắt dòng của Flutter rơi vào giữa
/// từ ghép rất thường xuyên: "…chờ đợi trong mơ / hồ." Chữ "hồ." đứng một mình
/// cuối đoạn vừa khó đọc vừa xấu — đúng chỗ khách chỉ ra (ảnh 2026-08-05).
///
/// Không có từ điển từ ghép nào ở đây, và cũng KHÔNG nên có: đoán "thay đổi"
/// hay "mơ hồ" là một từ đòi hỏi bộ tách từ tiếng Việt, thứ vừa nặng vừa sai
/// ngoài dự đoán. Thay vào đó dùng một quy tắc typography không cần hiểu nghĩa:
/// hai tiếng cuối câu luôn đi cùng nhau, nên dòng chót không bao giờ còn đúng
/// một tiếng cụt.
///
/// Chỉ đụng vào chỗ ngắt CUỐI CÂU. Những khoảng trắng khác giữ nguyên để dòng
/// chữ còn co giãn được — ép nhiều hơn sẽ đẩy cả cụm dài xuống dòng và để lại
/// một mảng trắng còn xấu hơn thứ đang chữa.
String wrKeepSentenceTailTogether(String text) {
  // <tiếng áp chót> <khoảng trắng> <tiếng chót><dấu kết câu>
  // Tiếng chót phải loại trừ dấu câu, nếu không `\S+` nuốt luôn dấu chấm và
  // mẫu không còn nhận ra đâu là cuối câu.
  final endOfSentence = RegExp(r'(\S+)[ \t]+([^\s.!?…]+)([.!?…]+["”\)\]]*)');

  // Câu chót của đoạn nhiều khi không có dấu chấm (dòng trích, câu hỏi gợi ý).
  // Nó vẫn là chỗ dễ rớt chữ nhất nên xử lý luôn.
  final endOfText = RegExp(r'(\S+)[ \t]+([^\s.!?…]+)\s*$');

  var out = text.replaceAllMapped(
    endOfSentence,
    (m) => '${m.group(1)}$nbsp${m.group(2)}${m.group(3)}',
  );

  out = out.replaceAllMapped(
    endOfText,
    (m) => '${m.group(1)}$nbsp${m.group(2)}',
  );

  return out;
}

/// Cho phép [WrParagraph] nối cụm cuối câu hay không.
///
/// Luôn `true` khi chạy thật. Bộ test đặt `false` ở `test/flutter_test_config.dart`
/// vì rất nhiều widget test đối chiếu NGUYÊN VĂN chuỗi hiển thị bằng
/// `find.text('…')`; đổi khoảng trắng thường thành U+00A0 sẽ làm chúng trượt
/// hàng loạt mà không nói lên điều gì về sản phẩm. Bản thân phép nối đã có
/// test riêng ở `test/core/wr_paragraph_test.dart`, nên tắt ở đây không bỏ sót
/// gì — nhưng đừng tắt nó ở mã chạy thật.
bool wrParagraphKeepsTail = true;

/// Đoạn văn nội dung: căn đều hai bên, chữ cuối câu không rớt xuống một mình.
///
/// Dùng cho phần ĐỌC — mô tả chủ đề, câu chuyện, insight, đoạn giải thích.
/// KHÔNG dùng cho tiêu đề, nhãn nút hay dòng chữ ngắn trong thẻ: căn đều một
/// dòng thì vô nghĩa, mà lỡ nó xuống hai dòng thì khoảng trắng giãn ra trông
/// còn lệch hơn căn trái.
class WrParagraph extends StatelessWidget {
  const WrParagraph(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.justify,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;

  /// Cắt bớt khi đoạn chỉ là bản xem trước (thẻ danh sách, dòng tóm tắt).
  final int? maxLines;
  final TextOverflow? overflow;

  /// Cho phép trả về canh trái/giữa ở những chỗ căn đều không hợp (ví dụ đoạn
  /// nằm giữa màn, hoặc cột quá hẹp).
  final TextAlign textAlign;

  /// Kiểu chữ mặc định của một đoạn đọc chậm.
  static const TextStyle defaultStyle = TextStyle(
    fontSize: 15.5,
    color: WrColors.muted,
    height: 1.6,
  );

  @override
  Widget build(BuildContext context) {
    return Text(
      wrParagraphKeepsTail ? wrKeepSentenceTailTogether(text) : text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: style ?? defaultStyle,
    );
  }
}
