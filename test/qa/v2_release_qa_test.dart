import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_canonical_catalog.dart';
import 'package:workreflection_mobile/core/logic/wr_career_health.dart';
import 'package:workreflection_mobile/core/logic/wr_deep_interpretation.dart';
import 'package:workreflection_mobile/core/logic/wr_situation_picker.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WrCanonicalCatalog catalog;
  final now = DateTime(2026, 9, 14);
  ReflectionEpisode episode(String? code) => ReflectionEpisode(
    userId: 'qa',
    humanMoment: HumanMoment.arrival,
    situationCode: code,
    openedAt: now,
  );
  setUpAll(() async => catalog = await loadWrCanonicalCatalog());

  for (final mood in Mood.values) {
    test('QA ${mood.name}: ten selections remain fresh across 100 seeds', () {
      for (var seed = 0; seed < 100; seed++) {
        final random = Random(seed);
        var recent = <String>[];
        for (var turn = 0; turn < 10; turn++) {
          final choices = pickSituationChoices(
            all: catalog.situations,
            mood: mood,
            recentIds: recent,
            random: random,
          );
          expect(choices, hasLength(5));
          expect(choices.map((s) => s.code).toSet(), hasLength(5));
          expect(choices.where((s) => recent.contains(s.code)), isEmpty);
          expect(
            choices.where((s) => s.mood == kMoodCodes[mood]),
            hasLength(3),
          );
          expect(choices.map((s) => s.valence).toSet(), hasLength(1));
          recent = rememberSituation(choices[random.nextInt(5)].code, recent);
        }
      }
    });
  }

  test(
    'QA repeated normalization keeps Unicode history but no false counts',
    () {
      const unknown = WrSituation(
        code: 'qa-unknown',
        wave: 1,
        text: 'Lịch sử riêng 🧭',
        scaDimension: ScaDimension.s1,
        pillarCode: 'S',
        subgroup: 'S1',
        mood: 'foggy',
        valence: WrValence.thachThuc,
      );
      final once = catalog.mergeSituations([unknown, unknown]);
      final twice = catalog.mergeSituations(once);
      expect(twice.length, once.length);
      expect(
        twice.singleWhere((s) => s.code == unknown.code).textVi,
        unknown.textVi,
      );
      final tally = pillarTally([
        episode(unknown.code),
        episode('other'),
        episode(null),
        episode(''),
        episode('A1-01'),
        episode('P-01'),
      ], twice);
      expect(tally.classified, 2);
      expect(tally.unclassified, 4);
      expect(tally.appearance.values.reduce((a, b) => a + b), 2);
      expect(tally.challengeTotal, 1);
      expect(tally.positiveTotal, 1);
    },
  );

  test('QA mixed-valence R3 describes challenge denominator', () {
    // Unique records avoid R1/R2: S=8, C=2, A=2 challenge records,
    // plus 6 distinct positives. The dominant challenge share is 8/12.
    final codes = [
      'S1-01',
      'S1-02',
      'S1-03',
      'S1-04',
      'S2-01',
      'S2-02',
      'S2-03',
      'S2-05',
      'C1-01',
      'C2-01',
      'A1-01',
      'A3-01',
      'P-01',
      'P-02',
      'P-03',
      'P-04',
      'P-05',
      'P-06',
    ];
    final result = buildDeepInterpretation(
      history: [
        ScaSelfCheckResponse(
          userId: 'qa',
          answers: const {},
          structureScore: 4.5,
          cultureScore: 4.5,
          activityScore: 4.5,
          takenAt: now,
        ),
      ],
      episodes: codes.map(episode).toList(),
      situations: catalog.situations,
      now: now,
    );
    expect(result.rung, DeepRung.awarenessGap);
    expect(result.facts.challengeTotal, 12);
    expect(result.facts.classifiedTotal, 18);
    expect(result.leadText, contains('8 trong 12'));
  });
}
