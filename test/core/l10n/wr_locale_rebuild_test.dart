// Đổi ngôn ngữ có thật sự làm màn hình dựng lại không.
//
// ---------------------------------------------------------------------------
// BÀI NÀY KHOÁ ĐIỀU GÌ
//
// `tr()` đọc một biến toàn cục. Đổi biến toàn cục KHÔNG báo cho Flutter, nên
// một màn hình chỉ đổi chữ khi có ai đó bảo nó dựng lại. Trong app thật, "ai đó"
// từng không tồn tại: mọi màn WorkReflection nằm trong bảng route dưới dạng
// `const WrHomeScreen()`, và Flutter bỏ qua cả nhánh khi widget cũ với widget
// mới là cùng một thực thể `const`.
//
// Đó là toàn bộ nguyên nhân của "đổi ngôn ngữ rất chậm, cứ xen kẽ": không có gì
// hỏng, chỉ là không có gì ra lệnh dựng lại.
//
// ---------------------------------------------------------------------------
// VÌ SAO CÁCH CHỮA CŨ (XOÁ PROVIDER) KHÔNG ĐỦ
//
// Bản trước xoá toàn bộ repository mỗi lần đổi ngôn ngữ, để widget nào đang
// nghe một provider dữ liệu thì dựng lại theo. Nó chữa được phần lớn màn, nhưng
// bỏ sót đúng những widget KHÔNG nghe provider nào — và trả giá bằng hàng chục
// lượt gọi server, mỗi lượt về một lúc, thay chữ một mảng màn hình.
//
// Ảnh khách chụp 10/09 là bằng chứng của cả hai vế: cả màn Hôm nay đã sang
// tiếng Anh, riêng dòng ngày "Thứ Năm, 10 tháng 9" ở đầu màn còn tiếng Việt.
// Dòng đó đọc `greetingNameProvider` — không nằm trong danh sách bị xoá.
//
// Cách chữa hiện tại (`_localeAwareBuilder` trong `lib/app.dart`) đổi `Key` của
// cả cây theo ngôn ngữ: key mới thì Flutter tháo nhánh cũ và dựng lại từ đầu,
// nên MỌI widget chạy `build` trong cùng một khung hình — `const` hay không,
// nghe provider hay không.
//
// Run: flutter test test/core/l10n/wr_locale_rebuild_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/app.dart';
import 'package:workreflection_mobile/core/l10n/wr_locale_scope.dart';
import 'package:workreflection_mobile/core/router/app_router.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';

final _localeProvider = StateProvider<String>((ref) => 'vi');

/// Màn hình thuần `tr()`, KHÔNG nghe provider nào.
///
/// Đây là dòng ngày ở đầu màn Hôm nay, thu nhỏ lại. Cách chữa bằng xoá provider
/// không bao giờ với tới được widget hình dạng này.
class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(tr('Thứ Năm, 10 tháng 9', 'Thursday, September 10')),
    );
  }
}

/// Bản CŨ: chỉ ghi `wrEnglish` trong `build`, rồi trả về widget `const`.
class _Shell extends ConsumerWidget {
  const _Shell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    wrSetLocale(ref.watch(_localeProvider));
    // `const` — đây chính là hình dạng của bảng route.
    return const _Screen();
  }
}

/// Bản ĐANG DÙNG: đúng hình dạng của `WrApp.build` + `_localeAwareBuilder`.
class _KeyedShell extends ConsumerWidget {
  const _KeyedShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(_localeProvider);
    // Ghi biến TRƯỚC khi dựng cây, để mọi `tr()` trong khung hình này đọc cùng
    // một ngôn ngữ.
    wrSetLocale(locale);

    return KeyedSubtree(
      key: ValueKey<String>('wr-locale-$locale'),
      child: const _Screen(),
    );
  }
}

