// "Diễn giải sâu & xu hướng" — ba lớp cho mỗi trụ.
//
// Nguồn: WorkReflection_Changelog_20260824.docx §7.
//
// Run: flutter test test/core/logic/wr_sca_deep_dive_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_sca_deep_dive.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

final _now = DateTime(2026, 8, 25, 10);

ScaSelfCheckResponse _check({
  required DateTime at,
  double s = 3.0,
  double c = 3.0,
  double a = 3.0,
}) =>
    ScaSelfCheckResponse(
      userId: 'u1',
      answers: const {},
      takenAt: at,
      structureScore: s,
      cultureScore: c,
      activityScore: a,
    );

ReflectionEpisode _ep(String code, DateTime openedAt) => ReflectionEpisode(
      userId: 'u1',
      humanMoment: HumanMoment.confusion,
      situationCode: code,
      openedAt: openedAt,
    );

const _situations = <WrSituation>[
  WrSituation(code: 'S1-01', text: 'Vai trò chưa rõ', scaDimension: ScaDimension.s1, wave: 1),
  WrSituation(code: 'C2-01', text: 'Không dám nói', scaDimension: ScaDimension.c2, wave: 1),
  WrSituation(code: 'A3-01', text: 'Việc bị cắt ngang', scaDimension: ScaDimension.a3, wave: 1),
];

