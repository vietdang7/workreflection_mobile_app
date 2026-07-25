// Tests for WrEntitlement logic — 3-level gating (Task 5).
// TDD: free/premium/expired scenarios + 3 gating levels.
// Run: flutter test test/core/wr_entitlement_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_entitlement.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

void main() {
  // Helpers
  WrEntitlement freePlan() => WrEntitlement(plan: WrPlan.free);
  WrEntitlement activePremium() => WrEntitlement(plan: WrPlan.premium);
  WrEntitlement expiredPremium() => WrEntitlement(
        plan: WrPlan.premium,
        validUntil: DateTime.now().subtract(const Duration(days: 1)),
      );
  WrEntitlement futurePremium() => WrEntitlement(
        plan: WrPlan.premium,
        validUntil: DateTime.now().add(const Duration(days: 30)),
      );

  // ---------------------------------------------------------------------------
  // isPremium
  // ---------------------------------------------------------------------------
  group('isPremium', () {
    test('free plan returns false', () {
      expect(freePlan().isPremium, isFalse);
    });

    test('active premium (no expiry) returns true', () {
      expect(activePremium().isPremium, isTrue);
    });

    test('premium with future validUntil returns true', () {
      expect(futurePremium().isPremium, isTrue);
    });

    test('premium with past validUntil returns false (expired)', () {
      expect(expiredPremium().isPremium, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Level 1: Feature gating
  // ---------------------------------------------------------------------------
  group('Level 1 - canUseFeature', () {
    test('free user cannot use any premium feature', () {
      final e = freePlan();
      for (final f in WrPremiumFeature.values) {
        expect(e.canUseFeature(f), isFalse, reason: 'feature: $f');
      }
    });

    test('active premium user can use all features', () {
      final e = activePremium();
      for (final f in WrPremiumFeature.values) {
        expect(e.canUseFeature(f), isTrue, reason: 'feature: $f');
      }
    });

    test('expired premium user cannot use premium features (treated as free)', () {
      final e = expiredPremium();
      for (final f in WrPremiumFeature.values) {
        expect(e.canUseFeature(f), isFalse, reason: 'feature: $f');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Level 2: Content gating
  // ---------------------------------------------------------------------------
  group('Level 2 - canAccessPracticeStep', () {
    test('free user can access non-premium steps', () {
      expect(freePlan().canAccessPracticeStep(isPremiumStep: false), isTrue);
    });

    test('free user cannot access premium steps', () {
      expect(freePlan().canAccessPracticeStep(isPremiumStep: true), isFalse);
    });

    test('premium user can access all steps', () {
      final e = activePremium();
      expect(e.canAccessPracticeStep(isPremiumStep: false), isTrue);
      expect(e.canAccessPracticeStep(isPremiumStep: true), isTrue);
    });

    test('expired premium cannot access premium steps', () {
      expect(expiredPremium().canAccessPracticeStep(isPremiumStep: true), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Level 3: Quota gating — practice themes
  // ---------------------------------------------------------------------------
  group('Level 3 - practice theme quota', () {
    test('free user has max 3 active themes', () {
      expect(freePlan().maxActivePracticeThemes, 3);
    });

    test('premium user has unlimited (null) themes', () {
      expect(activePremium().maxActivePracticeThemes, isNull);
    });

    test('free user can enroll when activeCount < 3', () {
      expect(freePlan().canEnrollPracticeTheme(0), isTrue);
      expect(freePlan().canEnrollPracticeTheme(2), isTrue);
    });

    test('free user cannot enroll when activeCount == 3', () {
      expect(freePlan().canEnrollPracticeTheme(3), isFalse);
    });

    test('free user cannot enroll when activeCount > 3', () {
      expect(freePlan().canEnrollPracticeTheme(4), isFalse);
    });

    test('premium user can always enroll regardless of count', () {
      expect(activePremium().canEnrollPracticeTheme(0), isTrue);
      expect(activePremium().canEnrollPracticeTheme(10), isTrue);
      expect(activePremium().canEnrollPracticeTheme(100), isTrue);
    });

    test('expired premium treated as free for quota', () {
      expect(expiredPremium().canEnrollPracticeTheme(3), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Level 3: Quota gating — context documents
  // ---------------------------------------------------------------------------
  group('Level 3 - context document quota', () {
    test('free user has max 1 context document', () {
      expect(freePlan().maxContextDocuments, 1);
    });

    test('premium user has unlimited (null) context documents', () {
      expect(activePremium().maxContextDocuments, isNull);
    });

    test('free user can upload when currentCount == 0', () {
      expect(freePlan().canUploadContextDocument(0), isTrue);
    });

    test('free user cannot upload when currentCount >= 1', () {
      expect(freePlan().canUploadContextDocument(1), isFalse);
      expect(freePlan().canUploadContextDocument(5), isFalse);
    });

    test('premium user can always upload', () {
      expect(activePremium().canUploadContextDocument(0), isTrue);
      expect(activePremium().canUploadContextDocument(10), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // WrEntitlement.fromRecord factory
  // ---------------------------------------------------------------------------
  group('WrEntitlement.fromRecord', () {
    test('creates from free record', () {
      final record = WrEntitlementRecord(
        userId: 'u1',
        plan: WrPlan.free,
        validUntil: null,
        source: null,
        updatedAt: null,
      );
      final e = WrEntitlement.fromRecord(record);
      expect(e.isPremium, isFalse);
    });

    test('creates from premium record with future date', () {
      final record = WrEntitlementRecord(
        userId: 'u1',
        plan: WrPlan.premium,
        validUntil: DateTime.now().add(const Duration(days: 10)),
        source: 'stripe',
        updatedAt: null,
      );
      final e = WrEntitlement.fromRecord(record);
      expect(e.isPremium, isTrue);
    });
  });
}
