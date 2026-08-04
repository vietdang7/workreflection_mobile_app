// Nắn câu trả lời của model trước khi đưa xuống app.
//
// Ba việc, đều là thứ KHÔNG được phép phó thác cho model nhớ:
//   1. Tách thẻ hành động ra khỏi câu chữ.
//   2. Lột ký hiệu Markdown.
//   3. Ép thẻ "calm" ở nhánh tín hiệu đáng lo ngại.
//
// Nguyên tắc chung: prompt lo phần model làm ĐÚNG, tầng này lo phần model làm
// SAI. Chỉ có một trong hai là không đủ.

/// Hai hành động app mở được từ một bong bóng trả lời.
export type ChatAction = 'reflect' | 'calm';

export type ShapedReply = {
  /// Chữ đã sạch, đưa thẳng lên màn hình.
  text: string;
  /// Nút cần hiện dưới bong bóng, hoặc null.
  action: ChatAction | null;
};

/// Bắt thẻ `[[ACTION:xxx]]` ở bất kỳ đâu trong câu trả lời.
///
/// Cố ý KHÔNG neo vào cuối chuỗi dù prompt bảo đặt ở dòng cuối: model đôi khi
/// đặt giữa bài hoặc kèm thêm một câu sau đó. Bắt ở mọi vị trí thì thẻ luôn
/// được gỡ sạch, còn neo vào cuối thì một lần đặt sai chỗ là người dùng đọc
/// thấy nguyên chuỗi `[[ACTION:calm]]` trên màn hình.
const ACTION_RE = /\[\[ACTION:(reflect|calm)\]\]/gi;

/// Dấu hiệu model đang chạy nhánh "Xử lý tín hiệu đáng lo ngại".
///
/// Bắt theo câu TỰ GIỚI HẠN của trợ lý, không bắt theo lời người dùng: câu này
/// do chính model viết ra khi nó nhận ra tình huống nghiêm trọng, nên nó là tín
/// hiệu đáng tin hơn việc ta tự dò từ khoá trong câu người dùng gõ.
///
/// ĐÒI HAI DẤU HIỆU, không chỉ một.
///
/// Bản đầu chỉ bắt câu tự giới hạn, và bộ 20 ca ngày 2026-08-03 cho thấy nó bắt
/// nhầm: lượt TỪ CHỐI jailbreak cũng chứa "mình không phải chuyên gia tâm lý hay
/// tư vấn nghề nghiệp" — đó là câu minh bạch về bản thân ở nguyên tắc 11, không
/// phải nhánh tín hiệu đáng lo ngại. Kết quả là người dùng vừa bị từ chối một
/// trò nghịch prompt thì thấy hiện nút "dịu lại", vô duyên và làm nút mất nghĩa.
///
/// Phần 2 của nhánh đó BUỘC phải hướng về người thật, nên mọi lượt thật đều có
/// cả hai. Đòi cả hai vừa giữ nguyên độ phủ, vừa cắt hẳn lớp bắt nhầm.
const RISK_SELF_LIMIT_RE = /không phải (là )?(một )?chuyên gia tâm lý/i;
///
/// Phải đòi một ĐỘNG TỪ TÌM ĐẾN đi kèm, không chỉ đòi tên một loại người. Bản
/// đầu nhận cả "đồng hành" làm dấu hiệu và lập tức bắt nhầm chính câu trợ lý tự
/// giới thiệu: "chỉ là một người bạn ĐỒNG HÀNH biết lắng nghe". Test bắt được
/// trước khi lên bản chạy.
///
/// NỚI RA Ở v1.2, sau khi đối chiếu từng mẫu của tài liệu Conversation Examples
/// với chính regex này. Mẫu "tín hiệu diễn đạt kiểu ẩn dụ" KHÔNG khớp bản cũ vì
/// hai lý do cộng lại: nó viết "ngay lúc này" thay vì "ngay bây giờ", và khoảng
/// cách từ danh từ tới động từ vượt 50 ký tự. Tức là ca ẩn dụ, đúng loại ca mà
/// dò từ khoá dễ bỏ sót nhất, lại là ca duy nhất lọt lưới.
///
/// Hai thay đổi, đều giữ nguyên yêu cầu "phải có cả danh từ lẫn động từ":
///   • Nhận thêm các biến thể chỉ thời điểm: "ngay lúc này", "lúc này".
///   • Nới cửa sổ 50 lên 90 ký tự. Câu tiếng Việt tự nhiên hay chèn một mệnh đề
///     phụ vào giữa ("nếu có ai đó bạn tin tưởng có thể nói chuyện...").
const RISK_REDIRECT_RE =
  /(tìm đến|tìm tới|nói chuyện với|chia sẻ với|liên hệ)[^.?!]{0,90}(người thân|bạn bè|người bạn|chuyên gia)|(người thân|bạn bè|người bạn|ai đó|chuyên gia tâm lý)[^.?!]{0,90}(tìm đến|tìm tới|ngay bây giờ|ngay lúc này|lúc này)/i;

