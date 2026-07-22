// WorkReflection intelligence models — WR Two-Layer Architecture v1.2.
// Plain immutable classes + fromJson/toInsert, mirroring wr_content.dart style.
// No Flutter dependencies.

import 'package:workreflection_mobile/core/models/wr_content.dart';

// ---------------------------------------------------------------------------
// WrPlan enum
// ---------------------------------------------------------------------------

/// Subscription plan. dbValue matches wr_entitlements.plan check constraint.
enum WrPlan {
  free,
  premium;

  String get dbValue => switch (this) {
        WrPlan.free => 'free',
        WrPlan.premium => 'premium',
      };

  static WrPlan fromDb(String value) => switch (value) {
        'free' => WrPlan.free,
        'premium' => WrPlan.premium,
        _ => throw ArgumentError('Unknown WrPlan db value: $value'),
      };
}

// ---------------------------------------------------------------------------
// ReflectionStepType enum
// ---------------------------------------------------------------------------

/// 5 bước phản chiếu. dbValue matches wr_reflection_steps.step check constraint.
enum ReflectionStepType {
  notice,
  meaning,
  insight,
  choice,
  action;

  String get dbValue => switch (this) {
        ReflectionStepType.notice => 'notice',
        ReflectionStepType.meaning => 'meaning',
        ReflectionStepType.insight => 'insight',
        ReflectionStepType.choice => 'choice',
        ReflectionStepType.action => 'action',
      };

  static ReflectionStepType fromDb(String value) => switch (value) {
        'notice' => ReflectionStepType.notice,
        'meaning' => ReflectionStepType.meaning,
        'insight' => ReflectionStepType.insight,
        'choice' => ReflectionStepType.choice,
        'action' => ReflectionStepType.action,
        _ => throw ArgumentError('Unknown ReflectionStepType db value: $value'),
      };
}

// ---------------------------------------------------------------------------
// WrEntitlementRecord
// ---------------------------------------------------------------------------

/// Maps to public.wr_entitlements.
class WrEntitlementRecord {
  const WrEntitlementRecord({
    required this.userId,
    required this.plan,
    this.validUntil,
    this.source,
    this.updatedAt,
  });

  final String userId;
  final WrPlan plan;
  final DateTime? validUntil;
  final String? source;
  final DateTime? updatedAt;

