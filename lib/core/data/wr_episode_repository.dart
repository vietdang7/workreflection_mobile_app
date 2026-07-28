// Reflection Episode repository — WXS v1.0 Chương 4 & 6.
// Abstract interface + Supabase implementation + Riverpod provider.
// Supabase queries live ONLY here.
//
// Repository là nơi cuối cùng chặn transition bất hợp lệ (WXS §4.4). UI có thể
// sai, state machine ở đây thì không được sai.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/wr_experience_state.dart';
import '../models/wr_content.dart';
import '../models/wr_episode.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class WrEpisodeRepository {
  /// Episode đang mở gần nhất của [userId] — dùng để resume (WXS §4.5).
  /// Trả về null khi không còn Episode nào đang mở.
  Future<ReflectionEpisode?> fetchOpenEpisode(String userId);

  /// Đọc một Episode theo id.
  Future<ReflectionEpisode?> fetchEpisode(String episodeId);

  /// Lịch sử Episode, mới nhất trước.
  Future<List<ReflectionEpisode>> fetchEpisodes(String userId, {int? limit});

  /// Mở một Episode mới ở state Captured. Trả về Episode đã có id.
  Future<ReflectionEpisode> openEpisode(ReflectionEpisode episode);

  /// Ghi một bước phản tư: thêm pattern vào patterns_done, lưu ghi chú.
  /// Tự chuyển Captured → Exploring ở bước đầu tiên.
  /// [situation] gắn thêm ngữ cảnh tình huống nếu bước này là chọn tình huống.
  Future<ReflectionEpisode> recordPattern({
    required ReflectionEpisode episode,
    required ReflectionPattern pattern,
    String? note,
    WrSituation? situation,
  });

  /// Lưu Draft Meaning — chưa vào Career Memory (WXS §4.3 State 4).
  Future<ReflectionEpisode> saveDraftMeaning({
    required ReflectionEpisode episode,
    required String meaning,
  });

  /// Người dùng xác nhận Meaning (WXS Inv.3 — AI không được làm thay).
  Future<ReflectionEpisode> confirmMeaning({
    required ReflectionEpisode episode,
    required String meaning,
    String? insightId,
  });

  /// Lưu Tiny Next Step (HXA Pattern Commit).
  /// [choice] là câu người dùng chọn từ Bể Lựa chọn (v1.6 §V · §VI); null khi
  /// họ tự viết. [action] là điều họ cam kết làm, luôn có.
  Future<ReflectionEpisode> commitAction({
    required ReflectionEpisode episode,
    required String action,
    String? choice,
  });

  /// Đóng Episode: đưa vào Career Memory (WXS §4.3 State 7).
  Future<ReflectionEpisode> integrate({
    required ReflectionEpisode episode,
    String? memoryEventId,
  });

  /// Tạm dừng — Episode ngủ, không mất (WXS §4.5).
  Future<ReflectionEpisode> makeDormant(ReflectionEpisode episode);

  /// Mở lại một Episode cũ để diễn giải lại (Backward Flow, WXS §3.5).
  Future<ReflectionEpisode> reactivate(ReflectionEpisode episode);
}

// ---------------------------------------------------------------------------
// Riverpod provider (overridable in tests)
// ---------------------------------------------------------------------------

