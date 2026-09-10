// lib/core/logic/wr_career_health.dart
//
// Career Health Check — Hướng 1 "tích luỹ hàng ngày" (khách chốt 2026-07-31).
//
// Người dùng check-in trên Home; đủ 15 LẦN thì bức tranh tổng thể mở ra. Ba
// điểm dễ hiểu nhầm, ghi ở đây một lần:
//
//   • Đếm LẦN, không đếm ngày. Bản đầu đếm số NGÀY riêng biệt cho đúng chữ
//     "tích luỹ 15 ngày", nhưng màn Hiểu mình còn một câu "Bạn đã nhìn lại N
//     lần" ngay bên dưới: hai con số đo hai đơn vị, đặt cạnh nhau thì không ai
//     đoán ra. Khách chốt 2026-07-31 (vòng sau) gộp về một đơn vị LẦN.
//   • Cái giá của quyết định đó: chạy 15 lượt trong một tối là mở khoá ngay,
//     và bức tranh tổng thể khi ấy dựng từ dữ liệu của đúng một ngày. Đây là
//     đánh đổi có ý thức để màn chỉ còn hai con số, không phải sơ suất.
//   • Trạng thái ba trụ suy từ đây chỉ nói TRỤ NÀO ĐANG BỊ CHẠM NHIỀU, không
//     phải trụ nào đang tốt. Check-in ghi nhận tình huống khó, không đo điều
//     kiện làm việc như bộ Self-Check. Vì thế nơi này chỉ trả về NHÃN CHỮ,
//     không bao giờ trả về một con số giả vờ tương đương điểm tự đánh giá.

import '../models/wr_content.dart';
import '../models/wr_episode.dart';
import 'wr_self_check_questions.dart';

/// Số lần nhìn lại để "bức tranh tổng thể" mở ra.
const int kCareerHealthThreshold = 15;

/// Đã đủ số lần để đọc ra bức tranh tổng thể chưa?
///
/// Cố tình nhận vào một `int` chứ không nhận danh sách Episode: con số truyền
/// vào phải là ĐÚNG con số màn hình đang hiện ở mục "Hành trình đã đi". Nhận
/// danh sách rồi tự đếm ở đây là mở lại đúng cái cửa vừa đóng — hai nơi đếm
/// theo hai luật rồi lệch nhau.
bool careerHealthUnlocked(int reflectionCount) =>
    reflectionCount >= kCareerHealthThreshold;

/// Trụ SCA của một chiều — chữ cái đầu của mã chiều (S1 → s, C2 → c, A3 → a).
/// Trả về null cho hai nhóm tình huống tích cực (P-ACHIEVE, P-STEADY): chúng
/// không thuộc trụ nào và không được kéo trạng thái trụ xuống.
SelfCheckPillar? pillarOfDimension(ScaDimension dim) {
  if (!dim.isSca) return null;
  return switch (dim.dbValue[0]) {
    'S' => SelfCheckPillar.s,
    'C' => SelfCheckPillar.c,
    'A' => SelfCheckPillar.a,
    _ => null,
  };
}

/// Tỉ trọng mỗi trụ trong recentSituationIds, trong khoảng 0–1.
///
/// Trụ không xuất hiện lần nào trả về 0. Tổng ba tỉ trọng bằng 1 khi có ít nhất
/// một lần ghi nhận thuộc SCA; rỗng thì cả ba bằng 0.
///
/// Đọc [recent] chứ không đọc `wr_pattern_counts`: v2.0 §4.3 chỉ cho một nguồn
/// trả lời "đang phản chiếu nhiều về điều gì", và "trụ nào đang bị chạm nhiều"
/// đúng là câu hỏi đó.
Map<SelfCheckPillar, double> pillarShares(
  List<String> recent,
  List<WrSituation> situations,
) {
  final codeToDim = {for (final s in situations) s.code: s.scaDimension};
  final tally = {for (final p in SelfCheckPillar.values) p: 0};
  var total = 0;
  for (final code in recent) {
    final dim = codeToDim[code];
    if (dim == null) continue;
    final pillar = pillarOfDimension(dim);
    if (pillar == null) continue;
    tally[pillar] = tally[pillar]! + 1;
    total++;
  }
  if (total == 0) {
    return {for (final p in SelfCheckPillar.values) p: 0};
  }
  return {
    for (final p in SelfCheckPillar.values) p: tally[p]! / total,
  };
}

