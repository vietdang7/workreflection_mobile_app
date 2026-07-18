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
      data: {'display_name': displayName},
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
}

/// Riverpod provider — can be overridden in tests.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(Supabase.instance.client);
});
