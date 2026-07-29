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
import '../../core/logic/wr_flow_error.dart';
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

/// Cảm xúc vừa chọn ở lưới check-in, giữ nguyên bốn mức của [Mood].
///
/// Vì sao cần tách khỏi [pendingEnergyProvider]: "căng thẳng" và "mệt mỏi" đều
/// là năng lượng thấp, nên `CheckinEnergy.low.toMood()` gộp cả hai thành
/// [Mood.tired]. Nhưng Kiến trúc Dữ liệu v1.6 §III lọc tình huống theo hai cụm
/// chiều KHÁC nhau cho hai cảm xúc đó (A3+C2 với A3+A1). Mất phân biệt ở đây là
/// mất luôn bộ lọc.
final pendingMoodProvider = StateProvider<Mood?>((ref) => null);

/// Một cặp hỏi–đáp người dùng đã đi qua trong Episode.
class ReflectionRecapItem {
  const ReflectionRecapItem({
    required this.pattern,
    required this.prompt,
    required this.answer,
  });

  /// Bước đã sinh ra câu trả lời này — cần để ghi đè khi người dùng sửa.
  final ReflectionPattern pattern;
  final String prompt;
  final String answer;
}

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
  ///
  /// Ghi luôn check-in ngày hôm nay. [mood] là cảm xúc người dùng thực sự chạm
  /// ở lưới check-in; bỏ trống thì suy ra từ [energy] như trước (dùng cho lối
  /// vào không qua lưới, ví dụ mở phiên mới khi đang dở một phiên khác).
  ///
  /// Truyền [mood] vào thay vì luôn suy từ energy là có lý do: `energy.toMood()`
  /// gộp "căng thẳng" và "mệt mỏi" thành [Mood.tired], trong khi v1.6 §III cần
  /// hai cụm chiều khác nhau cho hai cảm xúc này.
  Future<ReflectionEpisode> start({
    required CheckinEnergy energy,
    required HumanMoment moment,
    Mood? mood,
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
          .upsertCheckin(mood ?? energy.toMood(), energy: energy);
      _ref.invalidate(todayCheckinProvider);
    } catch (e, s) {
      // Không chặn luồng, nhưng phải nhìn thấy được ở bản debug.
      logFlowError('upsertCheckin', e, s);
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

  /// Những gì người dùng vừa viết, KÈM câu hỏi đã sinh ra chúng.
  ///
  /// Một câu trả lời tách khỏi câu hỏi của nó thì vô nghĩa: "hôm nay" không
  /// nói lên điều gì nếu không biết nó trả lời cho câu nào. Bước Ý nghĩa phải
  /// đọc lại đủ cặp hỏi–đáp thì người dùng mới rút ra được điều muốn giữ.
  ///
  /// Trả về theo đúng thứ tự đã đi qua của archetype.
  List<ReflectionRecapItem> recap() {
    final ep = state;
    if (ep == null) return const [];
    final sequence =
        patternSequences[ep.humanMoment] ?? const <ReflectionPattern>[];
    final items = <ReflectionRecapItem>[];
    for (final pattern in sequence) {
      final note = ep.notes[pattern.dbValue]?.trim();
      if (note == null || note.isEmpty) continue;
      items.add(ReflectionRecapItem(
        pattern: pattern,
        prompt: promptFor(ep.humanMoment, pattern),
        answer: note,
      ));
    }
    return items;
  }

  /// Sửa lại câu trả lời của một bước đã đi qua.
  ///
  /// WPA Inv.4: không có gì trong một Reflection bị khoá vĩnh viễn. Người dùng
  /// đọc lại rồi thấy mình viết cụt thì phải sửa được ngay tại chỗ, không phải
  /// lùi qua từng màn.
  Future<void> editNote({
    required ReflectionPattern pattern,
    required String note,
  }) async {
    final ep = state;
    if (ep == null || note.trim().isEmpty) return;
    state = await _repo.recordPattern(
      episode: ep,
      pattern: pattern,
      note: note,
    );
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

    // Ý nghĩa đã xác lập mà quay lại bấm lần nữa. Màn Lựa chọn và màn Đóng đều
    // mở bằng push, nên bấm Back là về đúng đây từ bất kỳ chặng nào sau đó —
    // gặp được cả ba state, không riêng meaning_confirmed. Chạy lại chuỗi
    // forming → confirmed lúc này là đâm vào "Transition bất hợp lệ" (WXS §4.4).
    if (ep.state.meaningAlreadySettled) {
      final text = meaning.trim();
      if (ep.state.canReviseMeaningInPlace &&
          text.isNotEmpty &&
          text != ep.draftMeaning?.trim()) {
        // Sửa câu chữ — cập nhật thuần, không đổi trạng thái.
        state = await _repo.reviseMeaning(episode: ep, meaning: text);
      }
      // Còn lại thì KHÔNG ghi gì: không sinh Insight trùng, và không lặng lẽ
      // sửa một phiên đã cam kết hoặc đã vào Career Memory.
      return;
    }

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
    } catch (e, s) {
      // Đúng chỗ đã giấu lỗi 400 `source = 'episode'` suốt từ 2026-07-27:
      // Episode vẫn giữ draft_meaning nên màn hình đi tiếp như không có gì,
      // trong khi bảng Insight rỗng. Best-effort thì được, nhưng phải kêu.
      logFlowError('insertInsight', e, s);
    }

    state = await _repo.confirmMeaning(episode: ep, meaning: meaning);
    _ref.invalidate(wrLatestInsightProvider);
  }

  // -------------------------------------------------------------------------
  // Commit + Integrate
  // -------------------------------------------------------------------------

  /// Lưu bước nhỏ tiếp theo (có thể bỏ qua).
  ///
  /// [choice] là câu người dùng chạm từ Bể Lựa chọn (v1.6 §V · §VI). Người tự
  /// viết thì để null — không có lựa chọn nào được đưa ra để mà chọn.
  Future<void> commit(String action, {String? choice}) async {
    final ep = state;
    if (ep == null) return;

    // Đã cam kết rồi mà quay lại bấm lần nữa. Màn Đóng mở bằng push, nên bấm
    // Back là về đúng đây với Episode ở committed hoặc integrated — cả hai đều
    // không đi được sang committed (WXS §4.4), chạy lại commitAction lúc này là
    // đâm vào "Transition bất hợp lệ". Cùng một cái bẫy như [confirmMeaning].
    if (ep.state.actionAlreadySettled) {
      final text = action.trim();
      final picked = choice?.trim();
      final changed = text != ep.tinyAction?.trim() ||
          _blankToNull(picked) != _blankToNull(ep.reflectChoice);
      if (ep.state.canReviseActionInPlace && text.isNotEmpty && changed) {
        // Đổi câu khi phiên còn mở — cập nhật thuần, không đổi trạng thái.
        state = await _repo.reviseAction(
          episode: ep,
          action: text,
          choice: picked,
        );
      }
      // Còn lại thì KHÔNG ghi gì: không sửa lặng lẽ một phiên đã vào Career
      // Memory, và không ghi đè bằng đúng câu cũ.
      return;
    }

    state = await _repo.commitAction(
      episode: ep,
      action: action,
      choice: choice,
    );
  }

  /// Đóng Episode: ghi Career Memory, pattern count, reflection steps.
  /// WDA Inv.6 — chỉ vào Career Memory sau khi đã có Meaning.
  Future<void> integrate() async {
    final ep = state;
    if (ep == null) return;

    // Không khép được thì DỪNG NGAY, trước khi ghi bất cứ thứ gì.
    //
    // Màn Đóng khép Episode ngay trong initState, nên bấm Back rồi tới lại là
    // chạy hàm này lần hai với state đã là integrated. Trước bản vá này,
    // assertTransition chỉ ném ở dòng cuối — sau khi Career Memory, đếm tình
    // huống và reflection steps đều đã được ghi thêm một lần nữa. Lỗi thì bị
    // màn hình nuốt, còn dữ liệu thì nhân đôi mà không ai thấy.
    //
    // Chặn ở đây cũng giữ luôn WDA Inv.6: state chưa có Meaning thì không
    // canTransition sang integrated, nên không có gì lọt vào Career Memory.
    if (!canTransition(ep.state, ExperienceState.integrated)) return;

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
    } catch (e, s) {
      logFlowError('insertMemoryEvent', e, s);
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
      } catch (e, s) {
        logFlowError('recordSituationOccurrence', e, s);
      }
    }

    // (3) Reflection steps theo Reflection Cycle của WDA §5.3.
    await _insertStep(userId, ReflectionStepType.notice,
        ep.notes[ReflectionPattern.notice.dbValue]);
    await _insertStep(userId, ReflectionStepType.meaning,
        ep.notes[ReflectionPattern.explore.dbValue]);
    await _insertStep(userId, ReflectionStepType.insight, ep.draftMeaning);
    // WDA Inv.9 + §V: Choice là một bước riêng, không phải một phần của Action.
    // Chỉ có dòng này khi người dùng thật sự chọn từ bể; tự viết thì bỏ qua.
    await _insertStep(userId, ReflectionStepType.choice, ep.reflectChoice);
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
      } catch (e, s) {
        logFlowError('makeDormant', e, s);
      }
    }
    state = null;
    _ref.invalidate(wrOpenEpisodeProvider);
  }

  /// Chuỗi rỗng và null là cùng một chuyện: "không có lựa chọn nào".
  static String? _blankToNull(String? value) {
    final text = value?.trim();
    return (text == null || text.isEmpty) ? null : text;
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
    } catch (e, s) {
      logFlowError('insertReflectionStep(${type.dbValue})', e, s);
    }
  }
}
