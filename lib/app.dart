import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/data/seed_service.dart';
import 'core/data/user_session_scope.dart';
import 'core/router/app_router.dart';
import 'core/theme/wr_text_scale.dart';
import 'core/theme/wr_theme.dart';
import 'features/profile/profile_providers.dart';
import 'l10n/app_localizations.dart';

class WrApp extends ConsumerStatefulWidget {
  const WrApp({super.key});

  @override
  ConsumerState<WrApp> createState() => _WrAppState();
}

class _WrAppState extends ConsumerState<WrApp> {
  StreamSubscription<AuthState>? _authSub;

  /// Ai đang đăng nhập ở lần sự kiện trước. Dùng để tách "đổi tài khoản" khỏi
  /// "vẫn người đó, chỉ làm mới token" — trường hợp sau không cần xoá cache.
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _lastUserId = Supabase.instance.client.auth.currentUser?.id;
    // Listen for OAuth deep-link session arrivals (Google Sign-In).
    // ensureSeeded is also called after email signUp/signIn in auth_screen.dart;
    // this listener handles the OAuth case where the session arrives asynchronously
    // via a deep link and auth_screen.dart's _submit() path is not taken.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        // Đổi người (kể cả đăng xuất → null) thì xoá cache của người cũ NGAY,
        // trước khi báo router chuyển màn. Làm sau sẽ trễ đúng một khung hình
        // — vừa đủ để màn Home kịp vẽ tên tài khoản trước đó.
        final newUserId = data.session?.user.id;
        if (isUserSwitch(previous: _lastUserId, next: newUserId)) {
          _lastUserId = newUserId;
          resetUserScopedProviders(ref.invalidate);
        }

        // Notify the router so redirect guard re-runs on every auth event
        // (sign-in via Google OAuth deep-link, sign-out, token refresh, etc.).
        ref.read(authChangeNotifierProvider).notify();

        if (data.event == AuthChangeEvent.signedIn) {
          try {
            await ref.read(seedServiceProvider).ensureSeeded();
          } catch (_) {
            // Seeding is best-effort; do not crash the app.
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final localeCode = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'WorkReflection',
      theme: wrTheme(),
      builder: wrTextScaleBuilder,
      routerConfig: router,
      locale: Locale(localeCode),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
