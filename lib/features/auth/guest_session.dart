// Phiên khách: dùng app trước, đăng ký sau (mockup v47, chốt 06/10/2026).
//
// Khách là một user Supabase ẩn danh thật (`is_anonymous = true`), không phải
// một chế độ giả lập trong app. Mọi bảng `wr_*` ghi theo `auth.uid()` như user
// thường, RLS chạy y nguyên. Khi khách lưu hành trình, email + mật khẩu được
// gắn vào CHÍNH user đó (`AuthRepository.attachEmail`), nên không có bước
// chuyển dữ liệu nào.
//
// Phía DB: `cc_profiles.email` là NOT NULL, nên trigger tạo hồ sơ web bỏ qua
// user ẩn danh và chỉ tạo hàng khi họ gắn email
// (migration 20261006100000_wr_anonymous_guest_profiles).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/app_router.dart';
import '../wr/wr_providers.dart' show currentUserEmailProvider;
import 'data/auth_repository.dart';

/// Người đang dùng là khách (chưa gắn email).
///
/// Đọc lại khi đổi người (nằm trong `userIdentityProviders`) và khi khách vừa
/// lưu hành trình — cùng `user_id` nên phải invalidate tay, xem
/// [markGuestSaved].
final isGuestProvider = Provider<bool>((ref) {
  try {
    return Supabase.instance.client.auth.currentUser?.isAnonymous ?? false;
  } catch (_) {
    return false;
  }
});

/// Có phiên đăng nhập nào chưa (khách hay tài khoản đều tính). Là một hàm để
/// mỗi lần gọi đọc trạng thái mới, và để test thay được.
final hasAuthSessionProvider = Provider<bool Function()>((ref) {
  return () {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  };
});

/// Mở phiên khách nếu máy chưa có phiên nào.
///
/// Chờ tới khi `app.dart` xử lý xong sự kiện đăng nhập rồi mới trả về. Ở đó
/// app XOÁ mọi provider của người dùng cũ (`resetUserScopedProviders`) — nếu
/// màn gọi hàm này ghi cảm xúc vừa chọn vào provider trước lúc đó, lần xoá
/// sẽ cuốn mất nó. Không nghe được sự kiện (test, hay app.dart chưa gắn) thì
/// thôi chờ sau [settle].
Future<void> ensureGuestSession(
  WidgetRef ref, {
  Duration settle = const Duration(seconds: 3),
}) async {
  if (ref.read(hasAuthSessionProvider)()) return;
  final notifier = ref.read(authChangeNotifierProvider);
  final handled = Completer<void>();
  void onAuth() {
    if (!handled.isCompleted) handled.complete();
  }

  notifier.addListener(onAuth);
  try {
    await ref.read(authRepositoryProvider).signInAnonymously();
    await handled.future.timeout(settle, onTimeout: () {});
  } finally {
    notifier.removeListener(onAuth);
  }
}

/// Sau khi khách gắn email: cùng `user_id` nên app.dart không coi là đổi
/// người, phải tự đọc lại hai provider danh tính.
void markGuestSaved(WidgetRef ref) {
  ref.invalidate(isGuestProvider);
  ref.invalidate(currentUserEmailProvider);
}

// ---------------------------------------------------------------------------
// Sheet "Lưu lại hành trình" chỉ tự hiện MỘT lần cho mỗi khách
// ---------------------------------------------------------------------------

String _saveSheetKey(String uid) => 'wr_save_sheet_seen_$uid';

/// Khách này đã thấy sheet chưa (theo `user_id`, để khách mới trên cùng máy
/// vẫn được mời).
Future<bool> saveSheetSeen(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_saveSheetKey(uid)) ?? false;
}

Future<void> markSaveSheetSeen(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_saveSheetKey(uid), true);
}
