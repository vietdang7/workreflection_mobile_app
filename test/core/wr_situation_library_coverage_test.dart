// Coverage contract for the canonical v2 catalog generated from
// SITUATIONS_v2.js. Run with:
//   flutter test test/core/wr_situation_library_coverage_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

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
  late List<Map<String, dynamic>> raw;
  late List<Map<String, dynamic>> real;
  late Map<String, WrSituation> parsed;

  setUpAll(() {
    raw =
        (jsonDecode(File('assets/seed/wr_situations.json').readAsStringSync())
                as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
    real = raw.where((row) => row['custom'] != true).toList(growable: false);
    parsed = {
      for (final row in raw) (row['code'] as String): WrSituation.fromJson(row),
    };
  });

  group('canonical v2 catalog', () {
    test('contains exactly 72 real rows plus client custom option', () {
      expect(raw, hasLength(73));
      expect(real, hasLength(72));
      expect(raw.where((row) => row['custom'] == true), hasLength(1));
      expect(parsed['other']!.isCustom, isTrue);
    });

    test('real row ids are unique and the custom id is other', () {
      final ids = real.map((row) => row['id']).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(raw.singleWhere((row) => row['custom'] == true)['id'], 'other');
    });

    test('real rows have valid explicit v2 classification', () {
      expect(
        real.every((row) => parsed[row['code']]!.hasV2Classification),
        isTrue,
      );
      expect(parsed['other']!.hasV2Classification, isFalse);
      expect(parsed['other']!.explicitValence, isNull);
    });

    test('explicit axes use only the v2 value sets', () {
      expect(
        real.every((row) => kWrV2PillarCodes.contains(row['pillar'])),
        isTrue,
      );
      expect(
        real.every((row) => kWrV2SubgroupCodes.contains(row['subgroup'])),
        isTrue,
      );
      expect(real.every((row) => kWrV2MoodCodes.contains(row['mood'])), isTrue);
      expect(
        real.every(
          (row) =>
              row['valence'] == WrValence.thachThuc.dbValue ||
              row['valence'] == WrValence.tichCuc.dbValue,
        ),
        isTrue,
      );
    });

    test('valence split is 48 challenge and 24 positive', () {
      expect(
        real.where((row) => row['valence'] == 'thach-thuc'),
        hasLength(48),
      );
      expect(real.where((row) => row['valence'] == 'tich-cuc'), hasLength(24));
    });

    test('each mood has exactly 12 real situations', () {
      for (final mood in kWrV2MoodCodes) {
        expect(
          real.where((row) => row['mood'] == mood),
          hasLength(12),
          reason: '$mood must have 12 rows',
        );
      }
    });

    test('each challenge subgroup has exactly 8 challenge rows', () {
      for (final subgroup in const ['S1', 'S2', 'C1', 'C2', 'A1', 'A3']) {
        expect(
          real.where(
            (row) =>
                row['subgroup'] == subgroup && row['valence'] == 'thach-thuc',
          ),
          hasLength(8),
          reason: '$subgroup must have 8 challenge rows',
        );
      }
    });

    test('all real rows retain the six editorial fields', () {
      for (final row in real) {
        for (final field in const [
          'title',
          'story',
          'reflection',
          'selfReflection',
          'aha',
          'practice',
        ]) {
          final value = row[field];
          expect(value, isA<String>(), reason: '${row['id']}.$field');
          expect((value as String).trim(), isNotEmpty);
        }
      }
    });

    test(
      'retirement audit proves removed ids are absent from active source',
      () {
        final audit = _retirementAudit();
        expect(audit['pass'], isTrue);
        expect(audit['retiredCount'], 11);
        expect(audit['activeRealCount'], real.length);
        expect(audit['customCount'], 1);
        expect(audit['activeRetiredCodes'], isEmpty);
        expect(audit['duplicateActiveCodes'], isEmpty);
      },
    );

    test('custom null sca_dimension parses without becoming classified', () {
      final custom = WrSituation.fromJson({
        'id': 'other',
        'title': 'Điều khác, để tôi tự mô tả',
        'sca_dimension': null,
        'custom': true,
      });
      expect(custom.isCustom, isTrue);
      expect(custom.hasV2Classification, isFalse);
    });

    test('legacy rows remain readable but are not v2 classified', () {
      final legacy = WrSituation.fromJson({
        'id': 'history-only',
        'title': 'Nhãn lịch sử',
        'sca_dimension': 'C2',
      });
      expect(legacy.text, 'Nhãn lịch sử');
      expect(legacy.hasV2Classification, isFalse);
      expect(legacy.explicitValence, isNull);
    });

    test(
      'source editorial title and story survive the adapter-shaped asset',
      () {
        final first = parsed['A1-01']!;
        expect(first.textVi, 'Tôi đang đi rất nhanh, nhưng đi đâu?');
        expect(
          raw.firstWhere((row) => row['id'] == 'A1-01')['story'],
          contains('Buổi đánh giá cuối kỳ diễn ra suôn sẻ'),
        );
      },
    );
  });
}
