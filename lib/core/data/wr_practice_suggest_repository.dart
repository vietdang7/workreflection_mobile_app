// Gợi ý thực hành bằng AI — gọi Edge Function `wr-practice-suggest`.
//
// Mọi đường hỏng (mất mạng, quá giờ, hết lượt, tắt quyền AI, máy chủ lỗi) đều
// trả [PracticeAiSuggestion.none]: màn tạo chủ đề khi đó dựng bằng luật (lớp 2)
// và người dùng không thấy lỗi nào.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/wr_tr.dart';
import '../logic/wr_practice_v47.dart';
import '../models/wr_intelligence.dart';

const String kWrPracticeSuggestFunction = 'wr-practice-suggest';

/// Chờ AI tối đa ngần này rồi dùng bộ luật (người dùng chốt 20/10/2026).
/// Máy chủ tự cắt ở 11 giây để không đốt token cho câu trả lời không ai chờ.
const Duration kWrPracticeSuggestTimeout = Duration(seconds: 12);

abstract class WrPracticeSuggestRepository {
  Future<PracticeAiSuggestion> suggest({
    required String title,
    required PracticeIntake intake,
  });
}

class SupabaseWrPracticeSuggestRepository
    implements WrPracticeSuggestRepository {
  const SupabaseWrPracticeSuggestRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PracticeAiSuggestion> suggest({
    required String title,
    required PracticeIntake intake,
  }) async {
    try {
      final res = await _client.functions
          .invoke(
            kWrPracticeSuggestFunction,
            headers: wrLocaleHeaders,
            body: {
              'locale': wrLocaleCode,
              'title': title,
              'situation': intake.situation,
              'goal': intake.goal,
              if (intake.tried != null) 'tried': intake.tried,
            },
          )
          .timeout(kWrPracticeSuggestTimeout);
      final data = res.data;
      if (data is! Map) return const PracticeAiSuggestion.none();
      return PracticeAiSuggestion.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return const PracticeAiSuggestion.none();
    }
  }
}

final wrPracticeSuggestRepositoryProvider =
    Provider<WrPracticeSuggestRepository>(
      (ref) => SupabaseWrPracticeSuggestRepository(Supabase.instance.client),
    );
