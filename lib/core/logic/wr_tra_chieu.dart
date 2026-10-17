// Trà Chiều Nghề Nghiệp — chương trình offline riêng của WorkReflection.
//
// Họp khách 2026-07-29:
//   • Không đẩy toàn bộ workshop của web app sang. Trà Chiều là một chương
//     trình riêng, "tới đó mọi người cũng chỉ phản chiếu trải nghiệm công việc
//     của mình", tức là chính trải nghiệm của app nhưng nói thành lời.
//   • Dùng CHUNG cơ sở dữ liệu với web app (`cc_workshops`), khách tạo buổi ở
//     web, app chỉ đọc. Không dựng màn tạo mới trong app.
//   • Hiển thị CHỮ, tuyệt đối không ảnh: "chị đang muốn nhìn chữ mà được làm
//     cho nó dễ nhìn hơn là có hình vô. Tại vì khi có hình vô là mình phải tổ
//     chức hình trong này như thế nào cho dễ nhìn, chứ không nó bị co hình lại."
//   • Bấm "Xem chi tiết" mới link sang web app.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

import '../l10n/wr_tr.dart';
import '../models/workshop_models.dart';

/// Địa chỉ web app dùng cho nút "Xem chi tiết".
///
/// Đổi được lúc build mà không phải sửa code:
/// `flutter build apk --dart-define=WEB_APP_BASE_URL=https://...`
const String kWebAppBaseUrl = String.fromEnvironment(
  'WEB_APP_BASE_URL',
  defaultValue: 'https://www.workreflection.app',
);

/// Đường dẫn web của một buổi Trà Chiều.
///
/// Khuôn đúng là `/services/workshops/<slug hoặc id>` — khách 2026-07-30 gửi
/// link thật: `https://www.workreflection.app/services/workshops/test-1`.
/// Bản trước ghép `cloudandcoral.com/workshops/<id>`, sai cả tên miền lẫn
/// đường dẫn nên bấm vào ra trang 404.
///
/// Route bên web (`/services/workshops/:id`) tự phân biệt UUID với slug, nên
/// truyền slug khi có là ra đúng link người dùng chia sẻ được.
String traChieuWebUrl(String workshopIdOrSlug) =>
    '$kWebAppBaseUrl/services/workshops/$workshopIdOrSlug';

/// Tham số đường dẫn của một buổi: slug nếu web đã đặt, không thì UUID.
String traChieuUrlKey(WorkshopDetail workshop) {
  final slug = workshop.slug?.trim();
  return slug == null || slug.isEmpty ? workshop.id : slug;
}

/// Link Zalo để giữ chỗ — khách 2026-07-30: "hoặc dẫn trực tiếp đến Zalo để
/// đăng ký tham gia".
///
/// Mặc định là số Zalo 0866883047 ('https://zalo.me/0866883047').
/// Đặt lúc build nếu muốn override:
/// `flutter build apk --dart-define=TRA_CHIEU_ZALO_URL=https://zalo.me/...`
const String kTraChieuDefaultZaloUrl = 'https://zalo.me/0866883047';

const String kTraChieuZaloUrl = String.fromEnvironment(
  'TRA_CHIEU_ZALO_URL',
  defaultValue: kTraChieuDefaultZaloUrl,
);

/// Nhãn hiển thị của chương trình — dùng chung ở mọi nơi nhắc tới nó.
String get kTraChieuLabel => tr('Trà Chiều Nghề Nghiệp', 'Career Tea Time');

/// Khuôn buổi — ba con số nói hết định dạng, dùng ở cả thẻ mời và màn chi tiết.
///
/// Đây là quy ước của chương trình, không phải dữ liệu từng buổi: mọi buổi đều
/// cùng số người, cùng thời lượng.
/// Dòng khuôn dưới tên chương trình (script `screenTraChieu`).
String get kTraChieuFormatLabel => tr(
  '10 đến 12 người · 2 tiếng · 1 câu hỏi.',
  '10 to 12 people · 2 hours · 1 question.',
);

/// Mô tả trên thẻ ở tab Phát triển (script Sprint 2).
String get kTraChieuCardDescription => tr(
  'Một buổi gặp ngoài đời thật. Không hội thảo, không sân khấu, chỉ ngồi quanh một bàn trà.',
  'A real-life gathering. No seminar, no stage, just sitting around a tea table.',
);

/// Dòng dưới tên chương trình ở thẻ tab Phát triển (mặc định nếu không có buổi từ DB).
String get kTraChieuCardLine => tr(
  'T7 22/08 · 10 đến 12 người · 2 giờ',
  'Sat 22/08 · 10 to 12 people · 2 hours',
);

/// Danh sách các buổi Trà Chiều mẫu từ script Sprint 2 (`TRA_CHIEU_SESSIONS`).
class TraChieuSessionItem {
  final String id;
  final String date;
  final String label;
  final String topic;
  final String? dim;
  final String? note;
  final bool publicSession;

