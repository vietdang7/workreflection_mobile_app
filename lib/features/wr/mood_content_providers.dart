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
final wrTodayMoodContentProvider =
    FutureProvider<List<MoodContent>>((ref) async {
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
final wrMoodLibraryProvider =
    FutureProvider<Map<Mood, List<MoodContent>>>((ref) async {
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
      Mood.stressed => tr('GỢI Ý KHI CĂNG THẲNG', 'IDEAS WHEN YOU ARE TENSE'),
      Mood.tired => tr('GỢI Ý KHI MỆT MỎI', 'IDEAS WHEN YOU ARE DRAINED'),
      Mood.foggy => tr('GỢI Ý KHI MỌI THỨ CHƯA RÕ RÀNG', 'IDEAS WHEN THINGS ARE UNCLEAR'),
      Mood.outofsync => tr('GỢI Ý KHI MỌI THỨ LỆCH NHAU', 'IDEAS WHEN THINGS ARE OUT OF SYNC'),
      Mood.okay => tr('GỢI Ý CHO HÔM NAY', 'IDEAS FOR TODAY'),
      Mood.happy => tr('GIỮ LẠI CẢM XÚC NÀY', 'HOLD ON TO THIS FEELING'),
    };
