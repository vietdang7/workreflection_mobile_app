// Lớp 3 — ba rào chắn cho câu AI diễn đạt lại (nhóm C).
//
// Nguồn: `WorkReflection_DienGiaiSau_NoiDung.docx` §7.
//
// §7 mở đầu bằng một câu định nghĩa toàn bộ vai trò của lớp này: "Vai trò duy
// nhất của AI ở đây là viết lại một câu đã hoàn chỉnh cho mượt hơn và bớt lặp.
// AI không nhận dữ liệu thô, không tự phân tích, không tự kết luận."
//
// Nghĩa là câu ĐÚNG đã có sẵn trước khi gọi AI. Lớp 3 chỉ được phép làm câu đó
// dễ đọc hơn, và mọi nghi ngờ đều phải rơi về câu gốc.
//
// ---------------------------------------------------------------------------
// Vì sao ba rào chắn nằm ở app, không chỉ ở Edge Function
// ---------------------------------------------------------------------------
//
// Rào chắn 1 và 2 chạy ở CẢ HAI phía. Không phải để chắc ăn cho vui: câu gốc
// (lớp 2) được dựng TRÊN MÁY từ dữ liệu của chính người dùng, còn Edge Function
// chỉ nhìn thấy chuỗi được gửi lên. Nếu chỉ kiểm ở máy chủ thì lớp 3 vẫn có thể
// hỏng do một bản app cũ gửi sai, do lỗi mạng cắt ngang giữa chừng, hoặc do một
// client khác gọi thẳng hàm. Bên nào giữ được câu gốc thì bên đó phải kiểm.
//
// Rào chắn 3 (thời gian chờ) chỉ ở phía app: chỉ app mới biết người dùng đang
// đứng nhìn màn hình nào.

/// Cờ bật/tắt lớp 3 — §7.3.
///
/// "Có thể bật hoặc tắt lớp này bằng một cờ cấu hình, để nếu chi phí hoặc chất
/// lượng không như mong đợi thì tắt đi mà sản phẩm vẫn chạy nguyên vẹn."
///
/// MẶC ĐỊNH TẮT. Đây là quyết định có chủ đích, không phải sự dè dặt: lớp 3 làm
/// câu chữ dễ đọc hơn nhưng cũng làm nó KHÔNG CÒN ĐỊNH TRƯỚC ĐƯỢC — hai người
/// cùng dữ liệu đọc ra hai câu khác nhau, và không ai đoán được câu nào. Trước
/// khi bật cho người dùng thật, đội nội dung cần đọc một mẻ bản viết lại và
/// khách cần đồng ý với giọng đó.
///
/// Bật khi build:
///   `flutter build apk --dart-define=WR_AI_POLISH=true`
const bool kPolishEnabled = bool.fromEnvironment('WR_AI_POLISH');

/// Trần thời gian chờ AI. §7.2 rào chắn 3.
///
/// "Nếu AI không trả lời trong khoảng 2 giây, dùng luôn câu gốc. Người dùng
/// không bao giờ nhìn thấy màn hình trống hay vòng xoay chờ ở màn này."
const Duration kPolishTimeout = Duration(seconds: 2);

/// Danh sách từ cấm của §7.1 quy tắc 6.
///
/// Ba nhóm, mỗi nhóm bị cấm vì một lý do khác nhau:
///
///   • `mindset`, `bứt phá`, `đột phá`, `thành công` — giọng sách self-help.
///     Đây là app nhìn lại công việc, không phải app tạo động lực.
///   • `burnout`, `trầm cảm`, `rối loạn` — chẩn đoán tâm lý. §7.1 quy tắc 3
///     cấm hẳn, và đây cũng là ranh giới pháp lý: gán một cái tên bệnh cho
///     người dùng dựa trên vài con số tần suất là điều app không có tư cách làm.
const List<String> kPolishBannedWords = [
  'mindset',
  'thành công',
  'bứt phá',
  'đột phá',
  'burnout',
  'trầm cảm',
  'rối loạn',
];

/// Chênh lệch độ dài cho phép so với câu gốc — §7.1 quy tắc 7 ("không quá 20
/// phần trăm").
const double kPolishLengthTolerance = 0.20;

/// Mọi con số trong [text], theo đúng thứ tự xuất hiện.
///
/// Bắt cả số thập phân dấu phẩy lẫn dấu chấm: câu tầng 1 nói "3.8" còn câu
/// tiếng Việt tự nhiên viết "3,8", và model rất hay đổi qua lại giữa hai kiểu.
/// Trả về dạng đã chuẩn hoá về dấu chấm để hai kiểu viết không bị coi là khác
/// nhau — đổi dấu phân cách KHÔNG phải là đổi con số.
List<String> extractNumbers(String text) {
  return [
    for (final m in RegExp(r'\d+(?:[.,]\d+)?').allMatches(text))
      m.group(0)!.replaceAll(',', '.'),
  ];
}