void main() {
  group('Lớp 1 · mức điểm dùng chung với màn Kết quả', () {
    test('ba mức theo ngưỡng 3.8 / 2.5 của màn Kết quả Self-Check', () {
      expect(scaPillarStatus(4.2), ScaPillarStatus.developing);
      expect(scaPillarStatus(3.8), ScaPillarStatus.developing);
      expect(scaPillarStatus(3.79), ScaPillarStatus.needsAttention);
      expect(scaPillarStatus(2.5), ScaPillarStatus.needsAttention);
      expect(scaPillarStatus(2.49), ScaPillarStatus.priority);
    });

    test('nhãn đúng nguyên văn màn Kết quả', () {
      expect(ScaPillarStatus.developing.label, 'Đang phát triển');
      expect(ScaPillarStatus.needsAttention.label, 'Cần chú ý');
      expect(ScaPillarStatus.priority.label, 'Ưu tiên cải thiện');
    });

    // "Cần chú ý" không phải lời tự nhận là ổn — gộp nó vào nhóm ổn thì câu
    // lệch pha sẽ bịa lại lời người dùng.
    test('chỉ mức cao nhất mới được coi là tự đánh giá ổn', () {
      expect(ScaPillarStatus.developing.isReassuring, isTrue);
      expect(ScaPillarStatus.needsAttention.isReassuring, isFalse);
      expect(ScaPillarStatus.priority.isReassuring, isFalse);
    });
  });

  group('Lớp 2 · xu hướng so với lần Self-Check trước', () {
    final prev = _check(at: DateTime(2026, 7, 20), s: 3.0);

    test('chưa có lần trước thì không có câu nào', () {
      expect(
        scaTrendText(pillar: SelfCheckPillar.s, score: 3.0, previous: null),
        isNull,
      );
    });

    test('chênh dưới 0.15 là gần như không đổi, kèm ngày lần trước', () {
      expect(
        scaTrendText(pillar: SelfCheckPillar.s, score: 3.1, previous: prev),
        'Gần như không đổi so với lần trước (20/07/2026).',
      );
    });

    test('tăng và giảm nói đúng chiều', () {
      expect(
        scaTrendText(pillar: SelfCheckPillar.s, score: 3.6, previous: prev),
        'Tăng nhẹ so với lần trước (20/07/2026).',
      );
      expect(
        scaTrendText(pillar: SelfCheckPillar.s, score: 2.4, previous: prev),
        'Giảm nhẹ so với lần trước (20/07/2026).',
      );
    });

    test('lần trước thiếu điểm trụ đó thì im lặng, không so bừa với 0', () {
      final noScore = ScaSelfCheckResponse(
        userId: 'u1',
        answers: const {},
        takenAt: DateTime(2026, 7, 20),
      );
      expect(
        scaTrendText(pillar: SelfCheckPillar.s, score: 3.0, previous: noScore),
        isNull,
      );
    });

    test('ngày luôn có hai chữ số', () {
      expect(scaDateLabel(DateTime(2026, 1, 5)), '05/01/2026');
    });
  });

  group('Lớp 3 · cửa sổ 30 ngày lịch', () {
    // §7 ghi rõ đây là chỗ mockup làm sai: mockup đếm 30 MỤC gần nhất, còn chữ
    // trên màn thì nói 30 NGÀY.
    test('lấy đúng 30 ngày lịch, không lấy 30 mục gần nhất', () {
      final episodes = [
        for (var i = 0; i < 40; i++)
          _ep('S1-01', _now.subtract(Duration(days: i))),
      ];
      final window = episodesWithinDays(episodes, now: _now);
      expect(window.length, kScaPatternWindowDays);
    });

    test('mốc cắt tính theo ngày, hôm nay là ngày thứ nhất', () {
      final episodes = [
        _ep('S1-01', _now),
        _ep('S1-01', _now.subtract(const Duration(days: 29))),
        _ep('S1-01', _now.subtract(const Duration(days: 30))),
      ];
      expect(episodesWithinDays(episodes, now: _now).length, 2);
    });

    test('Episode không có ngày thì bị loại, không đội lốt lượt vừa xong', () {
      final episodes = [
        const ReflectionEpisode(
          userId: 'u1',
          humanMoment: HumanMoment.confusion,
          situationCode: 'S1-01',
        ),
        _ep('S1-01', _now),
      ];
      expect(episodesWithinDays(episodes, now: _now).length, 1);
    });
  });

  group('Lớp 3 · đếm và tìm nhóm nổi bật', () {
    test('đếm theo lượt, chọn lại cùng tình huống vẫn là nhiều lượt', () {
      final counts = pillarPatternCounts(
        [
          _ep('C2-01', _now),
          _ep('C2-01', _now.subtract(const Duration(days: 1))),
          _ep('C2-01', _now.subtract(const Duration(days: 2))),
          _ep('S1-01', _now.subtract(const Duration(days: 3))),
        ],
        _situations,
        now: _now,
      );
      expect(counts[SelfCheckPillar.c], 3);
      expect(counts[SelfCheckPillar.s], 1);
      expect(counts[SelfCheckPillar.a], 0);
    });

    test('lượt ngoài cửa sổ không được đếm', () {
      final counts = pillarPatternCounts(
        [
          _ep('C2-01', _now),
          _ep('C2-01', _now.subtract(const Duration(days: 45))),
        ],
        _situations,
        now: _now,
      );
      expect(counts[SelfCheckPillar.c], 1);
    });

    test('mã lạ không thuộc thư viện thì bỏ qua, không nhét vào trụ nào', () {
      final counts = pillarPatternCounts(
        [_ep('X9-99', _now)],
        _situations,
        now: _now,
      );
      expect(counts.values.every((v) => v == 0), isTrue);
    });

    test('nhóm nổi bật là nhóm nhiều lượt nhất', () {
      expect(
        dominantPatternPillar(const {
          SelfCheckPillar.s: 1,
          SelfCheckPillar.c: 4,
          SelfCheckPillar.a: 2,
        }),
        SelfCheckPillar.c,
      );
    });

    test('hoà thì không có nhóm nổi bật', () {
      expect(
        dominantPatternPillar(const {
          SelfCheckPillar.s: 3,
          SelfCheckPillar.c: 3,
          SelfCheckPillar.a: 0,
        }),
        isNull,
      );
    });

    test('chưa có lượt nào thì không có nhóm nổi bật', () {
      expect(
        dominantPatternPillar(const {
          SelfCheckPillar.s: 0,
          SelfCheckPillar.c: 0,
          SelfCheckPillar.a: 0,
        }),
        isNull,
      );
    });
  });

  group('Lớp 3 · ba nhánh template', () {
    const counts = {
      SelfCheckPillar.s: 0,
      SelfCheckPillar.c: 5,
      SelfCheckPillar.a: 2,
    };

    test('không có lượt nào thuộc trụ thì nói thẳng là chưa đủ tín hiệu', () {
      final t = scaPatternText(
        pillar: SelfCheckPillar.s,
        status: ScaPillarStatus.developing,
        counts: counts,
        dominant: SelfCheckPillar.c,
      );
      expect(t, contains('Chưa có đủ tín hiệu'));
    });

    test('có lượt nhưng không nổi bật thì nói đúng số lần', () {
      final t = scaPatternText(
        pillar: SelfCheckPillar.a,
        status: ScaPillarStatus.needsAttention,
        counts: counts,
        dominant: SelfCheckPillar.c,
      );
      expect(t, contains('2 lần'));
      expect(t, contains('chưa phải nhóm chiếm ưu thế nhất'));
    });

    // Đây là nhánh §7 gọi là "lớp giá trị nhất".
    test('tự chấm ổn mà lại là nhóm quay lại nhiều nhất → nói ra lệch pha', () {
      final t = scaPatternText(
        pillar: SelfCheckPillar.c,
        status: ScaPillarStatus.developing,
        counts: counts,
        dominant: SelfCheckPillar.c,
      );
      expect(t, contains('đang phát triển'));
      expect(t, contains('quay lại nhiều nhất'));
      expect(t, contains('5 lần'));
      expect(t, contains('chênh lệch'));
    });

    test('tự chấm không ổn và cũng là nhóm nổi bật → hai nguồn xác nhận nhau', () {
      final t = scaPatternText(
        pillar: SelfCheckPillar.c,
        status: ScaPillarStatus.priority,
        counts: counts,
        dominant: SelfCheckPillar.c,
      );
      expect(t, contains('xác nhận lẫn nhau'));
      expect(t, isNot(contains('chênh lệch')));
    });
  });

  group('Ghép cả màn', () {
    test('chưa làm Self-Check lần nào thì không dựng thẻ nào', () {
      expect(
        buildScaDeepDive(
          history: const [],
          episodes: const [],
          situations: _situations,
          now: _now,
        ),
        isEmpty,
      );
    });

    test('lần trả lời thiếu điểm không được tính là một lần', () {
      final history = [
        ScaSelfCheckResponse(
          userId: 'u1',
          answers: const {},
          takenAt: DateTime(2026, 8, 20),
        ),
      ];
      expect(
        buildScaDeepDive(
          history: history,
          episodes: const [],
          situations: _situations,
          now: _now,
        ),
        isEmpty,
      );
    });

    test('đủ ba trụ, đúng thứ tự S · C · A, lấy điểm của lần mới nhất', () {
      final history = [
        _check(at: DateTime(2026, 7, 1), s: 2.0, c: 2.0, a: 2.0),
        _check(at: DateTime(2026, 8, 20), s: 4.0, c: 3.0, a: 2.0),
      ];
      final pillars = buildScaDeepDive(
        history: history,
        episodes: const [],
        situations: _situations,
        now: _now,
      );

      expect(pillars.map((p) => p.pillar).toList(), SelfCheckPillar.values);
      expect(pillars[0].score, 4.0);
      expect(pillars[0].status, ScaPillarStatus.developing);
      // Lần mới nhất là 20/08, lần trước là 01/07 — cả ba trụ đều tăng.
      expect(pillars[0].trendText, contains('01/07/2026'));
      expect(pillars[0].trendText, contains('Tăng nhẹ'));
    });

    test('lịch sử không sắp sẵn vẫn nhận đúng đâu là lần mới nhất', () {
      final history = [
        _check(at: DateTime(2026, 8, 20), s: 4.0),
        _check(at: DateTime(2026, 7, 1), s: 2.0),
      ];
      final reversed = history.reversed.toList();
      expect(
        buildScaDeepDive(
          history: reversed,
          episodes: const [],
          situations: _situations,
          now: _now,
        ).first.score,
        4.0,
      );
    });

    test('mỗi trụ đều có câu Lớp 3, kể cả trụ không có lượt nào', () {
      final pillars = buildScaDeepDive(
        history: [_check(at: DateTime(2026, 8, 20), s: 4.5, c: 4.5, a: 4.5)],
        episodes: [
          for (var i = 0; i < 4; i++)
            _ep('C2-01', _now.subtract(Duration(days: i))),
        ],
        situations: _situations,
        now: _now,
      );

      for (final p in pillars) {
        expect(p.patternText.trim(), isNotEmpty, reason: p.pillar.name);
      }
      final c = pillars.firstWhere((p) => p.pillar == SelfCheckPillar.c);
      expect(c.isDominant, isTrue);
      expect(c.patternCount, 4);
      expect(c.patternText, contains('chênh lệch'));

      final s = pillars.firstWhere((p) => p.pillar == SelfCheckPillar.s);
      expect(s.isDominant, isFalse);
      expect(s.patternText, contains('Chưa có đủ tín hiệu'));
    });

    test('chú thích cuối màn nói đúng cửa sổ và ngày lần trước', () {
      expect(scaDeepDiveFootnote(null), contains('chưa có'));
      expect(
        scaDeepDiveFootnote(_check(at: DateTime(2026, 7, 20))),
        contains('20/07/2026'),
      );
      expect(scaDeepDiveFootnote(null), contains('30 ngày'));
    });
  });

  // ── Khung "Lệch pha tự nhận thức" — §9, khung thứ ba của Insight ─────────
  //
  // Câu này dựng ở đây chứ không ở `wr_career_memory_rules.dart`: §9 nói thẳng
  // "tái dùng logic đã có ở Diễn giải sâu", và tính lại bên kia là dựng nguồn
  // sự thật thứ hai cho cùng một chênh lệch.

  group('selfAwarenessGapNarrative', () {
    List<ReflectionEpisode> fourCulture() => [
          for (var i = 0; i < 4; i++)
            _ep('C2-01', _now.subtract(Duration(days: i + 1))),
        ];

    test('tự chấm là ổn nhưng quay lại nhiều nhất → có câu', () {
      final text = selfAwarenessGapNarrative(
        history: [_check(at: _now.subtract(const Duration(days: 3)), c: 4.2)],
        episodes: fourCulture(),
        situations: _situations,
        now: _now,
      );

      expect(text, isNotNull);
      expect(text, contains('4 lần'));
      expect(text, contains('đang phát triển'));
    });

    test('tự chấm đã thấp thì KHÔNG phải lệch pha', () {
      // Hai nguồn xác nhận lẫn nhau không phải một Insight — đó là điều người
      // dùng đã biết.
      expect(
        selfAwarenessGapNarrative(
          history: [_check(at: _now, c: 2.0)],
          episodes: fourCulture(),
          situations: _situations,
          now: _now,
        ),
        isNull,
      );
    });

    test('chưa từng tự đánh giá thì im lặng', () {
      // §9: điều kiện kích hoạt là "có CẢ dữ liệu Self-Check lẫn Reflection".
      expect(
        selfAwarenessGapNarrative(
          history: const [],
          episodes: fourCulture(),
          situations: _situations,
          now: _now,
        ),
        isNull,
      );
    });

    test('không có nhóm nào chiếm ưu thế thì im lặng', () {
      expect(
        selfAwarenessGapNarrative(
          history: [_check(at: _now, c: 4.2, s: 4.2)],
          episodes: [
            _ep('C2-01', _now.subtract(const Duration(days: 1))),
            _ep('S1-01', _now.subtract(const Duration(days: 2))),
          ],
          situations: _situations,
          now: _now,
        ),
        isNull,
      );
    });

    test('chỉ đếm trong cửa sổ 30 ngày', () {
      expect(
        selfAwarenessGapNarrative(
          history: [_check(at: _now, c: 4.2)],
          episodes: [
            for (var i = 0; i < 4; i++)
              _ep('C2-01', _now.subtract(Duration(days: 60 + i))),
          ],
          situations: _situations,
          now: _now,
        ),
        isNull,
      );
    });
  });
}
