import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/widgets/wr_status_bar_strip.dart';

// Script Sprint 2 `.statusbar`: giờ và pin nằm trên một dải nền cố định, nội
// dung cuộn lên thì trôi XUỐNG DƯỚI dải đó (máy thật 13/10: chữ lẫn vào giờ).

Widget _app({required double top, ValueNotifier<String>? path}) => MediaQuery(
  data: MediaQueryData(padding: EdgeInsets.only(top: top)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: WrStatusBarStrip(
      isPaper: false,
      routeChanges: path,
      currentPath: path == null ? null : () => path.value,
      child: const ColoredBox(color: Colors.red),
    ),
  ),
);

void main() {
  const strip = Key('wr_status_bar_strip');

  testWidgets('phủ đúng chiều cao thanh trạng thái, sát mép trên', (
    tester,
  ) async {
    await tester.pumpWidget(_app(top: 32));
    final rect = tester.getRect(find.byKey(strip));
    expect(rect.top, 0);
    expect(rect.height, 32);
    expect(
      rect.width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
  });

  testWidgets('máy không có thanh trạng thái thì không dựng dải', (
    tester,
  ) async {
    await tester.pumpWidget(_app(top: 0));
    expect(find.byKey(strip), findsNothing);
  });

  testWidgets('màn nền navy (splash, thiết lập nghề nghiệp) không có dải', (
    tester,
  ) async {
    final path = ValueNotifier('/splash');
    await tester.pumpWidget(_app(top: 32, path: path));
    expect(find.byKey(strip), findsNothing);

    path.value = '/wr/home';
    await tester.pump();
    expect(find.byKey(strip), findsOneWidget);

    path.value = '/wr/career-setup';
    await tester.pump();
    expect(find.byKey(strip), findsNothing);
  });

  testWidgets('không chặn chạm vào nội dung bên dưới', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 40)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: WrStatusBarStrip(
            isPaper: false,
            routeChanges: null,
            currentPath: null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(20, 10));
    expect(taps, 1);
  });
}
