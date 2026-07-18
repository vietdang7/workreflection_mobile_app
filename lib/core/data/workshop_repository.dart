// Workshop repository — Phase 3.
// Abstract interface + SupabaseWorkshopRepository + provider.
// Supabase queries live ONLY here. Screens consume via workshopRepositoryProvider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/survey_models.dart';
import '../models/workshop_models.dart';

// ---------------------------------------------------------------------------
// WorkshopSurveySet
// ---------------------------------------------------------------------------

/// Holds the active question set for a workshop: its id and ordered questions.
class WorkshopSurveySet {
  const WorkshopSurveySet({
    required this.questionSetId,
    required this.questions,
  });

  final String questionSetId;
  final List<CcQuestion> questions;
}

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class WorkshopRepository {
  /// Returns all active public workshops ordered by date asc.
  /// Filters: is_active=true, status='active', org_id IS NULL.
  Future<List<WorkshopDetail>> getActiveWorkshops();

  /// Returns a single workshop by id, or null if not found.
  Future<WorkshopDetail?> getWorkshop(String id);

  /// Returns the current user's non-cancelled registration for a workshop,
  /// or null if they have not registered.
  Future<WorkshopRegistration?> getMyRegistration(String workshopId);

  /// Returns all registrations for the current user, newest first.
  Future<List<WorkshopRegistration>> getMyRegistrations();

  /// Registers the current user for a free workshop.
  ///
  /// Inserts cc_workshop_registrations {user_id, workshop_id, status:'registered'}
  /// then increments cc_workshops.current_participants client-side (matching web).
  /// Catches PostgrestException code '23505' (unique constraint) and treats it
  /// as already-registered (idempotent — no rethrow, no increment).
  Future<void> registerFree(String workshopId);

  /// Looks up a workshop by its check-in code (case-insensitive).
  Future<WorkshopDetail?> getWorkshopByCheckinCode(String code);

  /// Marks a registration as checked-in.
  ///
  /// Updates checked_in_at, attended=true, attended_at — does NOT change status
  /// (matching web behaviour).
  Future<void> checkIn(String registrationId);

  /// Records image-consent for a registration.
  Future<void> setImageConsent(String registrationId, bool consent);

  /// Returns attachments for a workshop ordered by sort_order asc.
  Future<List<WorkshopAttachment>> getAttachments(String workshopId);

  /// Returns the active survey set for a workshop, or null when none is assigned.
  ///
  /// Looks up cc_workshop_question_set_assignments (is_active=true),
  /// fetches the question_ids from cc_workshop_question_sets, then fetches
  /// questions from cc_questions preserving the array order.
  Future<WorkshopSurveySet?> getWorkshopSurveySet(String workshopId);

  /// Returns true when the current user has already submitted a completed
  /// workshop survey for [workshopId].
  Future<bool> hasSubmittedWorkshopSurvey(String workshopId);

  /// Submits a workshop survey.
  ///
  /// Flow:
  ///   1. INSERT cc_workshop_surveys → get survey id
  ///   2. Bulk INSERT cc_workshop_responses
  ///   3. UPDATE cc_workshop_surveys SET status='completed', completed_at=now()
  Future<void> submitWorkshopSurvey({
    required String workshopId,
    required String questionSetId,
    required Map<String, int> answers,
  });

  /// Returns the survey_id of the user's completed survey for [workshopId],
  /// or null if not found. Used to navigate to the results screen after submit.
  Future<String?> getCompletedSurveyId(String workshopId);

  /// Returns aggregate score data for a completed survey by [surveyId].
  ///
  /// Fetches cc_workshop_responses joined with cc_questions layer data,
  /// computes per-layer averages and an overall weighted total.
  Future<WorkshopSurveyResults?> getSurveyResults(String surveyId);

  /// Cancels the current user's registration for a workshop.
  ///
  /// Sets status='cancelled', payment_status='cancelled' and decrements
  /// current_participants — matching the web MyWorkshops.tsx cancelMutation.
  Future<void> cancelRegistration(String registrationId, String workshopId);
}

