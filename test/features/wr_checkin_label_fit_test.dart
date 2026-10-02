// Nhãn ô check-in không được tự xuống thêm dòng ở màn hẹp nhất hỗ trợ (320px).
// Ô cao cố định theo số dòng `\n` của nhãn, nên một dòng tự xuống thêm sẽ bị cắt
// (ảnh test máy thật 02/10: "I am tired / and need / rest" mất chữ "rest").
//
// Bề rộng lòng ô ở 320 logical px, đọc từ layout thật của wr_home_screen.dart:
//   ListView padding ngang 22          -> 320 - 2*22         = 276
//   WrCardMinimal: padding 20 + viền 1 -> 276 - 2*(20 + 1)   = 234
//   hai ô một hàng, khe SizedBox 12    -> (234 - 12) / 2     = 111
//   _CheckinTile: padding 10 + viền 1.5 -> 111 - 2*(10+1.5)  = 88
//
// Phải đo bằng font thật: app dùng Be Vietnam Pro (GoogleFonts, tải lúc chạy)
// còn bộ test mặc định rơi về Ahem (mỗi chữ rộng đúng 1em, rộng hơn thật nhiều
// nên mọi nhãn đều "tràn"). Bản SemiBold (w600, SIL OFL 1.1) được chép vào
// test/fixtures/fonts để đo offline.
//
// Run: flutter test test/features/wr_checkin_label_fit_test.dart

import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_home_screen.dart';

const double _screen = 320;
const double _tileText = (_screen - 2 * 22 - 2 * 21 - 12) / 2 - 2 * 11.5;

void main() {
  setUpAll(() async {
    final bytes = File(
      'test/fixtures/fonts/BeVietnamPro-SemiBold.ttf',
    ).readAsBytesSync();
    final loader = FontLoader('BeVietnamPro')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  test('bề rộng lòng ô tính ra 88', () => expect(_tileText, 88));

  for (final lang in ['vi', 'en']) {
    final name = lang == 'vi'
        ? '[vi] ĐÃ BIẾT: tired + outofsync tràn dòng ở 320px, chờ khách chốt '
              'chữ (đổi sang isEmpty khi sửa)'
        : '[en] không nhãn nào tự xuống thêm dòng ở 320px';
    test(name, () {
      wrSetLocale(lang);
      addTearDown(() => wrSetLocale('vi'));
      final bad = <String>[];
      for (final o in kCheckinOptions) {
        final tp = TextPainter(
          text: TextSpan(
            text: o.label,
            style: const TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: _tileText);
        final expected = '\n'.allMatches(o.label).length + 1;
        final got = tp.computeLineMetrics().length;
        if (got > expected) {
          bad.add('${o.id}: "${o.label}" $got dòng > $expected');
        }
      }
      if (lang == 'vi') {
        // Đã biết, CHƯA sửa (brief T1: không tự đổi chữ VI, báo lại). Hai nhãn
        // này tự xuống dòng ở 320px; ở khổ 360px+ thì vừa. Khi khách chốt chữ
        // mới, đổi thành `expect(bad, isEmpty)`.
        expect(bad.map((e) => e.split(':').first), ['tired', 'outofsync']);
      } else {
        expect(bad, isEmpty);
      }
    });
  }
}
