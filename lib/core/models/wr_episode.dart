// Reflection Episode — WXS v1.0 Chương 4 + HXA v1.0 Chương 2 & 3.
// Plain immutable classes + fromJson/toInsert, mirroring wr_intelligence.dart.
// No Flutter dependencies.
//
// Một Episode là đơn vị ý nghĩa cơ bản của trải nghiệm (WXS §1.6), không phải
// một màn hình. Nó có thể kéo dài qua nhiều màn, nhiều phiên, nhiều ngày.

import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

// ---------------------------------------------------------------------------
// HumanMoment — HXA §2.5, sáu Archetype. Không được thêm giá trị thứ bảy.
// ---------------------------------------------------------------------------

enum HumanMoment {
  arrival,
  confusion,
  decision,
  growth,
  recovery,
  celebration;

  String get dbValue => name;

  static HumanMoment fromDb(String value) => switch (value) {
        'arrival' => HumanMoment.arrival,
        'confusion' => HumanMoment.confusion,
        'decision' => HumanMoment.decision,
        'growth' => HumanMoment.growth,
        'recovery' => HumanMoment.recovery,
        'celebration' => HumanMoment.celebration,
        _ => throw ArgumentError('Unknown HumanMoment db value: $value'),
      };

  /// Nhãn hiển thị trên thẻ chọn khoảnh khắc.
  String get label => switch (this) {
        HumanMoment.arrival => 'Muốn dừng lại một chút',
        HumanMoment.confusion => 'Có gì đó chưa ổn',
        HumanMoment.decision => 'Đang phải chọn',
        HumanMoment.growth => 'Muốn tiến bộ hơn',
        HumanMoment.recovery => 'Vừa mất năng lượng',
        HumanMoment.celebration => 'Vừa làm được điều hay',
      };

  /// Reflection Tension — HXA §2.5, câu hỏi nội tâm của archetype.
  String get tension => switch (this) {
        HumanMoment.arrival => 'Điều gì đang diễn ra trong mình lúc này?',
        HumanMoment.confusion => 'Điều gì mình chưa nhìn thấy?',
        HumanMoment.decision => 'Giá trị nào đang dẫn dắt lựa chọn này?',
        HumanMoment.growth => 'Điều gì giúp phiên bản tiếp theo của mình hình thành?',
        HumanMoment.recovery => 'Điều gì đang cần được lắng nghe?',
        HumanMoment.celebration => 'Điều gì mình muốn giữ lại từ trải nghiệm này?',
      };

  /// Human Need mà archetype này thường chạm tới — dùng để lọc gợi ý.
  HumanNeed get relatedNeed => switch (this) {
        HumanMoment.arrival => HumanNeed.roRang,
        HumanMoment.confusion => HumanNeed.roRang,
        HumanMoment.decision => HumanNeed.roRang,
        HumanMoment.growth => HumanNeed.phatTrien,
        HumanMoment.recovery => HumanNeed.ketNoi,
        HumanMoment.celebration => HumanNeed.phatTrien,
      };
}

// ---------------------------------------------------------------------------
// ReflectionPattern — HXA §3.5, sáu Pattern. Người dùng KHÔNG chọn theo tên
// (HXA Invariant 5) — hệ thống suy ra từ Human Moment và bước đã đi qua.
// ---------------------------------------------------------------------------

enum ReflectionPattern {
  notice,
  name,
  explore,
  reframe,
  commit,
  preserve;

  // Không dùng `name` của enum ở đây: giá trị `ReflectionPattern.name` che mất
  // getter tổng hợp, nên phải liệt kê tường minh.
  String get dbValue => switch (this) {
        ReflectionPattern.notice => 'notice',
        ReflectionPattern.name => 'name',
        ReflectionPattern.explore => 'explore',
        ReflectionPattern.reframe => 'reframe',
        ReflectionPattern.commit => 'commit',
        ReflectionPattern.preserve => 'preserve',
      };

  static ReflectionPattern fromDb(String value) => switch (value) {
        'notice' => ReflectionPattern.notice,
        'name' => ReflectionPattern.name,
        'explore' => ReflectionPattern.explore,
        'reframe' => ReflectionPattern.reframe,
        'commit' => ReflectionPattern.commit,
        'preserve' => ReflectionPattern.preserve,
        _ => throw ArgumentError('Unknown ReflectionPattern db value: $value'),
      };
}

// ---------------------------------------------------------------------------
// ExperienceState — WXS §4.2, chín trạng thái nhận thức.
// Đây là trạng thái của con người, không phải trạng thái giao diện.
// ---------------------------------------------------------------------------

enum ExperienceState {
  emerging,
  captured,
  exploring,
  meaningForming,
  meaningConfirmed,
  committed,
  integrated,
  dormant,
  reactivated;

  String get dbValue => switch (this) {
        ExperienceState.emerging => 'emerging',
        ExperienceState.captured => 'captured',
        ExperienceState.exploring => 'exploring',
        ExperienceState.meaningForming => 'meaning_forming',
        ExperienceState.meaningConfirmed => 'meaning_confirmed',
        ExperienceState.committed => 'committed',
        ExperienceState.integrated => 'integrated',
        ExperienceState.dormant => 'dormant',
        ExperienceState.reactivated => 'reactivated',
      };

