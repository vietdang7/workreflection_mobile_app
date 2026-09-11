import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/l10n/wr_tr.dart';
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

  // Phần WorkReflection không đi qua `AppLocalizations` mà qua `tr()`, và `tr()`
  // đọc một biến toàn cục. Đặt ở đây, TRƯỚC `runApp`, để không có khung hình
  // nào dựng bằng ngôn ngữ cũ rồi mới nhảy sang ngôn ngữ đúng.
  wrSetLocale(initialLocale);

  runApp(
    ProviderScope(
      overrides: [
        appLocaleProvider.overrideWith((ref) => initialLocale),
      ],
      child: const WrApp(),
    ),
  );
}
