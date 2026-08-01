import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
import 'package:workreflection_mobile/core/logic/vn_date.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

/// In-memory fake WrContentRepository for widget/unit tests.
///
/// Pre-populate via the `seed*` methods before pumping widgets.
/// Inspect recorded calls via the `*Calls` fields.
///
/// Set [nextError] before a call to simulate an error; it is thrown once then
/// cleared automatically.
class FakeWrContentRepository implements WrContentRepository {
  // --- Internal state ---
  final List<WrSituation> _situations = [];
  final List<WrStory> _stories = [];
  final List<CareerMemoryEvent> _events = [];

  /// When set, the next repo call throws this error once, then clears it.
  Object? nextError;

  // --- Call recorders ---
  final List<CareerMemoryEvent> insertMemoryEventCalls = [];
  final List<({String userId, String situationCode, DateTime day})>
      deleteTodayMemoryEventsForSituationCalls = [];

  // --- Seed helpers ---

  void seedSituations(List<WrSituation> situations) {
    _situations
      ..clear()
      ..addAll(situations);
  }

  void seedStories(List<WrStory> stories) {
    _stories
      ..clear()
      ..addAll(stories);
  }

  void seedMemoryEvents(List<CareerMemoryEvent> events) {
    _events
      ..clear()
      ..addAll(events);
  }

  // --- Helpers ---

  void _maybeThrow() {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      // ignore: only_throw_errors
      throw err;
    }
  }

  // --- WrContentRepository impl ---

  @override
  Future<List<WrSituation>> fetchSituations({ScaDimension? dimension}) async {
    _maybeThrow();
    if (dimension == null) return List.unmodifiable(_situations);
    return List.unmodifiable(
      _situations.where((s) => s.scaDimension == dimension),
    );
  }

  @override
  Future<List<WrStory>> fetchStories({ScaDimension? dimension}) async {
    _maybeThrow();
    if (dimension == null) return List.unmodifiable(_stories);
    return List.unmodifiable(
      _stories.where((s) => s.scaDimension == dimension),
    );
  }

  @override
  Future<WrStory?> fetchStory(String id) async {
    _maybeThrow();
    try {
      return _stories.firstWhere((s) => s.storyId == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> insertMemoryEvent(CareerMemoryEvent event) async {
    _maybeThrow();
    insertMemoryEventCalls.add(event);
    // Stamp createdAt = now if not provided, so date-based filtering works in tests.
    final stamped = event.createdAt != null
        ? event
        : CareerMemoryEvent(
            id: event.id,
            userId: event.userId,
            storyId: event.storyId,
            situationCode: event.situationCode,
            humanNeed: event.humanNeed,
            scaDimension: event.scaDimension,
            emotion: event.emotion,
            behavior: event.behavior,
            intensity: event.intensity,
            reflectionText: event.reflectionText,
            careerStage: event.careerStage,
            createdAt: DateTime.now(),
          );
    _events.add(stamped);
  }

  @override
  Future<List<CareerMemoryEvent>> fetchMemoryEvents({int limit = 50}) async {
    _maybeThrow();
    final sorted = List.of(_events)
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
    final capped = sorted.length > limit ? sorted.sublist(0, limit) : sorted;
    return List.unmodifiable(capped);
  }

  @override
  Future<List<CareerMemoryEvent>> fetchMemoryEventsForUser(
    String userId, {
    int? limit,
  }) async {
    _maybeThrow();
    final sorted = _events.where((e) => e.userId == userId).toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
    if (limit != null && sorted.length > limit) {
      return List.unmodifiable(sorted.sublist(0, limit));
    }
    return List.unmodifiable(sorted);
  }

  @override
  Future<void> deleteTodayMemoryEventsForSituation({
    required String userId,
    required String situationCode,
    required DateTime day,
  }) async {
    _maybeThrow();
    deleteTodayMemoryEventsForSituationCalls.add((
      userId: userId,
      situationCode: situationCode,
      day: day,
    ));
    // day is a VN-local date-only DateTime (from todayVn()).
    // todayVnFrom expects UTC and adds 7h internally — pass UTC directly.
    final dayVn = todayVnFrom(day.toUtc());
    _events.removeWhere((e) {
      if (e.userId != userId) return false;
      if (e.situationCode != situationCode) return false;
      final created = e.createdAt;
      if (created == null) return false;
      final eventDayVn = todayVnFrom(created.toUtc());
      return eventDayVn == dayVn;
    });
  }
}
