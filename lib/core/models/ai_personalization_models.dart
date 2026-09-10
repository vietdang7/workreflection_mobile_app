// AI Personalization models — Phase 5 Task 4.
// Mirror of web's types/ai-personalize.ts.
// All classes are immutable. No Flutter dependencies.

import '../logic/wr_plain_text.dart';

/// Mọi trường ở file này là chữ do model `ai-personalize` viết ra, và màn Báo
/// cáo dựng bằng `Text` thuần — dấu sao Markdown lọt qua là hiện nguyên hình
/// (mục 17.1, khách 09/09).
///
/// Lọc Ở ĐÂY chứ không ở Edge Function vì `ai-personalize` **không nằm trong
/// repo này** (nó là hàm của phần web/Khảo sát). Đây là chỗ duy nhất trong tầm
/// với.
String _plain(dynamic v) => stripMarkdown(v as String);

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
        quote: _plain(j['quote']),
        intro: _plain(j['intro']),
        structureDesc: _plain(j['structure_desc']),
        cultureDesc: _plain(j['culture_desc']),
        activityDesc: _plain(j['activity_desc']),
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
        intro: _plain(j['intro']),
        item1Desc: _plain(j['item1_desc']),
        item2Desc: _plain(j['item2_desc']),
        item3Desc: _plain(j['item3_desc']),
        pausesIntro: _plain(j['pauses_intro']),
        pause1: _plain(j['pause1']),
        pause2: _plain(j['pause2']),
        pause3: _plain(j['pause3']),
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
        headerQuote: _plain(j['header_quote']),
        misconceptionText: _plain(j['misconception_text']),
        misconceptionQuote: _plain(j['misconception_quote']),
        asset1Desc: _plain(j['asset1_desc']),
        asset2Desc: _plain(j['asset2_desc']),
        asset3Desc: _plain(j['asset3_desc']),
        asset4Desc: _plain(j['asset4_desc']),
        asset5Desc: _plain(j['asset5_desc']),
        closingQuote: _plain(j['closing_quote']),
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