final wrEpisodeRepositoryProvider = Provider<WrEpisodeRepository>((ref) {
  return SupabaseWrEpisodeRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Live Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseWrEpisodeRepository implements WrEpisodeRepository {
  const SupabaseWrEpisodeRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'wr_reflection_episodes';

  /// Các state còn quay lại tiếp được — khớp [ExperienceState.isResumable].
  static final List<String> _openStates = ExperienceState.values
      .where((s) => s.isResumable)
      .map((s) => s.dbValue)
      .toList(growable: false);

  @override
  Future<ReflectionEpisode?> fetchOpenEpisode(String userId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .inFilter('state', _openStates)
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return ReflectionEpisode.fromJson(rows.first);
  }

  @override
  Future<ReflectionEpisode?> fetchEpisode(String episodeId) async {
    final row =
        await _client.from(_table).select().eq('id', episodeId).maybeSingle();
    if (row == null) return null;
    return ReflectionEpisode.fromJson(row);
  }

  @override
  Future<List<ReflectionEpisode>> fetchEpisodes(
    String userId, {
    int? limit,
  }) async {
    var query = _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('opened_at', ascending: false);
    if (limit != null) query = query.limit(limit);
    final rows = await query;
    return rows.map(ReflectionEpisode.fromJson).toList();
  }

  @override
  Future<ReflectionEpisode> openEpisode(ReflectionEpisode episode) async {
    final row =
        await _client.from(_table).insert(episode.toInsert()).select().single();
    return ReflectionEpisode.fromJson(row);
  }

  @override
  Future<ReflectionEpisode> recordPattern({
    required ReflectionEpisode episode,
    required ReflectionPattern pattern,
    String? note,
    WrSituation? situation,
  }) async {
    // Bước phản tư đầu tiên đưa Episode từ Captured sang Exploring.
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
    if (note != null && note.trim().isNotEmpty) {
      notes[pattern.dbValue] = note.trim();
    }

    return _patch(episode, {
      'state': nextState.dbValue,
      'patterns_done': patterns.map((p) => p.dbValue).toList(),
      'notes': notes,
      if (situation != null) ...{
        'situation_code': situation.code,
        'sca_dimension': situation.scaDimension.dbValue,
        if (situation.humanNeed != null)
          'human_need': situation.humanNeed!.dbValue,
      },
    });
  }

  @override
  Future<ReflectionEpisode> saveDraftMeaning({
    required ReflectionEpisode episode,
    required String meaning,
  }) async {
    // Episode vừa được mở lại đi qua Exploring trước (WXS §4.3 State 9) —
    // hai chặng đều hợp lệ, không phải nhảy cóc.
    var from = episode.state;
    if (from == ExperienceState.reactivated) {
      assertTransition(from, ExperienceState.exploring);
      from = ExperienceState.exploring;
    }
    if (from != ExperienceState.meaningForming) {
      assertTransition(from, ExperienceState.meaningForming);
    }
    return _patch(episode, {
      'state': ExperienceState.meaningForming.dbValue,
      'draft_meaning': meaning.trim(),
    });
  }

  @override
  Future<ReflectionEpisode> confirmMeaning({
    required ReflectionEpisode episode,
    required String meaning,
    String? insightId,
  }) async {
    assertTransition(episode.state, ExperienceState.meaningConfirmed);
    return _patch(episode, {
      'state': ExperienceState.meaningConfirmed.dbValue,
      'draft_meaning': meaning.trim(),
      if (insightId != null) 'confirmed_insight_id': insightId,
    });
  }

  @override
  Future<ReflectionEpisode> commitAction({
    required ReflectionEpisode episode,
    required String action,
    String? choice,
  }) async {
    assertTransition(episode.state, ExperienceState.committed);
    final picked = choice?.trim();
    return _patch(episode, {
      'state': ExperienceState.committed.dbValue,
      'tiny_action': action.trim(),
      // Chỉ ghi khi thật sự có lựa chọn được chọn. Người tự viết thì để null
      // chứ không chép lại tiny_action — làm vậy là biến một câu tự viết thành
      // "đã chọn từ bể", tức bịa ra dữ liệu chưa từng xảy ra.
      if (picked != null && picked.isNotEmpty) 'reflect_choice': picked,
    });
  }

  @override
  Future<ReflectionEpisode> integrate({
    required ReflectionEpisode episode,
    String? memoryEventId,
  }) async {
    assertTransition(episode.state, ExperienceState.integrated);
    return _patch(episode, {
      'state': ExperienceState.integrated.dbValue,
      if (memoryEventId != null) 'memory_event_id': memoryEventId,
      'closed_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<ReflectionEpisode> makeDormant(ReflectionEpisode episode) async {
    assertTransition(episode.state, ExperienceState.dormant);
    return _patch(episode, {'state': ExperienceState.dormant.dbValue});
  }

  @override
  Future<ReflectionEpisode> reactivate(ReflectionEpisode episode) async {
    assertTransition(episode.state, ExperienceState.reactivated);
    return _patch(episode, {
      'state': ExperienceState.reactivated.dbValue,
      'closed_at': null,
    });
  }

  // -------------------------------------------------------------------------

  Future<ReflectionEpisode> _patch(
    ReflectionEpisode episode,
    Map<String, dynamic> values,
  ) async {
    final id = episode.id;
    if (id == null) {
      throw StateError('Episode chưa có id — gọi openEpisode trước.');
    }
    final row = await _client
        .from(_table)
        .update({...values, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return ReflectionEpisode.fromJson(row);
  }
}
