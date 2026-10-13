// Chặng — luật khép chặng và ba khối của bản đọc (`wr_chapters.dart`).
//
// Run: flutter test test/core/logic/wr_chapters_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_chapters.dart';
import 'package:workreflection_mobile/core/models/wr_episode.dart';

ReflectionEpisode _ep(String? code, DateTime at) => ReflectionEpisode(
  userId: 'u1',
  humanMoment: HumanMoment.confusion,
  situationCode: code,
  openedAt: at,
);

const _labels = {
  'A': 'Phụ thuộc vào một người để việc chạy',
  'B': 'Ranh giới giữa vai trò và kỳ vọng',
  'C': 'Mối quan hệ trong công việc',
  'D': 'Không rõ phạm vi việc được giao',
};

final _t0 = DateTime(2026, 4, 1, 9);
DateTime _day(int d) => _t0.add(Duration(days: d));

void main() {
  group('luật khép chặng: đủ 8 lần VÀ đủ 6 tuần', () {
    test('chưa đủ 8 lần thì chưa có chặng, dù đã nhiều tuần', () {
      final eps = [for (var i = 0; i < 7; i++) _ep('A', _day(i * 10))];
      expect(buildChapters(eps, labels: _labels, now: _day(200)), isEmpty);
    });

    test('đủ 8 lần mà chưa đủ 6 tuần thì chặng còn mở', () {
      final eps = [for (var i = 0; i < 12; i++) _ep('A', _day(i))];
      expect(buildChapters(eps, labels: _labels, now: _day(20)), isEmpty);
    });

    test('đủ 8 lần sớm thì khép ở mốc 6 tuần, gom mọi lần trước mốc', () {
      final eps = [
        for (var i = 0; i < 10; i++) _ep('A', _day(i)),
        _ep('A', _day(50)), // sau mốc 42 ngày: thuộc chặng sau
      ];
      final chapters = buildChapters(eps, labels: _labels, now: _day(60));
      expect(chapters, hasLength(1));
      expect(chapters.single.entries, 10);
      expect(chapters.single.end, _day(42));
      expect(chapters.single.id, 'ch1');
      expect(chapters.single.isLatest, isTrue);
    });

    test('đủ 6 tuần trước thì khép ngay ở lần thứ 8', () {
      final eps = [for (var i = 0; i < 9; i++) _ep('A', _day(i * 7))];
      final chapters = buildChapters(eps, labels: _labels, now: _day(100));
      expect(chapters, hasLength(1));
      expect(chapters.single.entries, 8);
      expect(chapters.single.end, _day(49));
      expect(
        openChapterEntries(eps, chapters),
        1,
        reason: 'lần thứ 9 thuộc chặng đang đi',
      );
    });

    test('chặng sau tính 6 tuần từ lần khép trước', () {
      final eps = [
        for (var i = 0; i < 8; i++) _ep('A', _day(i)), // chặng 1 khép ở 42
        for (var i = 0; i < 8; i++) _ep('B', _day(43 + i)), // khép ở 84
      ];
      expect(buildChapters(eps, labels: _labels, now: _day(80)), hasLength(1));
      final two = buildChapters(eps, labels: _labels, now: _day(85));
      expect(two, hasLength(2));
      expect(two[1].start, _day(42));
      expect(two[1].end, _day(84));
      expect(two[0].isLatest, isFalse);
      expect(two[1].isLatest, isTrue);
    });
  });

  group('bản đọc chặng', () {
    test('chặng đầu: chỉ có "mới nổi lên" là điều nhiều lần nhất, là nền', () {
      final eps = [
        for (var i = 0; i < 4; i++) _ep('D', _day(i)),
        for (var i = 0; i < 3; i++) _ep('C', _day(4 + i)),
        _ep(null, _day(7)), // tự viết: tính lần, không tính tình huống
      ];
      final c = buildChapters(eps, labels: _labels, now: _day(60)).single;
      expect(c.entries, 8);
      expect(c.rose?.title, _labels['D']);
      expect(c.rose?.count, 4);
      expect(c.rose?.previousCount, isNull);
      expect(c.faded, isNull, reason: 'chỉ có từ chặng thứ hai');
      expect(c.steady, isNull);
      expect(c.ask, isNull);
      expect(
        c.lead,
        'Chặng đầu tiên. Chưa có chặng nào trước để so, nên đây là nền.',
      );
    });

    test('chặng sau: mới nổi lên · đã thôi lặp lại · vẫn vậy', () {
      final eps = [
        // Chặng 1 (ngày 0–41): A 6, C 4.
        for (var i = 0; i < 6; i++) _ep('A', _day(i)),
        for (var i = 0; i < 4; i++) _ep('C', _day(6 + i)),
        // Chặng 2 (ngày 42–83): B 7, A 1, C 5.
        for (var i = 0; i < 7; i++) _ep('B', _day(43 + i)),
        _ep('A', _day(51)),
        for (var i = 0; i < 5; i++) _ep('C', _day(52 + i)),
      ];
      final chapters = buildChapters(eps, labels: _labels, now: _day(90));
      expect(chapters, hasLength(2));
      final c = chapters.last;
      expect(c.label, 'Chặng 2');
      expect(c.rose?.title, _labels['B']);
      expect((c.rose?.count, c.rose?.previousCount), (7, 0));
      expect(c.faded?.title, _labels['A']);
      expect((c.faded?.count, c.faded?.previousCount), (1, 6));
      expect(c.steady?.title, _labels['C']);
      expect(c.steady?.count, 5);
      expect(
        c.lead,
        'Những gì bạn ghi lại ở chặng này đã đổi chỗ so với chặng trước.',
      );
      expect(c.ask, 'Chuyện đó đã nhẹ đi thật, hay bạn chỉ thôi để ý tới nó?');
      expect(c.note, contains(_labels['A']));
    });

    test('mã không có tên thì không bao giờ lên bản đọc', () {
      final eps = [for (var i = 0; i < 8; i++) _ep('X-99', _day(i))];
      final c = buildChapters(eps, labels: _labels, now: _day(60)).single;
      expect(c.rose, isNull);
    });
  });

  test('nhãn quãng thời gian đúng dạng script', () {
    expect(
      chapterRangeLabel(DateTime(2026, 8, 3), DateTime(2026, 10, 2)),
      'Tháng 8 đến tháng 10',
    );
    expect(
      chapterRangeLabel(DateTime(2026, 8, 3), DateTime(2026, 8, 30)),
      'Tháng 8',
    );
    expect(
      chapterRangeLabel(DateTime(2025, 11, 3), DateTime(2026, 1, 2)),
      'Tháng 11/2025 đến tháng 1/2026',
    );
  });
}
