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
///   stressed  → A3 (phản ứng cảm xúc, mất cân bằng) + C2 (né tránh lên tiếng,
///               thường đi kèm căng thẳng giao tiếp)
///   tired     → A3 (kiệt sức, mắc kẹt) + A1 (mất phương hướng, thường xuất
///               hiện cùng mệt mỏi kéo dài)
///   foggy     → S1 (rõ ràng vai trò & trách nhiệm)
///   outofsync → S2 (luồng thông tin & phối hợp)
///   okay      → P-STEADY (tình huống ổn định tự soạn, không dùng chiều vấn đề)
///   happy     → P-ACHIEVE (tình huống thành tựu tự soạn)
///
/// Hai cảm xúc tích cực cố tình KHÔNG trỏ vào chiều S/C/A nào: thư viện gốc chỉ
/// có tình huống dạng vấn đề, nên lọc vào đó sẽ ra gợi ý gượng ép (§2.3).
///
/// Hai dòng `foggy`/`outofsync` thêm 24/08/2026 (changelog mockup §2 và §3).
/// Chúng chỉ có MỘT chiều mỗi cảm xúc, khác hai dòng đầu — cố ý: nhóm Structure
/// đủ 6 tình huống mỗi chiều trong thư viện, thừa cho 5 chip của bước Notice,
/// nên không cần ghép thêm chiều thứ hai để lấp chỗ. Ghép thêm chỉ làm loãng
/// đúng cái mà người dùng vừa nói ra.
const Map<Mood, List<ScaDimension>> kMoodDimensions = {
  Mood.stressed: [ScaDimension.a3, ScaDimension.c2],
  Mood.tired: [ScaDimension.a3, ScaDimension.a1],
  Mood.foggy: [ScaDimension.s1],
  Mood.outofsync: [ScaDimension.s2],
  Mood.okay: [ScaDimension.pSteady],
  Mood.happy: [ScaDimension.pAchieve],
};

/// The v2 mood codes used by the editorial catalog. Keep this mapping next to
/// the picker so enum values never get compared with raw strings ad hoc.
const Map<Mood, String> kMoodCodes = {
  Mood.stressed: 'stress',
  Mood.tired: 'tired',
  Mood.foggy: 'foggy',
  Mood.outofsync: 'outofsync',
  Mood.okay: 'ok',
  Mood.happy: 'happy',
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

/// Five real situations for Notice, selected with the v2 soft-priority rule:
/// three matching the selected mood and two from another mood with the same
/// valence. The custom self-description option is appended by UI.
List<WrSituation> pickSituationChoices({
  required List<WrSituation> all,
  Mood? mood,
  List<String> recentIds = const [],
  int count = kSituationChoiceCount,
  Random? random,
}) {
  final offered = all.where(_isPickerEligible).toList();
  if (offered.isEmpty) return const [];

  final wanted = count < 0 ? 0 : count;
  if (wanted == 0) return const [];

  final recentWindow = recentIds.take(10).toSet();
  final selected = <WrSituation>[];
  final selectedCodes = <String>{};

  WrValence valenceOf(WrSituation situation) =>
      situation.explicitValence ?? situation.valence;

  List<WrSituation> unseenFirst(List<WrSituation> pool, int take) {
    if (take <= 0 || pool.isEmpty) return const [];
    final unseen = pool.where((s) => !recentWindow.contains(s.code)).toList();
    final source = unseen.length >= take ? unseen : pool;
    return _shuffle(source, random).take(take).toList();
  }

  if (mood == null) {
    selected.addAll(unseenFirst(offered, wanted));
  } else {
    final moodCode = kMoodCodes[mood];
    final matching = offered.where((s) => s.mood == moodCode).toList();
    // If a partial/legacy catalog has no mood rows, fail soft to the complete
    // real catalog instead of returning an empty Notice state.
    if (matching.isEmpty) {
      selected.addAll(unseenFirst(offered, wanted));
    } else {
      final matchingTake = wanted < 3 ? wanted : 3;
      final sameValence = offered
          .where(
            (s) =>
                s.mood != moodCode && valenceOf(s) == valenceOf(matching.first),
          )
          .toList();
      final otherTake = wanted - matchingTake;
      selected.addAll(unseenFirst(matching, matchingTake));
      selected.addAll(unseenFirst(sameValence, otherTake < 2 ? otherTake : 2));

      // Fill a non-standard count from any remaining real records. This path
      // also handles a malformed catalog where one of the two requested pools
      // is too small, without ever duplicating a code.
      if (selected.length < wanted) {
        final remainder = offered
            .where((s) => !selected.any((picked) => picked.code == s.code))
            .toList();
        selected.addAll(unseenFirst(remainder, wanted - selected.length));
      }
    }
  }

  // Defensive de-duplication protects callers that pass duplicate catalog
  // rows, while preserving the random order chosen above.
  return [
    for (final situation in selected)
      if (selectedCodes.add(situation.code)) situation,
  ];
}

bool _isPickerEligible(WrSituation situation) {
  return !situation.isCustom &&
      !situation.isRetired &&
      situation.hasV2Classification;
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
  return [code, ...recentIds.where((c) => c != code)].take(capacity).toList();
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
      .take(
        hasPractice
            ? kChoicePoolSampleWithPractice
            : kChoicePoolSampleWithoutPractice,
      )
      .toList();

  return hasPractice ? [suggestion, ...sample] : sample;
}

// ---------------------------------------------------------------------------
// Nối Situation (chip) với Story (nội dung 5 trường)
// ---------------------------------------------------------------------------

/// Story chứa story/reflection/selfReflection/aha/practice cho [situation].
///
/// v2.0 §2.2 mô tả Situation là MỘT thực thể có đủ chín trường. Trong app, dữ
/// liệu đó nằm ở hai bảng ra đời tách nhau — nhưng catalog v2 giữ cùng một mã
/// cho nội dung trong cả hai bảng:
///
///   wr_situations : 72 mục thư viện và một lựa chọn `other` phía client
///   wr_stories    : đúng 72 mã của các mục thư viện
///
/// Chỉ phép ghép mã tuyệt đối mới được trả về. Mã lịch sử cũ, mã không biết,
/// hoặc mã không còn Story tương ứng đều trả về null; không suy diễn theo
/// `scaDimension`, không băm mã, và không mượn Story của tình huống khác.
///
/// Trả về null khi không có Story chính xác — khi đó tầng UI phải tự lo, tuyệt
/// đối không bịa một câu Aha.
WrStory? resolveStoryFor(WrSituation situation, List<WrStory> stories) {
  if (situation.isCustom) return null;
  if (stories.isEmpty) return null;

  for (final s in stories) {
    if (s.storyId == situation.code) return s;
  }

  return null;
}

// ---------------------------------------------------------------------------

/// Trộn một bản sao, không đụng vào danh sách gốc.
List<T> _shuffle<T>(List<T> items, Random? random) {
  final copy = [...items];
  copy.shuffle(random ?? Random());
  return copy;
}
