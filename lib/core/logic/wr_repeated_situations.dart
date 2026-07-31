// recentSituationIds — nguồn sự thật DUY NHẤT cho câu hỏi "người này đang phản
// chiếu nhiều về điều gì".
//
// Kiến trúc Dữ liệu Hai Lớp v2.0 §4.3, "Nguyên tắc bắt buộc: một nguồn sự thật
// duy nhất":
//
//   "recentSituationIds không chỉ phục vụ xoay vòng. Đây là bản ghi lịch sử
//    Reflect thật của một người, và là nguồn duy nhất được phép dùng cho mọi
//    tính năng cần biết 'người này đang phản chiếu nhiều về điều gì': chiều
//    hoạt động nhiều nhất cho gợi ý Practice Theme (§XIII), đối chiếu chủ đề
//    Trà Chiều (§XII), và các khối hiển thị ở tab Hiểu (§IX) là 'Điều bạn đang
//    tìm kiếm' (Nhu cầu chủ đạo) và 'Tình huống lặp lại'."
//
// VÌ SAO PHẢI CÓ QUY TẮC NÀY. Trước bản 2026-07-31 có BA bảng cùng trả lời câu
// hỏi đó, và trên DB thật chúng cho ba con số khác nhau cho CÙNG một tình
// huống của cùng một người:
//
//     wr_pattern_counts        S1-sit-01 = 4
//     wr_career_memory_events  S1-sit-01 = 3
//     wr_reflection_episodes   S1-sit-01 = 1
//
// Chênh lệch đến từ chỗ mỗi bảng được ghi ở một thời điểm khác nhau trong
// luồng, cộng thêm một màn cũ (`/wr/situation`, Sprint 1) cộng thẳng vào
// wr_pattern_counts mà không tạo Episode nào. Màn hình đọc bảng nào thì ra con
// số của bảng đó, và không ai đối chiếu được.
//
// ĐƠN VỊ VÀ THỜI ĐIỂM. §4.3 nói rõ recentSituationIds "ghi nhận thời điểm CHỌN
// tình huống (bước Notice), không phải thời điểm hoàn tất trọn vẹn một
// Reflection". Điều đó đã đúng sẵn trong schema: `recordPattern` vá
// `situation_code` vào Episode ngay ở bước Notice
// (`wr_episode_repository.dart`). Nên bảng Episode CHÍNH LÀ recentSituationIds
// — không cần bảng mới, và cũng không được lọc theo trạng thái đã khép: bỏ dở
// giữa chừng thì tình huống vẫn đã được chọn.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

import '../models/wr_episode.dart';

/// Số mục gần nhất được giữ trong recentSituationIds (v2.0 §4.1: "tối đa 30
/// mục gần nhất, mới nhất đứng đầu").
const int kRecentSituationsWindow = 30;

/// Số dòng "Tình huống lặp lại" hiện ở tab Hiểu (v2.0 §4.3: "lấy ba tình huống
/// có số lần cao nhất").
const int kRepeatedSituationsTop = 3;

/// Số lần tối thiểu để một tình huống được gọi là "đang trở đi trở lại".
///
/// Yêu cầu khách 2026-07-31: "phần tình huống lặp lại chỉ hiện từ 3 lần trở
/// lên, cái nào được chọn nhiều thì hiển thị lên".
///
/// Vì sao cần ngưỡng, dù §4.3 không nói tới: gặp một lần là một chuyện đã xảy
/// ra, chưa phải một nếp. Không chặn thì màn "Những điều đang trở đi trở lại"
/// dài ra bằng đúng số tình huống khác nhau người dùng từng chạm, toàn dòng
/// "1 lần" — và cái đang thật sự trở đi trở lại chìm giữa chúng, đúng ngược
/// với việc màn này sinh ra để làm.
///
/// PHẠM VI: chỉ chặn phần HIỂN THỊ "Tình huống lặp lại" (tab Hiểu mình và màn
/// đầy đủ). Mọi thứ khác đọc recentSituationIds — nhu cầu chủ đạo, tỉ trọng ba
/// trụ, gợi ý Practice Theme, thẻ "Hệ thống nhận ra" ở Hôm nay — vẫn đếm từ
/// lần đầu tiên. Đưa ngưỡng này xuống tầng dữ liệu là làm mù luôn những chỗ đó.
const int kRepeatedSituationsMinCount = 3;

