// Ba rào chắn của lớp 3 — §7.2 (`WorkReflection_DienGiaiSau_NoiDung.docx`).
//
// §7.2 định nghĩa cả ba rào bằng cùng một hành vi dự phòng: "Cả ba rào chắn đều
// rơi về cùng một hành vi dự phòng: dùng câu đã ghép ở lớp 2. Vì câu đó vốn đã
// hoàn chỉnh và đọc được, việc AI thất bại không gây hậu quả gì cho người dùng."
//
// Nên nhóm test này khoá HAI điều, và điều thứ hai quan trọng hơn:
//   1. Rào chắn có bắt đúng những ca nó phải bắt.
//   2. Bắt rồi thì câu GỐC lên màn hình, không phải một chuỗi rỗng.
//
// Run: flutter test test/core/logic/wr_polish_guard_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_polish_guard.dart';

void main() {
  const original =
      'Bạn đã nhìn lại 21 lần trong 30 ngày qua, tăng so với 12 lần của '
      'tháng trước. Điều gì đang khiến bạn quay lại thường xuyên hơn?';

  group('rào chắn 1 · con số', () {
    test('câu viết lại giữ nguyên số thì qua', () {
      expect(
        inspectPolished(
          original: original,
          polished: 'Trong 30 ngày qua bạn nhìn lại 21 lần, nhiều hơn 12 lần '
              'của tháng trước. Điều gì khiến bạn quay lại đều hơn vậy?',
        ),
        isNull,
      );
    });

    test('đổi một con số là huỷ', () {
      expect(
        inspectPolished(
          original: original,
          polished: 'Bạn đã nhìn lại 20 lần trong 30 ngày qua, tăng so với 12 '
              'lần của tháng trước. Điều gì khiến bạn quay lại đều hơn?',
        ),
        PolishRejection.numbersChanged,
      );
    });

    test('bỏ bớt hoặc thêm một con số là huỷ', () {
      expect(
        inspectPolished(
          original: 'Bạn đã nhìn lại 21 lần.',
          polished: 'Bạn đã nhìn lại nhiều lần.',
        ),
        PolishRejection.numbersChanged,
      );
    });

    test('TRÁO số giữa hai đơn vị là huỷ', () {
      // Chỗ dễ làm sai nhất của rào chắn 1: so tập hợp trần thì ca này lọt, mà
      // "3 lần trong 14 ngày" và "14 lần trong 3 ngày" nói hai điều khác hẳn.
      expect(
        inspectPolished(
          original: '3 lần trong 14 ngày.',
          polished: '14 lần trong 3 ngày.',
        ),
        PolishRejection.numbersChanged,
      );
    });

    test('ĐẢO MỆNH ĐỀ thì qua — đó là việc model được giao', () {
      // Ca này lộ ra ngay khi viết test và làm đổi hẳn luật của rào chắn 1.
      // Bản đầu so hai dãy số theo thứ tự xuất hiện, nên nó huỷ câu dưới đây —
      // một bản viết lại không đổi con số nào, chỉ đưa mệnh đề thời gian lên
      // trước. Chặt kiểu đó thì phần lớn bản viết lại tốt đều bị huỷ và lớp 3
      // không bao giờ hiện.
      expect(
        inspectPolished(
          original: 'Bạn đã nhìn lại 21 lần trong 30 ngày qua.',
          polished: 'Trong 30 ngày qua, bạn đã nhìn lại 21 lần.',
        ),
        isNull,
      );
    });

    test('numberUnitPairs ghép số với đơn vị và sắp xếp', () {
      expect(
        numberUnitPairs('21 lần trong 30 ngày'),
        ['21|lần', '30|ngày'],
      );
      // Đảo chỗ ra cùng một danh sách — đó là điều làm nên khác biệt.
      expect(
        numberUnitPairs('30 ngày, 21 lần'),
        ['21|lần', '30|ngày'],
      );
    });

    test('đổi dấu thập phân KHÔNG phải đổi số', () {
      // Model đổi qua lại giữa "3.8" và "3,8" rất thường xuyên. Coi đó là đổi
      // số thì rào chắn 1 huỷ gần như mọi câu có điểm Self-Check, và lớp 3
      // không bao giờ chạy.
      expect(
        inspectPolished(
          original: 'Bạn tự chấm 3.8 điểm.',
          polished: 'Bạn tự chấm 3,8 điểm.',
        ),
        isNull,
      );
    });

    test('model viết số bằng CHỮ thì bị huỷ — và như vậy là đúng', () {
      // Ca này lộ ra ngay khi viết test: model rất hay đổi "30 ngày" thành "ba
      // mươi ngày". Nghiêm ngặt mà nói nó không đổi con số, nhưng rào chắn 1
      // không có cách nào biết — và không nên có: chấp nhận số viết bằng chữ
      // nghĩa là phải phân giải "ba mươi" thành 30, tức là mở cửa cho một tầng
      // đoán mới ngay giữa cái tầng sinh ra để CHẶN việc đoán.
      //
      // Huỷ ở đây chỉ mất một câu mượt hơn; nhận nhầm thì lọt một con số sai.
      expect(
        inspectPolished(
          original: 'Bạn đã nhìn lại 21 lần trong 30 ngày qua.',
          polished: 'Bạn đã nhìn lại 21 lần trong ba mươi ngày qua.',
        ),
        PolishRejection.numbersChanged,
      );
    });

    test('extractNumbers giữ đúng thứ tự và chuẩn hoá dấu', () {
      expect(extractNumbers('21 lần, 3,8 điểm, 30 ngày'), ['21', '3.8', '30']);
    });
  });

  group('rào chắn 2 · từ cấm', () {
    test('mỗi từ cấm đều bị bắt', () {
      for (final w in kPolishBannedWords) {
        expect(
          inspectPolished(original: 'Bạn ổn.', polished: 'Bạn $w.'),
          PolishRejection.bannedWord,
          reason: 'từ cấm "$w" lọt lưới',
        );
      }
    });

    test('bắt cả khi model viết hoa', () {
      expect(
        inspectPolished(original: 'Bạn ổn.', polished: 'Bạn Burnout.'),
        PolishRejection.bannedWord,
      );
    });
  });

  group('§7.1 quy tắc 7 · độ dài', () {
    test('dài hơn 20% là huỷ', () {
      expect(
        inspectPolished(
          original: 'Bạn đã nhìn lại đều hơn.',
          polished: 'Bạn đã nhìn lại đều hơn, và đó là một điều rất đáng ghi '
              'nhận trong quãng vừa rồi của bạn.',
        ),
        PolishRejection.lengthDrift,
      );
    });

    test('ngắn hơn 20% cũng là huỷ', () {
      // Ngắn quá nghĩa là model đã BỎ BỚT nội dung, không phải viết mượt hơn.
      expect(
        inspectPolished(original: original, polished: 'Bạn nhìn lại 21 lần.'),
        anyOf(PolishRejection.lengthDrift, PolishRejection.numbersChanged),
      );
    });

    test('rỗng là huỷ', () {
      expect(
        inspectPolished(original: original, polished: '   '),
        PolishRejection.empty,
      );
    });
  });

  group('mọi nhánh huỷ đều rơi về CÂU GỐC', () {
    test('null vào thì ra câu gốc', () {
      expect(polishedOrOriginal(original: original), original);
    });

    test('bản bị huỷ thì ra câu gốc, không ra chuỗi rỗng', () {
      for (final bad in ['', 'Bạn burnout rồi.', 'Bạn nhìn lại 99 lần.']) {
        expect(
          polishedOrOriginal(original: original, polished: bad),
          original,
          reason: 'bản "$bad" phải rơi về câu gốc',
        );
      }
    });

    test('bản qua được cả ba rào thì ra bản đó', () {
      const good = 'Trong 30 ngày qua bạn nhìn lại 21 lần, nhiều hơn 12 lần '
          'của tháng trước. Điều gì khiến bạn quay lại đều hơn vậy?';
      expect(
        polishedOrOriginal(original: original, polished: good),
        good,
      );
    });
  });

  group('cờ cấu hình', () {
    test('mặc định TẮT', () {
      // §7.3 cho phép tắt bằng cờ. Mặc định tắt là quyết định có chủ đích: lớp
      // 3 làm câu chữ không còn định trước được, nên khách phải đồng ý với giọng
      // đó trước khi bật cho người dùng thật.
      expect(kPolishEnabled, isFalse);
    });

    test('trần chờ đúng 2 giây như §7.2 rào chắn 3', () {
      expect(kPolishTimeout, const Duration(seconds: 2));
    });
  });
}
