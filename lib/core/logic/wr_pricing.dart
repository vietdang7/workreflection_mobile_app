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
//   product_type = 'premium'         → gói web
//   product_type = 'premium_mobile'  → các gói app   ← app đọc nhóm này
//
// Tách bằng `product_type` vì bảng không có cột nào chỉ nền tảng, mà web tra
// giá cũng bằng đúng cột đó (`useProductPrice(productType)` — repo web
// `src/hooks/useProductPrice.ts`). Sửa giá app ở trang quản trị là app đổi
// theo, không phải build lại.
//
// App bán NHIỀU gói cùng lúc — khách chốt 2026-08-04 thêm gói tháng để hạ rào
// cản cho người mới:
//
//   duration_days = 365, 499.000đ   (display_order 90) ← chọn sẵn
//   duration_days = 30,   70.000đ   (display_order 91)
//
// Mỗi gói là MỘT DÒNG cùng `product_type`, phân biệt bằng `duration_days`. Nên
// thêm gói 6 tháng sau này chỉ là thêm một dòng trên trang quản trị, không phải
// build lại app. Thứ tự hiện trên Paywall theo `display_order`, gói đầu tiên là
// gói chọn sẵn.
//
// Không có tự động gia hạn: hạ tầng thanh toán là chuyển khoản VietQR thủ công,
// hết hạn thì rơi về Free và mua lại.
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

  /// "một năm", "một tháng", "6 tháng", "90 ngày" — nói hạn gói cho đúng thay
  /// vì đoán.
  String get durationLabel {
    if (durationDays % 365 == 0) {
      final years = durationDays ~/ 365;
      return years == 1 ? 'một năm' : '$years năm';
    }
    if (durationDays % 30 == 0) {
      final months = durationDays ~/ 30;
      return months == 1 ? 'một tháng' : '$months tháng';
    }
    return '$durationDays ngày';
  }

  /// "năm", "tháng", "6 tháng", "90 ngày" — dạng ngắn để ghép sau dấu "/".
  ///
  /// Tách khỏi [durationLabel] vì "499.000đ / một năm" đọc lủng củng, mà "cho
  /// một năm Premium" thì lại cần đủ chữ.
  String get durationSuffix {
    if (durationDays % 365 == 0) {
      final years = durationDays ~/ 365;
      return years == 1 ? 'năm' : '$years năm';
    }
    if (durationDays % 30 == 0) {
      final months = durationDays ~/ 30;
      return months == 1 ? 'tháng' : '$months tháng';
    }
    return '$durationDays ngày';
  }

  /// Hạn gói quy ra số tháng, để so hai gói dài ngắn khác nhau trên cùng một
  /// thước.
  ///
  /// Một năm tính tròn 12 tháng chứ không phải 365/30 = 12,17 — người đọc so
  /// "một năm" với "một tháng" theo lịch, không theo số ngày.
  double get monthsSpan {
    if (durationDays % 365 == 0) return (durationDays ~/ 365) * 12;
    return durationDays / 30;
  }

  /// Giá quy về một tháng, để so gói năm với gói tháng.
  num get pricePerMonth => currentPrice / monthsSpan;

  /// Rẻ hơn [perMonthPlan] bao nhiêu phần trăm khi quy về cùng một tháng.
  ///
  /// null khi không rẻ hơn — không có gì để khoe thì đừng dán nhãn tiết kiệm.
  int? savingsPercentVs(WrPremiumPricing perMonthPlan) {
    final base = perMonthPlan.pricePerMonth;
    if (base <= 0 || pricePerMonth >= base) return null;
    final percent = ((base - pricePerMonth) / base * 100).round();
    return percent <= 0 ? null : percent;
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
