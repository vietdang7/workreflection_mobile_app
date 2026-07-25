// Tests cho wrEntitlementProvider.
// Run: flutter test test/features/wr_providers_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import '../support/fake_wr_intelligence_repository.dart';

/// Creates a container with fake repo AND a fixed userId so
/// the provider does not try to access Supabase.instance in tests.
ProviderContainer _makeContainer(
  FakeWrIntelligenceRepository fake, {
  String? userId = 'test-user',
}) {
  return ProviderContainer(
    overrides: [
      wrIntelligenceRepositoryProvider.overrideWithValue(fake),
      currentUserIdProvider.overrideWithValue(userId),
    ],
  );
}

void main() {
  group('wrEntitlementProvider', () {
    test('returns free when repository returns null (no record)', () async {
      final fake = FakeWrIntelligenceRepository();
      fake.seedEntitlement(null);
      final container = _makeContainer(fake);
      addTearDown(container.dispose);

      final result = await container.read(wrEntitlementProvider.future);
      expect(result.isPremium, isFalse);
      expect(result.plan, WrPlan.free);
    });

    test('returns free when repository throws', () async {
      final fake = FakeWrIntelligenceRepository();
      fake.nextError = Exception('DB error');
      final container = _makeContainer(fake);
      addTearDown(container.dispose);

      final result = await container.read(wrEntitlementProvider.future);
      expect(result.isPremium, isFalse);
      expect(result.plan, WrPlan.free);
    });

    test('returns premium when record has active premium plan', () async {
      final fake = FakeWrIntelligenceRepository();
      fake.seedEntitlement(WrEntitlementRecord(
        userId: 'user-1',
        plan: WrPlan.premium,
        validUntil: DateTime.now().add(const Duration(days: 30)),
      ));
      final container = _makeContainer(fake);
      addTearDown(container.dispose);

      final result = await container.read(wrEntitlementProvider.future);
      expect(result.isPremium, isTrue);
    });

    test('returns free when premium record is expired', () async {
      final fake = FakeWrIntelligenceRepository();
      fake.seedEntitlement(WrEntitlementRecord(
        userId: 'user-1',
        plan: WrPlan.premium,
        validUntil: DateTime.now().subtract(const Duration(days: 1)),
      ));
      final container = _makeContainer(fake);
      addTearDown(container.dispose);

      final result = await container.read(wrEntitlementProvider.future);
      expect(result.isPremium, isFalse);
    });

    test('returns free when premium plan has no expiry (perpetual)', () async {
      final fake = FakeWrIntelligenceRepository();
      fake.seedEntitlement(WrEntitlementRecord(
        userId: 'user-1',
        plan: WrPlan.premium,
        validUntil: null,
      ));
      final container = _makeContainer(fake);
      addTearDown(container.dispose);

      final result = await container.read(wrEntitlementProvider.future);
      expect(result.isPremium, isTrue);
    });
  });
}