  const TraChieuSessionItem({
    required this.id,
    required this.date,
    required this.label,
    required this.topic,
    this.dim,
    this.note,
    this.publicSession = true,
  });
}

const List<TraChieuSessionItem> kDefaultTraChieuSessions = [
  TraChieuSessionItem(id: 'TC1', date: '22/08/2026', label: 'T7 22/08', topic: 'Bận cả tuần, nhưng mình đang đi về đâu?'),
  TraChieuSessionItem(id: 'TC2', date: '05/09/2026', label: 'T7 05/09', topic: 'Nói không với sếp mà không thấy có lỗi', dim: 'C2'),
  TraChieuSessionItem(id: 'TC3', date: '19/09/2026', label: 'T7 19/09', topic: 'Khi nào nên ở lại, khi nào nên đi?', dim: 'A1'),
  TraChieuSessionItem(id: 'TC4', date: '03/10/2026', label: 'T7 03/10', topic: 'Mình làm tốt việc này, nhưng có thích nó không?', dim: 'S1'),
  TraChieuSessionItem(id: 'TC5', date: '17/10/2026', label: 'T7 17/10', topic: 'Cảm giác bị bỏ lại sau lưng', dim: 'A2'),
  TraChieuSessionItem(id: 'TC6', date: '24/10/2026', label: 'T7 24/10', topic: 'Thứ khiến bạn cạn năng lượng nhất tuần qua'),
  TraChieuSessionItem(id: 'TC7', date: '31/10/2026', label: 'T7 31/10', topic: 'Một điều bạn học được từ người ngồi cạnh', note: 'Mời lại người dự cũ'),
  TraChieuSessionItem(id: 'TC8', date: '14/11/2026', label: 'T7 14/11', topic: 'Nói thật trong team, vì sao khó đến vậy?', dim: 'C2'),
  TraChieuSessionItem(id: 'TC9', date: '21/11/2026', label: 'T7 21/11', topic: 'Nhìn lại 10 tháng: mình đã thay đổi gì?', dim: 'A3'),
  TraChieuSessionItem(id: 'TC10', date: '05/12/2026', label: 'T7 05/12', topic: 'Điều mình muốn giữ, điều muốn để lại', dim: 'A1'),
  TraChieuSessionItem(id: 'TC11', date: '19/12/2026', label: 'T7 19/12', topic: 'Trà Chiều Retrospective: nhìn lại 2026', note: 'Buổi lớn hơn, 12 đến 14 người'),
];

/// Địa điểm khi buổi chưa có địa chỉ (script `screenTraChieu`).
String get kTraChieuNoVenue => tr(
  'TP.HCM, địa điểm sẽ thông báo sau',
  'Ho Chi Minh City, venue to be announced',
);

/// Các giá trị `category` được coi là Trà Chiều.
///
/// Nhiều biến thể vì web app và app mobile không cùng một người nhập liệu: dấu
/// tiếng Việt, gạch nối hay khoảng trắng đều có thể xuất hiện. Thà nhận rộng
/// còn hơn để một buổi đã tạo không bao giờ hiện ra trên điện thoại.
/// Ô "Danh mục" bên web là một Select cố định, và nhãn của nó chạy qua i18n:
/// tiếng Việt lưu xuống "Trà chiều Nghề nghiệp", tiếng Anh lưu xuống "Career
/// Afternoon Tea" (`src/i18n/translations/{vi,en}.ts` → `trChiUNghNghiP`). Ai
/// tạo buổi lúc web đang để tiếng Anh thì `category` xuống DB là bản tiếng Anh,
/// nên phải nhận cả hai — không thì buổi đó có thật mà điện thoại không thấy.
const Set<String> kTraChieuCategoryKeys = {
  'tra chieu',
  'tra chieu nghe nghiep',
  'workreflection tra chieu',
  'wr tra chieu',
  'career afternoon tea',
};

