// Logic thanh toán Premium — bản dịch sang Dart của luồng web.
//
// Nguồn đối chiếu (repo web `workreflection`):
//   • src/lib/order-utils.ts   — sinh mã đơn, tính giảm giá
//   • src/pages/Payment.tsx    — thông tin ngân hàng, URL VietQR, kiểm tra
//                                voucher, ràng buộc form hoá đơn
//
// Hai đầu web và mobile dùng CHUNG một tài khoản ngân hàng, chung một webhook
// và chung RPC `complete_payment`. Nên mã đơn phải sinh y hệt web: webhook chỉ
// dò chuỗi `CNC…` trong nội dung chuyển khoản, sai một quy ước là tiền vào mà
// đơn không khớp.
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

/// Loại sản phẩm ghi vào `cc_orders.product_type` khi mua Premium.
///
/// Phải kết thúc bằng `_survey`: RPC `complete_payment` chỉ cấp role premium
/// khi `right(v_product_type, 7) = '_survey'`. Web dựng chuỗi này ở
/// `Services.tsx` bằng `${productType}_survey`.
const String kPremiumOrderProductType = 'premium_survey';

/// Cửa sổ thanh toán trước khi đơn bị đánh hết hạn. Bằng web (`Payment.tsx`).
const Duration kPaymentWindow = Duration(minutes: 30);

/// Nhịp hỏi lại trạng thái đơn. Bằng web.
const Duration kPaymentPollInterval = Duration(seconds: 3);

/// Tài khoản nhận tiền. Chép từ `bankInfo` trong `Payment.tsx`.
///
/// Cố ý viết cứng chứ không đưa vào bảng cấu hình: web cũng viết cứng, mà hai
/// bên lệch số tài khoản thì tiền đi lạc.
class WrBankInfo {
  const WrBankInfo._();

  static const String bankName = 'MBBank';
  static const String accountNumber = '2610130979';
  static const String accountName = 'CLOUD CORAL';

  /// Mã BIN ngân hàng trong đường dẫn ảnh VietQR (970422 = MBBank).
  static const String bankBin = '970422';

  /// Mã mẫu ảnh QR của VietQR, lấy nguyên từ URL bên web.
  static const String qrTemplate = 'xHAYZGr';
}

/// `CNC` + 8 ký tự hex đầu của order id, viết hoa, bỏ dấu gạch.
///
/// Giữ nguyên thuật toán `generateOrderCode` bên web — webhook dò bằng biểu
/// thức `/CNC([A-Z0-9]{6,8})/i` nên độ dài cũng phải khớp.
String generateOrderCode(String orderId) {
  final compact = orderId.replaceAll('-', '');
  final head = compact.length >= 8 ? compact.substring(0, 8) : compact;
  return 'CNC${head.toUpperCase()}';
}

/// Ảnh QR chuyển khoản. Trả chuỗi rỗng khi chưa có mã đơn.
///
/// Số tiền và nội dung nhúng thẳng vào QR để người dùng khỏi gõ tay — gõ sai
/// nội dung là webhook không tìm ra đơn.
String buildVietQrUrl({required String orderCode, required num amount}) {
  if (orderCode.isEmpty) return '';
  final name = Uri.encodeComponent(WrBankInfo.accountName);
  final info = Uri.encodeComponent(orderCode);
  return 'https://api.vietqr.io/image/'
      '${WrBankInfo.bankBin}-${WrBankInfo.accountNumber}-'
      '${WrBankInfo.qrTemplate}.jpg'
      '?accountName=$name&amount=${amount.round()}&addInfo=$info';
}

