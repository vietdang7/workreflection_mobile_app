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
import 'wr_seniority.dart';
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
    this.tier,
    this.gapRelevance = const {},
    this.autoRaisedDimensions = const [],
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

  /// Cấp bậc người dùng đã khai. Null = chưa biết, và khi chưa biết thì phép
  /// đối chiếu chạy y như trước: không xếp hạng, không nâng trọng số.
  final SeniorityTier? tier;

  /// Mức độ liên quan của từng khoảng trống theo bảng B.2, khoá theo `theme_id`.
  /// Rỗng khi chưa biết cấp bậc.
  final Map<String, SkillRelevance> gapRelevance;

  /// Những chiều được Nguyên tắc 3 (B.1) kéo vào dù JD không nhắc tới.
  ///
  /// Giữ lại để nói thật với người dùng: chỗ này không đến từ mô tả họ viết.
  final List<String> autoRaisedDimensions;

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
/// [tier] là cấp bậc người dùng đã khai (`cc_profiles.position`). Có thì bật
/// hai luật của Phần B: nâng trọng số nhóm Kết nối (Nguyên tắc 3) và xếp hạng
/// khoảng trống theo bảng B.2. Null thì mọi thứ chạy như trước.
SkillJdMatch? matchSkillsToContext({
  required String? contextText,
  required List<SkillFormation> formations,
  required List<PracticeTheme> allThemes,
  SeniorityTier? tier,
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

  // Nguyên tắc 3 (B.1): từ mức quản lý nhóm nhỏ trở lên, trụ Kết nối luôn được
  // tính là "cần", kể cả khi JD không có một từ khoá nào thuộc trụ đó. JD vị
  // trí quản lý hiếm khi ghi "cần biết tin tưởng đội" — nó được ngầm hiểu là
  // đương nhiên, và chính vì ngầm nên phép so từ khoá không bao giờ thấy.
  final autoRaised = <String>[];
  if (tier != null && tier.isManaging) {
    for (final d in kConnectionDimensions) {
      autoRaised.add(d.dbValue);
    }
    autoRaised.sort();
    // Thêm chứ không ghi đè: trụ nào JD nói thẳng vẫn giữ nguyên thứ hạng của
    // nó. Trụ C thêm vào ở cuối để không đẩy trụ mà mô tả thật sự xoay quanh
    // xuống dưới.
    hits.putIfAbsent('C', () => 0);
  }

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

  // B.2: cùng một khoảng trống, người ở cấp cao hơn nên thấy nó xếp trên, vì
  // phạm vi ảnh hưởng rộng hơn. Chưa biết cấp bậc thì giữ nguyên thứ tự cũ —
  // đoán một cấp bậc rồi đảo thứ tự là nói với người dùng một mức ưu tiên
  // không có căn cứ.
  final relevance = <String, SkillRelevance>{};
  if (tier != null) {
    for (final t in gaps) {
      final r = relevanceOf(t.scaDimension, tier);
      if (r != null) relevance[t.themeId] = r;
    }
    gaps.sort((a, b) {
      final ra = relevance[a.themeId];
      final rb = relevance[b.themeId];
      // Chiều ngoài bộ 10 (không có trong bảng) xếp cuối, không xếp đầu.
      final byRank = (rb?.rank ?? -1).compareTo(ra?.rank ?? -1);
      if (byRank != 0) return byRank;
      return a.themeId.compareTo(b.themeId);
    });
  }

  return SkillJdMatch(
    matchedPillars: pillars,
    matchedDimensions: matchedDims,
    matchedSkills: matchedSkills,
    gapThemes: gaps,
    basedOnKeywords: keywords,
    tier: tier,
    gapRelevance: relevance,
    autoRaisedDimensions: autoRaised,
  );
}
