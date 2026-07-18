// Roadmap tracker repository — Phase 5 Task 5.
//
// Mirrors web's useRoadmapTracker.ts (src/hooks/useRoadmapTracker.ts).
// Tables used:
//   cc_reports            — SELECT to find premium reports
//   cc_surveys            — JOIN to filter survey_type = 'PREMIUM'
//   cc_report_nicknames   — nickname upsert (user_id,report_id)
//   cc_roadmap_actions    — SELECT template rows (is_active=true)
//   cc_roadmap_progress   — upsert (user_id,report_id,action_ref_id)
//   cc_custom_roadmap_tasks — full CRUD (user_id,report_id keyed)
//   cc_roadmap_coach_access — upsert invite (user_id,coach_id)
//   cc_coaches            — list active coaches

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class PremiumReport {
  const PremiumReport({
    required this.id,
    required this.surveyId,
    required this.createdAt,
    required this.scoreTotal,
    required this.scoreStructure,
    required this.scoreCulture,
    required this.scoreActivity,
    this.bottleneckLayer,
    this.subScores,
    this.nickname,
  });

  final String id;
  final String surveyId;
  final DateTime createdAt;
  final double scoreTotal;
  final double scoreStructure;
  final double scoreCulture;
  final double scoreActivity;
  final String? bottleneckLayer;
  final Map<String, dynamic>? subScores;
  final String? nickname;

  factory PremiumReport.fromJson(Map<String, dynamic> json,
      {String? nickname}) {
    final ss = json['sub_scores'];
    return PremiumReport(
      id: json['id'] as String,
      surveyId: json['survey_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      scoreTotal: (json['score_total'] as num).toDouble(),
      scoreStructure: (json['score_structure'] as num).toDouble(),
      scoreCulture: (json['score_culture'] as num).toDouble(),
      scoreActivity: (json['score_activity'] as num).toDouble(),
      bottleneckLayer: json['bottleneck_layer'] as String?,
      subScores: ss != null ? Map<String, dynamic>.from(ss as Map) : null,
      nickname: nickname,
    );
  }
}

class RoadmapAction {
  const RoadmapAction({
    required this.id,
    required this.layer,
    required this.subComponent,
    required this.day,
    required this.titleVi,
    required this.descriptionVi,
    this.titleEn,
    this.descriptionEn,
  });

  final String id;
  final String layer;
  final String subComponent;
  final int day;
  final String titleVi;
  final String descriptionVi;
  final String? titleEn;
  final String? descriptionEn;

  factory RoadmapAction.fromJson(Map<String, dynamic> json) {
    return RoadmapAction(
      id: json['id'] as String,
      layer: json['layer'] as String,
      subComponent: json['sub_component'] as String,
      day: json['day'] as int,
      titleVi: json['title_vi'] as String? ?? '',
      descriptionVi: json['description_vi'] as String? ?? '',
      titleEn: json['title_en'] as String?,
      descriptionEn: json['description_en'] as String?,
    );
  }
}

class CustomTask {
  const CustomTask({
    required this.id,
    required this.reportId,
    required this.title,
    this.description,
    required this.layer,
    required this.day,
    required this.isCompleted,
    this.completedAt,
    required this.createdBy,
    required this.displayOrder,
    this.dueDate,
  });

  final String id;
  final String reportId;
  final String title;
  final String? description;
  final String layer;
  final int day;
  final bool isCompleted;
  final String? completedAt;
  final String createdBy;
  final int displayOrder;
  final String? dueDate;

  factory CustomTask.fromJson(Map<String, dynamic> json) {
    return CustomTask(
      id: json['id'] as String,
      reportId: json['report_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      layer: json['layer'] as String,
      day: json['day'] as int,
      isCompleted: json['is_completed'] as bool,
      completedAt: json['completed_at'] as String?,
      createdBy: json['created_by'] as String,
      displayOrder: json['display_order'] as int? ?? 0,
      dueDate: json['due_date'] as String?,
    );
  }

  CustomTask copyWith({bool? isCompleted, String? completedAt}) {
    return CustomTask(
      id: id,
      reportId: reportId,
      title: title,
      description: description,
      layer: layer,
      day: day,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdBy: createdBy,
      displayOrder: displayOrder,
      dueDate: dueDate,
    );
  }
}

class RoadmapProgressData {
  const RoadmapProgressData({
    required this.completedActionIds,
    required this.completedActionDates,
    required this.customTasks,
  });

  final Set<String> completedActionIds;
  final Map<String, String> completedActionDates; // action_ref_id → completed_at
  final List<CustomTask> customTasks;
}

class CoachAccessEntry {
  const CoachAccessEntry({
    required this.id,
    required this.userId,
    required this.coachId,
    required this.status,
    required this.invitedAt,
    this.acceptedAt,
    this.coachName,
    this.coachAvatarUrl,
    this.coachTitle,
  });

  final String id;
  final String userId;
  final String coachId;
  final String status; // 'pending' | 'accepted' | 'revoked'
  final String invitedAt;
  final String? acceptedAt;
  final String? coachName;
  final String? coachAvatarUrl;
  final String? coachTitle;

  factory CoachAccessEntry.fromJson(Map<String, dynamic> json) {
    final coach = json['coach'] as Map<String, dynamic>?;
    return CoachAccessEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      coachId: json['coach_id'] as String,
      status: json['status'] as String,
      invitedAt: json['invited_at'] as String,
      acceptedAt: json['accepted_at'] as String?,
      coachName: coach?['full_name'] as String?,
      coachAvatarUrl: coach?['avatar_url'] as String?,
      coachTitle: coach?['title'] as String?,
    );
  }
}

class AvailableCoach {
  const AvailableCoach({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.title,
  });

  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? title;

  factory AvailableCoach.fromJson(Map<String, dynamic> json) {
    return AvailableCoach(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      title: json['title'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Abstract repository
// ---------------------------------------------------------------------------

abstract class RoadmapRepository {
  /// Fetch all PREMIUM reports for the current user (with nicknames).
  Future<List<PremiumReport>> getPremiumReports();

  /// Fetch progress + custom tasks for one report.
  Future<RoadmapProgressData> getProgressForReport(String reportId);

  /// Fetch all active roadmap action templates.
  Future<List<RoadmapAction>> getRoadmapActions();

  /// Toggle a template action's completion (upsert cc_roadmap_progress).
  Future<void> toggleRoadmapAction({
    required String reportId,
    required String actionRefId,
    required bool isCompleted,
  });

  /// Toggle a custom task's completion.
  Future<void> toggleCustomTask({
    required String taskId,
    required bool isCompleted,
  });

  /// Add a new custom task.
  Future<CustomTask> addCustomTask({
    required String reportId,
    required String title,
    String? description,
    required String layer,
    required int day,
    String? dueDate,
  });

  /// Update an existing custom task.
  Future<void> updateCustomTask({
    required String taskId,
    required String title,
    String? description,
    String? dueDate,
  });

  /// Delete a custom task.
  Future<void> deleteCustomTask(String taskId);

  /// Upsert a nickname for a report.
  Future<void> updateReportNickname({
    required String reportId,
    required String nickname,
  });

  /// Fetch coach access entries for current user (with coach info).
  Future<List<CoachAccessEntry>> getCoachAccess();

  /// Invite a coach (upsert cc_roadmap_coach_access with 'pending').
  Future<void> inviteCoach(String coachId);

  /// Fetch all active coaches for the invite dialog.
  Future<List<AvailableCoach>> getAvailableCoaches();
}

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseRoadmapRepository implements RoadmapRepository {
  const SupabaseRoadmapRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  @override
  Future<List<PremiumReport>> getPremiumReports() async {
    final uid = _uid;

    // 1. Fetch all reports for this user
    final reports = await _client
        .from('cc_reports')
        .select(
            'id, created_at, score_total, score_structure, score_culture, score_activity, bottleneck_layer, sub_scores, survey_id')
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    if (reports.isEmpty) return [];

    // 2. Filter to PREMIUM surveys only
    final surveyIds =
        (reports as List).map((r) => r['survey_id'] as String).toSet().toList();
    final surveys = await _client
        .from('cc_surveys')
        .select('id, survey_type')
        .inFilter('id', surveyIds);

    final premiumSurveyIds = (surveys as List)
        .where((s) => s['survey_type'] == 'PREMIUM')
        .map((s) => s['id'] as String)
        .toSet();

    final premiumReports = (reports as List)
        .where((r) => premiumSurveyIds.contains(r['survey_id']))
        .toList();

    if (premiumReports.isEmpty) return [];

    // 3. Fetch nicknames
    final reportIds = premiumReports.map((r) => r['id'] as String).toList();
    final nicknames = await _client
        .from('cc_report_nicknames')
        .select('report_id, nickname')
        .eq('user_id', uid)
        .inFilter('report_id', reportIds);

    final nicknameMap = <String, String>{
      for (final n in (nicknames as List))
        (n['report_id'] as String): (n['nickname'] as String)
    };

    return premiumReports
        .map((r) => PremiumReport.fromJson(
              Map<String, dynamic>.from(r as Map),
              nickname: nicknameMap[r['id'] as String],
            ))
        .toList();
  }

  @override
  Future<RoadmapProgressData> getProgressForReport(String reportId) async {
    final uid = _uid;

    final results = await Future.wait([
      _client
          .from('cc_roadmap_progress')
          .select('action_ref_id, is_completed, completed_at')
          .eq('user_id', uid)
          .eq('report_id', reportId),
      _client
          .from('cc_custom_roadmap_tasks')
          .select(
              'id, report_id, title, description, layer, day, is_completed, completed_at, created_by, display_order, due_date')
          .eq('user_id', uid)
          .eq('report_id', reportId)
          .order('display_order'),
    ]);

    final progressRows = results[0] as List;
    final customTaskRows = results[1] as List;

    final completedRows =
        progressRows.where((p) => p['is_completed'] == true).toList();
    final completedActionIds =
        completedRows.map((p) => p['action_ref_id'] as String).toSet();
    final completedActionDates = <String, String>{
      for (final p in completedRows
          .where((p) => p['completed_at'] != null))
        (p['action_ref_id'] as String): (p['completed_at'] as String)
    };

    final customTasks = customTaskRows
        .map((t) => CustomTask.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();

    return RoadmapProgressData(
      completedActionIds: completedActionIds,
      completedActionDates: completedActionDates,
      customTasks: customTasks,
    );
  }

  @override
  Future<List<RoadmapAction>> getRoadmapActions() async {
    final rows = await _client
        .from('cc_roadmap_actions')
        .select(
            'id, layer, sub_component, day, title_vi, description_vi, title_en, description_en')
        .eq('is_active', true);

    return (rows as List)
        .map((r) => RoadmapAction.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<void> toggleRoadmapAction({
    required String reportId,
    required String actionRefId,
    required bool isCompleted,
  }) async {
    final uid = _uid;
    await _client.from('cc_roadmap_progress').upsert(
      {
        'user_id': uid,
        'report_id': reportId,
        'action_ref_id': actionRefId,
        'is_completed': isCompleted,
        'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
      },
      onConflict: 'user_id,report_id,action_ref_id',
    );
  }

  @override
  Future<void> toggleCustomTask({
    required String taskId,
    required bool isCompleted,
  }) async {
    await _client.from('cc_custom_roadmap_tasks').update({
      'is_completed': isCompleted,
      'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
    }).eq('id', taskId);
  }

  @override
  Future<CustomTask> addCustomTask({
    required String reportId,
    required String title,
    String? description,
    required String layer,
    required int day,
    String? dueDate,
  }) async {
    final uid = _uid;
    final row = await _client
        .from('cc_custom_roadmap_tasks')
        .insert({
          'user_id': uid,
          'report_id': reportId,
          'title': title,
          'description': description,
          'layer': layer,
          'day': day,
          'is_completed': false,
          'created_by': uid,
          'display_order': 0,
          'due_date': dueDate,
        })
        .select()
        .single();

    return CustomTask.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> updateCustomTask({
    required String taskId,
    required String title,
    String? description,
    String? dueDate,
  }) async {
    await _client.from('cc_custom_roadmap_tasks').update({
      'title': title,
      'description': description,
      'due_date': dueDate,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
  }

  @override
  Future<void> deleteCustomTask(String taskId) async {
    await _client.from('cc_custom_roadmap_tasks').delete().eq('id', taskId);
  }

  @override
  Future<void> updateReportNickname({
    required String reportId,
    required String nickname,
  }) async {
    final uid = _uid;
    await _client.from('cc_report_nicknames').upsert(
      {
        'user_id': uid,
        'report_id': reportId,
        'nickname': nickname,
      },
      onConflict: 'user_id,report_id',
    );
  }

  @override
  Future<List<CoachAccessEntry>> getCoachAccess() async {
    final uid = _uid;
    final rows = await _client
        .from('cc_roadmap_coach_access')
        .select(
            'id, user_id, coach_id, status, invited_at, accepted_at, coach:cc_coaches(id, full_name, avatar_url, title)')
        .eq('user_id', uid);

    return (rows as List)
        .map((r) =>
            CoachAccessEntry.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<void> inviteCoach(String coachId) async {
    final uid = _uid;
    await _client.from('cc_roadmap_coach_access').upsert(
      {
        'user_id': uid,
        'coach_id': coachId,
        'status': 'pending',
        'invited_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,coach_id',
    );
  }

  @override
  Future<List<AvailableCoach>> getAvailableCoaches() async {
    final rows = await _client
        .from('cc_coaches')
        .select('id, full_name, avatar_url, title, is_active')
        .eq('is_active', true)
        .order('full_name');

    return (rows as List)
        .map((r) =>
            AvailableCoach.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final roadmapRepositoryProvider = Provider<RoadmapRepository>((ref) {
  return SupabaseRoadmapRepository(Supabase.instance.client);
});
