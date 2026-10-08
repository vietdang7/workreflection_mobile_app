// Nắn câu trả lời của model trước khi đưa xuống app.
//
// Ba việc, đều là thứ KHÔNG được phép phó thác cho model nhớ:
//   1. Tách thẻ hành động ra khỏi câu chữ.
//   2. Lột ký hiệu Markdown.
//   3. Ép thẻ "calm" ở nhánh tín hiệu đáng lo ngại.
//
// Nguyên tắc chung: prompt lo phần model làm ĐÚNG, tầng này lo phần model làm
// SAI. Chỉ có một trong hai là không đủ.
//
// Việc 2 đã tách sang `_shared/strip_markdown.ts` ở mục 17.1 (khách 09/09):
// `wr-narrative` và `wr-doc-analyze` cũng trả thẳng chữ model ra màn hình mà
// không có lớp lọc nào. File này vẫn re-export để mọi chỗ đang import từ đây
// không phải đổi.

import { stripMarkdown } from '../_shared/strip_markdown.ts';

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
///
/// NỚI RA 08/10: "Có một bài đọc ngắn trong thư viện có thể giúp bạn dịu lại
/// một chút, muốn thử không?" ra màn hình không có nút (máy thật). Lời mời đứng
/// CUỐI câu, sau danh từ, nên nhánh "động từ trước, danh từ sau" không bắt được.
/// Nhánh mới vẫn đòi đủ hai phần: danh từ nội dung rồi một câu hỏi mời
/// ("thử / xem / đọc không").
const CALM_OFFER_RE =
  /(muốn|thử|gợi ý|giới thiệu|mình có)[^.?!]{0,40}(bài đọc|bài nghe|bài viết|audio|nội dung nhẹ|điều nhẹ nhàng)|thư viện nội dung cảm xúc|(bài đọc|bài viết|điều nhẹ nhàng)[^.?!]{0,80}(thử|xem|đọc) không/i;

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

/// Chính LỜI MỜI ghi lại, chứ không phải câu chỉ vào nút.
///
/// VÌ SAO PHẢI CÓ THÊM: đo thật qua bản deploy ngày 2026-08-04 bắt được một lượt
/// trợ lý viết "có vẻ như việc im lặng này đang lặp lại và đáng để nhìn kỹ hơn,
/// bạn có muốn ghi lại thành một Reflection không?" mà KHÔNG đặt thẻ. Câu đó
/// không chứa chữ "nút" nên [REFLECT_POINTER_RE] không đỡ được, và cũng không có
/// luật nào khác phủ.
///
/// Tức là lưới an toàn đang có một lỗ đúng ở trường hợp PHỔ BIẾN NHẤT: lời mời
/// đầu tiên. Nó chỉ vá được cái đến SAU lời mời, còn chính lời mời thì không.
///
/// Neo vào cụm "ghi lại ... Reflection" vì đó là cách nói của đúng một việc. Vẫn
/// đòi một dấu hiệu MỜI đi kèm (từ để hỏi hoặc dấu hỏi) để câu kể lại chuyện cũ
/// không kích hoạt nhầm.
const REFLECT_INVITE_RE =
  /(muốn|thử)[^.?!]{0,60}ghi lại[^.?!]{0,60}reflection|ghi lại thành (một )?reflection[^.?!]{0,40}\?/i;

/// Trợ lý đang NÓI KHÔNG về việc ghi lại, không phải đang mời.
///
/// Chặn [REFLECT_INVITE_RE] bắt nhầm những câu như "mình không tự ghi lại thành
/// một Reflection thay bạn được". Hiện nút ở đó là mâu thuẫn thẳng với chính câu
/// vừa nói.
const REFLECT_REFUSAL_RE =
  /(không|chưa) (thể |tự |được )?(ghi|lưu)|không có quyền (ghi|lưu)/i;

