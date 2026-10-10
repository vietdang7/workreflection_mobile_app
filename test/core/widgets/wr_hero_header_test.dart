// Nền dùng chung của mockup v47 (M0): hero, dải cảm xúc, thẻ chuẩn. Ảnh hero
// và dải theo mockup v55 Watercolor (09/10).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_ai_voice.dart';
import 'package:workreflection_mobile/core/theme/wr_colors.dart';
import 'package:workreflection_mobile/core/widgets/wr_card.dart';
import 'package:workreflection_mobile/core/widgets/wr_detail_scaffold.dart';
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
    test('đủ 6 ảnh v55 trên đĩa và pubspec khai báo thư mục', () {
      final paths = <String>{
        for (final a in WrHeroArt.values) a.asset,
        for (final m in WrMoodPalette.moods) WrReflectBand.assetFor(m),
      };
      expect(paths, hasLength(6));
      for (final p in paths) {
        expect(File(p).existsSync(), isTrue, reason: p);
      }
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/images/hero/'),
      );
    });

    test('bốn tab bốn ảnh riêng', () {
      expect(WrHeroArt.home.asset, 'assets/images/hero/hero_homnay.webp');
      expect(WrHeroArt.understand.asset, 'assets/images/hero/hero_hieu.webp');
      expect(WrHeroArt.act.asset, 'assets/images/hero/hero_phat.webp');
      expect(WrHeroArt.grow.asset, 'assets/images/hero/hero_hanh.webp');
    });

    test('dải màn con: căng thẳng / mơ hồ / khá ổn dùng band_a', () {
      for (final m in ['stress', 'foggy', 'ok']) {
        expect(WrReflectBand.assetFor(m), endsWith('band_a.webp'), reason: m);
      }
      for (final m in ['tired', 'outofsync', 'happy', null]) {
        expect(WrReflectBand.assetFor(m), endsWith('band_b.webp'), reason: m);
      }
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

    testWidgets('Home: chữ navy, mô tả đậm .94, không quầng màu', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          WrHeroHeader.home(
            title: 'Chào Yumi',
            overline: 'Thứ Ba, 24 tháng 6',
            subtitle: 'Dừng lại một chút.',
          ),
        ),
      );
      final title = tester.widget<Text>(find.text('Chào Yumi'));
      expect(title.style!.color, WrColors.navy);
      final copy = tester.widget<Text>(find.text('Dừng lại một chút.'));
      expect(copy.style!.color, const Color(0xF02C335D));
      final backdrop = tester.widget<WrHeroBackdrop>(
        find.byType(WrHeroBackdrop),
      );
      expect(backdrop.asset, WrHeroArt.home.asset);
      expect(backdrop.landscapeTint, isFalse);
    });

    testWidgets('eyebrow trên hero dùng màu .74', (tester) async {
      await tester.pumpWidget(
        _host(
          WrHeroHeader.inner(
            art: WrHeroArt.act,
            eyebrow: 'Phát triển',
            title: 'Thực hành',
          ),
        ),
      );
      final eyebrow = tester.widget<Text>(find.text('PHÁT TRIỂN'));
      expect(eyebrow.style!.color, WrColors.eyebrow);
    });
  });

  testWidgets('WrReflectBand mang mã cảm xúc đã chuẩn hoá', (tester) async {
    await tester.pumpWidget(_host(const WrReflectBand(mood: 'la')));
    expect(find.byKey(const Key('wr_reflect_band_happy')), findsOneWidget);
  });

  group('dải màn con theo tab (decorateInner, v55)', () {
    test('ảnh bg_* có trên đĩa, màu theo INNER_PAL', () {
      for (final a in WrHeroArt.values) {
        expect(File(a.bgAsset).existsSync(), isTrue, reason: a.bgAsset);
      }
      expect(WrHeroArt.understand.bandMood, 'tired');
      expect(WrHeroArt.act.bandMood, 'ok');
      expect(WrHeroArt.grow.bandMood, 'happy');
    });

    testWidgets('WrReflectBand.tab dùng ảnh bg của tab', (tester) async {
      await tester.pumpWidget(_host(WrReflectBand.tab(WrHeroArt.grow)));
      expect(find.byKey(const Key('wr_reflect_band_tab_grow')), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect((img.image as AssetImage).assetName, WrHeroArt.grow.bgAsset);
    });

    testWidgets('WrDetailScaffold có art thì có dải, không thì nền trơn', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WrDetailScaffold(
            eyebrow: 'E',
            title: 'T',
            art: WrHeroArt.grow,
            children: const [],
          ),
        ),
      );
      expect(find.byKey(const Key('wr_reflect_band_tab_grow')), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.transparent,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: WrDetailScaffold(eyebrow: 'E', title: 'T', children: []),
        ),
      );
      expect(find.byType(WrReflectBand), findsNothing);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        WrColors.pageBg,
      );
    });
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
