// Gợi ý mở lời cho màn trò chuyện, dựng từ chính tình huống người dùng hay chọn.
//
// ---------------------------------------------------------------------------
// VÌ SAO ĐỔI KHỎI DANH SÁCH GÁN CỨNG
//
// Bản đầu gán cứng ba câu: im lặng trong họp, nhận phản hồi khó nghe, làm xong
// việc khó. Ba câu đó viết cho một người dùng trung bình không có thật, và với
// người đã ghi lại hai chục lần về một chuyện hoàn toàn khác thì chúng nói sai
// về chính họ ngay ở màn hình đầu tiên.
//
// Cả sản phẩm dựng trên mệnh đề "AI nhìn thấy mẫu hình". Màn trò chuyện là nơi
// mệnh đề đó dễ kiểm chứng nhất, vì người dùng nhìn thấy gợi ý trước cả khi gõ
// chữ nào. Gợi ý gán cứng ở đúng chỗ đó là tự phủ nhận mình.
//
// ---------------------------------------------------------------------------
// NGUỒN SỰ THẬT
//
// Đọc recentSituationIds, giống mọi tính năng khác cần biết "người này đang
// phản chiếu nhiều về điều gì" (Kiến trúc Dữ liệu v2.0 §4.3). KHÔNG đọc
// `wr_pattern_counts` — xem đầu `wr_repeated_situations.dart` để biết vì sao ba
// bảng từng cho ba con số khác nhau.
//
// ---------------------------------------------------------------------------
// KHÔNG ÁP NGƯỠNG BA LẦN
//
// `kRepeatedSituationsMinCount` = 3 chỉ dành cho phần HIỂN THỊ "Tình huống lặp
// lại", nơi màn hình khẳng định với người dùng rằng một điều đang trở đi trở
// lại. Ở đây không có khẳng định nào: một gợi ý mở lời chỉ là một câu bấm được
// cho đỡ phải gõ.
//
// Áp ngưỡng 3 vào đây sẽ làm phần lớn người dùng mới không bao giờ thấy gợi ý
// của riêng mình, tức là đúng nhóm cần được giữ lại nhất lại nhận bản gán cứng.

import '../models/wr_content.dart';
import 'wr_repeated_situations.dart';

/// Số gợi ý hiện trên màn trống.
const int kChatStarterCount = 3;

/// Danh sách dự phòng, dùng khi người dùng chưa chọn tình huống nào.
///
/// Chọn theo phần "Bắt đúng cảm xúc trước khi đặt câu hỏi" và "Khi nào dẫn vào
/// Reflection thật" của system prompt: đều là tình huống CỤ THỂ đã xảy ra, tức
/// loại chất liệu trợ lý có thể dẫn tiếp vào một Reflection thật.
///
/// Cố ý không có câu nào kiểu "phân tích tôi đi": câu đó thuộc trục Premium, và
/// mời người dùng gõ nó ra là tự dựng một cánh cửa rồi đóng vào mặt họ.
///
/// Cũng cố ý phủ ba nhu cầu nền tảng khác nhau, để người chưa có dữ liệu vẫn
/// gặp được ít nhất một câu chạm đúng.
const List<String> kDefaultChatStarters = [
  'Hôm nay mình im lặng trong một cuộc họp dù có ý kiến khác.',
  'Mình vừa nhận một phản hồi khó nghe từ cấp trên.',
  'Mình làm xong một việc khó hơn mình tưởng.',
];

/// Đổi ngôi "tôi" thành "mình" trong một câu.
///
/// Tiêu đề tình huống trong `wr_situations` viết ở ngôi thứ nhất với đại từ
/// "tôi" ("Tôi biết có vấn đề nhưng không muốn nói"), còn toàn bộ giọng của trợ
/// lý và của màn trò chuyện dùng "mình". Đưa thẳng tiêu đề vào ô chat sẽ tạo ra
/// một câu lệch giọng ngay cạnh những câu dùng "mình".
///
/// ⚠ KHÔNG DÙNG `\b`. Trong Dart, `\b` chỉ hiểu ký tự ASCII, nên nó cắt sai ở
/// ranh giới chữ có dấu — đúng cái bẫy đã làm hỏng một thước đo trước đây. Phải
/// tự khoanh biên bằng lớp ký tự chữ theo Unicode.
///
/// Giữ nguyên hoa thường của chữ đầu: "Tôi" thành "Mình", "tôi" thành "mình".
String vietnameseFirstPerson(String text) => text.replaceAllMapped(
      RegExp(r'(^|[^\p{L}])([Tt])ôi(?![\p{L}])', unicode: true),
      (m) => '${m[1]}${m[2] == 'T' ? 'M' : 'm'}ình',
    );

/// Gợi ý mở lời cho [recent] — recentSituationIds của người dùng.
///
/// Lấy những tình huống được chọn NHIỀU NHẤT, đổi sang tiêu đề tiếng Việt, rồi
/// bù cho đủ [count] bằng [fallback].
///
/// BÙ CHỨ KHÔNG THAY THẾ: người mới có đúng một tình huống vẫn nên thấy đủ ba ô
/// để bấm. Hiện mỗi một ô làm màn hình trông như đang hỏng, và cũng làm lộ ra
/// rằng hệ thống mới biết rất ít về họ — đúng điều không nên nói to ở màn đầu.
///
/// Mã không tra được tiêu đề thì BỎ HẲN, không đưa mã thô ra màn hình: "C3-01"
/// nằm trong danh sách cấm của system prompt, và người dùng cũng chẳng hiểu nó.
List<String> chatStarters({
  required List<String> recent,
  required List<WrSituation> situations,
  int count = kChatStarterCount,
  List<String> fallback = kDefaultChatStarters,
}) {
  final labels = {for (final s in situations) s.code: s.text};
  final out = <String>[];

  for (final r in rankSituations(recent)) {
    if (out.length >= count) break;
    final text = labels[r.situationCode]?.trim();
    if (text == null || text.isEmpty) continue;
    final line = vietnameseFirstPerson(text);
    if (!out.contains(line)) out.add(line);
  }

  for (final f in fallback) {
    if (out.length >= count) break;
    if (!out.contains(f)) out.add(f);
  }

  return out;
}