  static ExperienceState fromDb(String value) => switch (value) {
        'emerging' => ExperienceState.emerging,
        'captured' => ExperienceState.captured,
        'exploring' => ExperienceState.exploring,
        'meaning_forming' => ExperienceState.meaningForming,
        'meaning_confirmed' => ExperienceState.meaningConfirmed,
        'committed' => ExperienceState.committed,
        'integrated' => ExperienceState.integrated,
        'dormant' => ExperienceState.dormant,
        'reactivated' => ExperienceState.reactivated,
        _ => throw ArgumentError('Unknown ExperienceState db value: $value'),
      };

  /// Episode còn đang mở — Home mời người dùng tiếp tục.
  bool get isOpen => switch (this) {
        ExperienceState.integrated || ExperienceState.dormant => false,
        _ => true,
      };
}

// ---------------------------------------------------------------------------
// ReflectionEpisode — maps to public.wr_reflection_episodes.
// ---------------------------------------------------------------------------

class ReflectionEpisode {
  const ReflectionEpisode({
    required this.userId,
    required this.humanMoment,
    this.id,
    this.state = ExperienceState.captured,
    this.energy,
    this.situationCode,
    this.scaDimension,
    this.humanNeed,
    this.intention,
    this.patternsDone = const [],
    this.notes = const {},
    this.draftMeaning,
    this.confirmedInsightId,
    this.tinyAction,
    this.themeId,
    this.memoryEventId,
    this.openedAt,
    this.updatedAt,
    this.closedAt,
  });

  final String? id;
  final String userId;
  final HumanMoment humanMoment;
  final ExperienceState state;
  final CheckinEnergy? energy;
  final String? situationCode;
  final ScaDimension? scaDimension;
  final HumanNeed? humanNeed;
  final String? intention;

  /// Các Pattern đã đi qua, theo thứ tự.
  final List<ReflectionPattern> patternsDone;

  /// Ghi chú người dùng tự viết, khoá là dbValue của Pattern.
  final Map<String, String> notes;

  final String? draftMeaning;
  final String? confirmedInsightId;
  final String? tinyAction;
  final String? themeId;
  final String? memoryEventId;
  final DateTime? openedAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;

  factory ReflectionEpisode.fromJson(Map<String, dynamic> json) {
    final rawPatterns = json['patterns_done'];
    final rawNotes = json['notes'];
    final rawDim = json['sca_dimension'] as String?;
    final rawNeed = json['human_need'] as String?;
    final rawEnergy = json['energy'] as String?;
    return ReflectionEpisode(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      humanMoment: HumanMoment.fromDb(json['human_moment'] as String),
      state: ExperienceState.fromDb(json['state'] as String),
      energy: rawEnergy != null ? CheckinEnergy.fromDb(rawEnergy) : null,
      situationCode: json['situation_code'] as String?,
      scaDimension: rawDim != null ? ScaDimension.fromDb(rawDim) : null,
      humanNeed: rawNeed != null ? HumanNeed.fromDb(rawNeed) : null,
      intention: json['intention'] as String?,
      patternsDone: rawPatterns is List
          ? rawPatterns
              .cast<String>()
              .map(ReflectionPattern.fromDb)
              .toList(growable: false)
          : const [],
      notes: rawNotes is Map
          ? rawNotes.map((k, v) => MapEntry(k as String, v?.toString() ?? ''))
          : const {},
      draftMeaning: json['draft_meaning'] as String?,
      confirmedInsightId: json['confirmed_insight_id'] as String?,
      tinyAction: json['tiny_action'] as String?,
      themeId: json['theme_id'] as String?,
      memoryEventId: json['memory_event_id'] as String?,
      openedAt: json['opened_at'] != null
          ? DateTime.parse(json['opened_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
    );
  }

  /// Map cho INSERT — bỏ các trường server sinh (id, opened_at, updated_at).
  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'human_moment': humanMoment.dbValue,
        'state': state.dbValue,
        if (energy != null) 'energy': energy!.dbValue,
        if (situationCode != null) 'situation_code': situationCode,
        if (scaDimension != null) 'sca_dimension': scaDimension!.dbValue,
        if (humanNeed != null) 'human_need': humanNeed!.dbValue,
        if (intention != null) 'intention': intention,
        'patterns_done': patternsDone.map((p) => p.dbValue).toList(),
        'notes': notes,
      };

  ReflectionEpisode copyWith({
    String? id,
    ExperienceState? state,
    CheckinEnergy? energy,
    String? situationCode,
    ScaDimension? scaDimension,
    HumanNeed? humanNeed,
    String? intention,
    List<ReflectionPattern>? patternsDone,
    Map<String, String>? notes,
    String? draftMeaning,
    String? confirmedInsightId,
    String? tinyAction,
    String? themeId,
    String? memoryEventId,
    DateTime? closedAt,
  }) {
    return ReflectionEpisode(
      id: id ?? this.id,
      userId: userId,
      humanMoment: humanMoment,
      state: state ?? this.state,
      energy: energy ?? this.energy,
      situationCode: situationCode ?? this.situationCode,
      scaDimension: scaDimension ?? this.scaDimension,
      humanNeed: humanNeed ?? this.humanNeed,
      intention: intention ?? this.intention,
      patternsDone: patternsDone ?? this.patternsDone,
      notes: notes ?? this.notes,
      draftMeaning: draftMeaning ?? this.draftMeaning,
      confirmedInsightId: confirmedInsightId ?? this.confirmedInsightId,
      tinyAction: tinyAction ?? this.tinyAction,
      themeId: themeId ?? this.themeId,
      memoryEventId: memoryEventId ?? this.memoryEventId,
      openedAt: openedAt,
      updatedAt: updatedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}
