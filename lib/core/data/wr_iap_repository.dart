// Mua Premium bằng In-App Purchase của kho ứng dụng.
//
// Bọc plugin `in_app_purchase` lại sau một giao diện của riêng app, vì hai lý
// do cụ thể chứ không phải để "cho sạch":
//
//   1. Màn hình không được đụng tới kiểu dữ liệu của plugin. Test widget của
//      Paywall mà phải dựng `ProductDetails` thật là kéo cả tầng nền tảng vào
//      một bài test lẽ ra chỉ kiểm chữ với nút.
//   2. Chỗ duy nhất được quyết định "đã mua thật chưa" là backend. Repository
//      này cố ý KHÔNG có hàm nào tự kết luận điều đó — nó chỉ chuyển biên lai
//      đã ký sang Edge Function `wr-verify-iap` rồi trả về câu trả lời của
//      server. Xem `supabase/functions/wr-verify-iap/index.ts`.
//
// ⚠️ StoreKit 2 là mặc định của `in_app_purchase_storekit` từ 0.4.x. Khác biệt
// quan trọng: `serverVerificationData` KHÔNG còn là app receipt base64 như
// StoreKit 1, mà là JWS — một JWT do Apple ký, tự kiểm chứng được bằng chuỗi
// chứng thư trong header. Nhờ vậy backend không cần App Store Connect API key,
// thứ mà tài khoản App Manager của khách không tạo được.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/wr_iap_catalog.dart';
import '../models/wr_intelligence.dart';

/// Tên Edge Function xác minh biên lai.
const String kWrVerifyIapFunction = 'wr-verify-iap';

/// Một gói đang bày bán, sau khi đã hỏi giá kho ứng dụng.
///
/// [priceLabel] là chuỗi StoreKit trả về, đã kèm ký hiệu tiền tệ đúng kho của
/// người dùng. Dán thẳng chuỗi này lên nút, đừng tự định dạng lại từ
/// [rawPrice] — Apple bắt hiện đúng giá của kho, mà quy tắc đặt dấu phân cách
/// của từng nước không phải thứ nên đoán.
class WrIapOffer {
  const WrIapOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.rawPrice,
    required this.currencyCode,
    required this.durationDays,
  });

  final String id;
  final String title;
  final String description;
  final String priceLabel;
  final double rawPrice;
  final String currencyCode;

  /// Lấy từ [kWrIapProducts], không phải từ kho ứng dụng — StoreKit trả chu kỳ
  /// dưới dạng đối tượng riêng của từng nền tảng, còn app chỉ cần số ngày.
  final int durationDays;

  /// "năm" / "tháng" / "90 ngày" — phần đứng sau dấu "/" trên nút giá.
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
}

/// Trạng thái một giao dịch do kho ứng dụng báo về.
enum WrIapStatus {
  /// Đang chờ — thường là "Ask to Buy" của tài khoản trẻ em, có thể treo hàng
  /// giờ. Không được coi là thất bại.
  pending,

  /// Mua xong.
  purchased,

  /// Khôi phục lại giao dịch cũ (người dùng cài lại app hoặc đổi máy).
  restored,

  /// Người dùng bấm huỷ. KHÔNG phải lỗi — không được hiện thông báo đỏ.
  canceled,

  /// Kho ứng dụng báo lỗi.
  error,
}

/// Một giao dịch do kho ứng dụng báo về.
class WrIapPurchase {
  const WrIapPurchase({
    required this.productId,
    required this.status,
    required this.serverVerificationData,
    required this.pendingComplete,
    this.purchaseId,
    this.errorMessage,
  });

  final String productId;
  final WrIapStatus status;

  /// Biên lai đã ký (JWS với StoreKit 2). Đây là thứ duy nhất backend tin.
  final String serverVerificationData;

  /// Còn phải gọi [WrIapRepository.finish] không.
  ///
  /// Quên gọi là giao dịch nằm lại hàng đợi của kho: iOS sẽ dựng lại nó mỗi lần
  /// mở app, và Apple coi đó là lỗi giao hàng.
  final bool pendingComplete;

  final String? purchaseId;
  final String? errorMessage;
}

