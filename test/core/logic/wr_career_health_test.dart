// Career Health Check — Hướng 1 "tích luỹ" (khách chốt 2026-07-31).
// Run: flutter test test/core/logic/wr_career_health_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_career_health.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

WrSituation _sit(String code, ScaDimension dim) => WrSituation(
      code: code,
      text: code,
      scaDimension: dim,
      wave: 1,
    );

/// [count] lần xuất hiện của [code] trong recentSituationIds.
List<String> _p(String code, int count) => List.filled(count, code);

void main() {
  group('careerHealthUnlocked', () {
    test('ngưỡng là 15', () {
      expect(kCareerHealthThreshold, 15);
    });

    test('chưa nhìn lại lần nào thì chưa mở', () {
      expect(careerHealthUnlocked(0), isFalse);
    });

    test('14 lần chưa mở, đúng 15 lần là mở', () {
      expect(careerHealthUnlocked(14), isFalse);
      expect(careerHealthUnlocked(15), isTrue);
    });

    test('quá ngưỡng vẫn mở', () {
      expect(careerHealthUnlocked(16), isTrue);
    });
  });

  group('pillarShares', () {
    final situations = [
      _sit('s-a', ScaDimension.s1),
      _sit('c-a', ScaDimension.c2),
      _sit('a-a', ScaDimension.a2),
      _sit('pos', ScaDimension.pAchieve),
    ];

    test('rỗng thì cả ba trụ bằng 0', () {
      final shares = pillarShares(const [], situations);
      for (final p in SelfCheckPillar.values) {
        expect(shares[p], 0);
      }
    });

    test('chia đúng tỉ trọng theo số lần', () {
      final shares = pillarShares(
        [..._p('s-a', 6), ..._p('c-a', 3), ..._p('a-a', 1)],
        situations,
      );
      expect(shares[SelfCheckPillar.s], closeTo(0.6, 0.001));
      expect(shares[SelfCheckPillar.c], closeTo(0.3, 0.001));
      expect(shares[SelfCheckPillar.a], closeTo(0.1, 0.001));
    });

    test('tình huống tích cực không kéo trụ nào xuống', () {
      // P-ACHIEVE không thuộc trụ nào — nếu bị tính vào mẫu số thì ba trụ đều
      // loãng đi và trụ đang thật sự vướng sẽ hiện nhẹ hơn thực tế.
      expect(pillarOfDimension(ScaDimension.pAchieve), isNull);
      final shares = pillarShares(
        [..._p('s-a', 1), ..._p('pos', 99)],
        situations,
      );
      expect(shares[SelfCheckPillar.s], 1.0);
    });

    test('tình huống không có trong danh mục thì bỏ qua', () {
      final shares = pillarShares(
        [..._p('s-a', 2), ..._p('khong-ton-tai', 50)],
        situations,
      );
      expect(shares[SelfCheckPillar.s], 1.0);
    });
  });

  group('behaviourPillarLabel', () {
    test('lệch hẳn về một trụ thì ưu tiên cải thiện', () {
      expect(behaviourPillarLabel(0.6), 'Ưu tiên cải thiện');
      expect(behaviourPillarLabel(0.45), 'Ưu tiên cải thiện');
    });

    test('quanh mức chia đều thì cần chú ý', () {
      expect(behaviourPillarLabel(0.33), 'Cần chú ý');
      expect(behaviourPillarLabel(0.20), 'Cần chú ý');
    });

    test('gần như không xuất hiện thì đang phát triển', () {
      expect(behaviourPillarLabel(0.19), 'Đang phát triển');
      expect(behaviourPillarLabel(0), 'Đang phát triển');
      expect(behaviourPillarIsHealthy(0), isTrue);
      expect(behaviourPillarIsHealthy(0.5), isFalse);
    });
  });
}