  factory WrEntitlementRecord.fromJson(Map<String, dynamic> json) {
    return WrEntitlementRecord(
      userId: json['user_id'] as String,
      plan: WrPlan.fromDb(json['plan'] as String),
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String)
          : null,
      source: json['source'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  bool get isActivePremium =>
      plan == WrPlan.premium &&
      (validUntil == null || validUntil!.isAfter(DateTime.now()));
}

// ---------------------------------------------------------------------------
// HumanNeedSnapshot
// ---------------------------------------------------------------------------

/// Maps to public.wr_human_need_snapshots.
class HumanNeedSnapshot {
  const HumanNeedSnapshot({
    required this.id,
    required this.userId,
    required this.snapshotDate,
    required this.roRang,
    required this.ketNoi,
    required this.thichNghi,
    required this.phatTrien,
    this.createdAt,
  });

  final String id;
  final String userId;
  final DateTime snapshotDate;
  final int roRang;
  final int ketNoi;
  final int thichNghi;
  final int phatTrien;
  final DateTime? createdAt;

  factory HumanNeedSnapshot.fromJson(Map<String, dynamic> json) {
    return HumanNeedSnapshot(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      snapshotDate: DateTime.parse(json['snapshot_date'] as String),
      roRang: json['ro_rang'] as int,
      ketNoi: json['ket_noi'] as int,
      thichNghi: json['thich_nghi'] as int,
      phatTrien: json['phat_trien'] as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// ReflectionStep
// ---------------------------------------------------------------------------

/// Maps to public.wr_reflection_steps.
class ReflectionStep {
  const ReflectionStep({
    required this.userId,
    required this.step,
    this.id,
    this.memoryEventId,
    this.content,
    this.createdAt,
  });

  final String? id;
  final String userId;
  final String? memoryEventId;
  final ReflectionStepType step;
  final String? content;
  final DateTime? createdAt;

  factory ReflectionStep.fromJson(Map<String, dynamic> json) {
    return ReflectionStep(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      memoryEventId: json['memory_event_id'] as String?,
      step: ReflectionStepType.fromDb(json['step'] as String),
      content: json['content'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Returns a map suitable for INSERT into public.wr_reflection_steps.
  /// Excludes server-generated fields: id, created_at.
  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        if (memoryEventId != null) 'memory_event_id': memoryEventId,
        'step': step.dbValue,
        if (content != null) 'content': content,
      };
}

// ---------------------------------------------------------------------------
// WrInsight
// ---------------------------------------------------------------------------

/// Maps to public.wr_insights.
class WrInsight {
  const WrInsight({
    required this.userId,
    required this.content,
    this.id,
    this.source,
    this.scaDimension,
    this.humanNeed,
    this.createdAt,
  });

  final String? id;
  final String userId;
  final String? source;
  final ScaDimension? scaDimension;
  final HumanNeed? humanNeed;
  final String content;
  final DateTime? createdAt;

  factory WrInsight.fromJson(Map<String, dynamic> json) {
    final rawDim = json['sca_dimension'] as String?;
    final rawNeed = json['human_need'] as String?;
    return WrInsight(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      source: json['source'] as String?,
      scaDimension: rawDim != null ? ScaDimension.fromDb(rawDim) : null,
      humanNeed: rawNeed != null ? HumanNeed.fromDb(rawNeed) : null,
      content: json['content'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Returns a map suitable for INSERT into public.wr_insights.
  /// Excludes server-generated fields: id, created_at.
  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        if (source != null) 'source': source,
        if (scaDimension != null) 'sca_dimension': scaDimension!.dbValue,
        if (humanNeed != null) 'human_need': humanNeed!.dbValue,
        'content': content,
      };
}

// ---------------------------------------------------------------------------
// PatternCount
// ---------------------------------------------------------------------------

/// Maps to public.wr_pattern_counts.
class PatternCount {
  const PatternCount({
    required this.userId,
    required this.occurrenceCount,
    required this.lastSeenAt,
    this.id,
    this.situationCode,
    this.scaDimension,
  });

  final String? id;
  final String userId;
  final String? situationCode;
  final ScaDimension? scaDimension;
  final int occurrenceCount;
  final DateTime lastSeenAt;

  factory PatternCount.fromJson(Map<String, dynamic> json) {
    final rawDim = json['sca_dimension'] as String?;
    return PatternCount(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      situationCode: json['situation_code'] as String?,
      scaDimension: rawDim != null ? ScaDimension.fromDb(rawDim) : null,
      occurrenceCount: json['occurrence_count'] as int,
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// PatternNarrative
// ---------------------------------------------------------------------------

/// Maps to public.wr_pattern_narratives.
class PatternNarrative {
  const PatternNarrative({
    required this.userId,
    required this.narrative,
    this.id,
    this.periodStart,
    this.periodEnd,
    this.createdAt,
  });

  final String? id;
  final String userId;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String narrative;
  final DateTime? createdAt;

  factory PatternNarrative.fromJson(Map<String, dynamic> json) {
    return PatternNarrative(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      periodStart: json['period_start'] != null
          ? DateTime.parse(json['period_start'] as String)
          : null,
      periodEnd: json['period_end'] != null
          ? DateTime.parse(json['period_end'] as String)
          : null,
      narrative: json['narrative'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// GrowthJourneySnapshot
// ---------------------------------------------------------------------------

/// Maps to public.wr_growth_journey_snapshots.
class GrowthJourneySnapshot {
  const GrowthJourneySnapshot({
    required this.userId,
    required this.progress,
    this.id,
    this.periodLabel,
    this.direction,
    this.createdAt,
  });

  final String? id;
  final String userId;
  final String? periodLabel;
  final Map<String, dynamic> progress;
  final String? direction;
  final DateTime? createdAt;

  factory GrowthJourneySnapshot.fromJson(Map<String, dynamic> json) {
    return GrowthJourneySnapshot(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      periodLabel: json['period_label'] as String?,
      progress: json['progress'] as Map<String, dynamic>? ?? {},
      direction: json['direction'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// ScaSelfCheckResponse
// ---------------------------------------------------------------------------

/// Maps to public.wr_sca_self_check_responses.
class ScaSelfCheckResponse {
  const ScaSelfCheckResponse({
    required this.userId,
    required this.answers,
    required this.takenAt,
    this.id,
    this.structureScore,
    this.cultureScore,
    this.activityScore,
  });

  final String? id;
  final String userId;
  final Map<String, dynamic> answers;
  final double? structureScore;
  final double? cultureScore;
  final double? activityScore;
  final DateTime takenAt;

  factory ScaSelfCheckResponse.fromJson(Map<String, dynamic> json) {
    return ScaSelfCheckResponse(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      answers: json['answers'] as Map<String, dynamic>,
      structureScore: (json['structure_score'] as num?)?.toDouble(),
      cultureScore: (json['culture_score'] as num?)?.toDouble(),
      activityScore: (json['activity_score'] as num?)?.toDouble(),
      takenAt: DateTime.parse(json['taken_at'] as String),
    );
  }

  /// Returns a map suitable for INSERT into public.wr_sca_self_check_responses.
  /// Excludes server-generated fields: id, taken_at.
  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'answers': answers,
        if (structureScore != null) 'structure_score': structureScore,
        if (cultureScore != null) 'culture_score': cultureScore,
        if (activityScore != null) 'activity_score': activityScore,
      };
}

// ---------------------------------------------------------------------------
// PracticeTheme
// ---------------------------------------------------------------------------

/// Maps to public.wr_practice_themes.
class PracticeTheme {
  const PracticeTheme({
    required this.themeId,
    required this.title,
    this.scaDimension,
    this.description,
    this.createdAt,
  });

  final String themeId;
  final String title;
  final ScaDimension? scaDimension;
  final String? description;
  final DateTime? createdAt;

  factory PracticeTheme.fromJson(Map<String, dynamic> json) {
    final rawDim = json['sca_dimension'] as String?;
    return PracticeTheme(
      themeId: json['theme_id'] as String,
      title: json['title'] as String,
      scaDimension: rawDim != null ? ScaDimension.fromDb(rawDim) : null,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// PracticeStep
// ---------------------------------------------------------------------------

/// Maps to public.wr_practice_steps.
class PracticeStep {
  const PracticeStep({
    required this.stepId,
    required this.themeId,
    required this.stepOrder,
    required this.title,
    required this.isPremium,
    this.content,
    this.createdAt,
  });

  final String stepId;
  final String themeId;
  final int stepOrder;
  final String title;
  final String? content;
  final bool isPremium;
  final DateTime? createdAt;

  factory PracticeStep.fromJson(Map<String, dynamic> json) {
    return PracticeStep(
      stepId: json['step_id'] as String,
      themeId: json['theme_id'] as String,
      stepOrder: json['step_order'] as int,
      title: json['title'] as String,
      content: json['content'] as String?,
      isPremium: json['is_premium'] as bool,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// PracticeEnrollment
// ---------------------------------------------------------------------------

/// Maps to public.wr_practice_enrollments.
class PracticeEnrollment {
  const PracticeEnrollment({
    required this.userId,
    required this.themeId,
    this.id,
    this.startedAt,
    this.completedAt,
    this.completedSteps = const [],
  });

  final String? id;
  final String userId;
  final String themeId;
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// IDs of practice steps the user has marked done (e.g. ['pt-voice-1']).
  /// Maps to completed_steps text[] column added by migration 20260722000002.
  final List<String> completedSteps;

  factory PracticeEnrollment.fromJson(Map<String, dynamic> json) {
    final raw = json['completed_steps'];
    final steps = raw is List ? raw.cast<String>() : <String>[];
    return PracticeEnrollment(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      themeId: json['theme_id'] as String,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      completedSteps: steps,
    );
  }

  /// Returns a map suitable for INSERT into public.wr_practice_enrollments.
  /// Excludes server-generated fields: id, started_at (server default), completed_at.
  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'theme_id': themeId,
      };

  PracticeEnrollment copyWith({List<String>? completedSteps}) {
    return PracticeEnrollment(
      id: id,
      userId: userId,
      themeId: themeId,
      startedAt: startedAt,
      completedAt: completedAt,
      completedSteps: completedSteps ?? this.completedSteps,
    );
  }
}

// ---------------------------------------------------------------------------
// WrContextDocument
// ---------------------------------------------------------------------------

/// Maps to public.wr_context_documents.
class WrContextDocument {
  const WrContextDocument({
    required this.userId,
    required this.filePath,
    this.id,
    this.docType,
    this.uploadedAt,
  });

  final String? id;
  final String userId;
  final String? docType;
  final String filePath;
  final DateTime? uploadedAt;

  factory WrContextDocument.fromJson(Map<String, dynamic> json) {
    return WrContextDocument(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      docType: json['doc_type'] as String?,
      filePath: json['file_path'] as String,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'] as String)
          : null,
    );
  }

  /// Returns a map suitable for INSERT into public.wr_context_documents.
  /// Excludes server-generated fields: id, uploaded_at.
  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'file_path': filePath,
        if (docType != null) 'doc_type': docType,
      };
}
