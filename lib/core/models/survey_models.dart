// Survey-phase models — Phase 2.
// All classes are immutable. No Flutter dependencies.

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum SurveyType {
  free,
  premium;

  static SurveyType fromJson(String v) => switch (v) {
        'FREE' => free,
        'PREMIUM' => premium,
        _ => throw ArgumentError('Unknown SurveyType: $v'),
      };

  String toJson() => switch (this) {
        free => 'FREE',
        premium => 'PREMIUM',
      };
}

enum ScaleType {
  likert5,
  esi5,
  enps10;

  static ScaleType fromJson(String v) => switch (v) {
        'LIKERT_5' => likert5,
        'ESI_5' => esi5,
        'ENPS_10' => enps10,
        _ => throw ArgumentError('Unknown ScaleType: $v'),
      };

  String toJson() => switch (this) {
        likert5 => 'LIKERT_5',
        esi5 => 'ESI_5',
        enps10 => 'ENPS_10',
      };
}

enum SurveyLayer {
  structure,
  culture,
  activity,
  esi,
  enps;

  static SurveyLayer fromJson(String v) => switch (v) {
        'STRUCTURE' => structure,
        'CULTURE' => culture,
        'ACTIVITY' => activity,
        'ESI' => esi,
        'ENPS' => enps,
        _ => throw ArgumentError('Unknown SurveyLayer: $v'),
      };

  String toJson() => switch (this) {
        structure => 'STRUCTURE',
        culture => 'CULTURE',
        activity => 'ACTIVITY',
        esi => 'ESI',
        enps => 'ENPS',
      };
}

enum ScoreLevel {
  high,
  good,
  warning,
  critical;

  static ScoreLevel fromJson(String v) => switch (v) {
        'HIGH' => high,
        'GOOD' => good,
        'WARNING' => warning,
        'CRITICAL' => critical,
        _ => throw ArgumentError('Unknown ScoreLevel: $v'),
      };

  String toJson() => switch (this) {
        high => 'HIGH',
        good => 'GOOD',
        warning => 'WARNING',
        critical => 'CRITICAL',
      };
}

// ---------------------------------------------------------------------------
// CcQuestion
// ---------------------------------------------------------------------------

class CcQuestion {
  const CcQuestion({
    required this.id,
    required this.layer,
    this.subComponent,
    required this.scaleType,
    required this.questionText,
    this.questionTextEn,
    required this.questionOrder,
    required this.isActive,
  });

  final String id;
  final SurveyLayer layer;
  final String? subComponent;
  final ScaleType scaleType;
  final String questionText;
  final String? questionTextEn;
  final int questionOrder;
  final bool isActive;

  factory CcQuestion.fromJson(Map<String, dynamic> json) {
    return CcQuestion(
      id: json['id'] as String,
      layer: SurveyLayer.fromJson(json['layer'] as String),
      subComponent: json['sub_component'] as String?,
      scaleType: ScaleType.fromJson(json['scale_type'] as String),
      questionText: json['question_text'] as String,
      questionTextEn: json['question_text_en'] as String?,
      questionOrder: json['question_order'] as int,
      isActive: json['is_active'] as bool,
    );
  }
}

// ---------------------------------------------------------------------------
// CcLikertOption
// ---------------------------------------------------------------------------

class CcLikertOption {
  const CcLikertOption({
    required this.scaleType,
    required this.value,
    required this.label,
    this.labelEn,
    required this.displayOrder,
  });

  final ScaleType scaleType;
  final int value;
  final String label;
  final String? labelEn;
  final int displayOrder;

  factory CcLikertOption.fromJson(Map<String, dynamic> json) {
    return CcLikertOption(
      scaleType: ScaleType.fromJson(json['scale_type'] as String),
      value: json['value'] as int,
      label: json['label'] as String,
      labelEn: json['label_en'] as String?,
      displayOrder: json['display_order'] as int,
    );
  }
}

// ---------------------------------------------------------------------------
// CcNarrative
// ---------------------------------------------------------------------------

class CcNarrative {
  const CcNarrative({
    required this.id,
    required this.type,
    this.layer,
    required this.scope,
    required this.scoreMin,
    required this.scoreMax,
    required this.narrativeText,
    this.narrativeTextEn,
    required this.narrativeVariants,
    required this.isActive,
  });

  final String id;
  final String type; // 'TOTAL', 'LAYER', 'BOTTLENECK', etc.
  final String? layer; // null for TOTAL
  final String scope;
  final double scoreMin;
  final double scoreMax;
  final String narrativeText;
  final String? narrativeTextEn;
  final List<String> narrativeVariants;
  final bool isActive;

