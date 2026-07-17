// Survey repository — Phase 2.
// Abstract interface + SupabaseSurveyRepository + provider.
// Supabase queries live ONLY here. Screens consume via surveyRepositoryProvider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/survey_scoring.dart';
import '../models/survey_models.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class SurveyRepository {
  /// Returns the user's role string from user_roles first, fallback cc_profiles.role.
  Future<String> getUserRole();

  /// Maps a role string to SurveyType.
  SurveyType surveyTypeForRole(String role);

  /// Fetches questions for the given survey type.
  /// Priority: active cc_question_set_config with question_ids,
  /// else cc_questions filtered + deduped per research §1.
  Future<List<CcQuestion>> getQuestions(SurveyType type);

  /// All cc_likert_options grouped by scaleType.
  Future<Map<ScaleType, List<CcLikertOption>>> getLikertOptions();

  /// Submits a completed survey:
  /// 1. Insert cc_surveys
  /// 2. Bulk insert cc_responses
  /// 3. Compute scores client-side
  /// 4. Insert cc_reports
  /// 5. Best-effort send-email (fire-and-forget)
  /// Returns the full CcReportFull.
  Future<CcReportFull> submitSurvey({
    required SurveyType type,
    required Map<String, int> answers,
    required List<CcQuestion> questions,
    String? userPosition,
    String? userWorkExperience,
    String? userCompanyTenure,
    String? userCompanySize,
    String? userDepartment,
  });

  /// Fetch a specific report by id.
  Future<CcReportFull?> getReport(String reportId);

  /// Fetch the latest report for the current user.
  Future<CcReportFull?> getLatestReportFull();

  /// Fetch narratives (scope=personal, is_active=true).
  Future<List<CcNarrative>> getNarratives();

  /// Fetch action plan phases + tasks for the given survey type.
  Future<List<ActionPlanPhase>> getActionPlan(SurveyType type);

  /// Fetch task progress for a report (map taskId → completed).
  Future<Map<String, bool>> getActionProgress(String reportId);

  /// Toggle a task completion via upsert on cc_user_action_progress.
  Future<void> toggleTask(String taskId, String reportId, bool completed);

  /// Invoke tts-proxy edge function and return TtsResult.
  Future<TtsResult> tts(String text, String language);
}

// ---------------------------------------------------------------------------
// Riverpod provider (overridable in tests)
// ---------------------------------------------------------------------------

