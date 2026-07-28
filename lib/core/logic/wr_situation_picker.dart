// Lọc tình huống theo cảm xúc + xoay vòng chống lặp lại.
//
// Kiến trúc Dữ liệu Hai Lớp v1.6 §III (lọc theo cảm xúc), §IV (xoay vòng),
// §VI (bể Lựa chọn).
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.
//
// Vấn đề đang chữa (§III): trước đây cơ chế gợi ý chỉ ép đúng MỘT tình huống
// liên quan vào danh sách 5, bốn cái còn lại lấy ngẫu nhiên từ toàn thư viện.
// Kết quả là phần lớn gợi ý không dính gì tới cảm xúc người dùng vừa chọn.

import 'dart:math';

import '../models/checkin.dart';
import '../models/wr_content.dart';

// ---------------------------------------------------------------------------
// §III — Ánh xạ cảm xúc check-in sang cụm chiều liên quan
// ---------------------------------------------------------------------------

/// Cụm chiều (dims) tương ứng với từng cảm xúc check-in, theo bảng §III.
///
/// Lý do từng cặp, giữ nguyên theo tài liệu:
///   stressed → A3 (phản ứng cảm xúc, mất cân bằng) + C2 (né tránh lên tiếng,
///              thường đi kèm căng thẳng giao tiếp)
///   tired    → A3 (kiệt sức, mắc kẹt) + A1 (mất phương hướng, thường xuất
///              hiện cùng mệt mỏi kéo dài)
///   okay     → P-STEADY (tình huống ổn định tự soạn, không dùng chiều vấn đề)
///   happy    → P-ACHIEVE (tình huống thành tựu tự soạn)
///
/// Hai cảm xúc tích cực cố tình KHÔNG trỏ vào chiều S/C/A nào: thư viện gốc chỉ
/// có tình huống dạng vấn đề, nên lọc vào đó sẽ ra gợi ý gượng ép (§2.3).
const Map<Mood, List<ScaDimension>> kMoodDimensions = {
  Mood.stressed: [ScaDimension.a3, ScaDimension.c2],
  Mood.tired: [ScaDimension.a3, ScaDimension.a1],
  Mood.okay: [ScaDimension.pSteady],
  Mood.happy: [ScaDimension.pAchieve],
};

/// Số tình huống hiện mỗi lần ở bước Notice (§III, §4.1).
const int kSituationChoiceCount = 5;

/// Sức chứa lịch sử chống lặp (§4.1).
const int kRecentSituationCapacity = 30;

/// Số câu lấy từ bể Lựa chọn khi tình huống CÓ Practice riêng (§VI).
const int kChoicePoolSampleWithPractice = 3;

/// Số câu lấy từ bể Lựa chọn khi KHÔNG có Practice riêng, tức "Điều khác" (§VI).
const int kChoicePoolSampleWithoutPractice = 4;

// ---------------------------------------------------------------------------
// §IV.1 — Chọn tình huống
// ---------------------------------------------------------------------------

/// Năm tình huống cho bước Notice, đã lọc theo [mood] và tránh lặp [recentIds].
///
/// Thuật toán theo đúng pseudo-code §4.1:
///
///   relevant = lọc theo cụm dims của mood
///   basePool = relevant nếu đủ ≥5, ngược lại toàn bộ thư viện
///   unseen   = basePool bỏ đi những mã đã có trong recentIds
///   pool     = unseen nếu đủ ≥5, ngược lại basePool
///   → 5 mục ngẫu nhiên từ pool
///
/// Hai lần "nếu đủ ≥5, ngược lại lùi về tập rộng hơn" là chủ đích: thà đưa gợi
/// ý kém liên quan còn hơn đưa danh sách trống. Nhưng thứ tự ưu tiên luôn là
/// đúng-cảm-xúc trước, rồi mới tới chưa-từng-thấy.
///
/// [mood] null nghĩa là vào thẳng từ tab, không qua check-in — khi đó dùng toàn
/// bộ thư viện, vì không có cảm xúc nào để bám vào.
///
/// [random] cho phép test cố định kết quả; production truyền null.
///
/// Mục "Điều khác, để tôi tự mô tả" KHÔNG nằm trong đây — nó luôn có mặt và
/// không thuộc cơ chế lọc (§III), nên tầng UI tự gắn thêm.
List<WrSituation> pickSituationChoices({
  required List<WrSituation> all,
  Mood? mood,
  List<String> recentIds = const [],
  int count = kSituationChoiceCount,
  Random? random,
}) {
  if (all.isEmpty) return const [];

  final dims = mood == null ? null : kMoodDimensions[mood];

  final relevant = dims == null
      ? all
      : all.where((s) => dims.contains(s.scaDimension)).toList();

  final basePool = relevant.length >= count ? relevant : all;

  final unseen = basePool.where((s) => !recentIds.contains(s.code)).toList();
  final pool = unseen.length >= count ? unseen : basePool;

  return _shuffle(pool, random).take(count).toList();
}

