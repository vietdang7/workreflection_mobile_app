// Luật đọc "Trải nghiệm của bạn" — "Logic đọc hiểu mình.docx" (15/10/2026).
//
// Run: flutter test test/core/logic/wr_experience_reading_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/logic/wr_experience_reading.dart';
import 'package:workreflection_mobile/core/logic/wr_self_check_questions.dart';

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

    // Tài liệu đặt trần chín chữ mỗi cụm, nhưng chính bảng của tài liệu có một
    // cụm mười chữ (câu 11, mức giữa). Giữ nguyên văn, chỉ cho phép đúng cụm đó.
    test('đủ 45 cụm, mỗi cụm tối đa chín chữ', () {
      expect(kCondPhrases.keys, _ids);
      for (final p in kCondPhrases.values) {
        for (final t in [p.up, p.mid, p.down]) {
          if (t == 'Mối nối giữa việc của bạn và mục tiêu chung') continue;
          expect(t.split(' ').length, lessThanOrEqualTo(9), reason: t);
        }
      }
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
}
