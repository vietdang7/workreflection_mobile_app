// SCA Self-Check — diễn giải sâu, phát hiện mất cân bằng, xu hướng, đối chiếu Pattern.
// Spec: Kiến trúc Dữ liệu Hai Lớp v1.2 §II.
//   Free  — kết quả tức thời cho từng trụ, không lưu xu hướng.
//   Paid  — diễn giải sâu theo khoảng điểm, phát hiện mất cân bằng giữa các trụ,
//           theo dõi xu hướng qua nhiều lần, đối chiếu chéo với Pattern.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_narrative.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

ScaSelfCheckResponse _resp(
  double s,
  double c,
  double a, {
  required DateTime at,
}) =>
    ScaSelfCheckResponse(
      userId: 'u1',
      answers: const {},
      structureScore: s,
      cultureScore: c,
      activityScore: a,
      takenAt: at,
    );


WrSituation _sitOf(String code, ScaDimension dim) => WrSituation(
      code: code,
      text: code,
      scaDimension: dim,
      wave: 1,
    );

void main() {
  group('bandForScore', () {
    test('dùng đúng 4 khoảng điểm của bộ narrative sẵn có', () {
      expect(bandForScore(5.0), SelfCheckBand.strong);
      expect(bandForScore(4.2), SelfCheckBand.strong);
      expect(bandForScore(4.19), SelfCheckBand.adequate);
      expect(bandForScore(3.5), SelfCheckBand.adequate);
      expect(bandForScore(3.49), SelfCheckBand.friction);
      expect(bandForScore(2.8), SelfCheckBand.friction);
      expect(bandForScore(2.79), SelfCheckBand.blocked);
      expect(bandForScore(0), SelfCheckBand.blocked);
    });
  });

  group('pillarNarrative', () {
    test('mỗi trụ × mỗi khoảng đều có tiêu đề và nội dung', () {
      for (final p in SelfCheckPillar.values) {
        for (final score in [4.6, 3.8, 3.0, 1.5]) {
          final n = pillarNarrative(p, score);
          expect(n.title.trim(), isNotEmpty, reason: '$p @ $score');
          expect(n.text.trim().length, greaterThan(60), reason: '$p @ $score');
          expect(n.pillar, p);
          expect(n.band, bandForScore(score));
        }
      }
    });

    test('không lộ mã nội bộ S1/C2/A4 ra nội dung hiển thị', () {
      final leak = RegExp(r'\b[SCA][1-4]\b');
      for (final p in SelfCheckPillar.values) {
        for (final score in [4.6, 3.8, 3.0, 1.5]) {
          final n = pillarNarrative(p, score);
          expect(leak.hasMatch(n.title), isFalse);
          expect(leak.hasMatch(n.text), isFalse);
        }
      }
    });

    test('dùng tên trụ thân thiện, không dùng Structure/Culture/Activity', () {
      final n = pillarNarrative(SelfCheckPillar.s, 3.0);
      expect(n.pillarName, 'Sự rõ ràng');
    });
  });

  group('detectPillarImbalance', () {
    test('ba trụ đều thấp → allLow', () {
      expect(detectPillarImbalance(2.5, 2.2, 2.7), PillarImbalance.allLow);
    });

    test('chênh lệch dưới ngưỡng 0.8 → không có mất cân bằng', () {
      expect(detectPillarImbalance(3.6, 3.9, 4.0), isNull);
      expect(detectPillarImbalance(4.0, 4.0, 4.0), isNull);
    });

    test('một trụ thấp rõ rệt (<2.8 và kém trung bình ≥1.0)', () {
      expect(detectPillarImbalance(2.2, 4.0, 4.1), PillarImbalance.sNotablyLow);
      expect(detectPillarImbalance(4.0, 2.2, 4.1), PillarImbalance.cNotablyLow);
      expect(detectPillarImbalance(4.0, 4.1, 2.2), PillarImbalance.aNotablyLow);
    });

    test('cặp lệch ≥0.8 khi chưa trụ nào xuống dưới 2.8', () {
      expect(detectPillarImbalance(3.0, 4.2, 3.4), PillarImbalance.cHighSLow);
      expect(detectPillarImbalance(4.2, 3.0, 3.4), PillarImbalance.sHighCLow);
    });

    test('trụ cách làm việc cao hơn hẳn hai trụ còn lại', () {
      expect(detectPillarImbalance(3.0, 3.1, 4.2), PillarImbalance.aHighScLow);
    });

    test('thiếu điểm thì không kết luận', () {
      expect(detectPillarImbalance(null, 3.0, 3.0), isNull);
    });

    test('mọi mất cân bằng đều có narrative không rỗng', () {
      for (final k in PillarImbalance.values) {
        expect(imbalanceNarrative(k).trim().length, greaterThan(60),
            reason: '$k');
      }
    });
  });

  group('trendFromHistory', () {
    final now = DateTime(2026, 7, 25);

    test('ít hơn 2 lần trả lời → chưa có xu hướng', () {
      expect(trendFromHistory(const []), isNull);
      expect(
        trendFromHistory([_resp(3, 3, 3, at: now)]),
        isNull,
      );
    });

    test('so lần mới nhất với lần liền trước', () {
      final trend = trendFromHistory([
        _resp(4.0, 3.0, 3.5, at: now),
        _resp(3.0, 3.4, 3.5, at: now.subtract(const Duration(days: 30))),
      ])!;
      expect(trend.structureDelta, closeTo(1.0, 0.001));
      expect(trend.cultureDelta, closeTo(-0.4, 0.001));
      expect(trend.activityDelta, closeTo(0.0, 0.001));
      expect(trend.takenCount, 2);
    });

    test('tự sắp xếp khi lịch sử không theo thứ tự', () {
      final trend = trendFromHistory([
        _resp(3.0, 3.0, 3.0, at: now.subtract(const Duration(days: 30))),
        _resp(4.0, 3.0, 3.0, at: now),
      ])!;
      expect(trend.structureDelta, closeTo(1.0, 0.001));
    });

    test('bỏ qua bản ghi thiếu điểm', () {
      final trend = trendFromHistory([
        _resp(4.0, 4.0, 4.0, at: now),
        ScaSelfCheckResponse(
          userId: 'u1',
          answers: const {},
          takenAt: now.subtract(const Duration(days: 10)),
        ),
        _resp(3.0, 3.0, 3.0, at: now.subtract(const Duration(days: 30))),
      ])!;
      expect(trend.structureDelta, closeTo(1.0, 0.001));
      expect(trend.takenCount, 2);
    });

    test('mô tả xu hướng bằng ngôn ngữ đời thường', () {
      final up = trendFromHistory([
        _resp(4.2, 4.2, 4.2, at: now),
        _resp(3.0, 3.0, 3.0, at: now.subtract(const Duration(days: 30))),
      ])!;
      expect(up.summary, contains('cải thiện'));

      final flat = trendFromHistory([
        _resp(3.0, 3.0, 3.0, at: now),
        _resp(3.05, 3.0, 3.0, at: now.subtract(const Duration(days: 30))),
      ])!;
      expect(flat.summary, contains('gần như không đổi'));
    });
  });

  // Từ 2026-07-31 khối "Đối chiếu với điều bạn hay gặp" đọc recentSituationIds
  // thay vì `wr_pattern_counts` (Kiến trúc v2.0 §4.3 — "đối chiếu" là một trong
  // các tính năng bắt buộc dùng nguồn duy nhất).
  group('patternsForPillar', () {
    List<String> rep(String code, int n) => List.filled(n, code);

    final situations = [
      _sitOf('C2-sit-01', ScaDimension.c2),
      _sitOf('S1-sit-01', ScaDimension.s1),
      _sitOf('C1-sit-01', ScaDimension.c1),
      _sitOf('A3-sit-01', ScaDimension.a3),
    ];
    final recent = [
      ...rep('C2-sit-01', 5),
      ...rep('S1-sit-01', 4),
      ...rep('C1-sit-01', 3),
      ...rep('A3-sit-01', 2),
    ];

    test('lọc theo trụ, giữ thứ tự số lần lặp giảm dần', () {
      final c = patternsForPillar(SelfCheckPillar.c, recent, situations);
      expect(c.map((p) => p.situationCode), ['C2-sit-01', 'C1-sit-01']);

      final s = patternsForPillar(SelfCheckPillar.s, recent, situations);
      expect(s.map((p) => p.situationCode), ['S1-sit-01']);

      final a = patternsForPillar(SelfCheckPillar.a, recent, situations);
      expect(a.map((p) => p.situationCode), ['A3-sit-01']);
    });

    test('bỏ qua tình huống không có trong danh mục', () {
      final res = patternsForPillar(
        SelfCheckPillar.c,
        rep('khong-ton-tai', 9),
        situations,
      );
      expect(res, isEmpty);
    });

    test('giới hạn số lượng trả về', () {
      final manySits = [
        for (var i = 0; i < 10; i++) _sitOf('C2-sit-0$i', ScaDimension.c2),
      ];
      final manyRecent = [
        for (var i = 0; i < 10; i++) ...rep('C2-sit-0$i', 10 - i),
      ];
      expect(
        patternsForPillar(SelfCheckPillar.c, manyRecent, manySits, limit: 3),
        hasLength(3),
      );
    });
  });

  group('lowestPillar', () {
    test('trả về trụ có điểm thấp nhất', () {
      expect(lowestPillar(4.0, 2.5, 3.2), SelfCheckPillar.c);
      expect(lowestPillar(2.0, 2.5, 3.2), SelfCheckPillar.s);
      expect(lowestPillar(4.0, 4.5, 3.2), SelfCheckPillar.a);
    });

    test('hoà điểm thì ưu tiên theo thứ tự S → C → A (ổn định)', () {
      expect(lowestPillar(3.0, 3.0, 3.0), SelfCheckPillar.s);
    });
  });
}
