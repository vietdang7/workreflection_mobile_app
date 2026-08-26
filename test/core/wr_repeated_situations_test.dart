// recentSituationIds — nguồn sự thật duy nhất (Kiến trúc Dữ liệu v2.0 §4.3).
//
// Bốn luật cần được giữ bằng test, vì cả bốn đều dễ bị đảo ngược khi ai đó
// "sửa cho tiện":
//   1. cửa sổ 30 mục gần nhất
//   2. tính từ lúc CHỌN, không đợi Episode khép
//   3. mặc định KHÔNG lọc theo số lần — ngưỡng hiển thị là tuỳ chọn của màn
//      hình, không phải luật của tầng dữ liệu
//   4. sắp xếp ổn định giữa hai lần dựng màn
//
// Run: flutter test test/core/wr_repeated_situations_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_repeated_situations.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';

ReflectionEpisode _ep(
  String id,
  String? code, {
  ExperienceState state = ExperienceState.integrated,
  DateTime? openedAt,
}) =>
    ReflectionEpisode(
      id: id,
      userId: 'u1',
      humanMoment: HumanMoment.confusion,
      state: state,
      situationCode: code,
      openedAt: openedAt ?? DateTime(2026, 7, 1),
    );

/// [count] Episode cho cùng một mã, thời điểm mở tăng dần từ [from].
List<ReflectionEpisode> _many(
  String code,
  int count, {
  required DateTime from,
}) =>
    [
      for (var i = 0; i < count; i++)
        _ep('$code-$i', code, openedAt: from.add(Duration(hours: i))),
    ];

