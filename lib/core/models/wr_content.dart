// WorkReflection content models — WR Data Foundation Sprint 0 (Task 3).
// Plain immutable classes + fromJson, mirroring checkin.dart / ai_personalization_models.dart style.
// No Flutter dependencies.

// ---------------------------------------------------------------------------
// HumanNeed enum
// ---------------------------------------------------------------------------

/// 4 nhu cầu cốt lõi. dbValue matches wr_situations.human_need check constraint.
enum HumanNeed {
  roRang,
  ketNoi,
  thichNghi,
  phatTrien;

  String get dbValue => switch (this) {
        HumanNeed.roRang => 'ro_rang',
        HumanNeed.ketNoi => 'ket_noi',
        HumanNeed.thichNghi => 'thich_nghi',
        HumanNeed.phatTrien => 'phat_trien',
      };

  static HumanNeed fromDb(String value) => switch (value) {
        'ro_rang' => HumanNeed.roRang,
        'ket_noi' => HumanNeed.ketNoi,
        'thich_nghi' => HumanNeed.thichNghi,
        'phat_trien' => HumanNeed.phatTrien,
        _ => throw ArgumentError('Unknown HumanNeed db value: $value'),
      };
}

// ---------------------------------------------------------------------------
// ScaDimension enum
// ---------------------------------------------------------------------------

/// 10 chiều SCA + 2 nhóm tình huống tích cực.
/// dbValue matches wr_situations.sca_dimension check constraint.
///
/// Wave mapping (read-only, not stored on enum):
///   wave1 = C2, A1, A3, C1
///   wave2 = A4, A2, S1
///   wave3 = C3, S2, S3
///
/// [pAchieve] và [pSteady] KHÔNG phải chiều SCA. Kiến trúc Dữ liệu v1.6 §2.3:
/// Career Situation Library chỉ có tình huống dạng vấn đề, vì nguồn gốc là công
/// cụ chẩn đoán tổ chức. Người dùng check-in "khá ổn" / "đang vui" mà vẫn nhận
/// tình huống vấn đề thì thấy gượng ép, nên hai nhóm này được soạn thêm và dùng
/// chung một trường `dim` với SCA (§2.2).
///
/// Mọi thống kê SCA phải lọc bằng [isSca] trước, nếu không hai nhóm tích cực sẽ
/// lẫn vào điểm số của một trụ mà chúng không thuộc về.
enum ScaDimension {
  s1,
  s2,
  s3,
  c1,
  c2,
  c3,
  a1,
  a2,
  a3,
  a4,
  pAchieve,
  pSteady;

  String get dbValue => switch (this) {
        ScaDimension.s1 => 'S1',
        ScaDimension.s2 => 'S2',
        ScaDimension.s3 => 'S3',
        ScaDimension.c1 => 'C1',
        ScaDimension.c2 => 'C2',
        ScaDimension.c3 => 'C3',
        ScaDimension.a1 => 'A1',
        ScaDimension.a2 => 'A2',
        ScaDimension.a3 => 'A3',
        ScaDimension.a4 => 'A4',
        ScaDimension.pAchieve => 'P-ACHIEVE',
        ScaDimension.pSteady => 'P-STEADY',
      };

  /// True cho 10 chiều SCA thật; false cho hai nhóm tình huống tích cực.
  bool get isSca => !isPositive;

  /// True cho nhóm tình huống tích cực tự soạn (§2.3).
  bool get isPositive =>
      this == ScaDimension.pAchieve || this == ScaDimension.pSteady;

  static ScaDimension fromDb(String value) => switch (value) {
        'S1' => ScaDimension.s1,
        'S2' => ScaDimension.s2,
        'S3' => ScaDimension.s3,
        'C1' => ScaDimension.c1,
        'C2' => ScaDimension.c2,
        'C3' => ScaDimension.c3,
        'A1' => ScaDimension.a1,
        'A2' => ScaDimension.a2,
        'A3' => ScaDimension.a3,
        'A4' => ScaDimension.a4,
        'P-ACHIEVE' => ScaDimension.pAchieve,
        'P-STEADY' => ScaDimension.pSteady,
        _ => throw ArgumentError('Unknown ScaDimension db value: $value'),
      };
}

// ---------------------------------------------------------------------------
// WrSituation
// ---------------------------------------------------------------------------

/// Maps to public.wr_situations.
class WrSituation {
  const WrSituation({
    required this.code,
    required this.text,
    required this.scaDimension,
    required this.wave,
    this.humanNeed,
    this.expectedOutcome,
    this.scaPerspective,
    this.createdAt,
  });

  final String code;
  final String text;
  final ScaDimension scaDimension;
  final HumanNeed? humanNeed;
  final String? expectedOutcome;
  final String? scaPerspective;
  final int wave;
  final DateTime? createdAt;

