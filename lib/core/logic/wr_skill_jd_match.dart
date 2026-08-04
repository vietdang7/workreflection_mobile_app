// Đối chiếu kỹ năng đã hình thành với Context Document (JD / mô tả vai trò).
// Pure Dart, không phụ thuộc Flutter.
//
// Spec: "Nếu chỉ dừng ở việc liệt kê kỹ năng đã đạt, tính năng dễ trở thành một
// bộ sưu tập huy hiệu không có ý nghĩa với sự nghiệp thật của người dùng."
// Đối chiếu để lộ ra hai điều: kỹ năng nào đã có sẵn phù hợp với công việc, và
// kỹ năng nào công việc cần nhưng chưa hình thành — khoảng trống đáng phát
// triển tiếp theo, và là một nguồn đầu vào cho Cơ hội phát triển.
//
// Tính LÚC HIỂN THỊ, không lưu (đúng ghi chú `jd_matched_dims` trong Schema):
// người dùng đổi JD thì kết quả phải đổi theo, lưu cứng là để lại một bức tranh
// lệch mà không ai biết nó lệch.
//
// Đối chiếu ở mức TRỤ (S / C / A), không ở mức từng chiều. Nói "JD này cần chiều
// C2" là giả vờ biết rõ hơn thực tế một phép so từ khoá có thể biết; nói "phần
// lớn mô tả xoay quanh mối quan hệ trong công việc" thì đúng với cái đang có.
// Đây cũng là mức mà Cơ hội phát triển đang dùng.

import '../models/wr_content.dart';
import '../models/wr_intelligence.dart';
import 'wr_skill_formation.dart';

/// Ba trụ, tên hiển thị lấy đúng bộ chữ của Self-Check để người dùng không gặp
/// hai cách gọi cho cùng một thứ.
const Map<String, String> kPillarNames = {
  'S': 'Sự rõ ràng',
  'C': 'Mối quan hệ',
  'A': 'Cách làm việc',
};

/// Từ khoá nhận ra mỗi trụ trong một bản mô tả công việc tiếng Việt.
///
/// Cố ý viết thường, không dấu câu: so khớp sau khi hạ chữ thường. Danh sách
/// ngắn và cụ thể hơn là dài và mơ hồ — một từ quá chung ("công việc") sẽ khớp
/// mọi JD và làm phép đối chiếu vô nghĩa.
const Map<String, List<String>> kPillarKeywords = {
  'S': [
    'mục tiêu',
    'kỳ vọng',
    'trách nhiệm',
    'quy trình',
    'kế hoạch',
    'báo cáo',
    'phân tích',
    'tài liệu',
    'rõ ràng',
    'định hướng',
    'chiến lược',
    'đánh giá kết quả',
  ],
  'C': [
    'giao tiếp',
    'phối hợp',
    'khách hàng',
    'đội nhóm',
    'đồng đội',
    'team',
    'đàm phán',
    'thuyết trình',
    'hợp tác',
    'tư vấn',
    'đối tác',
    'lãnh đạo',
    'quản lý đội',
    'phản hồi',
    'chăm sóc',
  ],
  'A': [
    'chủ động',
    'linh hoạt',
    'đa nhiệm',
    'áp lực',
    'deadline',
    'sắp xếp',
    'tổ chức công việc',
    'thích nghi',
    'cải tiến',
    'tối ưu',
    'vận hành',
    'quản lý thời gian',
    'ưu tiên',
  ],
};

/// Trụ của một chiều SCA. Null cho hai nhóm tình huống tích cực.
String? pillarOfDimension(ScaDimension? d) {
  if (d == null || d.isPositive) return null;
  return d.dbValue.substring(0, 1);
}

/// Kết quả đối chiếu giữa kỹ năng đã hình thành và Context Document.
class SkillJdMatch {
  const SkillJdMatch({
    required this.matchedPillars,
    required this.matchedDimensions,
    required this.matchedSkills,
    required this.gapThemes,
    required this.basedOnKeywords,
  });

  /// Trụ được xem là liên quan tới Context Document hiện tại.
  final List<String> matchedPillars;

