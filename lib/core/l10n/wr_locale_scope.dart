// Thứ ra lệnh cho màn hình dựng lại khi người dùng đổi ngôn ngữ.
//
// ---------------------------------------------------------------------------
// VÌ SAO CẦN CẢ MỘT FILE CHO VIỆC NÀY
//
// `tr()` đọc một biến toàn cục (`wrEnglish`). Đổi biến toàn cục KHÔNG báo cho
// Flutter, nên một màn chỉ đổi chữ vào lần nó tình cờ phải dựng lại. Cách hiển
// nhiên — dựng lại `MaterialApp` với `locale` mới — KHÔNG tới được màn hình, và
// lý do nằm sâu trong go_router:
//
//   `_CustomNavigatorState` (go_router 14.8.1, `src/builder.dart`) giữ danh
//   sách `Page` đã dựng trong `_pages`, và chỉ vứt đi khi `matchList` đổi hoặc
//   `didChangeDependencies` chạy. Cha dựng lại bao nhiêu lần cũng vậy: cùng
//   `matchList` thì cùng `_pages`, cùng `Page`, cùng widget màn hình — và
//   `Element.updateChild` thấy widget mới bằng widget cũ nên trả về ngay.
//
//   Navigator đó còn mang `GlobalObjectKey`, nên kể cả tháo cả cây phía trên và
//   dựng lại (đổi `Key` ở `MaterialApp.builder`) thì element của nó vẫn được
//   nhấc nguyên sang cây mới, mang theo `_pages` cũ. Đã thử — không ăn thua.
//
// Với `StatefulShellRoute.indexedStack` còn một tầng nữa: nhánh tab KHÔNG hoạt
// động được giữ nguyên widget đã dựng lần trước. Đó chính là ảnh khách chụp
// 10/09 — đổi ngôn ngữ trong màn Tài khoản, quay ra tab Hôm nay thì dòng ngày
// vẫn "Thứ Năm, 10 tháng 9" giữa một màn đã sang tiếng Anh, vì tab đó nằm im
// trong `IndexedStack` từ trước lúc đổi.
//
// ---------------------------------------------------------------------------
// CÁCH CHỮA
//
// go_router gói mỗi `builder` của route trong một `Builder`, và `Builder` thì
// dựng lại khi một `InheritedWidget` mà nó PHỤ THUỘC đổi giá trị — kể cả khi
// `Page` bọc ngoài vẫn là `Page` cũ, kể cả khi nhánh tab đang nằm ngoài màn
// hình. Đó là đường duy nhất đi xuyên qua cache của go_router.
//
// Nên: [WrLocaleScope] đặt trên `Router` (ở `MaterialApp.builder`), còn mỗi
// route gọi [wrLocaleAware] để ĐĂNG KÝ phụ thuộc vào nó. Đổi ngôn ngữ là mọi
// route đang sống — tab đang xem lẫn ba tab đang nằm im — dựng lại trong cùng
// một khung hình. Không xoá cache dữ liệu, không một lượt mạng nào.
//
// ⚠ Thêm route mới thì dùng `wrRoute(...)` trong `app_router.dart`, đừng dùng
//   thẳng `GoRoute(...)`. Một route đứng ngoài sẽ đứng yên ở ngôn ngữ của lần
//   dựng đầu tiên, và đó là loại lỗi chỉ lộ ra khi có người thật đổi ngôn ngữ
//   rồi đi qua đúng màn đó.

import 'package:flutter/widgets.dart';

import 'wr_tr.dart';

/// Mã ngôn ngữ đang bật, phát xuống cả cây widget.
///
/// Giá trị chỉ để so sánh — chữ vẫn lấy qua `tr()`. Cái quan trọng ở đây là
/// việc ĐĂNG KÝ phụ thuộc, không phải giá trị.
class WrLocaleScope extends InheritedWidget {
  const WrLocaleScope({
    super.key,
    required this.localeCode,
    required super.child,
  });

  final String localeCode;

  /// Đăng ký [context] làm bên phụ thuộc và trả về mã ngôn ngữ hiện tại.
  ///
  /// Không tìm thấy scope thì rơi về [wrLocaleCode]: test dựng một màn lẻ không
  /// có `MaterialApp` của app vẫn phải chạy được, và ở đó không có gì đổi ngôn
  /// ngữ giữa chừng nên không cần đăng ký.
  static String of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WrLocaleScope>();
    return scope?.localeCode ?? wrLocaleCode;
  }

  @override
  bool updateShouldNotify(WrLocaleScope oldWidget) =>
      oldWidget.localeCode != localeCode;
}

/// Bọc [child] của một route sao cho nó dựng lại khi đổi ngôn ngữ.
///
/// Hai việc, cả hai đều cần:
///   • `WrLocaleScope.of(context)` đăng ký `Builder` của go_router làm bên phụ
///     thuộc — đây là thứ khiến nó được gọi lại;
///   • `KeyedSubtree` với key theo ngôn ngữ vứt hẳn nhánh cũ đi. Không có nó,
///     màn hình `const` sẽ là cùng một thực thể ở cả hai lần dựng và Flutter bỏ
///     qua cả nhánh — đúng cái bẫy đang tránh.
Widget wrLocaleAware(BuildContext context, Widget child) {
  return KeyedSubtree(
    key: ValueKey<String>('wr-locale-${WrLocaleScope.of(context)}'),
    child: child,
  );
}
