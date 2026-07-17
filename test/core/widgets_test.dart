import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_colors.dart';
import 'package:workreflection_mobile/core/widgets/eyebrow.dart';
import 'package:workreflection_mobile/core/widgets/wr_card.dart';
import 'package:workreflection_mobile/core/widgets/progress_track.dart';
import 'package:workreflection_mobile/core/widgets/pill_button.dart';
import 'package:workreflection_mobile/core/widgets/action_link.dart';
import 'package:workreflection_mobile/core/widgets/section_divider.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('WrEyebrow', () {
    testWidgets('renders uppercase text', (tester) async {
      await tester.pumpWidget(wrap(const WrEyebrow('hello world')));
      // Text should be uppercased
      expect(find.text('HELLO WORLD'), findsOneWidget);
    });

    testWidgets('uses muted color', (tester) async {
      await tester.pumpWidget(wrap(const WrEyebrow('test')));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.color, WrColors.muted);
    });
  });

  group('WrCardMinimal', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(wrap(
        const WrCardMinimal(child: Text('content')),
      ));
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('has cream background', (tester) async {
      await tester.pumpWidget(wrap(
        const WrCardMinimal(child: Text('x')),
      ));
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, WrColors.cream);
    });

    testWidgets('has radius 20', (tester) async {
      await tester.pumpWidget(wrap(
        const WrCardMinimal(child: Text('x')),
      ));
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(
        (decoration.borderRadius as BorderRadius).topLeft.x,
        20,
      );
    });
  });

  group('WrCardDark', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(wrap(
        const WrCardDark(child: Text('dark content')),
      ));
      expect(find.text('dark content'), findsOneWidget);
    });

    testWidgets('has navy background', (tester) async {
      await tester.pumpWidget(wrap(
        const WrCardDark(child: Text('x')),
      ));
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, WrColors.navy);
    });
  });

  group('WrProgressTrack', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(wrap(
        const WrProgressTrack(value: 0.5, color: WrColors.teal),
      ));
      expect(find.byType(WrProgressTrack), findsOneWidget);
    });

    testWidgets('clamps value between 0 and 1', (tester) async {
      await tester.pumpWidget(wrap(
        const WrProgressTrack(value: 1.5, color: WrColors.coral),
      ));
      expect(find.byType(WrProgressTrack), findsOneWidget);
    });
  });

  group('WrPillButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(wrap(
        WrPillButton(label: 'Press me', onPressed: () {}),
      ));
      expect(find.text('Press me'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(wrap(
        WrPillButton(label: 'Tap', onPressed: () => pressed = true),
      ));
      await tester.tap(find.byType(WrPillButton));
      expect(pressed, isTrue);
    });

    testWidgets('navy variant uses navy color by default', (tester) async {
      await tester.pumpWidget(wrap(
        WrPillButton(label: 'Navy', onPressed: () {}),
      ));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final style = btn.style!;
      final bg = style.backgroundColor?.resolve({});
      expect(bg, WrColors.navy);
    });

    testWidgets('coral variant uses coral color', (tester) async {
      await tester.pumpWidget(wrap(
        WrPillButton(
          label: 'Coral',
          onPressed: () {},
          variant: WrPillVariant.coral,
        ),
      ));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final style = btn.style!;
      final bg = style.backgroundColor?.resolve({});
      expect(bg, WrColors.coral);
    });
  });

  group('WrActionLink', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(wrap(
        WrActionLink(label: 'Learn more', onTap: () {}),
      ));
      expect(find.text('Learn more'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        WrActionLink(label: 'Go', onTap: () => tapped = true),
      ));
      await tester.tap(find.byType(WrActionLink));
      expect(tapped, isTrue);
    });
  });

  group('WrSectionDivider', () {
    testWidgets('renders a Divider', (tester) async {
      await tester.pumpWidget(wrap(const WrSectionDivider()));
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('divider height is 1', (tester) async {
      await tester.pumpWidget(wrap(const WrSectionDivider()));
      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.thickness, 1);
    });
  });
}