/// Bỏ dấu tiếng Việt và chuẩn hoá về chữ thường, gạch nối thành khoảng trắng.
///
/// Chỉ đủ dùng cho việc so khớp nhãn phân loại — không phải một bộ chuẩn hoá
/// Unicode đầy đủ.
String normalizeCategory(String value) {
  const marks = {
    'àáạảãâầấậẩẫăằắặẳẵ': 'a',
    'èéẹẻẽêềếệểễ': 'e',
    'ìíịỉĩ': 'i',
    'òóọỏõôồốộổỗơờớợởỡ': 'o',
    'ùúụủũưừứựửữ': 'u',
    'ỳýỵỷỹ': 'y',
    'đ': 'd',
  };
  var out = value.toLowerCase().trim();
  for (final entry in marks.entries) {
    for (final ch in entry.key.split('')) {
      out = out.replaceAll(ch, entry.value);
    }
  }
  return out.replaceAll(RegExp(r'[-_]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
}

/// True khi [workshop] thuộc chương trình Trà Chiều.
bool isTraChieu(WorkshopDetail workshop) {
  final category = workshop.category;
  if (category == null || category.isEmpty) return false;
  return kTraChieuCategoryKeys.contains(normalizeCategory(category));
}

/// Các buổi Trà Chiều chưa diễn ra, sắp theo ngày gần nhất trước.
///
/// [now] truyền vào để test cố định được; production truyền `DateTime.now()`.
/// So sánh theo NGÀY chứ không theo giờ: buổi diễn ra chiều nay vẫn là buổi
/// sắp tới cho tới hết ngày.
List<WorkshopDetail> upcomingTraChieu(
  List<WorkshopDetail> workshops, {
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  return workshops.where(isTraChieu).where((w) {
    final d = DateTime(w.date.year, w.date.month, w.date.day);
    return !d.isBefore(today);
  }).toList()..sort((a, b) => a.date.compareTo(b.date));
}

/// Buổi gần nhất sắp diễn ra, hoặc null khi chưa có buổi nào được mở.
WorkshopDetail? nextTraChieu(
  List<WorkshopDetail> workshops, {
  required DateTime now,
}) => upcomingTraChieu(workshops, now: now).firstOrNull;

/// Vị trí chèn mục Trà Chiều vào danh sách chủ đề thực hành.
///
/// Họp khách 2026-07-29: "em thêm cho chị một cái tab là trà chiều nghề nghiệp
/// … nó ở giữa tư duy hệ thống với AI. Nó sau tư duy hệ thống được."
///
/// [titles] là tiêu đề các chủ đề theo đúng thứ tự đang hiển thị. Trả về chỉ số
/// ngay SAU chủ đề "Tư duy hệ thống". Không tìm thấy chủ đề mỏ neo — thư viện
/// đổi, hoặc người dùng đã ghi danh nó nên nó không còn trong danh sách — thì
/// trả về cuối danh sách: chèn bừa vào giữa còn khó hiểu hơn là để cuối.
int traChieuInsertIndex(List<String> titles) {
  const anchor = 'tu duy he thong';
  for (var i = 0; i < titles.length; i++) {
    if (normalizeCategory(titles[i]).contains(anchor)) return i + 1;
  }
  return titles.length;
}

/// Giá hiển thị của một buổi — "Miễn phí" khi bằng 0.
///
/// Định dạng nghìn bằng dấu chấm theo cách viết tiếng Việt: 99000 → "99.000đ".
String traChieuPriceLabel(WorkshopDetail workshop) {
  if (workshop.price == 0) return tr('Miễn phí', 'Free');
  final amount = workshop.price.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < amount.length; i++) {
    if (i > 0 && (amount.length - i) % 3 == 0) buffer.write('.');
    buffer.write(amount[i]);
  }
  final suffix = workshop.currency.toUpperCase() == 'VND'
      ? 'đ'
      : ' ${workshop.currency}';
  return '$buffer$suffix';
}

/// Dòng giá trên thẻ buổi: "Giữ chỗ 99.000đ", hoặc chỉ "Miễn phí".
///
/// Buổi miễn phí không ghép tiền tố: "Giữ chỗ Miễn phí" là một câu không ai nói.
String traChieuSeatLabel(WorkshopDetail workshop) => workshop.price == 0
    ? traChieuPriceLabel(workshop)
    : tr(
        'Giữ chỗ ${traChieuPriceLabel(workshop)}',
        'Reserve a spot ${traChieuPriceLabel(workshop)}',
      );

/// Ngày giờ hiển thị: "T7 22/08, 15:30 – 17:30" — bỏ phần nào không có dữ liệu.
String traChieuWhenLabel(WorkshopDetail workshop) {
  const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final d = workshop.date;
  final day =
      '${weekdays[d.weekday - 1]} '
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';

  String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  final start = workshop.startsAt;
  if (start == null) return day;
  final end = workshop.endsAt;
  return end == null
      ? '$day, ${hhmm(start)}'
      : '$day, ${hhmm(start)} – ${hhmm(end)}';
}

/// Tiêu đề thẻ Trà Chiều ở tab Phát triển (script: `${ev.label} · 15:00`):
/// "T7 08/08 · 15:00" theo giờ bắt đầu thật của buổi; buổi chưa có giờ thì chỉ
/// ghi ngày.
String traChieuCardLabel(WorkshopDetail workshop) {
  const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final d = workshop.date;
  final day =
      '${weekdays[d.weekday - 1]} '
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';
  final start = workshop.startsAt;
  if (start == null) return day;
  final t = start.toLocal();
  return '$day · ${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}
