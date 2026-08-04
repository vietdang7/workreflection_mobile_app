// lib/core/logic/wr_practice_match.dart
//
// Chọn chủ đề thực hành khớp với TÌNH HUỐNG người dùng đang lặp
// (khách chốt 2026-07-31: "nên tạo chủ đề khớp theo tình huống của người dùng").
//
// Bản trước chỉ khớp CHỮ CÁI TRỤ: nhu cầu Kết nối → lấy chủ đề nào có chiều bắt
// đầu bằng 'C'. Ba chiều C1/C2/C3 nói ba chuyện khác hẳn nhau — tin tưởng đội
// nhóm, dám lên tiếng, chất lượng đối thoại — nên người vướng C1 vẫn có thể bị
// đẩy vào chủ đề C3 chỉ vì nó đứng trước trong danh sách.
//
// Giờ khớp theo đúng CHIỀU của tình huống người dùng gặp nhiều nhất, và trả về
// luôn mã tình huống đó để màn hình nói được vì sao lại là chủ đề này.

import '../models/wr_content.dart';
import '../models/wr_intelligence.dart';
import 'wr_dominant_need.dart';

/// Chủ đề được chọn theo đường nào. Quyết định màn hình được phép nói gì:
/// khớp kiểu nào thì giải thích kiểu đó, không khớp được thì im lặng.
enum PracticeMatchKind {
  /// Đúng chiều của tình huống người dùng đang lặp.
  dimension,

  /// Chỉ đúng trụ của nhu cầu chủ đạo — chưa có tình huống nào để bám.
  pillar,

  /// Khớp theo trụ mà công việc của họ nhấn mạnh, đọc từ JD/CV đã phân tích
  /// hoặc mô tả vai trò họ tự viết.
  jobContext,

  /// Không khớp được gì, lấy chủ đề đầu bể. KHÔNG được giải thích: nói "vì bạn
  /// đang tìm kiếm sự kết nối" cho một chủ đề trụ S là dựng ra một mối liên hệ
  /// không có thật.
  fallback,
}

/// Kết quả gợi ý: chủ đề, khớp theo đường nào, và tình huống đã dẫn tới nó
/// (chỉ khác null khi khớp theo chiều).
typedef PracticeSuggestion = ({
  PracticeTheme theme,
  PracticeMatchKind kind,
  String? reasonSituationCode,
  int reasonCount,
});

/// Tổng số lần theo từng chiều SCA, giảm dần. Bỏ qua hai nhóm tình huống tích
/// cực: chúng không có chủ đề thực hành nào để khớp.
///
/// Đọc recentSituationIds — v2.0 §4.3 gọi thẳng tên "chiều hoạt động nhiều nhất
/// cho gợi ý Practice Theme (§XIII)" là một trong các tính năng bắt buộc dùng
/// nguồn duy nhất đó.
List<({ScaDimension dim, String situationCode, int count})> _dimensionRanking(
  List<String> recent,
  List<WrSituation> situations,
) {
  final codeToDim = {for (final s in situations) s.code: s.scaDimension};
  final totals = <ScaDimension, int>{};
  // Tình huống tiêu biểu của mỗi chiều = tình huống lặp nhiều nhất trong chiều.
  final perCode = <String, int>{};
  final best = <ScaDimension, (String, int)>{};

  for (final code in recent) {
    final dim = codeToDim[code];
    if (dim == null || !dim.isSca) continue;
    final n = (perCode[code] ?? 0) + 1;
    perCode[code] = n;
    totals[dim] = (totals[dim] ?? 0) + 1;
    final cur = best[dim];
    // Hoà số lần thì giữ mã nhỏ hơn, để hai lần dựng cùng dữ liệu ra cùng câu
    // giải thích — thứ tự trong `recent` là theo thời gian, không ổn định.
    if (cur == null || n > cur.$2 || (n == cur.$2 && code.compareTo(cur.$1) < 0)) {
      best[dim] = (code, n);
    }
  }

  final ranked = totals.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      // Hoà thì theo thứ tự chiều, để hai lần dựng cùng dữ liệu ra cùng kết quả.
      return a.key.dbValue.compareTo(b.key.dbValue);
    });

  return [
    for (final e in ranked)
      (
        dim: e.key,
        situationCode: best[e.key]!.$1,
        count: best[e.key]!.$2,
      ),
  ];
}

