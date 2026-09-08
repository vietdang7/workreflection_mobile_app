// Nhắc trước khi kỳ thuê bao kết thúc.
//
// Khách chốt 08/09/2026: bán gói TỰ ĐỘNG GIA HẠN, "nhưng phải thông báo nếu gần
// hết hạn".
//
// ---------------------------------------------------------------------------
// VÌ SAO PHẢI CÓ FILE NÀY THAY VÌ MỘT DÒNG `if` TRONG WIDGET
//
// Cùng một ngày trên lịch mang hai nghĩa ngược nhau, tuỳ người dùng đã tắt gia
// hạn hay chưa:
//
//   • còn bật gia hạn → đó là ngày BỊ TRỪ TIỀN kỳ tiếp
//   • đã tắt gia hạn  → đó là ngày MẤT QUYỀN
//
// Nói nhầm vế nào cũng là nói sai với đúng một nửa số người đọc. Mà còn vế thứ
// ba: NGAY SAU KHI MUA thì mình chưa biết gì cả — Apple chỉ báo trạng thái gia
// hạn qua App Store Server Notifications, và thông báo đầu tiên thường tới vào
// đúng kỳ gia hạn. Với người mua gói tháng thì "chưa biết" là trạng thái của cả
// tháng đầu, tức là trường hợp thường gặp nhất chứ không phải ngoại lệ hiếm.
//
// Ba vế, ba câu khác nhau, mỗi câu một cửa sổ ngày khác nhau — đủ để đáng có
// chỗ riêng và có test riêng, thay vì trốn trong `build()` của một widget.

/// Một thuê bao App Store của người đang đăng nhập.
///
/// Ảnh chụp từ `wr_iap_transactions` — bảng đó client chỉ ĐỌC được hàng của
/// chính mình, mọi thứ ghi vào đều do `wr-verify-iap` và
/// `wr-apple-notifications` làm bằng service role.
class WrIapSubscription {
  const WrIapSubscription({
    required this.productId,
    this.expiresAt,
    this.autoRenew,
    this.revokedAt,
  });

  final String productId;

  /// Mốc kết thúc kỳ hiện tại.
  final DateTime? expiresAt;

  /// `null` nghĩa là CHƯA BIẾT — Apple chưa gửi thông báo nào cho thuê bao này.
  /// Cố ý để ba trạng thái chứ không hai: đoán bừa là nói sai với người dùng.
  final bool? autoRenew;

  /// Có giá trị là Apple đã hoàn tiền / thu hồi.
  final DateTime? revokedAt;

  factory WrIapSubscription.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) =>
        v is String ? DateTime.tryParse(v)?.toLocal() : null;
    return WrIapSubscription(
      productId: json['product_id'] as String? ?? '',
      expiresAt: parse(json['expires_at']),
      autoRenew: json['auto_renew'] as bool?,
      revokedAt: parse(json['revoked_at']),
    );
  }
}

/// Kiểu lời nhắc — quyết định câu chữ và việc có nút gia hạn hay không.
enum WrRenewalKind {
  /// Sẽ tự động trừ tiền kỳ tiếp.
  willRenew,

  /// Đã tắt gia hạn, tới hạn là về bản miễn phí.
  willEnd,

  /// Chưa biết người dùng đã tắt gia hạn hay chưa.
  unknown,
}

/// Nội dung một lời nhắc, đã đủ để vẽ mà không cần tính thêm gì.
class WrRenewalNotice {
  const WrRenewalNotice({
    required this.kind,
    required this.date,
    required this.daysLeft,
  });

  final WrRenewalKind kind;

  /// Ngày kết thúc kỳ hiện tại.
  final DateTime date;

  /// Số ngày còn lại, đã làm tròn LÊN: còn 20 tiếng thì vẫn là "1 ngày" chứ
  /// không phải "0 ngày". Làm tròn xuống sẽ hiện "còn 0 ngày" suốt ngày cuối.
  final int daysLeft;

  String get dateLabel =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String get title => switch (kind) {
        WrRenewalKind.willRenew => 'Gói tự động gia hạn ngày $dateLabel',
        WrRenewalKind.willEnd => 'Gói hết hạn ngày $dateLabel',
        WrRenewalKind.unknown => 'Kỳ hiện tại kết thúc ngày $dateLabel',
      };

  String get body => switch (kind) {
        WrRenewalKind.willRenew =>
          'Apple sẽ trừ tiền kỳ tiếp vào ngày này. Không muốn gia hạn nữa thì '
              'tắt trước ngày đó — bạn vẫn dùng hết kỳ đã trả tiền.',
        WrRenewalKind.willEnd =>
          'Bạn đã tắt tự động gia hạn. Sau ngày này tài khoản trở về bản miễn '
              'phí, những gì bạn đã ghi vẫn còn nguyên.',
        WrRenewalKind.unknown =>
          'Nếu bạn chưa tắt tự động gia hạn thì Apple sẽ trừ tiền kỳ tiếp vào '
              'ngày này. Mở phần quản lý gói để xem và đổi.',
      };
}

/// Cửa sổ nhắc, tính bằng ngày trước lúc hết kỳ.
///
/// Người sắp MẤT quyền cần nhiều thời gian hơn người sắp bị trừ tiền: họ phải
/// quyết định có mua tiếp không, còn người kia chỉ cần biết để tắt nếu muốn.
const int kRenewNoticeDays = 7;
const int kEndNoticeDays = 14;

/// Lời nhắc cần hiện, hoặc `null` khi chưa tới lúc nói gì.
///
/// Trả `null` — tức IM LẶNG — trong bốn trường hợp, và mỗi trường hợp đều là im
/// lặng có chủ ý chứ không phải quên:
///
///   • không có thuê bao nào, hoặc thuê bao không có hạn;
///   • đã bị hoàn tiền / thu hồi — lúc đó người dùng đã về bản miễn phí, việc
///     của app là mời mua lại chứ không phải nhắc một cái hạn đã mất;
///   • hạn đã qua — cũng vậy;
///   • còn quá xa. Nhắc từ hai tháng trước là dạy người ta bỏ qua lời nhắc.
WrRenewalNotice? wrRenewalNotice(
  WrIapSubscription? subscription, {
  required DateTime now,
}) {
  final sub = subscription;
  if (sub == null) return null;
  if (sub.revokedAt != null) return null;

  final expiresAt = sub.expiresAt;
  if (expiresAt == null) return null;
  if (!expiresAt.isAfter(now)) return null;

  final kind = switch (sub.autoRenew) {
    true => WrRenewalKind.willRenew,
    false => WrRenewalKind.willEnd,
    null => WrRenewalKind.unknown,
  };

  // Cửa sổ của vế "chưa biết" đi theo vế nguy hiểm hơn: nếu hoá ra người dùng
  // đã tắt gia hạn mà mình im tới ngày thứ 7 thì họ mất 7 ngày để xoay xở.
  final window =
      kind == WrRenewalKind.willRenew ? kRenewNoticeDays : kEndNoticeDays;

  final daysLeft = expiresAt.difference(now).inMinutes / (60 * 24);
  final rounded = daysLeft.ceil();
  if (rounded > window) return null;

  return WrRenewalNotice(
    kind: kind,
    date: expiresAt,
    daysLeft: rounded,
  );
}