  factory WrSituation.fromJson(Map<String, dynamic> json) {
    final rawNeed = json['human_need'] as String?;
    return WrSituation(
      code: json['code'] as String,
      text: json['text'] as String,
      scaDimension: ScaDimension.fromDb(json['sca_dimension'] as String),
      humanNeed: rawNeed != null ? HumanNeed.fromDb(rawNeed) : null,
      expectedOutcome: json['expected_outcome'] as String?,
      scaPerspective: json['sca_perspective'] as String?,
      wave: json['wave'] as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// WrStory
// ---------------------------------------------------------------------------

/// Maps to public.wr_stories.
class WrStory {
  const WrStory({
    required this.storyId,
    required this.title,
    required this.scaDimension,
    required this.storyContent,
    required this.emotionTags,
    required this.behaviorTags,
    required this.careerStages,
    this.humanNeed,
    this.situation,
    this.difficultyLevel,
    this.reflectionQuestion,
    this.selfReflection,
    this.ahaMessage,
    this.practiceAction,
    this.createdAt,
  });

  final String storyId;
  final String title;
  final ScaDimension scaDimension;
  final HumanNeed? humanNeed;
  final String? situation;
  final List<String> emotionTags;
  final List<String> behaviorTags;
  final List<String> careerStages;
  final int? difficultyLevel;
  final String storyContent;
  final String? reflectionQuestion;
  final String? selfReflection;
  final String? ahaMessage;
  final String? practiceAction;
  final DateTime? createdAt;

  factory WrStory.fromJson(Map<String, dynamic> json) {
    final rawNeed = json['human_need'] as String?;
    return WrStory(
      storyId: json['story_id'] as String,
      title: json['title'] as String,
      scaDimension: ScaDimension.fromDb(json['sca_dimension'] as String),
      humanNeed: rawNeed != null ? HumanNeed.fromDb(rawNeed) : null,
      situation: json['situation'] as String?,
      emotionTags: _toStringList(json['emotion_tags']),
      behaviorTags: _toStringList(json['behavior_tags']),
      careerStages: _toStringList(json['career_stages']),
      difficultyLevel: json['difficulty_level'] as int?,
      storyContent: json['story_content'] as String,
      reflectionQuestion: json['reflection_question'] as String?,
      selfReflection: json['self_reflection'] as String?,
      ahaMessage: json['aha_message'] as String?,
      practiceAction: json['practice_action'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  static List<String> _toStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.cast<String>();
    return const [];
  }
}

// ---------------------------------------------------------------------------
// CareerMemoryEvent
// ---------------------------------------------------------------------------

/// Maps to public.wr_career_memory_events.
class CareerMemoryEvent {
  const CareerMemoryEvent({
    required this.id,
    required this.userId,
    this.storyId,
    this.situationCode,
    this.humanNeed,
    this.scaDimension,
    this.emotion,
    this.behavior,
    this.intensity,
    this.reflectionText,
    this.careerStage,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String? storyId;
  final String? situationCode;
  final HumanNeed? humanNeed;
  final ScaDimension? scaDimension;
  final String? emotion;
  final String? behavior;
  final int? intensity;
  final String? reflectionText;
  final String? careerStage;
  final DateTime? createdAt;

  factory CareerMemoryEvent.fromJson(Map<String, dynamic> json) {
    final rawNeed = json['human_need'] as String?;
    final rawDim = json['sca_dimension'] as String?;
    return CareerMemoryEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      storyId: json['story_id'] as String?,
      situationCode: json['situation_code'] as String?,
      humanNeed: rawNeed != null ? HumanNeed.fromDb(rawNeed) : null,
      scaDimension: rawDim != null ? ScaDimension.fromDb(rawDim) : null,
      emotion: json['emotion'] as String?,
      behavior: json['behavior'] as String?,
      intensity: json['intensity'] as int?,
      reflectionText: json['reflection_text'] as String?,
      careerStage: json['career_stage'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Returns a map suitable for INSERT into public.wr_career_memory_events.
  /// Excludes server-generated fields: id, created_at.
  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        if (storyId != null) 'story_id': storyId,
        if (situationCode != null) 'situation_code': situationCode,
        if (humanNeed != null) 'human_need': humanNeed!.dbValue,
        if (scaDimension != null) 'sca_dimension': scaDimension!.dbValue,
        if (emotion != null) 'emotion': emotion,
        if (behavior != null) 'behavior': behavior,
        if (intensity != null) 'intensity': intensity,
        if (reflectionText != null) 'reflection_text': reflectionText,
        if (careerStage != null) 'career_stage': careerStage,
      };
}
