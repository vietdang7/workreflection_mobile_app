// Payment repository — mua Premium.
//
// Mọi truy vấn Supabase liên quan tới `cc_orders` và `cc_vouchers` nằm ở đây;
// màn hình dùng qua paymentRepositoryProvider.
//
// Ràng buộc phía server cần nhớ khi sửa file này (migration
// 20260801000000_secure_complete_payment_and_cc_orders.sql):
//   • Chỉ tạo được đơn của CHÍNH MÌNH và bắt buộc status = 'pending'.
//     Client không được tự khai một đơn là 'paid'.
//   • Chỉ sửa được đơn khi chưa 'paid'.
//   • complete_payment chỉ cho người dùng thường hoàn tất đơn 0đ của mình.
//     Đơn có tiền phải do webhook ngân hàng xác nhận.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/wr_payment.dart';

/// Trạng thái một đơn hàng đang theo dõi.
class WrOrder {
  const WrOrder({
    required this.id,
    required this.code,
    required this.status,
    required this.originalAmount,
    required this.finalAmount,
    this.discountAmount = 0,
    this.voucherId,
    this.expiresAt,
  });

  final String id;
  final String code;

  /// 'pending' | 'paid' | 'expired' | 'cancelled'
  final String status;
  final num originalAmount;
  final num finalAmount;
  final num discountAmount;
  final String? voucherId;
  final DateTime? expiresAt;

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';

  /// Đơn 0đ (voucher giảm 100%) — không cần QR, tự hoàn tất được.
  bool get isFree => finalAmount <= 0;

  WrOrder copyWith({
    String? status,
    num? finalAmount,
    num? discountAmount,
    String? voucherId,
    bool clearVoucher = false,
  }) {
    return WrOrder(
      id: id,
      code: code,
      status: status ?? this.status,
      originalAmount: originalAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      voucherId: clearVoucher ? null : (voucherId ?? this.voucherId),
      expiresAt: expiresAt,
    );
  }

  factory WrOrder.fromJson(Map<String, dynamic> json) {
    return WrOrder(
      id: json['id'].toString(),
      code: json['order_code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      originalAmount: (json['original_amount'] as num?) ?? 0,
      finalAmount: (json['final_amount'] as num?) ?? 0,
      discountAmount: (json['discount_amount'] as num?) ?? 0,
      voucherId: json['voucher_id']?.toString(),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'].toString()),
    );
  }
}

/// Ném ra khi voucher không dùng được; [message] hiện thẳng cho người dùng.
class WrVoucherException implements Exception {
  const WrVoucherException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class PaymentRepository {
  /// Tạo đơn Premium ở trạng thái 'pending' và sinh mã `CNC…`.
  Future<WrOrder> createPremiumOrder({
    required String productId,
    required num amount,
    String currency = 'VND',
  });

  /// Đọc lại đơn để biết webhook đã xác nhận chưa.
  Future<WrOrder> getOrder(String orderId);

  /// Tra mã, kiểm tra hợp lệ, ghi voucher vào đơn và trả về đơn đã cập nhật.
  ///
  /// Ném [WrVoucherException] kèm lý do khi mã không dùng được.
  Future<WrOrder> applyVoucher({
    required WrOrder order,
    required String code,
    String? userRole,
    String? orgId,
  });

  /// Gỡ voucher, trả giá về nguyên gốc.
  Future<WrOrder> removeVoucher(WrOrder order);

  /// Lưu thông tin xuất hoá đơn vào đơn (chỉ khi đơn còn 'pending').
  Future<void> saveInvoiceInfo(String orderId, WrInvoiceForm form);

  /// Đánh dấu đơn hết hạn khi người dùng để quá cửa sổ thanh toán.
  Future<void> expireOrder(String orderId);

  /// Hoàn tất đơn 0đ. Chỉ dùng cho đơn miễn phí — đơn có tiền server sẽ từ chối.
  Future<void> completeFreeOrder(String orderId);
}

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------

class SupabasePaymentRepository implements PaymentRepository {
  SupabasePaymentRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('not authenticated');
    return user.id;
  }

  static const String _orderColumns =
      'id, order_code, status, original_amount, final_amount, '
      'discount_amount, voucher_id, expires_at';

