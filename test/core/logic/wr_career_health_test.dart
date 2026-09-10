// Career Health Check — Hướng 1 "tích luỹ" (khách chốt 2026-07-31).
// Run: flutter test test/core/logic/wr_career_health_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_career_health.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';

WrSituation _sit(String code, ScaDimension dim) => WrSituation(
      code: code,
      text: code,
      scaDimension: dim,
      wave: 1,
    );

/// [count] lần xuất hiện của [code] trong recentSituationIds.
List<String> _p(String code, int count) => List.filled(count, code);

ReflectionEpisode _episode(String? code) => ReflectionEpisode(
      userId: 'u',
      humanMoment: HumanMoment.arrival,
      situationCode: code,
    );

/// [count] lượt nhìn lại đã chọn tình huống [code].
List<ReflectionEpisode> _e(String code, int count) =>
    List.generate(count, (_) => _episode(code));

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

  // `pillarShares` trả ba số 0 cho hai trường hợp khác hẳn nhau, và ba số 0
  // đọc ra thành ba nhãn "Đang phát triển" — một lời khen dựng từ chỗ không có
  // dữ liệu. Hàm này để màn hình phân biệt được trước khi dựng nhãn.
  group('scaTouchedCount', () {
    final situations = [
      _sit('s-a', ScaDimension.s1),
      _sit('c-a', ScaDimension.c2),
      _sit('pos', ScaDimension.pAchieve),
    ];

    test('đếm đúng số lần rơi vào một trụ', () {
      expect(scaTouchedCount([..._p('s-a', 3), ..._p('c-a', 2)], situations), 5);
    });

    test('tình huống tích cực không tính — nó không thuộc trụ nào', () {
      expect(scaTouchedCount(_p('pos', 20), situations), 0);
    });

    test('mã không có trong danh mục thì không tính', () {
      expect(scaTouchedCount(_p('khong-ton-tai', 20), situations), 0);
    });

    test('danh mục rỗng thì không tra được trụ nào', () {
      // Đây là trạng thái thật lúc thư viện tình huống chưa tải xong.
      expect(scaTouchedCount(_p('s-a', 15), const []), 0);
    });

    test('rỗng thì 0', () {
      expect(scaTouchedCount(const [], situations), 0);
    });
  });

  // `behaviourPillarLabel` / `behaviourPillarIsHealthy` ĐÃ BỎ, cùng cả nhóm
  // test của chúng. Changelog CareerSnapshot §2 cấm gán nhãn đánh giá cho một
  // con số tần suất — quay lại nhóm Mối quan hệ 14 lần có thể vì đang gặp vấn
  // đề, cũng có thể vì đang chủ động làm việc với nó. Cột "Xuất hiện" nay chỉ
  // nói số lần trên tổng.

  group('pillarReflectionCounts', () {
    final situations = [
      _sit('s-a', ScaDimension.s1),
      _sit('c-a', ScaDimension.c2),
      _sit('a-a', ScaDimension.a2),
      _sit('pos', ScaDimension.pAchieve),
    ];

    test('đếm đúng số lần từng trụ', () {
      final counts = pillarReflectionCounts(
        [..._e('s-a', 5), ..._e('c-a', 14), ..._e('a-a', 8)],
        situations,
      );
      expect(counts[SelfCheckPillar.s], 5);
      expect(counts[SelfCheckPillar.c], 14);
      expect(counts[SelfCheckPillar.a], 8);
    });

    test('tình huống tích cực không thuộc trụ nào', () {
      final counts = pillarReflectionCounts(_e('pos', 20), situations);
      for (final p in SelfCheckPillar.values) {
        expect(counts[p], 0);
      }
    });

    test('lượt không có mã tình huống thì bỏ qua', () {
      final counts = pillarReflectionCounts(
        [..._e('s-a', 3), _episode(null)],
        situations,
      );
      expect(counts[SelfCheckPillar.s], 3);
    });

    // Chính cái bẫy §8 của changelog: `recentSituationIds` chặn ở 30 mục gần
    // nhất, nên đi qua nó thì người đã nhìn lại 80 lần vẫn đọc được "14 / 30".
    test('KHÔNG bị chặn ở cửa sổ 30 mục gần nhất', () {
      final counts = pillarReflectionCounts(_e('c-a', 80), situations);
      expect(counts[SelfCheckPillar.c], 80);
    });
  });

  group('dominantPillar', () {
    Map<SelfCheckPillar, int> counts(int s, int c, int a) => {
          SelfCheckPillar.s: s,
          SelfCheckPillar.c: c,
          SelfCheckPillar.a: a,
        };

    test('vượt 40% tổng thì là trụ nổi trội', () {
      // 14/27 = 51.9%
      expect(dominantPillar(counts(5, 14, 8), 27), SelfCheckPillar.c);
    });

    // Diễn giải sâu §2 nêu đích danh ví dụ này: 10/9/8 mà vẫn tuyên bố có một
    // trụ nổi trội là khẳng định một xu hướng không thật.
    test('phân bố tương đối đều thì trả null', () {
      expect(dominantPillar(counts(10, 9, 8), 27), isNull);
    });

    test('đúng 40% chưa đủ, phải VƯỢT', () {
      expect(dominantPillar(counts(4, 4, 2), 10), isNull);
      expect(dominantPillar(counts(4, 5, 1), 10), SelfCheckPillar.c);
    });

    // Mẫu số là tổng số lần nhìn lại, không phải tổng ba trụ: nếu phần lớn lượt
    // là tình huống tích cực hoặc tự viết, thì không trụ nào thật sự nổi trội
    // trong bức tranh mà người dùng đang nhìn.
    test('nhiều lượt không thuộc trụ nào thì không ai nổi trội', () {
      expect(dominantPillar(counts(0, 15, 0), 100), isNull);
    });

    test('chưa nhìn lại lần nào thì trả null', () {
      expect(dominantPillar(counts(0, 0, 0), 0), isNull);
    });

    // Ngưỡng 40% một mình không đủ: hoà 3–3–0 thì trụ đầu chiếm 50%, vượt
    // ngưỡng, nhưng chọn nó chỉ là chọn theo thứ tự khai báo enum.
    test('hoà thì trả null dù có vượt 40%', () {
      expect(dominantPillar(counts(3, 3, 0), 6), isNull);
      expect(dominantPillar(counts(5, 5, 5), 15), isNull);
    });
  });

  group('selfCheckIsStale', () {
    final now = DateTime(2026, 9, 10);

    test('ngưỡng là 90 ngày', () {
      expect(kSelfCheckStaleDays, 90);
    });

    test('vừa làm hôm qua thì chưa cũ', () {
      expect(selfCheckIsStale(now.subtract(const Duration(days: 1)), now),
          isFalse);
    });

    test('89 ngày chưa cũ, 90 ngày là cũ', () {
      expect(selfCheckIsStale(now.subtract(const Duration(days: 89)), now),
          isFalse);
      expect(
          selfCheckIsStale(now.subtract(const Duration(days: 90)), now), isTrue);
    });

    test('ngày in ra dạng dd/MM/yyyy', () {
      expect(selfCheckDateLabel(DateTime(2026, 5, 20)), '20/05/2026');
    });
  });
}
