import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final vouchersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(wrRepositoryProvider).getVouchers();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VouchersScreen extends ConsumerStatefulWidget {
  const VouchersScreen({super.key});

  @override
  ConsumerState<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends ConsumerState<VouchersScreen> {
  String? _copiedId;

  void _copyCode(String code, String id) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copiedId = id);
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.voucherCopiedToast(code))),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedId = null);
    });
  }

  String _formatDate(String? raw) {
    if (raw == null) return 'Chưa có';
    final d = DateTime.tryParse(raw);
    if (d == null) return 'Chưa có';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(vouchersProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: const BackButton(color: WrColors.navy),
        title: Text(l10n.vouchersTitle, style: WrTextStyles.hMedium),
        centerTitle: false,
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: WrColors.coral)),
        error: (_, __) => Center(
          child: Text(l10n.vouchersEmpty, style: WrTextStyles.body),
        ),
        data: (vouchers) => _VouchersList(
          vouchers: vouchers,
          copiedId: _copiedId,
          onCopy: _copyCode,
          formatDate: _formatDate,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List body
// ---------------------------------------------------------------------------

class _VouchersList extends StatelessWidget {
  const _VouchersList({
    required this.vouchers,
    required this.copiedId,
    required this.onCopy,
    required this.formatDate,
  });

  final List<Map<String, dynamic>> vouchers;
  final String? copiedId;
  final void Function(String code, String id) onCopy;
  final String Function(String? raw) formatDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Web-note banner
        Container(
          width: double.infinity,
          color: WrColors.coral.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: WrColors.coral, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.voucherWebNote,
                  style: WrTextStyles.body
                      .copyWith(fontSize: 12, color: WrColors.coral),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: vouchers.isEmpty
              ? _EmptyState(l10n: l10n)
              : ListView.builder(
                  key: const Key('vouchers_list'),
                  padding: const EdgeInsets.all(16),
                  itemCount: vouchers.length,
                  itemBuilder: (ctx, i) => _VoucherCard(
                    key: Key('voucher_${vouchers[i]['id']}'),
                    voucher: vouchers[i],
                    copiedId: copiedId,
                    onCopy: onCopy,
                    formatDate: formatDate,
                  ),
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: WrColors.navy.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.confirmation_number_outlined,
                color: WrColors.muted, size: 32),
          ),
          const SizedBox(height: 16),
          Text(l10n.vouchersEmpty,
              style: WrTextStyles.hMedium.copyWith(color: WrColors.navy)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.vouchersEmptyBody,
              style: WrTextStyles.body.copyWith(color: WrColors.muted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voucher card
// ---------------------------------------------------------------------------

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    super.key,
    required this.voucher,
    required this.copiedId,
    required this.onCopy,
    required this.formatDate,
  });

  final Map<String, dynamic> voucher;
  final String? copiedId;
  final void Function(String code, String id) onCopy;
  final String Function(String? raw) formatDate;

  bool get _isExpired {
    final raw = voucher['valid_to'] as String?;
    if (raw == null) return false;
    return DateTime.tryParse(raw)?.isBefore(DateTime.now()) ?? false;
  }

  bool get _isFull {
    final maxUses = (voucher['max_uses'] as num?)?.toInt() ?? 0;
    final usedCount = (voucher['used_count'] as num?)?.toInt() ?? 0;
    return maxUses > 0 && usedCount >= maxUses;
  }

  bool get _isAvailable => !_isExpired && !_isFull;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final id = voucher['id'] as String? ?? '';
    final code = voucher['code'] as String? ?? '';
    final discountType = voucher['discount_type'] as String? ?? 'percentage';
    final discountPercent =
        (voucher['discount_percent'] as num?)?.toInt() ?? 0;
    final discountAmount = (voucher['discount_amount'] as num?) ?? 0;
    final maxUses = (voucher['max_uses'] as num?)?.toInt() ?? 0;
    final usedCount = (voucher['used_count'] as num?)?.toInt() ?? 0;
    final applicable =
        (voucher['applicable_products'] as List?)?.cast<String>() ?? [];
    final validTo = voucher['valid_to'] as String?;

    final isCopied = copiedId == id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: _isAvailable ? 1 : 0,
      color: _isAvailable ? WrColors.white : WrColors.navy.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: ticket icon + code + status badge
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isAvailable
                        ? WrColors.coral.withValues(alpha: 0.1)
                        : WrColors.navy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.confirmation_number_outlined,
                    size: 20,
                    color: _isAvailable ? WrColors.coral : WrColors.muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: WrTextStyles.hMedium.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 1.5,
                          color: _isAvailable
                              ? WrColors.navy
                              : WrColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        discountType == 'percentage'
                            ? l10n.voucherDiscountPercent(discountPercent)
                            : l10n.voucherDiscountAmount(
                                discountAmount.toStringAsFixed(0)),
                        style: WrTextStyles.body
                            .copyWith(fontSize: 12, color: WrColors.muted),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  isExpired: _isExpired,
                  isFull: _isFull,
                  l10n: l10n,
                ),
              ],
            ),

            // Applicable products
            if (applicable.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: applicable.map((s) {
                  final labels = {
                    'premium': l10n.voucherProductPremium,
                    'workshop': l10n.voucherProductWorkshop,
                    'coaching': l10n.voucherProductCoaching,
                  };
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: WrColors.coral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      labels[s] ?? s,
                      style: WrTextStyles.body.copyWith(
                          fontSize: 10, color: WrColors.pillCoralText),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Bottom row: expiry + uses + copy button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.voucherExpiry(formatDate(validTo)),
                        style: WrTextStyles.body
                            .copyWith(fontSize: 12, color: WrColors.muted),
                      ),
                      if (maxUses > 0)
                        Text(
                          l10n.voucherUsesLeft(
                              maxUses - usedCount, maxUses),
                          style: WrTextStyles.body.copyWith(
                              fontSize: 12, color: WrColors.muted),
                        ),
                    ],
                  ),
                ),
                if (_isAvailable)
                  ElevatedButton.icon(
                    key: Key('voucher_copy_$id'),
                    onPressed: () => onCopy(code, id),
                    icon: Icon(
                      isCopied ? Icons.check : Icons.copy_outlined,
                      size: 14,
                    ),
                    label: Text(
                      isCopied ? l10n.voucherCopied : l10n.voucherCopy,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WrColors.coral,
                      foregroundColor: WrColors.navy,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.isExpired,
    required this.isFull,
    required this.l10n,
  });

  final bool isExpired;
  final bool isFull;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    if (isExpired) {
      bg = WrColors.muted.withValues(alpha: 0.12);
      fg = WrColors.muted;
      label = l10n.voucherExpired;
    } else if (isFull) {
      bg = WrColors.muted.withValues(alpha: 0.12);
      fg = WrColors.muted;
      label = l10n.voucherFull;
    } else {
      bg = Colors.green.withValues(alpha: 0.1);
      fg = Colors.green.shade700;
      label = l10n.voucherAvailable;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: WrTextStyles.body.copyWith(fontSize: 11, color: fg)),
    );
  }
}
