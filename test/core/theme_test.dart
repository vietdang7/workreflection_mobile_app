import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_colors.dart';
import 'package:workreflection_mobile/core/theme/wr_theme.dart';

void main() {
  group('WrColors', () {
    test('navy is #093774', () {
      expect(WrColors.navy, const Color(0xFF093774));
    });

    test('coral is #FF6859', () {
      expect(WrColors.coral, const Color(0xFFFF6859));
    });

    test('teal is #15B5B0', () {
      expect(WrColors.teal, const Color(0xFF15B5B0));
    });

    test('cream is #FFF3E6', () {
      expect(WrColors.cream, const Color(0xFFFFF3E6));
    });

    test('dark is #2C335D', () {
      expect(WrColors.dark, const Color(0xFF2C335D));
    });

    // Spec §01b: chữ phụ không được là xám trung tính, phải là Deep Space pha
    // alpha (--text-2). #8A95A3 cũ là lỗi.
    test('muted is text-2 rgba(44,51,93,0.72)', () {
      expect(WrColors.muted, const Color(0xB82C335D));
      expect(WrColors.muted, WrColors.text2);
    });

    test('white is #FFFFFF', () {
      expect(WrColors.white, const Color(0xFFFFFFFF));
    });

    test('destructive is #FF3B30', () {
      expect(WrColors.destructive, const Color(0xFFFF3B30));
    });
  });

  // wrColorScheme() is a pure function — no font loading — safe to test without
  // the Flutter binding or GoogleFonts config.
  group('wrColorScheme', () {
    test('primary color is navy', () {
      expect(wrColorScheme().primary, WrColors.navy);
    });

    test('secondary color is coral', () {
      expect(wrColorScheme().secondary, WrColors.coral);
    });

    test('tertiary color is teal', () {
      expect(wrColorScheme().tertiary, WrColors.teal);
    });

    test('surface is white', () {
      expect(wrColorScheme().surface, WrColors.white);
    });
  });

  group('wrTheme', () {
    // Spec §01: nền toàn màn hình là Cream BG #FBF9F5. Trắng thuần làm thẻ
    // trắng chìm mất, đây là lỗi cũ đã sửa — giữ chốt để không quay lại.
    testWidgets('scaffold background is cream, not pure white', (tester) async {
      expect(wrTheme().scaffoldBackgroundColor, WrColors.pageBg);
      expect(wrTheme().scaffoldBackgroundColor, const Color(0xFFFBF9F5));
    });
  });

  group('WrTextStyles', () {
    test('eyebrow is 11px weight 700 text-3', () {
      final style = WrTextStyles.eyebrow;
      expect(style.fontSize, 11);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, WrColors.text3);
    });

    test('hLarge is 22px weight 700 navy', () {
      final style = WrTextStyles.hLarge;
      expect(style.fontSize, 22);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, WrColors.navy);
    });

    test('hMedium is 16px weight 600 dark', () {
      final style = WrTextStyles.hMedium;
      expect(style.fontSize, 16);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, WrColors.dark);
    });

    test('body is 14px height 1.5', () {
      final style = WrTextStyles.body;
      expect(style.fontSize, 14);
      expect(style.height, 1.5);
    });

    test('insightQuote is 20px italic navy height 1.45', () {
      final style = WrTextStyles.insightQuote;
      expect(style.fontSize, 20);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.color, WrColors.navy);
      expect(style.height, 1.45);
    });

    test('dateTitle is 32px weight 800 navy', () {
      final style = WrTextStyles.dateTitle;
      expect(style.fontSize, 32);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.color, WrColors.navy);
    });

    test('greeting is 14px muted', () {
      final style = WrTextStyles.greeting;
      expect(style.fontSize, 14);
      expect(style.color, WrColors.muted);
    });
  });
}