  factory CcNarrative.fromJson(Map<String, dynamic> json) {
    final variants = json['narrative_variants'];
    final List<String> parsedVariants;
    if (variants == null) {
      parsedVariants = const [];
    } else {
      parsedVariants = (variants as List).cast<String>();
    }
    return CcNarrative(
      id: json['id'] as String,
      type: json['type'] as String,
      layer: json['layer'] as String?,
      scope: json['scope'] as String,
      scoreMin: (json['score_min'] as num).toDouble(),
      scoreMax: (json['score_max'] as num).toDouble(),
      narrativeText: json['narrative_text'] as String,
      narrativeTextEn: json['narrative_text_en'] as String?,
      narrativeVariants: parsedVariants,
      isActive: json['is_active'] as bool,
    );
  }
}

// ---------------------------------------------------------------------------
// CcReportFull
// ---------------------------------------------------------------------------

class CcReportFull {
  const CcReportFull({
    required this.id,
    required this.surveyId,
    required this.userId,
    required this.scoreTotal,
    required this.scoreStructure,
    required this.scoreCulture,
    required this.scoreActivity,
    this.scoreEsi,
    this.scoreEnps,
    required this.bottleneckLayer,
    required this.scoreLevel,
    this.subScores,
    this.selectedNarrativeVariants,
    required this.createdAt,
  });

  final String id;
  final String surveyId;
  final String userId;
  final double scoreTotal;
  final double scoreStructure;
  final double scoreCulture;
  final double scoreActivity;
  final double? scoreEsi;
  final int? scoreEnps;
  final SurveyLayer bottleneckLayer;
  final ScoreLevel scoreLevel;
  final Map<String, dynamic>? subScores;
  final Map<String, dynamic>? selectedNarrativeVariants;
  final DateTime createdAt;

