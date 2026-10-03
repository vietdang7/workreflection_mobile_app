// Lột ký hiệu Markdown khỏi chữ do model sinh ra.
//
// Mục 17.1 (khách 09/09): "Ký tự `*` / `**` markdown trong chữ do model sinh
// ra. Hiện không có lớp lọc nào." Đúng ba trong bốn Edge Function trả thẳng chữ
// model viết ra màn hình; chỉ `wr-chat` có lọc, và bản lọc đó nằm chôn trong
// `reply_shaping.ts` của riêng nó.
//
// File này là bản dùng chung, chuyển nguyên vẹn từ `wr-chat/reply_shaping.ts`
// sau khi đã chạy thật từ 2026-08-03. `reply_shaping.ts` nay re-export lại nó,
// nên toàn bộ test và hành vi của wr-chat giữ nguyên.
//
// ---------------------------------------------------------------------------
// Vì sao vẫn cần thêm một tầng lọc PHÍA APP
// ---------------------------------------------------------------------------
//
// Bài học từ chính `reply_shaping`: prompt lo phần model làm ĐÚNG, tầng lọc lo
// phần model làm SAI. Nhưng Edge Function không phải nguồn duy nhất — chữ AI
// cũng vào app qua `ai-personalize` (nay đã nằm trong repo này và gọi bộ lọc
// này ở phía máy chủ; tầng app vẫn lọc lại dữ liệu đã lưu từ trước) và qua bất
// kỳ hàm nào thêm sau. Một tầng nữa ngay trước lúc dựng
// `Text` là chỗ duy nhất phủ được hết. Xem `lib/core/logic/wr_plain_text.dart`.

/// Lột ký hiệu Markdown, giữ nguyên chữ.
///
/// Mọi màn của WorkReflection dựng bằng `Text` thuần, nên ký hiệu Markdown lọt
/// ra là hiện nguyên hình trên màn hình.
// Vết AI ngoài Markdown (Task B3, khách 01/10): gạch dài và emoji.
//
// - "—" dính liền giữa hai chữ ("speed—it's") và " — " / " – " có cách đều là
//   dấu phẩy ngầm của model, đổi thành ", " (kể cả khi trước là nháy đóng, ngoặc,
//   hoặc chỉ một bên là số). Gạch cách giữa hai SỐ (kể cả số kèm đơn vị ngắn) ("5 – 3", "8h – 17h") là
//   khoảng giá trị thật, giữ nguyên. Gạch kề dấu câu thì chỉ bỏ gạch.
// - Mũi tên U+2190-21FF (↔ →) không phải emoji. Keycap U+20E3 gỡ cùng emoji.
// - "—" đầu dòng là gạch đầu dòng/đối thoại, bỏ.
// - Emoji bỏ cùng U+FE0F và ZWJ mồ côi; © ® ™ không phải emoji trang trí.
// Luật này phải GIỐNG HỆT bản Dart `lib/core/logic/wr_plain_text.dart`.
// Chỉ gọi trên chữ do model sinh ra, không bao giờ trên chữ người dùng.
const EMOJI_RUN =
  /([ \t]*)((?:(?![\u00A9\u00AE\u2122\u2190-\u21FF])\p{Extended_Pictographic}|[\u{1F3FB}-\u{1F3FF}\uFE0F\u200D\u20E3])+)([ \t]*)/gu;

function stripAiTraces(text: string): string {
  return text
    .replace(EMOJI_RUN, (_m, before: string, _e: string, after: string, offset: number, whole: string) => {
      const atLineStart = offset === 0 || whole[offset - 1] === '\n';
      return atLineStart || (!before && !after) ? '' : ' ';
    })
    .replace(/^[ \t]*—[ \t]*/gm, '')
    .replace(/(?<=[\p{L}\p{M}])—(?=[\p{L}\p{M}])/gu, ', ')
    .replace(/[ \t]+[—–](?=[ \t]*[,.;:!?])/g, '')
    .replace(/(?<=[,.;:!?])[ \t]+[—–][ \t]+/g, ' ')
    .replace(/(?<=\S)(?<![ \t])[ \t]+[—–][ \t]+(?!\d)/g, ', ')
    .replace(/(?<=[^\s\d])(?<!\d[\p{L}%]{0,3})[ \t]+[—–][ \t]+(?=\d)/gu, ', ')
    .replace(/[ \t]+(?=[,.;:!?])/g, '')
    .replace(/[ \t]+$/gm, '');
}

export function stripMarkdown(input: string): string {
  // Bỏ ký hiệu Markdown TRƯỚC, lọc vết AI SAU: `**Tốt** — rất` phải lộ ra
  // chữ ngay trước gạch thì luật gạch giữa hai chữ mới khớp.
  return stripAiTraces(stripMdSymbols(input));
}

function stripMdSymbols(input: string): string {
  return input
    // Đậm và nghiêng. Xử lý `***` trước `**` trước `*`, nếu không `**a**` sẽ bị
    // luật một-sao ăn mất một lớp và chừa lại `*a*`.
    .replace(/\*\*\*(.+?)\*\*\*/gs, '$1')
    .replace(/\*\*(.+?)\*\*/gs, '$1')
    .replace(/(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])/gs, '$1')
    // CỐ Ý KHÔNG lột `__đậm__`.
    //
    // Test bắt được: `cột __init__ của tôi` bị biến thành `cột init của tôi`.
    // Không có cách phân biệt `__đậm__` với một tên có gạch dưới ở hai đầu, vì
    // xét về cú pháp chúng là một. Phải chọn bên nào sai thì ít hại hơn.
    //
    // Model này viết đậm bằng `**`, chưa lần nào thấy nó dùng `__`. Còn chữ
    // người dùng dán vào thì hoàn toàn có thể chứa gạch dưới — mà ở
    // `wr-doc-analyze` thì cả một bản JD/CV được dán vào. Nên bỏ quy tắc này:
    // giữ nguyên `__` chỉ để lọt vài dấu gạch dưới hiếm hoi, còn lột nó là âm
    // thầm sửa chữ của người dùng.
    // Tiêu đề `# `, `## `, `### ` ở đầu dòng.
    .replace(/^\s{0,3}#{1,6}\s+/gm, '')
    // Gạch đầu dòng `- `, `* `, `+ ` ở đầu dòng. Giữ lại chữ, bỏ dấu.
    .replace(/^\s{0,3}[-*+]\s+/gm, '')
    // Chữ trong dấu nháy ngược.
    .replace(/`([^`]+)`/g, '$1')
    // Liên kết `[chữ](đường-dẫn)` — giữ chữ, bỏ đường dẫn. Không hàm nào trong
    // hệ thống có lý do phát đường dẫn ra ngoài.
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    // Ba dòng trống trở lên gộp còn một dòng trống.
    .replace(/\n{3,}/g, '\n\n');
}
