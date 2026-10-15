// Khối "Bạn đang khó ở chỗ nào" — gọi Edge Function `wr-experience-read`.
//
// Nguồn: "Logic đọc hiểu mình.docx" §2 (15/10/2026). Máy chủ tự nhớ đệm theo
// nguyên liệu, nên gọi lại với cùng danh sách chuyện chỉ tốn một lượt đọc bảng.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/wr_tr.dart';
import '../logic/wr_experience_reading.dart';

const String kWrExperienceReadFunction = 'wr-experience-read';

abstract class WrExperienceReadRepository {
  /// Xin bản đọc cho các nhóm trong [pillars] (xem [difficultyRequest]).
  ///
  /// KHÔNG BAO GIỜ NÉM: app gọi tự động khi mở màn. Hỏng thì trả bản rỗng và
  /// màn hình chỉ hiện số đếm, đúng như lúc chưa đủ dữ liệu.
  Future<ExperienceAiReading> read(List<Map<String, dynamic>> pillars);
}

class SupabaseWrExperienceReadRepository implements WrExperienceReadRepository {
  const SupabaseWrExperienceReadRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ExperienceAiReading> read(List<Map<String, dynamic>> pillars) async {
    try {
      final res = await _client.functions.invoke(
        kWrExperienceReadFunction,
        headers: wrLocaleHeaders,
        body: {'locale': wrLocaleCode, 'pillars': pillars},
      );
      final data = res.data;
      if (data is! Map) return const ExperienceAiReading.none();
      return ExperienceAiReading.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return const ExperienceAiReading.none();
    }
  }
}

final wrExperienceReadRepositoryProvider = Provider<WrExperienceReadRepository>(
  (ref) => SupabaseWrExperienceReadRepository(Supabase.instance.client),
);
