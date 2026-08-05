// Màn thanh toán Premium — chuyển khoản ngân hàng qua VietQR.
//
// Bám theo `src/pages/Payment.tsx` của web: cùng tài khoản nhận tiền, cùng quy
// ước mã đơn `CNC…`, cùng cửa sổ 30 phút và nhịp hỏi lại 3 giây. Webhook ngân
// hàng không phân biệt đơn đến từ web hay app — nó chỉ dò mã trong nội dung
// chuyển khoản.
//
// Vòng đời một đơn:
//   tạo đơn 'pending'  →  hiện QR  →  người dùng chuyển khoản
//        →  SePay gọi webhook  →  complete_payment  →  status = 'paid'
//        →  màn này thấy 'paid' khi hỏi lại  →  mở khoá Premium
//
// Nhánh 0đ (voucher giảm 100%) không có QR: gọi thẳng complete_payment, đúng
// nhánh mà RLS cho phép chủ đơn tự hoàn tất.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/payment_repository.dart';
import '../../../core/logic/wr_payment.dart';
import '../../../core/logic/wr_pricing.dart';
import '../../../core/theme/wr_colors.dart';
import '../../profile/profile_providers.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

class WrPaymentScreen extends ConsumerStatefulWidget {
  const WrPaymentScreen({super.key, this.plan});

  /// Gói người dùng đã chọn ở Paywall (năm hay tháng).
  ///
  /// null khi màn này được mở thẳng, không đi qua Paywall — khi đó lấy gói chọn
  /// sẵn (`wrPremiumPricingProvider`) để không có đường nào dẫn tới màn thanh
  /// toán mà không biết đang bán gói nào.
  final WrPremiumPricing? plan;

  @override
  ConsumerState<WrPaymentScreen> createState() => _WrPaymentScreenState();
}

class _WrPaymentScreenState extends ConsumerState<WrPaymentScreen> {
  WrOrder? _order;
  String? _fatalError;
  bool _creating = true;

  /// Đã hoàn tất — hiện màn cảm ơn thay vì QR.
  bool _done = false;

  Duration _remaining = kPaymentWindow;
  Timer? _ticker;
  Timer? _poller;

  // Voucher
  final _voucherCtl = TextEditingController();
  String? _voucherError;
  bool _voucherBusy = false;
  String? _appliedCode;

  // Đơn 0đ
  bool _completingFree = false;
  String? _freeError;

  // Hoá đơn
  WrInvoiceForm _invoice = const WrInvoiceForm();
  Timer? _invoiceDebounce;

