// Các bản "Diễn biến" hiện ở màn Nhìn lại dòng thời gian (Premium).
//
// Họp khách 14/10: "đọc dữ liệu thời gian bị đan xen, lặp ngày tháng, không
// đúng trình tự". Gốc lỗi nằm ở dữ liệu chứ không ở cách vẽ: `wr-narrative`
// mỗi lần kể lại đọc 30 lần nhìn lại GẦN NHẤT, nên các bản liền nhau chồng gần
// trọn lên nhau (24/8→08/10, 23/8→07/10, 23/8→01/10…), có quãng ghi tới ba
// bản giống hệt (28/7→25/8). Màn cũ lấy 6 bản mới tạo nhất rồi xếp theo ngày
// tạo, nên người đọc thấy cùng một quãng kể đi kể lại, ngày tháng nhảy lung
// tung.
//
// Luật ở đây: mỗi quãng giữ MỘT bản (bản mới nhất của quãng đó), các quãng giữ
// lại không chồng lên nhau quá [kTimelineStageOverlapDays] ngày, và xếp theo
// thời gian từ cũ đến mới — đúng câu "từ ghi nhận đầu tiên đến hôm nay".

import '../models/wr_intelligence.dart';

/// Hai quãng liền nhau được phép chồng nhau tối đa chừng này ngày. Cửa sổ 30
/// lần nhìn lại trượt theo từng lần, nên đòi tách hẳn thì gần như chỉ còn một
/// bản; cho chồng một tuần thì vẫn ra các chặng nối tiếp nhau.
const int kTimelineStageOverlapDays = 7;

/// Lọc [narratives] (đã đúng ngôn ngữ) thành các chặng nối tiếp, cũ trước.
///
/// Bản không có ngày bị bỏ: không đặt được nó vào dòng thời gian.
List<PatternNarrative> timelineStages(List<PatternNarrative> narratives) {
  final dated = [
    for (final n in narratives)
      if (n.periodStart != null && n.periodEnd != null) n,
  ];
  // Mới nhất trước: quãng kết thúc muộn hơn trước, cùng quãng thì bản tạo sau
  // trước (bản viết lại gần nhất là bản đúng nhất).
  dated.sort((a, b) {
    final byEnd = b.periodEnd!.compareTo(a.periodEnd!);
    if (byEnd != 0) return byEnd;
    final ca = a.createdAt ?? DateTime(0);
    final cb = b.createdAt ?? DateTime(0);
    return cb.compareTo(ca);
  });

  final kept = <PatternNarrative>[];
  for (final n in dated) {
    if (kept.isEmpty) {
      kept.add(n);
      continue;
    }
    final earliestStart = kept.last.periodStart!;
    final limit = earliestStart.add(
      const Duration(days: kTimelineStageOverlapDays),
    );
    // Phải bắt đầu sớm hơn chặng đã giữ và kết thúc trước (hoặc chỉ lấn nhẹ
    // vào) chặng đó.
    if (n.periodStart!.isBefore(earliestStart) &&
        !n.periodEnd!.isAfter(limit)) {
      kept.add(n);
    }
  }
  return kept.reversed.toList();
}
