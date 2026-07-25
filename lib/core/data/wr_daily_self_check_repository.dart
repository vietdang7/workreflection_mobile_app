import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wr_daily_self_check.dart';

/// Kho lưu bản nháp Self-Check hằng ngày, tách khỏi intelligence repository lớn
/// để luồng câu hỏi tiến dần có blast radius nhỏ và dễ kiểm thử độc lập.
abstract class WrDailySelfCheckRepository {
  Future<WrDailySelfCheckDraft> fetchDraft(String userId);

  Future<WrDailySelfCheckDraft> saveAnswer({
    required String userId,
    required String questionId,
    required int value,
  });

  Future<void> markCompleted(String userId);
}

final wrDailySelfCheckRepositoryProvider = Provider<WrDailySelfCheckRepository>(
  (ref) {
    return SupabaseWrDailySelfCheckRepository(Supabase.instance.client);
  },
);

class SupabaseWrDailySelfCheckRepository implements WrDailySelfCheckRepository {
  const SupabaseWrDailySelfCheckRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<WrDailySelfCheckDraft> fetchDraft(String userId) async {
    final row = await _client
        .from('wr_sca_self_check_drafts')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return WrDailySelfCheckDraft(userId: userId);
    return WrDailySelfCheckDraft.fromJson(row);
  }

  @override
  Future<WrDailySelfCheckDraft> saveAnswer({
    required String userId,
    required String questionId,
    required int value,
  }) async {
    if (value < 1 || value > 5) {
      throw ArgumentError.value(value, 'value', 'must be between 1 and 5');
    }
    final current = await fetchDraft(userId);
    final answers = {...current.answers, questionId: value};
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from('wr_sca_self_check_drafts')
        .upsert({
          'user_id': userId,
          'answers': answers,
          'last_prompted_at': now,
          'updated_at': now,
        }, onConflict: 'user_id')
        .select()
        .single();
    return WrDailySelfCheckDraft.fromJson(row);
  }

  @override
  Future<void> markCompleted(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('wr_sca_self_check_drafts')
        .update({'completed_at': now, 'updated_at': now})
        .eq('user_id', userId);
  }
}