final surveyRepositoryProvider = Provider<SurveyRepository>((ref) {
  return SupabaseSurveyRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Live Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseSurveyRepository implements SurveyRepository {
  const SupabaseSurveyRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  String get _userEmail =>
      _client.auth.currentUser?.email ?? '';

  String get _userFullName =>
      (_client.auth.currentUser?.userMetadata?['display_name'] as String?) ??
      _userEmail;

  // ---------------------------------------------------------------------------
  // Role / type
  // ---------------------------------------------------------------------------

  @override
  Future<String> getUserRole() async {
    // Try user_roles first
    final roleRows = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', _uid)
        .limit(1);
    if (roleRows.isNotEmpty) {
      return roleRows.first['role'] as String;
    }
    // Fallback: cc_profiles.role
    final profileRows = await _client
        .from('cc_profiles')
        .select('role')
        .eq('id', _uid)
        .limit(1);
    if (profileRows.isNotEmpty) {
      return profileRows.first['role'] as String? ?? 'user';
    }
    return 'user';
  }

  @override
  SurveyType surveyTypeForRole(String role) {
    return (role == 'premium' || role == 'admin')
        ? SurveyType.premium
        : SurveyType.free;
  }

  // ---------------------------------------------------------------------------
  // Questions
  // ---------------------------------------------------------------------------

  @override
  Future<List<CcQuestion>> getQuestions(SurveyType type) async {
    // 1. Check for active question_set_config with question_ids array.
    final configRows = await _client
        .from('cc_question_set_config')
        .select('question_ids')
        .eq('is_active', true)
        .limit(1);

    if (configRows.isNotEmpty) {
      final ids = configRows.first['question_ids'] as List<dynamic>;
      if (ids.isNotEmpty) {
        final rows = await _client
            .from('cc_questions')
            .select()
            .inFilter('id', ids.cast<String>())
            .order('question_order');
        return rows.map(CcQuestion.fromJson).toList();
      }
    }

    // 2. Fallback: filter by survey type + is_active, dedup by question_order.
    final List<String> scaleTypes;
    if (type == SurveyType.premium) {
      scaleTypes = ['LIKERT_5', 'ESI_5', 'ENPS_10'];
    } else {
      scaleTypes = ['LIKERT_5'];
    }

    final rows = await _client
        .from('cc_questions')
        .select()
        .eq('is_active', true)
        .inFilter('survey_type', [type.toJson(), 'BOTH'])
        .inFilter('scale_type', scaleTypes)
        .order('question_order');

    // Dedup by question_order (keep first occurrence per order).
    final seen = <int>{};
    final deduped = <CcQuestion>[];
    for (final row in rows) {
      final q = CcQuestion.fromJson(row);
      if (seen.add(q.questionOrder)) {
        deduped.add(q);
      }
    }
    return deduped;
  }

  // ---------------------------------------------------------------------------
  // Likert options
  // ---------------------------------------------------------------------------

  @override
  Future<Map<ScaleType, List<CcLikertOption>>> getLikertOptions() async {
    final rows = await _client
        .from('cc_likert_options')
        .select()
        .order('display_order');
    final result = <ScaleType, List<CcLikertOption>>{};
    for (final row in rows) {
      final opt = CcLikertOption.fromJson(row);
      result.putIfAbsent(opt.scaleType, () => []).add(opt);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Submit survey
  // ---------------------------------------------------------------------------

  @override
  Future<CcReportFull> submitSurvey({
    required SurveyType type,
    required Map<String, int> answers,
    required List<CcQuestion> questions,
    String? userPosition,
    String? userWorkExperience,
    String? userCompanyTenure,
    String? userCompanySize,
    String? userDepartment,
  }) async {
    final now = DateTime.now().toIso8601String();

    // 1. Insert cc_surveys
    final surveyRows = await _client.from('cc_surveys').insert({
      'user_id': _uid,
      'survey_type': type.toJson(),
      'status': 'COMPLETED',
      'user_email': _userEmail,
      'user_full_name': _userFullName,
      if (userPosition != null) 'user_position': userPosition,
      if (userWorkExperience != null) 'user_work_experience': userWorkExperience,
      if (userCompanyTenure != null) 'user_company_tenure': userCompanyTenure,
      if (userCompanySize != null) 'user_company_size': userCompanySize,
      if (userDepartment != null) 'user_department': userDepartment,
      'started_at': now,
      'completed_at': now,
      'campaign_id': null,
    }).select('id').single();

    final surveyId = surveyRows['id'] as String;

    // 2. Bulk insert cc_responses
    final responses = answers.entries.map((e) => {
          'survey_id': surveyId,
          'question_id': e.key,
          'answer_value': e.value,
        }).toList();
    await _client.from('cc_responses').insert(responses);

    // 3. Compute scores client-side
    final scores = computeSurveyScores(answers: answers, questions: questions);

    // 4. Insert cc_reports
    final reportRows = await _client.from('cc_reports').insert({
      'survey_id': surveyId,
      'user_id': _uid,
      'score_total': scores.scoreTotal,
      'score_structure': scores.scoreStructure,
      'score_culture': scores.scoreCulture,
      'score_activity': scores.scoreActivity,
      'score_esi': scores.scoreEsi,
      'score_enps': scores.scoreEnps,
      'bottleneck_layer': scores.bottleneckLayer.toJson(),
      'score_level': scores.scoreLevel.toJson(),
      'sub_scores': null,
      'selected_narrative_variants': null,
    }).select().single();

    // 5. Best-effort send-email (fire-and-forget)
    _client.functions.invoke('send-email', body: {
      'template': 'survey-completed',
      'userId': _uid,
      'surveyId': surveyId,
    }).ignore();

    return CcReportFull.fromJson(reportRows);
  }

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------

  @override
  Future<CcReportFull?> getReport(String reportId) async {
    final rows = await _client
        .from('cc_reports')
        .select()
        .eq('id', reportId)
        .eq('user_id', _uid)
        .limit(1);
    if (rows.isEmpty) return null;
    return CcReportFull.fromJson(rows.first);
  }

  @override
  Future<CcReportFull?> getLatestReportFull() async {
    final rows = await _client
        .from('cc_reports')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return CcReportFull.fromJson(rows.first);
  }

  // ---------------------------------------------------------------------------
  // Narratives
  // ---------------------------------------------------------------------------

  @override
  Future<List<CcNarrative>> getNarratives() async {
    final rows = await _client
        .from('cc_narratives')
        .select()
        .eq('scope', 'personal')
        .eq('is_active', true);
    return rows.map(CcNarrative.fromJson).toList();
  }

  // ---------------------------------------------------------------------------
  // Action plan
  // ---------------------------------------------------------------------------

  @override
  Future<List<ActionPlanPhase>> getActionPlan(SurveyType type) async {
    final phaseRows = await _client
        .from('cc_action_plan_phases')
        .select()
        .eq('survey_type', type.toJson())
        .order('display_order');

    final taskRows = await _client
        .from('cc_action_plan_tasks')
        .select()
        .order('display_order');

    // Group tasks by phase_id
    final Map<String, List<ActionPlanTask>> tasksByPhase = {};
    for (final row in taskRows) {
      final task = ActionPlanTask.fromJson(row);
      tasksByPhase.putIfAbsent(task.phaseId, () => []).add(task);
    }

    return phaseRows.map((row) {
      final phase = ActionPlanPhase.fromJson(row);
      final tasks = tasksByPhase[phase.id] ?? [];
      return ActionPlanPhase(
        id: phase.id,
        day: phase.day,
        titleVi: phase.titleVi,
        titleEn: phase.titleEn,
        description: phase.description,
        reflectionQuestion: phase.reflectionQuestion,
        surveyType: phase.surveyType,
        displayOrder: phase.displayOrder,
        tasks: tasks,
      );
    }).toList();
  }

  @override
  Future<Map<String, bool>> getActionProgress(String reportId) async {
    final rows = await _client
        .from('cc_user_action_progress')
        .select('task_id, completed')
        .eq('user_id', _uid)
        .eq('report_id', reportId);
    return {
      for (final row in rows as List)
        row['task_id'] as String: row['completed'] as bool? ?? false,
    };
  }

  @override
  Future<void> toggleTask(String taskId, String reportId, bool completed) async {
    await _client.from('cc_user_action_progress').upsert({
      'user_id': _uid,
      'task_id': taskId,
      'report_id': reportId,
      'completed': completed,
      'completed_at': completed ? DateTime.now().toIso8601String() : null,
    }, onConflict: 'user_id,task_id,report_id');
  }

  // ---------------------------------------------------------------------------
  // TTS
  // ---------------------------------------------------------------------------

  @override
  Future<TtsResult> tts(String text, String language) async {
    final response = await _client.functions.invoke(
      'tts-proxy',
      body: {
        'action': 'generate_and_wait',
        'text': text,
        'language': language,
      },
    );
    return TtsResult.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }
}
