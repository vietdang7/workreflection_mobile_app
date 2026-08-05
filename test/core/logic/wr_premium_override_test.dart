// Công tắc Premium thử nghiệm — giới hạn theo tài khoản.
//
// Hai luật phải giữ bằng test, vì hỏng cái nào cũng biến một công cụ nội bộ
// thành đường vòng qua thanh toán:
//   1. chỉ đúng một email thấy công tắc
//   2. công tắc lưu trên MÁY, nên mỗi lần đọc phải hỏi lại người đang đăng
//      nhập có phải chủ công tắc không

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_premium_override.dart';

void main() {
  group('canTogglePremium', () {
    test('đúng danh sách tài khoản nội bộ được phép', () {
      expect(kPremiumTogglePermittedEmails, {
        'thedangs7@gmail.com',
        'ngduythong1412@gmail.com',
      });
      for (final e in kPremiumTogglePermittedEmails) {
        expect(canTogglePremium(e), isTrue, reason: 'chặn nhầm $e');
      }
    });

    test('danh sách viết sẵn chữ thường', () {
      // canTogglePremium hạ email về chữ thường rồi mới tra Set. Một mục viết
      // hoa trong danh sách sẽ không bao giờ khớp — hỏng lặng lẽ.
      for (final e in kPremiumTogglePermittedEmails) {
        expect(e, e.toLowerCase(), reason: '$e phải viết thường');
      }
    });

    test('bỏ qua hoa thường và khoảng trắng thừa', () {
      // Supabase trả email đúng như lúc đăng ký; một chữ hoa lạc chỗ không nên
      // làm mất công tắc.
      expect(canTogglePremium('TheDangS7@Gmail.com'), isTrue);
      expect(canTogglePremium('  thedangs7@gmail.com  '), isTrue);
    });

    test('mọi tài khoản khác đều không', () {
      for (final other in [
        'yumi.cloudncoral@gmail.com',
        // Những biến thể gần giống — chặn được kiểu email na ná.
        'ngduythong141414@gmail.com',
        'thedangs7@gmail.com.vn',
        'xthedangs7@gmail.com',
        'thedangs7@gmail.co',
        '',
        null,
      ]) {
        expect(canTogglePremium(other), isFalse, reason: 'lọt: $other');
      }
    });
  });

  group('overrideForAccount', () {
    const owner = 'thedangs7@gmail.com';

    test('chủ công tắc đọc lại được đúng giá trị mình đã bật', () {
      for (final v in [true, false]) {
        expect(
          overrideForAccount(stored: v, storedOwner: owner, current: owner),
          v,
        );
      }
    });

    test('người khác đăng nhập trên cùng máy thì công tắc vô hiệu', () {
      // Đây là lỗ hổng phải bịt: SharedPreferences lưu theo MÁY. Bật một lần
      // rồi đưa máy cho người khác đăng nhập là họ thành Premium.
      expect(
        overrideForAccount(
          stored: true,
          storedOwner: owner,
          current: 'nguoikhac@gmail.com',
        ),
        isNull,
      );
    });

    test('email nội bộ KHÁC cũng không dùng được công tắc của nhau', () {
      expect(
        overrideForAccount(
          stored: true,
          storedOwner: owner,
          current: 'ngduythong1412@gmail.com',
        ),
        isNull,
      );
    });

    test('dữ liệu bản cũ (không ghi chủ) bị bỏ', () {
      // Bản trước chỉ lưu true/false. Giữ lại là cấp Premium cho bất kỳ ai đăng
      // nhập sau đó trên máy đã từng bật.
      expect(
        overrideForAccount(stored: true, storedOwner: null, current: owner),
        isNull,
      );
    });

    test('chưa đăng nhập thì vô hiệu', () {
      expect(
        overrideForAccount(stored: true, storedOwner: owner, current: null),
        isNull,
      );
    });

    test('chưa từng bật thì trả null', () {
      expect(
        overrideForAccount(stored: null, storedOwner: null, current: owner),
        isNull,
      );
    });

    test('bỏ qua hoa thường khi đối chiếu chủ công tắc', () {
      expect(
        overrideForAccount(
          stored: true,
          storedOwner: 'TheDangS7@Gmail.com',
          current: '  thedangs7@gmail.com ',
        ),
        isTrue,
      );
    });
  });

  group('resolvePremium', () {
    test('chưa động vào công tắc thì trả gói thật', () {
      for (final actual in [true, false]) {
        expect(
          resolvePremium(actual: actual, override: null, allowed: true),
          actual,
        );
      }
    });

    test('công tắc ép được cả hai chiều', () {
      expect(resolvePremium(actual: false, override: true, allowed: true),
          isTrue);
      // Chiều ngược lại quan trọng ngang chiều bật: người đang có Premium thật
      // vẫn phải xem được bản miễn phí trông ra sao.
      expect(resolvePremium(actual: true, override: false, allowed: true),
          isFalse);
    });

    test('KHÔNG được phép thì công tắc vô hiệu, kể cả đang bật', () {
      // Đây là cái chốt. Công tắc lưu trên máy chứ không theo tài khoản — đăng
      // xuất rồi người khác đăng nhập trên cùng máy mà cờ cũ còn hiệu lực thì
      // công cụ thử nghiệm thành lỗ hổng.
      expect(
        resolvePremium(actual: false, override: true, allowed: false),
        isFalse,
      );
      expect(
        resolvePremium(actual: true, override: false, allowed: false),
        isTrue,
        reason: 'người khác không được phép bị công tắc hạ gói thật xuống',
      );
    });
  });
}
