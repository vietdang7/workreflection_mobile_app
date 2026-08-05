import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/data/payment_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_payment.dart';
import 'package:workreflection_mobile/core/logic/wr_pricing.dart';
import 'package:workreflection_mobile/features/profile/profile_providers.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_payment_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

/// Repo thanh toán giả — ghi lại lời gọi để test kiểm đúng thứ được gửi lên.
class FakePaymentRepository implements PaymentRepository {
  FakePaymentRepository({this.createFails = false});

  final bool createFails;

  WrOrder order = const WrOrder(
    id: 'order-1',
    code: 'CNCORDER01',
    status: 'pending',
    originalAmount: 499000,
    finalAmount: 499000,
  );

  /// Đơn mà [getOrder] trả về ở lần hỏi tiếp theo. Null thì trả [order].
  WrOrder? nextPolled;

  String? createdProductId;
  num? createdAmount;
  int expireCalls = 0;
  int completeFreeCalls = 0;
  final List<WrInvoiceForm> savedInvoices = [];
  Object? voucherError;

  @override
  Future<WrOrder> createPremiumOrder({
    required String productId,
    required num amount,
    String currency = 'VND',
  }) async {
    if (createFails) throw StateError('boom');
    createdProductId = productId;
    createdAmount = amount;
    return order;
  }

  /// Đơn cũ còn hạn mà [findReusablePendingOrder] tìm thấy. Null = không có.
  WrOrder? reusable;
  int findReusableCalls = 0;

  @override
  Future<WrOrder?> findReusablePendingOrder({
    required String productId,
    required num amount,
  }) async {
    findReusableCalls++;
    return reusable;
  }

  /// Danh sách mã mà bảng gợi ý nhận được.
  List<WrVoucher> vouchers = const [];

  @override
  Future<List<WrVoucher>> listVouchers() async => vouchers;

  @override
  Future<WrOrder> getOrder(String orderId) async => nextPolled ?? order;

  @override
  Future<WrOrder> applyVoucher({
    required WrOrder order,
    required String code,
    String? userRole,
    String? orgId,
  }) async {
    if (voucherError != null) throw voucherError!;
    final updated = order.copyWith(discountAmount: 499000, finalAmount: 0);
    this.order = updated;
    return updated;
  }

  @override
  Future<WrOrder> removeVoucher(WrOrder order) async {
    final updated = order.copyWith(
      clearVoucher: true,
      discountAmount: 0,
      finalAmount: order.originalAmount,
    );
    this.order = updated;
    return updated;
  }

  @override
  Future<void> saveInvoiceInfo(String orderId, WrInvoiceForm form) async {
    savedInvoices.add(form);
  }

  @override
  Future<void> expireOrder(String orderId) async => expireCalls++;

  /// Khi khác null, [completeFreeOrder] ném lỗi này — mô phỏng RPC hỏng.
  Object? completeFreeError;

  @override
  Future<void> completeFreeOrder(String orderId) async {
    completeFreeCalls++;
    if (completeFreeError != null) throw completeFreeError!;
  }
}

Widget _wrap(FakePaymentRepository repo, {WrPremiumPricing? pricing}) {
  return ProviderScope(
    overrides: [
      paymentRepositoryProvider.overrideWithValue(repo),
      wrPremiumPricingProvider.overrideWith(
        (ref) async =>
            pricing ??
            // Giá gói APP (`cc_products.product_type = 'premium_mobile'`),
            // không phải gói web 249.000đ.
            const WrPremiumPricing(
              currentPrice: 499000,
              productId: 'prod-1',
            ),
      ),
      ccProfileProvider.overrideWith((ref) async => {'role': 'user'}),
    ],
    child: MaterialApp(
        builder: wrTextScaleBuilder,
        home: const WrPaymentScreen(),
      ),
  );
}

