// Providers cho Thư viện Nội dung Cảm xúc + Bể Lựa chọn.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §VI, §VIII.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_mood_content_repository.dart';
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
final wrChoicePoolProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(wrMoodContentRepositoryProvider);
  try {
    return await repo.fetchChoicePool();
  } catch (_) {
    return const [];
  }
});

/// Nhãn hiển thị của từng cảm xúc trên màn Thư viện.
String moodLabel(Mood mood) => switch (mood) {
      Mood.stressed => 'Căng thẳng',
      Mood.tired => 'Mệt mỏi',
      Mood.okay => 'Khá ổn',
      Mood.happy => 'Đang vui',
    };

/// Tiêu đề thẻ gợi ý trên Home, đổi theo cảm xúc vừa check-in.
///
/// Bốn câu khác nhau chứ không phải một câu chung: người vừa chọn "đang vui"
/// mà thấy "Gợi ý khi căng thẳng" thì thẻ mất hết ý nghĩa.
String moodSuggestionTitle(Mood mood) => switch (mood) {
      Mood.stressed => 'GỢI Ý KHI CĂNG THẲNG',
      Mood.tired => 'GỢI Ý KHI MỆT MỎI',
      Mood.okay => 'GỢI Ý CHO HÔM NAY',
      Mood.happy => 'GIỮ LẠI CẢM XÚC NÀY',
    };
