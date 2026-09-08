// Trạng thái luồng mua Premium qua kho ứng dụng.
//
// Hình dạng của luồng này do StoreKit quy định chứ không do app chọn: bấm nút
// mua KHÔNG trả về kết quả. Kết quả tới sau, qua `purchaseUpdates`, có thể là
// vài giây (mua xong), có thể là vài giờ (tài khoản trẻ em cần cha mẹ duyệt),
// và có thể tới lúc app vừa mở lên (giao dịch còn treo từ phiên trước). Nên
// controller này phải nghe từ lúc app dựng màn, không phải từ lúc bấm nút.
//
// Ba việc, đúng thứ tự, không được đảo:
//   1. Nhận giao dịch từ kho ứng dụng.
//   2. Gửi biên lai sang `wr-verify-iap` để server xác minh và cấp quyền.
//   3. Chỉ khi server đã cấp quyền mới báo "đã giao hàng" cho kho ứng dụng.
//
// Đảo bước 3 lên trước bước 2 là mất tiền của người dùng: giao dịch đóng rồi
// thì kho ứng dụng không đẩy lại nữa, mà quyền thì chưa kịp ghi vào
// `wr_entitlements`. Đúng thứ tự này thì lần mở app sau StoreKit dựng lại giao
// dịch và app thử xác minh lại.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/wr_iap_repository.dart';
import 'wr_providers.dart';

/// Các gói đang bày bán, đã hỏi giá kho ứng dụng.
///
/// Không bao giờ ném: kho không dùng được hay chưa duyệt gói thì trả danh sách
/// rỗng, và Paywall tự nói "chưa mở bán ở đây" thay vì hiện màn lỗi.
final wrIapOffersProvider = FutureProvider<List<WrIapOffer>>((ref) async {
  final policy = ref.watch(wrStorePolicyProvider);
  if (!policy.allowsNativeIap) return const [];

  final repo = ref.watch(wrIapRepositoryProvider);
  if (!await repo.isStoreAvailable()) return const [];
  return repo.fetchOffers();
});

/// Giai đoạn của luồng mua, để Paywall biết vẽ gì.
enum WrIapPhase {
  /// Chưa bấm gì.
  idle,

  /// Đã mở hộp thoại của kho ứng dụng, đang chờ người dùng.
  buying,

  /// Kho ứng dụng báo giao dịch còn chờ duyệt (Ask to Buy).
  awaitingApproval,

  /// Đang gửi biên lai cho server xác minh.
  verifying,

  /// Xong, quyền đã được cấp.
  done,
}

/// Trạng thái luồng mua.
class WrIapState {
  const WrIapState({
    this.phase = WrIapPhase.idle,
    this.error,
    this.restoredNothing = false,
  });

  final WrIapPhase phase;

  /// Câu lỗi đã sẵn sàng hiện cho người dùng. Null khi không có lỗi.
  ///
  /// Người dùng bấm huỷ KHÔNG đặt trường này — huỷ là một lựa chọn hợp lệ, báo
  /// đỏ vào mặt người vừa đổi ý là thô lỗ.
  final String? error;

  /// Vừa bấm "Khôi phục giao dịch" mà không tìm thấy gói nào.
  ///
  /// Tách khỏi [error] vì đây không phải trục trặc: phần lớn là người chưa từng
  /// mua trên tài khoản Apple đang đăng nhập.
  final bool restoredNothing;

  bool get busy =>
      phase == WrIapPhase.buying ||
      phase == WrIapPhase.awaitingApproval ||
      phase == WrIapPhase.verifying;

  WrIapState copyWith({
    WrIapPhase? phase,
    Object? error = _keep,
    bool? restoredNothing,
  }) {
    return WrIapState(
      phase: phase ?? this.phase,
      error: identical(error, _keep) ? this.error : error as String?,
      restoredNothing: restoredNothing ?? this.restoredNothing,
    );
  }

  static const Object _keep = Object();
}

class WrIapController extends StateNotifier<WrIapState> {
  WrIapController(this._ref) : super(const WrIapState()) {
    _listen();
  }

  final Ref _ref;
  StreamSubscription<WrIapPurchase>? _sub;

  WrIapRepository get _repo => _ref.read(wrIapRepositoryProvider);

  void _listen() {
    if (!_ref.read(wrStorePolicyProvider).allowsNativeIap) return;
    try {
      _sub = _repo.purchaseUpdates.listen(
        _onPurchase,
        onError: (_) {
          if (!mounted) return;
          state = state.copyWith(
            phase: WrIapPhase.idle,
            error: 'Kho ứng dụng báo lỗi. Bạn thử lại sau nhé.',
          );
        },
      );
    } catch (_) {
      /* nền tảng không có plugin — Paywall đã tự ẩn phần mua rồi */
    }
  }