/// Một tình huống trong recentSituationIds, kèm số lần xuất hiện.
class RepeatedSituation {
  const RepeatedSituation({required this.situationCode, required this.count});

  final String situationCode;
  final int count;
}

/// Mã tình huống người dùng đã chọn, mới nhất đứng đầu, tối đa [window].
///
/// [episodes] không cần sắp sẵn. Sắp theo `openedAt` — thời điểm phiên bắt đầu,
/// tức sát nhất với lúc người dùng chọn tình huống ở bước Notice. KHÔNG sắp
/// theo `updatedAt`: mỗi bước sau đều vá lại Episode nên `updatedAt` trôi theo
/// bước cuối cùng, và một phiên viết dài sẽ nhảy lên trước một phiên bắt đầu
/// sau nó.
///
/// Không lọc theo trạng thái: §4.3 tính từ lúc CHỌN, nên một phiên bỏ dở vẫn
/// đóng góp đúng cái tình huống đã được chọn. Phiên tự viết không có mã nào —
/// bỏ qua, không gộp thành một nhóm "khác" giả.
List<String> recentSituationIds(
  List<ReflectionEpisode> episodes, {
  int window = kRecentSituationsWindow,
}) {
  final coded = episodes
      .where((e) => e.situationCode?.isNotEmpty ?? false)
      .toList()
    ..sort((a, b) {
      final av = a.openedAt ?? a.updatedAt ?? a.closedAt;
      final bv = b.openedAt ?? b.updatedAt ?? b.closedAt;
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;
      return bv.compareTo(av);
    });

  return [for (final e in coded.take(window)) e.situationCode!];
}

/// Xếp hạng tình huống theo số lần xuất hiện trong [recent].
///
/// Giảm dần theo số lần; hoà thì theo mã để thứ tự ổn định giữa hai lần dựng
/// màn — danh sách nhảy chỗ mỗi lần mở app là một lỗi hiển thị.
///
/// [minCount] bỏ đi những tình huống chưa lặp đủ. Mặc định 1 = giữ nguyên mọi
/// thứ, vì phần lớn nơi gọi cần con số thật để suy ra nhu cầu chủ đạo hay tỉ
/// trọng ba trụ. Chỉ hai màn "Tình huống lặp lại" truyền
/// [kRepeatedSituationsMinCount] vào đây.
///
/// Việc cắt lấy mấy dòng vẫn là của màn hình, không phải của hàm này — màn Hiểu
/// lấy [kRepeatedSituationsTop], màn danh sách đầy đủ lấy tất cả những gì còn
/// lại sau [minCount].
List<RepeatedSituation> rankSituations(
  List<String> recent, {
  int minCount = 1,
}) {
  final counts = <String, int>{};
  for (final code in recent) {
    counts[code] = (counts[code] ?? 0) + 1;
  }

  return [
    for (final entry in counts.entries)
      if (entry.value >= minCount)
        RepeatedSituation(situationCode: entry.key, count: entry.value),
  ]..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.situationCode.compareTo(b.situationCode);
    });
}

/// Tiện ích gộp: xếp hạng thẳng từ danh sách Episode.
List<RepeatedSituation> repeatedSituations(
  List<ReflectionEpisode> episodes, {
  int window = kRecentSituationsWindow,
  int minCount = 1,
}) =>
    rankSituations(
      recentSituationIds(episodes, window: window),
      minCount: minCount,
    );
