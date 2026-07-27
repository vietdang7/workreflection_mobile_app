// Episode Flow Controller — điều phối một Reflection Episode qua các màn.
//
// WXS §5 (Experience Orchestration): sản phẩm điều phối Reflection, không điều
// hướng Screen. Controller giữ Episode đang chạy; mỗi màn chỉ đọc state và gọi
// đúng một hành động.
//
// WXS §6.4 (Runtime Persistence): mọi bước đều ghi xuống DB ngay, nên đóng app
// giữa chừng không mất tiến trình.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_content_repository.dart';
import '../../core/data/wr_episode_repository.dart';
import '../../core/data/wr_intelligence_repository.dart';
import '../../core/data/wr_repository.dart';
import '../../core/logic/wr_experience_state.dart';
import '../../core/models/checkin.dart';
import '../../core/models/wr_content.dart';
import '../../core/models/wr_episode.dart';
import '../../core/models/wr_intelligence.dart';
import 'wr_providers.dart';

/// Episode đang được thao tác trong luồng check-in. Null = không có luồng nào.
final episodeFlowProvider =
    StateNotifierProvider<EpisodeFlowController, ReflectionEpisode?>((ref) {
  return EpisodeFlowController(ref);
});

/// Năng lượng vừa chọn ở màn đầu — chưa gắn vào Episode nào cho tới khi người
/// dùng chọn Human Moment.
final pendingEnergyProvider = StateProvider<CheckinEnergy?>((ref) => null);

class EpisodeFlowController extends StateNotifier<ReflectionEpisode?> {
  EpisodeFlowController(this._ref) : super(null);

  final Ref _ref;

  WrEpisodeRepository get _repo => _ref.read(wrEpisodeRepositoryProvider);
  WrIntelligenceRepository get _intel =>
      _ref.read(wrIntelligenceRepositoryProvider);
  WrContentRepository get _content => _ref.read(wrContentRepositoryProvider);

  /// Nạp lại một Episode để đi tiếp (nút "Tiếp tục" ở Home).
  ///
  /// Episode đang ngủ phải được đánh thức trước: Dormant chỉ đi được sang
  /// Reactivated (WXS §4.4). Nếu nạp thẳng vào luồng, bước lưu kế tiếp sẽ đâm
  /// vào một transition bất hợp lệ và người dùng chỉ thấy "Không lưu được".
  Future<ReflectionEpisode> resume(ReflectionEpisode episode) async {
    final woken = await reopen(episode);
    state = woken ?? episode;
    return state!;
  }

  /// Rời luồng mà không đóng Episode — Episode vẫn mở, Home mời quay lại.
  void leave() => state = null;

  /// Mở lại một Episode đã khép hoặc đang ngủ để hiểu lại nó.
  ///
  /// WPA Inv.4 / WXS Inv.7: Reflection luôn có thể mở lại, không có trạng thái
  /// khóa vĩnh viễn. Reactivated luôn quay về Exploring (WXS §4.3 State 9),
  /// nên chuỗi Pattern được tiếp tục chứ không bắt đầu lại từ đầu.
  Future<ReflectionEpisode?> reopen(ReflectionEpisode episode) async {
    if (!canTransition(episode.state, ExperienceState.reactivated)) {
      return null;
    }
    final reopened = await _repo.reactivate(episode);
    state = reopened;
    _ref.invalidate(wrOpenEpisodeProvider);
    _ref.invalidate(wrEpisodeHistoryProvider);
    return reopened;
  }

  // -------------------------------------------------------------------------
  // Capture
  // -------------------------------------------------------------------------

  /// Mở Episode mới sau khi người dùng chọn năng lượng + Human Moment.
  /// Ghi luôn check-in ngày hôm nay (mood suy ra từ energy — cột mood NOT NULL).
  Future<ReflectionEpisode> start({
    required CheckinEnergy energy,
    required HumanMoment moment,
  }) async {
    final userId = _ref.read(currentUserIdProvider) ?? '';
    final episode = await _repo.openEpisode(
      ReflectionEpisode(
        userId: userId,
        humanMoment: moment,
        state: ExperienceState.captured,
        energy: energy,
        humanNeed: moment.relatedNeed,
        intention: moment.tension,
      ),
    );
    state = episode;

    // Check-in ngày — best-effort, không chặn luồng phản tư.
    try {
      await _ref
          .read(wrRepositoryProvider)
          .upsertCheckin(energy.toMood(), energy: energy);
      _ref.invalidate(todayCheckinProvider);
    } catch (_) {
      /* nuốt lỗi: check-in không phải mục đích chính của Episode */
    }

    return episode;
  }

  // -------------------------------------------------------------------------
  // Exploring
  // -------------------------------------------------------------------------

  /// Pattern kế tiếp cần đi qua. Null = đã đủ, sang bước Ý nghĩa.
  ReflectionPattern? get currentPattern {
    final ep = state;
    if (ep == null) return null;
    return nextPattern(ep.humanMoment, ep.patternsDone);
  }

  /// Ghi lại một bước phản tư: ghi chú tự viết hoặc tình huống đã chọn.
  Future<void> submitStep({
    required ReflectionPattern pattern,
    String? note,
    WrSituation? situation,
  }) async {
    final ep = state;
    if (ep == null) return;

    // [situation] gắn thêm ngữ cảnh tình huống — nguồn cho Pattern Intelligence.
    state = await _repo.recordPattern(
      episode: ep,
      pattern: pattern,
      note: note ?? situation?.text,
      situation: situation,
    );
  }

