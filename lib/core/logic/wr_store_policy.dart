// Chính sách bán hàng của bản build.
//
// Vì sao có file này: CẢ HAI kho ứng dụng đều cấm bán hàng số bằng cổng thanh
// toán riêng, mà luồng mua Premium đầu tiên của WorkReflection là chuyển khoản
// VietQR (`wr_payment.dart`).
//
//   • Apple — App Store Review Guideline 3.1.1: mọi thứ mở khoá tính năng số
//     phải đi qua In-App Purchase.
//   • Google — Play Payments policy: "app functionality or premium features"
//     và "subscription services" bắt buộc dùng Google Play Billing.
//
// Nên trên cả iOS lẫn Android, app ẩn màn QR và chỉ dẫn người dùng hoàn tất
// trên web. Vi phạm bên Apple là bị từ chối bản nộp; bên Google nặng hơn — bị
// gỡ app khỏi kho.
//
// ⚠️ ẨN THÔI THÌ KHÔNG ĐỦ — bài học bản 1.0 (6), bị từ chối 06/09/2026.
//
// Bản đó build ở chế độ [silent]: không QR, không giá, không nút sang web. Vẫn
// dính 3.1.1. Lý do: tài khoản demo gửi Apple có `cc_profiles.role = 'premium'`
// mua từ web, nên người duyệt đăng nhập vào là dùng được đầy đủ tính năng trả
// tiền — đúng câu Apple viết, "accesses digital content purchased outside the
// app, but that content isn't available to purchase using In-App Purchase".
//
// Guideline 3.1.3(b) CHO PHÉP dùng chéo nền tảng (mua trên web, xài trên app),
// nhưng kèm điều kiện: gói đó phải mua được bằng IAP ngay trong app. Nên lối
// thoát duy nhất giữ được giá trị cho khách đã mua web là [nativeIap] — xem
// `lib/core/logic/wr_iap_catalog.dart`.
//
// Phần app KHÔNG dính hai policy này, nên không đụng tới:
//   • Trà Chiều / workshop offline — sự kiện đời thực, cả hai kho đều miễn.
//   • Coaching 1:1 — Google miễn riêng "1:1 online services"; Apple cũng cho
//     dịch vụ người-thật-dạy-người-thật ra ngoài IAP.
// Hai luồng đó vốn đã chỉ hiện hộp thoại "thanh toán trên web", không có QR.
//
// ⚠️ Lưu ý pháp lý còn tồn đọng: cả hai kho cũng cấm "dẫn dụ ra ngoài"
// (anti-steering), tức chính cái nút sang web cũng chưa chắc lọt.
//   • Apple mở ngoại lệ cho kho Mỹ (phán quyết Epic 2025) và EU (DMA).
//   • Google mở billing thay thế + link ra web từ 30/6/2026 cho Mỹ, EEA, Anh,
//     và Úc từ 30/9/2026.
// Kho Việt Nam KHÔNG nằm trong nhóm nào cả — Việt Nam cũng không có trong
// danh sách hơn 35 nước của user choice billing. Nên nút dẫn sang web vẫn là
// rủi ro. Muốn an toàn tuyệt đối thì build với
// `--dart-define=HIDE_WEB_PURCHASE_LINK=true`, lúc đó paywall chỉ giải thích
// tính năng chứ không nhắc tới chuyện mua ở đâu.
//
// Pure Dart trừ một hằng của Flutter → test được trực tiếp.

import 'package:flutter/foundation.dart';

/// Quy tắc bán hàng của một bản build.
@immutable
class WrStorePolicy {
  const WrStorePolicy({
    required this.allowsVietQrCheckout,
    required this.allowsWebPurchaseLink,
    this.allowsNativeIap = false,
  });

  /// Có được mở màn thanh toán QR ngay trong app không.
  ///
  /// Mặc định false ở MỌI bản build: màn `/wr/payment` bị chặn ở tầng route
  /// luôn, không chỉ ẩn nút — deep link hay đoạn code cũ nào còn
  /// `push('/wr/payment')` cũng không lọt được.
  final bool allowsVietQrCheckout;

  /// Có được hiện lối dẫn sang trang mua trên web không.
  ///
  /// Tách khỏi [allowsVietQrCheckout] để hạ rủi ro duyệt bằng một cờ build,
  /// khỏi phải sửa code nếu kho ứng dụng bắt bẻ chuyện anti-steering.
  final bool allowsWebPurchaseLink;

  /// Có bán Premium bằng In-App Purchase của kho ứng dụng không.
  ///
  /// ĐỪNG NHẦM với [allowsVietQrCheckout]. Hai thứ này cùng là "mua ngay trong
  /// app" nhưng khác nhau ở chỗ tiền chạy qua đâu, và đó đúng là chỗ hai kho
  /// ứng dụng quan tâm:
  ///   • [allowsVietQrCheckout] — chuyển khoản VietQR, tiền về thẳng tài khoản
  ///     công ty. Đây là thứ Guideline 3.1.1 CẤM.
  ///   • [allowsNativeIap]      — StoreKit/Play Billing, kho ứng dụng thu hộ và
  ///     giữ lại 15–30%. Đây là thứ Guideline 3.1.1 BẮT BUỘC.
  ///
  /// Mặc định false để bản Android và các bản chạy thử không đụng tới StoreKit
  /// — hiện chỉ bản iOS bật, vì mới chỉ khai gói bên App Store Connect.
  final bool allowsNativeIap;

