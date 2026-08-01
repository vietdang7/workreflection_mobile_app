// Giá gói Premium — lấy từ cùng một nguồn với web.
//
// Khách chốt 2026-08-01: "giá premium trên app cũng canh theo web luôn". Nguồn
// sự thật là bảng `cc_products` (product_type = 'premium', is_active = true),
// đúng bảng mà trang quản trị Gói dịch vụ của web ghi vào — sửa giá ở đó là app
// đổi theo, không phải build lại.
//
// Web đọc bảng này qua `useProductPrice` (repo web:
// `src/hooks/useProductPrice.ts`), lấy `current_price` / `original_price` và
// rơi về 499.000 khi không có hàng nào. Bản mobile giữ đúng quy ước đó để hai
// đầu không bao giờ báo hai con số khác nhau.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

/// Giá đã rơi về mặc định nếu `cc_products` không trả hàng nào.
///
/// Cùng con số với `FALLBACK_PRICES.premium` bên web — nếu một ngày web đổi
/// mặc định thì đổi cả ở đây.
const num kPremiumFallbackPrice = 499000;

/// Giá gói Premium để hiển thị.
class WrPremiumPricing {
  const WrPremiumPricing({
    required this.currentPrice,
    this.originalPrice,
    this.currency = 'VND',
    this.name,
    this.description,
  });

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
    return WrPremiumPricing(
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
