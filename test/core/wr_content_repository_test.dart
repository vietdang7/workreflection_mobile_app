// Tests for FakeWrContentRepository — verifies the behavior contract.
// TDD: written BEFORE production code.
// Run: flutter test test/core/wr_content_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

import '../support/fake_wr_content_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

WrSituation _situation({
  String code = 'S1-sit-01',
  ScaDimension dim = ScaDimension.s1,
  HumanNeed? need = HumanNeed.roRang,
  int wave = 1,
}) {
  return WrSituation(
    code: code,
    text: 'Test situation $code',
    scaDimension: dim,
    humanNeed: need,
    wave: wave,
  );
}

WrStory _story({
  String id = 'A1-01',
  ScaDimension dim = ScaDimension.a1,
  HumanNeed? need = HumanNeed.thichNghi,
}) {
  return WrStory(
    storyId: id,
    title: 'Story $id',
    scaDimension: dim,
    humanNeed: need,
    storyContent: 'Content for story $id.',
    emotionTags: const [],
    behaviorTags: const [],
    careerStages: const [],
  );
}

CareerMemoryEvent _event({
  String id = 'evt-1',
  String userId = 'user-1',
  String? storyId = 'A1-01',
  HumanNeed? need = HumanNeed.phatTrien,
  ScaDimension? dim = ScaDimension.a1,
}) {
  return CareerMemoryEvent(
    id: id,
    userId: userId,
    storyId: storyId,
    humanNeed: need,
    scaDimension: dim,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeWrContentRepository repo;

  setUp(() {
    repo = FakeWrContentRepository();
  });

  // --- fetchSituations ---

  group('fetchSituations', () {
    test('returns all seeded situations when no filter', () async {
      repo.seedSituations([
        _situation(code: 'S1-sit-01', dim: ScaDimension.s1),
        _situation(code: 'C1-sit-01', dim: ScaDimension.c1),
        _situation(code: 'A1-sit-01', dim: ScaDimension.a1),
      ]);

      final result = await repo.fetchSituations();

      expect(result.length, 3);
    });

    test('filters by ScaDimension when provided', () async {
      repo.seedSituations([
        _situation(code: 'S1-sit-01', dim: ScaDimension.s1),
        _situation(code: 'S1-sit-02', dim: ScaDimension.s1),
        _situation(code: 'C1-sit-01', dim: ScaDimension.c1),
      ]);

      final result = await repo.fetchSituations(dimension: ScaDimension.s1);

      expect(result.length, 2);
      expect(result.every((s) => s.scaDimension == ScaDimension.s1), isTrue);
    });

    test('returns empty list when no situations seeded', () async {
      final result = await repo.fetchSituations();
      expect(result, isEmpty);
    });

    test('nextError throws once then clears', () async {
      repo.seedSituations([_situation()]);
      repo.nextError = Exception('forced error');

      expect(() => repo.fetchSituations(), throwsException);
      // Second call should succeed
      final result = await repo.fetchSituations();
      expect(result.length, 1);
    });
  });

  // --- fetchStories ---

  group('fetchStories', () {
    test('returns all seeded stories when no filter', () async {
      repo.seedStories([
        _story(id: 'A1-01', dim: ScaDimension.a1),
        _story(id: 'A2-01', dim: ScaDimension.a2),
        _story(id: 'C1-01', dim: ScaDimension.c1),
      ]);

      final result = await repo.fetchStories();

      expect(result.length, 3);
    });

    test('filters by ScaDimension when provided', () async {
      repo.seedStories([
        _story(id: 'A1-01', dim: ScaDimension.a1),
        _story(id: 'A1-02', dim: ScaDimension.a1),
        _story(id: 'C1-01', dim: ScaDimension.c1),
      ]);

      final result = await repo.fetchStories(dimension: ScaDimension.a1);

      expect(result.length, 2);
      expect(result.every((s) => s.scaDimension == ScaDimension.a1), isTrue);
    });

    test('returns empty list when no stories seeded', () async {
      final result = await repo.fetchStories();
      expect(result, isEmpty);
    });
  });

  // --- fetchStory ---

  group('fetchStory', () {
    test('returns story when found', () async {
      repo.seedStories([_story(id: 'A1-01'), _story(id: 'A1-02')]);

      final result = await repo.fetchStory('A1-01');

      expect(result, isNotNull);
      expect(result!.storyId, 'A1-01');
    });

    test('returns null when story not found', () async {
      repo.seedStories([_story(id: 'A1-01')]);

      final result = await repo.fetchStory('X9-99');

      expect(result, isNull);
    });

    test('nextError throws on fetchStory', () async {
      repo.seedStories([_story()]);
      repo.nextError = Exception('err');

      expect(() => repo.fetchStory('A1-01'), throwsException);
    });
  });

  // --- insertMemoryEvent ---

  group('insertMemoryEvent', () {
    test('records inserted event', () async {
      final evt = _event(id: 'e1');

      await repo.insertMemoryEvent(evt);

      expect(repo.insertMemoryEventCalls, [evt]);
    });

    test('inserted event appears in fetchMemoryEvents', () async {
      final evt = _event(id: 'e1');

      await repo.insertMemoryEvent(evt);
      final events = await repo.fetchMemoryEvents();

      expect(events.map((e) => e.id), contains('e1'));
    });

    test('multiple inserts accumulate', () async {
      await repo.insertMemoryEvent(_event(id: 'e1'));
      await repo.insertMemoryEvent(_event(id: 'e2'));

      final events = await repo.fetchMemoryEvents();
      expect(events.length, 2);
    });
  });

  // --- fetchMemoryEvents ---

  group('fetchMemoryEvents', () {
    test('returns seeded events', () async {
      repo.seedMemoryEvents([
        _event(id: 'e1'),
        _event(id: 'e2'),
        _event(id: 'e3'),
      ]);

      final result = await repo.fetchMemoryEvents();

      expect(result.length, 3);
    });

    test('respects limit parameter', () async {
      repo.seedMemoryEvents(List.generate(
        10,
        (i) => _event(id: 'e$i'),
      ));

      final result = await repo.fetchMemoryEvents(limit: 3);

      expect(result.length, 3);
    });

    test('default limit is 50', () async {
      repo.seedMemoryEvents(List.generate(
        60,
        (i) => _event(id: 'e${i.toString().padLeft(2, '0')}'),
      ));

      final result = await repo.fetchMemoryEvents();

      expect(result.length, 50);
    });

    test('returns empty list when no events', () async {
      final result = await repo.fetchMemoryEvents();
      expect(result, isEmpty);
    });

    test('nextError throws on fetchMemoryEvents', () async {
      repo.nextError = Exception('err');
      expect(() => repo.fetchMemoryEvents(), throwsException);
    });
  });
}
