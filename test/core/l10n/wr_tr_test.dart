// Tầng dịch tại chỗ của phần WorkReflection.
//
// Run: flutter test test/core/l10n/wr_tr_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';

void main() {
  // Mọi bài trong repo đang khoá chuỗi tiếng Việt. Trả biến về mặc định sau
  // mỗi bài, không thì một bài quên dọn làm đỏ hàng trăm bài chạy sau nó — và
  // lỗi sẽ hiện ra ở file khác hẳn với file gây ra.
  tearDown(() => wrEnglish = false);

  test('mặc định là tiếng Việt', () {
    expect(wrEnglish, isFalse);
    expect(tr('Tiếp tục', 'Continue'), 'Tiếp tục');
  });

  test('bật tiếng Anh thì đọc vế thứ hai', () {
    wrSetLocale('en');
    expect(tr('Tiếp tục', 'Continue'), 'Continue');
  });

  test('mã ngôn ngữ lạ rơi về tiếng Việt, không rơi về chuỗi rỗng', () {
    // `appLocaleProvider` giữ chuỗi tự do. Một mã chưa hỗ trợ ('ja', 'fr', hay
    // một giá trị hỏng đọc từ bộ nhớ máy) phải cho ra bản gốc — bản gốc luôn
    // là bản đã được duyệt nội dung.
    wrSetLocale('ja');
    expect(tr('Tiếp tục', 'Continue'), 'Tiếp tục');
    wrSetLocale('');
    expect(tr('Tiếp tục', 'Continue'), 'Tiếp tục');
  });

  test('đổi qua đổi lại đọc đúng ngôn ngữ đang bật', () {
    // Nút đổi ngôn ngữ trong Tài khoản đổi được nhiều lần trong một phiên.
    wrSetLocale('en');
    expect(tr('Xong', 'Done'), 'Done');
    wrSetLocale('vi');
    expect(tr('Xong', 'Done'), 'Xong');
    wrSetLocale('en');
    expect(tr('Xong', 'Done'), 'Done');
  });
}
