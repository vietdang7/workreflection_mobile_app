// Luồng quay về sau khi mua.
//
// Paywall được đẩy lên từ 9 màn khác nhau, rồi chính nó đẩy tiếp màn thanh
// toán. Nên nếu màn thành công chỉ pop một lớp, người vừa trả tiền xong lại
// rơi đúng vào trang mời mua. Test này giữ cho điều đó không tái diễn.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/payment_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_entitlement.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/logic/wr_payment.dart';
import 'package:workreflection_mobile/core/logic/wr_pricing.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_payment_screen.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_paywall_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

import 'wr_payment_screen_test.dart' show FakePaymentRepository;

/// Dựng đúng chồng màn hình thật: trang gốc → Paywall → Thanh toán.
Widget _app(FakePaymentRepository repo, {required bool premiumAfter}) {
  final router = GoRouter(
    initialLocation: '/goc',
    routes: [
      GoRoute(
        path: '/goc',
        builder: (_, __) => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                key: const Key('mo_paywall'),
                onPressed: () => context.push('/wr/paywall'),
                child: const Text('TRANG GỐC'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/wr/paywall',
        builder: (_, __) => const WrPaywallScreen(),
      ),
      GoRoute(
        path: '/wr/payment',
        builder: (_, __) => const WrPaymentScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      paymentRepositoryProvider.overrideWithValue(repo),
      wrPremiumPricingProvider.overrideWith(
        (ref) async => const WrPremiumPricing(
          currentPrice: 249000,
          originalPrice: 499000,
          productId: 'prod-1',
        ),
      ),
      ccProfileProvider.overrideWith((ref) async => {'role': 'user'}),
      wrEntitlementProvider.overrideWith(
        (ref) async => WrEntitlement(
          plan: premiumAfter ? WrPlan.premium : WrPlan.free,
        ),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _goToPayment(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mo_paywall')));
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.byKey(const Key('wr_paywall_cta')),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('wr_paywall_cta')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mua xong bấm nút thì về TRANG GỐC, không phải Paywall', (
    tester,
  ) async {
    final repo = FakePaymentRepository();
    await tester.pumpWidget(_app(repo, premiumAfter: true));
    await tester.pumpAndSettle();

    await _goToPayment(tester);
    expect(find.byKey(const Key('wr_payment_countdown')), findsOneWidget);

    // Webhook xác nhận.
    repo.nextPolled = repo.order.copyWith(status: 'paid');
    await tester.pump(kPaymentPollInterval);
    await tester.pump();
    expect(find.byKey(const Key('wr_payment_success')), findsOneWidget);

    await tester.tap(find.byKey(const Key('wr_payment_success_cta')));
    await tester.pumpAndSettle();

    expect(find.text('TRANG GỐC'), findsOneWidget);
    expect(find.byKey(const Key('wr_paywall_cta')), findsNothing);
  });

  testWidgets('bấm nút quay lại sau khi đã trả tiền cũng về TRANG GỐC', (
    tester,
  ) async {
    // Không bấm nút trên màn thành công mà bấm back — push trả về null, nên
    // Paywall phải tự hỏi lại quyền chứ không thể chỉ tin vào kết quả pop.
    final repo = FakePaymentRepository();
    await tester.pumpWidget(_app(repo, premiumAfter: true));
    await tester.pumpAndSettle();

    await _goToPayment(tester);

    repo.nextPolled = repo.order.copyWith(status: 'paid');
    await tester.pump(kPaymentPollInterval);
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('TRANG GỐC'), findsOneWidget);
  });

  testWidgets('chưa mua mà quay lại thì Paywall vẫn còn', (tester) async {
    // Đóng nhầm Paywall của người chưa mua là cướp mất lối vào duy nhất.
    final repo = FakePaymentRepository();
    await tester.pumpWidget(_app(repo, premiumAfter: false));
    await tester.pumpAndSettle();

    await _goToPayment(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wr_paywall_cta')), findsOneWidget);
    expect(find.text('TRANG GỐC'), findsNothing);
  });
}