void main() {
  tearDown(() => wrEnglish = false);

  testWidgets('cha dựng lại nhưng con `const` thì KHÔNG — đây là cái bẫy',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _Shell(),
      ),
    );
    expect(find.text('Thứ Năm, 10 tháng 9'), findsOneWidget);

    // Đổi ngôn ngữ. `_Shell` dựng lại và `wrEnglish` đã là true…
    container.read(_localeProvider.notifier).state = 'en';
    await tester.pump();

    // …nhưng `_Screen` là `const`, Flutter thấy widget không đổi nên không gọi
    // `build`. Chữ đứng yên. Khách nhìn thấy đúng cảnh này.
    expect(wrEnglish, isTrue);
    expect(find.text('Thứ Năm, 10 tháng 9'), findsOneWidget);
    expect(find.text('Thursday, September 10'), findsNothing);
  });

  testWidgets('đổi Key theo ngôn ngữ thì con `const` cũng dựng lại',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _KeyedShell(),
      ),
    );
    expect(find.text('Thứ Năm, 10 tháng 9'), findsOneWidget);

    // Chỉ đổi ngôn ngữ, không xoá provider nào, không gọi server lần nào —
    // đúng như người dùng bấm trong màn Tài khoản.
    container.read(_localeProvider.notifier).state = 'en';
    await tester.pump();

    // Một khung hình duy nhất, đổi hết. Không còn cảnh nửa màn tiếng Anh nửa
    // màn tiếng Việt.
    expect(find.text('Thursday, September 10'), findsOneWidget);
    expect(find.text('Thứ Năm, 10 tháng 9'), findsNothing);
  });

  testWidgets('đổi đi rồi đổi lại vẫn đúng, không kẹt ở tiếng thứ hai',
      (tester) async {
    // Khách báo cả hai chiều đều chậm. Chiều về là chỗ dễ sót: nếu key được
    // dựng từ thứ gì đó chỉ tăng (số lần đổi chẳng hạn) thì chiều nào cũng chạy
    // — nhưng nếu ai đó "tối ưu" nó thành một cờ bật/tắt một chiều thì chiều về
    // hỏng, và bài này đỏ.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _KeyedShell(),
      ),
    );

    container.read(_localeProvider.notifier).state = 'en';
    await tester.pump();
    expect(find.text('Thursday, September 10'), findsOneWidget);

    container.read(_localeProvider.notifier).state = 'vi';
    await tester.pump();
    expect(find.text('Thứ Năm, 10 tháng 9'), findsOneWidget);
    expect(find.text('Thursday, September 10'), findsNothing);
  });

  testWidgets('màn đang mở đổi tiếng ngay, và không bị đá về màn đầu',
      (tester) async {
    // Dùng THẲNG `wrRoute` và `wrLocaleAwareBuilder` của app, không chép lại:
    // chép lại thì bài này khoá bản sao chứ không khoá thứ đang chạy thật.
    //
    // Bài này từng ĐỎ với mọi cách chữa "hiển nhiên" — đổi `locale` của
    // `MaterialApp`, đổi `Key` ở `builder`, đổi `Key` của cả `MaterialApp`.
    // go_router giữ `Page` đã dựng nên không cách nào trong số đó tới được màn
    // hình. Lý do đầy đủ ở `core/l10n/wr_locale_scope.dart`.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        wrRoute(path: '/', builder: (_, __) => _Screen()),
        wrRoute(path: '/sau', builder: (_, __) => _DeepScreen()),
      ],
    );
    addTearDown(router.dispose);

    Widget app() => MaterialApp.router(
          routerConfig: router,
          builder: wrLocaleAwareBuilder,
        );

    await tester.pumpWidget(app());
    router.go('/sau');
    await tester.pumpAndSettle();
    expect(find.text('Màn trong'), findsOneWidget);

    // Đổi ngôn ngữ trong lúc đang đọc dở một màn.
    wrSetLocale('en');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Inner screen'), findsOneWidget);
    expect(find.text('Màn trong'), findsNothing);
    // …và vẫn ở nguyên màn đó. Đổi ngôn ngữ mà bị ném về Home thì là đổi một
    // phiền toái lấy một phiền toái lớn hơn.
    expect(router.state.uri.path, '/sau');
  });

  testWidgets('TAB ĐANG NẰM IM cũng đổi tiếng — đúng ảnh khách chụp 10/09',
      (tester) async {
    // Đây là lỗi trong ảnh: khách đổi sang tiếng Anh ở màn Tài khoản, quay ra
    // tab Hôm nay thì dòng ngày vẫn "Thứ Năm, 10 tháng 9" giữa một màn đã sang
    // tiếng Anh.
    //
    // `StatefulShellRoute.indexedStack` giữ nguyên widget đã dựng của nhánh
    // KHÔNG hoạt động. Tab Hôm nay được dựng từ trước lúc đổi ngôn ngữ và nằm
    // im trong `IndexedStack`, nên không có gì chạm tới nó — cho tới khi
    // `wrLocaleAware` đăng ký nó làm bên phụ thuộc của `WrLocaleScope`.
    final router = GoRouter(
      initialLocation: '/mot',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              wrLocaleAware(context, _TabShell(shell: shell)),
          branches: [
            StatefulShellBranch(routes: [
              wrRoute(path: '/mot', builder: (_, __) => _Screen()),
            ]),
            StatefulShellBranch(routes: [
              wrRoute(path: '/hai', builder: (_, __) => _DeepScreen()),
            ]),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    Widget app() => MaterialApp.router(
          routerConfig: router,
          builder: wrLocaleAwareBuilder,
        );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Thứ Năm, 10 tháng 9'), findsOneWidget);

    // Sang tab hai, rồi đổi ngôn ngữ khi đang đứng ở đó — tab một lúc này đã
    // được dựng xong và đang nằm im với chữ tiếng Việt.
    router.go('/hai');
    await tester.pumpAndSettle();
    wrSetLocale('en');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Quay lại tab một.
    router.go('/mot');
    await tester.pumpAndSettle();
    expect(find.text('Thursday, September 10'), findsOneWidget);
    expect(find.text('Thứ Năm, 10 tháng 9'), findsNothing);
  });
}

class _DeepScreen extends StatelessWidget {
  const _DeepScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text(tr('Màn trong', 'Inner screen'))),
      );
}

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(body: shell);
}