  String? _copiedField;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _createOrder());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    _invoiceDebounce?.cancel();
    _voucherCtl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Vòng đời đơn
  // ---------------------------------------------------------------------

  Future<void> _createOrder() async {
    final WrPremiumPricing pricing = widget.plan ??
        await ref.read(wrPremiumPricingProvider.future);

    // Không có product_id thì không tạo đơn: complete_payment tra
    // `cc_products` bằng id để biết cấp Premium bao nhiêu ngày, thiếu là đơn
    // trả tiền xong mà không rõ hạn.
    if (!pricing.canPurchase) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _fatalError = 'Chưa đọc được gói Premium từ hệ thống. '
            'Bạn thử lại sau ít phút giúp mình nhé.';
      });
      return;
    }

    try {
      final repo = ref.read(paymentRepositoryProvider);

      // Nhặt lại đơn còn hạn trước khi tạo mới. Bấm nâng cấp rồi thoát ra vài
      // lần sẽ để lại một loạt đơn 'expired' rác trong bảng quản trị.
      final reused = await repo.findReusablePendingOrder(
        productId: pricing.productId!,
        amount: pricing.currentPrice,
      );
      final order = reused ??
          await repo.createPremiumOrder(
            productId: pricing.productId!,
            amount: pricing.currentPrice,
            currency: pricing.currency,
          );

      if (!mounted) return;
      setState(() {
        _order = order;
        // Đơn dùng lại thì đếm nốt phần hạn còn lại, không quay về 30 phút.
        _remaining = _remainingFor(order);
        _creating = false;
      });
      _startTimers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _fatalError = 'Không tạo được đơn hàng. Kiểm tra kết nối rồi thử lại.';
      });
    }
  }

  /// Hạn còn lại của [order]. Đơn không ghi `expires_at` thì cho trọn cửa sổ.
  Duration _remainingFor(WrOrder order) {
    final at = order.expiresAt;
    if (at == null) return kPaymentWindow;
    final left = at.difference(DateTime.now().toUtc());
    if (left.isNegative) return Duration.zero;
    // Kẹp trên: đơn có hạn dài bất thường cũng không hiện quá cửa sổ chuẩn.
    return left > kPaymentWindow ? kPaymentWindow : left;
  }

  void _startTimers() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _remaining - const Duration(seconds: 1);
      if (next.inSeconds <= 0) {
        setState(() => _remaining = Duration.zero);
        _expire();
        return;
      }
      setState(() => _remaining = next);
    });

    _poller = Timer.periodic(kPaymentPollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    final order = _order;
    if (order == null || _done) return;
    try {
      final fresh = await ref.read(paymentRepositoryProvider).getOrder(order.id);
      if (!mounted) return;
      if (fresh.isPaid) {
        _onPaid();
      } else {
        setState(() => _order = fresh);
      }
    } catch (_) {
      // Mất mạng chốc lát thì bỏ qua nhịp này, nhịp sau hỏi lại. Không báo lỗi
      // vì người dùng đang chờ chuyển khoản, hiện lỗi chỉ làm họ hoang mang.
    }
  }

  void _onPaid() {
    _ticker?.cancel();
    _poller?.cancel();
    // Bỏ công tắc thử nghiệm nếu đang bật. Nó nằm cao hơn mọi nguồn quyền
    // khác trong wrEntitlementProvider, nên một công tắc "ép miễn phí" bỏ quên
    // sẽ nuốt trọn gói vừa mua: tiền đã trả, DB đã cấp, mà app vẫn khoá.
    // Mua thật thì phải thắng công cụ thử nghiệm.
    if (ref.read(canTogglePremiumProvider)) {
      ref.read(premiumOverrideProvider.notifier).set(null);
    }
    // Đọc lại quyền: cc_profiles.role vừa được complete_payment nâng lên
    // 'premium', không làm mới thì app vẫn tưởng đang là Free.
    ref.invalidate(ccProfileProvider);
    ref.invalidate(wrEntitlementProvider);
    if (!mounted) return;
    setState(() => _done = true);
  }

  Future<void> _expire() async {
    _ticker?.cancel();
    _poller?.cancel();
    final order = _order;
    if (order == null) return;
    try {
      await ref.read(paymentRepositoryProvider).expireOrder(order.id);
    } catch (_) {
      // Đánh dấu hết hạn thất bại cũng không sao: đơn 'pending' quá hạn không
      // gây hại, và người dùng vẫn thấy màn hết giờ.
    }
    if (!mounted) return;
    setState(() => _order = order.copyWith(status: 'expired'));
  }

  /// Bắt đầu lại từ đầu sau khi đơn hết hạn — tạo đơn mới, hẹn giờ mới.
  void _restart() {
    setState(() {
      _order = null;
      _creating = true;
      _remaining = kPaymentWindow;
      _appliedCode = null;
      _voucherError = null;
      _voucherCtl.clear();
      _invoice = const WrInvoiceForm();
      _completingFree = false;
      _freeError = null;
    });
    _createOrder();
  }

  /// Đơn 0đ: không có gì để chuyển khoản, tự hoàn tất.
  Future<void> _completeFree() async {
    final order = _order;
    if (order == null || _completingFree) return;
    setState(() {
      _completingFree = true;
      _freeError = null;
    });
    try {
      await ref.read(paymentRepositoryProvider).completeFreeOrder(order.id);
      _onPaid();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _completingFree = false;
        // Kèm nguyên văn lỗi server. Một câu chung chung "thử lại giúp mình"
        // đã từng giấu mất lỗi 42883 của RPC, phải đi dựng đơn thử mới lần ra.
        _freeError = 'Không hoàn tất được đơn.\n$e';
      });
    }
  }

  // ---------------------------------------------------------------------
  // Voucher
  // ---------------------------------------------------------------------

  Future<void> _applyVoucher() async {
    final order = _order;
    if (order == null) return;
    setState(() {
      _voucherBusy = true;
      _voucherError = null;
    });
    try {
      final role = ref.read(ccProfileProvider).valueOrNull?['role'] as String?;
      final updated = await ref.read(paymentRepositoryProvider).applyVoucher(
            order: order,
            code: _voucherCtl.text,
            userRole: role,
          );
      if (!mounted) return;
      setState(() {
        _order = updated;
        _appliedCode = _voucherCtl.text.trim().toUpperCase();
        _voucherBusy = false;
      });
      // Giảm 100% thì không còn gì để quét — đi thẳng tới hoàn tất.
      if (updated.isFree) await _completeFree();
    } on WrVoucherException catch (e) {
      if (!mounted) return;
      setState(() {
        _voucherError = e.message;
        _voucherBusy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voucherError = 'Có lỗi xảy ra, thử lại giúp mình';
        _voucherBusy = false;
      });
    }
  }

  /// Mở bảng gợi ý mã. Chọn một mã là điền vào ô rồi áp dụng luôn, như web.
  Future<void> _openVoucherList() async {
    final repo = ref.read(paymentRepositoryProvider);
    final role = ref.read(ccProfileProvider).valueOrNull?['role'] as String?;
    final userId = ref.read(ccProfileProvider).valueOrNull?['id'] as String?;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: WrColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VoucherListSheet(
        load: () async {
          final all = await repo.listVouchers();
          return selectableVouchers(
            all,
            userId: userId,
            userRole: role,
          );
        },
      ),
    );

    if (picked == null || !mounted) return;
    _voucherCtl.text = picked;
    await _applyVoucher();
  }

  Future<void> _removeVoucher() async {
    final order = _order;
    if (order == null) return;
    setState(() => _voucherBusy = true);
    try {
      final updated =
          await ref.read(paymentRepositoryProvider).removeVoucher(order);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _appliedCode = null;
        _voucherCtl.clear();
        _voucherError = null;
        _freeError = null;
      });
    } finally {
      if (mounted) setState(() => _voucherBusy = false);
    }
  }

  // ---------------------------------------------------------------------
  // Hoá đơn
  // ---------------------------------------------------------------------

  void _updateInvoice(WrInvoiceForm next) {
    setState(() => _invoice = next);
    // Lưu trễ 500ms như web: gõ tới đâu ghi tới đó sẽ nện DB mỗi phím.
    _invoiceDebounce?.cancel();
    _invoiceDebounce = Timer(const Duration(milliseconds: 500), () {
      final order = _order;
      if (order == null) return;
      ref
          .read(paymentRepositoryProvider)
          .saveInvoiceInfo(order.id, next)
          .catchError((_) {
        // Lưu hụt một nhịp không chặn thanh toán; lần gõ sau ghi đè lại.
      });
    });
  }

  Future<void> _copy(String text, String field) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copiedField = field);
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedField = null);
    });
  }

  // ---------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        foregroundColor: WrColors.navy,
        title: const Text(
          'Thanh toán',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_creating) {
      return const Center(
        key: Key('wr_payment_loading'),
        child: CircularProgressIndicator(color: WrColors.coral),
      );
    }

    final fatal = _fatalError;
    if (fatal != null) return _Message(key: const Key('wr_payment_error'), text: fatal);

    if (_done) return const _SuccessView(key: Key('wr_payment_success'));

    final order = _order;
    if (order == null) {
      return const _Message(
        key: Key('wr_payment_error'),
        text: 'Không tạo được đơn hàng.',
      );
    }

    if (order.status == 'expired') {
      return _ExpiredView(
        key: const Key('wr_payment_expired'),
        order: order,
        onRetry: _restart,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        _CountdownBar(remaining: _remaining),
        const SizedBox(height: 16),
        _AmountCard(order: order),
        const SizedBox(height: 14),
        _VoucherCard(
          controller: _voucherCtl,
          appliedCode: _appliedCode,
          error: _voucherError,
          busy: _voucherBusy,
          onApply: _applyVoucher,
          onRemove: _removeVoucher,
          onBrowse: _openVoucherList,
        ),
        const SizedBox(height: 14),
        // Đơn 0đ không có gì để quét. Hiện QR số tiền 0 chỉ làm người dùng
        // hoang mang, và họ cần một đường thử lại khi hoàn tất hụt.
        if (order.isFree)
          _FreeOrderCard(
            busy: _completingFree,
            error: _freeError,
            onComplete: _completeFree,
          )
        else ...[
          _QrCard(order: order),
          const SizedBox(height: 14),
          _BankCard(
            order: order,
            copiedField: _copiedField,
            onCopy: _copy,
          ),
        ],
        const SizedBox(height: 14),
        _InvoiceCard(form: _invoice, onChanged: _updateInvoice),
        if (!order.isFree) ...[
          const SizedBox(height: 18),
          const _WaitingNote(),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thành phần
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WrColors.line),
      ),
      child: child,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16.5, color: WrColors.text2, height: 1.5),
        ),
      ),
    );
  }
}

