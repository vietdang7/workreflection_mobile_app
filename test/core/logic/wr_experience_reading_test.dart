// Luật đọc "Trải nghiệm của bạn" — "Logic đọc hiểu mình.docx" (15/10/2026).
//
// Run: flutter test test/core/logic/wr_experience_reading_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_experience_reading.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';

final _ids = [
  for (var i = 1; i <= 15; i++) 'scq-${i.toString().padLeft(2, '0')}',
];

Map<String, dynamic> _answers(Map<int, int> overrides, {int base = 4}) => {
  for (var i = 1; i <= 15; i++) _ids[i - 1]: overrides[i] ?? base,
};

void main() {
  setUp(() => wrSetLocale('vi'));

  group('ba mức của một câu', () {
    test('4–5 nâng đỡ, 3 thất thường, 1–2 cản trở', () {
      expect(condLevelOf(5), CondLevel.up);
      expect(condLevelOf(4), CondLevel.up);
      // "Đôi khi" không dồn vào phía nào cho gọn.
      expect(condLevelOf(3), CondLevel.mid);
      expect(condLevelOf(2), CondLevel.down);
      expect(condLevelOf(1), CondLevel.down);
    });

    // Tài liệu đặt trần chín chữ mỗi cụm; cụm câu 11 mức giữa của tài liệu
    // dài mười chữ nên đã rút "của" (15/10).
    test('đủ 45 cụm, mỗi cụm tối đa chín chữ', () {
      expect(kCondPhrases.keys, _ids);
      for (final p in kCondPhrases.values) {
        for (final t in [p.up, p.mid, p.down]) {
          expect(t.split(' ').length, lessThanOrEqualTo(9), reason: t);
        }
      }
      expect(
        kCondPhrases['scq-11']!.mid,
        'Mối nối giữa việc bạn và mục tiêu chung',
      );
    });

    test('giá trị lạ bị bỏ qua, không bị đếm thành cản trở', () {
      final s = condSplit({
        'scq-01': 0,
        'scq-02': 'x',
        'scq-03': 3,
      }, SelfCheckPillar.s);
      expect(s.answered, 1);
      expect(s.mid, ['scq-03']);
    });
  });

  group('nhãn của một nhóm', () {
    test('một câu điểm 1 giữa bốn câu tốt: nhãn nói ra câu đó', () {
      final l = pillarCondLabel(_answers({1: 1}, base: 5), SelfCheckPillar.s);
      expect(l.text, '1 điều đang cản trở');
      expect(l.blocked, isTrue);
    });

    test('ngưỡng 3,8 / 2,6 trên thang 1–5', () {
      // 4,4,4,3,4 → 3,8.
      expect(
        pillarCondLabel(_answers({4: 3}), SelfCheckPillar.s).text,
        'Đang nâng đỡ bạn',
      );
      // 4,3,3,3,4 → 3,4.
      expect(
        pillarCondLabel(_answers({2: 3, 3: 3, 4: 3}), SelfCheckPillar.s).text,
        'Nâng đỡ nhưng chưa đều',
      );
    });

    test('chưa trả lời thì "Chưa đánh giá"', () {
      expect(
        pillarCondLabel(const {}, SelfCheckPillar.a).text,
        'Chưa đánh giá',
      );
    });

    test('dòng phụ: hai cụm, phần còn lại đếm gộp', () {
      final s = condSplit(
        _answers({11: 2, 12: 2, 13: 1, 14: 2}),
        SelfCheckPillar.a,
      );
      expect(
        pillarCondSubline(s),
        'Đang cản trở: Chưa thấy việc mình gắn với mục tiêu chung · Mục tiêu '
        'đổi mà biết muộn · và 2 điều nữa',
      );
      final all3 = condSplit(_answers({}, base: 3), SelfCheckPillar.c);
      expect(
        pillarCondSubline(all3),
        'Cả 5 điều ở nhóm này đều còn thất thường',
      );
    });
  });

  group('câu nối chuỗi cản trở chỉ dùng khi nó đúng', () {
    test('A đúng ba điều 11·12·14: dùng câu viết sẵn', () {
      final s = condSplit(_answers({11: 2, 12: 2, 14: 2}), SelfCheckPillar.a);
      expect(pillarCondLead(SelfCheckPillar.a, s), startsWith('Ba điều'));
    });

    test('A cản trở ở 13·15: KHÔNG dùng câu gọi tên 11·12·14', () {
      final s = condSplit(_answers({13: 2, 15: 1}), SelfCheckPillar.a);
      expect(
        pillarCondLead(SelfCheckPillar.a, s),
        '2 điều ở nhóm này đang cản trở bạn: nhịp phối hợp chưa đều và điều '
        'chỉnh nói rồi để đó.',
      );
      expect(
        blockedChainFragment(SelfCheckPillar.a, s),
        'nhịp phối hợp chưa đều và điều chỉnh nói rồi để đó',
      );
    });

    test('mảnh chuỗi cản trở ghép từ cụm chỉ lấy hai cụm đầu', () {
      final s = condSplit(
        _answers({6: 1, 7: 1, 8: 1, 9: 1, 10: 1}),
        SelfCheckPillar.c,
      );
      expect(s.down, hasLength(5));
      final p = s.phrasesOf(CondLevel.down);
      String low(String x) => x[0].toLowerCase() + x.substring(1);
      expect(
        blockedChainFragment(SelfCheckPillar.c, s),
        '${low(p[0])} và ${low(p[1])}',
      );
    });

    test(
      'S có thêm câu 5 (thay đổi bất ngờ): không còn "đều ở lúc bắt đầu"',
      () {
        final ok = condSplit(_answers({1: 2, 2: 2}), SelfCheckPillar.s);
        expect(pillarCondLead(SelfCheckPillar.s, ok), contains('lúc bắt đầu'));
        final off = condSplit(_answers({1: 2, 2: 2, 5: 2}), SelfCheckPillar.s);
        expect(
          pillarCondLead(SelfCheckPillar.s, off),
          isNot(contains('lúc bắt đầu')),
        );
      },
    );

    test('một điều thì gọi đúng tên điều đó, không dựng chuỗi', () {
      final s = condSplit(_answers({8: 2}), SelfCheckPillar.c);
      expect(
        pillarCondLead(SelfCheckPillar.c, s),
        'Một điều ở nhóm này đang cản trở bạn: nói khác số đông còn e dè.',
      );
    });
  });

  group('Tổng quan', () {
    OverviewInputs inputs(Map<String, dynamic> answers, {int dom = 9}) =>
        OverviewInputs(
          dom: SelfCheckPillar.c,
          domCount: dom,
          total: 16,
          answers: answers,
        );

    test('không cản trở: bắt đầu từ nhóm dom', () {
      final o = buildOverview(inputs(_answers({})));
      expect(o.kind, OverviewCase.noBlock);
      expect(o.startPillar, SelfCheckPillar.c);
      expect(o.link, isNull);
    });

    test('hoà số điều cản trở mà dom nằm trong đó: trùng nhau', () {
      final o = buildOverview(inputs(_answers({1: 2, 8: 2})));
      expect(o.kind, OverviewCase.aligned);
      expect(o.key, 'aligned:c:c');
    });

    test('lệch nhau: bắt đầu từ nhóm blocked, câu nối ghép từ dữ liệu', () {
      final o = buildOverview(inputs(_answers({4: 1, 5: 2})));
      expect(o.kind, OverviewCase.diverged);
      expect(o.startPillar, SelfCheckPillar.s);
      expect(
        o.link,
        startsWith(
          'Hai chuyện này thường có liên hệ. Khi thông tin nằm rải '
          'nhiều nơi và thay đổi thường đến bất ngờ, những chuyện bạn ghi lại '
          'ở Mối quan hệ cũng khó tự nhẹ đi.',
        ),
      );
    });

    test('chưa quá nửa thì không nói "phần lớn"', () {
      final o = buildOverview(inputs(_answers({4: 1}), dom: 6));
      expect(o.body, startsWith('Những gì bạn ghi lại nằm nhiều nhất ở'));
    });

    test('lệch nhau: có mảnh AI thì câu nối dùng mảnh đó', () {
      final i = OverviewInputs(
        dom: SelfCheckPillar.c,
        domCount: 9,
        total: 16,
        answers: _answers({4: 1, 5: 2}),
        hardPart: 'việc nói ra mà không đến nơi',
        hardPartLocale: 'vi',
      );
      expect(
        buildOverview(i).link,
        contains(', việc nói ra mà không đến nơi cũng khó tự nhẹ đi.'),
      );
      // Mảnh viết bằng tiếng Anh thì không ghép vào câu tiếng Việt.
      final en = OverviewInputs.fromJson({
        ...i.toJson(),
        'hard_part_locale': 'en',
      })!;
      expect(
        buildOverview(en).link,
        contains('những chuyện bạn ghi lại ở Mối quan hệ cũng khó tự nhẹ đi'),
      );
    });

    test('mảnh AI được lưu cùng bản đọc', () {
      final i = OverviewInputs(
        dom: SelfCheckPillar.c,
        domCount: 9,
        total: 16,
        answers: _answers({4: 1}),
        hardPart: 'việc nói ra mà không đến nơi',
        hardPartLocale: 'vi',
      );
      final back = OverviewInputs.fromJson(i.toJson())!;
      expect(back.hardPart, i.hardPart);
      expect(buildOverview(back).link, buildOverview(i).link);
    });

    test('đầu vào lưu được rồi dựng lại đúng bản cũ', () {
      final i = inputs(_answers({11: 2, 12: 2, 14: 2}));
      final back = OverviewInputs.fromJson(i.toJson())!;
      expect(buildOverview(back).key, buildOverview(i).key);
      expect(buildOverview(back).link, buildOverview(i).link);
      expect(OverviewInputs.fromJson(const {}), isNull);
    });
  });

  test('khảo sát quá ba tháng thì cũ', () {
    final t = DateTime(2026, 7, 10);
    expect(surveyIsStale(t, DateTime(2026, 10, 9)), isFalse);
    expect(surveyIsStale(t, DateTime(2026, 10, 11)), isTrue);
  });

  test('bản tiếng Anh không lọt chữ Việt', () {
    wrSetLocale('en');
    final s = condSplit(_answers({13: 2, 15: 1}), SelfCheckPillar.a);
    expect(
      pillarCondLead(SelfCheckPillar.a, s),
      '2 things in this group are holding you back: an uneven working rhythm '
      'and adjustments get talked about, then dropped.',
    );
    expect(
      pillarCondLabel(_answers({}), SelfCheckPillar.a).text,
      'Supporting you',
    );
  });

  group('những chuyện đang quay lại', () {
    const situations = [
      WrSituation(
        code: 'C2-01',
        text: 'Không dám nói',
        scaDimension: ScaDimension.c2,
        wave: 1,
        pillarCode: 'C',
        subgroup: 'C2',
        mood: 'stress',
        valence: WrValence.thachThuc,
      ),
      WrSituation(
        code: 'C2-02',
        text: 'Ý kiến bị bỏ qua',
        scaDimension: ScaDimension.c2,
        wave: 1,
        pillarCode: 'C',
        subgroup: 'C2',
        mood: 'stress',
        valence: WrValence.thachThuc,
      ),
      WrSituation(
        code: 'C3-P',
        text: 'Đồng nghiệp hỗ trợ',
        scaDimension: ScaDimension.c3,
        wave: 1,
        pillarCode: 'C',
        subgroup: 'C3',
        mood: 'happy',
        valence: WrValence.tichCuc,
      ),
    ];
    final t0 = DateTime.utc(2026, 10, 1, 3);
    ReflectionEpisode ep(String code, int day, [String? note]) =>
        ReflectionEpisode(
          userId: 'u1',
          humanMoment: HumanMoment.confusion,
          situationCode: code,
          openedAt: t0.add(Duration(days: day)),
          notes: {if (note != null) ReflectionPattern.explore.dbValue: note},
        );

    test('từ 2 lần mới vào danh sách; không lấy tình huống tích cực', () {
      final stories = recurringStories(
        [
          ep('C2-01', 0, 'Họp xong mới nghĩ ra'),
          ep('C2-01', 3),
          ep('C2-01', 5, 'Nói mà không ai nghe'),
          ep('C2-02', 1),
          ep('C3-P', 2),
          ep('C3-P', 4),
        ],
        situations,
        SelfCheckPillar.c,
      );
      expect(stories.map((s) => s.code), ['C2-01']);
      final s = stories.single;
      expect(s.count, 3);
      expect(s.lines.map((l) => l.text), [
        'Nói mà không ai nghe',
        'Họp xong mới nghĩ ra',
      ]);
      expect(s.markOnly, 1);
      expect(s.lines.first.dateLabel, '06/10/2026');
    });

    test('ngưỡng viết câu: hai chuyện, hoặc một chuyện từ ba lần', () {
      RecurringStory st(int n) =>
          RecurringStory(code: 'x$n', title: 'x', count: n, lines: const []);
      expect(difficultyReadable([st(2)]), isFalse);
      expect(difficultyReadable([st(3)]), isTrue);
      expect(difficultyReadable([st(2), st(2)]), isTrue);
    });

    test('hai trích dẫn mới nhất, lấy chung mọi chuyện', () {
      final stories = recurringStories(
        [
          ep('C2-01', 0, 'a'),
          ep('C2-01', 9, 'b'),
          ep('C2-02', 4, 'c'),
          ep('C2-02', 6),
        ],
        situations,
        SelfCheckPillar.c,
      );
      expect(difficultyQuotes(stories).map((l) => l.text), ['b', 'c']);
    });

    test('chỉ gửi nhóm đủ ngưỡng', () {
      final c = recurringStories(
        [ep('C2-01', 0), ep('C2-01', 1), ep('C2-02', 2), ep('C2-02', 3)],
        situations,
        SelfCheckPillar.c,
      );
      final req = difficultyRequest({
        SelfCheckPillar.c: c,
        SelfCheckPillar.s: const [],
      });
      expect(req.map((r) => r['pillar']), ['c']);
      expect((req.single['stories'] as List).length, 2);
    });

    test('bản AI viết bằng ngôn ngữ khác thì không dùng', () {
      final r = ExperienceAiReading.fromJson({
        'locale': 'en',
        'pillars': {
          'c': {'shape': 'S', 'detail': 'D', 'hard_part': 'h'},
          's': {'shape': '', 'detail': 'D'},
        },
      });
      expect(r.pillars.keys, [SelfCheckPillar.c]);
      expect(r.of(SelfCheckPillar.c), isNull);
      wrSetLocale('en');
      expect(r.of(SelfCheckPillar.c)!.hardPart, 'h');
    });
  });
}