/// Cuộn tới khi [finder] lọt vào khung.
///
/// Khung test mặc định 800×600, mà màn thanh toán dài hơn thế — khối ngân hàng
/// và form hoá đơn nằm dưới ảnh QR nên mặc định chưa dựng.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  // Ảnh QR gọi ra mạng; trong test luôn hỏng nên màn hiện nhánh dự phòng.
  // Điều đó vẫn đúng ý: thông tin chuyển khoản thủ công phải luôn có mặt.

  group('WrPaymentScreen — tạo đơn', () {
    testWidgets('tạo đơn với đúng product_id và giá hiện tại', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      expect(repo.createdProductId, 'prod-1');
      expect(repo.createdAmount, 499000);
    });

    testWidgets('hiện số tiền và mã đơn để chuyển khoản tay', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('wr_payment_amount')), findsOneWidget);
      expect(find.text('499.000đ'), findsOneWidget);

      await _scrollTo(tester, find.text('CNCORDER01'));
      expect(find.text('CNCORDER01'), findsOneWidget);
      expect(find.text('2610130979'), findsOneWidget);
      expect(find.text('CLOUD CORAL'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('không có product_id thì từ chối tạo đơn', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(
        _wrap(repo, pricing: WrPremiumPricing.fallback),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('wr_payment_error')), findsOneWidget);
      expect(repo.createdProductId, isNull);
    });

    testWidgets('tạo đơn lỗi thì báo lỗi chứ không treo màn loading', (
      tester,
    ) async {
      final repo = FakePaymentRepository(createFails: true);
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('wr_payment_error')), findsOneWidget);
      expect(find.byKey(const Key('wr_payment_loading')), findsNothing);
    });
  });

  group('WrPaymentScreen — đếm ngược', () {
    testWidgets('bắt đầu từ 30:00 và đếm lùi', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      expect(find.text('Đơn còn hiệu lực 30:00'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Đơn còn hiệu lực 29:59'), findsOneWidget);

      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Đơn còn hiệu lực 29:00'), findsOneWidget);

      // Dọn hai timer đang chạy để test không rò.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hết giờ thì đánh dấu đơn hết hạn', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await tester.pump(kPaymentWindow);
      await tester.pump();

      expect(repo.expireCalls, 1);
      expect(find.byKey(const Key('wr_payment_expired')), findsOneWidget);
    });
  });

  group('WrPaymentScreen — hỏi lại trạng thái', () {
    testWidgets('thấy đơn đã paid thì hiện màn thành công', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('wr_payment_success')), findsNothing);

      // Webhook xác nhận giữa hai nhịp hỏi.
      repo.nextPolled = repo.order.copyWith(status: 'paid');
      await tester.pump(kPaymentPollInterval);
      await tester.pump();

      expect(find.byKey(const Key('wr_payment_success')), findsOneWidget);
      expect(find.text('Đã nhận được thanh toán'), findsOneWidget);
    });

    testWidgets('đã thành công thì dừng đếm ngược', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      repo.nextPolled = repo.order.copyWith(status: 'paid');
      await tester.pump(kPaymentPollInterval);
      await tester.pump();

      // Quá cửa sổ 30 phút mà không được đánh hết hạn — đơn đã trả rồi.
      await tester.pump(kPaymentWindow);
      await tester.pump();

      expect(repo.expireCalls, 0);
      expect(find.byKey(const Key('wr_payment_success')), findsOneWidget);
    });
  });

  group('WrPaymentScreen — voucher', () {
    testWidgets('giảm 100% thì tự hoàn tất, không cần QR', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('wr_payment_voucher_input')),
        'FREE100',
      );
      await tester.tap(find.byKey(const Key('wr_payment_voucher_apply')));
      await tester.pump();
      await tester.pump();

      expect(repo.completeFreeCalls, 1);
      expect(find.byKey(const Key('wr_payment_success')), findsOneWidget);
    });

    testWidgets('mã hỏng thì hiện đúng lý do', (tester) async {
      final repo = FakePaymentRepository()
        ..voucherError = const WrVoucherException('Mã giảm giá đã hết hạn');
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('wr_payment_voucher_input')),
        'CU',
      );
      await tester.tap(find.byKey(const Key('wr_payment_voucher_apply')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Mã giảm giá đã hết hạn'), findsOneWidget);
      expect(repo.completeFreeCalls, 0);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WrPaymentScreen — dùng lại đơn còn hạn', () {
    testWidgets('có đơn cũ còn hạn thì KHÔNG tạo đơn mới', (tester) async {
      final repo = FakePaymentRepository();
      repo.reusable = WrOrder(
        id: 'order-cu',
        code: 'CNCCU000001',
        status: 'pending',
        originalAmount: 499000,
        finalAmount: 499000,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 12)),
      );

      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      expect(repo.findReusableCalls, 1);
      expect(repo.createdProductId, isNull, reason: 'không được tạo đơn mới');
      await _scrollTo(tester, find.text('CNCCU000001'));
      expect(find.text('CNCCU000001'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('đếm nốt hạn còn lại chứ không quay về 30:00', (tester) async {
      final repo = FakePaymentRepository();
      repo.reusable = WrOrder(
        id: 'order-cu',
        code: 'CNCCU000001',
        status: 'pending',
        originalAmount: 499000,
        finalAmount: 499000,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 12)),
      );

      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      expect(find.text('Đơn còn hiệu lực 30:00'), findsNothing);
      expect(find.textContaining('Đơn còn hiệu lực 11:5'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('không có đơn cũ thì tạo mới như thường', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      expect(repo.findReusableCalls, 1);
      expect(repo.createdProductId, 'prod-1');

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WrPaymentScreen — đơn hết hạn', () {
    testWidgets('hiện mã đơn, số tiền và dịch vụ', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await tester.pump(kPaymentWindow);
      await tester.pump();

      expect(find.text('Đơn hàng đã hết hạn'), findsOneWidget);
      expect(find.text('CNCORDER01'), findsOneWidget);
      expect(find.text('499.000đ'), findsOneWidget);
      expect(find.text('Work Reflection Premium'), findsOneWidget);
    });

    testWidgets('bấm tạo đơn mới thì quay lại màn QR', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();
      await tester.pump(kPaymentWindow);
      await tester.pump();

      await tester.tap(find.byKey(const Key('wr_payment_expired_retry')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('wr_payment_expired')), findsNothing);
      expect(find.text('Đơn còn hiệu lực 30:00'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WrPaymentScreen — bảng chọn mã', () {
    const goodVoucher = WrVoucher(
      id: 'v1',
      code: 'HELLO50',
      discountType: 'percentage',
      discountPercent: 50,
    );

    testWidgets('hiện mã dùng được kèm mức giảm', (tester) async {
      final repo = FakePaymentRepository()..vouchers = [goodVoucher];
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await _scrollTo(tester, find.byKey(const Key('wr_payment_voucher_browse')));
      await tester.tap(find.byKey(const Key('wr_payment_voucher_browse')));
      await tester.pumpAndSettle();

      expect(find.text('HELLO50'), findsOneWidget);
      expect(find.text('Giảm 50%'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('mã hết hạn hiện mờ kèm lý do, không có nút Dùng', (
      tester,
    ) async {
      final expired = WrVoucher(
        id: 'v2',
        code: 'CUROI',
        discountType: 'percentage',
        discountPercent: 10,
        validTo: DateTime(2020),
      );
      final repo = FakePaymentRepository()..vouchers = [expired];
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await _scrollTo(tester, find.byKey(const Key('wr_payment_voucher_browse')));
      await tester.tap(find.byKey(const Key('wr_payment_voucher_browse')));
      await tester.pumpAndSettle();

      expect(find.text('CUROI'), findsOneWidget);
      expect(find.text('Hết hạn'), findsOneWidget);
      expect(find.byKey(const Key('wr_payment_voucher_pick_CUROI')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('chọn một mã thì áp dụng luôn', (tester) async {
      final repo = FakePaymentRepository()..vouchers = [goodVoucher];
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await _scrollTo(tester, find.byKey(const Key('wr_payment_voucher_browse')));
      await tester.tap(find.byKey(const Key('wr_payment_voucher_browse')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('wr_payment_voucher_pick_HELLO50')));
      await tester.pumpAndSettle();

      // Repo giả trả về đơn 0đ nên đi thẳng tới màn thành công.
      expect(repo.completeFreeCalls, 1);
      expect(find.byKey(const Key('wr_payment_success')), findsOneWidget);
    });

    testWidgets('không có mã nào thì nói rõ', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await _scrollTo(tester, find.byKey(const Key('wr_payment_voucher_browse')));
      await tester.tap(find.byKey(const Key('wr_payment_voucher_browse')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('wr_payment_voucher_list_empty')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WrPaymentScreen — đơn 0đ', () {
    /// Đơn đã gắn voucher giảm hết từ trước, mở lại màn là thấy ngay —
    /// đúng tình huống đơn CNCB2DE90DF ngày 2026-08-01.
    WrOrder freeOrder() => WrOrder(
          id: 'order-free',
          code: 'CNCFREE0001',
          status: 'pending',
          originalAmount: 499000,
          discountAmount: 499000,
          finalAmount: 0,
          voucherId: 'v1',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 20)),
        );

    testWidgets('không hiện QR, hiện nút nhận Premium', (tester) async {
      final repo = FakePaymentRepository()
        ..reusable = freeOrder()
        ..completeFreeError = StateError('server hỏng');

      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('wr_payment_qr')), findsNothing);
      expect(find.byKey(const Key('wr_payment_free_card')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hoàn tất hụt thì vẫn còn đường thử lại', (tester) async {
      final repo = FakePaymentRepository()
        ..reusable = freeOrder()
        ..completeFreeError = StateError('42883 operator does not exist');

      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await _scrollTo(tester, find.byKey(const Key('wr_payment_free_complete')));
      await tester.tap(find.byKey(const Key('wr_payment_free_complete')));
      await tester.pump();
      await tester.pump();

      // Lỗi hiện nguyên văn để lần sau khỏi phải dựng đơn thử mới lần ra.
      expect(find.textContaining('42883'), findsOneWidget);
      expect(repo.completeFreeCalls, 1);

      // Nút vẫn bấm được — đây chính là chỗ trước đây người dùng bị kẹt.
      repo.completeFreeError = null;
      await tester.tap(find.byKey(const Key('wr_payment_free_complete')));
      await tester.pump();
      await tester.pump();

      expect(repo.completeFreeCalls, 2);
      expect(find.byKey(const Key('wr_payment_success')), findsOneWidget);
    });
  });

  group('WrPaymentScreen — công tắc thử nghiệm', () {
    testWidgets('mua xong thì bỏ công tắc đang ép miễn phí', (tester) async {
      // Tình huống thật 2026-08-01: đơn CNC31194525 đã paid, cc_profiles.role
      // là admin, mà app vẫn hiện miễn phí — vì công tắc thử nghiệm trên máy
      // nằm cao hơn mọi nguồn quyền khác trong wrEntitlementProvider.
      SharedPreferences.setMockInitialValues({
        'wr_dev_premium_override': false,
      });

      final repo = FakePaymentRepository();
      final container = ProviderContainer(
        overrides: [
          paymentRepositoryProvider.overrideWithValue(repo),
          wrPremiumPricingProvider.overrideWith(
            (ref) async => const WrPremiumPricing(
              currentPrice: 499000,
              productId: 'prod-1',
            ),
          ),
          ccProfileProvider.overrideWith((ref) async => {'role': 'admin'}),
          // Máy này thuộc danh sách được bật/tắt gói. Phải khai cả email: từ
          // 2026-08-05 công tắc ghi kèm chủ sở hữu, `set` từ chối khi không
          // biết ai đang bật.
          canTogglePremiumProvider.overrideWithValue(true),
          currentUserEmailProvider.overrideWithValue('thedangs7@gmail.com'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(premiumOverrideProvider.notifier).set(false);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
        builder: wrTextScaleBuilder,
        home: const WrPaymentScreen(),
      ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(container.read(premiumOverrideProvider), isFalse,
          reason: 'trước khi mua vẫn đang bị ép miễn phí');

      repo.nextPolled = repo.order.copyWith(status: 'paid');
      await tester.pump(kPaymentPollInterval);
      await tester.pump();

      expect(container.read(premiumOverrideProvider), isNull,
          reason: 'mua thật phải thắng công cụ thử nghiệm');
      expect(find.byKey(const Key('wr_payment_success')), findsOneWidget);
    });

    testWidgets('máy không được phép bật/tắt thì không đụng tới công tắc', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'wr_dev_premium_override': false,
      });

      final repo = FakePaymentRepository();
      final container = ProviderContainer(
        overrides: [
          paymentRepositoryProvider.overrideWithValue(repo),
          wrPremiumPricingProvider.overrideWith(
            (ref) async => const WrPremiumPricing(
              currentPrice: 499000,
              productId: 'prod-1',
            ),
          ),
          ccProfileProvider.overrideWith((ref) async => {'role': 'user'}),
          canTogglePremiumProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(premiumOverrideProvider.notifier).set(false);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
        builder: wrTextScaleBuilder,
        home: const WrPaymentScreen(),
      ),
        ),
      );
      await tester.pump();
      await tester.pump();

      repo.nextPolled = repo.order.copyWith(status: 'paid');
      await tester.pump(kPaymentPollInterval);
      await tester.pump();

      // Tài khoản này không được phép: `set` bị từ chối ngay từ đầu, nên công
      // tắc không bao giờ có giá trị để mà phải xoá.
      expect(container.read(premiumOverrideProvider), isNull);
    });
  });

  group('WrPaymentScreen — hoá đơn VAT', () {
    testWidgets('mặc định tắt, bật lên mới hiện các ô', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('wr_payment_invoice_buyer')), findsNothing);

      await _scrollTo(tester, find.byKey(const Key('wr_payment_invoice_toggle')));
      await tester.tap(find.byKey(const Key('wr_payment_invoice_toggle')));
      await tester.pump();

      expect(find.byKey(const Key('wr_payment_invoice_buyer')), findsOneWidget);
      expect(find.byKey(const Key('wr_payment_invoice_tax')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('lưu xuống đơn sau khi ngừng gõ', (tester) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await _scrollTo(tester, find.byKey(const Key('wr_payment_invoice_toggle')));
      await tester.tap(find.byKey(const Key('wr_payment_invoice_toggle')));
      await tester.pump();
      // Nhịp lưu của lần bật công tắc.
      await tester.pump(const Duration(milliseconds: 600));

      await tester.enterText(
        find.byKey(const Key('wr_payment_invoice_buyer')),
        'Nguyễn A',
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(repo.savedInvoices.last.requested, isTrue);
      expect(repo.savedInvoices.last.buyerName, 'Nguyễn A');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('có mã số thuế mà thiếu tên đơn vị thì cảnh báo', (
      tester,
    ) async {
      final repo = FakePaymentRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pump();
      await tester.pump();

      await _scrollTo(tester, find.byKey(const Key('wr_payment_invoice_toggle')));
      await tester.tap(find.byKey(const Key('wr_payment_invoice_toggle')));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('wr_payment_invoice_buyer')),
        'A',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('wr_payment_invoice_address')),
        'Hà Nội',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('wr_payment_invoice_tax')),
        '0101234567',
      );
      await tester.pump();

      expect(find.text('Có mã số thuế thì phải có tên đơn vị'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
