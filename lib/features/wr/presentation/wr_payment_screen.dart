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

import '../../../core/data/payment_repository.dart';
import '../../../core/logic/wr_payment.dart';
import '../../../core/logic/wr_pricing.dart';
import '../../../core/theme/wr_colors.dart';
import '../../profile/profile_providers.dart';
import '../wr_providers.dart';

class WrPaymentScreen extends ConsumerStatefulWidget {
  const WrPaymentScreen({super.key});

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
    final pricing = await ref.read(wrPremiumPricingProvider.future);

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
      final order = await ref.read(paymentRepositoryProvider).createPremiumOrder(
            productId: pricing.productId!,
            amount: pricing.currentPrice,
            currency: pricing.currency,
          );
      if (!mounted) return;
      setState(() {
        _order = order;
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

  /// Đơn 0đ: không có gì để chuyển khoản, tự hoàn tất.
  Future<void> _completeFree() async {
    final order = _order;
    if (order == null) return;
    try {
      await ref.read(paymentRepositoryProvider).completeFreeOrder(order.id);
      _onPaid();
    } catch (e) {
      if (!mounted) return;
      setState(() => _voucherError = 'Không hoàn tất được đơn. Thử lại giúp mình.');
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
      return _Message(
        key: const Key('wr_payment_expired'),
        text: 'Đơn hàng đã hết hạn sau ${kPaymentWindow.inMinutes} phút.\n'
            'Bạn quay lại và bấm nâng cấp lần nữa nhé.',
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
        ),
        const SizedBox(height: 14),
        _QrCard(order: order),
        const SizedBox(height: 14),
        _BankCard(
          order: order,
          copiedField: _copiedField,
          onCopy: _copy,
        ),
        const SizedBox(height: 14),
        _InvoiceCard(form: _invoice, onChanged: _updateInvoice),
        const SizedBox(height: 18),
        const _WaitingNote(),
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
          style: const TextStyle(fontSize: 15, color: WrColors.text2, height: 1.5),
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
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: urgent ? WrColors.coral : WrColors.teal,
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
                  fontSize: 11,
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
                      fontSize: 15,
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
  });

  final TextEditingController controller;
  final String? appliedCode;
  final String? error;
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final applied = appliedCode;
    return _Card(
      key: const Key('wr_payment_voucher'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MÃ GIẢM GIÁ',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: WrColors.text3)),
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
                          fontSize: 14,
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
                style: const TextStyle(fontSize: 13, color: WrColors.coral)),
          ],
        ],
      ),
    );
  }
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WrColors.navy)),
          const SizedBox(height: 4),
          const Text('Số tiền và nội dung đã nằm sẵn trong mã',
              style: TextStyle(fontSize: 12.5, color: WrColors.text3)),
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
                    style: TextStyle(fontSize: 13, color: WrColors.text2),
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
                  fontSize: 11,
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
          const Text(
            'Giữ nguyên nội dung chuyển khoản. Sai nội dung là hệ thống không '
            'nhận ra đơn của bạn.',
            style: TextStyle(fontSize: 12.5, color: WrColors.coral, height: 1.4),
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
                style: const TextStyle(fontSize: 13, color: WrColors.text3)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14,
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
                        fontSize: 14.5,
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
            const Text(
              'Hoá đơn phát hành sau khi thanh toán thành công và gửi vào email '
              'bạn điền ở đây.',
              style: TextStyle(fontSize: 12.5, color: WrColors.text3, height: 1.4),
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
                    style: const TextStyle(fontSize: 13, color: WrColors.coral)),
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
            style: TextStyle(fontSize: 13, color: WrColors.text3),
          ),
        ),
      ],
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
              style: TextStyle(fontSize: 14.5, color: WrColors.text2, height: 1.5),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('wr_payment_success_cta'),
                onPressed: () => Navigator.of(context).maybePop(),
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
