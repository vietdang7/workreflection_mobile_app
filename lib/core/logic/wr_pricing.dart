// Giá gói Premium bán trong app.
//
// Khách chốt 2026-08-04: web và app bán HAI GÓI KHÁC NHAU, khác giá — web
// 249.000đ, app 499.000đ — nhưng thanh toán xong thì cả hai cùng cấp một
// `role = 'premium'`. Nên khác nhau đúng ở dòng sản phẩm và con số, không khác
// ở quyền.
//
// (Luật 2026-08-01 "giá app canh theo web" đã hết hiệu lực. Quyền Premium thì
// vẫn dùng chung như luật đó nói — xem `wrEntitlementProvider`.)
//
// Nguồn sự thật vẫn là bảng `cc_products` mà trang quản trị Gói dịch vụ của web
// ghi vào, chỉ khác dòng:
//
//   product_type = 'premium'         → gói web, 249.000đ
//   product_type = 'premium_mobile'  → gói app, 499.000đ   ← app đọc dòng này
//
// Tách bằng `product_type` vì bảng không có cột nào chỉ nền tảng, mà web tra
// giá cũng bằng đúng cột đó (`useProductPrice(productType)` — repo web
// `src/hooks/useProductPrice.ts`). Sửa giá app ở trang quản trị là app đổi
// theo, không phải build lại.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

/// `cc_products.product_type` của gói app.
///
/// KHÔNG phải `cc_orders.product_type` — đơn hàng vẫn ghi
/// [kPremiumOrderProductType] (`premium_survey`), vì RPC `complete_payment`
/// chỉ cấp role premium khi chuỗi đó kết thúc bằng `_survey`.
const String kPremiumMobileProductType = 'premium_mobile';

/// Giá đã rơi về mặc định nếu `cc_products` không có dòng
/// [kPremiumMobileProductType] nào đang bật.
///
/// 499.000đ — đúng giá gói app, cũng trùng `FALLBACK_PRICES.premium` bên web.
const num kPremiumFallbackPrice = 499000;

/// Số ngày Premium khi `cc_products.duration_days` bỏ trống.
///
/// Cùng con số với `COALESCE(v_duration_days, 365)` trong RPC
/// `complete_payment` — server mới là nơi thật sự cấp hạn, ở đây chỉ để hiển
/// thị cho khớp.
const int kPremiumFallbackDurationDays = 365;

/// Giá gói Premium để hiển thị.
class WrPremiumPricing {
  const WrPremiumPricing({
    required this.currentPrice,
    this.originalPrice,
    this.currency = 'VND',
    this.name,
    this.description,
    this.productId,
    this.durationDays = kPremiumFallbackDurationDays,
  });

  /// `cc_products.id` — phải ghi vào `cc_orders.product_id`, vì
  /// `complete_payment` tra ngược bảng này để biết cấp Premium bao nhiêu ngày.
  ///
  /// null khi rơi về [fallback]: chưa biết mua gói nào thì không cho tạo đơn.
  final String? productId;

  /// Hạn gói, để nói "một năm" hay "6 tháng" cho đúng thay vì đoán.
  final int durationDays;

  /// Giá phải trả bây giờ (`cc_products.current_price`).
  final num currentPrice;

  /// Giá gốc để gạch ngang (`cc_products.original_price`).
  ///
  /// null khi không có khuyến mãi. [hasDiscount] mới là thứ nên hỏi trước khi
  /// vẽ — giá gốc bằng hoặc thấp hơn giá hiện tại thì gạch ngang nó là nói dối.
  final num? originalPrice;

  final String currency;
  final String? name;
  final String? description;

  /// Mặc định khi chưa tải xong hoặc bảng rỗng.
  static const WrPremiumPricing fallback =
      WrPremiumPricing(currentPrice: kPremiumFallbackPrice);

  factory WrPremiumPricing.fromJson(Map<String, dynamic> json) {
    final current = json['current_price'] as num?;
    final original = json['original_price'] as num?;
    final duration = json['duration_days'] as num?;
    return WrPremiumPricing(
      productId: json['id'] as String?,
      durationDays: (duration == null || duration <= 0)
          ? kPremiumFallbackDurationDays
          : duration.toInt(),
      // 0 cũng coi như "chưa đặt giá": cột mặc định 0 bên web, và một gói
      // Premium 0đ gần như chắc chắn là dữ liệu bỏ trống chứ không phải miễn
      // phí thật.
      currentPrice:
          (current == null || current <= 0) ? kPremiumFallbackPrice : current,
      originalPrice: (original == null || original <= 0) ? null : original,
      currency: json['currency'] as String? ?? 'VND',
      name: json['name'] as String?,
      description: json['description'] as String?,
    );
  }

  /// Chỉ mua được khi biết đích xác đang mua gói nào.
  ///
  /// Rơi về [fallback] nghĩa là `cc_products` không trả hàng nào: vẫn hiện giá
  /// tham khảo được, nhưng tạo đơn thì không — đơn thiếu `product_id` sẽ khiến
  /// `complete_payment` không biết cấp bao nhiêu ngày.
  bool get canPurchase => productId != null;

  /// "một năm", "6 tháng", "90 ngày" — nói hạn gói cho đúng thay vì đoán.
  String get durationLabel {
    if (durationDays % 365 == 0) {
      final years = durationDays ~/ 365;
      return years == 1 ? 'một năm' : '$years năm';
    }
    if (durationDays % 30 == 0) return '${durationDays ~/ 30} tháng';
    return '$durationDays ngày';
  }

  /// True khi có giá gốc cao hơn giá hiện tại — chỉ khi đó mới gạch ngang.
  bool get hasDiscount =>
      originalPrice != null && originalPrice! > currentPrice;

  /// Phần trăm giảm, làm tròn. 0 khi không giảm.
  int get discountPercent {
    if (!hasDiscount) return 0;
    return (((originalPrice! - currentPrice) / originalPrice!) * 100).round();
  }

  String get currentLabel => formatVndPrice(currentPrice, currency);

  String? get originalLabel =>
      hasDiscount ? formatVndPrice(originalPrice!, currency) : null;
}

/// "499.000đ" — dấu chấm ngăn nhóm nghìn, hậu tố đ, đúng như web và ảnh chụp
/// trang quản trị.
///
/// Ngoài VND thì trả về "số cách mã tiền" chứ không bịa ký hiệu.
String formatVndPrice(num amount, [String currency = 'VND']) {
  final whole = amount.round().abs();
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  final sign = amount < 0 ? '-' : '';
  if (currency.toUpperCase() != 'VND') return '$sign$buf $currency';
  // Hậu tố tách thành hằng số: `đ` không phải ký tự định danh của Dart, nên
  // viết thẳng '${buf}đ' thì lint đòi bỏ ngoặc, mà bỏ ngoặc ('$bufđ') lại đọc
  // như một biến tên lạ.
  const dong = 'đ';
  return '$sign$buf$dong';
}
