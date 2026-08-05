// Repository cho Thư viện Nội dung Cảm xúc + Bể Lựa chọn.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §VI, §VIII.
//
// Hai bảng tĩnh, chỉ đọc. Truy vấn Supabase nằm GỌN ở đây; màn hình dùng qua
// provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/checkin.dart';
import '../models/wr_mood_content.dart';

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

abstract class WrMoodContentRepository {
  /// Nội dung theo cảm xúc [mood], đã sắp theo `sort_order`.
  ///
  /// §8.3: Home hiện đúng MỤC ĐẦU TIÊN của mảng (không xoay vòng ở đây), nên
  /// thứ tự trả về phải ổn định giữa các lần gọi.
  Future<List<MoodContent>> fetchByMood(Mood mood);

  /// Toàn bộ thư viện, nhóm theo cảm xúc — dùng cho màn Thư viện (§8.3).
  Future<Map<Mood, List<MoodContent>>> fetchAllGrouped();

  /// Tám câu trong Bể Lựa chọn (§VI), chỉ lấy dòng còn hiệu lực.
  Future<List<String>> fetchChoicePool();
}

// ---------------------------------------------------------------------------
// Provider (ghi đè được trong test)
// ---------------------------------------------------------------------------

final wrMoodContentRepositoryProvider =
    Provider<WrMoodContentRepository>((ref) {
  return SupabaseWrMoodContentRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseWrMoodContentRepository implements WrMoodContentRepository {
  const SupabaseWrMoodContentRepository(this._client);

  final SupabaseClient _client;

  /// §XII.3: app đọc qua VIEW, không đọc bảng gốc.
  ///
  /// View `wr_mood_content_public` cố tình không có cột `script` (kịch bản lồng
  /// tiếng chỉ dùng nội bộ cho đội sản xuất audio). Trỏ thẳng vào
  /// `wr_mood_content` sẽ kéo kịch bản về client — đúng điều tài liệu cấm.
  static const String _table = 'wr_mood_content_public';

  @override
  Future<List<MoodContent>> fetchByMood(Mood mood) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('mood', mood.moodContentKey)
        .order('sort_order', ascending: true);
    return MoodContent.releasable(rows.map(MoodContent.fromJson).toList());
  }

  @override
  Future<Map<Mood, List<MoodContent>>> fetchAllGrouped() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('mood', ascending: true)
        .order('sort_order', ascending: true);

    final grouped = <Mood, List<MoodContent>>{};
    for (final item in MoodContent.releasable(
      rows.map(MoodContent.fromJson).toList(),
    )) {
      grouped.putIfAbsent(item.mood, () => <MoodContent>[]).add(item);
    }
    return grouped;
  }

  @override
  Future<List<String>> fetchChoicePool() async {
    final rows = await _client
        .from('wr_choice_pool')
        .select('text')
        .eq('active', true)
        .order('id', ascending: true);
    return rows.map((r) => r['text'] as String).toList();
  }
}
