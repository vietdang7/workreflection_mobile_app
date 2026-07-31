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
/// Thuật toán theo pseudo-code §4.1, CÓ MỘT SỬA ĐỔI bắt buộc — xem khối dưới:
///
///   relevant = lọc theo cụm dims của mood
///   basePool = relevant nếu đủ ≥5, ngược lại toàn bộ thư viện
///   neo      = tình huống gần đây nhất đã chọn mà vẫn thuộc basePool  ← THÊM
///   unseen   = basePool bỏ neo và bỏ những mã đã có trong recentIds
///   pool     = unseen nếu đủ chỗ, ngược lại basePool bỏ neo
///   → neo đứng đầu, rồi 4 mục ngẫu nhiên từ pool
///
/// Hai lần "nếu đủ, ngược lại lùi về tập rộng hơn" là chủ đích: thà đưa gợi ý
/// kém liên quan còn hơn đưa danh sách trống. Nhưng thứ tự ưu tiên luôn là
/// đúng-cảm-xúc trước, rồi mới tới chưa-từng-thấy.
///
/// ---------------------------------------------------------------------------
/// VÌ SAO PHẢI CÓ Ô NEO — tài liệu tự mâu thuẫn ở chỗ này
/// ---------------------------------------------------------------------------
///
/// §4.1 bảo LOẠI khỏi bể mọi mã đã có trong recentSituationIds (30 mã gần
/// nhất). §4.3 bảo ĐẾM số lần lặp của từng mã trong chính danh sách đó. Hai câu
/// không thể cùng đúng: đã loại thì không bao giờ chọn lại được, mà không chọn
/// lại được thì không mã nào đếm quá 1.
///
/// Đó không phải suy luận. Trên DB thật ngày 2026-07-31, một người dùng có 16
/// Episode mang mã — **16 mã phân biệt, 0 lần lặp**. Người này cụm "mệt mỏi"
/// (A3+A1, 20 tình huống) đã dùng 8 mã; cả 8 bị khoá khỏi bể vì `unseen` vẫn
/// còn 12 ≥ 5. Họ mô tả đúng triệu chứng: "tôi cũng ráng chọn rồi nhưng vẫn
/// không thấy... không thấy các câu hỏi mà tôi đã chọn ban đầu để chọn".
///
/// Cách chữa giữ được cả hai ý: xoay vòng vẫn lo phần đa dạng cho 4 ô còn lại,
/// nhưng MỘT ô luôn dành cho điều gần nhất người đó đã chọn trong cụm này. "Vẫn
/// chuyện đó" luôn cách một cú chạm, nên một chuyện lặp thật sẽ đếm lên thật.
/// Ô neo đứng ĐẦU, không trộn — mục đích của nó là tìm thấy được ngay.
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
  // Chỉ những tình huống còn được đề xuất mới vào bể. 60 chip Tầng 1 cũ vẫn
  // nằm trong bảng để tra ngược ra nhãn cho lịch sử Episode.
  //
  // ⚠ Đính chính (đo trên DB thật 2026-07-31): hai tập KHÔNG phải một bản đổi
  // tên của nhau. Đối chiếu từng chip cũ với mục thư viện CÙNG CHIỀU: chỉ 6/60
  // là cùng một câu, 5/60 gần, 49/60 diễn đạt hẳn một tình huống khác. Chúng
  // phủ cùng bộ chiều SCA nhưng bằng hai bộ từ vựng riêng.
  //
  // Vì vậy vẫn phải gỡ chúng khỏi bể: bày cả hai là đưa người dùng hai bộ từ
  // vựng cho cùng một chiều, và số đếm "Tình huống lặp lại" (§4.3) bị xé đôi
  // theo bộ nào họ tình cờ chạm. Nhưng ĐỪNG suy ra rằng mọi mã cũ đều có một
  // mã mới tương đương để ghép lịch sử — phần lớn thì không.
  final offered = all.where((s) => !s.isRetired).toList();
  if (offered.isEmpty) return const [];

  final dims = mood == null ? null : kMoodDimensions[mood];

  final relevant = dims == null
      ? offered
      : offered.where((s) => dims.contains(s.scaDimension)).toList();

  final basePool = relevant.length >= count ? relevant : offered;

  final anchor = anchorSituation(basePool, recentIds);
  final rest = anchor == null
      ? basePool
      : basePool.where((s) => s.code != anchor.code).toList();
  final fill = anchor == null ? count : count - 1;

  final unseen = rest.where((s) => !recentIds.contains(s.code)).toList();
  final pool = unseen.length >= fill ? unseen : rest;

  return [
    if (anchor != null) anchor,
    ..._shuffle(pool, random).take(fill),
  ];
}

/// Tình huống gần đây nhất đã được chọn mà vẫn còn trong [pool].
///
/// [recentIds] có mới nhất đứng đầu (§4.1), nên duyệt xuôi là ra ngay cái gần
/// nhất. Trả về null khi chưa chọn lần nào, hoặc khi mọi mã đã chọn đều nằm
/// ngoài bể hiện tại — ví dụ đổi cảm xúc check-in sang một cụm chiều khác hẳn.
///
/// Tầng UI gọi lại hàm này trên chính danh sách đang hiện để biết chip nào là ô
/// neo mà gắn nhãn "Lần trước". An toàn: mọi mã khác trong danh sách nếu có mặt
/// trong [recentIds] đều CŨ HƠN ô neo, nên phép duyệt vẫn trả về đúng nó.
WrSituation? anchorSituation(List<WrSituation> pool, List<String> recentIds) {
  for (final code in recentIds) {
    for (final s in pool) {
      if (s.code == code) return s;
    }
  }
  return null;
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
/// v2.0 §2.2 mô tả Situation là MỘT thực thể có đủ chín trường. Trong app, dữ
/// liệu đó nằm ở hai bảng ra đời tách nhau — nhưng từ migration
/// `20260731090000_wr_situations_from_library.sql`, MỌI tình huống còn được đề
/// xuất đều có mã trùng khít giữa hai bảng:
///
///   wr_situations : 100 mục thư viện `<DIM>-NN` + 10 tích cực `P-NN`
///   wr_stories    : đúng 110 mã đó
///
/// Nên nhánh (1) dưới đây luôn trúng cho phiên mới.
///
/// Nhánh (2) chỉ còn phục vụ dữ liệu CŨ: những Episode đã ghi mã Tầng 1
/// `<DIM>-sit-NN` trước khi gộp. Mã đó không có story trùng tên, nên lùi về một
/// story cùng chiều, chọn theo chỉ số suy ra từ mã để cùng một chip LUÔN ra
/// cùng một story — bốc ngẫu nhiên thì câu Aha đổi mỗi lần mở và người dùng
/// không quay lại được điều mình vừa đọc.
///
/// ⚠ Nhánh (2) là phép ĐOÁN: câu chuyện nó trả về thường không nói đúng tình
/// huống đã chọn. Đó chính là lý do phải gộp mã. Đừng dựa vào nó cho nội dung
/// mới — thêm tình huống nào thì thêm story cùng mã cho tình huống đó.
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
