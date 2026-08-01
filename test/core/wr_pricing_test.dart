// Giá gói Premium — khách chốt 2026-08-01 rằng giá trên app canh theo web:
// giá gốc 499.000đ, giá hiện tại 249.000đ, lấy từ `cc_products`.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_pricing.dart';

void main() {
  group('formatVndPrice', () {
    test('chấm ngăn nhóm nghìn và hậu tố đ', () {
      expect(formatVndPrice(499000), '499.000đ');
      expect(formatVndPrice(249000), '249.000đ');
    });

    test('số nhỏ hơn một nghìn không có dấu chấm', () {
      expect(formatVndPrice(0), '0đ');
      expect(formatVndPrice(999), '999đ');
    });

    test('hàng triệu ngăn đủ hai dấu chấm', () {
      expect(formatVndPrice(1200000), '1.200.000đ');
      expect(formatVndPrice(12345678), '12.345.678đ');
    });

    test('làm tròn phần lẻ — cc_products.current_price là numeric', () {
      expect(formatVndPrice(249000.4), '249.000đ');
      expect(formatVndPrice(248999.6), '249.000đ');
    });

    test('tiền khác VND thì ghi mã tiền, không bịa ký hiệu', () {
      expect(formatVndPrice(20, 'USD'), '20 USD');
    });
  });

  group('WrPremiumPricing.fromJson', () {
    test('đọc đúng giá gốc và giá hiện tại như ảnh trang quản trị', () {
      final p = WrPremiumPricing.fromJson({
        'name': 'Work Reflection Premium',
        'current_price': 249000,
        'original_price': 499000,
        'currency': 'VND',
      });

      expect(p.currentLabel, '249.000đ');
      expect(p.originalLabel, '499.000đ');
      expect(p.hasDiscount, isTrue);
      expect(p.discountPercent, 50);
      expect(p.name, 'Work Reflection Premium');
    });

    test('không có giá gốc thì không gạch ngang gì cả', () {
      final p = WrPremiumPricing.fromJson({'current_price': 499000});

      expect(p.hasDiscount, isFalse);
      expect(p.originalLabel, isNull);
      expect(p.discountPercent, 0);
    });

    test('giá gốc thấp hơn hoặc bằng giá hiện tại thì không phải khuyến mãi', () {
      final bang = WrPremiumPricing.fromJson({
        'current_price': 499000,
        'original_price': 499000,
      });
      final thap = WrPremiumPricing.fromJson({
        'current_price': 499000,
        'original_price': 399000,
      });

      expect(bang.hasDiscount, isFalse);
      expect(thap.hasDiscount, isFalse);
    });

    test('current_price null hoặc 0 rơi về giá mặc định của web', () {
      // Cột mặc định 0 bên web; một gói Premium 0đ gần như chắc chắn là dữ
      // liệu bỏ trống chứ không phải miễn phí thật.
      expect(WrPremiumPricing.fromJson({}).currentPrice, kPremiumFallbackPrice);
      expect(
        WrPremiumPricing.fromJson({'current_price': 0}).currentPrice,
        kPremiumFallbackPrice,
      );
    });

    test('original_price 0 coi như không có, không gạch ngang "0đ"', () {
      final p = WrPremiumPricing.fromJson({
        'current_price': 249000,
        'original_price': 0,
      });

      expect(p.hasDiscount, isFalse);
      expect(p.originalLabel, isNull);
    });

    test('giá mặc định khi bảng rỗng khớp với web', () {
      expect(WrPremiumPricing.fallback.currentLabel, '499.000đ');
      expect(WrPremiumPricing.fallback.hasDiscount, isFalse);
    });

    test('phần trăm giảm làm tròn', () {
      final p = WrPremiumPricing.fromJson({
        'current_price': 333000,
        'original_price': 499000,
      });

      expect(p.discountPercent, 33);
    });
  });

  group('productId và duration_days', () {
    test('đọc được id và số ngày từ cc_products', () {
      final p = WrPremiumPricing.fromJson({
        'id': 'abc-123',
        'current_price': 249000,
        'duration_days': 365,
      });
      expect(p.productId, 'abc-123');
      expect(p.durationDays, 365);
      expect(p.canPurchase, isTrue);
    });

    test('không có id thì KHÔNG cho mua', () {
      // complete_payment tra cc_products bằng product_id để biết cấp bao nhiêu
      // ngày. Tạo đơn thiếu id là trả tiền xong không rõ hạn gói.
      expect(WrPremiumPricing.fallback.canPurchase, isFalse);
    });

    test('duration_days trống hoặc 0 rơi về 365, khớp COALESCE trong RPC', () {
      expect(
        WrPremiumPricing.fromJson({'current_price': 1}).durationDays,
        kPremiumFallbackDurationDays,
      );
      expect(
        WrPremiumPricing.fromJson({'current_price': 1, 'duration_days': 0})
            .durationDays,
        365,
      );
    });

    test('durationLabel nói đúng hạn thay vì đoán', () {
      WrPremiumPricing withDays(int d) =>
          WrPremiumPricing(currentPrice: 1, durationDays: d);
      expect(withDays(365).durationLabel, 'một năm');
      expect(withDays(730).durationLabel, '2 năm');
      expect(withDays(180).durationLabel, '6 tháng');
      expect(withDays(45).durationLabel, '45 ngày');
    });
  });
}