/// Lời mời đọc hoặc nghe một nội dung để dịu lại, ở những lượt NHẸ hơn nhánh
/// "Xử lý tín hiệu đáng lo ngại".
///
/// Đo 64 lượt ngày 2026-08-03: có 1 lượt trợ lý hỏi "bạn có muốn thử một bài đọc
/// ngắn để dịu lại một chút không" mà quên đặt thẻ. Tỉ lệ nhỏ, nhưng hậu quả thì
/// không nhỏ theo tỉ lệ: người dùng đọc thấy một đề nghị rồi không bấm được gì,
/// và lượt đó rơi vào đúng lúc họ đang mệt.
///
/// Đòi HAI phần cùng lúc, một động từ mời và một danh từ nội dung, nên câu chỉ
/// nhắc ngang qua ("hôm trước bạn có nghe một bài") không kích hoạt nhầm. Ép
/// nhầm một nút hại hơn thiếu nút: nút hiện ra không đúng chỗ dạy người dùng
/// rằng nút ở đây là vô nghĩa.
///
/// Hai dạng, vì trợ lý mời theo hai kiểu câu khác nhau:
///
///   • Hỏi:      "bạn có MUỐN thử một BÀI ĐỌC ngắn không"
///   • Trần thuật: "CÓ MỘT BÀI ĐỌC ngắn trong THƯ VIỆN NỘI DUNG CẢM XÚC"
///
/// Vòng đo đầu chỉ bắt dạng hỏi nên vẫn lọt 2 lượt dạng trần thuật. Nhắc đúng
/// tên Thư viện Nội dung Cảm xúc là tín hiệu chắc chắn: trợ lý không có lý do
/// nào khác để gọi tên một phần của app ra giữa câu.
///
/// NỚI RA Ở v1.2. Mẫu "mệt mỏi thông thường" của tài liệu viết "mình có vài
/// điều nhẹ nhàng có thể giúp bạn dịu lại" — một lời mời rõ ràng, nhưng danh từ
/// nội dung thì mơ hồ nên bản cũ không bắt được, và lượt đó ra màn hình không có
/// nút nào. Tài liệu v1.2 đã sửa mẫu để gọi tên "bài đọc ngắn", nhưng model vẫn
/// tự do diễn đạt, nên nới thêm ở đây là hàng rào thứ hai.
///
/// Thêm "điều nhẹ nhàng" và "bài viết" vào nhóm danh từ. VẪN đòi một động từ mời
/// đi kèm trong 40 ký tự, nên câu chỉ nhắc ngang qua không kích hoạt nhầm.
const CALM_OFFER_RE =
  /(muốn|thử|gợi ý|giới thiệu|mình có)[^.?!]{0,40}(bài đọc|bài nghe|bài viết|audio|nội dung nhẹ|điều nhẹ nhàng)|thư viện nội dung cảm xúc/i;

/// Trợ lý đang CHỈ VÀO cái nút mở luồng Reflection.
///
/// Khách gặp 2026-08-03: sau khi họ nói "có", trợ lý trả lời "nút mở luồng
/// Reflection đang hiện ngay dưới đây, bạn bấm vào đó nhé" mà KHÔNG đặt thẻ, nên
/// dưới bong bóng chẳng có nút nào. Chỉ vào một thứ không tồn tại còn tệ hơn im
/// lặng: người dùng tìm quanh màn hình rồi nghĩ app hỏng.
///
/// Đây là tín hiệu chắc chắn, không cần đoán: trợ lý không có lý do nào khác để
/// nhắc tới "nút" giữa một cuộc trò chuyện.
///
/// NỚI RA Ở v1.2: thêm nhánh "mở luồng". Bản cũ của tài liệu có mẫu "mình mở
/// luồng Reflection cho bạn ngay" — câu đó không chứa chữ "nút" nên lọt lưới,
/// và nó còn sai về bản chất vì trợ lý không tự mở được màn nào. Tài liệu v1.2
/// đã sửa mẫu thành câu chỉ vào nút, nhưng model vẫn có thể diễn đạt theo lối
/// cũ, nên bắt luôn cả cách nói đó.
const REFLECT_POINTER_RE =
  /(nút|bấm vào)[^.?!]{0,50}(reflection|luồng|ngay dưới|bên dưới|phía dưới)|bấm vào (nút|đó)|mở luồng (reflection|nhìn lại)/i;

