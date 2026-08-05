// Tests cho wrEntitlementProvider.
// Run: flutter test test/features/wr_providers_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_pricing.dart';
import '../support/fake_wr_intelligence_repository.dart';
import '../support/fake_repository.dart';

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

  // Khách chốt 2026-08-01: "nếu trên web role Premium thì trên app cũng Premium
  // luôn". Hai nguồn được HỢP lúc đọc — không đồng bộ dữ liệu giữa hai bảng.
  group('wrEntitlementProvider — Premium chung với web', () {
    ProviderContainer makeWith({
      required String? webRole,
      WrEntitlementRecord? mobileRecord,
    }) {
      final intel = FakeWrIntelligenceRepository()..seedEntitlement(mobileRecord);
      final repo = FakeWrRepository()
        ..seedCcProfile({'full_name': 'Y', 'email': 'y@y.com', 'role': webRole});
      return ProviderContainer(
        overrides: [
          wrIntelligenceRepositoryProvider.overrideWithValue(intel),
          wrRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('test-user'),
        ],
      );
    }

    test('role premium trên web mở khoá app dù wr_entitlements rỗng', () async {
      final container = makeWith(webRole: 'premium', mobileRecord: null);
      addTearDown(container.dispose);

      final result = await container.read(wrEntitlementProvider.future);
      expect(result.isPremium, isTrue);
    });

    test('role admin cũng mở khoá', () async {
      final container = makeWith(webRole: 'admin', mobileRecord: null);
      addTearDown(container.dispose);

      expect((await container.read(wrEntitlementProvider.future)).isPremium, isTrue);
    });

    test('role thường + không có gói mobile = miễn phí', () async {
      final container = makeWith(webRole: 'user', mobileRecord: null);
      addTearDown(container.dispose);

      expect((await container.read(wrEntitlementProvider.future)).isPremium, isFalse);
    });

    test('gói mobile vẫn có hiệu lực khi web không phải Premium', () async {
      // Hai nguồn là HOẶC: mua trong app cũng mở khoá, không cần role web.
      final container = makeWith(
        webRole: 'user',
        mobileRecord: WrEntitlementRecord(
          userId: 'test-user',
          plan: WrPlan.premium,
          validUntil: DateTime.now().add(const Duration(days: 30)),
        ),
      );
      addTearDown(container.dispose);

      expect((await container.read(wrEntitlementProvider.future)).isPremium, isTrue);
    });

    test('Premium web không bị hạ xuống bởi gói mobile đã hết hạn', () async {
      final container = makeWith(
        webRole: 'premium',
        mobileRecord: WrEntitlementRecord(
          userId: 'test-user',
          plan: WrPlan.premium,
          validUntil: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      addTearDown(container.dispose);

      expect((await container.read(wrEntitlementProvider.future)).isPremium, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Công tắc Premium nghiệm thu — đường đi thật, qua SharedPreferences.
  //
  // Lỗi phải chặn: công tắc lưu theo MÁY. Chủ sản phẩm bật một lần, rồi bất kỳ
  // ai đăng nhập trên máy đó cũng thành Premium — kể cả khi cc_profiles.role
  // của họ là 'free'.
  // -------------------------------------------------------------------------
  group('premiumOverrideProvider — theo tài khoản, không theo máy', () {
    ProviderContainer containerFor(String? email) {
      final c = ProviderContainer(
        overrides: [
          currentUserEmailProvider.overrideWithValue(email),
          currentUserIdProvider.overrideWithValue('u1'),
          wrIntelligenceRepositoryProvider.overrideWithValue(
            FakeWrIntelligenceRepository()..seedEntitlement(null),
          ),
          ccProfileProvider.overrideWith((ref) async => {'role': 'free'}),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('chủ công tắc bật rồi mở lại app thì vẫn còn', () async {
      SharedPreferences.setMockInitialValues({
        'wr_dev_premium_override': true,
        'wr_dev_premium_override_owner': 'thedangs7@gmail.com',
      });
      final c = containerFor('thedangs7@gmail.com');

      expect(c.read(premiumOverrideProvider), isNull, reason: 'chưa đọc xong');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(premiumOverrideProvider), isTrue);
      expect((await c.read(wrEntitlementProvider.future)).isPremium, isTrue);
    });

    test('người khác đăng nhập trên máy đã bật: KHÔNG Premium', () async {
      SharedPreferences.setMockInitialValues({
        'wr_dev_premium_override': true,
        'wr_dev_premium_override_owner': 'thedangs7@gmail.com',
      });
      final c = containerFor('nguoila@example.com');
      await Future<void>.delayed(Duration.zero);

      expect(c.read(premiumOverrideProvider), isNull);
      expect(c.read(canTogglePremiumProvider), isFalse,
          reason: 'không được thấy cả nút bật/tắt');
      expect((await c.read(wrEntitlementProvider.future)).isPremium, isFalse);

      // Và cờ bị dọn khỏi máy, không nằm chờ ai đó nữa.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('wr_dev_premium_override'), isFalse);
    });

    test('cờ của bản cũ (không ghi chủ) không cấp Premium cho ai', () async {
      SharedPreferences.setMockInitialValues({
        'wr_dev_premium_override': true,
      });
      final c = containerFor('thedangs7@gmail.com');
      await Future<void>.delayed(Duration.zero);

      expect(c.read(premiumOverrideProvider), isNull);
    });

    test('người không được phép gọi set() cũng không bật được', () async {
      SharedPreferences.setMockInitialValues({});
      final c = containerFor('nguoila@example.com');
      await c.read(premiumOverrideProvider.notifier).set(true);

      expect(c.read(premiumOverrideProvider), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('wr_dev_premium_override'), isFalse);
    });

    test('bật xong thì ghi kèm email chủ công tắc', () async {
      SharedPreferences.setMockInitialValues({});
      final c = containerFor('thedangs7@gmail.com');
      await c.read(premiumOverrideProvider.notifier).set(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('wr_dev_premium_override'), isTrue);
      expect(prefs.getString('wr_dev_premium_override_owner'),
          'thedangs7@gmail.com');
    });
  });

  group('wrPremiumPricingProvider', () {
    // Gói app 499k, KHÔNG phải gói web 249k (khách chốt 2026-08-04).
    test('lấy giá gói app từ repo — 499k, không gạch ngang', () async {
      final repo = FakeWrRepository();
      final container = ProviderContainer(
        overrides: [wrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final p = await container.read(wrPremiumPricingProvider.future);
      expect(p.currentLabel, '499.000đ');
      expect(p.originalLabel, isNull);
      expect(p.discountPercent, 0);
    });

    test('repo hỏng thì rơi về giá mặc định chứ không ném', () async {
      final repo = FakeWrRepository()
        ..premiumPricingError = Exception('network');
      final container = ProviderContainer(
        overrides: [wrRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final p = await container.read(wrPremiumPricingProvider.future);
      expect(p.currentPrice, kPremiumFallbackPrice);
    });
  });
}
