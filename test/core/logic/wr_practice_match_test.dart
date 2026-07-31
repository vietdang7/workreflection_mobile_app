// Chủ đề khớp theo TÌNH HUỐNG, không chỉ theo chữ cái trụ (khách 2026-07-31).
// Run: flutter test test/core/logic/wr_practice_match_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_practice_match.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

PracticeTheme _theme(String id, ScaDimension dim) =>
    PracticeTheme(themeId: id, title: id, scaDimension: dim);

WrSituation _sit(String code, ScaDimension dim, {HumanNeed? need}) =>
    WrSituation(
      code: code,
      text: 'Tình huống $code',
      scaDimension: dim,
      wave: 1,
      humanNeed: need,
    );

/// [count] lần xuất hiện của [code] trong recentSituationIds.
List<String> _p(String code, int count) => List.filled(count, code);

void main() {
  // Ba chiều của trụ C nói ba chuyện khác hẳn nhau — đây là lý do phải khớp
  // theo chiều chứ không theo chữ cái đầu.
  final themes = [
    _theme('pt-c1', ScaDimension.c1),
    _theme('pt-c2', ScaDimension.c2),
    _theme('pt-c3', ScaDimension.c3),
    _theme('pt-s1', ScaDimension.s1),
  ];

  final situations = [
    _sit('c1-01', ScaDimension.c1, need: HumanNeed.ketNoi),
    _sit('c3-01', ScaDimension.c3, need: HumanNeed.ketNoi),
    _sit('s1-01', ScaDimension.s1, need: HumanNeed.roRang),
    _sit('pos-01', ScaDimension.pAchieve),
  ];

  test('khớp đúng chiều của tình huống lặp nhiều nhất', () {
    // Trước bản này, nhu cầu Kết nối chỉ khớp chữ 'C' nên sẽ trả pt-c1 vì nó
    // đứng đầu danh sách — dù người dùng đang vướng ở C3.
    final s = suggestPracticeTheme(
      candidates: themes,
      recent: [..._p('c3-01', 5), ..._p('c1-01', 1)],
      situations: situations,
      need: HumanNeed.ketNoi,
    );
    expect(s!.theme.themeId, 'pt-c3');
    expect(s.kind, PracticeMatchKind.dimension);
    expect(s.reasonSituationCode, 'c3-01');
    expect(s.reasonCount, 5);
  });

  test('chiều nhiều lần hơn thắng, kể cả khác trụ với nhu cầu chủ đạo', () {
    final s = suggestPracticeTheme(
      candidates: themes,
      recent: [..._p('s1-01', 9), ..._p('c1-01', 2)],
      situations: situations,
      need: HumanNeed.ketNoi,
    );
    expect(s!.theme.themeId, 'pt-s1');
  });

  test('chưa có tình huống nào thì lùi về khớp trụ theo nhu cầu', () {
    // Đây là đường của Hướng 2: mới làm Self-Check, chưa có pattern nào.
    final s = suggestPracticeTheme(
      candidates: themes,
      recent: const [],
      situations: situations,
      need: HumanNeed.ketNoi,
    );
    expect(s!.theme.scaDimension!.dbValue.startsWith('C'), isTrue);
    expect(s.kind, PracticeMatchKind.pillar);
    expect(s.reasonSituationCode, isNull);
  });

  test('chiều đã ghi danh hết thì bỏ qua, xuống chiều kế', () {
    final s = suggestPracticeTheme(
      candidates: [_theme('pt-c1', ScaDimension.c1)], // c3 không còn trong bể
      recent: [..._p('c3-01', 9), ..._p('c1-01', 1)],
      situations: situations,
      need: HumanNeed.ketNoi,
    );
    expect(s!.theme.themeId, 'pt-c1');
    expect(s.reasonSituationCode, 'c1-01');
  });

  test('tình huống tích cực không kéo được chủ đề nào', () {
    // P-ACHIEVE không có chủ đề thực hành — không được vì nó mà đề xuất bừa.
    final s = suggestPracticeTheme(
      candidates: themes,
      recent: [..._p('pos-01', 99)],
      situations: situations,
      need: null,
    );
    expect(s!.reasonSituationCode, isNull);
    expect(s.kind, PracticeMatchKind.fallback);
    expect(s.theme.themeId, 'pt-c1'); // lùi về phần tử đầu, im lặng về lý do
  });

  test('không còn chủ đề nào thì không đề xuất', () {
    final s = suggestPracticeTheme(
      candidates: const [],
      recent: [..._p('c1-01', 5)],
      situations: situations,
      need: HumanNeed.ketNoi,
    );
    expect(s, isNull);
  });

  test('hoà số lần thì kết quả ổn định giữa hai lần dựng', () {
    List<String> pick() => [
          for (var i = 0; i < 5; i++)
            suggestPracticeTheme(
              candidates: themes,
              recent: [..._p('c1-01', 3), ..._p('c3-01', 3)],
              situations: situations,
              need: HumanNeed.ketNoi,
            )!
                .theme
                .themeId,
        ];
    expect(pick().toSet().length, 1);
  });

  group('PracticeTheme.retiredAt', () {
    test('đọc được từ JSON', () {
      final t = PracticeTheme.fromJson({
        'theme_id': 'pt-voice',
        'title': 'Dám lên tiếng',
        'sca_dimension': 'C2',
        'retired_at': '2026-07-31T00:00:00Z',
      });
      expect(t.isRetired, isTrue);
    });

    test('thiếu cột thì coi như còn dùng được', () {
      final t = PracticeTheme.fromJson({
        'theme_id': 'pt-c2',
        'title': 'Dám lên tiếng',
        'sca_dimension': 'C2',
      });
      expect(t.isRetired, isFalse);
    });
  });
}