class _CountdownBar extends StatelessWidget {
  const _CountdownBar({required this.remaining});
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    // Dưới 5 phút thì đổi sang đỏ — đủ sớm để còn kịp làm gì đó.
    final urgent = remaining.inMinutes < 5;
    return Container(
      key: const Key('wr_payment_countdown'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: urgent ? const Color(0x14FF6859) : const Color(0x1415B5B0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule,
              size: 17, color: urgent ? WrColors.coral : WrColors.teal),
          const SizedBox(width: 8),
          Text(
            'Đơn còn hiệu lực ${formatCountdown(remaining)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: urgent ? WrColors.coral : WrColors.pillTealText,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.order});
  final WrOrder order;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SỐ TIỀN CẦN CHUYỂN',
              style: TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: WrColors.text3)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatVndPrice(order.finalAmount),
                key: const Key('wr_payment_amount'),
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: WrColors.navy),
              ),
              if (order.discountAmount > 0) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    formatVndPrice(order.originalAmount),
                    style: const TextStyle(
                      fontSize: 16.5,
                      color: WrColors.text3,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.controller,
    required this.appliedCode,
    required this.error,
    required this.busy,
    required this.onApply,
    required this.onRemove,
    required this.onBrowse,
  });

  final TextEditingController controller;
  final String? appliedCode;
  final String? error;
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onRemove;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final applied = appliedCode;
    return _Card(
      key: const Key('wr_payment_voucher'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('MÃ GIẢM GIÁ',
                    style: TextStyle(
                        fontSize: 12.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: WrColors.text3)),
              ),
              if (applied == null)
                TextButton(
                  key: const Key('wr_payment_voucher_browse'),
                  onPressed: busy ? null : onBrowse,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Chọn mã có sẵn',
                      style: TextStyle(fontSize: 14.5)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (applied != null)
            Row(
              children: [
                const Icon(Icons.check_circle, size: 18, color: WrColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Đã áp dụng $applied',
                      key: const Key('wr_payment_voucher_applied'),
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: WrColors.navy)),
                ),
                TextButton(
                  key: const Key('wr_payment_voucher_remove'),
                  onPressed: busy ? null : onRemove,
                  child: const Text('Gỡ'),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('wr_payment_voucher_input'),
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Nhập mã',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  key: const Key('wr_payment_voucher_apply'),
                  onPressed: busy ? null : onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WrColors.navy,
                    foregroundColor: WrColors.white,
                  ),
                  child: const Text('Áp dụng'),
                ),
              ],
            ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!,
                key: const Key('wr_payment_voucher_error'),
                style: const TextStyle(fontSize: 14.5, color: WrColors.coral)),
          ],
        ],
      ),
    );
  }
}

