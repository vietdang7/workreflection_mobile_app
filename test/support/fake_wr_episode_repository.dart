import 'package:workreflection_mobile/core/data/wr_episode_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_experience_state.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';

import 'fake_wr_intelligence_repository.dart' show kAllowedScaDimensions;

/// In-memory fake WrEpisodeRepository cho unit/widget test.
///
/// Giữ nguyên luật state machine như bản thật: mọi transition đều đi qua
/// [assertTransition], nên test sẽ bắt được nếu UI cố nhảy cóc.
class FakeWrEpisodeRepository implements WrEpisodeRepository {
  final List<ReflectionEpisode> episodes = [];

  Object? nextError;
  int _seq = 0;

  final List<ReflectionEpisode> openEpisodeCalls = [];
  final List<ReflectionEpisode> integrateCalls = [];
  final List<ReflectionEpisode> confirmMeaningCalls = [];
  final List<ReflectionEpisode> reviseMeaningCalls = [];
  final List<ReflectionEpisode> commitActionCalls = [];
  final List<ReflectionEpisode> reviseActionCalls = [];
  final List<ReflectionEpisode> dormantCalls = [];

  void seed(List<ReflectionEpisode> seeded) {
    episodes
      ..clear()
      ..addAll(seeded);
  }

  void _maybeThrow() {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
  }

  ReflectionEpisode _store(ReflectionEpisode episode) {
    _assertEpisodeConstraints(episode);
    final idx = episodes.indexWhere((e) => e.id == episode.id);
    if (idx >= 0) {
      episodes[idx] = episode;
    } else {
      episodes.add(episode);
    }
    return episode;
  }

  @override
  Future<ReflectionEpisode?> fetchOpenEpisode(String userId) async {
    _maybeThrow();
    for (final e in episodes.reversed) {
      if (e.userId == userId && e.state.isResumable) return e;
    }
    return null;
  }

  @override
  Future<ReflectionEpisode?> fetchEpisode(String episodeId) async {
    _maybeThrow();
    for (final e in episodes) {
      if (e.id == episodeId) return e;
    }
    return null;
  }

  @override
  Future<List<ReflectionEpisode>> fetchEpisodes(
    String userId, {
    int? limit,
  }) async {
    _maybeThrow();
    final mine = episodes.where((e) => e.userId == userId).toList().reversed;
    final list = mine.toList();
    return limit == null ? list : list.take(limit).toList();
  }

  @override
  Future<ReflectionEpisode> openEpisode(ReflectionEpisode episode) async {
    _maybeThrow();
    openEpisodeCalls.add(episode);
    final withId = episode.copyWith(id: 'ep${++_seq}');
    return _store(withId);
  }

  @override
  Future<ReflectionEpisode> recordPattern({
    required ReflectionEpisode episode,
    required ReflectionPattern pattern,
    String? note,
    WrSituation? situation,
  }) async {
    _maybeThrow();
    final nextState = episode.state == ExperienceState.captured ||
            episode.state == ExperienceState.reactivated
        ? ExperienceState.exploring
        : episode.state;
    if (nextState != episode.state) {
      assertTransition(episode.state, nextState);
    }

    final patterns = episode.patternsDone.contains(pattern)
        ? episode.patternsDone
        : [...episode.patternsDone, pattern];
    final notes = {...episode.notes};
    final text = note ?? situation?.text;
    if (text != null && text.trim().isNotEmpty) {
      notes[pattern.dbValue] = text.trim();
    }

    return _store(episode.copyWith(
      state: nextState,
      patternsDone: patterns,
      notes: notes,
      situationCode: situation?.code,
      scaDimension: situation?.scaDimension,
      humanNeed: situation?.humanNeed,
    ));
  }