/// Câu giải thích vì sao lại là chủ đề này.
///
/// null = không giải thích được thì im lặng, không bịa một lý do nghe cho có.
///
/// Ở chung file với [suggestPracticeTheme] để mọi màn nói CÙNG một câu: trước
/// 2026-08-04 hàm này nằm private trong màn Phát triển, nên màn thư viện chủ đề
/// bày ra một danh sách trần không kèm lý do nào — người dùng không hiểu vì sao
/// lại là những chủ đề đó.
String? practiceSuggestionReason(
  PracticeSuggestion? suggestion,
  List<WrSituation> situations,
  HumanNeed? need,
) {
  switch (suggestion?.kind) {
    case PracticeMatchKind.dimension:
      final code = suggestion!.reasonSituationCode;
      final text = situations.where((s) => s.code == code).firstOrNull?.text;
      if (text == null) return null;
      final n = suggestion.reasonCount;
      return n > 1
          ? 'Vì bạn đã gặp "$text" $n lần.'
          : 'Vì bạn đã gặp "$text".';
    case PracticeMatchKind.jobContext:
      // Khớp từ JD/CV đã đọc hoặc mô tả vai trò họ tự viết. Nói "công việc bạn
      // mô tả" chứ không nói "JD của bạn": người dùng có thể chỉ mới gõ vài
      // dòng chứ chưa tải tài liệu nào.
      return 'Vì công việc bạn mô tả nghiêng nhiều về phần này.';
    case PracticeMatchKind.pillar:
      // Chưa có tình huống nào để chỉ ra — mới chỉ Self-Check chẳng hạn.
      return need == null
          ? null
          : 'Vì bạn đang tìm kiếm ${needSeekingLabel(need)}.';
    case PracticeMatchKind.fallback:
    case null:
      return null;
  }
}

/// Chủ đề nên đề xuất, chọn trong [candidates].
///
/// [candidates] phải đã loại chủ đề người dùng đã ghi danh và chủ đề đã ngưng
/// đề xuất — hàm này không tự biết hai điều đó.
///
/// Thứ tự ưu tiên:
///   1. Chiều của tình huống người dùng gặp nhiều nhất — khớp đúng chiều.
///   2. Chưa có tình huống nào (mới chỉ Self-Check): khớp trụ theo [need].
///   3. Cùng đường không có thì lấy chủ đề đầu danh sách, và không bịa lý do.
PracticeSuggestion? suggestPracticeTheme({
  required List<PracticeTheme> candidates,
  required List<String> recent,
  required List<WrSituation> situations,
  HumanNeed? need,
  List<String> jobPillars = const [],
}) {
  if (candidates.isEmpty) return null;

  // 1 — khớp đúng chiều của tình huống đang lặp.
  for (final entry in _dimensionRanking(recent, situations)) {
    for (final t in candidates) {
      if (t.scaDimension == entry.dim) {
        return (
          theme: t,
          kind: PracticeMatchKind.dimension,
          reasonSituationCode: entry.situationCode,
          reasonCount: entry.count,
        );
      }
    }
  }

  // 2 — chưa có tình huống nào lặp lại, nhưng biết công việc của họ đòi gì.
  //
  // Xếp SAU chiều tình huống là có chủ đích: điều họ thật sự đang vướng quan
  // trọng hơn điều bản mô tả công việc nói. JD chỉ vào cuộc khi chưa có gì để
  // bám — lúc đó nó vẫn tốt hơn một chủ đề lấy đại đầu danh sách.
  for (final pillar in jobPillars) {
    for (final t in candidates) {
      final dim = t.scaDimension;
      if (dim != null && dim.isSca && dim.dbValue.startsWith(pillar)) {
        return (
          theme: t,
          kind: PracticeMatchKind.jobContext,
          reasonSituationCode: null,
          reasonCount: 0,
        );
      }
    }
  }

  // 3 — chưa có hành vi nào để bám: khớp trụ theo nhu cầu chủ đạo.
  if (need != null) {
    final pillar = needPillarLetter(need);
    for (final t in candidates) {
      final dim = t.scaDimension;
      if (dim != null && dim.isSca && dim.dbValue.startsWith(pillar)) {
        return (
          theme: t,
          kind: PracticeMatchKind.pillar,
          reasonSituationCode: null,
          reasonCount: 0,
        );
      }
    }
  }

  // 4 — không khớp được gì thì vẫn mời một chủ đề, nhưng im lặng về lý do.
  return (
    theme: candidates.first,
    kind: PracticeMatchKind.fallback,
    reasonSituationCode: null,
    reasonCount: 0,
  );
}
