// Chính sách bán hàng theo nền tảng — bản phát hành qua kho ứng dụng không
// được bán trong app.
//
// Vì sao phải có test: cả hai kho đều cấm mở khoá tính năng số bằng cổng thanh
// toán riêng (Apple Guideline 3.1.1, Google Play Payments policy), mà luồng
// mua của WorkReflection là QR chuyển khoản. Một `push('/wr/payment')` sót lại
// ở đâu đó là đủ để bị từ chối bản nộp — hoặc bị gỡ app bên Google — nên chặn
// phải được kiểm cả ở tầng route chứ không chỉ ở nút bấm.

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_entitlement.dart';
import 'package:workreflection_mobile/core/logic/wr_pricing.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart'
    show WrPlan;
import 'package:workreflection_mobile/core/logic/wr_store_policy.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_paywall_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

const _plans = [
  WrPremiumPricing(
    currentPrice: 499000,
    productId: 'prod-year',
    durationDays: 365,
  ),
  WrPremiumPricing(
    currentPrice: 70000,
    productId: 'prod-month',
    durationDays: 30,
  ),
];

Widget _paywall(WrStorePolicy policy, {bool premium = false}) => ProviderScope(
      overrides: [
        wrStorePolicyProvider.overrideWithValue(policy),
        wrPremiumPlansProvider.overrideWith((ref) async => _plans),
        wrEntitlementProvider.overrideWith(
          (ref) async => WrEntitlement(
            plan: premium ? WrPlan.premium : WrPlan.free,
          ),
        ),
      ],
      child: MaterialApp(
        builder: wrTextScaleBuilder,
        home: const WrPaywallScreen(),
      ),
    );

void main() {
  group('wrWebPremiumUrl', () {
    test('kèm gói đã chọn và nguồn để web đo được', () {
      final url = wrWebPremiumUrl(
        baseUrl: 'https://www.workreflection.app',
        planProductId: 'prod-year',
        source: 'ios_app',
      );
      final uri = Uri.parse(url);
      expect(uri.path, '/premium');
      expect(uri.queryParameters['plan'], 'prod-year');
      expect(uri.queryParameters['source'], 'ios_app');
    });

    test('không có gói thì vẫn ra đường dẫn hợp lệ, không kèm plan rỗng', () {
      final uri = Uri.parse(
        wrWebPremiumUrl(baseUrl: 'https://www.workreflection.app'),
      );
      expect(uri.queryParameters.containsKey('plan'), isFalse);
      expect(uri.queryParameters['source'], 'app');
    });

    // Hai kho tách riêng vì quyết định có làm billing thật hay không là quyết
    // định riêng từng kho — gộp chung một nhãn là mất luôn căn cứ để quyết.
    test('phân biệt được nguồn iOS với Android', () {
      for (final src in ['ios_app', 'android_app']) {
        final uri = Uri.parse(
          wrWebPremiumUrl(
            baseUrl: 'https://www.workreflection.app',
            source: src,
          ),
        );
        expect(uri.queryParameters['source'], src);
      }
    });

    test('baseUrl có dấu / cuối không sinh ra //premium', () {
      final url = wrWebPremiumUrl(
        baseUrl: 'https://www.workreflection.app/',
        planProductId: 'p',
      );
      expect(url.contains('//premium'), isFalse);
      expect(Uri.parse(url).path, '/premium');
    });
  });

  // Khoá là mặc định, mở mới là ngoại lệ phải khai bằng cờ build. Không suy
  // theo nền tảng nữa: từng cho bản web chạy `open` và hậu quả là chạy thử
  // `flutter run -d chrome` thấy y nguyên màn QR, tưởng phần chặn hỏng.
  group('WrStorePolicy.forThisBuild', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('mọi nền tảng đều khoá màn thanh toán trong app', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          WrStorePolicy.forThisBuild(),
          WrStorePolicy.webLinkOnly,
          reason: 'nền tảng $platform phải khoá',
        );
      }
    });

    test('bản mở phải được khai rõ, không tự dưng có', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(WrStorePolicy.forThisBuild().allowsInAppPurchase, isFalse);
    });
  });

  group('Paywall đổi dáng theo chính sách', () {
    testWidgets('Web/desktop: có nút mua trong app', (tester) async {
      await tester.pumpWidget(_paywall(WrStorePolicy.open));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_paywall_cta')), findsOneWidget);
      expect(find.byKey(const Key('wr_paywall_cta_web')), findsNothing);
    });

    testWidgets('Kho ứng dụng: nút mua trong app biến mất, thay bằng lối sang web',
        (tester) async {
      await tester.pumpWidget(_paywall(WrStorePolicy.webLinkOnly));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_paywall_cta')), findsNothing);
      expect(find.byKey(const Key('wr_paywall_cta_web')), findsOneWidget);
      // Vẫn phải cho biết giá — bấm sang trình duyệt mà mù thông tin thì tệ.
      expect(find.textContaining('499.000đ'), findsWidgets);
    });

    testWidgets('Bản im lặng: không nút, không con số giá nào',
        (tester) async {
      await tester.pumpWidget(_paywall(WrStorePolicy.silent));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_paywall_cta')), findsNothing);
      expect(find.byKey(const Key('wr_paywall_cta_web')), findsNothing);
      expect(find.byKey(const Key('wr_paywall_cta_silent')), findsOneWidget);
      expect(find.textContaining('499.000đ'), findsNothing);
      expect(find.textContaining('70.000đ'), findsNothing);
    });
  });

  // Người duyệt app của Apple dùng tài khoản demo đã có Premium. Nếu màn này
  // vẫn chào bán, họ thấy ngay nút dẫn ra trình duyệt — đúng thứ Guideline
  // 3.1.3 (anti-steering) cấm. Người thật đã trả tiền bị mời mua lại cũng vô
  // lý y như vậy.
  group('Đã có quyền thì Paywall thôi chào bán', () {
    testWidgets('Kho ứng dụng: không còn lối sang web, không còn giá',
        (tester) async {
      await tester.pumpWidget(
        _paywall(WrStorePolicy.webLinkOnly, premium: true),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_paywall_cta_owned')), findsOneWidget);
      expect(find.byKey(const Key('wr_paywall_cta_web')), findsNothing);
      expect(find.textContaining('499.000đ'), findsNothing);
      expect(find.textContaining('70.000đ'), findsNothing);
    });

    testWidgets('Bản mở: nút mua trong app cũng biến mất', (tester) async {
      await tester.pumpWidget(_paywall(WrStorePolicy.open, premium: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('wr_paywall_cta_owned')), findsOneWidget);
      expect(find.byKey(const Key('wr_paywall_cta')), findsNothing);
    });
  });
}