/// Mỗi con số ghép với ĐƠN VỊ đi ngay sau nó, đã sắp xếp.
///
/// ---------------------------------------------------------------------------
/// Vì sao không so con số theo THỨ TỰ XUẤT HIỆN
/// ---------------------------------------------------------------------------
///
/// Bản đầu của rào chắn 1 so hai dãy số theo đúng thứ tự. Nghe thì chặt, nhưng
/// nó huỷ đúng cái việc model được giao:
///
///   gốc:      "Bạn đã nhìn lại 21 lần trong 30 ngày qua, tăng so với 12 lần…"
///   viết lại: "Trong 30 ngày qua bạn nhìn lại 21 lần, nhiều hơn 12 lần…"
///
/// Không con số nào đổi. Chỉ mệnh đề đảo chỗ — mà đảo mệnh đề chính là cách
/// viết lại một câu cho tự nhiên hơn. So theo thứ tự thì phần lớn bản viết lại
/// tốt đều bị huỷ, và lớp 3 thành ra không bao giờ hiện.
///
/// ---------------------------------------------------------------------------
/// Vì sao cũng không so TẬP HỢP số
/// ---------------------------------------------------------------------------
///
/// So tập hợp thì cho qua cả ca nguy hiểm nhất: "3 lần trong 14 ngày" thành
/// "14 lần trong 3 ngày". Cùng tập số, nói hai điều khác hẳn.
///
/// Ghép mỗi số với từ đứng ngay sau nó giữ được cả hai: đảo mệnh đề thì các cặp
/// vẫn y nguyên, còn tráo số giữa hai đơn vị thì cặp đổi và bị bắt.
///
/// Đơn vị lấy thô — một từ, bỏ dấu câu, hạ về chữ thường. Không cần hiểu tiếng
/// Việt: chỉ cần nó ỔN ĐỊNH giữa hai câu nói cùng một điều.
List<String> numberUnitPairs(String text) {
  final pairs = <String>[];
  for (final m in RegExp(r'(\d+(?:[.,]\d+)?)\s*([^\s\d]*)').allMatches(text)) {
    final number = m.group(1)!.replaceAll(',', '.');
    final unit = m
        .group(2)!
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}%]', unicode: true), '');
    pairs.add('$number|$unit');
  }
  pairs.sort();
  return pairs;
}

/// Kết quả soi một câu AI trả về.
enum PolishRejection {
  /// Rỗng, hoặc chỉ có khoảng trắng.
  empty,

  /// Rào chắn 1 — tập con số khác câu gốc.
  numbersChanged,

  /// Rào chắn 2 — dính từ cấm.
  bannedWord,

  /// §7.1 quy tắc 7 — dài hoặc ngắn hơn câu gốc quá 20%.
  lengthDrift,
}

/// Soi câu [polished] so với câu gốc [original].
///
/// Trả null nghĩa là dùng được. Trả một [PolishRejection] nghĩa là huỷ và dùng
/// câu gốc — §7.2: "Cả ba rào chắn đều rơi về cùng một hành vi dự phòng."
PolishRejection? inspectPolished({
  required String original,
  required String polished,
}) {
  final text = polished.trim();
  if (text.isEmpty) return PolishRejection.empty;

  // Rào chắn 1. So các cặp SỐ + ĐƠN VỊ — xem ghi chú dài ở [numberUnitPairs]
  // về việc vì sao không so theo thứ tự và cũng không so tập hợp trần.
  final before = numberUnitPairs(original);
  final after = numberUnitPairs(text);
  if (before.length != after.length) return PolishRejection.numbersChanged;
  for (var i = 0; i < before.length; i++) {
    if (before[i] != after[i]) return PolishRejection.numbersChanged;
  }

  // Rào chắn 2. So không phân biệt hoa thường; không đòi ranh giới từ vì tiếng
  // Việt viết rời ("trầm cảm" là hai âm tiết) và ranh giới từ của regex không
  // hiểu điều đó.
  final lower = text.toLowerCase();
  for (final w in kPolishBannedWords) {
    if (lower.contains(w.toLowerCase())) return PolishRejection.bannedWord;
  }

  // §7.1 quy tắc 7. Đây không phải rào chắn thứ tư mà là cùng một ý với hai rào
  // trên: câu dài gấp rưỡi là model đã THÊM nội dung, câu ngắn một nửa là nó đã
  // BỎ BỚT. Cả hai đều vượt quá việc "viết lại cho mượt hơn".
  final base = original.trim().length;
  if (base > 0) {
    final drift = (text.length - base).abs() / base;
    if (drift > kPolishLengthTolerance) return PolishRejection.lengthDrift;
  }

  return null;
}

/// Câu để hiện lên màn hình: bản AI nếu qua được cả ba rào, không thì câu gốc.
///
/// Đây là hàm DUY NHẤT tầng UI nên gọi. Để tầng UI tự quyết định lấy bản nào là
/// sớm muộn có một màn quên kiểm.
String polishedOrOriginal({
  required String original,
  String? polished,
}) {
  if (polished == null) return original;
  return inspectPolished(original: original, polished: polished) == null
      ? polished.trim()
      : original;
}