void main() {
  group('recentSituationIds', () {
    test('cửa sổ là 30, top là 3', () {
      expect(kRecentSituationsWindow, 30);
      expect(kRepeatedSituationsTop, 3);
    });

    test('mới nhất đứng đầu', () {
      final ids = recentSituationIds([
        _ep('e1', 'cu', openedAt: DateTime(2026, 7, 1)),
        _ep('e3', 'moi', openedAt: DateTime(2026, 7, 3)),
        _ep('e2', 'giua', openedAt: DateTime(2026, 7, 2)),
      ]);

      expect(ids, ['moi', 'giua', 'cu']);
    });

    test('cắt đúng 30 mục gần nhất', () {
      final ids = recentSituationIds([
        ..._many('cu', 5, from: DateTime(2026, 6, 1)),
        ..._many('moi', 30, from: DateTime(2026, 7, 1)),
      ]);

      expect(ids, hasLength(30));
      expect(ids.contains('cu'), isFalse);
    });

    test('phiên CHƯA khép vẫn được tính', () {
      // v2.0 §4.3: recentSituationIds "ghi nhận thời điểm CHỌN tình huống (bước
      // Notice), không phải thời điểm hoàn tất trọn vẹn một Reflection". Bản
      // trước lọc `state == integrated` nên người bỏ dở giữa chừng mất luôn
      // tình huống họ đã chọn.
      final ids = recentSituationIds([
        _ep('e1', 'a', state: ExperienceState.exploring),
        _ep('e2', 'b', state: ExperienceState.captured),
        _ep('e3', 'c', state: ExperienceState.meaningForming),
      ]);

      expect(ids.toSet(), {'a', 'b', 'c'});
    });

    test('phiên tự viết không có mã thì bỏ qua', () {
      // Không gộp thành một nhóm "khác" giả, và cũng không ăn mất một ô của
      // cửa sổ.
      final ids = recentSituationIds([
        _ep('n1', null),
        _ep('n2', ''),
        _ep('e1', 'a'),
      ]);

      expect(ids, ['a']);
    });

    test('không có Episode nào thì rỗng', () {
      expect(recentSituationIds(const []), isEmpty);
    });
  });

  group('rankSituations', () {
    test('đếm và sắp giảm dần theo số lần', () {
      final result = rankSituations(['a', 'b', 'a', 'c', 'a', 'b']);

      expect(result.map((r) => r.situationCode), ['a', 'b', 'c']);
      expect(result.first.count, 3);
    });

    test('mặc định KHÔNG lọc theo số lần', () {
      // Nhu cầu chủ đạo, tỉ trọng ba trụ và gợi ý Practice Theme đều đếm từ
      // lần đầu tiên. Đưa ngưỡng hiển thị xuống mặc định là làm mù cả ba.
      final result = rankSituations(['a']);

      expect(result, hasLength(1));
      expect(result.single.count, 1);
    });

    test('minCount cắt bỏ những tình huống chưa lặp đủ', () {
      // Bảng "Tình huống lặp lại" chỉ hiện từ kRepeatedSituationsMinCount lần
      // trở lên, nhiều nhất đứng trước.
      //
      // Ngưỡng là HAI. Khách chốt 3 hôm 2026-07-31 rồi đảo lại ở họp 26_1:
      // người mới check-in ít, để 3 thì tuần đầu màn này luôn trống.
      expect(kRepeatedSituationsMinCount, 2);

      final result = rankSituations(
        ['a', 'a', 'a', 'a', 'b', 'b', 'b', 'c', 'c', 'd'],
        minCount: kRepeatedSituationsMinCount,
      );

      expect(result.map((r) => r.situationCode), ['a', 'b', 'c']);
      expect(result.first.count, 4);
      // 'd' mới một lần — một chuyện đã xảy ra, chưa phải một nếp.
      expect(result.map((r) => r.situationCode), isNot(contains('d')));
    });

    test('minCount không đổi thứ tự — nhiều lần nhất vẫn đứng đầu', () {
      final result = rankSituations(
        ['it', 'it', 'it', 'nhieu', 'nhieu', 'nhieu', 'nhieu', 'nhieu'],
        minCount: 3,
      );

      expect(result.map((r) => r.situationCode), ['nhieu', 'it']);
    });

    test('không mục nào đủ ngưỡng thì rỗng, không rơi về danh sách đầy đủ', () {
      expect(rankSituations(['a', 'a', 'b'], minCount: 3), isEmpty);
    });

    test('hoà số lần thì sắp theo mã cho ổn định', () {
      // Thứ tự trong `recent` là theo thời gian, không ổn định giữa hai lần
      // dựng màn — danh sách nhảy chỗ mỗi lần mở app là một lỗi hiển thị.
      expect(
        rankSituations(['zz', 'aa', 'mm', 'zz', 'aa', 'mm'])
            .map((r) => r.situationCode),
        ['aa', 'mm', 'zz'],
      );
    });

    test('rỗng thì rỗng', () {
      expect(rankSituations(const []), isEmpty);
    });
  });

  group('repeatedSituations — gộp hai bước', () {
    test('đọc thẳng từ Episode ra bảng xếp hạng', () {
      final result = repeatedSituations([
        ..._many('a', 3, from: DateTime(2026, 7, 1)),
        ..._many('b', 1, from: DateTime(2026, 7, 5)),
      ]);

      expect(result.map((r) => r.situationCode), ['a', 'b']);
      expect(result.first.count, 3);
    });

    test('chỉ đếm trong cửa sổ 30', () {
      // 'cu' lặp 4 lần nhưng đã bị 30 lượt mới hơn đẩy ra khỏi cửa sổ.
      final result = repeatedSituations([
        ..._many('cu', 4, from: DateTime(2026, 6, 1)),
        ..._many('moi', 30, from: DateTime(2026, 7, 1)),
      ]);

      expect(result.map((r) => r.situationCode), ['moi']);
    });

    test('minCount đi xuyên tới rankSituations', () {
      final result = repeatedSituations(
        [
          ..._many('du', 3, from: DateTime(2026, 7, 1)),
          ..._many('thieu', 1, from: DateTime(2026, 7, 5)),
        ],
        minCount: kRepeatedSituationsMinCount,
      );

      expect(result.map((r) => r.situationCode), ['du']);
    });
  });

  // Khách báo 2026-08-01: tab Hiểu mình ghi "4 lần", mở ra thì đầu màn ghi "5
  // lần" mà bên dưới chỉ liệt kê 4 mục. Nguyên nhân: màn chi tiết đếm từ
  // `wr_pattern_counts` — bảng cộng ở bước KHÉP nên một Episode mở lại rồi xác
  // nhận Ý nghĩa lần nữa bị cộng hai. Hai hàm dưới đây tồn tại để con số và
  // danh sách không bao giờ tách nguồn được nữa.
  group('episodesForSituation / countSituation', () {
    test('số đếm bằng đúng độ dài danh sách hiện ra', () {
      final episodes = [
        ..._many('a', 4, from: DateTime(2026, 7, 1)),
        ..._many('b', 2, from: DateTime(2026, 7, 5)),
      ];

      expect(episodesForSituation(episodes, 'a').length, 4);
      expect(countSituation(episodes, 'a'), 4);
      expect(countSituation(episodes, 'b'), 2);
    });

    test('khớp đúng con số mà tab Hiểu mình hiện cho cùng mã', () {
      final episodes = [
        ..._many('a', 4, from: DateTime(2026, 7, 1)),
        ..._many('b', 3, from: DateTime(2026, 7, 5)),
      ];

      for (final r in repeatedSituations(episodes)) {
        expect(countSituation(episodes, r.situationCode), r.count);
      }
    });

    test('mã chưa từng chọn thì là 0, không phải một', () {
      expect(countSituation(_many('a', 2, from: DateTime(2026, 7, 1)), 'z'), 0);
    });

    test('phiên bỏ dở vẫn được tính — tính từ lúc CHỌN', () {
      final episodes = [
        _ep('e1', 'a', openedAt: DateTime(2026, 7, 1)),
        _ep('e2', 'a',
            state: ExperienceState.reactivated, openedAt: DateTime(2026, 7, 2)),
      ];

      expect(countSituation(episodes, 'a'), 2);
    });

    test('danh sách trả về mới nhất đứng đầu', () {
      final episodes = [
        _ep('cu', 'a', openedAt: DateTime(2026, 7, 1)),
        _ep('moi', 'a', openedAt: DateTime(2026, 7, 9)),
      ];

      expect(
        episodesForSituation(episodes, 'a').map((e) => e.id),
        ['moi', 'cu'],
      );
    });

    test('cùng cửa sổ 30 với recentSituationIds', () {
      final episodes = [
        ..._many('cu', 4, from: DateTime(2026, 6, 1)),
        ..._many('moi', 30, from: DateTime(2026, 7, 1)),
      ];

      expect(countSituation(episodes, 'cu'), 0);
      expect(countSituation(episodes, 'moi'), 30);
    });
  });
}
