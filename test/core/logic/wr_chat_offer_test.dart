// Suy lại nút chatbox từ câu chữ khi đọc lại lịch sử.
//
// Bộ ca chính nằm ở `supabase/functions/wr-chat/offer_cases.json` và được
// test Deno của máy chủ chạy y hệt: hai bản mẫu (TS và Dart) phải cho cùng kết
// quả, nếu không thì cái nút app hiện lúc chat khác cái nút app hiện lúc mở lại.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_chat_offer.dart';
import 'package:workreflection_mobile/core/models/wr_chat.dart';

WrChatMessage _assistant(String text) =>
    WrChatMessage(role: WrChatRole.assistant, content: text);
WrChatMessage _user(String text) =>
    WrChatMessage(role: WrChatRole.user, content: text);

void main() {
  group('inferChatAction khớp bộ ca dùng chung với máy chủ', () {
    final raw = File(
      'supabase/functions/wr-chat/offer_cases.json',
    ).readAsStringSync();
    final cases = (jsonDecode(raw)['cases'] as List)
        .cast<Map<String, dynamic>>();

    for (final c in cases) {
      final text = c['text'] as String;
      test(text, () {
        expect(
          inferChatAction(text),
          WrChatAction.fromWire(c['expect'] as String?),
        );
      });
    }
  });

  group('restoreLastChatAction', () {
    const offer =
        'Xin lỗi bạn, mình đã sơ suất quên đặt nút mở bài đọc. Bạn có muốn '
        'thử một bài đọc ngắn để thấy nhẹ lòng hơn lúc này không?';

    test('lượt cuối của trợ lý có lời mời thì có lại nút', () {
      final out = restoreLastChatAction([
        _user('khá là căng thẳng'),
        _assistant(offer),
      ]);

      expect(out.last.action, WrChatAction.calm);
      expect(out.last.content, offer);
    });

    test('chỉ lượt CUỐI được suy lại, lượt cũ hơn vẫn không có nút', () {
      final out = restoreLastChatAction([
        _assistant(offer),
        _user('ừ'),
        _assistant('Mình ở đây khi nào bạn muốn nói tiếp.'),
      ]);

      expect(out.map((m) => m.action), everyElement(isNull));
    });

    test('người dùng đã nói sau lời mời thì không suy lại', () {
      final out = restoreLastChatAction([_assistant(offer), _user('thôi')]);

      expect(out.first.action, isNull);
    });

    test('lịch sử rỗng không lỗi', () {
      expect(restoreLastChatAction(const []), isEmpty);
    });
  });
}