/// Số lần trong [recent] thật sự rơi vào một trụ SCA.
///
/// `pillarShares` trả về ba số 0 cho hai trường hợp KHÁC HẲN nhau: chưa ghi
/// nhận gì, và đã ghi nhận nhiều nhưng toàn tình huống tích cực (P-ACHIEVE,
/// P-STEADY) hoặc tình huống tự viết không có mã. Cả ba số 0 đọc ra thành ba
/// nhãn "Đang hỗ trợ tốt" — một lời khen bịa ra từ chỗ không có dữ liệu.
///
/// Đủ 15 lần nhìn lại mà bức tranh vẫn phải im lặng thì màn hình phải NÓI RA
/// điều đó, chứ không được bịa. Hàm này để nơi gọi phân biệt được hai trường
/// hợp trước khi dựng nhãn.
int scaTouchedCount(List<String> recent, List<WrSituation> situations) {
  final codeToDim = {for (final s in situations) s.code: s.scaDimension};
  var total = 0;
  for (final code in recent) {
    final dim = codeToDim[code];
    if (dim == null) continue;
    if (pillarOfDimension(dim) == null) continue;
    total++;
  }
  return total;
}

// ---------------------------------------------------------------------------
// ĐÃ BỎ: behaviourPillarLabel / behaviourPillarIsHealthy
// ---------------------------------------------------------------------------
//
// Hai hàm đó gán nhãn ĐÁNH GIÁ ("Đang cản trở" / "Ổn, còn dư địa" / "Đang hỗ
// trợ tốt") cho một con số TẦN SUẤT. `Changelog_CareerSnapshot.docx` §2 yêu cầu
// bỏ hoàn toàn:
//
//   "Tần suất cao KHÔNG đồng nghĩa với 'tệ'. Một người quay lại nhóm Mối quan
//    hệ 14 lần có thể vì đang gặp vấn đề, nhưng cũng có thể vì đang chủ động
//    làm việc với nó. Gán nhãn đánh giá kiểu 'Đang cản trở' cho một con số
//    tần suất là suy diễn vượt quá dữ liệu."
//
// Còn tệ hơn: bộ chữ đó CỐ Ý trùng với `pillarStatusLabel` của đường tự đánh
// giá, để "hai nơi không nói khác nhau". Kết quả ngược lại — dùng chung một
// thang từ vựng khiến người đọc mặc định hai khối đang đo cùng một thứ, nên hai
// kết quả khác nhau bị đọc thành lỗi hệ thống. Đó chính là màn hình khách chụp
// lại: cùng ba trụ, hai lần, hai kết luận ngược nhau.
//
// Nay cột tần suất chỉ nói SỐ LẦN TRÊN TỔNG, không nhãn, không màu cảnh báo.

