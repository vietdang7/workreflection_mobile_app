import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// Be Vietnam Pro phải nạp được từ assets/google_fonts mà KHÔNG cần mạng.
//
// Trước 08/10 font này tải qua mạng lúc chạy. Khung hình đầu dựng bằng font
// dự phòng, lưới check-in ở Home đo chiều cao ô theo chữ hẹp hơn, rồi font
// thật về làm chữ rộng ra một dòng mà ô không cao theo: "Tôi mệt mỏi cần nghỉ
// ngơi" mất chữ "ngơi" trên máy thật. Thiếu file cho một độ đậm mà theme dùng
// thì test này đỏ, thay vì app lặng lẽ quay lại tải qua mạng.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('textTheme Be Vietnam Pro nạp trọn từ assets, tắt tải mạng', () async {
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(() => GoogleFonts.config.allowRuntimeFetching = true);

    // google_fonts không ném lỗi khi thiếu file, chỉ `print` rồi để chữ rơi
    // về font dự phòng; nên phải bắt chính dòng log đó.
    final logs = <String>[];
    await runZoned(
      () async {
        GoogleFonts.beVietnamProTextTheme();
        await GoogleFonts.pendingFonts();
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => logs.add(line),
      ),
    );
    expect(logs.where((l) => l.contains('unable to load font')), isEmpty);
  });
}