/// Ghi nhận [code] vừa được chọn vào lịch sử chống lặp.
///
/// Mới nhất đứng đầu, tối đa [capacity] mục (§4.1). Chọn lại một tình huống đã
/// có trong danh sách thì nó được đẩy lên đầu chứ không nhân đôi — nếu không,
/// một mã chọn nhiều lần sẽ chiếm hết 30 chỗ và vô hiệu hoá cơ chế xoay vòng.
List<String> rememberSituation(
  String code,
  List<String> recentIds, {
  int capacity = kRecentSituationCapacity,
}) {
  return [
    code,
    ...recentIds.where((c) => c != code),
  ].take(capacity).toList();
}

// ---------------------------------------------------------------------------
// §VI — Bể Lựa chọn
// ---------------------------------------------------------------------------

/// Các lựa chọn hiện ở bước Lựa chọn.
///
/// [practice] là gợi ý hành động riêng của tình huống. Có thì nó LUÔN đứng đầu
/// và được gắn nhãn "Gợi ý" ở tầng UI, cộng 3 câu ngẫu nhiên từ [pool]. Không có
/// (nhánh "Điều khác") thì lấy 4 câu ngẫu nhiên.
///
/// Vị trí đầu tiên cố định là có chủ ý: Practice bám đúng tình huống người dùng
/// vừa kể, còn 8 câu trong bể là câu chung cho mọi tình huống. Trộn lẫn thì gợi
/// ý sát nhất bị chìm.
List<String> pickChoiceOptions({
  String? practice,
  required List<String> pool,
  Random? random,
}) {
  final suggestion = practice?.trim();
  final hasPractice = suggestion != null && suggestion.isNotEmpty;

  // Không để câu chung trùng lặp gợi ý riêng của tình huống.
  final candidates = hasPractice
      ? pool.where((c) => c.trim() != suggestion).toList()
      : pool;

  final sample = _shuffle(candidates, random)
      .take(hasPractice
          ? kChoicePoolSampleWithPractice
          : kChoicePoolSampleWithoutPractice)
      .toList();

  return hasPractice ? [suggestion, ...sample] : sample;
}

// ---------------------------------------------------------------------------
// Nối Situation (chip) với Story (nội dung 5 trường)
// ---------------------------------------------------------------------------

/// Story chứa story/reflection/selfReflection/aha/practice cho [situation].
///
/// Kiến trúc Dữ liệu v1.6 §2.2 mô tả Situation là MỘT thực thể có đủ chín
/// trường. Trong app, dữ liệu đó nằm ở hai bảng ra đời tách nhau:
///
///   wr_situations : 60 nhãn chip ngắn, mã `<DIM>-sit-NN`
///   wr_stories    : 100 nội dung đầy đủ, mã `<DIM>-NN`
///
/// Hai tập mã KHÔNG trùng nhau, trừ 10 tình huống tích cực P-01→P-10 vốn được
/// tạo cùng lúc ở cả hai bảng. Vì vậy hàm này nối theo hai nấc:
///
///   1. Trùng mã tuyệt đối — đúng cho nhóm P-*.
///   2. Cùng chiều SCA — cho 60 tình huống còn lại. Chọn theo chỉ số suy ra từ
///      mã chip nên cùng một chip LUÔN ra cùng một story: nếu bốc ngẫu nhiên,
///      câu Aha sẽ đổi mỗi lần mở, và người dùng không thể quay lại điều mình
///      vừa đọc.
///
/// Trả về null khi không có story nào cùng chiều — khi đó tầng UI phải tự lo,
/// tuyệt đối không bịa một câu Aha.
WrStory? resolveStoryFor(
  WrSituation situation,
  List<WrStory> stories,
) {
  if (stories.isEmpty) return null;

  for (final s in stories) {
    if (s.storyId == situation.code) return s;
  }

  final sameDimension =
      stories.where((s) => s.scaDimension == situation.scaDimension).toList()
        ..sort((a, b) => a.storyId.compareTo(b.storyId));
  if (sameDimension.isEmpty) return null;

  // Ổn định theo mã chip, không theo thời điểm gọi.
  final index = situation.code.hashCode.abs() % sameDimension.length;
  return sameDimension[index];
}

// ---------------------------------------------------------------------------

/// Trộn một bản sao, không đụng vào danh sách gốc.
List<T> _shuffle<T>(List<T> items, Random? random) {
  final copy = [...items];
  copy.shuffle(random ?? Random());
  return copy;
}