  /// `jd_matched_dims` trong Schema — các chiều thuộc những trụ đã khớp.
  /// Tính lúc hiển thị, không lưu.
  final List<String> matchedDimensions;

  /// Kỹ năng đã hình thành và nằm trong vùng công việc cần.
  final List<SkillFormation> matchedSkills;

  /// Chủ đề công việc cần nhưng người dùng chưa hình thành thành kỹ năng —
  /// khoảng trống đáng phát triển tiếp theo.
  final List<PracticeTheme> gapThemes;

  /// Từ khoá đã bắt được trong mô tả — để nói ra mình dựa vào đâu (minh bạch),
  /// không phán một kết luận từ hộp đen.
  final List<String> basedOnKeywords;

  bool get isEmpty => matchedSkills.isEmpty && gapThemes.isEmpty;

  /// Tên trụ dạng câu: "Mối quan hệ và Cách làm việc".
  String get pillarSentence {
    final names = [
      for (final p in matchedPillars)
        if (kPillarNames[p] != null) kPillarNames[p]!,
    ];
    if (names.isEmpty) return '';
    if (names.length == 1) return names.single;
    return '${names.take(names.length - 1).join(', ')} và ${names.last}';
  }
}

/// Đối chiếu kỹ năng đã hình thành với mô tả công việc.
///
/// [contextText] là Context Document ở dạng chữ: mô tả vai trò người dùng tự
/// viết, hoặc nội dung JD khi đã đọc được. Rỗng hoặc không bắt được trụ nào thì
/// trả null — chưa đủ căn cứ thì im lặng, không bịa một bức tranh nghe cho có.
///
/// [formations] là trạng thái của các chủ đề đang theo; [allThemes] là toàn bộ
/// chủ đề còn đề xuất, dùng để tìm khoảng trống (kể cả chủ đề chưa ghi danh).
SkillJdMatch? matchSkillsToContext({
  required String? contextText,
  required List<SkillFormation> formations,
  required List<PracticeTheme> allThemes,
}) {
  final text = contextText?.trim().toLowerCase();
  if (text == null || text.isEmpty) return null;

  final hits = <String, int>{};
  final keywords = <String>[];
  for (final entry in kPillarKeywords.entries) {
    for (final kw in entry.value) {
      if (!text.contains(kw)) continue;
      hits[entry.key] = (hits[entry.key] ?? 0) + 1;
      if (!keywords.contains(kw)) keywords.add(kw);
    }
  }
  if (hits.isEmpty) return null;

  // Trụ nhiều từ khoá nhất trước; hoà thì giữ thứ tự S → C → A cho ổn định.
  final pillars = hits.keys.toList()
    ..sort((a, b) {
      final byHits = hits[b]!.compareTo(hits[a]!);
      return byHits != 0 ? byHits : a.compareTo(b);
    });
  final pillarSet = pillars.toSet();

  final matchedDims = <String>[
    for (final d in ScaDimension.values)
      if (pillarSet.contains(pillarOfDimension(d))) d.dbValue,
  ]..sort();

  final formedIds = <String>{
    for (final f in formations)
      if (f.skillFormed) f.themeId,
  };

  final matchedSkills = <SkillFormation>[
    for (final f in formedSkills(formations))
      if (pillarSet.contains(pillarOfDimension(f.scaDimension))) f,
  ];

  // Khoảng trống: chủ đề thuộc vùng công việc cần, nhưng chưa hình thành. Bỏ
  // chủ đề đã ngưng đề xuất — mời người dùng đi vào một chủ đề đã rút là dẫn
  // họ vào ngõ cụt.
  final gaps = <PracticeTheme>[
    for (final t in allThemes)
      if (!t.isRetired &&
          !formedIds.contains(t.themeId) &&
          pillarSet.contains(pillarOfDimension(t.scaDimension)))
        t,
  ];

  return SkillJdMatch(
    matchedPillars: pillars,
    matchedDimensions: matchedDims,
    matchedSkills: matchedSkills,
    gapThemes: gaps,
    basedOnKeywords: keywords,
  );
}
