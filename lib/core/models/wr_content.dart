// WorkReflection content models — WR Data Foundation Sprint 0 (Task 3).
// Plain immutable classes + fromJson, mirroring checkin.dart / ai_personalization_models.dart style.
// No Flutter dependencies.

import '../l10n/wr_tr.dart';

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
    // Editorial v2 values are kept in the generated seed beside the
    // database alias. Accepting them here makes a direct JS-shaped payload
    // safe to inspect without teaching callers about the import mapping.
    'Structure' => HumanNeed.roRang,
    'Connection' => HumanNeed.ketNoi,
    'Adaptability' => HumanNeed.thichNghi,
    'Phát triển' => HumanNeed.phatTrien,
    _ => throw ArgumentError('Unknown HumanNeed db value: $value'),
  };

  /// Nullable parser used at persistence boundaries. A malformed historical
  /// row should be ignored by aggregation, not take down the whole profile.
  static HumanNeed? tryFromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return fromDb(value);
    } on ArgumentError {
      return null;
    }
  }
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
///
/// TỪ 11/09/2026 CÓ MỘT NGOẠI LỆ, và nó không mâu thuẫn với đoạn trên.
/// `DienGiaiSau v2` §2.1 gán trụ cho cả 10 tình huống tích cực, nhưng gán vào
/// một trường RIÊNG ([WrSituation.pillar]) chứ không đụng vào `sca_dimension`.
/// Hai câu hỏi khác nhau: "tình huống này đo chiều SCA nào" (vẫn chỉ 10 chiều
/// thật) và "tình huống này thuộc mặt nào của công việc" (46 → nay 110 tình
/// huống đều trả lời được). Xem [WrValence] về vì sao cần cả hai.
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

  /// Nullable parser for legacy rows that may contain a removed dimension.
  static ScaDimension? tryFromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return fromDb(value);
    } on ArgumentError {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// WrValence
// ---------------------------------------------------------------------------

/// Tình huống này là một khó khăn hay một điều thuận lợi.
///
/// `DienGiaiSau v2` §2.2 gọi đây là "phần bắt buộc", và lý do nằm gọn trong một
/// ví dụ: "Nếu nhóm C có 10 lần, hệ thống không phân biệt được đó là 10 lần gặp
/// khó khăn về quan hệ hay 10 lần có trải nghiệm tốt về quan hệ. Hai điều này
/// có ý nghĩa trái ngược nhau hoàn toàn."
///
/// Nên trụ và valence là HAI TRỤC ĐỘC LẬP, không suy được cái này từ cái kia.
/// Trụ nói *mặt nào* của công việc, valence nói *chiều nào* của trải nghiệm.
///
/// KHÔNG CẦN CỘT DB. §2.2 yêu cầu thêm một trường, nhưng trường ấy đã tồn tại
/// sẵn dưới một cái tên khác: đúng 10 tình huống P là tích cực, và chúng đã
/// được tách bằng [ScaDimension.isPositive] từ trước. Dựng thêm một cột nữa là
/// mở đường cho hai nguồn nói khác nhau về cùng một tình huống.
enum WrValence {
  /// 160 tình huống của Career Situation Library — nguồn gốc là công cụ chẩn
  /// đoán tổ chức nên tất cả đều ở dạng vấn đề.
  thachThuc,

  /// 10 tình huống P-ACHIEVE / P-STEADY.
  tichCuc;

  String get dbValue => switch (this) {
    WrValence.thachThuc => 'thach-thuc',
    WrValence.tichCuc => 'tich-cuc',
  };

  bool get isPositive => this == WrValence.tichCuc;

  static WrValence fromDb(String value) => switch (value) {
    'thach-thuc' => WrValence.thachThuc,
    'tich-cuc' => WrValence.tichCuc,
    _ => throw ArgumentError('Unknown WrValence db value: $value'),
  };

  static WrValence? tryFromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return fromDb(value);
    } on ArgumentError {
      return null;
    }
  }
}

/// Explicit v2 catalog axes. Keep these values in the data layer so every
/// consumer (picker, counts, deep reading, and UI) agrees on what is a
/// classified situation. A legacy row may still be parsed, but it is not a
/// v2 situation unless all of these axes are valid and explicit.
const Set<String> kWrV2PillarCodes = {'S', 'C', 'A'};
const Set<String> kWrV2SubgroupCodes = {
  'S1',
  'S2',
  'C1',
  'C2',
  'A1',
  'A3',
  'Sp',
  'Cp',
  'Ap',
};
const Set<String> kWrV2MoodCodes = {
  'stress',
  'tired',
  'foggy',
  'outofsync',
  'ok',
  'happy',
};
const Map<String, String> kWrV2SubgroupPillars = {
  'S1': 'S',
  'S2': 'S',
  'C1': 'C',
  'C2': 'C',
  'A1': 'A',
  'A3': 'A',
  'Sp': 'S',
  'Cp': 'C',
  'Ap': 'A',
};