/// "29:58" — đếm ngược dạng phút:giây, âm thì kẹp về 0.
String formatCountdown(Duration remaining) {
  final total = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ---------------------------------------------------------------------------
// Voucher
// ---------------------------------------------------------------------------

/// Một mã giảm giá đọc từ `cc_vouchers`.
class WrVoucher {
  const WrVoucher({
    required this.id,
    required this.code,
    required this.discountType,
    this.discountPercent = 0,
    this.discountAmount,
    this.isActive = true,
    this.validFrom,
    this.validTo,
    this.maxUses,
    this.usedCount = 0,
    this.targetType = 'all',
    this.assignedUsers = const [],
    this.applicableProducts = const [],
  });

  final String id;
  final String code;

  /// 'percentage' hoặc 'fixed'.
  final String discountType;
  final num discountPercent;
  final num? discountAmount;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validTo;
  final int? maxUses;
  final int usedCount;

  /// 'all' | 'individual_free' | 'individual_premium' | 'enterprise' |
  /// 'specific_users'
  final String targetType;
  final List<String> assignedUsers;

  /// Danh sách dịch vụ áp dụng: 'premium' | 'workshop' | 'coaching'.
  final List<String> applicableProducts;

  factory WrVoucher.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    List<String> parseList(Object? v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return WrVoucher(
      id: json['id'].toString(),
      code: json['code']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? 'percentage',
      discountPercent: (json['discount_percent'] as num?) ?? 0,
      discountAmount: json['discount_amount'] as num?,
      isActive: json['is_active'] as bool? ?? true,
      validFrom: parseDate(json['valid_from']),
      validTo: parseDate(json['valid_to']),
      maxUses: (json['max_uses'] as num?)?.toInt(),
      usedCount: ((json['used_count'] as num?) ?? 0).toInt(),
      targetType: json['target_type']?.toString() ?? 'all',
      assignedUsers: parseList(json['assigned_users']),
      applicableProducts: parseList(json['applicable_products']),
    );
  }
}

/// Số tiền được giảm. Bản dịch của `calculateDiscount` bên web.
///
/// Giảm theo số tiền cố định thì không vượt quá giá gốc — nếu không sẽ ra đơn
/// âm tiền.
num calculateVoucherDiscount(WrVoucher voucher, num originalPrice) {
  if (voucher.discountType == 'percentage') {
    return (originalPrice * (voucher.discountPercent / 100)).round();
  }
  final fixed = voucher.discountAmount ?? 0;
  return fixed < originalPrice ? fixed : originalPrice;
}

/// Kiểm tra một voucher có dùng được cho lần mua này không.
///
/// Trả về null khi hợp lệ, hoặc câu báo lỗi tiếng Việt để hiện thẳng lên màn
/// hình. Thứ tự kiểm tra giữ đúng như web để hai bên báo cùng một lý do khi
/// một mã hỏng vì nhiều nguyên nhân cùng lúc.
String? validateVoucher(
  WrVoucher voucher, {
  required DateTime now,
  String? userId,
  String? userRole,
  String? orgId,
  String productType = kPremiumOrderProductType,
}) {
  if (!voucher.isActive) return 'Mã giảm giá đã ngừng hoạt động';

  final validTo = voucher.validTo;
  if (validTo != null && validTo.isBefore(now)) {
    return 'Mã giảm giá đã hết hạn';
  }

  final validFrom = voucher.validFrom;
  if (validFrom != null && validFrom.isAfter(now)) {
    return 'Mã giảm giá chưa đến ngày sử dụng';
  }

  final maxUses = voucher.maxUses;
  if (maxUses != null && maxUses > 0 && voucher.usedCount >= maxUses) {
    return 'Mã giảm giá đã hết lượt sử dụng';
  }

  // Quyền dùng theo nhóm người dùng. Admin và điều phối viên bỏ qua vòng này,
  // giống web — họ cần thử được mọi mã.
  final role = (userRole ?? '').trim().toLowerCase();
  final privileged = role == 'admin' || role == 'coordinator';
  if (voucher.targetType != 'all' && !privileged) {
    final effectiveRole = role.isEmpty ? 'free' : role;
    final eligible = switch (voucher.targetType) {
      'individual_free' => effectiveRole == 'free',
      'individual_premium' => effectiveRole == 'premium',
      'enterprise' => effectiveRole == 'enterprise' || (orgId ?? '').isNotEmpty,
      'specific_users' =>
        userId != null && voucher.assignedUsers.contains(userId),
      _ => true,
    };
    if (!eligible) return 'Mã giảm giá không áp dụng cho tài khoản của bạn';
  }

  // Giới hạn theo dịch vụ.
  if (voucher.applicableProducts.isNotEmpty) {
    final service = serviceKeyForProductType(productType);
    if (!voucher.applicableProducts.contains(service)) {
      const labels = {
        'premium': 'Bài test Premium',
        'workshop': 'Workshop',
        'coaching': 'Coaching',
      };
      final allowed = voucher.applicableProducts
          .map((s) => labels[s] ?? s)
          .join(', ');
      return 'Mã giảm giá chỉ áp dụng cho $allowed';
    }
  }

  return null;
}

/// Quy `product_type` của đơn về khoá dịch vụ mà voucher dùng.
///
/// Web gộp mọi `*_survey` về 'premium' và hai loại workshop về 'workshop'.
String serviceKeyForProductType(String productType) {
  if (productType.endsWith('_survey')) return 'premium';
  if (productType == 'workshop' || productType == 'workshop_enterprise') {
    return 'workshop';
  }
  return productType;
}

// ---------------------------------------------------------------------------
// Hoá đơn VAT
// ---------------------------------------------------------------------------

/// Nội dung form xuất hoá đơn, ánh xạ sang các cột `invoice_*` của `cc_orders`.
class WrInvoiceForm {
  const WrInvoiceForm({
    this.requested = false,
    this.buyerName = '',
    this.legalName = '',
    this.taxCode = '',
    this.address = '',
    this.email = '',
  });

  /// Có lấy hoá đơn hay không. Tắt thì mọi ô còn lại bị bỏ qua.
  final bool requested;

  /// Người mua — bắt buộc khi lấy hoá đơn.
  final String buyerName;

  /// Tên đơn vị. Đi cặp với [taxCode].
  final String legalName;

  /// Mã số thuế. Đi cặp với [legalName].
  final String taxCode;

  /// Địa chỉ — bắt buộc khi lấy hoá đơn.
  final String address;

  final String email;

  WrInvoiceForm copyWith({
    bool? requested,
    String? buyerName,
    String? legalName,
    String? taxCode,
    String? address,
    String? email,
  }) {
    return WrInvoiceForm(
      requested: requested ?? this.requested,
      buyerName: buyerName ?? this.buyerName,
      legalName: legalName ?? this.legalName,
      taxCode: taxCode ?? this.taxCode,
      address: address ?? this.address,
      email: email ?? this.email,
    );
  }

  /// Lý do form chưa hợp lệ, hoặc null khi đã đủ.
  ///
  /// Cùng ràng buộc với web: cần tên người mua và địa chỉ; mã số thuế và tên
  /// đơn vị phải cùng có hoặc cùng trống — có mã số thuế mà thiếu tên đơn vị
  /// thì cơ quan thuế không nhận.
  String? get validationError {
    if (!requested) return null;
    if (buyerName.trim().isEmpty) return 'Chưa điền tên người mua';
    if (address.trim().isEmpty) return 'Chưa điền địa chỉ';
    final hasTax = taxCode.trim().isNotEmpty;
    final hasLegal = legalName.trim().isNotEmpty;
    if (hasTax && !hasLegal) return 'Có mã số thuế thì phải có tên đơn vị';
    if (hasLegal && !hasTax) return 'Có tên đơn vị thì phải có mã số thuế';
    return null;
  }

  bool get isValid => validationError == null;

  /// Payload ghi vào `cc_orders`. Tắt hoá đơn thì xoá sạch các cột cũ chứ
  /// không để lại dữ liệu mồ côi.
  Map<String, dynamic> toOrderPayload() {
    if (!requested) {
      return const {
        'invoice_requested': false,
        'invoice_buyer_name': null,
        'invoice_legal_name': null,
        'invoice_tax_code': null,
        'invoice_address': null,
        'invoice_email': null,
      };
    }
    String? trimmed(String v) => v.trim().isEmpty ? null : v.trim();
    return {
      'invoice_requested': true,
      'invoice_buyer_name': trimmed(buyerName),
      'invoice_legal_name': trimmed(legalName),
      'invoice_tax_code': trimmed(taxCode),
      'invoice_address': trimmed(address),
      'invoice_email': trimmed(email),
    };
  }
}
