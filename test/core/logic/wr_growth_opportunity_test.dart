// Luật suy ra Cơ hội phát triển — Kiến trúc Dữ liệu Hai Lớp v1.6 §XI.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_growth_opportunity.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_mood_content.dart';

final _now = DateTime(2026, 7, 28);

WrSituation _sit(String code, ScaDimension dim) => WrSituation(
      code: code,
      text: 'Tình huống $code',
      scaDimension: dim,
      wave: 1,
    );

/// [count] lần xuất hiện của [code] trong recentSituationIds.
///
/// Từ 2026-07-31 luật này đọc nguồn duy nhất đó thay vì `wr_pattern_counts`
/// (Kiến trúc v2.0 §4.3).
List<String> _pat(String code, int count) => List.filled(count, code);

GrowthOpportunity? _derive({
  required List<String> recent,
  required List<WrSituation> situations,
  String? roleText,
}) =>
    deriveGrowthOpportunity(
      userId: 'u1',
      recent: recent,
      situations: situations,
      roleText: roleText,
      now: _now,
    );

void main() {
  group('Im lặng khi chưa đủ căn cứ (§11.3)', () {
    test('chưa có Pattern nào thì không gợi ý', () {
      expect(_derive(recent: const [], situations: const []), isNull);
    });

    test('dưới ngưỡng lặp lại thì không gợi ý', () {
      final sits = [_sit('C1-sit-01', ScaDimension.c1)];
      final result = _derive(
        recent: [..._pat('C1-sit-01', kGrowthOpportunityThreshold - 1)],
        situations: sits,
      );
      expect(result, isNull);
    });

    test('hai trụ bằng điểm nhau thì không gợi ý — chưa có hướng nào trội', () {
      final sits = [
        _sit('C1-sit-01', ScaDimension.c1),
        _sit('A1-sit-01', ScaDimension.a1),
      ];
      final result = _derive(
        recent: [..._pat('C1-sit-01', 3), ..._pat('A1-sit-01', 3)],
        situations: sits,
      );
      expect(result, isNull);
    });

    test('chỉ toàn tình huống tích cực thì không gợi ý', () {
      // P-ACHIEVE/P-STEADY là chỗ đang ổn, không phải hướng cần phát triển.
      final sits = [_sit('P-01', ScaDimension.pAchieve)];
      expect(_derive(recent: [..._pat('P-01', 9)], situations: sits), isNull);
    });

    test('Pattern trỏ tới mã tình huống không có trong thư viện thì bỏ qua', () {
      final result = _derive(
        recent: [..._pat('KHONG-CO', 20)],
        situations: [_sit('C1-sit-01', ScaDimension.c1)],
      );
      expect(result, isNull);
    });
  });

  group('Gợi ý khi trụ đã trội hẳn', () {
    test('trụ C trội → nói về năng lực đối thoại', () {
      final sits = [
        _sit('C1-sit-01', ScaDimension.c1),
        _sit('C2-sit-01', ScaDimension.c2),
        _sit('A1-sit-01', ScaDimension.a1),
      ];
      final result = _derive(
        recent: [
          ..._pat('C1-sit-01', 3),
          ..._pat('C2-sit-01', 2),
          ..._pat('A1-sit-01', 1),
        ],
        situations: sits,
      );
      expect(result, isNotNull);
      expect(result!.suggestionText, contains('đối thoại'));
    });

    test('trụ S trội → nói về năng lực tự định vị', () {
      final sits = [_sit('S1-sit-01', ScaDimension.s1)];
      final result =
          _derive(recent: [..._pat('S1-sit-01', 5)], situations: sits);
      expect(result!.suggestionText, contains('tự định vị'));
    });

    test('trụ A trội → nói về năng lực tự điều phối', () {
      final sits = [_sit('A3-sit-01', ScaDimension.a3)];
      final result =
          _derive(recent: [..._pat('A3-sit-01', 4)], situations: sits);
      expect(result!.suggestionText, contains('tự điều phối'));
    });

    test('§11.1: câu gợi ý ở thể điều kiện, không phán chắc chắn', () {
      final sits = [_sit('S1-sit-01', ScaDimension.s1)];
      final result =
          _derive(recent: [..._pat('S1-sit-01', 5)], situations: sits)!;
      expect(result.suggestionText, contains('Có vẻ'));
      expect(result.suggestionText, contains('có thể'));
    });

    test('§11.2: luôn kèm đúng câu ghi chú độ chính xác', () {
      final sits = [_sit('S1-sit-01', ScaDimension.s1)];
      final result =
          _derive(recent: [..._pat('S1-sit-01', 5)], situations: sits)!;
      expect(result.confidenceNote, GrowthOpportunity.kConfidenceNote);
      expect(result.confidenceNote, isNotEmpty);
    });

    test('§11.5: ghi lại các mã tình huống đã dùng, không trùng lặp', () {
      final sits = [
        _sit('C1-sit-01', ScaDimension.c1),
        _sit('C2-sit-01', ScaDimension.c2),
      ];
      final result = _derive(
        recent: [
          ..._pat('C1-sit-01', 3),
          ..._pat('C1-sit-01', 1),
          ..._pat('C2-sit-01', 1),
        ],
        situations: sits,
      )!;
      expect(result.basedOn, ['C1-sit-01', 'C2-sit-01']);
    });

    test('tình huống tích cực không lọt vào basedOn', () {
      final sits = [
        _sit('S1-sit-01', ScaDimension.s1),
        _sit('P-01', ScaDimension.pSteady),
      ];
      final result = _derive(
        recent: [..._pat('S1-sit-01', 5), ..._pat('P-01', 2)],
        situations: sits,
      )!;
      expect(result.basedOn, ['S1-sit-01']);
    });
  });

  group('role_text neo gợi ý vào công việc thật', () {
    final sits = [_sit('S1-sit-01', ScaDimension.s1)];
    final recent = [..._pat('S1-sit-01', 5)];

    test('có mô tả công việc thì gắn thêm một câu nhắc tới nó', () {
      final result = _derive(
        recent: recent,
        situations: sits,
        roleText: 'trưởng nhóm nội dung',
      )!;
      expect(result.suggestionText, contains('trưởng nhóm nội dung'));
    });

    test('mô tả rỗng hoặc chỉ khoảng trắng thì không bịa thêm câu nào', () {
      final blank = _derive(
        recent: recent,
        situations: sits,
        roleText: '   ',
      )!;
      final none = _derive(recent: recent, situations: sits)!;
      expect(blank.suggestionText, none.suggestionText);
      expect(blank.suggestionText, isNot(contains('Đặt cạnh công việc')));
    });
  });
}
