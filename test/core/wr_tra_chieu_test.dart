// Trà Chiều Nghề Nghiệp — luật lọc và cách hiển thị (họp khách 2026-07-29).

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_tra_chieu.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';

WorkshopDetail _w({
  String id = 'w1',
  String? slug,
  String title = 'Bận cả tuần, nhưng mình đang đi về đâu?',
  String? category = 'Trà chiều nghề nghiệp',
  DateTime? date,
  DateTime? startsAt,
  DateTime? endsAt,
  String? location,
  num price = 99000,
  String currency = 'VND',
}) =>
    WorkshopDetail(
      id: id,
      slug: slug,
      title: title,
      category: category,
      date: date ?? DateTime(2026, 8, 22),
      startsAt: startsAt,
      endsAt: endsAt,
      location: location,
      price: price,
      currency: currency,
      currentParticipants: 0,
      status: 'published',
      isActive: true,
    );

void main() {
  group('isTraChieu', () {
    test('nhận mọi biến thể dấu và gạch nối', () {
      for (final c in [
        'Trà chiều nghề nghiệp',
        'tra-chieu-nghe-nghiep',
        'TRA_CHIEU',
        'Trà Chiều',
        'wr tra chieu',
        // Web lưu nhãn theo ngôn ngữ đang bật. Tạo buổi lúc web để tiếng Anh
        // thì `category` xuống DB là bản dịch, không phải chuỗi tiếng Việt.
        'Career Afternoon Tea',
      ]) {
        expect(isTraChieu(_w(category: c)), isTrue, reason: 'trượt "$c"');
      }
    });

    test('nhãn danh mục khác của web không bị nhận nhầm', () {
      for (final c in [
        'Tư duy hệ thống',
        'AI Skill dành cho người đi làm',
        'Phong cách chuyên nghiệp',
        'Khác',
      ]) {
        expect(isTraChieu(_w(category: c)), isFalse, reason: 'nhận nhầm "$c"');
      }
    });

    test('không nhận workshop thường', () {
      expect(isTraChieu(_w(category: 'Tư duy hệ thống')), isFalse);
      expect(isTraChieu(_w(category: null)), isFalse);
      expect(isTraChieu(_w(category: '')), isFalse);
    });
  });

  group('upcomingTraChieu', () {
    final now = DateTime(2026, 8, 20, 10);

    test('bỏ buổi đã qua, giữ buổi diễn ra trong hôm nay', () {
      final list = upcomingTraChieu([
        _w(id: 'cu', date: DateTime(2026, 8, 1)),
        _w(id: 'homnay', date: DateTime(2026, 8, 20)),
        _w(id: 'sautoi', date: DateTime(2026, 9, 5)),
      ], now: now);

      expect(list.map((w) => w.id), ['homnay', 'sautoi']);
    });

    test('loại workshop không phải Trà Chiều', () {
      final list = upcomingTraChieu([
        _w(id: 'khac', category: 'AI cho người đi làm'),
        _w(id: 'tc'),
      ], now: now);

      expect(list.map((w) => w.id), ['tc']);
    });

    test('nextTraChieu lấy buổi gần nhất, null khi chưa mở buổi nào', () {
      expect(
        nextTraChieu([
          _w(id: 'xa', date: DateTime(2026, 10, 3)),
          _w(id: 'gan', date: DateTime(2026, 8, 22)),
        ], now: now)!
            .id,
        'gan',
      );
      expect(nextTraChieu(const [], now: now), isNull);
    });
  });

  group('hiển thị', () {
    test('giá theo cách viết tiếng Việt, miễn phí thì nói miễn phí', () {
      expect(traChieuPriceLabel(_w(price: 99000)), '99.000đ');
      expect(traChieuPriceLabel(_w(price: 1490000)), '1.490.000đ');
      expect(traChieuPriceLabel(_w(price: 0)), 'Miễn phí');
      expect(traChieuPriceLabel(_w(price: 20, currency: 'USD')), '20 USD');
    });

    test('ngày giờ bỏ phần nào không có dữ liệu', () {
      expect(
        traChieuWhenLabel(_w(date: DateTime(2026, 8, 22))),
        'T7 22/08',
      );
      expect(
        traChieuWhenLabel(_w(
          date: DateTime(2026, 8, 22),
          startsAt: DateTime(2026, 8, 22, 15, 30),
        )),
        'T7 22/08, 15:30',
      );
      expect(
        traChieuWhenLabel(_w(
          date: DateTime(2026, 8, 22),
          startsAt: DateTime(2026, 8, 22, 15, 30),
          endsAt: DateTime(2026, 8, 22, 17, 30),
        )),
        'T7 22/08, 15:30 – 17:30',
      );
    });

    test('link chi tiết đúng khuôn web app', () {
      // Link thật khách gửi 2026-07-30:
      // https://www.workreflection.app/services/workshops/test-1
      expect(
        traChieuWebUrl('test-1'),
        'https://www.workreflection.app/services/workshops/test-1',
      );
    });

    test('ưu tiên slug, không có slug thì dùng id', () {
      expect(traChieuUrlKey(_w(id: 'uuid-1', slug: 'test-1')), 'test-1');
      expect(traChieuUrlKey(_w(id: 'uuid-1')), 'uuid-1');
      // Slug rỗng hoặc toàn khoảng trắng cũng phải rơi về id, không ghép ra
      // một đường dẫn cụt.
      expect(traChieuUrlKey(_w(id: 'uuid-1', slug: '  ')), 'uuid-1');
    });
  });

  group('traChieuInsertIndex', () {
    test('chèn ngay sau Tư duy hệ thống', () {
      expect(
        traChieuInsertIndex(['Tư duy hệ thống', 'AI cho người đi làm']),
        1,
      );
    });

    test('không phụ thuộc dấu tiếng Việt', () {
      expect(traChieuInsertIndex(['Tu duy he thong', 'Khác']), 1);
    });

    test('không có mỏ neo thì để cuối, không chèn bừa vào giữa', () {
      expect(traChieuInsertIndex(['AI', 'Phong cách hiện diện']), 2);
      expect(traChieuInsertIndex(const []), 0);
    });
  });
}
