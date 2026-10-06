// Nền dùng chung của mockup v47 (M0): hero, dải cảm xúc, thẻ chuẩn.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_ai_voice.dart';
import 'package:workreflection_mobile/core/theme/wr_colors.dart';
import 'package:workreflection_mobile/core/widgets/wr_card.dart';
import 'package:workreflection_mobile/core/widgets/wr_hero_header.dart';

Widget _host(Widget child, {double top = 0}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      padding: EdgeInsets.only(top: top),
    ),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  group('ảnh hero', () {
    test('đủ 13 ảnh trên đĩa và pubspec khai báo thư mục', () {
      final paths = [
        for (final p in WrDayPeriod.values) wrCityHeroAsset(p),
        for (final a in WrHeroArt.values) a.asset,
        for (final m in WrMoodPalette.moods) 'assets/images/hero/band_$m.webp',
      ];
      expect(paths, hasLength(13));
      for (final p in paths) {
        expect(File(p).existsSync(), isTrue, reason: p);
      }
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/images/hero/'),
      );
    });

    test('tối và khuya là ảnh tối, sáng và chiều là ảnh sáng', () {
      expect(wrIsDarkPeriod(WrDayPeriod.morning), isFalse);
      expect(wrIsDarkPeriod(WrDayPeriod.afternoon), isFalse);
      expect(wrIsDarkPeriod(WrDayPeriod.evening), isTrue);
      expect(wrIsDarkPeriod(WrDayPeriod.latenight), isTrue);
    });
  });

  group('WrMoodPalette', () {
    test('sáu mã khớp lưới check-in, mã lạ rơi về happy', () {
      expect(WrMoodPalette.moods.toSet(), {
        'stress',
        'tired',
        'foggy',
        'outofsync',
        'ok',
        'happy',
      });
      expect(WrMoodPalette.normalize(null), 'happy');
      expect(WrMoodPalette.normalize('khong-co'), 'happy');
      expect(WrMoodPalette.dot('ok'), const Color(0xFF4FB59B));
    });
  });

  group('WrHeroHeader', () {
    testWidgets('cao 250 cộng thanh trạng thái, chữ bắt đầu ngay dưới', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          WrHeroHeader.inner(
            key: const Key('hero'),
            art: WrHeroArt.understand,
            eyebrow: 'Hiểu mình',
            title: 'Những điều đang lặp lại',
            subtitle: 'Sau một thời gian nhìn lại, có vài chuyện cứ quay về.',
          ),
          top: 24,
        ),
      );
      expect(tester.getSize(find.byKey(const Key('hero'))).height, 274);
      expect(find.text('HIỂU MÌNH'), findsOneWidget);
      expect(find.text('Những điều đang lặp lại'), findsOneWidget);
      // Tiêu đề nằm sát mép trên: 24 thanh trạng thái + 8 lề + eyebrow.
      expect(tester.getTopLeft(find.text('HIỂU MÌNH')).dy, 32);
    });

    testWidgets('ảnh tối thì tiêu đề màu kem', (tester) async {
      await tester.pumpWidget(
        _host(
          WrHeroHeader.city(
            period: WrDayPeriod.evening,
            title: 'Chào Yumi',
            overline: 'Thứ Ba, 24 tháng 6',
          ),
        ),
      );
      final title = tester.widget<Text>(find.text('Chào Yumi'));
      expect(title.style!.color, WrColors.cream);
    });

    testWidgets('ảnh sáng thì tiêu đề màu navy', (tester) async {
      await tester.pumpWidget(
        _host(
          WrHeroHeader.city(period: WrDayPeriod.morning, title: 'Chào Yumi'),
        ),
      );
      final title = tester.widget<Text>(find.text('Chào Yumi'));
      expect(title.style!.color, WrColors.navy);
    });
  });

  testWidgets('WrReflectBand mang mã cảm xúc đã chuẩn hoá', (tester) async {
    await tester.pumpWidget(_host(const WrReflectBand(mood: 'la')));
    expect(find.byKey(const Key('wr_reflect_band_happy')), findsOneWidget);
  });

  group('WrCard', () {
    testWidgets('thẻ thường bo 18, viền line', (tester) async {
      await tester.pumpWidget(_host(const WrCard(child: Text('a'))));
      final box = tester.widget<Container>(
        find.ancestor(of: find.text('a'), matching: find.byType(Container)),
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.borderRadius, BorderRadius.circular(18));
      expect((deco.border! as Border).top.color, WrColors.line);
    });

    testWidgets('thẻ nét đứt vẫn bấm được', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          WrCard(dashed: true, onTap: () => taps++, child: const Text('b')),
        ),
      );
      await tester.tap(find.text('b'));
      expect(taps, 1);
    });

    testWidgets('WrMentorCard: chọn thì viền coral', (tester) async {
      await tester.pumpWidget(
        _host(const WrMentorCard(selected: true, child: Text('c'))),
      );
      final box = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final deco = box.decoration! as BoxDecoration;
      expect((deco.border! as Border).top.color, WrColors.coral);
    });
  });

  test('giọng AI mặc định tắt (khách 06/10)', () {
    expect(kAiVoiceEnabled, isFalse);
  });
}