// ---------------------------------------------------------------------------
// Riverpod provider (overridable in tests)
// ---------------------------------------------------------------------------

final workshopRepositoryProvider = Provider<WorkshopRepository>((ref) {
  return SupabaseWorkshopRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Live Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseWorkshopRepository implements WorkshopRepository {
  const SupabaseWorkshopRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  // ---------------------------------------------------------------------------
  // Workshops
  // ---------------------------------------------------------------------------

  @override
  Future<List<WorkshopDetail>> getActiveWorkshops() async {
    final rows = await _client
        .from('cc_workshops')
        .select()
        .eq('is_active', true)
        .eq('status', 'active')
        .isFilter('org_id', null)
        .order('date', ascending: true);
    return rows.map(WorkshopDetail.fromJson).toList();
  }

  @override
  Future<WorkshopDetail?> getWorkshop(String id) async {
    final rows = await _client
        .from('cc_workshops')
        .select()
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return WorkshopDetail.fromJson(rows.first);
  }

  @override
  Future<WorkshopRegistration?> getMyRegistration(String workshopId) async {
    final uid = _uid;
    final rows = await _client
        .from('cc_workshop_registrations')
        .select()
        .eq('user_id', uid)
        .eq('workshop_id', workshopId)
        .neq('status', 'cancelled')
        .limit(1);
    if (rows.isEmpty) return null;
    return WorkshopRegistration.fromJson(rows.first);
  }

  @override
  Future<List<WorkshopRegistration>> getMyRegistrations() async {
    final uid = _uid;
    final rows = await _client
        .from('cc_workshop_registrations')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return rows.map(WorkshopRegistration.fromJson).toList();
  }

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  @override
  Future<void> registerFree(String workshopId) async {
    final uid = _uid;

    // Insert the registration. Catch duplicate (23505) and treat as success.
    // The increment below is skipped in that case (already counted).
    try {
      await _client.from('cc_workshop_registrations').insert({
        'user_id': uid,
        'workshop_id': workshopId,
        'status': 'registered',
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // already registered — idempotent
      rethrow;
    }

    // Increment current_participants client-side, matching web behaviour.
    // This is a read-then-write (small race acceptable — same pattern as web).
    final workshopRows = await _client
        .from('cc_workshops')
        .select('current_participants')
        .eq('id', workshopId)
        .limit(1);
    final current = workshopRows.isNotEmpty
        ? workshopRows.first['current_participants'] as int? ?? 0
        : 0;
    await _client
        .from('cc_workshops')
        .update({'current_participants': current + 1}).eq('id', workshopId);
  }

  // ---------------------------------------------------------------------------
  // Check-in
  // ---------------------------------------------------------------------------

  @override
  Future<WorkshopDetail?> getWorkshopByCheckinCode(String code) async {
    final rows = await _client
        .from('cc_workshops')
        .select()
        .eq('checkin_code', code.toUpperCase())
        .limit(1);
    if (rows.isEmpty) return null;
    return WorkshopDetail.fromJson(rows.first);
  }

  @override
  Future<void> checkIn(String registrationId) async {
    final now = DateTime.now().toIso8601String();
    await _client.from('cc_workshop_registrations').update({
      'checked_in_at': now,
      'attended': true,
      'attended_at': now,
      // NOTE: status is intentionally NOT updated — web check-in does not
      // change status (verified against web source CheckIn.tsx lines 86-94).
    }).eq('id', registrationId);
  }

  @override
  Future<void> setImageConsent(String registrationId, bool consent) async {
    await _client.from('cc_workshop_registrations').update({
      'image_consent': consent,
      'image_consent_at': DateTime.now().toIso8601String(),
    }).eq('id', registrationId);
  }

  // ---------------------------------------------------------------------------
  // Attachments
  // ---------------------------------------------------------------------------

  @override
  Future<List<WorkshopAttachment>> getAttachments(String workshopId) async {
    final rows = await _client
        .from('cc_workshop_attachments')
        .select()
        .eq('workshop_id', workshopId)
        .order('sort_order', ascending: true);
    return rows.map(WorkshopAttachment.fromJson).toList();
  }

  // ---------------------------------------------------------------------------
  // Post-workshop survey
  // ---------------------------------------------------------------------------

  @override
  Future<WorkshopSurveySet?> getWorkshopSurveySet(String workshopId) async {
    // Step 1: find the active assignment for this workshop.
    final assignmentRows = await _client
        .from('cc_workshop_question_set_assignments')
        .select('question_set_id')
        .eq('workshop_id', workshopId)
        .eq('is_active', true)
        .limit(1);

    if (assignmentRows.isEmpty) return null;

    final questionSetId = assignmentRows.first['question_set_id'] as String;

    // Step 2: fetch the question_set to get the ordered question_ids array.
    final setRows = await _client
        .from('cc_workshop_question_sets')
        .select('question_ids')
        .eq('id', questionSetId)
        .limit(1);

    if (setRows.isEmpty) return null;

    final rawIds = setRows.first['question_ids'];
    if (rawIds == null) return null;

    final questionIds = (rawIds as List).cast<String>();
    if (questionIds.isEmpty) return null;

    // Step 3: fetch questions from cc_questions and sort by the order in
    // question_ids (the array order is the canonical display order).
    final questionRows = await _client
        .from('cc_questions')
        .select()
        .inFilter('id', questionIds);

    final byId = <String, Map<String, dynamic>>{
      for (final row in questionRows) row['id'] as String: row,
    };

    final questions = questionIds
        .where((id) => byId.containsKey(id))
        .map((id) => CcQuestion.fromJson(byId[id]!))
        .toList();

    return WorkshopSurveySet(
      questionSetId: questionSetId,
      questions: questions,
    );
  }

  @override
  Future<bool> hasSubmittedWorkshopSurvey(String workshopId) async {
    final uid = _uid;

    // We need the active question_set_id to check for a completed survey,
    // matching the web hasSubmitted check which includes question_set_id.
    final assignmentRows = await _client
        .from('cc_workshop_question_set_assignments')
        .select('question_set_id')
        .eq('workshop_id', workshopId)
        .eq('is_active', true)
        .limit(1);

    if (assignmentRows.isEmpty) return false;
    final questionSetId = assignmentRows.first['question_set_id'] as String;

    final surveyRows = await _client
        .from('cc_workshop_surveys')
        .select('id')
        .eq('user_id', uid)
        .eq('workshop_id', workshopId)
        .eq('question_set_id', questionSetId)
        .eq('status', 'completed')
        .limit(1);

    return surveyRows.isNotEmpty;
  }

  @override
  Future<void> submitWorkshopSurvey({
    required String workshopId,
    required String questionSetId,
    required Map<String, int> answers,
  }) async {
    final uid = _uid;
    final now = DateTime.now().toIso8601String();

    // Step 1: insert cc_workshop_surveys and get the generated id.
    final surveyRow = await _client.from('cc_workshop_surveys').insert({
      'user_id': uid,
      'workshop_id': workshopId,
      'question_set_id': questionSetId,
      'status': 'in_progress',
      'started_at': now,
    }).select('id').single();

    final surveyId = surveyRow['id'] as String;

    // Step 2: bulk insert responses.
    final responses = answers.entries
        .map((e) => {
              'survey_id': surveyId,
              'question_id': e.key, // stored as text in cc_workshop_responses
              'answer_value': e.value,
            })
        .toList();
    await _client.from('cc_workshop_responses').insert(responses);

    // Step 3: mark survey completed.
    await _client.from('cc_workshop_surveys').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', surveyId);
  }

  // ---------------------------------------------------------------------------
  // Survey results
  // ---------------------------------------------------------------------------

  @override
  Future<String?> getCompletedSurveyId(String workshopId) async {
    final uid = _uid;

    // Need the active question_set_id to identify the correct survey row.
    final assignmentRows = await _client
        .from('cc_workshop_question_set_assignments')
        .select('question_set_id')
        .eq('workshop_id', workshopId)
        .eq('is_active', true)
        .limit(1);

    if (assignmentRows.isEmpty) return null;
    final questionSetId = assignmentRows.first['question_set_id'] as String;

    final rows = await _client
        .from('cc_workshop_surveys')
        .select('id')
        .eq('user_id', uid)
        .eq('workshop_id', workshopId)
        .eq('question_set_id', questionSetId)
        .eq('status', 'completed')
        .order('completed_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) return null;
    return rows.first['id'] as String;
  }

  @override
  Future<WorkshopSurveyResults?> getSurveyResults(String surveyId) async {
    // Fetch all responses for this survey.
    final responseRows = await _client
        .from('cc_workshop_responses')
        .select('question_id, answer_value')
        .eq('survey_id', surveyId);

    if (responseRows.isEmpty) return null;

    final questionIds =
        responseRows.map((r) => r['question_id'] as String).toSet().toList();

    // Fetch question layers from cc_questions.
    final questionRows = await _client
        .from('cc_questions')
        .select('id, layer')
        .inFilter('id', questionIds);

    final layerById = <String, String>{
      for (final q in questionRows)
        q['id'] as String: (q['layer'] as String).toUpperCase(),
    };

    // Accumulate per-layer values.
    final layerValues = <String, List<double>>{};
    for (final r in responseRows) {
      final qId = r['question_id'] as String;
      final layer = layerById[qId];
      if (layer == null) continue;
      final val = (r['answer_value'] as num).toDouble();
      layerValues.putIfAbsent(layer, () => []).add(val);
    }

    double avg(List<double> vals) =>
        vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;

    double round1(double v) =>
        (v * 10).round() / 10;

    final layerScores = {
      for (final e in layerValues.entries) e.key: round1(avg(e.value)),
    };

    // Weighted total matching web SurveyResults.tsx scoring logic.
    final s = layerScores['STRUCTURE'] ?? 0.0;
    final c = layerScores['CULTURE'] ?? 0.0;
    final a = layerScores['ACTIVITY'] ?? 0.0;

    double total;
    if (s > 0 && c > 0 && a > 0) {
      total = round1(s * 0.5 + c * 0.3 + a * 0.2);
    } else {
      final active = layerScores.values.where((v) => v > 0).toList();
      total = active.isEmpty ? 0.0 : round1(avg(active));
    }

    return WorkshopSurveyResults(
      layerScores: layerScores,
      total: total,
      responseCount: responseRows.length,
    );
  }

  // ---------------------------------------------------------------------------
  // Cancel registration
  // ---------------------------------------------------------------------------

  @override
  Future<void> cancelRegistration(
      String registrationId, String workshopId) async {
    // Set status and payment_status to 'cancelled' — matching web MyWorkshops
    // cancelMutation (lines 224-229).
    await _client.from('cc_workshop_registrations').update({
      'status': 'cancelled',
      'payment_status': 'cancelled',
    }).eq('id', registrationId);

    // Decrement current_participants, matching web (lines 230-235).
    final workshopRows = await _client
        .from('cc_workshops')
        .select('current_participants')
        .eq('id', workshopId)
        .limit(1);
    if (workshopRows.isNotEmpty) {
      final current =
          (workshopRows.first['current_participants'] as int?) ?? 0;
      await _client.from('cc_workshops').update({
        'current_participants': current > 0 ? current - 1 : 0,
      }).eq('id', workshopId);
    }
  }
}
