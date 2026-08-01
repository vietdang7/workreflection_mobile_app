import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_payment.dart';

void main() {
  group('generateOrderCode', () {
    test('khớp thuật toán generateOrderCode bên web', () {
      // Web: 'CNC' + 8 hex đầu, bỏ gạch, viết hoa.
      expect(
        generateOrderCode('7c0cb925-622c-4e41-b81b-4e21301e87b3'),
        'CNC7C0CB925',
      );
      expect(
        generateOrderCode('d0af925f-ccc8-436b-9e12-e9f3e2046b1a'),
        'CNCD0AF925F',
      );
    });

    test('luôn dài 11 ký tự — webhook dò /CNC([A-Z0-9]{6,8})/', () {
      final code = generateOrderCode('04f91e54-a800-42df-a89c-a33e50d208a8');
      expect(code.length, 11);
      expect(RegExp(r'^CNC[A-Z0-9]{8}$').hasMatch(code), isTrue);
    });

    test('id ngắn bất thường vẫn không ném lỗi', () {
      expect(generateOrderCode('abc'), 'CNCABC');
    });
  });

  group('buildVietQrUrl', () {
    test('nhúng đúng số tiền và nội dung', () {
      final url = buildVietQrUrl(orderCode: 'CNCABC12345', amount: 249000);
      expect(url, contains('970422-2610130979-xHAYZGr.jpg'));
      expect(url, contains('amount=249000'));
      expect(url, contains('addInfo=CNCABC12345'));
      expect(url, contains('accountName=CLOUD%20CORAL'));
    });

    test('làm tròn số tiền — VietQR không nhận số lẻ', () {
      final url = buildVietQrUrl(orderCode: 'CNCX', amount: 249000.6);
      expect(url, contains('amount=249001'));
    });

    test('chưa có mã đơn thì trả chuỗi rỗng', () {
      expect(buildVietQrUrl(orderCode: '', amount: 1000), '');
    });
  });

  group('formatCountdown', () {
    test('đệm 0 cho cả phút và giây', () {
      expect(formatCountdown(const Duration(minutes: 30)), '30:00');
      expect(formatCountdown(const Duration(minutes: 4, seconds: 5)), '04:05');
      expect(formatCountdown(const Duration(seconds: 9)), '00:09');
    });

    test('âm thì kẹp về 00:00 chứ không hiện số âm', () {
      expect(formatCountdown(const Duration(seconds: -5)), '00:00');
    });
  });

  group('calculateVoucherDiscount', () {
    const percent = WrVoucher(
      id: 'v1',
      code: 'GIAM50',
      discountType: 'percentage',
      discountPercent: 50,
    );

    test('giảm theo phần trăm, làm tròn', () {
      expect(calculateVoucherDiscount(percent, 249000), 124500);
    });

    test('giảm 100% cho ra đơn 0đ', () {
      const full = WrVoucher(
        id: 'v2',
        code: 'FREE',
        discountType: 'percentage',
        discountPercent: 100,
      );
      expect(calculateVoucherDiscount(full, 249000), 249000);
    });

    test('giảm số tiền cố định không vượt quá giá gốc', () {
      const fixed = WrVoucher(
        id: 'v3',
        code: 'BOT500K',
        discountType: 'fixed',
        discountAmount: 500000,
      );
      // Không kẹp thì đơn thành âm tiền.
      expect(calculateVoucherDiscount(fixed, 249000), 249000);
    });
  });

  group('validateVoucher', () {
    final now = DateTime(2026, 8, 1, 12);

    WrVoucher base({
      DateTime? validFrom,
      DateTime? validTo,
      int? maxUses,
      int usedCount = 0,
      String targetType = 'all',
      List<String> assignedUsers = const [],
      List<String> applicableProducts = const [],
      bool isActive = true,
    }) {
      return WrVoucher(
        id: 'v',
        code: 'X',
        discountType: 'percentage',
        discountPercent: 10,
        isActive: isActive,
        validFrom: validFrom,
        validTo: validTo,
        maxUses: maxUses,
        usedCount: usedCount,
        targetType: targetType,
        assignedUsers: assignedUsers,
        applicableProducts: applicableProducts,
      );
    }

    test('mã sạch thì hợp lệ', () {
      expect(validateVoucher(base(), now: now), isNull);
    });

    test('hết hạn', () {
      final v = base(validTo: DateTime(2026, 7, 31));
      expect(validateVoucher(v, now: now), 'Mã giảm giá đã hết hạn');
    });

    test('chưa tới ngày', () {
      final v = base(validFrom: DateTime(2026, 8, 2));
      expect(validateVoucher(v, now: now), 'Mã giảm giá chưa đến ngày sử dụng');
    });

    test('hết lượt', () {
      final v = base(maxUses: 5, usedCount: 5);
      expect(validateVoucher(v, now: now), 'Mã giảm giá đã hết lượt sử dụng');
    });

    test('max_uses = 0 nghĩa là không giới hạn, không phải hết lượt', () {
      final v = base(maxUses: 0, usedCount: 10);
      expect(validateVoucher(v, now: now), isNull);
    });

    test('mã dành cho người dùng Free thì Premium không dùng được', () {
      final v = base(targetType: 'individual_free');
      expect(
        validateVoucher(v, now: now, userRole: 'premium'),
        'Mã giảm giá không áp dụng cho tài khoản của bạn',
      );
      expect(validateVoucher(v, now: now, userRole: 'free'), isNull);
    });

    test('không có role thì tính là free', () {
      final v = base(targetType: 'individual_free');
      expect(validateVoucher(v, now: now, userRole: null), isNull);
    });

    test('admin bỏ qua kiểm tra nhóm người dùng', () {
      final v = base(targetType: 'individual_free');
      expect(validateVoucher(v, now: now, userRole: 'admin'), isNull);
    });

    test('specific_users chỉ cho đúng người trong danh sách', () {
      final v = base(targetType: 'specific_users', assignedUsers: ['u1']);
      expect(validateVoucher(v, now: now, userId: 'u1'), isNull);
      expect(validateVoucher(v, now: now, userId: 'u2'), isNotNull);
    });

    test('mã chỉ cho Workshop thì mua Premium báo rõ lý do', () {
      final v = base(applicableProducts: ['workshop']);
      expect(
        validateVoucher(v, now: now),
        'Mã giảm giá chỉ áp dụng cho Workshop',
      );
    });

    test('mã cho premium dùng được khi mua Premium', () {
      final v = base(applicableProducts: ['premium']);
      expect(validateVoucher(v, now: now), isNull);
    });
  });

  group('serviceKeyForProductType', () {
    test('mọi *_survey quy về premium', () {
      expect(serviceKeyForProductType('premium_survey'), 'premium');
      expect(serviceKeyForProductType('enterprise_survey'), 'premium');
    });

    test('hai loại workshop quy về workshop', () {
      expect(serviceKeyForProductType('workshop'), 'workshop');
      expect(serviceKeyForProductType('workshop_enterprise'), 'workshop');
    });

    test('coaching giữ nguyên', () {
      expect(serviceKeyForProductType('coaching'), 'coaching');
    });
  });

  group('WrInvoiceForm', () {
    test('tắt hoá đơn thì luôn hợp lệ', () {
      expect(const WrInvoiceForm().isValid, isTrue);
    });

    test('bật mà thiếu tên hoặc địa chỉ là chưa hợp lệ', () {
      const f = WrInvoiceForm(requested: true);
      expect(f.validationError, 'Chưa điền tên người mua');
      expect(
        const WrInvoiceForm(requested: true, buyerName: 'A').validationError,
        'Chưa điền địa chỉ',
      );
    });

    test('mã số thuế và tên đơn vị phải đi cặp', () {
      const onlyTax = WrInvoiceForm(
        requested: true,
        buyerName: 'A',
        address: 'B',
        taxCode: '0101234567',
      );
      expect(onlyTax.validationError, 'Có mã số thuế thì phải có tên đơn vị');

      const onlyLegal = WrInvoiceForm(
        requested: true,
        buyerName: 'A',
        address: 'B',
        legalName: 'Công ty X',
      );
      expect(onlyLegal.validationError, 'Có tên đơn vị thì phải có mã số thuế');

      const both = WrInvoiceForm(
        requested: true,
        buyerName: 'A',
        address: 'B',
        taxCode: '0101234567',
        legalName: 'Công ty X',
      );
      expect(both.isValid, isTrue);
    });

    test('cá nhân không có mã số thuế vẫn hợp lệ', () {
      const f = WrInvoiceForm(requested: true, buyerName: 'A', address: 'B');
      expect(f.isValid, isTrue);
    });

    test('tắt hoá đơn thì payload xoá sạch cột cũ', () {
      final p = const WrInvoiceForm(requested: false, buyerName: 'A')
          .toOrderPayload();
      expect(p['invoice_requested'], false);
      expect(p['invoice_buyer_name'], isNull);
      expect(p['invoice_tax_code'], isNull);
    });

    test('payload cắt khoảng trắng, ô trống thành null', () {
      final p = const WrInvoiceForm(
        requested: true,
        buyerName: '  Nguyễn A  ',
        address: 'Hà Nội',
        email: '   ',
      ).toOrderPayload();
      expect(p['invoice_buyer_name'], 'Nguyễn A');
      expect(p['invoice_address'], 'Hà Nội');
      expect(p['invoice_email'], isNull);
    });
  });

  group('hằng số khớp web', () {
    test('product_type phải kết thúc bằng _survey', () {
      // complete_payment chỉ cấp role premium khi right(product_type,7) =
      // '_survey'. Đổi hằng này mà quên đuôi là mua xong không lên Premium.
      expect(kPremiumOrderProductType.endsWith('_survey'), isTrue);
    });

    test('cửa sổ 30 phút và nhịp hỏi 3 giây', () {
      expect(kPaymentWindow, const Duration(minutes: 30));
      expect(kPaymentPollInterval, const Duration(seconds: 3));
    });

    test('tài khoản nhận tiền đúng như web', () {
      expect(WrBankInfo.accountNumber, '2610130979');
      expect(WrBankInfo.accountName, 'CLOUD CORAL');
      expect(WrBankInfo.bankBin, '970422');
    });
  });
}
