import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/data/seed_service.dart';
import 'core/router/app_router.dart';
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

  @override
  void initState() {
    super.initState();
    // Listen for OAuth deep-link session arrivals (Google Sign-In).
    // ensureSeeded is also called after email signUp/signIn in auth_screen.dart;
    // this listener handles the OAuth case where the session arrives asynchronously
    // via a deep link and auth_screen.dart's _submit() path is not taken.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
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
