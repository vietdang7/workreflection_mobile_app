// WR Content repository — WR Data Foundation Sprint 0 (Task 4).
// Abstract interface + SupabaseWrContentRepository + Riverpod provider.
// Supabase queries live ONLY here. Screens consume via wrContentRepositoryProvider.
//
// DECISION: wave filter for fetchStories is NOT implemented.
// Rationale: wr_stories has no `wave` column — wave lives on wr_situations.
// Filtering stories by wave would require a JOIN or a two-step query (fetch
// situation codes for that wave, then filter stories by sca_dimension proxy).
// Since the relationship is dimension-level (not story-level), filtering by
// ScaDimension already gives wave-aligned results in practice.
// If wave-level story filtering is needed in the future, add a `wave` column
// to wr_stories or use a DB view.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'wr_canonical_catalog.dart';
import '../models/wr_content.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class WrContentRepository {
  /// Fetches all situations, optionally filtered by [dimension].
  Future<List<WrSituation>> fetchSituations({ScaDimension? dimension});

  /// Fetches all stories, optionally filtered by [dimension].
  ///
  /// NOTE: wave-based filtering is not supported — see file-level comment.
  Future<List<WrStory>> fetchStories({ScaDimension? dimension});

  /// Fetches a single story by [id]. Returns null if not found.
  Future<WrStory?> fetchStory(String id);

  /// Inserts a new career memory event. Uses [event.toInsert()] to build
  /// the payload (excludes id/created_at).
  Future<void> insertMemoryEvent(CareerMemoryEvent event);

  /// Fetches the current user's career memory events, newest first.
  /// [limit] defaults to 50.
  Future<List<CareerMemoryEvent>> fetchMemoryEvents({int limit = 50});

  /// Fetch memory events for a specific [userId] — for UI layers that
  /// pass userId explicitly (e.g. Journey screen via Riverpod provider).
  Future<List<CareerMemoryEvent>> fetchMemoryEventsForUser(
    String userId, {
    int? limit,
  });

  /// Delete all career memory events for [userId] and [situationCode] that
  /// fall on the same Vietnam-local date as [day].
  /// Dùng khi người dùng đổi tình huống trong cùng một ngày.
  Future<void> deleteTodayMemoryEventsForSituation({
    required String userId,
    required String situationCode,
    required DateTime day,
  });
}

// ---------------------------------------------------------------------------
// Riverpod provider (overridable in tests)
// ---------------------------------------------------------------------------