/// Ném khi không mua được. [message] hiện thẳng cho người dùng.
class WrIapException implements Exception {
  const WrIapException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Giao diện
// ---------------------------------------------------------------------------

abstract class WrIapRepository {
  /// Kho ứng dụng có dùng được trên máy này không.
  ///
  /// false ở máy bị khoá mua hàng, ở giả lập chưa đăng nhập, và ở mọi nền tảng
  /// không phải iOS/Android.
  Future<bool> isStoreAvailable();

  /// Hỏi giá các gói trong [kWrIapProducts].
  ///
  /// Trả danh sách rỗng khi kho không trả về gói nào — thường là gói chưa được
  /// duyệt bên App Store Connect, hoặc bản build đang chạy với bundle id khác.
  Future<List<WrIapOffer>> fetchOffers();

  /// Dòng giao dịch của kho ứng dụng.
  ///
  /// Không chỉ có giao dịch vừa bấm mua: iOS đẩy vào đây cả giao dịch còn treo
  /// từ lần mở app trước, và cả giao dịch khôi phục.
  Stream<WrIapPurchase> get purchaseUpdates;

  /// Mở hộp thoại mua của kho ứng dụng.
  ///
  /// [userId] là id Supabase của người đang đăng nhập, gửi kèm làm
  /// `appAccountToken`. Apple ghi nó vào biên lai đã ký, nhờ đó backend biết
  /// biên lai này thuộc về ai mà không phải tin lời client.
  Future<void> buy({required String productId, required String userId});

  /// Khôi phục các gói đã mua trước đó của cùng tài khoản Apple.
  ///
  /// Apple BẮT BUỘC app có nút này khi bán gói không tiêu hao.
  Future<void> restore({required String userId});

  /// Báo với kho ứng dụng là đã giao hàng xong.
  Future<void> finish(WrIapPurchase purchase);

  /// Gửi biên lai sang backend xác minh và nhận về quyền đã được cấp.
  ///
  /// Ném [WrIapException] khi backend từ chối. Không bao giờ tự suy ra quyền ở
  /// phía client: biên lai chỉ là chuỗi ký tự cho tới khi server kiểm chữ ký.
  Future<WrEntitlementRecord> verify(WrIapPurchase purchase);
}

// ---------------------------------------------------------------------------
// Bản chạy thật
// ---------------------------------------------------------------------------

class StoreKitIapRepository implements WrIapRepository {
  StoreKitIapRepository(this._iap, this._client);

  final InAppPurchase _iap;
  final SupabaseClient _client;

