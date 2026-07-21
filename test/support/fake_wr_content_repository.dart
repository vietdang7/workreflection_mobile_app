import 'package:workreflection_mobile/core/data/wr_content_repository.dart';
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
    _events.add(event);
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
}
