// Dựng lại một câu ĐÃ GHÉP SẴN theo ngôn ngữ đang bật.
//
// ---------------------------------------------------------------------------
// Vì sao cần lớp này
// ---------------------------------------------------------------------------
//
// Phần lớn chữ trong app đi qua `tr(vi, en)` ngay lúc dựng widget, nên đổi ngôn
// ngữ là đổi theo. Nhưng câu Insight thì không: `_writeDerivedMemory` ghép câu
// hoàn chỉnh NGAY LÚC khép một lượt nhìn lại, rồi `insertMemoryEvent` lưu chuỗi
// đó vào cột `reflection_text` của `wr_career_memory_events`. Màn Hành trình
// đọc cột đó và in ra nguyên văn.
//
// Hệ quả: ngôn ngữ của câu được chốt tại thời điểm GHI, không phải thời điểm
// ĐỌC. Ai từng bật tiếng Anh một lần rồi quay về tiếng Việt sẽ mang theo vĩnh
// viễn những dòng Insight tiếng Anh nằm giữa giao diện tiếng Việt — và không có
// thao tác nào trong app gỡ được, vì chuỗi đã nằm trong database.
//
// Còn tệ hơn thế: một câu có thể lẫn hai thứ tiếng cùng lúc. Ô {first}/{last}
// lấy từ `_storyTitle`, mà hàm đó trả về hoặc NHÃN TÌNH HUỐNG (dịch được) hoặc
// CHÍNH CHỮ NGƯỜI DÙNG TỰ VIẾT (không được dịch, và không nên dịch). Nên câu
// khung tiếng Anh + nhãn tiếng Anh + câu người dùng viết bằng tiếng Việt là
// chuyện bình thường, đúng như ảnh khách gửi ngày 15/09/2026.
//
// ---------------------------------------------------------------------------
// Cách chữa: dựng lại lúc đọc, không thêm cột
// ---------------------------------------------------------------------------
//
// Câu Insight không do model sinh ra — nó ghép từ một số hữu hạn câu mẫu mà
// chính repo này giữ. Nên thay vì thêm cột `reflection_text_en` (chỉ chữa được
// các dòng ghi TỪ NAY, còn dòng cũ vẫn kẹt), ta nhận diện câu đã lưu thuộc câu
// mẫu nào, lấy lại các ô trống, rồi in lại bằng câu mẫu của ngôn ngữ đang bật.
//
// Cách này chữa luôn cả dữ liệu cũ, không cần migration, không cần backfill.
//
// Ô nào không tra được trong bảng đối chiếu thì GIỮ NGUYÊN — đó gần như chắc
// chắn là chữ người dùng tự viết, và dịch chữ của người ta là việc không được
// phép làm.

library;

import '../l10n/wr_tr.dart';

/// Một câu mẫu có sẵn hai bản, để còn nhận ra nó khi đọc lại.
class WrFrozenSentence {
  const WrFrozenSentence(this.vi, this.en);

  final String vi;
  final String en;

  /// Bản của ngôn ngữ đang bật.
  String get text => tr(vi, en);
}

/// Dựng lại [frozen] bằng ngôn ngữ đang bật.
///
/// [templates] là mọi câu mẫu mà chuỗi này CÓ THỂ đã được ghép từ đó.
/// [phraseSwaps] tra một cụm con bất kỳ (nhãn nhu cầu, nhãn tình huống) ở BẤT
/// KỲ ngôn ngữ nào sang bản đang bật.
///
/// Không nhận ra được thì trả lại nguyên văn: thà để một dòng cũ sai ngôn ngữ
/// còn hơn in ra một câu ghép sai nghĩa.
String localizeFrozenSentence(
  String frozen, {
  required List<WrFrozenSentence> templates,
  required Map<String, String> phraseSwaps,
}) {
  final text = frozen.trim();
  if (text.isEmpty) return frozen;

  for (final template in templates) {
    // Thử khớp với CẢ HAI bản. Bản đang bật cũng phải thử: câu có thể đúng
    // ngôn ngữ ở phần khung nhưng lẫn nhãn của ngôn ngữ kia trong ô trống.
    for (final source in [template.vi, template.en]) {
      final slots = _slotsOf(text, source);
      if (slots == null) continue;

      var out = template.text;
      slots.forEach((name, value) {
        out = out.replaceAll('{$name}', _swap(value, phraseSwaps));
      });
      return out;
    }
  }

  return frozen;
}

/// Khớp [text] với [template], trả về giá trị của từng ô `{tên}`.
///
/// Trả null khi không khớp.
Map<String, String>? _slotsOf(String text, String template) {
  final names = <String>[];
  final pattern = StringBuffer('^');
  var cursor = 0;

  for (final slot in _slotPattern.allMatches(template)) {
    pattern.write(RegExp.escape(template.substring(cursor, slot.start)));
    names.add(slot.group(1)!);
    // Không tham lam: các ô cách nhau bằng chữ cố định, nên cứ ăn ít nhất có
    // thể rồi để phần khung phía sau quyết định chỗ dừng.
    pattern.write('(.+?)');
    cursor = slot.end;
  }
  pattern.write(RegExp.escape(template.substring(cursor)));
  pattern.write(r'$');

  if (names.isEmpty) return null;

  final match = RegExp(pattern.toString(), dotAll: true).firstMatch(text);
  if (match == null) return null;

  return {for (var i = 0; i < names.length; i++) names[i]: match.group(i + 1)!};
}

final RegExp _slotPattern = RegExp(r'\{(\w+)\}');

/// Đổi một ô trống sang ngôn ngữ đang bật, giữ nguyên dấu ngoặc kép bao ngoài.
///
/// `{first}`/`{last}` được bọc `"..."` lúc ghép câu, nên phải bóc ra mới tra
/// được, rồi bọc lại để câu đọc vẫn như cũ.
String _swap(String raw, Map<String, String> phraseSwaps) {
  final value = raw.trim();
  final quoted =
      value.length >= 2 && value.startsWith('"') && value.endsWith('"');
  final inner = quoted ? value.substring(1, value.length - 1) : value;

  final swapped = phraseSwaps[inner.trim()];
  if (swapped == null) return raw;

  return quoted ? '"$swapped"' : swapped;
}