// ---------------------------------------------------------------------------
// WrSituation
// ---------------------------------------------------------------------------

/// Maps to public.wr_situations.
class WrSituation {
  const WrSituation({
    required this.code,
    required String text,
    required this.scaDimension,
    required this.wave,
    this.textEn,
    this.humanNeed,
    this.expectedOutcome,
    this.scaPerspective,
    this.pillarCode,
    this.subgroup,
    this.mood,
    WrValence? valence,
    this.custom = false,
    this.createdAt,
    this.retiredAt,
  }) : textVi = text,
       _explicitValence = valence;

  /// Client-only custom self-description choice. It deliberately carries no
  /// v2 classification; the compatibility dimension is never used by the v2
  /// counting/picker paths.
  static const WrSituation customOption = WrSituation(
    code: 'other',
    text: 'Điều khác, để tôi tự mô tả',
    scaDimension: ScaDimension.pSteady,
    wave: 1,
    custom: true,
  );

  final String code;

  /// Bản tiếng Việt, đúng như trong bảng.
  ///
  /// Đọc trực tiếp trường này khi cần CHÍNH bản gốc bất kể ngôn ngữ đang bật —
  /// ví dụ khi đem so khớp với dữ liệu tiếng Việt. Muốn chữ để HIỆN LÊN thì
  /// dùng [text].
  final String textVi;

  /// Bản tiếng Anh, null khi đội nội dung chưa dịch dòng này.
  final String? textEn;

  /// Chữ đem hiển thị, đã chọn theo ngôn ngữ đang bật.
  ///
  /// Là getter chứ không phải trường, và cố ý giữ nguyên tên `text` cũ: 64 chỗ
  /// đang dựng và đọc `WrSituation` không phải sửa dòng nào, mà tất cả cùng lúc
  /// biết nghe theo ngôn ngữ. Chưa có bản dịch thì rơi về [textVi].
  String get text => trDb(textVi, textEn);

  final ScaDimension scaDimension;
  final HumanNeed? humanNeed;
  final String? expectedOutcome;
  final String? scaPerspective;
  final int wave;
  final DateTime? createdAt;

  /// Khác null = ngưng đề xuất cho phiên mới.
  ///
  /// Dùng cho 60 chip Tầng 1 cũ (`<DIM>-sit-NN`), đã được thay bằng 100 mục của
  /// Career Situation Library có mã trùng `wr_stories.story_id`.
  ///
  /// KHÔNG xoá khỏi bảng: `wr_reflection_episodes`, `wr_pattern_counts` và
  /// `wr_career_memory_events` còn tham chiếu những mã này, và tab Hiểu mình
  /// tra ngược ra nhãn từ đó. Xoá là làm trống nhãn của toàn bộ lịch sử.
  /// Chỉ những chỗ CHÀO MỜI một tình huống mới phải lọc — xem
  /// [pickSituationChoices].
  final DateTime? retiredAt;

  bool get isRetired => retiredAt != null;

  /// Chữ 'S' / 'C' / 'A' đọc thẳng từ cột `wr_situations.pillar`, hoặc null khi
  /// đội nội dung chưa điền.
  ///
  /// Để thô như vậy — không phải `SelfCheckPillar` — vì model này nằm ở tầng dữ
  /// liệu và không được biết tới enum của tầng logic Self-Check. Chỗ dịch sang
  /// enum là `pillarOfSituation` trong `wr_career_health.dart`.
  final String? pillarCode;

  /// Explicit v2 subgroup, for example `S1`, `C2`, or the positive groups
  /// `Sp`/`Cp`/`Ap`.
  final String? subgroup;

  /// Check-in mood code (`stress`, `tired`, `foggy`, `outofsync`, `ok`,
  /// `happy`).
  final String? mood;

  /// Whether this is the client-only free-form option.
  final bool custom;

  final WrValence? _explicitValence;

  /// The v2 value as declared by the catalog. Null for legacy/custom rows.
  /// Use this property when a caller must distinguish “not classified” from a
  /// legacy value inferred from [scaDimension].
  WrValence? get explicitValence => _explicitValence;

  /// Alias that reads naturally at call sites migrating to v2.
  WrValence? get v2Valence => _explicitValence;

  bool get isCustom => custom || code == 'other';

