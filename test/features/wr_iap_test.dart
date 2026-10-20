// Mua Premium bằng In-App Purchase của kho ứng dụng.
//
// Vì sao phải có test: App Store từ chối bản 1.0 (6) ngày 06/09/2026 theo
// Guideline 3.1.1 vì app cho dùng Premium mua từ web mà gói đó không mua được
// trong app. Bản nộp lại phải bán được bằng IAP, và có ba thứ Apple bắt buộc mà
// thiếu thứ nào cũng là một lý do từ chối riêng: giá lấy từ StoreKit, nút khôi
// phục giao dịch, và liên kết Điều khoản + Chính sách quyền riêng tư.
//
// Một luật nữa được khoá ở đây, và nó là luật về TIỀN CỦA NGƯỜI DÙNG: phải xác
// minh biên lai với máy chủ XONG rồi mới báo "đã giao hàng" cho kho ứng dụng.
// Làm ngược lại thì giao dịch bị đóng trong khi quyền chưa kịp ghi, và kho ứng
// dụng sẽ không bao giờ đẩy lại giao dịch đó nữa — người dùng mất tiền.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workreflection_mobile/core/data/wr_iap_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_entitlement.dart';
import 'package:workreflection_mobile/core/logic/wr_iap_catalog.dart';
import 'package:workreflection_mobile/core/logic/wr_iap_renewal.dart';
import 'package:workreflection_mobile/core/logic/wr_pricing.dart';
import 'package:workreflection_mobile/core/logic/wr_store_policy.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/iap_providers.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_paywall_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

const _userId = '894bdba6-c41f-4dde-812b-2329c3bba0ac';

/// Giá VND của `cc_products` — dùng để khẳng định bản IAP KHÔNG dán số này lên
/// nút mua.
const _webPlans = [
  WrPremiumPricing(
    currentPrice: 499000,
    productId: 'prod-year',
    durationDays: 365,
  ),
];

const _offers = [
  WrIapOffer(
    id: kIapYearlyProductId,
    title: 'Premium 1 năm',
    description: 'Mở toàn bộ phần trả phí.',
    // Giá StoreKit trả về — cố ý KHÁC 499.000đ để phân biệt được hai nguồn.
    priceLabel: '449.000 ₫',
    rawPrice: 449000,
    currencyCode: 'VND',
    durationDays: 365,
  ),
  WrIapOffer(
    id: kIapMonthlyProductId,
    title: 'Premium 1 tháng',
    description: 'Dùng thử một tháng.',
    priceLabel: '69.000 ₫',
    rawPrice: 69000,
    currencyCode: 'VND',
    durationDays: 30,
  ),
];

/// Repository giả, ghi lại thứ tự các lời gọi.
class _FakeIapRepository implements WrIapRepository {
  _FakeIapRepository({
    this.offers = _offers,
    this.available = true,
    this.verifyFails = false,
  });

  final List<WrIapOffer> offers;
  final bool available;

  /// Máy chủ từ chối biên lai.
  final bool verifyFails;

  final List<String> calls = [];
  final StreamController<WrIapPurchase> controller =
      StreamController<WrIapPurchase>.broadcast();

  @override
  Future<bool> isStoreAvailable() async => available;

  @override
  Future<List<WrIapOffer>> fetchOffers() async => offers;

  @override
  Stream<WrIapPurchase> get purchaseUpdates => controller.stream;

  @override
  Future<void> buy({required String productId, required String userId}) async {
    calls.add('buy:$productId:$userId');
  }

  @override
  Future<void> restore({required String userId}) async {
    calls.add('restore:$userId');
  }

  @override
  Future<void> finish(WrIapPurchase purchase) async {
    calls.add('finish:${purchase.productId}');
  }

  @override
  Future<WrEntitlementRecord> verify(WrIapPurchase purchase) async {
    calls.add('verify:${purchase.productId}');
    if (verifyFails) {
      throw const WrIapException('Chưa xác nhận được giao dịch.');
    }
    return WrEntitlementRecord(
      userId: _userId,
      plan: WrPlan.premium,
      validUntil: DateTime.now().add(const Duration(days: 365)),
      source: 'apple_iap',
    );
  }
}