  // -------------------------------------------------------------------------
  // Meaning
  // -------------------------------------------------------------------------

  /// Câu tóm lược hệ thống đề xuất — WIA: chỉ Propose, không Confirm.
  /// Lấy ghi chú sâu nhất người dùng đã viết, không thêm diễn giải.
  String proposedMeaning() {
    final ep = state;
    if (ep == null) return '';
    const priority = [
      ReflectionPattern.reframe,
      ReflectionPattern.explore,
      ReflectionPattern.name,
      ReflectionPattern.notice,
      ReflectionPattern.preserve,
    ];
    for (final p in priority) {
      final note = ep.notes[p.dbValue];
      if (note != null && note.trim().isNotEmpty) return note.trim();
    }
    return '';
  }

  /// Lưu bản nháp ý nghĩa — chưa vào Career Memory.
  Future<void> saveDraft(String meaning) async {
    final ep = state;
    if (ep == null) return;
    state = await _repo.saveDraftMeaning(episode: ep, meaning: meaning);
  }

  /// Người dùng xác nhận ý nghĩa. Chỉ ở đây Insight mới được tạo.
  Future<void> confirmMeaning(String meaning) async {
    var ep = state;
    if (ep == null) return;
    if (ep.state != ExperienceState.meaningForming) {
      ep = await _repo.saveDraftMeaning(episode: ep, meaning: meaning);
    }

    final userId = ep.userId;
    // insertInsight không trả id — Episode vẫn truy vết được qua draft_meaning
    // và memory event, nên confirmed_insight_id để trống ở bản này.
    try {
      await _intel.insertInsight(WrInsight(
        userId: userId,
        source: 'episode',
        scaDimension: ep.scaDimension,
        humanNeed: ep.humanNeed,
        content: meaning.trim(),
      ));
    } catch (_) {
      /* best-effort: Episode vẫn giữ draft_meaning */
    }

    state = await _repo.confirmMeaning(episode: ep, meaning: meaning);
    _ref.invalidate(wrLatestInsightProvider);
  }

  // -------------------------------------------------------------------------
  // Commit + Integrate
  // -------------------------------------------------------------------------

  /// Lưu bước nhỏ tiếp theo (có thể bỏ qua).
  Future<void> commit(String action) async {
    final ep = state;
    if (ep == null) return;
    state = await _repo.commitAction(episode: ep, action: action);
  }

  /// Đóng Episode: ghi Career Memory, pattern count, reflection steps.
  /// WDA Inv.6 — chỉ vào Career Memory sau khi đã có Meaning.
  Future<void> integrate() async {
    final ep = state;
    if (ep == null) return;
    final userId = ep.userId;

    // (1) Career Memory Event — nội dung là Meaning, không phải ghi chú thô.
    try {
      await _content.insertMemoryEvent(CareerMemoryEvent(
        id: '',
        userId: userId,
        situationCode: ep.situationCode,
        humanNeed: ep.humanNeed,
        scaDimension: ep.scaDimension,
        emotion: ep.energy?.dbValue,
        behavior: 'reflection_episode',
        reflectionText: ep.draftMeaning,
      ));
    } catch (_) {
      /* best-effort */
    }

    // (2) Đếm tình huống lặp lại — nguồn cho tab Hiểu mình.
    final code = ep.situationCode;
    final dim = ep.scaDimension;
    if (code != null && dim != null) {
      try {
        await _intel.recordSituationOccurrence(
          userId: userId,
          situationCode: code,
          scaDimensionDb: dim.dbValue,
        );
      } catch (_) {
        /* best-effort */
      }
    }

    // (3) Reflection steps theo Reflection Cycle của WDA §5.3.
    await _insertStep(userId, ReflectionStepType.notice,
        ep.notes[ReflectionPattern.notice.dbValue]);
    await _insertStep(userId, ReflectionStepType.meaning,
        ep.notes[ReflectionPattern.explore.dbValue]);
    await _insertStep(userId, ReflectionStepType.insight, ep.draftMeaning);
    await _insertStep(userId, ReflectionStepType.action, ep.tinyAction);

    state = await _repo.integrate(episode: ep);

    _ref.invalidate(wrPatternCountsProvider);
    _ref.invalidate(wrOpenEpisodeProvider);
    _ref.invalidate(wrEpisodeHistoryProvider);
  }

  /// Tạm dừng Episode — giữ nguyên tiến trình (WXS §4.5).
  Future<void> pause() async {
    final ep = state;
    if (ep == null) return;
    if (canTransition(ep.state, ExperienceState.dormant)) {
      try {
        await _repo.makeDormant(ep);
      } catch (_) {
        /* best-effort */
      }
    }
    state = null;
    _ref.invalidate(wrOpenEpisodeProvider);
  }

  Future<void> _insertStep(
    String userId,
    ReflectionStepType type,
    String? content,
  ) async {
    if (content == null || content.trim().isEmpty) return;
    try {
      await _intel.insertReflectionStep(ReflectionStep(
        userId: userId,
        step: type,
        content: content.trim(),
      ));
    } catch (_) {
      /* best-effort */
    }
  }
}
