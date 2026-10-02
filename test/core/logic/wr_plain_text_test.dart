// Tầng lọc Markdown phía app — mục 17.1 (khách 09/09/2026).
//
// Bản Deno ở `supabase/functions/_shared/strip_markdown.ts` đã có test riêng
// (`reply_shaping_test.ts`). Nhóm dưới đây khoá bản Dart theo ĐÚNG những ca mà
// bản Deno đã học được khi chạy thật, để hai bản không lệch nhau — lệch thì
// cùng một câu đọc ra hai kiểu tuỳ nó đi đường nào.
//
// Run: flutter test test/core/logic/wr_plain_text_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_plain_text.dart';
import 'package:workreflection_mobile/core/models/wr_chat.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

void main() {
  group('stripMarkdown', () {
    test('lột đậm, nghiêng, và đậm-nghiêng', () {
      expect(
        stripMarkdown('một điều **quan trọng** với bạn'),
        'một điều quan trọng với bạn',
      );
      expect(
        stripMarkdown('một điều *quan trọng* với bạn'),
        'một điều quan trọng với bạn',
      );
      expect(
        stripMarkdown('một điều ***quan trọng*** với bạn'),
        'một điều quan trọng với bạn',
      );
    });

    test('`***` phải xử lý TRƯỚC `**` và `*`', () {
      // Sai thứ tự thì luật một-sao ăn mất một lớp và chừa lại `*a*` trên màn
      // hình — tệ hơn là để nguyên, vì nó trông như lỗi hiển thị.
      expect(stripMarkdown('**a**'), 'a');
      expect(stripMarkdown('***a***'), 'a');
    });

    test('KHÔNG lột `__gạch dưới__`', () {
      // Không phân biệt được `__đậm__` với một tên có gạch dưới hai đầu. Model
      // này viết đậm bằng `**`; chữ người dùng dán vào thì có thể chứa gạch
      // dưới thật.
      expect(stripMarkdown('cột __init__ của tôi'), 'cột __init__ của tôi');
    });

    test('bỏ tiêu đề và gạch đầu dòng, giữ chữ', () {
      expect(
        stripMarkdown('## Ba điều\n- một\n* hai\n+ ba'),
        'Ba điều\nmột\nhai\nba',
      );
    });

    test('lột nháy ngược và liên kết, bỏ đường dẫn', () {
      expect(stripMarkdown('gõ `flutter test` nhé'), 'gõ flutter test nhé');
      expect(stripMarkdown('xem [trang này](https://a.b/c)'), 'xem trang này');
    });

    test('gộp ba dòng trống trở lên còn một', () {
      expect(stripMarkdown('a\n\n\n\nb'), 'a\n\nb');
    });

    test('không phá dấu sao đứng một mình giữa câu', () {
      // Người dùng gõ một dấu sao lẻ thì nó không phải cú pháp Markdown. Ăn nó
      // đi là sửa chữ của họ.
      expect(stripMarkdown('lương 5 * 3 triệu'), 'lương 5 * 3 triệu');
    });

    test('stripMarkdownOrNull: null vào null ra', () {
      expect(stripMarkdownOrNull(null), isNull);
      expect(stripMarkdownOrNull('**a**'), 'a');
    });
  });

  group('cửa vào của model — lọc ở fromJson, không rải ở widget', () {
    test('bài Diễn biến được lột khi đọc từ database', () {
      // Bài đã sinh TRƯỚC hôm bật bộ lọc ở Edge Function vẫn còn nguyên dấu sao
      // trong database, nên lọc ở hàm sinh là không đủ.
      final n = PatternNarrative.fromJson({
        'user_id': 'u1',
        'narrative': 'Ba tháng qua bạn **quay lại** chuyện này nhiều lần.',
      });
      expect(n.narrative, 'Ba tháng qua bạn quay lại chuyện này nhiều lần.');
    });

    test('bản phân tích JD được lột cả trường lẻ lẫn danh sách', () {
      final a = WrDocAnalysis.fromJson({
        'title': '**Chuyên viên** Nhân sự',
        'summary': 'Vị trí *phụ trách* tuyển dụng.',
        'responsibilities': ['- Tuyển dụng', '**Đào tạo** nội bộ'],
      });
      expect(a.title, 'Chuyên viên Nhân sự');
      expect(a.summary, 'Vị trí phụ trách tuyển dụng.');
      expect(a.responsibilities, ['Tuyển dụng', 'Đào tạo nội bộ']);
    });

    test('lượt TRỢ LÝ được lột, lượt NGƯỜI DÙNG giữ nguyên', () {
      // Đây là chỗ dễ làm sai nhất của cả mục 17.1: `content` chở cả hai vai.
      // Lột cả lượt người dùng là âm thầm sửa chữ của họ.
      final bot = WrChatMessage.fromJson({
        'role': 'assistant',
        'content': 'Điều **đáng chú ý** là bạn đã nhận ra nó.',
      });
      expect(bot.content, 'Điều đáng chú ý là bạn đã nhận ra nó.');

      final me = WrChatMessage.fromJson({
        'role': 'user',
        'content': 'sếp bảo mình *phải* xong trong 2 ngày',
      });
      expect(me.content, 'sếp bảo mình *phải* xong trong 2 ngày');
    });

    test('câu trả lời một lượt gửi cũng được lột', () {
      final r = WrChatReply.fromJson({
        'reply': 'Mình nghe **rõ** rồi.',
        'usedToday': 1,
        'limit': 5,
      });
      expect(r.reply, 'Mình nghe rõ rồi.');
    });
  });

  group('vết AI: gạch dài và emoji', () {
    test('gạch dài giữa hai chữ thành dấu phẩy, emoji bị bỏ', () {
      expect(
        stripMarkdown('Bạn đã làm tốt — rất tốt 🎉'),
        'Bạn đã làm tốt, rất tốt',
      );
    });

    test('gạch dài sau chữ in đậm/nghiêng vẫn thành dấu phẩy', () {
      expect(stripMarkdown('**Tốt** — rất tốt'), 'Tốt, rất tốt');
      expect(stripMarkdown('*Ý chính* — giải thích'), 'Ý chính, giải thích');
    });

    test('gạch ngắn giữa hai chữ cũng thành dấu phẩy', () {
      expect(stripMarkdown('một việc – một nhịp'), 'một việc, một nhịp');
    });

    test('gạch giữa hai SỐ giữ nguyên', () {
      expect(stripMarkdown('tỉ số 5 – 3'), 'tỉ số 5 – 3');
      expect(stripMarkdown('từ 5 — 7 triệu'), 'từ 5 — 7 triệu');
    });

    test('gạch dài đầu dòng bị bỏ', () {
      expect(
        stripMarkdown('— Xin chào\n— Bạn khỏe không'),
        'Xin chào\nBạn khỏe không',
      );
    });

    test('emoji: đủ loại, kèm U+FE0F và ZWJ mồ côi', () {
      expect(stripMarkdown('Ổn rồi ❤️ nhé'), 'Ổn rồi nhé');
      expect(stripMarkdown('Cả nhà 👨\u200D👩\u200D👧 vui'), 'Cả nhà vui');
      expect(stripMarkdown('🌱 Bắt đầu'), 'Bắt đầu');
      expect(stripMarkdown('Tốt lắm 👍🏽!'), 'Tốt lắm!');
    });

    test('không còn khoảng trắng thừa trước dấu câu', () {
      expect(stripMarkdown('Hay quá 🎉.'), 'Hay quá.');
      expect(stripMarkdown('Hay quá 🎉 , nhỉ'), 'Hay quá, nhỉ');
    });

    test('gạch dài KHÔNG cách giữa hai chữ thành dấu phẩy', () {
      expect(
        stripMarkdown("It's not about speed\u2014it's about clarity."),
        "It's not about speed, it's about clarity.",
      );
      expect(
        stripMarkdown('Slow\u2014steady\u2014and calm'),
        'Slow, steady, and calm',
      );
    });

    test('gạch cách cạnh nháy đóng, ngoặc hoặc chỉ một bên là số', () {
      expect(
        stripMarkdown('\u201CTốt\u201D \u2014 rất tốt'),
        '\u201CTốt\u201D, rất tốt',
      );
      expect(stripMarkdown('Năm 2024 \u2014 mình'), 'Năm 2024, mình');
      expect(stripMarkdown('(xong) \u2013 rồi'), '(xong), rồi');
    });

    test('gạch cách giữa hai SỐ vẫn giữ, kể cả "8h – 17h"', () {
      expect(stripMarkdown('8h \u2013 17h'), '8h \u2013 17h');
      expect(stripMarkdown('5 \u2013 3'), '5 \u2013 3');
    });

    test('gạch kề dấu câu thì chỉ bỏ gạch', () {
      expect(stripMarkdown('Xong \u2014, rồi'), 'Xong, rồi');
      expect(stripMarkdown('Xong \u2014.'), 'Xong.');
      expect(stripMarkdown('Xong, \u2014 rồi'), 'Xong, rồi');
    });

    test('mũi tên không phải emoji; keycap bị gỡ cả U+20E3', () {
      expect(stripMarkdown('Trust \u2194 Autonomy'), 'Trust \u2194 Autonomy');
      expect(stripMarkdown('A \u2192 B'), 'A \u2192 B');
      expect(stripMarkdown('1\uFE0F\u20E3 Bước một'), '1 Bước một');
    });

    test('ký hiệu ©, ® và ™ không bị coi là emoji', () {
      expect(stripMarkdown('WorkReflection™ ©2026'), 'WorkReflection™ ©2026');
    });

    test('chữ Việt có dấu giữa hai bên gạch vẫn được nhận là chữ', () {
      expect(stripMarkdown('chậm lại — ổn định'), 'chậm lại, ổn định');
    });

    test('lượt chat của NGƯỜI DÙNG không bị lọc', () {
      final me = WrChatMessage.fromJson({
        'role': 'user',
        'content': 'sếp bảo — phải xong 🎉',
      });
      expect(me.content, 'sếp bảo — phải xong 🎉');
    });
  });
}
