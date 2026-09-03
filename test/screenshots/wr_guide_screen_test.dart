// Chụp màn "Hướng dẫn sử dụng" (Hồ sơ) để duyệt giao diện.
//
//   WR_SCREENSHOTS=1 flutter test test/screenshots/wr_guide_screen_test.dart --update-goldens
//
// Ảnh ra `screenshots/`. Cùng quy ước với các bộ chụp khác: mặc định BỎ QUA,
// vì so golden phụ thuộc font và engine render nên để chạy thường sẽ đỏ trên
// máy khác mà không nói lên điều gì về sản phẩm.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/logic/wr_user_guide.dart';
import 'package:workreflection_mobile/core/theme/wr_text.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/profile/presentation/guide_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final loader = FontLoader(family)
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }

  await load('NotoSans', 'assets/fonts/NotoSans-Regular.ttf');
  await load('NotoSans', 'assets/fonts/NotoSans-Bold.ttf');
  await load(WrText.serifFamily, 'assets/fonts/Lora-Italic.ttf');

  for (final candidate in _materialIconCandidates()) {
    if (File(candidate).existsSync()) {
      await load('MaterialIcons', candidate);
      break;
    }
  }
}

List<String> _materialIconCandidates() {
  const relative =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      Platform.environment['FLUTTER_ROOT']!,
    '${Platform.environment['HOME']}/snap/flutter/common/flutter',
    '${Platform.environment['HOME']}/flutter',
    '/opt/flutter',
    '/usr/local/flutter',
  ];
  return [for (final r in roots) '$r/$relative'];
}

Widget _app() {
  final router = GoRouter(
    initialLocation: '/profile/guide',
    routes: [
      GoRoute(
        path: '/profile/guide',
        builder: (_, __) => const GuideScreen(),
      ),
      GoRoute(
        path: '/wr/ask',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'NotoSans', useMaterial3: true),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
    ),
  );
}

Future<void> _shoot(
  WidgetTester tester,
  String name, {
  Size size = const Size(390, 844), // iPhone 14
  List<String> open = const [],
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  for (final id in open) {
    final row = find.byKey(Key('guide_section_$id'));
    await tester.scrollUntilVisible(row, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
  }

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../screenshots/$name.png'),
  );
}

final bool _enabled = Platform.environment['WR_SCREENSHOTS'] == '1';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  group('Hướng dẫn sử dụng', skip: !_enabled, () {
    testWidgets('đầu màn — thẻ Chatbot và danh sách mục', (tester) async {
      await _shoot(tester, '40_huong_dan_dau_man');
    });

    // Một mục đã mở, để duyệt cả kiểu chữ bên trong chứ không chỉ danh sách
    // tiêu đề. Chọn "Nhìn lại mỗi ngày" vì nó có đủ bước đánh số, nhãn "bỏ qua
    // được" và khối lưu ý.
    testWidgets('một mục đã mở', (tester) async {
      await _shoot(tester, '41_huong_dan_muc_mo', open: const ['daily']);
    });

    // Bảng "bốn tab" — khối hai cột duy nhất của bộ chữ, và là chỗ icon mục
    // trùng icon thanh tab thật.
    testWidgets('bảng bốn tab', (tester) async {
      await _shoot(tester, '42_huong_dan_bang_tab', open: const ['tabs']);
    });

    // Cuối màn: nhóm thứ ba và dòng chốt — hai thứ các ảnh trên không chạm tới.
    testWidgets('cuối màn — nhóm cuối và dòng chốt', (tester) async {
      await _shoot(tester, '43_huong_dan_cuoi_man', open: const ['faq']);
    });
  });

  test('bộ chữ có đủ mục để chụp', () {
    expect(wrGuideSections().map((s) => s.id), contains('daily'));
  });
}
