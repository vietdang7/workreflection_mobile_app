// AI Personalization models — Phase 5 Task 4.
// Mirror of web's types/ai-personalize.ts.
// All classes are immutable. No Flutter dependencies.

// ---------------------------------------------------------------------------
// Content shapes (mirror SECTION_SCHEMAS in the edge function)
// ---------------------------------------------------------------------------

class AiModelContent {
  const AiModelContent({
    required this.quote,
    required this.intro,
    required this.structureDesc,
    required this.cultureDesc,
    required this.activityDesc,
  });

  final String quote;
  final String intro;
  final String structureDesc;
  final String cultureDesc;
  final String activityDesc;

  factory AiModelContent.fromJson(Map<String, dynamic> j) => AiModelContent(
        quote: j['quote'] as String,
        intro: j['intro'] as String,
        structureDesc: j['structure_desc'] as String,
        cultureDesc: j['culture_desc'] as String,
        activityDesc: j['activity_desc'] as String,
      );
}

class AiReflectionContent {
  const AiReflectionContent({
    required this.intro,
    required this.item1Desc,
    required this.item2Desc,
    required this.item3Desc,
    required this.pausesIntro,
    required this.pause1,
    required this.pause2,
    required this.pause3,
  });

  final String intro;
  final String item1Desc;
  final String item2Desc;
  final String item3Desc;
  final String pausesIntro;
  final String pause1;
  final String pause2;
  final String pause3;

  factory AiReflectionContent.fromJson(Map<String, dynamic> j) =>
      AiReflectionContent(
        intro: j['intro'] as String,
        item1Desc: j['item1_desc'] as String,
        item2Desc: j['item2_desc'] as String,
        item3Desc: j['item3_desc'] as String,
        pausesIntro: j['pauses_intro'] as String,
        pause1: j['pause1'] as String,
        pause2: j['pause2'] as String,
        pause3: j['pause3'] as String,
      );
}

class AiRelationshipContent {
  const AiRelationshipContent({
    required this.headerQuote,
    required this.misconceptionText,
    required this.misconceptionQuote,
    required this.asset1Desc,
    required this.asset2Desc,
    required this.asset3Desc,
    required this.asset4Desc,
    required this.asset5Desc,
    required this.closingQuote,
  });

  final String headerQuote;
  final String misconceptionText;
  final String misconceptionQuote;
  final String asset1Desc;
  final String asset2Desc;
  final String asset3Desc;
  final String asset4Desc;
  final String asset5Desc;
  final String closingQuote;

  factory AiRelationshipContent.fromJson(Map<String, dynamic> j) =>
      AiRelationshipContent(
        headerQuote: j['header_quote'] as String,
        misconceptionText: j['misconception_text'] as String,
        misconceptionQuote: j['misconception_quote'] as String,
        asset1Desc: j['asset1_desc'] as String,
        asset2Desc: j['asset2_desc'] as String,
        asset3Desc: j['asset3_desc'] as String,
        asset4Desc: j['asset4_desc'] as String,
        asset5Desc: j['asset5_desc'] as String,
        closingQuote: j['closing_quote'] as String,
      );
}

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

class AiPersonalizationResult {
  const AiPersonalizationResult({
    this.model,
    this.reflection,
    this.relationship,
  });

  final AiModelContent? model;
  final AiReflectionContent? reflection;
  final AiRelationshipContent? relationship;
}

// ---------------------------------------------------------------------------
// User/Score context (payload fields)
// ---------------------------------------------------------------------------

class AiPersonalizationUserContext {
  const AiPersonalizationUserContext({
    this.position,
    this.tenure,
    this.department,
  });

  final String? position;
  final String? tenure;
  final String? department;

  Map<String, dynamic> toJson() => {
        if (position != null) 'position': position,
        if (tenure != null) 'tenure': tenure,
        if (department != null) 'department': department,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiPersonalizationUserContext &&
          position == other.position &&
          tenure == other.tenure &&
          department == other.department;

  @override
  int get hashCode => Object.hash(position, tenure, department);
}

class AiPersonalizationScoreContext {
  const AiPersonalizationScoreContext({
    required this.structure,
    required this.culture,
    required this.activity,
    required this.total,
    required this.esi,
    required this.bottleneck,
    required this.scoreLevel,
  });

  final double structure;
  final double culture;
  final double activity;
  final double total;
  final double esi;
  final String bottleneck;
  final String scoreLevel;

  Map<String, dynamic> toJson() => {
        'structure': structure,
        'culture': culture,
        'activity': activity,
        'total': total,
        'esi': esi,
        'bottleneck': bottleneck,
        'scoreLevel': scoreLevel,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiPersonalizationScoreContext &&
          structure == other.structure &&
          culture == other.culture &&
          activity == other.activity &&
          total == other.total &&
          esi == other.esi &&
          bottleneck == other.bottleneck &&
          scoreLevel == other.scoreLevel;

  @override
  int get hashCode =>
      Object.hash(structure, culture, activity, total, esi, bottleneck, scoreLevel);
}