/// Gỡ thẻ, lột Markdown, và áp luật an toàn.
export function shapeReply(raw: string): ShapedReply {
  let action: ChatAction | null = null;

  // Lấy thẻ ĐẦU TIÊN. Prompt bảo mỗi lượt nhiều nhất một thẻ; nếu model đặt hai
  // thì lấy cái đầu và bỏ phần còn lại, thay vì hiện hai nút mâu thuẫn nhau.
  const found = [...raw.matchAll(ACTION_RE)];
  if (found.length > 0) {
    action = found[0][1].toLowerCase() as ChatAction;
  }

  // Gộp khoảng trắng thừa do gỡ thẻ để lại. Model đôi khi đặt thẻ GIỮA câu chứ
  // không ở dòng cuối như prompt dặn, và khi đó chỗ vừa gỡ chừa lại hai dấu cách
  // liền nhau giữa câu chữ.
  let text = raw.replace(ACTION_RE, '').replace(/[ \t]{2,}/g, ' ');
  text = stripMarkdown(text);

  // ── Luật an toàn ────────────────────────────────────────────────────────
  //
  // Bước 3 của phần "Xử lý tín hiệu đáng lo ngại" buộc phải đề nghị Thư viện
  // Nội dung Cảm xúc. Nếu model chạy đúng nhánh đó mà QUÊN đặt thẻ, ta tự đặt.
  //
  // Đây là chỗ duy nhất trong cả hệ thống ép một nút mà model không yêu cầu, và
  // nó đáng: lượt này xảy ra đúng lúc người dùng đang tệ nhất, và thứ tệ nhất
  // ta có thể làm là đề nghị giúp rồi không mở được gì.
  if (
    action === null &&
    RISK_SELF_LIMIT_RE.test(text) && RISK_REDIRECT_RE.test(text)
  ) {
    action = 'calm';
  }

  // Cùng lý lẽ, cho những lượt nhẹ hơn: đã mời đọc gì đó cho dịu lại thì phải
  // mở được. Đặt SAU luật trên để nhánh tín hiệu đáng lo ngại luôn quyết định.
  if (action === null && CALM_OFFER_RE.test(text)) {
    action = 'calm';
  }

  // Và nếu trợ lý đang chỉ vào cái nút mở luồng Reflection thì cái nút đó phải
  // có thật. Đặt cuối cùng: hai luật trên nói về nội dung cảm xúc, luật này chỉ
  // dọn nốt trường hợp trợ lý nhắc tới nút mà quên đặt thẻ.
  if (action === null && REFLECT_POINTER_RE.test(text)) {
    action = 'reflect';
  }

  return { text: text.trim(), action };
}

/// Lột ký hiệu Markdown, giữ nguyên chữ.
///
/// Bong bóng chat dựng bằng `Text` thuần nên mọi ký hiệu sẽ hiện nguyên hình.
/// Prompt đã bảo model viết chữ thuần, nhưng nó quên rải rác — quan sát
/// 2026-08-03: 1 trên 4 câu trả lời dài có `**...**`. Prompt lo phần thường
/// xuyên, hàm này lo phần còn lại.
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
    // người dùng dán vào thì hoàn toàn có thể chứa gạch dưới. Nên bỏ quy tắc
    // này: giữ nguyên `__` chỉ để lọt vài dấu gạch dưới hiếm hoi, còn lột nó là
    // âm thầm sửa chữ của người dùng.
    // Tiêu đề `# `, `## `, `### ` ở đầu dòng.
    .replace(/^\s{0,3}#{1,6}\s+/gm, '')
    // Gạch đầu dòng `- `, `* `, `+ ` ở đầu dòng. Giữ lại chữ, bỏ dấu.
    .replace(/^\s{0,3}[-*+]\s+/gm, '')
    // Chữ trong dấu nháy ngược.
    .replace(/`([^`]+)`/g, '$1')
    // Liên kết `[chữ](đường-dẫn)` — giữ chữ, bỏ đường dẫn. Trợ lý không có lý
    // do gì để phát đường dẫn ra ngoài.
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    // Ba dòng trống trở lên gộp còn một dòng trống.
    .replace(/\n{3,}/g, '\n\n');
}

/// Tiêu đề cuộc trò chuyện, lấy từ câu đầu tiên người dùng gõ.
///
/// Cắt ở ranh giới TỪ, không cắt giữa chữ: "Hôm nay mình bị sếp nhắc trước cả
/// phò…" đọc như một lỗi hiển thị, không như một tiêu đề.
export function conversationTitle(firstMessage: string, max = 60): string {
  const clean = firstMessage.replace(/\s+/g, ' ').trim();
  if (clean.length <= max) return clean;
  const cut = clean.slice(0, max);
  const lastSpace = cut.lastIndexOf(' ');
  return `${(lastSpace > max * 0.6 ? cut.slice(0, lastSpace) : cut).trim()}…`;
}
