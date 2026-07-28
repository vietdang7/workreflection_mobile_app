// Cơ hội phát triển — suy ra bằng luật (Kiến trúc Dữ liệu Hai Lớp v1.6 §XI).
//
// Bản này cố ý KHÔNG gọi AI. §XI mô tả một gợi ý tổng hợp từ toàn bộ hành trình
// Reflection; luật đủ để nói đúng điều đã quan sát được, và chạy được ngay mà
// không cần đối tác sửa edge function. Khi có AI, chỉ cần đổi nguồn của
// `wrGrowthOpportunityProvider` — phần hiển thị và ràng buộc §XII.7 giữ nguyên.
//
// Bốn ràng buộc của §XI được cài thẳng vào đây:
//   §11.1  Câu gợi ý luôn ở thể điều kiện, không phán một kết luận chắc chắn.
//   §11.2  Luôn kèm ghi chú độ chính xác — [GrowthOpportunity] bắt cả hai
//          trường non-null nên không dựng nổi một gợi ý thiếu ghi chú.
//   §11.3  Chưa đủ dữ liệu thì im lặng. Trả null, KHÔNG bịa một câu chung chung.
//   §11.5  Ghi lại đã dựa trên Pattern nào, phục vụ minh bạch.
//
// Pure Dart — không phụ thuộc Flutter.

import '../models/wr_content.dart';
import '../models/wr_intelligence.dart';
import '../models/wr_mood_content.dart';

/// Số lần lặp tối thiểu trước khi được phép nói một Cơ hội phát triển.
///
/// Cao hơn ngưỡng của Development Flow (2): gợi ý một hướng năng lực là phát
/// biểu về cả chặng đường, không phải về một chủ đề vừa lặp lại hai lần.
const int kGrowthOpportunityThreshold = 4;

/// Trụ SCA của một chiều — 'S', 'C' hoặc 'A'. Null cho hai nhóm tích cực.
String? _pillarOf(ScaDimension d) =>
    d.isPositive ? null : d.dbValue.substring(0, 1);

/// Hướng năng lực ứng với từng trụ, viết ở thể điều kiện (§11.1).
///
/// Chỉ ba câu vì SCA chỉ có ba trụ. Nói theo trụ chứ không theo từng chiều: mười
/// câu khác nhau sẽ nghe như hệ thống biết rõ hơn thực tế nó biết.
const Map<String, String> _pillarSuggestion = {
  'S': 'Có vẻ phần lớn điều bạn nhìn lại xoay quanh cách bạn tự nhìn mình '
      'trong công việc. Nếu điều đó đúng, hướng phát triển gần nhất của bạn '
      'có thể là năng lực tự định vị: gọi tên được mình mạnh ở đâu và nói ra '
      'được điều đó khi cần.',
  'C': 'Có vẻ phần lớn điều bạn nhìn lại xoay quanh quan hệ với người khác '
      'trong công việc. Nếu điều đó đúng, hướng phát triển gần nhất của bạn '
      'có thể là năng lực đối thoại: nói điều khó nói mà vẫn giữ được quan hệ.',
  'A': 'Có vẻ phần lớn điều bạn nhìn lại xoay quanh quyền chủ động trong công '
      'việc. Nếu điều đó đúng, hướng phát triển gần nhất của bạn có thể là '
      'năng lực tự điều phối: chọn được việc nào làm trước và giữ được ranh '
      'giới của mình.',
};

/// Suy ra Cơ hội phát triển từ Pattern đã tích luỹ.
///
/// Trả null khi chưa đủ dữ liệu (§11.3) hoặc khi không có trụ nào trội hơn hẳn.
/// [roleText] là mô tả công việc người dùng tự viết — có thì gắn thêm một câu
/// neo gợi ý vào vai trò thật, không có thì bỏ, không đoán.
GrowthOpportunity? deriveGrowthOpportunity({
  required String userId,
  required List<PatternCount> patterns,
  required List<WrSituation> situations,
  String? roleText,
  required DateTime now,
}) {
  if (patterns.isEmpty) return null;

  final codeToDim = <String, ScaDimension>{
    for (final s in situations) s.code: s.scaDimension,
  };

  // Cộng dồn theo trụ, bỏ qua tình huống tích cực: P-ACHIEVE/P-STEADY là chỗ
  // đang ổn, không phải hướng cần phát triển.
  final tally = <String, int>{};
  final basedOn = <String>[];
  for (final p in patterns) {
    final code = p.situationCode;
    if (code == null) continue;
    final dim = codeToDim[code];
    if (dim == null) continue;
    final pillar = _pillarOf(dim);
    if (pillar == null) continue;
    tally[pillar] = (tally[pillar] ?? 0) + p.occurrenceCount;
    basedOn.add(code);
  }
  if (tally.isEmpty) return null;

  final total = tally.values.reduce((a, b) => a + b);
  if (total < kGrowthOpportunityThreshold) return null;

  final sorted = tally.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Hai trụ bằng điểm nhau thì chưa có hướng nào trội — im lặng còn hơn bốc
  // đại một trong hai rồi nói như thể đã thấy rõ.
  if (sorted.length > 1 && sorted[0].value == sorted[1].value) return null;

  final suggestion = _pillarSuggestion[sorted.first.key];
  if (suggestion == null) return null;

  final role = roleText?.trim();
  final text = (role == null || role.isEmpty)
      ? suggestion
      : '$suggestion Đặt cạnh công việc bạn mô tả — "$role" — đây có thể là '
          'chỗ đáng thử trước.';

  return GrowthOpportunity(
    id: '',
    userId: userId,
    suggestionText: text,
    confidenceNote: GrowthOpportunity.kConfidenceNote,
    basedOn: basedOn.toSet().toList()..sort(),
    generatedAt: now,
  );
}
