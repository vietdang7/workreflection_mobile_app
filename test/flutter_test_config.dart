// Cấu hình chạy trước MỌI test trong thư mục này (Flutter tự nhận file tên
// `flutter_test_config.dart`).
//
// Tắt phép nối cụm cuối câu của [WrParagraph]. Hàng chục widget test đối chiếu
// nguyên văn chuỗi hiển thị bằng `find.text('…')`; nếu để bật, khoảng trắng
// thường bị đổi thành U+00A0 và những test đó trượt hàng loạt mà không phản
// ánh lỗi nào của sản phẩm. Phép nối vẫn được kiểm riêng, trực tiếp trên hàm,
// ở `test/core/wr_paragraph_test.dart`.
import 'dart:async';

import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  wrParagraphKeepsTail = false;
  await testMain();
}
