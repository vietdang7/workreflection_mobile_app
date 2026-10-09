import 'package:flutter/material.dart';

import '../l10n/wr_tr.dart';
import '../l10n/wr_vi_compounds.g.dart';
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
/// Quy tắc này không cần hiểu nghĩa: hai tiếng cuối câu luôn đi cùng nhau, nên
/// dòng chót không bao giờ còn đúng một tiếng cụt. Từ ghép GIỮA câu là việc của
/// [wrKeepCompoundsTogether] (có từ điển, thêm 08/10).
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

/// Một "tiếng": dãy chữ cái liền nhau, kể cả chữ có dấu. Phải khớp với `WORD`
/// trong `tool/gen_vi_compounds.py`, nếu không cặp sinh ra sẽ không bao giờ
/// khớp lúc chạy.
final _viSyllable = RegExp(r'[\p{L}\p{M}]+', unicode: true);

/// Một cụm nối tối đa bao nhiêu tiếng. Hai từ ghép chồng lên nhau ("an toàn" +
/// "toàn tâm" + "tâm lý") được nối thành một cụm, nhưng không cho cụm dài vô
/// hạn: một cụm không ngắt được dài hơn bề ngang cột là tràn ô.
const _kMaxCompoundRun = 4;

/// Giữ hai tiếng của một từ ghép đi liền nhau ("phụ thuộc", "thực hành").
///
/// Khách họp 08/10: "phụ thuộc" rớt mất chữ "thuộc" xuống dòng dưới.
/// [wrKeepSentenceTailTogether] chỉ chữa được cuối câu; giữa câu thì phải biết
/// đâu là một từ, nên ở đây có từ điển — [kWrViCompounds], lọc từ Viet74K chỉ
/// lấy những từ thật sự có trong chữ của app.
///
/// Nối CẢ CHUỖI từ ghép chồng nhau thay vì chọn từng cặp từ trái sang: từ điển
/// có cả "ba khía" lẫn "khía cạnh", chọn tham từ trái thì "ba khía cạnh" thành
/// "ba khía / cạnh" — tách đúng cái từ cần giữ. Nối cả ba thì không bao giờ
/// tách sai, chỉ đổi lại một cụm dài hơn chút.
///
/// Chỉ cho tiếng Việt: vài cặp không dấu trong từ điển có thể trùng hai chữ
/// tiếng Anh đứng cạnh nhau, nên tắt hẳn khi đang tiếng Anh.
String wrKeepCompoundsTogether(String text) {
  if (wrEnglish) return text;
  final syllables = _viSyllable.allMatches(text).toList();
  if (syllables.length < 2) return text;

  final out = StringBuffer();
  var cursor = 0;
  var run = 1;
  for (var i = 0; i < syllables.length - 1; i++) {
    final a = syllables[i];
    final b = syllables[i + 1];
    // Chỉ một dấu cách thường giữa hai tiếng. Có dấu câu, xuống dòng hay hai
    // dấu cách là hai tiếng đó không cùng một từ.
    final joinable =
        b.start == a.end + 1 &&
        text.codeUnitAt(a.end) == 0x20 &&
        run < _kMaxCompoundRun &&
        kWrViCompounds.contains(
          '${a[0]!.toLowerCase()} ${b[0]!.toLowerCase()}',
        );
    if (joinable) {
      out
        ..write(text.substring(cursor, a.end))
        ..write(nbsp);
      cursor = b.start;
      run++;
    } else {
      run = 1;
    }
  }
  out.write(text.substring(cursor));
  return out.toString();
}

/// Bản dùng cho chữ đọc ngoài [WrParagraph] — dòng mô tả trong thẻ, câu trích.
///
/// Gồm cả từ ghép lẫn cuối câu, và tắt theo cùng cờ [wrParagraphKeepsTail] để
/// bộ test so chuỗi nguyên văn vẫn chạy.
String wrKeepWords(String text) => wrParagraphKeepsTail
    ? wrKeepSentenceTailTogether(wrKeepCompoundsTogether(text))
    : text;

/// Bản chỉ khoá từ ghép, KHÔNG nối hai tiếng cuối câu — cho nhãn ngắn trong
/// ô hẹp (ô cảm xúc, tiêu đề). Nối cuối câu ở đó biến "feeling good" thành một
/// khối không ngắt được rộng hơn lòng ô (ảnh khách 11/09); còn từ ghép chỉ bật
/// ở tiếng Việt nên không dính lỗi đó.
String wrKeepCompounds(String text) =>
    wrParagraphKeepsTail ? wrKeepCompoundsTogether(text) : text;

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
      wrKeepWords(text),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: style ?? defaultStyle,
    );
  }
}
