// Providers cho Thư viện Nội dung Cảm xúc + Bể Lựa chọn.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §VI, §VIII.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_mood_content_repository.dart';
import '../../core/l10n/wr_tr.dart';
import '../../core/models/checkin.dart';
import '../../core/models/wr_mood_content.dart';
import 'wr_providers.dart';

/// Nội dung gợi ý theo cảm xúc đã check-in hôm nay.
///
/// §8.3: Home hiện đúng MỘT mục — mục đầu tiên của nhóm, không xoay vòng. Xoay
/// vòng ở đây sẽ làm thẻ đổi nội dung mỗi lần mở app, khiến người dùng không
/// quay lại được bài đang đọc dở.
///
/// Chưa check-in thì rỗng: không có cảm xúc nào để bám vào, và bịa một gợi ý
/// mặc định thì sai tinh thần "gợi ý theo đúng cảm giác lúc này".
final wrTodayMoodContentProvider = FutureProvider<List<MoodContent>>((
  ref,
) async {
  final mood = ref.watch(todayCheckinProvider).valueOrNull?.mood;
  if (mood == null) return const [];
  final repo = ref.watch(wrMoodContentRepositoryProvider);
  try {
    return await repo.fetchByMood(mood);
  } catch (_) {
    // Thư viện là nội dung phụ trợ; lỗi đọc không được chặn màn Home.
    return const [];
  }
});

/// Toàn bộ thư viện, nhóm theo cảm xúc — cho màn "Xem thêm gợi ý" (§8.3).
/// Bài nghe đứng trước bài đọc, giữ nguyên thứ tự `sort_order` trong từng
/// loại. Họp khách 14/10: thư viện cảm xúc ưu tiên bài nghe (Healing Audio);
/// bài nghe chưa có bản thu thì vẫn xếp sau bài đọc.
List<MoodContent> audioFirst(Iterable<MoodContent> items) {
  final list = items.toList();
  int rank(MoodContent c) =>
      c.type == MoodContentType.audio && c.hasAudio ? 0 : 1;
  // Sắp ổn định: `List.sort` không hứa giữ thứ tự, nên so thêm vị trí cũ.
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final r = rank(a.$2).compareTo(rank(b.$2));
    return r != 0 ? r : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

final wrMoodLibraryProvider = FutureProvider<Map<Mood, List<MoodContent>>>((
  ref,
) async {
  final repo = ref.watch(wrMoodContentRepositoryProvider);
  try {
    return await repo.fetchAllGrouped();
  } catch (_) {
    return const {};
  }
});

/// Tám câu trong Bể Lựa chọn (§VI).
///
/// Đọc một lần rồi giữ: đây là bảng tĩnh 8 dòng, không đổi giữa các phiên.
final wrChoicePoolProvider = FutureProvider<List<ChoicePoolLine>>((ref) async {
  final repo = ref.watch(wrMoodContentRepositoryProvider);
  try {
    return await repo.fetchChoicePool();
  } catch (_) {
    return const [];
  }
});

/// Nhãn hiển thị của từng cảm xúc trên màn Thư viện.
///
/// Nguyên văn `MOOD_LABELS` của mockup v16 — hai nhãn thêm 24/08/2026 cố ý ngắn
/// ("Mơ hồ", "Lệch nhau") vì chúng còn được ghép vào câu ở thẻ "Hệ thống nhận
/// ra".
String moodLabel(Mood mood) => switch (mood) {
  Mood.stressed => tr('Căng thẳng', 'Tense'),
  Mood.tired => tr('Mệt mỏi', 'Drained'),
  Mood.foggy => tr('Mơ hồ', 'Unclear'),
  Mood.outofsync => tr('Lệch nhau', 'Out of sync'),
  Mood.okay => tr('Khá ổn', 'Doing okay'),
  Mood.happy => tr('Đang vui', 'Feeling good'),
};

/// Tiêu đề thẻ gợi ý trên Home, đổi theo cảm xúc vừa check-in.
///
/// Sáu câu khác nhau chứ không phải một câu chung: người vừa chọn "đang vui"
/// mà thấy "Gợi ý khi căng thẳng" thì thẻ mất hết ý nghĩa.
String moodSuggestionTitle(Mood mood) => switch (mood) {
  // Nguyên văn `cardTitle` của mockup Sprint 2: chữ thường, không viết hoa —
  // nó đứng đầu dòng meta "Gợi ý khi căng thẳng · BÀI ĐỌC · 2 phút đọc".
  Mood.stressed => tr('Gợi ý khi căng thẳng', 'Ideas for when you feel tense'),
  Mood.tired => tr('Gợi ý khi mệt mỏi', 'Ideas for when you feel drained'),
  Mood.foggy => tr(
    'Gợi ý khi mọi thứ chưa rõ ràng',
    'Ideas for when things are unclear',
  ),
  Mood.outofsync => tr(
    'Gợi ý khi mọi thứ lệch nhau',
    'Ideas for when things are out of sync',
  ),
  Mood.okay => tr('Gợi ý cho hôm nay', 'Ideas for today'),
  Mood.happy => tr('Giữ lại cảm xúc này', 'Hold on to this feeling'),
};
