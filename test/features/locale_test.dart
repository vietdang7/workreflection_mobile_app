import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';

void main() {
  group('readPersistedLocale', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns "vi" when no persisted value', () async {
      final locale = await readPersistedLocale();
      expect(locale, 'vi');
    });

    test('returns "en" when app_language is "en"', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'en'});
      final locale = await readPersistedLocale();
      expect(locale, 'en');
    });

    test('returns "vi" when app_language is "vi"', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'vi'});
      final locale = await readPersistedLocale();
      expect(locale, 'vi');
    });

    test('returns "vi" for unknown locale value', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'fr'});
      // Only 'vi' and 'en' are supported; unknown falls back to 'vi'.
      final locale = await readPersistedLocale();
      expect(locale, 'vi');
    });
  });

  group('appLocaleProvider initialized from SharedPreferences', () {
    test('ProviderScope override sets locale from persisted value', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'en'});
      final initialLocale = await readPersistedLocale();

      final container = ProviderContainer(overrides: [
        appLocaleProvider.overrideWith((ref) => initialLocale),
      ]);
      addTearDown(container.dispose);

      expect(container.read(appLocaleProvider), 'en');
    });
  });
}