/// Số lần mỗi trụ bị chạm, đếm trên TOÀN BỘ [episodes].
///
/// Cố tình KHÔNG đi qua `recentSituationIds`: hàm đó chặn ở 30 mục gần nhất
/// (v2.0 §4.1), nên lấy nó làm nguồn cho cột "Xuất hiện" thì người đã nhìn lại
/// 80 lần vẫn đọc được "14 / 30 lần" — đúng cái bẫy §8 của changelog cảnh báo.
///
/// Hai nhóm tình huống tích cực (P-ACHIEVE, P-STEADY) và những lượt tự viết
/// không có mã đều không thuộc trụ nào, nên tổng ba số ở đây NHỎ HƠN tổng số
/// lần nhìn lại. Đó là sự thật, không phải sai số: mẫu số của cột là tổng số
/// lần, và không phải lần nào cũng rơi vào một trụ.
Map<SelfCheckPillar, int> pillarReflectionCounts(
  List<ReflectionEpisode> episodes,
  List<WrSituation> situations,
) {
  final codeToDim = {for (final s in situations) s.code: s.scaDimension};
  final counts = {for (final p in SelfCheckPillar.values) p: 0};
  for (final e in episodes) {
    final code = e.situationCode;
    if (code == null || code.isEmpty) continue;
    final dim = codeToDim[code];
    if (dim == null) continue;
    final pillar = pillarOfDimension(dim);
    if (pillar == null) continue;
    counts[pillar] = counts[pillar]! + 1;
  }
  return counts;
}

/// Sau bao nhiêu ngày thì một lần Self-Check được coi là đã cũ (§5).
///
/// Ba tháng. §5: "Self-Check là ảnh chụp tại một thời điểm, còn Reflection là
/// dòng chảy liên tục. Nếu một người làm Self-Check hồi tháng 3, rồi phản chiếu
/// đều đặn đến tháng 9, việc hiển thị 'Bạn đánh giá: Ổn, còn dư địa' như thể đó là
/// đánh giá hiện tại là sai lệch."
///
/// Nguy hiểm hơn cái nhãn cũ: hệ thống lấy chính con số cũ đó đối chiếu với
/// hành vi mới, nên kết luận về khoảng lệch cũng sai theo.
const int kSelfCheckStaleDays = 90;

/// Lần tự đánh giá này đã cũ tới mức nên mời làm lại chưa?
bool selfCheckIsStale(DateTime takenAt, DateTime now) =>
    now.difference(takenAt).inDays >= kSelfCheckStaleDays;

/// Ngày dạng dd/MM/yyyy — dạng §5 yêu cầu hiện kèm cột đánh giá.
String selfCheckDateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Tỉ trọng tối thiểu để một trụ được gọi là nổi trội (Diễn giải sâu §2).
const double kDominantPillarShare = 0.40;

/// Trụ nổi trội, hoặc null khi phân bố tương đối đều.
///
/// `Diễn giải sâu §2`: "dominantPillar phải trả về null khi phân bố tương đối
/// đều (không trụ nào vượt 40%). Nếu cứ lấy trụ cao nhất bất kể chênh lệch, hệ
/// thống sẽ khẳng định một xu hướng không thật, ví dụ 10 / 9 / 8 lần mà vẫn
/// tuyên bố có một trụ nổi trội."
///
/// Mẫu số là [total] — tổng số lần nhìn lại, đúng con số đang hiện ở cột
/// "Xuất hiện". Chia cho tổng ba trụ thay vì tổng số lần sẽ ra một tỉ lệ không
/// khớp với bất kỳ con số nào người dùng nhìn thấy trên màn.
/// HAI điều kiện, không phải một. Trụ cao nhất phải vượt 40% VÀ phải là duy
/// nhất. Hoà 3–3–0 thì tỉ trọng của trụ đầu là 50%, vượt ngưỡng, nhưng gọi nó
/// là trụ nổi trội thì chỉ là chọn theo thứ tự khai báo enum.
SelfCheckPillar? dominantPillar(Map<SelfCheckPillar, int> counts, int total) {
  if (total <= 0) return null;
  SelfCheckPillar? best;
  var bestCount = 0;
  var tied = false;
  for (final e in counts.entries) {
    if (e.value > bestCount) {
      bestCount = e.value;
      best = e.key;
      tied = false;
    } else if (e.value == bestCount && bestCount > 0) {
      tied = true;
    }
  }
  if (best == null || tied) return null;
  if (bestCount / total <= kDominantPillarShare) return null;
  return best;
}