  @override
  Future<bool> isStoreAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      // Nền tảng không có plugin (test trên máy bàn, bản web) thì plugin ném
      // MissingPluginException. Đó là "không bán được ở đây", không phải sự cố.
      return false;
    }
  }

  @override
  Future<List<WrIapOffer>> fetchOffers() async {
    final ProductDetailsResponse res;
    try {
      res = await _iap.queryProductDetails(kWrIapProductIds);
    } catch (_) {
      return const [];
    }

    final offers = <WrIapOffer>[];
    // Duyệt theo thứ tự của [kWrIapProducts] chứ không theo thứ tự kho trả về:
    // StoreKit không hứa hẹn gì về thứ tự, mà Paywall thì cần gói năm đứng
    // trước gói tháng.
    for (final product in kWrIapProducts) {
      ProductDetails? details;
      for (final d in res.productDetails) {
        if (d.id == product.id) {
          details = d;
          break;
        }
      }
      if (details == null) continue;
      offers.add(
        WrIapOffer(
          id: details.id,
          title: details.title.isEmpty ? product.title : details.title,
          description:
              details.description.isEmpty ? product.blurb : details.description,
          priceLabel: details.price,
          rawPrice: details.rawPrice,
          currencyCode: details.currencyCode,
          durationDays: product.durationDays,
        ),
      );
    }
    return offers;
  }

  @override
  Stream<WrIapPurchase> get purchaseUpdates =>
      _iap.purchaseStream.asyncExpand(_convert);

  /// Bản gốc của plugin, gắn kèm từng [WrIapPurchase] đã phát ra.
  ///
  /// Dùng [Expando] chứ không phải Map khoá theo `purchaseID`: hai giao dịch
  /// khác nhau có thể cùng `purchaseID` null (lúc còn `pending`), mà một Map
  /// như thế thì giao dịch sau ghi đè giao dịch trước và app đóng nhầm đơn.
  /// Expando gắn theo chính đối tượng nên không có chuyện trùng khoá.
  final Expando<PurchaseDetails> _originals = Expando<PurchaseDetails>();

  Stream<WrIapPurchase> _convert(List<PurchaseDetails> batch) async* {
    for (final d in batch) {
      if (!isWrIapProductId(d.productID)) {
        // Giao dịch của product id không còn bán — ví dụ gói của bản build cũ.
        // Vẫn PHẢI đóng lại: giao dịch chưa đóng thì iOS dựng lại nó mỗi lần mở
        // app, và người dùng thấy hộp thoại mua hiện lên vô cớ.
        if (d.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(d);
          } catch (_) {
            /* đóng không được thì lần mở app sau thử lại */
          }
        }
        continue;
      }
      final purchase = _toPurchase(d);
      _originals[purchase] = d;
      yield purchase;
    }
  }

  WrIapPurchase _toPurchase(PurchaseDetails d) {
    return WrIapPurchase(
      productId: d.productID,
      status: switch (d.status) {
        PurchaseStatus.pending => WrIapStatus.pending,
        PurchaseStatus.purchased => WrIapStatus.purchased,
        PurchaseStatus.restored => WrIapStatus.restored,
        PurchaseStatus.canceled => WrIapStatus.canceled,
        PurchaseStatus.error => WrIapStatus.error,
      },
      serverVerificationData: d.verificationData.serverVerificationData,
      pendingComplete: d.pendingCompletePurchase,
      purchaseId: d.purchaseID,
      errorMessage: d.error?.message,
    );
  }

  @override
  Future<void> buy({required String productId, required String userId}) async {
    final res = await _iap.queryProductDetails({productId});
    ProductDetails? details;
    for (final d in res.productDetails) {
      if (d.id == productId) {
        details = d;
        break;
      }
    }

    if (details == null) {
      throw const WrIapException(
        'Gói này chưa bày bán trên kho ứng dụng. Bạn thử lại sau nhé.',
      );
    }

    // buyNonConsumable, không phải buyConsumable: gói đăng ký của Apple thuộc
    // nhóm không tiêu hao trong mô hình của plugin. Gọi nhầm buyConsumable thì
    // "Khôi phục giao dịch" sẽ không tìm lại được gói đã mua.
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: details,
        applicationUserName: userId,
      ),
    );
  }

  @override
  Future<void> restore({required String userId}) =>
      _iap.restorePurchases(applicationUserName: userId);

  @override
  Future<void> finish(WrIapPurchase purchase) async {
    // Plugin đòi đúng đối tượng PurchaseDetails mà chính nó phát ra, còn tầng
    // trên chỉ cầm kiểu của app. [_originals] nối hai thứ đó lại.
    final original = _originals[purchase];
    if (original == null || !original.pendingCompletePurchase) return;
    await _iap.completePurchase(original);
  }

  @override
  Future<WrEntitlementRecord> verify(WrIapPurchase purchase) async {
    if (purchase.serverVerificationData.isEmpty) {
      throw const WrIapException(
        'Kho ứng dụng không gửi kèm biên lai. Bạn thử "Khôi phục giao dịch".',
      );
    }
    try {
      final res = await _client.functions.invoke(
        kWrVerifyIapFunction,
        body: {
          'receipt': purchase.serverVerificationData,
          'productId': purchase.productId,
          'platform': 'ios',
        },
      );
      final data = res.data;
      if (data is! Map || data['entitlement'] == null) {
        throw const WrIapException(
          'Chưa xác nhận được giao dịch. Bạn thử "Khôi phục giao dịch".',
        );
      }
      return WrEntitlementRecord.fromJson(
        Map<String, dynamic>.from(data['entitlement'] as Map),
      );
    } on FunctionException catch (e) {
      final detail = e.details;
      final message = detail is Map ? detail['error']?.toString() : null;
      throw WrIapException(
        message ?? 'Chưa xác nhận được giao dịch. Bạn thử lại sau nhé.',
      );
    } on WrIapException {
      rethrow;
    } catch (_) {
      throw const WrIapException(
        'Không kết nối được để xác nhận giao dịch. Tiền chưa mất đi đâu — bạn '
        'kiểm tra mạng rồi bấm "Khôi phục giao dịch".',
      );
    }
  }
}

final wrIapRepositoryProvider = Provider<WrIapRepository>((ref) {
  return StoreKitIapRepository(
    InAppPurchase.instance,
    Supabase.instance.client,
  );
});
