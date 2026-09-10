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
// hỏng, chỉ là không có gì ra lệnh dựng lại. Màn nào tình cờ phải dựng lại vì
// một lý do khác thì đổi chữ, màn còn lại giữ nguyên tiếng cũ.
//
// Bài dưới dựng đúng cái bẫy đó — một widget `const` nằm dưới một cha có dựng
// lại — rồi chứng minh hai chiều:
//   • chỉ đổi `wrEnglish` thôi thì chữ KHÔNG đổi (bẫy còn nguyên);
//   • xoá provider mà widget đang nghe thì chữ đổi (cách chữa đang dùng).
//
// Run: flutter test test/core/l10n/wr_locale_rebuild_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';

/// Đứng thay cho một repository trong `userDataProviders`.
///
/// Trả về một THỰC THỂ MỚI mỗi lần dựng, đúng như `wrRepositoryProvider` và
/// `wrContentRepositoryProvider` (`return SupabaseWrRepository(...)`). Chi tiết
/// này quyết định cả cơ chế: Riverpod chỉ báo cho bên phụ thuộc khi giá trị mới
/// KHÁC giá trị cũ. Repository nào trả về một hằng — hoặc có `operator ==` coi
/// hai thực thể là một — thì xoá nó xong sẽ không ai được báo, và cách chữa này
/// im lặng ngừng hoạt động.
class _Repo {}

final _repoProvider = Provider<_Repo>((ref) => _Repo());

/// Đứng thay cho một `FutureProvider` dữ liệu: nó `watch` repository, nên xoá
/// repository là nó dựng lại theo — đúng cơ chế app dùng.
final _dataProvider = Provider<String>((ref) {
  ref.watch(_repoProvider);
  return tr('dữ liệu', 'data');
});

/// Cha có dựng lại mỗi lần đổi ngôn ngữ, giống `MaterialApp` nhận `locale` mới.
final _localeProvider = StateProvider<String>((ref) => 'vi');

/// Bản CŨ: chỉ ghi `wrEnglish` trong `build`, không báo cho ai.
class _Shell extends ConsumerWidget {
  const _Shell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    wrSetLocale(ref.watch(_localeProvider));
    // `const` — đây chính là hình dạng của bảng route.
    return const _Screen();
  }
}

/// Bản ĐANG DÙNG: đúng hình dạng của `WrApp.build` trong `lib/app.dart`.
class _FixedShell extends ConsumerWidget {
  const _FixedShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    wrSetLocale(ref.watch(_localeProvider));

    ref.listen<String>(_localeProvider, (previous, next) {
      if (previous == next) return;
      // THỨ TỰ Ở ĐÂY LÀ CẢ CƠ CHẾ, đừng đảo.
      //
      // Xoá provider trước rồi mới ghi `wrEnglish` thì provider tính lại NGAY
      // lúc bị xoá, lúc đó biến vẫn còn giá trị cũ, nên nó ra đúng giá trị cũ.
      // Riverpod thấy giá trị không đổi thì không báo cho ai — và cả cách chữa
      // này im lặng không làm gì cả, y như chưa từng có nó.
      wrSetLocale(next);
      ref.invalidate(_repoProvider);
    });

    return const _Screen();
  }
}

class _Screen extends ConsumerWidget {
  const _Screen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text('${tr('Xin chào', 'Hello')} · ${ref.watch(_dataProvider)}'),
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
    expect(find.text('Xin chào · dữ liệu'), findsOneWidget);

    // Đổi ngôn ngữ. `_Shell` dựng lại và `wrEnglish` đã là true…
    container.read(_localeProvider.notifier).state = 'en';
    await tester.pump();

    // …nhưng `_Screen` là `const`, Flutter thấy widget không đổi nên không gọi
    // `build`. Chữ đứng yên. Khách nhìn thấy đúng cảnh này.
    expect(wrEnglish, isTrue);
    expect(find.text('Xin chào · dữ liệu'), findsOneWidget);
    expect(find.text('Hello · data'), findsNothing);
  });

  testWidgets('xoá provider mà màn đang nghe thì nó dựng lại, kể cả `const`',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _FixedShell(),
      ),
    );
    expect(find.text('Xin chào · dữ liệu'), findsOneWidget);

    // Chỉ đổi ngôn ngữ, không gọi tay gì thêm — phần còn lại là việc của
    // listener trong shell, đúng như người dùng bấm trong màn Tài khoản.
    container.read(_localeProvider.notifier).state = 'en';
    await tester.pump();

    // Cả chữ giao diện (`tr`) lẫn chữ đi qua provider dữ liệu đều đổi, trong
    // CÙNG một khung hình. Không còn cảnh nửa màn tiếng Anh nửa màn tiếng Việt.
    expect(find.text('Hello · data'), findsOneWidget);
    expect(find.text('Xin chào · dữ liệu'), findsNothing);
  });

  testWidgets('provider dữ liệu tính lại SAU khi `wrEnglish` đã đổi',
      (tester) async {
    // Provider dữ liệu chở chữ đã dịch sẵn, nên thời điểm nó tính lại quyết
    // định nó chở tiếng gì. Tính lại lúc `wrEnglish` còn là false thì nó ra
    // đúng giá trị cũ, Riverpod thấy "không có gì đổi" và không báo cho ai —
    // hỏng mà không có lỗi nào, không có bài nào đỏ.
    //
    // Cái giữ cho điều đó không xảy ra là listener ghi `wrEnglish` NGAY khi
    // ngôn ngữ đổi, còn provider thì tính lại muộn hơn, lúc màn hình dựng.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _FixedShell(),
      ),
    );

    container.read(_localeProvider.notifier).state = 'en';
    // Chưa dựng khung hình nào, nhưng biến ngôn ngữ đã đúng rồi.
    expect(wrEnglish, isTrue);
    // Nên bất cứ lúc nào provider tính lại, nó cũng đọc được giá trị mới.
    expect(container.read(_dataProvider), 'data');
  });
}