  @override
  Future<ReflectionEpisode> saveDraftMeaning({
    required ReflectionEpisode episode,
    required String meaning,
  }) async {
    _maybeThrow();
    var from = episode.state;
    if (from == ExperienceState.reactivated) {
      assertTransition(from, ExperienceState.exploring);
      from = ExperienceState.exploring;
    }
    if (from != ExperienceState.meaningForming) {
      assertTransition(from, ExperienceState.meaningForming);
    }
    return _store(episode.copyWith(
      state: ExperienceState.meaningForming,
      draftMeaning: meaning.trim(),
    ));
  }

  @override
  Future<ReflectionEpisode> confirmMeaning({
    required ReflectionEpisode episode,
    required String meaning,
    String? insightId,
  }) async {
    _maybeThrow();
    assertTransition(episode.state, ExperienceState.meaningConfirmed);
    confirmMeaningCalls.add(episode);
    return _store(episode.copyWith(
      state: ExperienceState.meaningConfirmed,
      draftMeaning: meaning.trim(),
      confirmedInsightId: insightId,
    ));
  }

  @override
  Future<ReflectionEpisode> reviseMeaning({
    required ReflectionEpisode episode,
    required String meaning,
  }) async {
    _maybeThrow();
    reviseMeaningCalls.add(episode);
    // Không assertTransition: sửa câu chữ không đổi trạng thái nào.
    return _store(episode.copyWith(draftMeaning: meaning.trim()));
  }

  @override
  Future<ReflectionEpisode> commitAction({
    required ReflectionEpisode episode,
    required String action,
    String? choice,
  }) async {
    _maybeThrow();
    assertTransition(episode.state, ExperienceState.committed);
    commitActionCalls.add(episode);
    final picked = choice?.trim();
    return _store(episode.copyWith(
      state: ExperienceState.committed,
      tinyAction: action.trim(),
      reflectChoice: picked != null && picked.isNotEmpty ? picked : null,
    ));
  }

  @override
  Future<ReflectionEpisode> reviseAction({
    required ReflectionEpisode episode,
    required String action,
    String? choice,
  }) async {
    _maybeThrow();
    reviseActionCalls.add(episode);
    // Không assertTransition: đổi câu không đổi trạng thái nào.
    final picked = choice?.trim();
    final hasPick = picked != null && picked.isNotEmpty;
    return _store(episode.copyWith(
      tinyAction: action.trim(),
      reflectChoice: hasPick ? picked : null,
      clearReflectChoice: !hasPick,
    ));
  }

  @override
  Future<ReflectionEpisode> integrate({
    required ReflectionEpisode episode,
    String? memoryEventId,
  }) async {
    _maybeThrow();
    assertTransition(episode.state, ExperienceState.integrated);
    integrateCalls.add(episode);
    return _store(episode.copyWith(
      state: ExperienceState.integrated,
      memoryEventId: memoryEventId,
      closedAt: DateTime(2026, 7, 27),
    ));
  }

  @override
  Future<ReflectionEpisode> makeDormant(ReflectionEpisode episode) async {
    _maybeThrow();
    assertTransition(episode.state, ExperienceState.dormant);
    dormantCalls.add(episode);
    return _store(episode.copyWith(state: ExperienceState.dormant));
  }

  @override
  Future<ReflectionEpisode> reactivate(ReflectionEpisode episode) async {
    _maybeThrow();
    assertTransition(episode.state, ExperienceState.reactivated);
    return _store(episode.copyWith(state: ExperienceState.reactivated));
  }
}

/// Ném khi Episode vi phạm check constraint của `wr_reflection_episodes`.
///
/// Cùng lý do với [FakeWrIntelligenceRepository]: bảng Episode ghi
/// `sca_dimension` của tình huống vừa chọn ở MỌI vòng phản tư, nên nếu constraint
/// DB hẹp hơn enum Dart thì nhánh tình huống tích cực vỡ mà không test nào thấy.
void _assertEpisodeConstraints(ReflectionEpisode e) {
  final dim = e.scaDimension?.dbValue;
  if (dim != null && !kAllowedScaDimensions.contains(dim)) {
    throw StateError(
      'wr_reflection_episodes_sca_dimension_check: "$dim" không nằm trong '
      '$kAllowedScaDimensions',
    );
  }
}
