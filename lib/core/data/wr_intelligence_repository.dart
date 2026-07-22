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

  /// Mark a theme enrollment as completed for [userId]/[themeId].
  Future<void> completeTheme({required String userId, required String themeId});

  /// Insert a context document record.
  Future<void> insertContextDocument(WrContextDocument d);

  /// Fetch context documents for [userId].
  Future<List<WrContextDocument>> fetchContextDocuments(String userId);

  /// Fetch pattern narratives for [userId].
  Future<List<PatternNarrative>> fetchPatternNarratives(String userId);

  /// Fetch growth journey snapshots for [userId].
  Future<List<GrowthJourneySnapshot>> fetchGrowthSnapshots(String userId);
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
        .from('wr_insights')
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
        .from('wr_insights')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(WrInsight.fromJson).toList();
  }

  @override
  Future<void> insertInsight(WrInsight i) async {
    await _client.from('wr_insights').insert(i.toInsert());
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
    final rows = await _client
        .from('wr_practice_enrollments')
        .select()
        .eq('user_id', userId);
    return rows.map(PracticeEnrollment.fromJson).toList();
  }

  @override
  Future<void> enrollTheme(PracticeEnrollment e) async {
    await _client.from('wr_practice_enrollments').insert(e.toInsert());
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
  Future<void> insertContextDocument(WrContextDocument d) async {
    await _client.from('wr_context_documents').insert(d.toInsert());
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
}
