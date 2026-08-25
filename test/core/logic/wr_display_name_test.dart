// Tên để chào — khách báo họp 26_1: "app chào bằng email chứ không chào bằng
// tên".
//
// Ba luật ở đây, cả ba đều đã từng bị vi phạm trong dữ liệu thật:
//   1. Không bao giờ dùng email làm tên, kể cả khi email đang nằm sẵn trong ô
//      tên của DB (hàng `demo.review@workreflection.app` có `display_name` là
//      chính địa chỉ email đó).
//   2. Tài khoản đăng ký từ app di động có `cc_profiles.full_name = NULL` — tên
//      chỉ có ở metadata hoặc ở bảng của app, phải đọc tiếp chứ không dừng.
//   3. Không biết tên thì trả null để màn hình nói "bạn", không bịa.
//
// Run: flutter test test/core/logic/wr_display_name_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_display_name.dart';

void main() {
  group('looksLikeEmail', () {
    test('có @ là email', () {
      expect(looksLikeEmail('demo.review@workreflection.app'), isTrue);
    });

    test('tên người thì không', () {
      expect(looksLikeEmail('Nguyễn Duy Thông'), isFalse);
      expect(looksLikeEmail('thong'), isFalse);
    });
  });

  group('wrGreetingName', () {
    test('ưu tiên cc_profiles.full_name', () {
      expect(
        wrGreetingName(
          ccFullName: 'Trần Thị Mỹ Dung',
          displayName: 'dung',
          userMetadata: const {'name': 'Dung T.'},
        ),
        'Trần Thị Mỹ Dung',
      );
    });

    test('không có cc thì đọc display_name của app', () {
      // Đúng trường hợp tài khoản đăng ký từ app di động trước bản sửa này:
      // trigger `handle_new_user` đọc `full_name`, app lại gửi `display_name`,
      // nên cột bên cc_profiles là NULL.
      expect(
        wrGreetingName(ccFullName: null, displayName: 'duy thong'),
        'duy thong',
      );
    });

    test('không có bảng nào thì đọc metadata — kể cả khoá của Google', () {
      expect(
        wrGreetingName(userMetadata: const {'name': 'Duy Thông'}),
        'Duy Thông',
      );
      expect(
        wrGreetingName(userMetadata: const {'full_name': 'Duy Thông'}),
        'Duy Thông',
      );
      expect(
        wrGreetingName(userMetadata: const {'display_name': 'Duy Thông'}),
        'Duy Thông',
      );
    });

    test('EMAIL trong ô tên bị bỏ qua, không được dùng làm tên', () {
      // Hàng thật trong DB: wr_mobile_profiles.display_name =
      // 'demo.review@workreflection.app'. Không migration nào chữa được dữ liệu
      // người dùng thật, nên nơi ĐỌC phải tự nhận ra.
      expect(
        wrGreetingName(displayName: 'demo.review@workreflection.app'),
        isNull,
      );
    });

    test('email ở ô trước không chặn tên thật ở ô sau', () {
      expect(
        wrGreetingName(
          displayName: 'demo.review@workreflection.app',
          userMetadata: const {'full_name': 'App Review Demo'},
        ),
        'App Review Demo',
      );
    });

    test('chuỗi rỗng và chuỗi toàn khoảng trắng đều là chưa biết tên', () {
      expect(wrGreetingName(ccFullName: '', displayName: '   '), isNull);
    });

    test('cắt khoảng trắng thừa', () {
      expect(wrGreetingName(ccFullName: '  Thông  '), 'Thông');
    });

    test('không có gì thì null, KHÔNG trả sẵn chữ "bạn"', () {
      // Nơi gọi cần phân biệt được: avatar dựng chữ tắt từ tên, mà "bạn" thì
      // không có chữ tắt nào có nghĩa.
      expect(wrGreetingName(), isNull);
    });
  });

  group('wrGreeting', () {
    test('có tên thì gọi tên', () {
      expect(wrGreeting('Thông'), 'Chào Thông');
    });

    test('không có tên thì "Chào bạn"', () {
      expect(wrGreeting(null), 'Chào bạn');
    });
  });
}
