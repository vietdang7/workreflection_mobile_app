import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract interface so tests can inject a fake without touching Supabase.
abstract class AuthRepository {
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password, String displayName);
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> changePassword(String newPassword);
  Future<void> deleteAccount();
}

/// Live implementation backed by Supabase.
class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      // BA khoá cho cùng một cái tên, và cả ba đều cần thiết:
      //
      //   full_name    trigger `handle_new_user` bên Postgres đọc đúng khoá này
      //                (rồi mới tới `name`) để dựng `cc_profiles.full_name`.
      //                Thiếu nó thì hàng cc_profiles của mọi tài khoản tạo từ
      //                app di động có tên NULL — đã kiểm chứng trên DB thật
      //                (khách báo "app chào bằng email", họp 26_1).
      //   name         một số nơi bên web đọc khoá này.
      //   display_name khoá app di động vẫn dùng; giữ để bản cũ đang chạy trên
      //                máy người dùng không mất tên sau khi cập nhật.
      data: {
        'full_name': displayName,
        'name': displayName,
        'display_name': displayName,
      },
    );
    // Upsert profile row (best-effort; wr_mobile_profiles may not exist yet in dev)
    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      await _client.from('wr_mobile_profiles').upsert({
        'user_id': uid,
        'display_name': displayName,
        'language': 'vi',
      });
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'app.workreflection.mobile://login-callback',
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Sends a password-reset email. The link will redirect the user to
  /// the production web reset-password page (https://workreflection.app/reset-password)
  /// which is the same URL used by the web's send-email edge function.
  @override
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://workreflection.app/reset-password',
    );
  }

  /// Updates the current user's password.
  /// Requires an active session; throws if session is expired.
  @override
  Future<void> changePassword(String newPassword) async {
    final response = await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    if (response.user == null) {
      throw Exception('changePassword: no user returned');
    }
  }

  /// Xoá vĩnh viễn tài khoản đang đăng nhập và toàn bộ dữ liệu của nó.
  ///
  /// App Store Guideline 5.1.1(v) bắt buộc phải xoá được ngay trong app.
  ///
  /// Việc xoá nằm ở RPC `wr_delete_own_account` (migration
  /// 20260805140000): hàm đó chạy `security definer`, chỉ đụng tới
  /// `auth.uid()` của phiên gọi nên không có đường xoá nhầm tài khoản khác.
  ///
  /// Gọi `signOut` ngay sau đó: phiên vẫn còn access token hợp lệ tới lúc hết
  /// hạn dù user đã biến mất, để nguyên thì app tưởng còn đăng nhập và mọi
  /// truy vấn tiếp theo đều lỗi khó hiểu.
  @override
  Future<void> deleteAccount() async {
    await _client.rpc<void>('wr_delete_own_account');
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Token của tài khoản vừa xoá có thể bị từ chối — không sao, dữ liệu đã
      // xoá xong rồi. Đừng ném lỗi làm người dùng tưởng xoá hụt.
    }
  }
}

/// Riverpod provider — can be overridden in tests.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(Supabase.instance.client);
});