// ── Bản tiếng Anh của năm mẫu trên ──────────────────────────────────────────
//
// Từ 09/2026 app có tiếng Anh, và khi đó model DỊCH các mẫu câu tiếng Việt của
// prompt ("I have a short reading that might help…", "the button is right
// below"). Năm mẫu ở trên chỉ biết tiếng Việt, nên ở tiếng Anh một lượt quên
// thẻ là ra màn hình không có nút nào — đúng loại lỗi mà cả lớp này dựng lên để
// chặn. Mỗi mẫu dưới đây giữ nguyên yêu cầu của bản tiếng Việt (động từ mời +
// danh từ nội dung, v.v.), chỉ đổi từ vựng. `\b` để "trying to finish reading
// the report" không khớp "try … reading".
//
// App đọc lại lịch sử chat cũng suy nút bằng đúng các mẫu này (bản Dart ở
// `lib/core/logic/wr_chat_offer.dart`). Hai bên cùng chạy bộ ca trong
// `offer_cases.json`, nên sửa một bên mà quên bên kia thì test đỏ.

const RISK_SELF_LIMIT_EN_RE =
  /\bnot an? (licensed |trained )?(therapist|psychologist|counsell?or|mental health (professional|expert))\b/i;

const RISK_REDIRECT_EN_RE =
  /\b(reach out to|talk to|speak (to|with)|contact|turn to)\b[^.?!]{0,90}\b(someone you trust|a friend|friends|family|a professional|a therapist|a counsell?or|a doctor)\b|\b(someone you trust|a friend|family|a professional|a therapist)\b[^.?!]{0,90}\b(right now|right away)\b/i;

const CALM_OFFER_EN_RE =
  /\b(want|would you like|like to|try|suggest|recommend|i have|there is|there's)\b[^.?!]{0,40}\b(short read|reading|article|audio|something (gentle|gentler|calming|lighter))\b|\bemotional content library\b/i;

const REFLECT_POINTER_EN_RE =
  /\b(button|tap)\b[^.?!]{0,50}\b(reflection|below|underneath)\b|\btap (it|that|the button|on it)\b|\bopen (the )?reflection\b/i;

const REFLECT_INVITE_EN_RE =
  /\b(want|would you like|like to|try)\b[^.?!]{0,60}\b(record|write|capture|save|note)\b[^.?!]{0,60}\breflection\b|\b(record|write|capture|save) (it|this|that) (down )?as an? (full )?reflection\b[^.?!]{0,40}\?/i;

const REFLECT_REFUSAL_EN_RE =
  /\b(can ?not|can't|cannot|unable to|not able to)\b[^.?!]{0,20}\b(record|save|write|log)\b/i;

/// Nút mà CÂU CHỮ đang hứa, khi model không đặt thẻ.
///
/// Tách khỏi [shapeReply] để chạy riêng được trên bộ ca dùng chung với app.
/// Thứ tự luật giữ nguyên như trước khi tách: nhánh tín hiệu đáng lo ngại
/// quyết định trước, lời mời ghi lại rộng nhất nên quyết định sau cùng.
export function inferAction(text: string): ChatAction | null {
  if (
    (RISK_SELF_LIMIT_RE.test(text) && RISK_REDIRECT_RE.test(text)) ||
    (RISK_SELF_LIMIT_EN_RE.test(text) && RISK_REDIRECT_EN_RE.test(text))
  ) {
    return 'calm';
  }
  if (CALM_OFFER_RE.test(text) || CALM_OFFER_EN_RE.test(text)) return 'calm';
  if (REFLECT_POINTER_RE.test(text) || REFLECT_POINTER_EN_RE.test(text)) {
    return 'reflect';
  }
  if (
    (REFLECT_INVITE_RE.test(text) && !REFLECT_REFUSAL_RE.test(text)) ||
    (REFLECT_INVITE_EN_RE.test(text) && !REFLECT_REFUSAL_EN_RE.test(text))
  ) {
    return 'reflect';
  }
  return null;
}

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
  // Nội dung Cảm xúc; các lời mời nhẹ hơn và lời mời ghi lại cũng vậy: câu chữ
  // đã hứa một nút thì nút phải có thật. Nếu model QUÊN đặt thẻ, ta tự đặt —
  // chỗ duy nhất trong cả hệ thống ép một nút mà model không yêu cầu. Chi tiết
  // từng luật ở các hằng phía trên, thứ tự ở [inferAction].
  if (action === null) action = inferAction(text);

  return { text: text.trim(), action };
}

// `stripMarkdown` đã chuyển sang `_shared/strip_markdown.ts` — xem đầu file.
export { stripMarkdown };

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