  @override
  Future<WrOrder> createPremiumOrder({
    required String productId,
    required num amount,
    String currency = 'VND',
  }) async {
    final expiresAt = DateTime.now().toUtc().add(kPaymentWindow);

    // Hai nhịp giống hệt web: chèn trước để lấy id, rồi mới sinh mã từ id đó.
    // Mã đơn phải suy ra được từ id nên không thể biết trước lúc chèn.
    final row = await _client
        .from('cc_orders')
        .insert({
          'order_code': 'TEMP',
          'user_id': _uid, // cột TEXT, uid dạng chuỗi dùng thẳng được
          'product_type': kPremiumOrderProductType,
          'product_id': productId,
          'original_amount': amount,
          'final_amount': amount,
          'currency': currency,
          'status': 'pending',
          'expires_at': expiresAt.toIso8601String(),
        })
        .select(_orderColumns)
        .single();

    final order = WrOrder.fromJson(Map<String, dynamic>.from(row));
    final code = generateOrderCode(order.id);

    await _client
        .from('cc_orders')
        .update({'order_code': code}).eq('id', order.id);

    return WrOrder(
      id: order.id,
      code: code,
      status: order.status,
      originalAmount: order.originalAmount,
      finalAmount: order.finalAmount,
      discountAmount: order.discountAmount,
      voucherId: order.voucherId,
      expiresAt: order.expiresAt,
    );
  }

  @override
  Future<WrOrder> getOrder(String orderId) async {
    final row = await _client
        .from('cc_orders')
        .select(_orderColumns)
        .eq('id', orderId)
        .single();
    return WrOrder.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<WrOrder> applyVoucher({
    required WrOrder order,
    required String code,
    String? userRole,
    String? orgId,
  }) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) throw const WrVoucherException('Chưa nhập mã');

    final row = await _client
        .from('cc_vouchers')
        .select(
          'id, code, discount_type, discount_percent, discount_amount, '
          'is_active, valid_from, valid_to, max_uses, used_count, '
          'target_type, assigned_users, applicable_products',
        )
        .eq('code', trimmed.toUpperCase())
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

    if (row == null) {
      throw const WrVoucherException('Mã giảm giá không tồn tại');
    }

    final voucher = WrVoucher.fromJson(Map<String, dynamic>.from(row));
    final reason = validateVoucher(
      voucher,
      now: DateTime.now(),
      userId: _uid,
      userRole: userRole,
      orgId: orgId,
    );
    if (reason != null) throw WrVoucherException(reason);

    final discount = calculateVoucherDiscount(voucher, order.originalAmount);
    final finalAmount = order.originalAmount - discount;

    await _client.from('cc_orders').update({
      'voucher_id': voucher.id,
      'discount_amount': discount,
      'final_amount': finalAmount,
    }).eq('id', order.id);

    return order.copyWith(
      voucherId: voucher.id,
      discountAmount: discount,
      finalAmount: finalAmount,
    );
  }

  @override
  Future<WrOrder> removeVoucher(WrOrder order) async {
    await _client.from('cc_orders').update({
      'voucher_id': null,
      'discount_amount': 0,
      'final_amount': order.originalAmount,
    }).eq('id', order.id);

    return order.copyWith(
      clearVoucher: true,
      discountAmount: 0,
      finalAmount: order.originalAmount,
    );
  }

  @override
  Future<void> saveInvoiceInfo(String orderId, WrInvoiceForm form) async {
    // Chặn ở 'pending': đơn đã trả thì hàm sepay-invoice đã đọc thông tin rồi,
    // sửa nữa cũng không vào hoá đơn mà chỉ làm lệch dữ liệu.
    await _client
        .from('cc_orders')
        .update(form.toOrderPayload())
        .eq('id', orderId)
        .eq('status', 'pending');
  }

  @override
  Future<void> expireOrder(String orderId) async {
    await _client
        .from('cc_orders')
        .update({'status': 'expired'})
        .eq('id', orderId)
        .eq('status', 'pending');
  }

  @override
  Future<void> completeFreeOrder(String orderId) async {
    await _client.rpc('complete_payment', params: {'p_order_id': orderId});
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return SupabasePaymentRepository(Supabase.instance.client);
});
