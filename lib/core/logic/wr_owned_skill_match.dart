// lib/core/logic/wr_owned_skill_match.dart
//
// Đề xuất chủ đề thư viện cho một chứng chỉ / khoá học / kỹ năng người dùng tự
// khai đã có (họp khách 01/10/2026, Task D2).
//
// Máy chỉ ĐỀ XUẤT, người dùng xác nhận bằng ô tích trước khi lưu. Nên luật
// quan trọng nhất ở đây là KHÔNG ĐOÁN BỪA: tên không khớp từ khoá nào thì trả
// rỗng, không rơi về "chủ đề đầu danh sách" như `suggestPracticeTheme`.
//
// Ba tầng điểm, cộng dồn:
//   3 — từ khoá RIÊNG của một chiều ([kOwnedSkillDimensionKeywords]);
//   2 — một cụm hai tiếng trong tên khớp tên chủ đề ("phản hồi" ↔ "Phản hồi
//       thật, không chỉ lịch sự");
//   1 — từ khoá của cả TRỤ ([kPillarKeywords], cùng bảng đối chiếu JD dùng).
// Khớp theo nguyên từ (đệm khoảng trắng hai đầu), không khớp nửa chữ.

import '../models/wr_content.dart';
import '../models/wr_intelligence.dart';
import 'wr_skill_jd_match.dart';

/// Trần số chủ đề đề xuất cho một mục.
const int kOwnedSkillMaxSuggestions = 3;

/// Từ khoá chỉ thẳng một chiều. Viết thường, có dấu; thêm bản tiếng Anh vì tên
/// chứng chỉ thường để nguyên tiếng Anh.
const Map<ScaDimension, List<String>> kOwnedSkillDimensionKeywords = {
  ScaDimension.s1: [
    'kỳ vọng',
    'mục tiêu',
    'okr',
    'kpi',
    'yêu cầu công việc',
    'phân tích nghiệp vụ',
    'business analysis',
  ],
  ScaDimension.s2: [
    'ưu tiên',
    'quản lý dự án',
    'dự án',
    'pmp',
    'project management',
    'kế hoạch',
    'lập kế hoạch',
    'quản lý thời gian',
    'time management',
    'agile',
    'scrum',
  ],
  ScaDimension.s3: [
    'thay đổi',
    'quản trị thay đổi',
    'change management',
    'chuyển đổi',
  ],
  ScaDimension.c1: [
    'giao việc',
    'uỷ quyền',
    'ủy quyền',
    'delegation',
    'lãnh đạo',
    'leadership',
    'quản lý đội',
    'huấn luyện',
    'coaching',
  ],
  ScaDimension.c2: [
    'thuyết trình',
    'nói trước đám đông',
    'public speaking',
    'presentation',
    'đàm phán',
    'negotiation',
    'tự tin',
  ],
  ScaDimension.c3: [
    'phản hồi',
    'feedback',
    'góp ý',
    'đối thoại',
    'lắng nghe',
    'communication',
  ],
  ScaDimension.a1: [
    'định hướng nghề nghiệp',
    'nghề nghiệp',
    'career',
    'chiến lược',
    'strategy',
  ],
  ScaDimension.a2: [
    'cân bằng',
    'sức khoẻ',
    'sức khỏe',
    'chánh niệm',
    'mindfulness',
    'căng thẳng',
    'stress',
    'năng lượng',
    'thiền',
    'yoga',
  ],
  ScaDimension.a3: [
    'cảm xúc',
    'trí tuệ cảm xúc',
    'emotional',
    'eq',
    'xung đột',
    'conflict',
  ],
  ScaDimension.a4: [
    'cải tiến',
    'kaizen',
    'lean',
    'six sigma',
    'giải quyết vấn đề',
    'problem solving',
    'tư duy phản biện',
    'critical thinking',
  ],
};

/// Tiếng hư không mang nghĩa riêng: một cụm hai tiếng có chứa nó không đủ để
/// nói tên chứng chỉ và tên chủ đề là cùng một chuyện.
const Set<String> _kStopSyllables = {
  'và',
  'của',
  'cho',
  'với',
  'một',
  'các',
  'những',
  'là',
  'khi',
  'không',
  'chỉ',
  'mình',
  'được',
  'về',
  'đúng',
  'đi',
  'đâu',
  'đang',
  'mọi',
  'thứ',
  'cùng',
  'lại',
  'khỏi',
  'thật',
  'kỹ',
  'năng',
  'khoá',
  'khóa',
  'học',
  'chứng',
};

String _norm(String s) =>
    ' ${s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim()} ';

bool _hasWord(String normText, String keyword) =>
    normText.contains(' ${keyword.toLowerCase()} ');

List<String> _syllables(String normText) =>
    normText.trim().split(' ').where((w) => w.isNotEmpty).toList();

/// Cụm hai tiếng liền nhau, bỏ cụm có tiếng hư.
Set<String> _bigrams(String normText) {
  final w = _syllables(normText);
  return {
    for (var i = 0; i + 1 < w.length; i++)
      if (!_kStopSyllables.contains(w[i]) &&
          !_kStopSyllables.contains(w[i + 1]))
        '${w[i]} ${w[i + 1]}',
  };
}

/// Tối đa [kOwnedSkillMaxSuggestions] `themeId` nên gắn với mục tên [title],
/// điểm cao trước, hoà điểm thì theo `themeId`. Không khớp gì thì rỗng.
List<String> suggestThemesForOwnedSkill(
  String title,
  List<PracticeTheme> themes,
) {
  final text = _norm(title);
  if (text.trim().isEmpty) return const [];

  final pillarHits = <String>{
    for (final e in kPillarKeywords.entries)
      if (e.value.any((kw) => _hasWord(text, kw))) e.key,
  };
  final bigrams = _bigrams(text);

  final scores = <String, int>{};
  for (final t in themes) {
    if (t.isRetired) continue;
    final dim = t.scaDimension;
    if (dim == null || !dim.isSca) continue;

    var score = 0;
    final dimKeywords = kOwnedSkillDimensionKeywords[dim] ?? const [];
    if (dimKeywords.any((kw) => _hasWord(text, kw))) score += 3;

    final titleNorm = _norm(t.titleVi);
    if (bigrams.any((b) => titleNorm.contains(' $b '))) score += 2;

    if (pillarHits.contains(pillarOfDimension(dim))) score += 1;

    if (score > 0) scores[t.themeId] = score;
  }

  final ranked = scores.keys.toList()
    ..sort((a, b) {
      final byScore = scores[b]!.compareTo(scores[a]!);
      return byScore != 0 ? byScore : a.compareTo(b);
    });
  return ranked.take(kOwnedSkillMaxSuggestions).toList();
}
