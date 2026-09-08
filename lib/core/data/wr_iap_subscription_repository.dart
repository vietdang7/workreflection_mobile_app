// Đọc thuê bao App Store của chính người đang đăng nhập.
//
// Tách khỏi `wr_iap_repository.dart` có chủ ý: file kia nói chuyện với StoreKit
// (hỏi giá, mở hộp thoại mua), file này nói chuyện với Supabase. Gộp lại thì
// mọi test về lời nhắc gia hạn đều phải dựng một cái kho ứng dụng giả.
//
// Bảng `wr_iap_transactions` cho chủ sở hữu SELECT hàng của mình và KHÔNG cho
// ghi — ghi được vào đó là tự cấp Premium. Nên ở đây chỉ có đúng một phép đọc.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/wr_iap_renewal.dart';

abstract class WrIapSubscriptionRepository {
  /// Thuê bao gần nhất của người dùng, hoặc `null` khi chưa mua bao giờ.
  Future<WrIapSubscription?> fetchSubscription(String userId);
}

final wrIapSubscriptionRepositoryProvider =
    Provider<WrIapSubscriptionRepository>((ref) {
  return SupabaseWrIapSubscriptionRepository(Supabase.instance.client);
});

class SupabaseWrIapSubscriptionRepository
    implements WrIapSubscriptionRepository {
  const SupabaseWrIapSubscriptionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<WrIapSubscription?> fetchSubscription(String userId) async {
    // Sắp theo `expires_at` giảm dần rồi lấy một: một tài khoản có thể có nhiều
    // hàng nếu từng mua gói tháng rồi mua tiếp gói năm — hàng còn hạn xa nhất
    // mới là hàng quyết định quyền, và cũng là hàng đáng nhắc.
    final rows = await _client
        .from('wr_iap_transactions')
        .select()
        .eq('user_id', userId)
        .order('expires_at', ascending: false, nullsFirst: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return WrIapSubscription.fromJson(rows.first);
  }
}
