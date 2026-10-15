import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_timeline_stages.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/models/wr_learning_resource.dart';

PatternNarrative _n(
  String start,
  String end,
  String created, [
  String t = '',
]) => PatternNarrative(
  userId: 'u',
  narrative: t.isEmpty ? '$start→$end' : t,
  periodStart: DateTime.parse(start),
  periodEnd: DateTime.parse(end),
  createdAt: DateTime.parse(created),
);

void main() {
  group('timelineStages (họp khách 14/10: ngày tháng đan xen, lặp)', () {
    test('quãng chồng gần trọn chỉ giữ bản mới nhất, cũ trước', () {
      // Dữ liệu thật của một tài khoản test: cửa sổ 30 lần trượt dần.
      final out = timelineStages([
        _n('2026-08-24', '2026-10-08', '2026-10-08'),
        _n('2026-08-23', '2026-10-07', '2026-10-07'),
        _n('2026-08-23', '2026-10-01', '2026-10-01'),
        _n('2026-08-22', '2026-09-25', '2026-09-26'),
        _n('2026-08-19', '2026-09-15', '2026-09-15'),
        _n('2026-08-12', '2026-09-12', '2026-09-12'),
        _n('2026-08-08', '2026-09-01', '2026-09-05'),
        _n('2026-08-08', '2026-08-28', '2026-08-28'),
      ]);
      expect(out.map((n) => n.narrative), [
        '2026-08-08→2026-08-28',
        '2026-08-24→2026-10-08',
      ]);
    });

    test('cùng một quãng ghi nhiều lần thì lấy bản tạo sau cùng', () {
      final out = timelineStages([
        _n('2026-07-28', '2026-08-25', '2026-09-11T01:38', 'cũ'),
        _n('2026-07-28', '2026-08-25', '2026-09-11T02:10', 'mới'),
        _n('2026-07-28', '2026-08-25', '2026-09-11T01:57', 'giữa'),
      ]);
      expect(out.map((n) => n.narrative), ['mới']);
    });

    test('các chặng nối tiếp đều giữ, theo thứ tự thời gian', () {
      final out = timelineStages([
        _n('2026-09-01', '2026-09-30', '2026-09-30'),
        _n('2026-07-01', '2026-07-31', '2026-07-31'),
        _n('2026-08-01', '2026-08-31', '2026-08-31'),
      ]);
      expect(out.map((n) => n.periodStart!.month), [7, 8, 9]);
    });

    test('bản không có ngày bị bỏ', () {
      expect(
        timelineStages([const PatternNarrative(userId: 'u', narrative: 'x')]),
        isEmpty,
      );
    });
  });

  group('Chuỗi series Tâm thế người đi làm (lọc theo tag)', () {
    LearningResource r(List<String>? tags) => LearningResource.fromJson({
      'id': '1',
      'title': 'Tập 1',
      'external_url': 'https://youtu.be/iKs4vZjT7rs',
      'tags': tags,
    });

    test('nhận tag bỏ dấu, không phân biệt hoa thường', () {
      expect(r(['Chuỗi series tâm thế người đi làm']).isMindsetSeries, isTrue);
      expect(r(['CHUỖI SERIES TÂM THẾ NGƯỜI ĐI LÀM']).isMindsetSeries, isTrue);
      expect(r(['chuoi series tam the nguoi di lam']).isMindsetSeries, isTrue);
    });

    test('không có tag hoặc tag khác thì không nhận', () {
      expect(r(null).isMindsetSeries, isFalse);
      expect(r(['Communication']).isMindsetSeries, isFalse);
    });
  });
}