  /// Mở màn QR trong app. KHÔNG phải mặc định của bản build nào cả.
  ///
  /// Chỉ dùng khi cố ý bật bằng `--dart-define=FORCE_STORE_POLICY=open`, và
  /// trong test của chính luồng thanh toán. Bản Flutter web cũng không được
  /// hưởng chế độ này: repo này là app di động, "web" của sản phẩm là repo
  /// React với trang `/premium` riêng. Từng để bản web chạy `open` và hậu quả
  /// là chạy thử `flutter run -d chrome` thấy y nguyên màn QR, tưởng chặn hỏng.
  static const WrStorePolicy open = WrStorePolicy(
    allowsVietQrCheckout: true,
    allowsWebPurchaseLink: true,
  );

  /// Bản phát hành qua kho ứng dụng: không bán trong app, chỉ dẫn sang web.
  static const WrStorePolicy webLinkOnly = WrStorePolicy(
    allowsVietQrCheckout: false,
    allowsWebPurchaseLink: true,
  );

  /// Bản dè dặt nhất: không bán, cũng không nhắc tới chỗ mua.
  ///
  /// Để dành cho tình huống bị từ chối vì anti-steering — đổi cờ build là nộp
  /// lại được ngay, không phải sửa code.
  ///
  /// ⚠️ ĐÂY LÀ CHÍNH SÁCH CỦA BẢN BỊ TỪ CHỐI 06/09/2026. Im lặng không gỡ được
  /// 3.1.1 khi tài khoản vẫn dùng được Premium mua từ web. Đừng quay lại đây để
  /// chữa lỗi đó — dùng [appStore].
  static const WrStorePolicy silent = WrStorePolicy(
    allowsVietQrCheckout: false,
    allowsWebPurchaseLink: false,
  );

  /// Bản nộp App Store: bán bằng IAP, không QR, không dẫn ra web.
  ///
  /// Bỏ luôn nút sang web chứ không chỉ vì anti-steering: khi trong app đã mua
  /// được rồi thì một nút "rẻ hơn ở web" ngay cạnh là mời Apple từ chối lần
  /// nữa. Người đã mua trên web vẫn dùng được bình thường — quyền của họ tới
  /// từ `cc_profiles.role`, không cần nút nào cả.
  static const WrStorePolicy appStore = WrStorePolicy(
    allowsVietQrCheckout: false,
    allowsWebPurchaseLink: false,
    allowsNativeIap: true,
  );

  /// Cờ build hạ nút dẫn sang web:
  /// `flutter build ipa --dart-define=HIDE_WEB_PURCHASE_LINK=true`
  static const bool _hideWebLink = bool.fromEnvironment(
    'HIDE_WEB_PURCHASE_LINK',
  );

  /// Cờ ép chính sách để xem thử, bất kể đang chạy nền tảng nào.
  ///
  /// Dùng để mở LẠI màn QR khi cần kiểm tra luồng thanh toán, vì mọi bản build
  /// mặc định đã khoá:
  ///   `flutter run --dart-define=FORCE_STORE_POLICY=open`
  ///   `flutter run --dart-define=FORCE_STORE_POLICY=silent`
  ///   `flutter run --dart-define=FORCE_STORE_POLICY=web_link`
  ///   `flutter run --dart-define=FORCE_STORE_POLICY=app_store`
  static const String _forced = String.fromEnvironment('FORCE_STORE_POLICY');

  /// Chính sách của bản build này.
  ///
  /// KHÔNG suy theo nền tảng nữa. Repo này chỉ phát hành qua App Store và CH
  /// Play, cả hai đều cấm bán hàng số bằng cổng riêng — nên khoá là mặc định,
  /// mở mới là ngoại lệ phải khai rõ. Bản chạy thử trên Chrome hay desktop
  /// cũng khoá y hệt, để thứ mình nhìn thấy lúc chạy thử đúng bằng thứ người
  /// duyệt app sẽ thấy.
  factory WrStorePolicy.forThisBuild() {
    // Giá trị lạ thì bỏ qua chứ không ném: gõ sai cờ lúc build mà app chết
    // ngay khi mở paywall là cái giá quá đắt cho một lỗi chính tả.
    switch (_forced) {
      case 'web_link':
        return webLinkOnly;
      case 'silent':
        return silent;
      case 'open':
        return open;
      case 'app_store':
        return appStore;
    }

    return _hideWebLink ? silent : webLinkOnly;
  }

  @override
  bool operator ==(Object other) =>
      other is WrStorePolicy &&
      other.allowsVietQrCheckout == allowsVietQrCheckout &&
      other.allowsWebPurchaseLink == allowsWebPurchaseLink &&
      other.allowsNativeIap == allowsNativeIap;

  @override
  int get hashCode => Object.hash(
        allowsVietQrCheckout,
        allowsWebPurchaseLink,
        allowsNativeIap,
      );
}

/// Đường dẫn web mở thẳng trang mua Premium, kèm gói đã chọn sẵn.
///
/// `plan` là `cc_products.id`; web đọc `?plan=` để bôi sẵn đúng gói, khỏi bắt
/// người dùng chọn lại thứ họ vừa chọn trong app. Không có id thì trả đường
/// dẫn trần, web tự để người dùng chọn.
///
/// `source` để bên web đo được bao nhiêu người thật sự đi hết đường từ app
/// sang — con số này quyết định có đáng bỏ 15–30% doanh thu ra làm IAP/Play
/// Billing thật hay không. Tách riêng iOS với Android vì hai kho có thể cho
/// ra tỉ lệ rất khác nhau, mà quyết định làm billing lại là quyết định riêng
/// từng kho.
String wrWebPremiumUrl({
  required String baseUrl,
  String? planProductId,
  String source = 'app',
}) {
  final root = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final query = <String, String>{'source': source};
  final plan = planProductId?.trim();
  if (plan != null && plan.isNotEmpty) query['plan'] = plan;
  final qs = query.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  return '$root/premium?$qs';
}
