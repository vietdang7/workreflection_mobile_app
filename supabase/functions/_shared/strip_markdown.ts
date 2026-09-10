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
// cũng vào app qua `ai-personalize` (hàm của phần Khảo sát, không nằm trong
// repo này) và qua bất kỳ hàm nào thêm sau. Một tầng nữa ngay trước lúc dựng
// `Text` là chỗ duy nhất phủ được hết. Xem `lib/core/logic/wr_plain_text.dart`.

/// Lột ký hiệu Markdown, giữ nguyên chữ.
///
/// Mọi màn của WorkReflection dựng bằng `Text` thuần, nên ký hiệu Markdown lọt
/// ra là hiện nguyên hình trên màn hình.
export function stripMarkdown(input: string): string {
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
