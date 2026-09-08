// Danh mục gói Premium bán bằng In-App Purchase của kho ứng dụng.
//
// Vì sao có file này: App Store từ chối bản 1.0 (6) ngày 06/09/2026 theo
// Guideline 3.1.1. Nguyên văn phần cốt lõi — "The app accesses digital content
// purchased outside the app, but that content isn't available to purchase using
// In-App Purchase". Tức là app cho người mua-trên-web dùng Premium, mà chính
// gói đó lại không mua được trong app. Guideline 3.1.3(b) cho phép dùng chéo
// nền tảng, nhưng kèm đúng điều kiện đó.
//
// ⚠️ HAI HỆ GÓI, ĐỪNG TRỘN:
//
//   `cc_products`                    ← trang quản trị của web ghi, giá VND
//     product_type = 'premium'          gói web, 249.000đ
//     product_type = 'premium_mobile'   gói app bán qua VietQR, 499.000đ / 70.000đ
//
//   App Store Connect                ← khai bên Apple, giá theo bậc của Apple
//     [kIapYearlyProductId]             gói năm
//     [kIapMonthlyProductId]            gói tháng
//
// Hai hệ này KHÔNG có chung id, không chung giá, và không được suy ra nhau. Lý
// do không phải kỹ thuật mà là luật: Apple bắt hiển thị đúng giá StoreKit trả
// về cho kho của người dùng — cùng một gói, người ở Mỹ thấy USD, người ở Việt
// Nam thấy VND, và con số VND đó cũng không nhất thiết bằng 499.000đ vì Apple
// chỉ có các bậc giá định sẵn. Lấy giá từ `cc_products` mà dán lên nút IAP là
// nói dối người mua, và là một cách khác để bị từ chối.
//
// Nên phân vai rành mạch:
//   • Giá, nhãn tiền tệ, chu kỳ  → StoreKit (`ProductDetails`).
//   • Thời hạn quy ra ngày       → bảng dưới đây, vì backend cần con số này để
//                                  ghi `wr_entitlements.valid_until`.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

/// Bundle id của bản iOS. Phải khớp `PRODUCT_BUNDLE_IDENTIFIER` trong
/// `ios/Runner.xcodeproj/project.pbxproj`.
///
/// Backend đối chiếu trường `bundleId` trong biên lai đã ký với hằng này —
/// biên lai của một app khác ký đúng chuẩn Apple vẫn là biên lai thật, nên nếu
/// không so bundle id thì ai cũng có thể lấy biên lai mua app khác đổi lấy
/// Premium ở đây.
const String kIosBundleId = 'app.workreflection.mobile';

/// Gói năm, khai bên App Store Connect.
const String kIapYearlyProductId = 'app.workreflection.mobile.premium.yearly';

/// Gói tháng, khai bên App Store Connect.
const String kIapMonthlyProductId = 'app.workreflection.mobile.premium.monthly';

/// Một gói Premium bán qua kho ứng dụng.
class WrIapProduct {
  const WrIapProduct({
    required this.id,
    required this.durationDays,
    required this.title,
    required this.blurb,
  });

  /// Product ID khai bên App Store Connect.
  final String id;

  /// Thời hạn quy ra ngày, để backend tính `valid_until`.
  ///
  /// Đây là con số DỰ PHÒNG. Với gói tự động gia hạn, Apple trả thẳng
  /// `expiresDate` trong biên lai đã ký và backend phải ưu tiên con số đó —
  /// người dùng có thể được Apple tặng thêm ngày (đền bù sự cố, gia hạn khuyến
  /// mãi) mà app không hề biết. Chỉ khi biên lai không có `expiresDate` thì mới
  /// cộng từng này ngày kể từ ngày mua.
  final int durationDays;

  /// Tên gói hiển thị khi StoreKit chưa tải kịp.
  ///
  /// Tải xong thì dùng `ProductDetails.title` của Apple, vì tên bên đó mới là
  /// tên đã được duyệt và đã dịch theo kho.
  final String title;

  /// Một câu mô tả ngắn của riêng app, đặt dưới tên gói.
  final String blurb;
}

/// Các gói bán trong app, xếp theo thứ tự hiện trên Paywall.
///
/// Gói năm đứng trước và là gói chọn sẵn — giống thứ tự `display_order` của
/// `cc_products` (90 trước 91).
const List<WrIapProduct> kWrIapProducts = [
  WrIapProduct(
    id: kIapYearlyProductId,
    durationDays: 365,
    title: 'Premium 1 năm',
    blurb: 'Mở toàn bộ phần trả phí trong một năm.',
  ),
  WrIapProduct(
    id: kIapMonthlyProductId,
    durationDays: 30,
    title: 'Premium 1 tháng',
    blurb: 'Dùng thử một tháng trước khi quyết định.',
  ),
];

/// Tập id để truyền vào `queryProductDetails`.
final Set<String> kWrIapProductIds =
    kWrIapProducts.map((p) => p.id).toSet();

/// Tra gói theo product id. null khi id không phải của app này.
///
/// Trả null chứ không ném: `purchaseStream` của StoreKit trả về MỌI giao dịch
/// còn treo của tài khoản Apple đó, kể cả giao dịch của bản build cũ với id đã
/// bỏ. Ném ở đây là chết app ngay lúc mở, vì luồng đó chạy tự động.
WrIapProduct? wrIapProductById(String? id) {
  if (id == null) return null;
  for (final p in kWrIapProducts) {
    if (p.id == id) return p;
  }
  return null;
}

/// True khi [id] là một gói Premium của app này.
bool isWrIapProductId(String? id) => wrIapProductById(id) != null;