WrIapPurchase _purchase({
  WrIapStatus status = WrIapStatus.purchased,
  String productId = kIapYearlyProductId,
  String? errorMessage,
}) => WrIapPurchase(
  productId: productId,
  status: status,
  serverVerificationData: 'jws...',
  pendingComplete: true,
  purchaseId: 'tx-1',
  errorMessage: errorMessage,
);

ProviderContainer _container(_FakeIapRepository repo) {
  final c = ProviderContainer(
    overrides: [
      wrStorePolicyProvider.overrideWithValue(WrStorePolicy.appStore),
      wrIapRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue(_userId),
      wrEntitlementProvider.overrideWith(
        (ref) async => WrEntitlement(plan: WrPlan.free),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Widget _paywall(
  _FakeIapRepository repo, {
  WrStorePolicy policy = WrStorePolicy.appStore,
  bool premium = false,
  WrIapSubscription? subscription,
}) => ProviderScope(
  overrides: [
    wrStorePolicyProvider.overrideWithValue(policy),
    wrIapSubscriptionProvider.overrideWith((ref) async => subscription),
    wrIapRepositoryProvider.overrideWithValue(repo),
    currentUserIdProvider.overrideWithValue(_userId),
    wrPremiumPlansProvider.overrideWith((ref) async => _webPlans),
    wrEntitlementProvider.overrideWith(
      (ref) async =>
          WrEntitlement(plan: premium ? WrPlan.premium : WrPlan.free),
    ),
  ],
  child: MaterialApp(
    builder: wrTextScaleBuilder,
    home: const WrPaywallScreen(),
  ),
);

void main() {
  group('Danh mục gói', () {
    test('tra được theo product id, id lạ thì trả null chứ không ném', () {
      expect(wrIapProductById(kIapYearlyProductId)?.durationDays, 365);
      expect(wrIapProductById(kIapMonthlyProductId)?.durationDays, 30);
      // Giao dịch treo của bản build cũ đi qua purchaseStream — ném ở đây là
      // chết app ngay lúc mở, vì luồng đó chạy tự động.
      expect(wrIapProductById('com.cu.khong.con.ban'), isNull);
      expect(wrIapProductById(null), isNull);
      expect(isWrIapProductId('com.cu.khong.con.ban'), isFalse);
    });

    test('product id mang tiền tố bundle id của app', () {
      for (final p in kWrIapProducts) {
        expect(p.id, startsWith(kIosBundleId));
      }
    });

    test('không có hai gói trùng id', () {
      expect(kWrIapProductIds.length, kWrIapProducts.length);
    });

    test('mã gửi kho Google Play vừa giới hạn 40 ký tự và đổi ngược được', () {
      for (final store in WrIapStore.values) {
        for (final p in kWrIapProducts) {
          final storeId = store.storeProductId(p.id);
          expect(wrIapCanonicalProductId(storeId), p.id);
          if (store == WrIapStore.googlePlay) {
            expect(storeId.length, lessThanOrEqualTo(40), reason: storeId);
          }
        }
      }
      expect(
        WrIapStore.googlePlay.storeProductId(kIapMonthlyProductId),
        kIapMonthlyPlayProductId,
      );
      expect(
        WrIapStore.appStore.storeProductId(kIapMonthlyProductId),
        kIapMonthlyProductId,
      );
    });
  });

  group('Nhãn thời hạn', () {
    test('quy ra chữ đọc được', () {
      expect(_offers[0].durationSuffix, 'năm');
      expect(_offers[1].durationSuffix, 'tháng');
    });
  });

  group('Luồng mua', () {
    test('xác minh với máy chủ XONG rồi mới đóng giao dịch', () async {
      final repo = _FakeIapRepository();
      final c = _container(repo);
      c.read(wrIapControllerProvider);

      repo.controller.add(_purchase());
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls, [
        'verify:$kIapYearlyProductId',
        'finish:$kIapYearlyProductId',
      ]);
      expect(c.read(wrIapControllerProvider).phase, WrIapPhase.done);
    });

    test('máy chủ từ chối thì KHÔNG đóng giao dịch', () async {
      final repo = _FakeIapRepository(verifyFails: true);
      final c = _container(repo);
      c.read(wrIapControllerProvider);

      repo.controller.add(_purchase());
      await Future<void>.delayed(Duration.zero);

      // Đóng ở đây là người dùng mất tiền: kho ứng dụng sẽ không đẩy lại giao
      // dịch nữa, mà quyền thì chưa ghi được.
      expect(repo.calls, ['verify:$kIapYearlyProductId']);
      expect(repo.calls, isNot(contains('finish:$kIapYearlyProductId')));
      expect(c.read(wrIapControllerProvider).phase, WrIapPhase.idle);
      expect(c.read(wrIapControllerProvider).error, isNotNull);
    });

    test('giao dịch khôi phục cũng đi qua xác minh', () async {
      final repo = _FakeIapRepository();
      final c = _container(repo);
      c.read(wrIapControllerProvider);

      repo.controller.add(_purchase(status: WrIapStatus.restored));
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls.first, 'verify:$kIapYearlyProductId');
      expect(c.read(wrIapControllerProvider).phase, WrIapPhase.done);
    });

    test('người dùng huỷ thì không báo lỗi', () async {
      final repo = _FakeIapRepository();
      final c = _container(repo);
      c.read(wrIapControllerProvider);

      repo.controller.add(_purchase(status: WrIapStatus.canceled));
      await Future<void>.delayed(Duration.zero);

      // Huỷ là một lựa chọn hợp lệ. Báo đỏ vào mặt người vừa đổi ý là thô lỗ.
      expect(c.read(wrIapControllerProvider).error, isNull);
      expect(c.read(wrIapControllerProvider).phase, WrIapPhase.idle);
      expect(repo.calls, isEmpty);
    });

    test('giao dịch lỗi vẫn phải được đóng', () async {
      final repo = _FakeIapRepository();
      final c = _container(repo);
      c.read(wrIapControllerProvider);

      repo.controller.add(
        _purchase(status: WrIapStatus.error, errorMessage: 'Thẻ bị từ chối'),
      );
      await Future<void>.delayed(Duration.zero);

      // Không đóng thì iOS dựng lại giao dịch mỗi lần mở app.
      expect(repo.calls, ['finish:$kIapYearlyProductId']);
      expect(c.read(wrIapControllerProvider).error, 'Thẻ bị từ chối');
    });

    test('chờ duyệt (Ask to Buy) không phải là thất bại', () async {
      final repo = _FakeIapRepository();
      final c = _container(repo);
      c.read(wrIapControllerProvider);

      repo.controller.add(_purchase(status: WrIapStatus.pending));
      await Future<void>.delayed(Duration.zero);

      expect(
        c.read(wrIapControllerProvider).phase,
        WrIapPhase.awaitingApproval,
      );
      expect(c.read(wrIapControllerProvider).error, isNull);
    });

    test('mua thì gửi kèm id người dùng làm appAccountToken', () async {
      final repo = _FakeIapRepository();
      final c = _container(repo);

      await c.read(wrIapControllerProvider.notifier).buy(kIapYearlyProductId);

      // Không có id này thì máy chủ không biết biên lai thuộc về ai.
      expect(repo.calls, contains('buy:$kIapYearlyProductId:$_userId'));
    });

    // LỖI THẬT, lộ ở lần chạy thử sandbox đầu tiên 11/09/2026.
    //
    // Công tắc Premium nội bộ nằm CAO HƠN mọi nguồn quyền khác trong
    // `wrEntitlementProvider`. Muốn tới được Paywall để mua thử, chủ sản phẩm
    // phải gạt nó sang "ép miễn phí" — rồi mua xong, chính cái công tắc đó nuốt
    // trọn gói vừa mua: Apple đã trừ tiền, `wr_entitlements` đã ghi
    // `plan = premium / source = apple_iap`, mà app vẫn hiện Free.
    //
    // Luồng QR đã xử lý đúng từ đầu (`wr_payment_screen._onPaid`); luồng App
    // Store thì quên. Mua thật phải thắng công cụ thử nghiệm.
    test(
      'mua thành công thì GỠ công tắc ép miễn phí của tài khoản nội bộ',
      () async {
        SharedPreferences.setMockInitialValues({
          'wr_dev_premium_override': false,
          'wr_dev_premium_override_owner': 'thedangs7@gmail.com',
        });
        final repo = _FakeIapRepository();
        final c = ProviderContainer(
          overrides: [
            wrStorePolicyProvider.overrideWithValue(WrStorePolicy.appStore),
            wrIapRepositoryProvider.overrideWithValue(repo),
            currentUserIdProvider.overrideWithValue(_userId),
            currentUserEmailProvider.overrideWithValue('thedangs7@gmail.com'),
          ],
        );
        addTearDown(c.dispose);

        // Đọc một lần để notifier được dựng và bắt đầu `load()`, rồi mới nhả
        // nhịp cho nó đọc xong SharedPreferences.
        c.read(premiumOverrideProvider);
        c.read(wrIapControllerProvider);
        await Future<void>.delayed(Duration.zero);
        expect(c.read(canTogglePremiumProvider), isTrue);
        expect(
          c.read(premiumOverrideProvider),
          isFalse,
          reason: 'đang ép miễn phí — đúng trạng thái để mua thử',
        );

        repo.controller.add(_purchase());
        await Future<void>.delayed(Duration.zero);

        expect(c.read(wrIapControllerProvider).phase, WrIapPhase.done);
        expect(
          c.read(premiumOverrideProvider),
          isNull,
          reason: 'công tắc phải trả về "dùng gói thật"',
        );
      },
    );

    test('mua hỏng thì KHÔNG đụng tới công tắc', () async {
      SharedPreferences.setMockInitialValues({
        'wr_dev_premium_override': false,
        'wr_dev_premium_override_owner': 'thedangs7@gmail.com',
      });
      final repo = _FakeIapRepository(verifyFails: true);
      final c = ProviderContainer(
        overrides: [
          wrStorePolicyProvider.overrideWithValue(WrStorePolicy.appStore),
          wrIapRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(_userId),
          currentUserEmailProvider.overrideWithValue('thedangs7@gmail.com'),
        ],
      );
      addTearDown(c.dispose);

      c.read(premiumOverrideProvider);
      c.read(wrIapControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(
        c.read(premiumOverrideProvider),
        isFalse,
        reason: 'trạng thái đầu',
      );

      repo.controller.add(_purchase());
      await Future<void>.delayed(Duration.zero);

      // Xác minh hỏng nghĩa là chưa có quyền. Gỡ công tắc lúc này là đổi trạng
      // thái màn hình của người đang nghiệm thu mà chẳng đổi lại được gì.
      expect(c.read(premiumOverrideProvider), isFalse);
    });
  });

  group('Kết quả rỗng của Google Play', () {
    // Play báo lần mua hỏng / bị huỷ bằng một giao dịch `productID: ''`. Nuốt
    // nó là Paywall quay mãi — đã gặp trên máy thật 20/10/2026.
    Future<WrIapPurchase> firstUpdate(PurchaseDetails d) {
      final plugin = _FakePlugin();
      final repo = StoreKitIapRepository(
        plugin,
        SupabaseClient('http://localhost', 'test-anon-key'),
      );
      final next = repo.purchaseUpdates.first;
      plugin.emit([d]);
      return next;
    }

    PurchaseDetails emptyResult(PurchaseStatus status, String code) =>
        PurchaseDetails(
            purchaseID: '',
            productID: '',
            status: status,
            transactionDate: null,
            verificationData: PurchaseVerificationData(
              localVerificationData: '',
              serverVerificationData: '',
              source: 'google_play',
            ),
          )
          ..error = IAPError(
            source: 'google_play',
            code: 'purchase_error',
            message: code,
          );

    test('ITEM_UNAVAILABLE tới được tầng trên thành lỗi đọc được', () async {
      final p = await firstUpdate(
        emptyResult(PurchaseStatus.error, 'BillingResponse.itemUnavailable'),
      );
      expect(p.status, WrIapStatus.error);
      expect(p.errorMessage, contains('Google Play'));
      expect(p.errorMessage, isNot(contains('BillingResponse')));
    });

    test('huỷ cũng tới được tầng trên', () async {
      final p = await firstUpdate(
        emptyResult(PurchaseStatus.canceled, 'BillingResponse.userCanceled'),
      );
      expect(p.status, WrIapStatus.canceled);
    });

    test('tên gói lấy từ danh mục, không mang đuôi tên app của Play', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final plugin = _FakePlugin()
          ..details = [
            ProductDetails(
              id: kIapMonthlyPlayProductId,
              title: 'Premium 1 tháng (app.workreflection.mobile (unreviewed))',
              description: 'mô tả',
              price: '70.000 ₫',
              rawPrice: 70000,
              currencyCode: 'VND',
            ),
          ];
        final repo = StoreKitIapRepository(
          plugin,
          SupabaseClient('http://localhost', 'test-anon-key'),
        );
        final offers = await repo.fetchOffers();
        expect(offers.single.id, kIapMonthlyProductId);
        expect(offers.single.title, isNot(contains('unreviewed')));
        expect(
          offers.single.title,
          wrIapProductById(kIapMonthlyProductId)!.title,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('mã lỗi lạ thì để Paywall dùng câu chung', () async {
      final p = await firstUpdate(
        emptyResult(PurchaseStatus.error, 'BillingResponse.error'),
      );
      expect(p.status, WrIapStatus.error);
      expect(p.errorMessage, isNull);
    });
  });

  group('Hai kho ứng dụng', () {
    test('Android bán qua Google Play, còn lại qua App Store', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(WrIapStore.current, WrIapStore.googlePlay);
        // Server rẽ nhánh kiểm biên lai theo đúng chữ này.
        expect(WrIapStore.current.verifyPlatform, 'android');
        expect(
          WrIapStore.current.manageSubscriptionsUrl,
          contains('package=$kAndroidPackageName'),
        );
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(WrIapStore.current, WrIapStore.appStore);
        expect(WrIapStore.current.verifyPlatform, 'ios');
        expect(
          WrIapStore.current.manageSubscriptionsUrl,
          startsWith('https://apps.apple.com/'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('package Android trùng bundle id iOS — product id dùng chung', () {
      expect(kAndroidPackageName, kIosBundleId);
    });

    testWidgets(
      'Paywall Android gọi đúng tên Google Play, không dán EULA Apple',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await tester.pumpWidget(_paywall(_FakeIapRepository()));
          await tester.pumpAndSettle();

          expect(find.textContaining('tài khoản Google Play'), findsWidgets);
          expect(find.textContaining('Apple'), findsNothing);
          expect(find.byKey(const Key('wr_paywall_terms_link')), findsNothing);
          expect(
            find.byKey(const Key('wr_paywall_privacy_link')),
            findsOneWidget,
          );
          // Nút khôi phục Google không bắt buộc nhưng vẫn giữ: người đổi máy
          // Android cũng cần lấy lại gói đã mua.
          expect(
            find.byKey(const Key('wr_paywall_iap_restore')),
            findsOneWidget,
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  group('Paywall bản App Store', () {
    testWidgets('hiện giá của StoreKit, KHÔNG hiện giá VND của cc_products', (
      tester,
    ) async {
      await tester.pumpWidget(_paywall(_FakeIapRepository()));
      await tester.pumpAndSettle();

      expect(find.textContaining('449.000 ₫'), findsWidgets);
      expect(find.textContaining('69.000 ₫'), findsWidgets);
      // 499.000đ là giá gói web trong `cc_products`. Dán nó lên nút IAP là nói
      // dối người mua — Apple bắt hiện đúng giá kho của họ.
      expect(find.textContaining('499.000'), findsNothing);
    });

    testWidgets('có nút mua từng gói', (tester) async {
      await tester.pumpWidget(_paywall(_FakeIapRepository()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_paywall_iap_buy_$kIapYearlyProductId')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wr_paywall_iap_buy_$kIapMonthlyProductId')),
        findsOneWidget,
      );
    });

    testWidgets('có nút khôi phục giao dịch — Apple bắt buộc', (tester) async {
      await tester.pumpWidget(_paywall(_FakeIapRepository()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_paywall_iap_restore')), findsOneWidget);
    });

    testWidgets('có liên kết Điều khoản và Chính sách quyền riêng tư', (
      tester,
    ) async {
      // Máy test mặc định là Android; EULA mẫu chỉ hiện ở bản iOS.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(_paywall(_FakeIapRepository()));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('wr_paywall_terms_link')), findsOneWidget);
        expect(
          find.byKey(const Key('wr_paywall_privacy_link')),
          findsOneWidget,
        );
        expect(find.textContaining('tài khoản Apple'), findsWidgets);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('không có nút dẫn sang web — đó là thứ bị từ chối lần trước', (
      tester,
    ) async {
      await tester.pumpWidget(_paywall(_FakeIapRepository()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_paywall_cta_web')), findsNothing);
      expect(find.byKey(const Key('wr_paywall_cta')), findsNothing);
    });

    testWidgets('kho không trả gói nào thì nói tử tế, không báo lỗi', (
      tester,
    ) async {
      await tester.pumpWidget(_paywall(_FakeIapRepository(offers: const [])));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_paywall_iap_unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('Chưa mở bán'), findsOneWidget);
    });

    testWidgets('máy không mua được thì cũng không bày nút mua', (
      tester,
    ) async {
      await tester.pumpWidget(_paywall(_FakeIapRepository(available: false)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_paywall_iap_unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('người đã có quyền không bị chào bán lại', (tester) async {
      await tester.pumpWidget(_paywall(_FakeIapRepository(), premium: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_paywall_cta_owned')), findsOneWidget);
      expect(
        find.byKey(const Key('wr_paywall_iap_buy_$kIapYearlyProductId')),
        findsNothing,
      );
    });

    testWidgets('gói mua qua kho: trang Bản Premium có nút quản lý gói', (
      tester,
    ) async {
      await tester.pumpWidget(
        _paywall(
          _FakeIapRepository(),
          premium: true,
          subscription: WrIapSubscription(
            productId: kIapMonthlyProductId,
            expiresAt: DateTime.now().add(const Duration(days: 20)),
            autoRenew: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_paywall_manage_subscription')),
        findsOneWidget,
      );
    });

    testWidgets('Premium từ web: không có gói kho nào để tắt', (tester) async {
      await tester.pumpWidget(_paywall(_FakeIapRepository(), premium: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_paywall_cta_owned')), findsOneWidget);
      expect(
        find.byKey(const Key('wr_paywall_manage_subscription')),
        findsNothing,
      );
    });

    testWidgets('bấm mua thì gọi kho ứng dụng', (tester) async {
      final repo = _FakeIapRepository();
      await tester.pumpWidget(_paywall(repo));
      await tester.pumpAndSettle();

      // Paywall dài hơn màn hình nên nút nằm dưới vùng nhìn thấy — không cuộn
      // tới thì cú chạm rơi vào khoảng không và test xanh vì lý do sai.
      final button = find.byKey(
        const Key('wr_paywall_iap_buy_$kIapYearlyProductId'),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();

      expect(repo.calls, contains('buy:$kIapYearlyProductId:$_userId'));
    });
  });

  group('Chính sách build', () {
    test('appStore bán bằng IAP, không QR, không dẫn ra web', () {
      expect(WrStorePolicy.appStore.allowsNativeIap, isTrue);
      expect(WrStorePolicy.appStore.allowsVietQrCheckout, isFalse);
      expect(WrStorePolicy.appStore.allowsWebPurchaseLink, isFalse);
    });

    test('các chính sách cũ không tự dưng bật IAP', () {
      expect(WrStorePolicy.silent.allowsNativeIap, isFalse);
      expect(WrStorePolicy.webLinkOnly.allowsNativeIap, isFalse);
      expect(WrStorePolicy.open.allowsNativeIap, isFalse);
    });

    test('appStore khác silent — bản silent chính là bản bị từ chối', () {
      expect(WrStorePolicy.appStore, isNot(WrStorePolicy.silent));
    });
  });
}

class _FakePlugin implements InAppPurchase {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();

  void emit(List<PurchaseDetails> batch) => _controller.add(batch);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  List<ProductDetails> details = const [];

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: details.where((d) => ids.contains(d.id)).toList(),
        notFoundIDs: const [],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