  /// True only when all four v2 classification axes are valid and explicit.
  /// The compatibility `scaDimension` never participates in this decision.
  bool get hasV2Classification =>
      !isCustom &&
      kWrV2PillarCodes.contains(pillarCode) &&
      kWrV2SubgroupCodes.contains(subgroup) &&
      kWrV2SubgroupPillars[subgroup] == pillarCode &&
      kWrV2MoodCodes.contains(mood) &&
      _explicitValence != null;

  /// Khó khăn hay thuận lợi (§2.2).
  ///
  /// Public compatibility getter. Canonical v2 rows use the explicit value;
  /// old rows fall back to their persisted compatibility dimension. For
  /// custom rows this value is not a classification and must be ignored when
  /// [isCustom] is true.
  WrValence get valence =>
      _explicitValence ??
      (scaDimension.isPositive ? WrValence.tichCuc : WrValence.thachThuc);

  factory WrSituation.fromJson(Map<String, dynamic> json) {
    final rawNeed = (json['human_need'] ?? json['need']) as String?;
    final code = (json['code'] ?? json['id']) as String?;
    if (code == null || code.isEmpty) {
      throw const FormatException('Situation is missing code/id');
    }
    final isCustom = json['custom'] == true || code == 'other';
    final rawDimension = json['sca_dimension'] as String?;
    final dimension = rawDimension == null
        ? (isCustom ? ScaDimension.pSteady : null)
        : ScaDimension.fromDb(rawDimension);
    if (dimension == null) {
      throw FormatException('Situation $code is missing sca_dimension');
    }
    final rawText = (json['text'] ?? json['title']) as String?;
    if (rawText == null) {
      throw FormatException('Situation $code is missing text/title');
    }
    return WrSituation(
      code: code,
      text: rawText,
      textEn: json['text_en'] as String?,
      scaDimension: dimension,
      humanNeed: HumanNeed.tryFromDb(rawNeed),
      expectedOutcome: json['expected_outcome'] as String?,
      scaPerspective: json['sca_perspective'] as String?,
      pillarCode: json['pillar'] as String?,
      subgroup: json['subgroup'] as String?,
      mood: json['mood'] as String?,
      valence: WrValence.tryFromDb(json['valence'] as String?),
      custom: isCustom,
      wave: (json['wave'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      retiredAt: json['retired_at'] != null
          ? DateTime.parse(json['retired_at'] as String)
          : null,
    );
  }
}

/// Shared name for the UI's client-only free-form choice.
const kWrOtherSituation = WrSituation.customOption;

// ---------------------------------------------------------------------------
// WrStory
// ---------------------------------------------------------------------------

/// Maps to public.wr_stories.
class WrStory {
  const WrStory({
    required this.storyId,
    required String title,
    required this.scaDimension,
    required String storyContent,
    required this.emotionTags,
    required this.behaviorTags,
    required this.careerStages,
    this.titleEn,
    this.storyContentEn,
    this.humanNeed,
    this.situation,
    this.pillarCode,
    this.subgroup,
    this.mood,
    WrValence? valence,
    this.difficultyLevel,
    String? reflectionQuestion,
    String? selfReflection,
    String? ahaMessage,
    String? practiceAction,
    this.reflectionQuestionEn,
    this.selfReflectionEn,
    this.ahaMessageEn,
    this.practiceActionEn,
    this.createdAt,
  }) : titleVi = title,
       storyContentVi = storyContent,
       reflectionQuestionVi = reflectionQuestion,
       selfReflectionVi = selfReflection,
       ahaMessageVi = ahaMessage,
       practiceActionVi = practiceAction,
       _explicitValence = valence;

  final String storyId;
  final ScaDimension scaDimension;
  final HumanNeed? humanNeed;

  /// Có trong bảng và trong model, nhưng KHÔNG chỗ nào đưa lên màn hình — nên
  /// cố ý không có bản tiếng Anh. Xem đầu migration `content_en_columns`.
  final String? situation;

  /// Optional v2 classification copied from the matching situation record.
  /// Stories remain readable for legacy rows where these columns were absent.
  final String? pillarCode;
  final String? subgroup;
  final String? mood;
  final WrValence? _explicitValence;

  WrValence? get explicitValence => _explicitValence;

  WrValence? get valence => _explicitValence;

  final List<String> emotionTags;
  final List<String> behaviorTags;

  /// Dùng để XẾP THỨ TỰ trong `wr_career_profile.dart`, không phải chữ đọc.
  /// Dịch là làm hỏng phép so khớp.
  final List<String> careerStages;

  final int? difficultyLevel;
  final DateTime? createdAt;

  // Sáu cặp dưới đây là sáu chỗ hiện lên trong luồng đọc truyện. Mỗi cặp giữ
  // bản gốc ở trường `…Vi`, bản dịch ở `…En`, và mở ra ngoài bằng một getter
  // mang đúng tên cũ — 14 chỗ dựng `WrStory` không phải sửa dòng nào.
  final String titleVi;
  final String? titleEn;
  String get title => trDb(titleVi, titleEn);

  final String storyContentVi;
  final String? storyContentEn;
  String get storyContent => trDb(storyContentVi, storyContentEn);

  final String? reflectionQuestionVi;
  final String? reflectionQuestionEn;
  String? get reflectionQuestion =>
      _pick(reflectionQuestionVi, reflectionQuestionEn);

  final String? selfReflectionVi;
  final String? selfReflectionEn;
  String? get selfReflection => _pick(selfReflectionVi, selfReflectionEn);

  final String? ahaMessageVi;
  final String? ahaMessageEn;
  String? get ahaMessage => _pick(ahaMessageVi, ahaMessageEn);

  final String? practiceActionVi;
  final String? practiceActionEn;
  String? get practiceAction => _pick(practiceActionVi, practiceActionEn);

  /// Như `trDb` nhưng cho cột mà bản THÂN bản gốc cũng có thể vắng.
  ///
  /// Bốn cột này nullable từ trước, và nơi dùng đang phân biệt "có câu" với
  /// "không có câu" để quyết định hiện hay giấu cả khối. Ép về chuỗi rỗng ở đây
  /// là biến "không có" thành "có nhưng trắng", tức hiện một khối trống.
  static String? _pick(String? vi, String? en) =>
      vi == null ? null : trDb(vi, en);

  factory WrStory.fromJson(Map<String, dynamic> json) {
    final rawNeed = (json['human_need'] ?? json['need']) as String?;
    final storyId = (json['story_id'] ?? json['id']) as String?;
    if (storyId == null || storyId.isEmpty) {
      throw const FormatException('Story is missing story_id/id');
    }
    final rawTitle = (json['title'] ?? json['text']) as String?;
    if (rawTitle == null) {
      throw FormatException('Story $storyId is missing title/text');
    }
    final rawContent = (json['story_content'] ?? json['story']) as String?;
    if (rawContent == null) {
      throw FormatException('Story $storyId is missing story_content/story');
    }
    return WrStory(
      storyId: storyId,
      title: rawTitle,
      titleEn: json['title_en'] as String?,
      scaDimension: ScaDimension.fromDb(json['sca_dimension'] as String),
      humanNeed: HumanNeed.tryFromDb(rawNeed),
      situation: json['situation'] as String?,
      pillarCode: json['pillar'] as String?,
      subgroup: json['subgroup'] as String?,
      mood: json['mood'] as String?,
      valence: WrValence.tryFromDb(json['valence'] as String?),
      emotionTags: _toStringList(json['emotion_tags']),
      behaviorTags: _toStringList(json['behavior_tags']),
      careerStages: _toStringList(json['career_stages']),
      difficultyLevel: json['difficulty_level'] as int?,
      storyContent: rawContent,
      storyContentEn: json['story_content_en'] as String?,
      reflectionQuestion: json['reflection_question'] as String?,
      reflectionQuestionEn: json['reflection_question_en'] as String?,
      selfReflection: json['self_reflection'] as String?,
      selfReflectionEn: json['self_reflection_en'] as String?,
      ahaMessage: json['aha_message'] as String?,
      ahaMessageEn: json['aha_message_en'] as String?,
      practiceAction: json['practice_action'] as String?,
      practiceActionEn: json['practice_action_en'] as String?,
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
    this.themeId,
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

  /// Chủ đề thực hành sinh ra mảnh ký ức này.
  ///
  /// Null với mọi hàng ghi trước 05/08/2026 — lúc đó cột chưa tồn tại. Bộ đếm
  /// thực hành phải chấp nhận cả hai: có `themeId` thì so theo nó (chính xác
  /// tuyệt đối), không có thì lùi về so theo tên chủ đề như cũ để người dùng
  /// không mất tiến độ đã tích luỹ.
  final String? themeId;

  final DateTime? createdAt;

  factory CareerMemoryEvent.fromJson(Map<String, dynamic> json) {
    final rawNeed = (json['human_need'] ?? json['need']) as String?;
    final rawDim = json['sca_dimension'] as String?;
    return CareerMemoryEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      storyId: json['story_id'] as String?,
      situationCode: json['situation_code'] as String?,
      humanNeed: HumanNeed.tryFromDb(rawNeed),
      scaDimension: ScaDimension.tryFromDb(rawDim),
      emotion: json['emotion'] as String?,
      behavior: json['behavior'] as String?,
      intensity: json['intensity'] as int?,
      reflectionText: json['reflection_text'] as String?,
      careerStage: json['career_stage'] as String?,
      themeId: json['theme_id'] as String?,
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
    if (themeId != null) 'theme_id': themeId,
  };
}