  Future<void> _onPurchase(WrIapPurchase purchase) async {
    switch (purchase.status) {
      case WrIapStatus.pending:
        state = state.copyWith(
          phase: WrIapPhase.awaitingApproval,
          error: null,
        );
        return;

      case WrIapStatus.canceled:
        // Không đặt error: huỷ là lựa chọn, không phải sự cố.
        state = state.copyWith(phase: WrIapPhase.idle, error: null);
        return;

      case WrIapStatus.error:
        // Vẫn phải đóng giao dịch lỗi, nếu không nó dựng lại mỗi lần mở app.
        await _finishQuietly(purchase);
        state = state.copyWith(
          phase: WrIapPhase.idle,
          error: purchase.errorMessage?.trim().isNotEmpty == true
              ? purchase.errorMessage
              : 'Kho ứng dụng không hoàn tất được giao dịch.',
        );
        return;

      case WrIapStatus.purchased:
      case WrIapStatus.restored:
        await _verifyThenFinish(purchase);
        return;
    }
  }

  Future<void> _verifyThenFinish(WrIapPurchase purchase) async {
    state = state.copyWith(phase: WrIapPhase.verifying, error: null);
    try {
      await _repo.verify(purchase);
    } on WrIapException catch (e) {
      // CỐ Ý KHÔNG đóng giao dịch ở đây. Chưa xác minh được mà đóng là người
      // dùng mất tiền không lấy lại được quyền. Để nguyên thì StoreKit đẩy lại
      // giao dịch lần mở app sau và app thử lại.
      if (!mounted) return;
      state = state.copyWith(phase: WrIapPhase.idle, error: e.message);
      return;
    }

    // Server đã ghi quyền — giờ mới báo kho ứng dụng là đã giao hàng.
    await _finishQuietly(purchase);

    // Bắt cả app đọc lại quyền: Paywall, các cổng Premium, màn Tài khoản.
    _ref.invalidate(wrEntitlementProvider);

    if (!mounted) return;
    state = state.copyWith(
      phase: WrIapPhase.done,
      error: null,
      restoredNothing: false,
    );
  }

  Future<void> _finishQuietly(WrIapPurchase purchase) async {
    try {
      await _repo.finish(purchase);
    } catch (_) {
      /* đóng không được thì lần mở app sau thử lại, không làm phiền người dùng */
    }
  }

  /// Bắt đầu mua [productId].
  Future<void> buy(String productId) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        error: 'Bạn cần đăng nhập trước khi mua.',
      );
      return;
    }
    state = state.copyWith(
      phase: WrIapPhase.buying,
      error: null,
      restoredNothing: false,
    );
    try {
      await _repo.buy(productId: productId, userId: userId);
    } on WrIapException catch (e) {
      if (!mounted) return;
      state = state.copyWith(phase: WrIapPhase.idle, error: e.message);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        phase: WrIapPhase.idle,
        error: 'Không mở được cửa sổ thanh toán của kho ứng dụng.',
      );
    }
  }

  /// Khôi phục gói đã mua trên cùng tài khoản Apple.
  ///
  /// Kho ứng dụng trả kết quả qua [purchaseUpdates] chứ không trả tại chỗ, nên
  /// hàm này chỉ đặt trạng thái chờ. Không tìm thấy gì thì luồng im lặng —
  /// [restoredNothing] để Paywall nói được điều đó thay vì quay mãi.
  Future<void> restore() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(error: 'Bạn cần đăng nhập trước.');
      return;
    }
    state = state.copyWith(
      phase: WrIapPhase.verifying,
      error: null,
      restoredNothing: false,
    );
    try {
      await _repo.restore(userId: userId);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        phase: WrIapPhase.idle,
        error: 'Không khôi phục được lúc này. Bạn thử lại sau nhé.',
      );
      return;
    }

    // Chờ một nhịp cho kho ứng dụng đẩy giao dịch cũ vào luồng. Hết nhịp mà vẫn
    // ở trạng thái chờ nghĩa là tài khoản Apple này không có gói nào để trả về.
    await Future<void>.delayed(kWrIapRestoreWindow);
    if (!mounted) return;
    if (state.phase == WrIapPhase.verifying) {
      state = state.copyWith(phase: WrIapPhase.idle, restoredNothing: true);
    }
  }

  /// Xoá thông báo lỗi sau khi màn hình đã hiện xong.
  void clearMessages() {
    state = state.copyWith(error: null, restoredNothing: false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Bao lâu thì coi như "khôi phục xong mà không có gì".
///
/// 6 giây: `restorePurchases` của StoreKit thường trả trong 1–2 giây, nhưng
/// mạng 3G ở quán cà phê thì chậm hơn. Ngắn quá là báo nhầm "không có gói nào"
/// cho người thật sự có gói.
const Duration kWrIapRestoreWindow = Duration(seconds: 6);

final wrIapControllerProvider =
    StateNotifierProvider<WrIapController, WrIapState>((ref) {
  return WrIapController(ref);
});
