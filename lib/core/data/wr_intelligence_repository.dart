// WR Intelligence repository — WR Two-Layer Architecture v1.2.
// Abstract interface + SupabaseWrIntelligenceRepository + Riverpod provider.
// Supabase queries live ONLY here.
//
// NOTE: Repository does NOT enforce premium gating.
// UI layer must call WrEntitlement.canUseFeature() before calling premium methods.
// See lib/core/logic/wr_entitlement.dart for gating logic.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wr_intelligence.dart';
import '../models/wr_mood_content.dart';

/// Tên Edge Function đọc tài liệu bối cảnh bằng AI.
const String kWrDocAnalyzeFunction = 'wr-doc-analyze';

/// Lỗi khi đọc tài liệu — [message] là câu tiếng Việt để hiện thẳng cho người
/// dùng, không phải mã lỗi kỹ thuật.
class WrDocAnalysisException implements Exception {
  const WrDocAnalysisException(this.message, {this.needsPremium = false});

  final String message;

  /// Máy chủ từ chối vì gói: màn hình đổi sang mời nâng cấp thay vì báo lỗi.
  final bool needsPremium;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class WrIntelligenceRepository {
  /// Fetch entitlement record for [userId]. Returns null if no record (assume free).
  Future<WrEntitlementRecord?> fetchEntitlement(String userId);

  /// Fetch pattern counts for [userId], ordered by occurrence_count desc.
  Future<List<PatternCount>> fetchPatternCounts(String userId);

  /// Upsert a situation occurrence for [userId].
  /// If (user_id, situation_code) exists: increment occurrence_count, update last_seen_at.
  /// If not: insert new row with occurrence_count=1.
  /// Uses supabase upsert with onConflict: 'user_id,situation_code'.
  Future<void> recordSituationOccurrence({
    required String userId,
    required String situationCode,
    required String scaDimensionDb,
  });

  /// Decrement occurrence_count for (userId, situationCode).
  /// If count > 1: update count - 1. If count == 1: delete the row entirely.
  Future<void> decrementSituationOccurrence({
    required String userId,
    required String situationCode,
  });

  /// Insert a reflection step.
  Future<void> insertReflectionStep(ReflectionStep step);

  /// Insert a SCA self-check response.
  Future<void> insertSelfCheckResponse(ScaSelfCheckResponse r);

  /// Fetch self-check history for [userId], newest first.
  /// [limit] defaults to 10.
  Future<List<ScaSelfCheckResponse>> fetchSelfCheckHistory(String userId, {int? limit});

  /// Fetch the most recent insight for [userId] (Free tier — latest only).
  Future<WrInsight?> fetchLatestInsight(String userId);

  /// Fetch all insights for [userId] (UI gates premium access via WrEntitlement).
  /// IMPORTANT: this method does NOT enforce premium — caller must check entitlement.
  Future<List<WrInsight>> fetchInsightHistory(String userId);

  /// Insert an insight record.
  Future<void> insertInsight(WrInsight i);

  /// Fetch all practice themes.
  Future<List<PracticeTheme>> fetchPracticeThemes();

  /// Fetch practice steps for [themeId], ordered by step_order ascending.
  Future<List<PracticeStep>> fetchPracticeSteps(String themeId);

  /// Fetch enrollments for [userId].
  Future<List<PracticeEnrollment>> fetchEnrollments(String userId);

  /// Enroll user in a practice theme.
  Future<void> enrollTheme(PracticeEnrollment e);

  /// Update the completedSteps list for an enrollment.
  Future<void> updateEnrollmentSteps({
    required String userId,
    required String themeId,
    required List<String> completedSteps,
  });

  /// Mark a theme enrollment as completed for [userId]/[themeId].
  Future<void> completeTheme({required String userId, required String themeId});

  /// Insert a context document record. Trả về id vừa tạo (null nếu không lấy
  /// được) — cần id để gọi phân tích ngay sau khi tải lên.
  Future<String?> insertContextDocument(WrContextDocument d);

  /// Fetch context documents for [userId].
  Future<List<WrContextDocument>> fetchContextDocuments(String userId);

  /// Nhờ Edge Function `wr-doc-analyze` đọc tài liệu [documentId] bằng AI.
  ///
  /// Trả về bản ghi đã cập nhật. Ném [WrDocAnalysisException] với câu tiếng
  /// Việt do máy chủ soạn khi hỏng — đây là thứ hiện thẳng lên màn hình.
  Future<WrContextDocument> analyzeContextDocument(String documentId);

  /// Xoá một tài liệu bối cảnh (kèm file trong Storage nếu xoá được).
  Future<void> deleteContextDocument(WrContextDocument doc);

  /// Fetch pattern narratives for [userId].
  Future<List<PatternNarrative>> fetchPatternNarratives(String userId);

  /// Fetch growth journey snapshots for [userId].
  Future<List<GrowthJourneySnapshot>> fetchGrowthSnapshots(String userId);

  // --- Hai Lớp v1.6 ---

  /// Cơ hội phát triển mới nhất của [userId] (§XI). Null khi chưa tổng hợp lần
  /// nào — khi đó UI im lặng thay vì bịa nội dung.
  Future<GrowthOpportunity?> fetchLatestGrowthOpportunity(String userId);

  /// Lưu một gợi ý Cơ hội phát triển đã tổng hợp (§11.5).
  Future<void> insertGrowthOpportunity(GrowthOpportunity opportunity);

  /// Ghi chú tùy chọn khi hoàn thành một bước Thực hành (§VII).
  ///
  /// Trả về id của dòng vừa ghi, để nối với mục Career Memory sinh ra từ nó.
  /// Ghi lại cùng một bước thì cập nhật chính dòng cũ.
  Future<String?> upsertPracticeStepNote(PracticeStepNote note);

  /// Ghi một câu hỏi nghề nghiệp người dùng vừa gửi.
  Future<void> insertCareerQuestion(CareerQuestion question);

  /// Câu hỏi nghề nghiệp của [userId], mới nhất trước.
  Future<List<CareerQuestion>> fetchCareerQuestions(String userId);
}

// ---------------------------------------------------------------------------
// Riverpod provider (overridable in tests)
// ---------------------------------------------------------------------------

final wrIntelligenceRepositoryProvider = Provider<WrIntelligenceRepository>((ref) {
  return SupabaseWrIntelligenceRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Live Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseWrIntelligenceRepository implements WrIntelligenceRepository {
  const SupabaseWrIntelligenceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<WrEntitlementRecord?> fetchEntitlement(String userId) async {
    final rows = await _client
        .from('wr_entitlements')
        .select()
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return WrEntitlementRecord.fromJson(rows.first);
  }

  @override
  Future<List<PatternCount>> fetchPatternCounts(String userId) async {
    final rows = await _client
        .from('wr_pattern_counts')
        .select()
        .eq('user_id', userId)
        .order('occurrence_count', ascending: false);
    return rows.map(PatternCount.fromJson).toList();
  }

  @override
  Future<void> recordSituationOccurrence({
    required String userId,
    required String situationCode,
    required String scaDimensionDb,
  }) async {
    // Read-then-write: acceptable for single-user mobile client where race
    // conditions are negligible (one active session per device).
    final existing = await _client
        .from('wr_pattern_counts')
        .select('id, occurrence_count')
        .eq('user_id', userId)
        .eq('situation_code', situationCode)
        .maybeSingle();

    final now = DateTime.now().toIso8601String();
    if (existing != null) {
      final newCount = (existing['occurrence_count'] as int) + 1;
      await _client
          .from('wr_pattern_counts')
          .update({'occurrence_count': newCount, 'last_seen_at': now})
          .eq('id', existing['id'] as String);
    } else {
      await _client.from('wr_pattern_counts').insert({
        'user_id': userId,
        'situation_code': situationCode,
        'sca_dimension': scaDimensionDb,
        'occurrence_count': 1,
        'last_seen_at': now,
      });
    }
  }

  @override
  Future<void> decrementSituationOccurrence({
    required String userId,
    required String situationCode,
  }) async {
    final existing = await _client
        .from('wr_pattern_counts')
        .select('id, occurrence_count')
        .eq('user_id', userId)
        .eq('situation_code', situationCode)
        .maybeSingle();
    if (existing == null) return;
    final count = existing['occurrence_count'] as int;
    if (count > 1) {
      await _client
          .from('wr_pattern_counts')
          .update({'occurrence_count': count - 1})
          .eq('id', existing['id'] as String);
    } else {
      await _client
          .from('wr_pattern_counts')
          .delete()
          .eq('id', existing['id'] as String);
    }
  }

  @override
  Future<void> insertReflectionStep(ReflectionStep step) async {
    await _client.from('wr_reflection_steps').insert(step.toInsert());
  }

  @override
  Future<void> insertSelfCheckResponse(ScaSelfCheckResponse r) async {
    await _client.from('wr_sca_self_check_responses').insert(r.toInsert());
  }

  @override
  Future<List<ScaSelfCheckResponse>> fetchSelfCheckHistory(
    String userId, {
    int? limit,
  }) async {
    var query = _client
        .from('wr_sca_self_check_responses')
        .select()
        .eq('user_id', userId)
        .order('taken_at', ascending: false);
    if (limit != null) {
      query = query.limit(limit);
    }
    final rows = await query;
    return rows.map(ScaSelfCheckResponse.fromJson).toList();
  }

  @override
  Future<WrInsight?> fetchLatestInsight(String userId) async {
    final rows = await _client
        .from('wr_reflection_insights')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return WrInsight.fromJson(rows.first);
  }

  @override
  Future<List<WrInsight>> fetchInsightHistory(String userId) async {
    // NOTE: Does NOT enforce premium gating. Caller must check WrEntitlement.
    final rows = await _client
        .from('wr_reflection_insights')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(WrInsight.fromJson).toList();
  }

  @override
  Future<void> insertInsight(WrInsight i) async {
    await _client.from('wr_reflection_insights').insert(i.toInsert());
  }

  @override
  Future<List<PracticeTheme>> fetchPracticeThemes() async {
    final rows = await _client
        .from('wr_practice_themes')
        .select()
        .order('theme_id', ascending: true);
    return rows.map(PracticeTheme.fromJson).toList();
  }

  @override
  Future<List<PracticeStep>> fetchPracticeSteps(String themeId) async {
    final rows = await _client
        .from('wr_practice_steps')
        .select()
        .eq('theme_id', themeId)
        .order('step_order', ascending: true);
    return rows.map(PracticeStep.fromJson).toList();
  }

  @override
  Future<List<PracticeEnrollment>> fetchEnrollments(String userId) async {
    // `order` không phải trang trí: không có nó, Postgres được phép trả về thứ
    // tự bất kỳ, mà cả Home ("chủ đề đang dở") lẫn tab Phát triển ("chủ đề trọng
    // tâm") đều lấy phần tử ĐẦU của danh sách này. Không sắp thì hai màn có thể
    // nói về hai chủ đề khác nhau, và cùng một màn đổi chủ đề giữa hai lần mở.
    // Ghi danh sớm nhất lên trước — thứ tự người dùng đã thấy từ đầu.
    final rows = await _client
        .from('wr_practice_enrollments')
        .select()
        .eq('user_id', userId)
        .order('started_at', ascending: true);
    return rows.map(PracticeEnrollment.fromJson).toList();
  }

  @override
  Future<void> enrollTheme(PracticeEnrollment e) async {
    await _client.from('wr_practice_enrollments').insert(e.toInsert());
  }

  @override
  Future<void> updateEnrollmentSteps({
    required String userId,
    required String themeId,
    required List<String> completedSteps,
  }) async {
    await _client
        .from('wr_practice_enrollments')
        .update({'completed_steps': completedSteps})
        .eq('user_id', userId)
        .eq('theme_id', themeId);
  }

  @override
  Future<void> completeTheme({
    required String userId,
    required String themeId,
  }) async {
    await _client
        .from('wr_practice_enrollments')
        .update({'completed_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .eq('theme_id', themeId);
  }

  @override
  Future<String?> insertContextDocument(WrContextDocument d) async {
    final row = await _client
        .from('wr_context_documents')
        .insert(d.toInsert())
        .select('id')
        .maybeSingle();
    return row?['id'] as String?;
  }

  @override
  Future<WrContextDocument> analyzeContextDocument(String documentId) async {
    try {
      final res = await _client.functions.invoke(
        kWrDocAnalyzeFunction,
        body: {'documentId': documentId},
      );
      final data = res.data;
      if (data is! Map || data['status'] != 'ready') {
        throw const WrDocAnalysisException(
          'Chưa đọc được tài liệu này. Bạn thử lại sau nhé.',
        );
      }
    } on FunctionException catch (e) {
      throw _docFailure(e);
    } on WrDocAnalysisException {
      rethrow;
    } catch (_) {
      throw const WrDocAnalysisException(
        'Không kết nối được lúc này. Bạn kiểm tra mạng rồi thử lại nhé.',
      );
    }

    // Đọc lại từ bảng thay vì tin thân phản hồi: nguồn sự thật là dòng dữ liệu,
    // và app còn cần đúng những trường khác (ngày phân tích, model) mà hàm
    // không trả về hết.
    final row = await _client
        .from('wr_context_documents')
        .select()
        .eq('id', documentId)
        .maybeSingle();
    if (row == null) {
      throw const WrDocAnalysisException('Không tìm thấy tài liệu này.');
    }
    return WrContextDocument.fromJson(row);
  }

  @override
  Future<void> deleteContextDocument(WrContextDocument doc) async {
    final id = doc.id;
    if (id == null) return;
    await _client.from('wr_context_documents').delete().eq('id', id);
    try {
      await _client.storage.from('context-docs').remove([doc.filePath]);
    } catch (_) {
      // Dòng đã xoá rồi thì tài liệu coi như biến mất với người dùng. File mồ
      // côi trong Storage là việc của người vận hành, không đáng để báo lỗi.
    }
  }

  /// Lấy câu báo lỗi tiếng Việt Edge Function đã soạn sẵn.
  WrDocAnalysisException _docFailure(FunctionException e) {
    final d = e.details;
    if (d is Map) {
      final msg = d['error'];
      if (msg is String && msg.trim().isNotEmpty) {
        return WrDocAnalysisException(
          msg.trim(),
          needsPremium: d['needsPremium'] == true,
        );
      }
    }
    return const WrDocAnalysisException(
      'Chưa đọc được tài liệu này. Bạn thử lại sau nhé.',
    );
  }

  @override
  Future<List<WrContextDocument>> fetchContextDocuments(String userId) async {
    final rows = await _client
        .from('wr_context_documents')
        .select()
        .eq('user_id', userId)
        .order('uploaded_at', ascending: false);
    return rows.map(WrContextDocument.fromJson).toList();
  }

  @override
  Future<List<PatternNarrative>> fetchPatternNarratives(String userId) async {
    final rows = await _client
        .from('wr_pattern_narratives')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(PatternNarrative.fromJson).toList();
  }

  @override
  Future<List<GrowthJourneySnapshot>> fetchGrowthSnapshots(String userId) async {
    final rows = await _client
        .from('wr_growth_journey_snapshots')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(GrowthJourneySnapshot.fromJson).toList();
  }

  // --- Hai Lớp v1.6 ---

  @override
  Future<GrowthOpportunity?> fetchLatestGrowthOpportunity(String userId) async {
    final rows = await _client
        .from('wr_growth_opportunities')
        .select()
        .eq('user_id', userId)
        .order('generated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return GrowthOpportunity.fromJson(rows.first);
  }

  @override
  Future<void> insertGrowthOpportunity(GrowthOpportunity opportunity) async {
    await _client
        .from('wr_growth_opportunities')
        .insert(opportunity.toInsert());
  }

  @override
  Future<String?> upsertPracticeStepNote(PracticeStepNote note) async {
    final rows = await _client
        .from('wr_practice_step_notes')
        .upsert(note.toInsert(), onConflict: 'user_id,step_id')
        .select('id');
    if (rows.isEmpty) return null;
    return rows.first['id'] as String?;
  }

  @override
  Future<void> insertCareerQuestion(CareerQuestion question) async {
    await _client.from('wr_career_questions').insert(question.toInsert());
  }

  @override
  Future<List<CareerQuestion>> fetchCareerQuestions(String userId) async {
    final rows = await _client
        .from('wr_career_questions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(20);
    return rows.map(CareerQuestion.fromJson).toList();
  }
}
