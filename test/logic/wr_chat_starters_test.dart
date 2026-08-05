// Test cho gợi ý mở lời màn trò chuyện.
//
// Vì sao đáng test riêng: đây là chỗ ĐẦU TIÊN người dùng nhìn thấy ở màn chat,
// trước cả khi gõ chữ nào. Một gợi ý nói sai về họ ở đúng chỗ đó là phủ nhận
// mệnh đề nền của cả sản phẩm, "AI nhìn thấy mẫu hình", ngay trước khi họ kịp
// thử.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_chat_starters.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

WrSituation sit(String code, String text) => WrSituation(
      code: code,
      text: text,
      scaDimension: ScaDimension.c3,
      wave: 1,
    );

final _situations = [
  sit('C3-01', 'Tôi biết có vấn đề nhưng không muốn nói'),
  sit('C2-02', 'Cuộc họp kết thúc nhưng điều quan trọng nhất vẫn chưa được nói ra'),
  sit('A1-06', 'Tôi đang phát triển hay chỉ đang bận?'),
];

void main() {
  group('đổi ngôi tôi sang mình', () {
    test('giữ nguyên hoa thường của chữ đầu', () {
      expect(
        vietnameseFirstPerson('Tôi biết có vấn đề nhưng không muốn nói'),
        'Mình biết có vấn đề nhưng không muốn nói',
      );
      expect(vietnameseFirstPerson('Việc của tôi'), 'Việc của mình');
    });

    test('KHÔNG đụng vào chữ khác chỉ vì trông giống', () {
      // Đây là lý do không dùng `\b`: trong Dart nó chỉ hiểu ASCII nên cắt sai ở
      // ranh giới chữ có dấu.
      expect(vietnameseFirstPerson('Buổi tối hôm qua'), 'Buổi tối hôm qua');
      expect(vietnameseFirstPerson('Thôi không nói nữa'), 'Thôi không nói nữa');
      expect(vietnameseFirstPerson('Tôi thôi việc'), 'Mình thôi việc');
    });

    test('câu không có đại từ thì giữ nguyên', () {
      const s = 'Cuộc họp kết thúc nhưng điều quan trọng nhất vẫn chưa được nói ra';
      expect(vietnameseFirstPerson(s), s);
    });
  });

  group('dựng gợi ý', () {
    test('chưa chọn tình huống nào thì rơi về danh sách dự phòng', () {
      expect(
        chatStarters(recent: const [], situations: _situations),
        kDefaultChatStarters,
      );
    });

    test('tình huống chọn nhiều nhất lên đầu', () {
      final out = chatStarters(
        recent: const ['A1-06', 'C3-01', 'C3-01', 'C3-01', 'A1-06'],
        situations: _situations,
      );

      expect(out.first, 'Mình biết có vấn đề nhưng không muốn nói');
      expect(out[1], 'Mình đang phát triển hay chỉ đang bận?');
    });

    test('BÙ cho đủ ba ô, không thay thế hết', () {
      // Người mới có đúng một tình huống vẫn phải thấy đủ ba ô để bấm. Hiện mỗi
      // một ô làm màn hình trông như đang hỏng.
      final out = chatStarters(recent: const ['C3-01'], situations: _situations);

      expect(out.length, 3);
      expect(out.first, 'Mình biết có vấn đề nhưng không muốn nói');
      expect(out.sublist(1), kDefaultChatStarters.take(2));
    });

    test('KHÔNG áp ngưỡng ba lần', () {
      // Ngưỡng đó chỉ dành cho phần hiển thị "Tình huống lặp lại", nơi màn hình
      // khẳng định một điều đang trở đi trở lại. Một gợi ý mở lời không khẳng
      // định gì cả.
      final out = chatStarters(recent: const ['C3-01'], situations: _situations);
      expect(out.first, contains('biết có vấn đề'));
    });

    test('mã không tra được tiêu đề thì BỎ HẲN, không đưa mã thô ra màn hình', () {
      // "C3-01" nằm trong danh sách cấm của system prompt, và người dùng cũng
      // chẳng hiểu nó.
      final out = chatStarters(
        recent: const ['MÃ-KHÔNG-CÓ', 'MÃ-KHÔNG-CÓ', 'C3-01'],
        situations: _situations,
      );

      expect(out.any((s) => s.contains('MÃ-KHÔNG-CÓ')), isFalse);
      expect(out.first, 'Mình biết có vấn đề nhưng không muốn nói');
    });

    test('không lặp lại cùng một câu hai lần', () {
      final out = chatStarters(
        recent: const ['C3-01', 'C3-01'],
        situations: [..._situations, sit('C3-99', 'Tôi biết có vấn đề nhưng không muốn nói')],
      );
      expect(out.toSet().length, out.length);
    });

    test('không bao giờ trả về quá số ô yêu cầu', () {
      final out = chatStarters(
        recent: const ['C3-01', 'C2-02', 'A1-06'],
        situations: _situations,
      );
      expect(out.length, kChatStarterCount);
    });
  });
}
