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

/// Nhãn trạng thái một trụ, suy từ tỉ trọng bị chạm.
///
/// Ba trụ chia đều thì mỗi trụ khoảng 0.33. Trên 0.45 là lệch hẳn về một phía;
/// dưới 0.20 là gần như không xuất hiện suốt 15 ngày. Bộ chữ giữ đúng như
/// `pillarStatusLabel` của đường tự đánh giá để hai nơi không nói khác nhau.
String behaviourPillarLabel(double share) {
  if (share >= 0.45) return 'Ưu tiên cải thiện';
  if (share >= 0.20) return 'Cần chú ý';
  return 'Đang phát triển';
}

/// True khi nhãn của [share] là nhãn "ổn" — dùng để chọn màu.
bool behaviourPillarIsHealthy(double share) => share < 0.20;
