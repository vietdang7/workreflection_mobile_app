// Lột ký hiệu Markdown khỏi chữ do model sinh ra — tầng phía APP.
//
// Mục 17.1 (khách 09/09). Bản Deno dùng chung ở
// `supabase/functions/_shared/strip_markdown.ts` là bản gốc; file này là bản
// Dart CÙNG LUẬT.
//
// ---------------------------------------------------------------------------
// Vì sao có hai bản, không phải một
// ---------------------------------------------------------------------------
//
// Lọc ở Edge Function là đúng chỗ nhất: sửa một lần, mọi client hưởng. Nhưng
// nó không phủ hết được:
//
//   • `ai-personalize` (phần Khảo sát) nay nằm trong repo này và đã gọi bộ lọc
//     phía máy chủ, nhưng bản trả về đã lưu/cache từ trước vẫn có thể còn vết.
//   • Dữ liệu đã lưu trước hôm nay vẫn còn nguyên dấu sao trong database. Lọc ở
//     hàm sinh chỉ sạch từ bản ghi mới trở đi.
//   • Hàm mới thêm sau này sẽ quên gọi bộ lọc — đó là chuyện đã xảy ra đúng ba
//     lần với ba hàm hiện có.
//
// Nên tầng này đặt ngay trước lúc dựng `Text`, là chỗ duy nhất chắc chắn mọi
// chữ AI đều đi qua.
//
// ---------------------------------------------------------------------------
// Chỉ áp cho chữ AI, KHÔNG áp cho chữ người dùng
// ---------------------------------------------------------------------------
//
// Người dùng gõ `*` thật, gõ tên có gạch dưới, dán một đoạn JD có gạch đầu
// dòng. Lột ở đó là âm thầm sửa chữ của họ. Danh giới: gọi hàm này ở đúng chỗ
// hiển thị NỘI DUNG DO MODEL SINH RA.

/// Lột ký hiệu Markdown, giữ nguyên chữ.
///
/// Giữ đúng thứ tự và đúng ngoại lệ của bản Deno — hai bản lệch nhau thì cùng
/// một câu đọc ra hai kiểu tuỳ nó đi đường nào.
// Vết AI ngoài Markdown (Task B3): gạch dài và emoji. Giống hệt bản Deno.
// Mũi tên U+2190-21FF không phải emoji; keycap U+20E3 gỡ cùng emoji.
final RegExp _emojiRun = RegExp(
  r'([ \t]*)((?:(?![\u00A9\u00AE\u2122\u2190-\u21FF])\p{Extended_Pictographic}|[\u{1F3FB}-\u{1F3FF}\uFE0F\u200D\u20E3])+)([ \t]*)',
  unicode: true,
);

String _stripAiTraces(String text) {
  return text
      .replaceAllMapped(_emojiRun, (m) {
        final atLineStart = m.start == 0 || text[m.start - 1] == '\n';
        final noSpace = m[1]!.isEmpty && m[3]!.isEmpty;
        return atLineStart || noSpace ? '' : ' ';
      })
      .replaceAll(RegExp(r'^[ \t]*—[ \t]*', multiLine: true), '')
      .replaceAll(
        RegExp(r'(?<=[\p{L}\p{M}])—(?=[\p{L}\p{M}])', unicode: true),
        ', ',
      )
      .replaceAll(RegExp(r'[ \t]+[—–](?=[ \t]*[,.;:!?])'), '')
      .replaceAll(RegExp(r'(?<=[,.;:!?])[ \t]+[—–][ \t]+'), ' ')
      .replaceAll(RegExp(r'(?<=\S)(?<![ \t])[ \t]+[—–][ \t]+(?!\d)'), ', ')
      .replaceAll(
        RegExp(
          r'(?<=[^\s\d])(?<!\d[\p{L}%]{0,3})[ \t]+[—–][ \t]+(?=\d)',
          unicode: true,
        ),
        ', ',
      )
      .replaceAll(RegExp(r'[ \t]+(?=[,.;:!?])'), '')
      .replaceAll(RegExp(r'[ \t]+$', multiLine: true), '');
}

// Bỏ ký hiệu Markdown TRƯỚC, lọc vết AI SAU (giống bản Deno).
String stripMarkdown(String input) => _stripAiTraces(_stripMdSymbols(input));

String _stripMdSymbols(String input) {
  return input
      // Đậm và nghiêng. Xử lý `***` trước `**` trước `*`, nếu không `**a**` sẽ
      // bị luật một-sao ăn mất một lớp và chừa lại `*a*`.
      .replaceAllMapped(
        RegExp(r'\*\*\*(.+?)\*\*\*', dotAll: true),
        (m) => m[1]!,
      )
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*', dotAll: true), (m) => m[1]!)
      .replaceAllMapped(
        RegExp(r'(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])', dotAll: true),
        (m) => m[1]!,
      )
      // CỐ Ý KHÔNG lột `__đậm__` — xem lý do ở bản Deno. Tóm tắt: không phân
      // biệt được `__đậm__` với một tên có gạch dưới ở hai đầu, mà chữ người
      // dùng dán vào thì có thể chứa gạch dưới thật.
      // Tiêu đề `# `, `## `, `### ` ở đầu dòng.
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
      // Gạch đầu dòng `- `, `* `, `+ ` ở đầu dòng. Giữ chữ, bỏ dấu.
      .replaceAll(RegExp(r'^\s{0,3}[-*+]\s+', multiLine: true), '')
      // Chữ trong dấu nháy ngược.
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!)
      // Liên kết `[chữ](đường-dẫn)` — giữ chữ, bỏ đường dẫn.
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
      // Ba dòng trống trở lên gộp còn một dòng trống.
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

/// [stripMarkdown] cho chuỗi có thể null. Null vào thì null ra.
String? stripMarkdownOrNull(String? input) =>
    input == null ? null : stripMarkdown(input);