  factory CcReportFull.fromJson(Map<String, dynamic> json) {
    final snv = json['selected_narrative_variants'];
    final ss = json['sub_scores'];
    return CcReportFull(
      id: json['id'] as String,
      surveyId: json['survey_id'] as String,
      userId: json['user_id'] as String,
      scoreTotal: (json['score_total'] as num).toDouble(),
      scoreStructure: (json['score_structure'] as num).toDouble(),
      scoreCulture: (json['score_culture'] as num).toDouble(),
      scoreActivity: (json['score_activity'] as num).toDouble(),
      scoreEsi: json['score_esi'] != null
          ? (json['score_esi'] as num).toDouble()
          : null,
      scoreEnps: json['score_enps'] as int?,
      bottleneckLayer:
          SurveyLayer.fromJson(json['bottleneck_layer'] as String),
      scoreLevel: ScoreLevel.fromJson(json['score_level'] as String),
      subScores: ss != null ? Map<String, dynamic>.from(ss as Map) : null,
      selectedNarrativeVariants:
          snv != null ? Map<String, dynamic>.from(snv as Map) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// ActionPlanPhase
// ---------------------------------------------------------------------------

class ActionPlanPhase {
  const ActionPlanPhase({
    required this.id,
    required this.day,
    required this.titleVi,
    required this.titleEn,
    this.description,
    this.reflectionQuestion,
    required this.surveyType,
    required this.displayOrder,
    this.tasks = const [],
  });

  final String id;
  final int day;
  final String titleVi;
  final String titleEn;
  final String? description;
  final String? reflectionQuestion;
  final SurveyType surveyType;
  final int displayOrder;
  final List<ActionPlanTask> tasks;

  factory ActionPlanPhase.fromJson(Map<String, dynamic> json) {
    return ActionPlanPhase(
      id: json['id'] as String,
      day: json['day'] as int,
      titleVi: json['title_vi'] as String,
      titleEn: json['title_en'] as String,
      description: json['description'] as String?,
      reflectionQuestion: json['reflection_question'] as String?,
      surveyType: SurveyType.fromJson(json['survey_type'] as String),
      displayOrder: json['display_order'] as int,
    );
  }
}

// ---------------------------------------------------------------------------
// ActionPlanTask
// ---------------------------------------------------------------------------

class ActionPlanTask {
  const ActionPlanTask({
    required this.id,
    required this.phaseId,
    required this.label,
    required this.displayOrder,
    this.completed = false,
  });

  final String id;
  final String phaseId;
  final String label;
  final int displayOrder;
  final bool completed;

  factory ActionPlanTask.fromJson(Map<String, dynamic> json) {
    return ActionPlanTask(
      id: json['id'] as String,
      phaseId: json['phase_id'] as String,
      label: json['label'] as String,
      displayOrder: json['display_order'] as int,
      completed: json['completed'] as bool? ?? false,
    );
  }

  ActionPlanTask copyWith({bool? completed}) {
    return ActionPlanTask(
      id: id,
      phaseId: phaseId,
      label: label,
      displayOrder: displayOrder,
      completed: completed ?? this.completed,
    );
  }
}

// ---------------------------------------------------------------------------
// TtsResult
// ---------------------------------------------------------------------------

class TtsResult {
  const TtsResult({
    required this.audioUrl,
    required this.durationMs,
    required this.fromCache,
  });

  final String audioUrl;
  final int durationMs;
  final bool fromCache;

  factory TtsResult.fromJson(Map<String, dynamic> json) {
    return TtsResult(
      audioUrl: json['audioUrl'] as String,
      durationMs: json['durationMs'] as int,
      fromCache: json['fromCache'] as bool? ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// CcReportSummary — lightweight list item for survey history
// ---------------------------------------------------------------------------

class CcReportSummary {
  const CcReportSummary({
    required this.id,
    required this.surveyId,
    required this.createdAt,
    required this.scoreTotal,
    required this.scoreLevel,
    this.scoreEsi,
    this.scoreEnps,
  });

  final String id;
  final String surveyId;
  final DateTime createdAt;
  final double scoreTotal;
  final ScoreLevel scoreLevel;

  /// Non-null for premium reports.
  final double? scoreEsi;

  /// Non-null for premium reports.
  final int? scoreEnps;

  bool get isPremium => scoreEsi != null || scoreEnps != null;

  factory CcReportSummary.fromJson(Map<String, dynamic> json) {
    return CcReportSummary(
      id: json['id'] as String,
      surveyId: json['survey_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      scoreTotal: (json['score_total'] as num).toDouble(),
      scoreLevel: ScoreLevel.fromJson(json['score_level'] as String),
      scoreEsi: json['score_esi'] != null
          ? (json['score_esi'] as num).toDouble()
          : null,
      scoreEnps: json['score_enps'] as int?,
    );
  }
}

// ---------------------------------------------------------------------------
// EnpsBreakdown — render-time eNPS breakdown computed from cc_responses
// ---------------------------------------------------------------------------

class EnpsBreakdown {
  const EnpsBreakdown({
    required this.promoters,
    required this.passives,
    required this.detractors,
    required this.total,
  });

  final int promoters;
  final int passives;
  final int detractors;
  final int total;

  /// Compute breakdown from raw answer values.
  /// Thresholds mirror web calculateENPS: >=9 promoter, >=7 passive, else detractor.
  factory EnpsBreakdown.fromValues(List<int> values) {
    int promoters = 0, passives = 0, detractors = 0;
    for (final v in values) {
      if (v >= 9) {
        promoters++;
      } else if (v >= 7) {
        passives++;
      } else {
        detractors++;
      }
    }
    return EnpsBreakdown(
      promoters: promoters,
      passives: passives,
      detractors: detractors,
      total: values.length,
    );
  }
}

// ---------------------------------------------------------------------------
// SubComponentScore — per sub-component avg score from cc_responses + cc_questions
// ---------------------------------------------------------------------------

class SubComponentScore {
  const SubComponentScore({
    required this.subComponent,
    required this.label,
    required this.score,
    required this.count,
  });

  final String subComponent;
  final String label;
  final double score;
  final int count;
}

// ---------------------------------------------------------------------------
// SurveyScores (output of scoring engine)
// ---------------------------------------------------------------------------

class SurveyScores {
  const SurveyScores({
    required this.scoreStructure,
    required this.scoreCulture,
    required this.scoreActivity,
    required this.scoreTotal,
    this.scoreEsi,
    this.scoreEnps,
    required this.bottleneckLayer,
    required this.scoreLevel,
    this.enpsPromoters,
    this.enpsPassives,
    this.enpsDetractors,
  });

  final double scoreStructure;
  final double scoreCulture;
  final double scoreActivity;
  final double scoreTotal;
  final double? scoreEsi;
  final int? scoreEnps;
  final SurveyLayer bottleneckLayer;
  final ScoreLevel scoreLevel;
  final int? enpsPromoters;
  final int? enpsPassives;
  final int? enpsDetractors;
}
