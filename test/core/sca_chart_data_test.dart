import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/sca_chart_data.dart';

void main() {
  group('ScaChartData', () {
    test('ratios are scores divided by 5.0', () {
      final data = ScaChartData.fromScores(
        structure: 5.0,
        culture: 2.5,
        activity: 0.0,
      );
      expect(data.structureRatio, closeTo(1.0, 0.001));
      expect(data.cultureRatio, closeTo(0.5, 0.001));
      expect(data.activityRatio, closeTo(0.0, 0.001));
    });

    test('scores above max clamp to 1.0 ratio', () {
      // defensive: if a score somehow exceeds 5, ratio should not exceed 1.0
      final data = ScaChartData.fromScores(
        structure: 6.0,
        culture: 5.0,
        activity: 5.0,
      );
      expect(data.structureRatio, closeTo(1.0, 0.001));
    });

    test('scores below 0 clamp to 0.0 ratio', () {
      final data = ScaChartData.fromScores(
        structure: -1.0,
        culture: 0.0,
        activity: 0.0,
      );
      expect(data.structureRatio, closeTo(0.0, 0.001));
    });

    test('typical scores produce correct ratios', () {
      final data = ScaChartData.fromScores(
        structure: 3.5,
        culture: 4.2,
        activity: 3.8,
      );
      expect(data.structureRatio, closeTo(0.70, 0.001));
      expect(data.cultureRatio, closeTo(0.84, 0.001));
      expect(data.activityRatio, closeTo(0.76, 0.001));
    });

    test('hasData is false when all scores are zero', () {
      final data = ScaChartData.fromScores(
        structure: 0.0,
        culture: 0.0,
        activity: 0.0,
      );
      expect(data.hasData, isFalse);
    });

    test('hasData is true when any score is non-zero', () {
      final data = ScaChartData.fromScores(
        structure: 0.0,
        culture: 0.1,
        activity: 0.0,
      );
      expect(data.hasData, isTrue);
    });
  });
}