final wrContentRepositoryProvider = Provider<WrContentRepository>((ref) {
  return SupabaseWrContentRepository(Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Live Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseWrContentRepository implements WrContentRepository {
  SupabaseWrContentRepository(
    this._client, {
    WrCanonicalCatalogLoader? catalogLoader,
  }) : _catalogLoader = catalogLoader ?? _loadCanonicalCatalog;

  final SupabaseClient _client;
  final WrCanonicalCatalogLoader _catalogLoader;
  Future<WrCanonicalCatalog>? _catalogFuture;

  Future<WrCanonicalCatalog> _canonicalCatalog() =>
      _catalogFuture ??= _catalogLoader();

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  @override
  Future<List<WrSituation>> fetchSituations({ScaDimension? dimension}) async {
    final catalog = await _canonicalCatalog();
    var remote = const <WrSituation>[];
    try {
      final rows = await _client
          .from('wr_situations')
          .select()
          .order('code', ascending: true);
      remote = _parseSituations(rows);
    } catch (_) {
      // The local catalog is sufficient for a new install or while the remote
      // migration is rolling out. Historical rows are best-effort when the
      // network is unavailable.
    }
    final merged = catalog.mergeSituations(remote);
    return dimension == null
        ? merged
        : merged.where((s) => s.scaDimension == dimension).toList();
  }

  @override
  Future<List<WrStory>> fetchStories({ScaDimension? dimension}) async {
    final catalog = await _canonicalCatalog();
    var remote = const <WrStory>[];
    try {
      final rows = await _client
          .from('wr_stories')
          .select()
          .order('story_id', ascending: true);
      remote = _parseStories(rows);
    } catch (_) {
      // Canonical local editorial content remains available if Supabase is
      // unavailable or the new columns have not reached this environment.
    }
    final merged = catalog.mergeStories(remote);
    return dimension == null
        ? merged
        : merged.where((s) => s.scaDimension == dimension).toList();
  }

  @override
  Future<WrStory?> fetchStory(String id) async {
    final catalog = await _canonicalCatalog();
    final canonical = catalog.storyFor(id);
    if (canonical != null) return canonical;

    final rows = await _client
        .from('wr_stories')
        .select()
        .eq('story_id', id)
        .limit(1);
    for (final row in rows) {
      final story = _tryParseStory(row);
      if (story?.storyId == id) return story;
    }
    return null;
  }

  @override
  Future<void> insertMemoryEvent(CareerMemoryEvent event) async {
    await _client.from('wr_career_memory_events').insert(event.toInsert());
  }

  @override
  Future<List<CareerMemoryEvent>> fetchMemoryEvents({int limit = 50}) async {
    final uid = _uid;
    final rows = await _client
        .from('wr_career_memory_events')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(CareerMemoryEvent.fromJson).toList();
  }

  @override
  Future<List<CareerMemoryEvent>> fetchMemoryEventsForUser(
    String userId, {
    int? limit,
  }) async {
    var query = _client
        .from('wr_career_memory_events')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    if (limit != null) {
      query = query.limit(limit);
    }
    final rows = await query;
    return rows.map(CareerMemoryEvent.fromJson).toList();
  }

  @override
  Future<void> deleteTodayMemoryEventsForSituation({
    required String userId,
    required String situationCode,
    required DateTime day,
  }) async {
    // day is a VN-local date-only DateTime (from todayVn()).
    // We compute the UTC bounds of that VN day:
    //   VN midnight = day (no time) → UTC = day - 7h
    //   VN end of day = day + 1 day - 1ms → UTC = (day + 1d) - 7h - 1ms
    // day is a VN-local date-only DateTime (year/month/day only, no timezone).
    // Build the UTC equivalent of VN midnight directly from the date components,
    // without calling .toUtc() which would apply the machine's local timezone
    // and cause a double-shift on UTC+7 devices.
    final vnMidnightUtc = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).subtract(const Duration(hours: 7));
    final vnEndOfDayUtc = vnMidnightUtc.add(const Duration(hours: 24));
    await _client
        .from('wr_career_memory_events')
        .delete()
        .eq('user_id', userId)
        .eq('situation_code', situationCode)
        .gte('created_at', vnMidnightUtc.toIso8601String())
        .lt('created_at', vnEndOfDayUtc.toIso8601String());
  }

  static List<WrSituation> _parseSituations(Iterable<dynamic> rows) => [
    for (final row in rows)
      if (_tryParseSituation(row) case final situation?) situation,
  ];

  static WrSituation? _tryParseSituation(dynamic row) {
    if (row is! Map) return null;
    try {
      return WrSituation.fromJson(Map<String, dynamic>.from(row));
    } on Object {
      return null;
    }
  }

  static List<WrStory> _parseStories(Iterable<dynamic> rows) => [
    for (final row in rows)
      if (_tryParseStory(row) case final story?) story,
  ];

  static WrStory? _tryParseStory(dynamic row) {
    if (row is! Map) return null;
    try {
      return WrStory.fromJson(Map<String, dynamic>.from(row));
    } on Object {
      return null;
    }
  }
}

typedef WrCanonicalCatalogLoader = Future<WrCanonicalCatalog> Function();

Future<WrCanonicalCatalog> _loadCanonicalCatalog() => loadWrCanonicalCatalog();