/// Đơn 0đ — thay chỗ của QR và khối ngân hàng.
///
/// Có nút bấm riêng chứ không chỉ tự chạy một lần lúc áp voucher: hoàn tất hụt
/// (mất mạng, lỗi server) mà không có đường thử lại thì người dùng kẹt cứng,
/// buộc phải gỡ voucher rồi áp lại mới mong chạy lại.
class _FreeOrderCard extends StatelessWidget {
  const _FreeOrderCard({
    required this.busy,
    required this.error,
    required this.onComplete,
  });

  final bool busy;
  final String? error;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return _Card(
      key: const Key('wr_payment_free_card'),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard, size: 34, color: WrColors.teal),
          const SizedBox(height: 10),
          const Text('Đơn này miễn phí',
              style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy)),
          const SizedBox(height: 4),
          const Text('Mã giảm giá đã trừ hết. Không cần chuyển khoản.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: WrColors.text3)),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!,
                key: const Key('wr_payment_free_error'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: WrColors.coral, height: 1.4)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('wr_payment_free_complete'),
              onPressed: busy ? null : onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                busy
                    ? 'Đang xử lý…'
                    : (error == null ? 'Nhận Premium' : 'Thử lại'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bảng gợi ý mã giảm giá. Trả về mã được chọn qua Navigator.pop.
class _VoucherListSheet extends StatefulWidget {
  const _VoucherListSheet({required this.load});

  final Future<List<WrVoucher>> Function() load;

  @override
  State<_VoucherListSheet> createState() => _VoucherListSheetState();
}

class _VoucherListSheetState extends State<_VoucherListSheet> {
  late final Future<List<WrVoucher>> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn mã giảm giá',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: WrColors.navy)),
            const SizedBox(height: 4),
            const Text('Những mã đang dùng được cho gói Premium.',
                style: TextStyle(fontSize: 14.5, color: WrColors.text3)),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: FutureBuilder<List<WrVoucher>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: CircularProgressIndicator(color: WrColors.coral),
                      ),
                    );
                  }
                  // Lỗi mạng cũng hiện như danh sách rỗng: ô nhập tay vẫn còn
                  // đó, không có lý do chặn người dùng lại.
                  final list = snap.data ?? const <WrVoucher>[];
                  if (list.isEmpty) {
                    return const Padding(
                      key: Key('wr_payment_voucher_list_empty'),
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text('Chưa có mã nào dành cho bạn lúc này.',
                            style: TextStyle(
                                fontSize: 15.5, color: WrColors.text3)),
                      ),
                    );
                  }
                  final now = DateTime.now();
                  return ListView.separated(
                    key: const Key('wr_payment_voucher_list'),
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _VoucherTile(
                      voucher: list[i],
                      reason: voucherIneligibleReason(list[i], now: now),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherTile extends StatelessWidget {
  const _VoucherTile({required this.voucher, required this.reason});

  final WrVoucher voucher;

  /// Lý do chưa dùng được; null nghĩa là dùng được.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final usable = reason == null;
    final maxUses = voucher.maxUses;
    return Opacity(
      // Mã hỏng vẫn hiện, chỉ mờ đi — biến mất không lời giải thích sẽ khiến
      // người dùng tưởng mình nhớ nhầm mã.
      opacity: usable ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WrColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voucher.code,
                      style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: WrColors.navy)),
                  const SizedBox(height: 2),
                  Text(voucherDiscountLabel(voucher),
                      style: const TextStyle(
                          fontSize: 14.5, color: WrColors.text2)),
                  if (voucher.validTo != null || (maxUses != null && maxUses > 0))
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        [
                          if (voucher.validTo != null)
                            'HSD ${_date(voucher.validTo!)}',
                          if (maxUses != null && maxUses > 0)
                            'còn ${maxUses - voucher.usedCount}/$maxUses lượt',
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 13.5, color: WrColors.text3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (usable)
              ElevatedButton(
                key: Key('wr_payment_voucher_pick_${voucher.code}'),
                onPressed: () => Navigator.of(context).pop(voucher.code),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.teal,
                  foregroundColor: WrColors.white,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Dùng'),
              )
            else
              Text(reason!,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: WrColors.muted)),
          ],
        ),
      ),
    );
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.order});
  final WrOrder order;

  @override
  Widget build(BuildContext context) {
    final url = buildVietQrUrl(orderCode: order.code, amount: order.finalAmount);
    return _Card(
      child: Column(
        children: [
          const Text('Mở app ngân hàng và quét mã',
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: WrColors.navy)),
          const SizedBox(height: 4),
          const Text('Số tiền và nội dung đã nằm sẵn trong mã',
              style: TextStyle(fontSize: 14, color: WrColors.text3)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              key: const Key('wr_payment_qr'),
              width: 220,
              height: 220,
              fit: BoxFit.contain,
              // Ảnh QR do VietQR sinh. Hỏng mạng thì vẫn còn khối thông tin
              // ngân hàng bên dưới để chuyển tay.
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 220,
                height: 220,
                child: Center(
                  child: Text(
                    'Không tải được mã QR.\nBạn chuyển khoản thủ công\ntheo thông tin bên dưới nhé.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, color: WrColors.text2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({
    required this.order,
    required this.copiedField,
    required this.onCopy,
  });

  final WrOrder order;
  final String? copiedField;
  final void Function(String value, String field) onCopy;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HOẶC CHUYỂN KHOẢN THỦ CÔNG',
              style: TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: WrColors.text3)),
          const SizedBox(height: 12),
          _row('Ngân hàng', WrBankInfo.bankName, null),
          _row('Số tài khoản', WrBankInfo.accountNumber, 'account'),
          _row('Chủ tài khoản', WrBankInfo.accountName, null),
          _row('Số tiền', order.finalAmount.round().toString(), 'amount'),
          _row('Nội dung', order.code, 'code'),
          const SizedBox(height: 10),
          const WrParagraph(
            'Giữ nguyên nội dung chuyển khoản. Sai nội dung là hệ thống không '
            'nhận ra đơn của bạn.',
            style: TextStyle(fontSize: 14, color: WrColors.coral, height: 1.4),
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, String? copyField) {
    final copied = copyField != null && copiedField == copyField;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(label,
                style: const TextStyle(fontSize: 14.5, color: WrColors.text3)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: WrColors.navy)),
          ),
          if (copyField != null)
            IconButton(
              key: Key('wr_payment_copy_$copyField'),
              visualDensity: VisualDensity.compact,
              icon: Icon(copied ? Icons.check : Icons.copy_rounded,
                  size: 17, color: copied ? WrColors.teal : WrColors.muted),
              onPressed: () => onCopy(value, copyField),
            ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.form, required this.onChanged});

  final WrInvoiceForm form;
  final ValueChanged<WrInvoiceForm> onChanged;

  @override
  Widget build(BuildContext context) {
    final err = form.validationError;
    return _Card(
      key: const Key('wr_payment_invoice'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Xuất hoá đơn VAT',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: WrColors.navy)),
              ),
              Switch(
                key: const Key('wr_payment_invoice_toggle'),
                value: form.requested,
                activeThumbColor: WrColors.coral,
                onChanged: (v) => onChanged(form.copyWith(requested: v)),
              ),
            ],
          ),
          if (form.requested) ...[
            const SizedBox(height: 4),
            const WrParagraph(
              'Hoá đơn phát hành sau khi thanh toán thành công và gửi vào email '
              'bạn điền ở đây.',
              style: TextStyle(fontSize: 14, color: WrColors.text3, height: 1.4),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 12),
            _field('Tên người mua', 'invoice_buyer', form.buyerName,
                (v) => onChanged(form.copyWith(buyerName: v))),
            _field('Địa chỉ', 'invoice_address', form.address,
                (v) => onChanged(form.copyWith(address: v))),
            _field('Tên đơn vị (nếu có)', 'invoice_legal', form.legalName,
                (v) => onChanged(form.copyWith(legalName: v))),
            _field('Mã số thuế (nếu có)', 'invoice_tax', form.taxCode,
                (v) => onChanged(form.copyWith(taxCode: v))),
            _field('Email nhận hoá đơn', 'invoice_email', form.email,
                (v) => onChanged(form.copyWith(email: v))),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(err,
                    key: const Key('wr_payment_invoice_error'),
                    style: const TextStyle(fontSize: 14.5, color: WrColors.coral)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _field(String label, String keyName, String value,
      ValueChanged<String> onChangedField) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        key: Key('wr_payment_$keyName'),
        initialValue: value,
        onChanged: onChangedField,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _WaitingNote extends StatelessWidget {
  const _WaitingNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: WrColors.muted),
        ),
        SizedBox(width: 10),
        Flexible(
          child: Text(
            'Đang chờ ngân hàng báo về. Bạn cứ để màn này mở.',
            style: TextStyle(fontSize: 14.5, color: WrColors.text3),
          ),
        ),
      ],
    );
  }
}

