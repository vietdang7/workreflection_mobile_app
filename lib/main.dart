import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/supabase/supabase_config.dart';
import 'features/profile/profile_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );

  // Read persisted locale before first frame so the app starts in the correct
  // language without a locale flash.
  final initialLocale = await readPersistedLocale();

  runApp(
    ProviderScope(
      overrides: [
        appLocaleProvider.overrideWith((ref) => initialLocale),
      ],
      child: const WrApp(),
    ),
  );
}
