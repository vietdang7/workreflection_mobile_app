import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_deep_interpretation.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';

final _now = DateTime(2026, 9, 10);

WrSituation _situation({
  required String code,
  required String subgroup,
  required WrValence valence,
}) {
  final pillar = kWrV2SubgroupPillars[subgroup]!;
  final dimension = switch (subgroup) {
    'S1' => ScaDimension.s1,
    'S2' => ScaDimension.s2,
    'C1' => ScaDimension.c1,
    'C2' => ScaDimension.c2,
    'A1' => ScaDimension.a1,
    'A3' => ScaDimension.a3,
    'Sp' || 'Ap' => ScaDimension.pAchieve,
    'Cp' => ScaDimension.pSteady,
    _ => ScaDimension.s1,
  };
  final mood = switch (subgroup) {
    'S1' => 'foggy',
    'S2' => 'outofsync',
    'C1' || 'C2' => 'stress',
    'A1' || 'A3' => 'tired',
    'Sp' || 'Cp' => 'ok',
    _ => 'happy',
  };
  return WrSituation(
    code: code,
    text: code,
    scaDimension: dimension,
    pillarCode: pillar,
    subgroup: subgroup,
    mood: mood,
    valence: valence,
    wave: 1,
  );
}

ReflectionEpisode _episode(String code) => ReflectionEpisode(
  userId: 'u1',
  humanMoment: HumanMoment.arrival,
  situationCode: code,
  openedAt: _now,
);

DeepFacts _facts({
  required List<WrSituation> situations,
  required List<ReflectionEpisode> episodes,
}) => buildDeepFacts(
  history: const [],
  episodes: episodes,
  situations: situations,
  now: _now,
);

List<WrSituation> _balancedCatalog() => [
  for (var i = 0; i < 16; i++)
    _situation(code: 'S-$i', subgroup: 'S1', valence: WrValence.thachThuc),
  for (var i = 0; i < 12; i++)
    _situation(
      code: 'P-$i',
      subgroup: ['Sp', 'Cp', 'Ap'][i % 3],
      valence: WrValence.tichCuc,
    ),
];

void main() {
  test('R4 includes zero positive share with classified data', () {
    final catalog = _balancedCatalog();
    final f = _facts(
      situations: catalog,
      episodes: [for (var i = 0; i < 16; i++) _episode('S-$i')],
    );
    expect(f.classifiedTotal, 16);
    expect(f.positiveShare, 0);
    expect(deepRung(f), DeepRung.positiveBalance);
  });

  test('R4 includes exactly 20 percent positive share', () {
    final catalog = _balancedCatalog();
    final f = _facts(
      situations: catalog,
      episodes: [
        for (var i = 0; i < 16; i++) _episode('S-$i'),
        for (var i = 0; i < 4; i++) _episode('P-$i'),
      ],
    );
    expect(f.positiveShare, closeTo(0.20, 1e-9));
    expect(deepRung(f), DeepRung.positiveBalance);
  });

  test('R5 is used above 20 percent when below 60 percent', () {
    final catalog = _balancedCatalog();
    final f = _facts(
      situations: catalog,
      episodes: [
        for (var i = 0; i < 16; i++) _episode('S-$i'),
        for (var i = 0; i < 5; i++) _episode('P-$i'),
      ],
    );
    expect(f.positiveShare, greaterThan(0.20));
    expect(f.positiveShare, lessThan(0.60));
    expect(deepRung(f), DeepRung.evenSpread);
  });

  test('R4 includes exactly 60 percent positive share', () {
    final catalog = _balancedCatalog();
    final f = _facts(
      situations: catalog,
      episodes: [
        for (var i = 0; i < 8; i++) _episode('S-$i'),
        for (var i = 0; i < 12; i++) _episode('P-$i'),
      ],
    );
    expect(f.positiveShare, closeTo(0.60, 1e-9));
    expect(deepRung(f), DeepRung.positiveBalance);
  });

  test('missing subgroup in one pillar cannot form an R2 cluster', () {
    final catalog = [
      const WrSituation(
        code: 'legacy-s1',
        text: 'Legacy S1',
        scaDimension: ScaDimension.s1,
        pillarCode: 'S',
        valence: WrValence.thachThuc,
        wave: 1,
      ),
      const WrSituation(
        code: 'legacy-s2',
        text: 'Legacy S2',
        scaDimension: ScaDimension.s2,
        pillarCode: 'S',
        valence: WrValence.thachThuc,
        wave: 1,
      ),
    ];
    final f = _facts(
      situations: catalog,
      episodes: [
        for (var i = 0; i < 3; i++) _episode('legacy-s1'),
        for (var i = 0; i < 3; i++) _episode('legacy-s2'),
      ],
    );
    expect(f.classifiedTotal, 0);
    expect(deepCluster(f), isNull);
    expect(deepRung(f), isNot(DeepRung.situationCluster));
  });

  test(
    'same pillar with different explicit subgroups cannot combine in R2',
    () {
      final catalog = [
        _situation(code: 'S1-a', subgroup: 'S1', valence: WrValence.thachThuc),
        _situation(code: 'S2-a', subgroup: 'S2', valence: WrValence.thachThuc),
      ];
      final f = _facts(
        situations: catalog,
        episodes: [
          for (var i = 0; i < 3; i++) _episode('S1-a'),
          for (var i = 0; i < 3; i++) _episode('S2-a'),
        ],
      );
      expect(f.situations, hasLength(2));
      expect(deepCluster(f), isNull);
      expect(deepRung(f), isNot(DeepRung.situationCluster));
    },
  );
}
