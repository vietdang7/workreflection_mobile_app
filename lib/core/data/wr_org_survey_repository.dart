// Repository cho Khảo sát tổ chức (ESI + eNPS).
//
// Tách hẳn khỏi `WrRepository`: bài này không đọc, không ghi, không tham chiếu
// bất cứ thứ gì thuộc Reflection — đúng như màn giới thiệu hứa với người dùng.
// Để chung một interface với Check-in, Insight và Career Memory là mở sẵn đường
// cho lời hứa đó bị phá về sau mà không ai để ý.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/wr_org_survey_scoring.dart';
import '../models/wr_org_survey.dart';

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

abstract class WrOrgSurveyRepository {
  /// 12 câu đang bật, đã sắp theo `sort_order`.
  Future<List<OrgSurveyQuestion>> fetchQuestions();

  /// Lần làm gần nhất của người dùng hiện tại, null nếu chưa từng làm.
  Future<OrgSurveyResponse?> fetchLatestResponse();

  /// Ghi một lần làm. Trả về bản ghi đã lưu, kèm bốn số trung bình do máy chủ
  /// tính — không phải bản app vừa gửi lên.
  Future<OrgSurveyResponse> submit({
    required Map<String, int> answers,
    int? enps,
  });

  /// Mặt bằng chung để so sánh, một dòng cho mỗi mảng cộng một dòng eNPS.
  Future<List<OrgSurveyBenchmark>> fetchBenchmark();

  /// Ngừng tham gia: xoá mọi câu trả lời của người dùng hiện tại.
  ///
  /// Có mặt vì màn giới thiệu hứa "Có thể ngừng tham gia bất kỳ lúc nào".
  Future<void> withdraw();
}

// ---------------------------------------------------------------------------
// Provider (ghi đè được trong test)
// ---------------------------------------------------------------------------

final wrOrgSurveyRepositoryProvider = Provider<WrOrgSurveyRepository>((ref) {
  return SupabaseWrOrgSurveyRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseWrOrgSurveyRepository implements WrOrgSurveyRepository {
  const SupabaseWrOrgSurveyRepository(this._client);

  final SupabaseClient _client;

  static const String _questionsTable = 'wr_org_survey_questions';
  static const String _responsesTable = 'wr_org_survey_responses';

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  @override
  Future<List<OrgSurveyQuestion>> fetchQuestions() async {
    final rows = await _client
        .from(_questionsTable)
        .select('id, area, text, sort_order')
        .eq('active', true)
        .order('sort_order', ascending: true);
    return rows
        .map((r) => OrgSurveyQuestion.fromJson(r))
        .whereType<OrgSurveyQuestion>()
        .toList();
  }

  @override
  Future<OrgSurveyResponse?> fetchLatestResponse() async {
    final row = await _client
        .from(_responsesTable)
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : OrgSurveyResponse.fromJson(row);
  }

  @override
  Future<OrgSurveyResponse> submit({
    required Map<String, int> answers,
    int? enps,
  }) async {
    // Cố tình KHÔNG gửi bốn cột avg_*: trigger trên bảng tính chúng. Gửi lên
    // thì hai bên có thể lệch nhau mà không ai thấy, cho tới lúc bản so sánh
    // nói một điều vô lý.
    final row = await _client
        .from(_responsesTable)
        .insert({
          'user_id': _uid,
          'answers': answers,
          if (enps != null) 'enps': enps,
        })
        .select()
        .single();
    return OrgSurveyResponse.fromJson(row);
  }

  @override
  Future<List<OrgSurveyBenchmark>> fetchBenchmark() async {
    final rows = await _client.rpc<List<dynamic>>(
      'wr_org_survey_benchmark',
      params: {'min_sample': kOrgSurveyMinSample},
    );
    return rows
        .map((r) => OrgSurveyBenchmark.fromJson(
              Map<String, dynamic>.from(r as Map),
            ))
        .toList();
  }

  @override
  Future<void> withdraw() async {
    await _client.from(_responsesTable).delete().eq('user_id', _uid);
  }
}
