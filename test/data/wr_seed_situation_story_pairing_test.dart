// Contract tests for the generated v2 seed assets.
//
// The importer is the only place that maps SITUATIONS_v2.js into the two
// checked-in assets. These tests ensure the generated situation/story pair is
// still one exact editorial entity at the repository boundary.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_canonical_catalog.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

const _situationsPath = 'assets/seed/wr_situations.json';
const _storiesPath = 'assets/seed/wr_stories.json';

List<Map<String, dynamic>> _readRows(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! List) throw FormatException('$path is not a list');
  return [
    for (final row in decoded)
      if (row is Map<String, dynamic>)
        row
      else if (row is Map)
        Map<String, dynamic>.from(row)
      else
        throw FormatException('$path contains a non-object row'),
  ];
}

List<Map<String, dynamic>> _real(List<Map<String, dynamic>> rows) =>
    rows.where((row) => row['custom'] != true).toList(growable: false);

Set<String> _codes(List<Map<String, dynamic>> rows, String field) => {
  for (final row in rows) row[field] as String,
};

Map<String, dynamic> _retirementAudit() {
  final result = Process.runSync('node', [
    'scripts/audit_retired_situation_ids.js',
    '--json',
  ]);
  if (result.exitCode != 0) {
    throw StateError('retirement audit failed: ${result.stderr}');
  }
  return Map<String, dynamic>.from(jsonDecode(result.stdout as String) as Map);
}

void main() {
  late List<Map<String, dynamic>> situationRows;
  late List<Map<String, dynamic>> storyRows;
  late List<Map<String, dynamic>> realSituations;

  setUpAll(() {
    situationRows = _readRows(_situationsPath);
    storyRows = _readRows(_storiesPath);
    realSituations = _real(situationRows);
  });

  group('v2 seed shape', () {
    test('contains 72 real rows plus the client custom option', () {
      expect(situationRows, hasLength(73));
      expect(realSituations, hasLength(72));
      expect(situationRows.where((row) => row['custom'] == true), hasLength(1));
      expect(
        situationRows.singleWhere((row) => row['custom'] == true)['id'],
        'other',
      );
    });

    test('has the required 48/24 valence split', () {
      expect(
        realSituations.where(
          (row) => row['valence'] == WrValence.thachThuc.dbValue,
        ),
        hasLength(48),
      );
      expect(
        realSituations.where(
          (row) => row['valence'] == WrValence.tichCuc.dbValue,
        ),
        hasLength(24),
      );
    });

    test('each of the six check-in moods has 12 situations', () {
      for (final mood in kWrV2MoodCodes) {
        expect(
          realSituations.where((row) => row['mood'] == mood),
          hasLength(12),
          reason: '$mood must have 12 rows',
        );
      }
    });

    test('challenge subgroups are balanced at eight rows each', () {
      for (final subgroup in const ['S1', 'S2', 'C1', 'C2', 'A1', 'A3']) {
        expect(
          realSituations.where(
            (row) =>
                row['subgroup'] == subgroup &&
                row['valence'] == WrValence.thachThuc.dbValue,
          ),
          hasLength(8),
          reason: '$subgroup must have 8 challenge rows',
        );
      }
    });

    test('active situation ids are unique', () {
      final ids = realSituations.map((row) => row['id']).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('exact situation/story pairing', () {
    test('every real situation has exactly one story with the same id', () {
      final situationIds = _codes(realSituations, 'id');
      final storyIds = _codes(storyRows, 'story_id');

      expect(storyRows, hasLength(72));
      expect(storyIds, hasLength(storyRows.length));
      expect(storyIds, situationIds);
    });

    test('all six editorial fields stay byte-for-byte paired', () {
      final storiesById = {
        for (final row in storyRows) row['story_id'] as String: row,
      };
      for (final situation in realSituations) {
        final id = situation['id'] as String;
        final story = storiesById[id]!;
        for (final field in const [
          'title',
          'story',
          'reflection',
          'selfReflection',
          'aha',
          'practice',
        ]) {
          expect(
            story[field],
            situation[field],
            reason: '$id.$field diverged between seed entities',
          );
        }
      }
    });

    test('canonical adapter parses custom without a null dimension cast', () {
      final catalog = WrCanonicalCatalog.fromJson(
        situationsJson: situationRows,
        storiesJson: storyRows,
      );
      expect(catalog.realSituations, hasLength(72));
      expect(catalog.situationFor('other')!.isCustom, isTrue);
      expect(catalog.situationFor('other')!.hasV2Classification, isFalse);
      expect(catalog.situationFor('other')!.explicitValence, isNull);
    });
  });

  group('retirement audit', () {
    test('explicit audit passes without deleting historical rows', () {
      final audit = _retirementAudit();
      expect(audit['pass'], isTrue);
      expect(audit['retiredCount'], 11);
      expect(audit['activeRetiredCodes'], isEmpty);
      expect(audit['activeRealCount'], 72);
      expect(audit['customCount'], 1);
    });
  });
}