/// Đơn hết hạn. Bố cục theo `PaymentStatus.tsx` bên web: nêu rõ đơn nào,
/// bao nhiêu tiền, dịch vụ gì — rồi mới mời thử lại.
class _ExpiredView extends StatelessWidget {
  const _ExpiredView({required this.order, required this.onRetry, super.key});

  final WrOrder order;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1AD4A017),
              ),
              child: const Icon(Icons.schedule,
                  size: 38, color: WrColors.amber),
            ),
            const SizedBox(height: 18),
            const Text('Đơn hàng đã hết hạn',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: WrColors.navy)),
            const SizedBox(height: 8),
            Text(
              'Phiên thanh toán ${kPaymentWindow.inMinutes} phút đã kết thúc. '
              'Bạn tạo đơn mới rồi quét lại nhé.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15.5, color: WrColors.text2, height: 1.5),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: WrColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: WrColors.line),
              ),
              child: Column(
                children: [
                  _row('Mã đơn hàng', order.code),
                  _row('Số tiền', formatVndAmount(order.finalAmount)),
                  _row('Dịch vụ', 'Work Reflection Premium', last: true),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('wr_payment_expired_retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tạo đơn mới',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.coral,
                  foregroundColor: WrColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Để sau'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: WrColors.lineSoft)),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14.5, color: WrColors.text3)),
          const SizedBox(width: 16),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy)),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: WrColors.teal),
            const SizedBox(height: 18),
            const Text('Đã nhận được thanh toán',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: WrColors.navy)),
            const SizedBox(height: 10),
            const Text(
              'Premium đã mở. Toàn bộ phần khoá trước đây giờ dùng được ngay.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: WrColors.text2, height: 1.5),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('wr_payment_success_cta'),
                // Về thẳng Home, không lùi từng lớp.
                //
                // Chồng màn hình lúc này là: trang đang đứng → Paywall → màn
                // này. Pop một lớp thì rơi đúng vào trang mời mua, pop hai lớp
                // thì về trang cũ nhưng Paywall vẫn nằm trong lịch sử. `go`
                // thay cả chồng, nên bấm nút quay lại sau đó không thể lạc về
                // trang thanh toán hay Paywall nữa.
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.coral,
                  foregroundColor: WrColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Bắt đầu dùng',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
