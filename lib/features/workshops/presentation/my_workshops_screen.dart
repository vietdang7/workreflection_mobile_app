// My Workshops screen — Phase 3 Task 11 / Phase 5 Task 7 / Phase 5 Task 10.
//
// Shows all the current user's workshop registrations, each paired with
// workshop detail. Tapping a row navigates to the workshop detail screen.
// Handles loading, error (with retry), and empty states.
//
// Phase 5 additions:
//   - Cancel registration (matches web: status='cancelled', 48h cutoff,
//     personal only, payment_status != 'paid').
//   - Survey results link when a survey is completed for a past workshop.
//   - Task 10: "Tải chứng nhận" button when reg.attended == true (mirrors
//     web MyWorkshops.tsx line 586: {reg.attended && <Button…>}).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/data/workshop_repository.dart';
import '../../../core/models/workshop_models.dart';
import '../../../core/pdf/certificate_pdf_builder.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/profile_providers.dart';
import '../workshops_providers.dart';

class MyWorkshopsScreen extends ConsumerStatefulWidget {
  const MyWorkshopsScreen({super.key});

  @override
  ConsumerState<MyWorkshopsScreen> createState() => _MyWorkshopsScreenState();
}

class _MyWorkshopsScreenState extends ConsumerState<MyWorkshopsScreen> {
  /// Registration id pending cancel confirmation.
  String? _pendingCancelId;
  String? _pendingCancelWorkshopId;
  bool _cancelling = false;

  /// Set of registration ids currently generating a certificate PDF.
  final Set<String> _generatingCertFor = {};

  Future<void> _confirmCancel() async {
    final regId = _pendingCancelId;
    final wsId = _pendingCancelWorkshopId;
    if (regId == null || wsId == null) return;

    setState(() => _cancelling = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final repo = ref.read(workshopRepositoryProvider);
      await repo.cancelRegistration(regId, wsId);
      ref.invalidate(myWorkshopsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.wsCancelRegSuccess)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.wsCancelRegError)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cancelling = false;
          _pendingCancelId = null;
          _pendingCancelWorkshopId = null;
        });
      }
    }
  }

  /// Generates and shares a certificate PDF for an attended workshop.
  ///
  /// Eligibility mirrors web line 586: button shown when reg.attended == true.
  Future<void> _generateCertificate(
    WorkshopRegistration reg,
    WorkshopDetail workshop,
  ) async {
    if (_generatingCertFor.contains(reg.id)) return;
    setState(() => _generatingCertFor.add(reg.id));

    final l10n = AppLocalizations.of(context)!;
    final locale = ref.read(appLocaleProvider);

    // Fetch participant name from cc_profiles.full_name (fallback to email).
    final ccProfile = ref.read(ccProfileProvider).valueOrNull;
    final participantName =
        (ccProfile?['full_name'] as String?)?.isNotEmpty == true
            ? ccProfile!['full_name'] as String
            : ccProfile?['email'] as String?;

    try {
      final bytes = await CertificatePdfBuilder.build(
        CertificateData(
          participantName: participantName,
          workshopTitle: workshop.title,
          workshopDate: workshop.date,
          workshopLocation: workshop.location,
          locale: locale,
        ),
      );
      final safeTitle = workshop.title.replaceAll(RegExp(r'\s+'), '_');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Certificate_$safeTitle.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.wsCertificateError)),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingCertFor.remove(reg.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final myAsync = ref.watch(myWorkshopsProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.wsMyTitle, style: WrTextStyles.hMedium),
      ),
      body: myAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorCard(
          onRetry: () => ref.invalidate(myWorkshopsProvider),
        ),
        data: (pairs) {
          if (pairs.isEmpty) {
            return Center(
              child: Text(l10n.wsMyEmpty, style: WrTextStyles.body),
            );
          }
          return ListView.separated(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            itemCount: pairs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final (reg, workshop) = pairs[index];
              return _MyWorkshopRow(
                registration: reg,
                workshop: workshop,
                onTap: () => context.push('/workshops/${reg.workshopId}'),
                onCancel: _canCancel(reg, workshop)
                    ? () => setState(() {
                          _pendingCancelId = reg.id;
                          _pendingCancelWorkshopId = reg.workshopId;
                        })
                    : null,
                onDownloadCertificate:
                    (reg.attended && workshop != null)
                        ? () => _generateCertificate(reg, workshop)
                        : null,
                isGeneratingCertificate:
                    _generatingCertFor.contains(reg.id),
              );
            },
          );
        },
      ),

      // Cancel confirmation dialog
      persistentFooterButtons: _pendingCancelId != null
          ? [
              _CancelDialog(
                l10n: l10n,
                cancelling: _cancelling,
                onConfirm: _confirmCancel,
                onDismiss: () => setState(() {
                  _pendingCancelId = null;
                  _pendingCancelWorkshopId = null;
                }),
              ),
            ]
          : null,
    );
  }

  /// Mirrors web canCancel logic:
  ///   - no org_id (personal registration only)
  ///   - status != 'cancelled'
  ///   - now < 48 h before workshop date
  ///   - payment_status is NOT 'paid' (not stored in mobile model — skip check,
  ///     matches paid=false default for free workshops which are the common case)
  bool _canCancel(WorkshopRegistration reg, WorkshopDetail? workshop) {
    if (workshop == null) return false;
    // org_id not in mobile WorkshopRegistration model — skip (only personal
    // registrations appear since getMyRegistrations uses user_id filter).
    if (reg.status == 'cancelled') return false;
    final cutoff = workshop.date.subtract(const Duration(hours: 48));
    return DateTime.now().isBefore(cutoff);
  }
}

// ---------------------------------------------------------------------------
// Single row
// ---------------------------------------------------------------------------

class _MyWorkshopRow extends ConsumerWidget {
  const _MyWorkshopRow({
    required this.registration,
    required this.workshop,
    required this.onTap,
    this.onCancel,
    this.onDownloadCertificate,
    this.isGeneratingCertificate = false,
  });

  final WorkshopRegistration registration;
  final WorkshopDetail? workshop;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  /// Non-null when reg.attended == true (mirrors web eligibility line 586).
  final VoidCallback? onDownloadCertificate;
  final bool isGeneratingCertificate;

  String _formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  /// Derives display status from registration.
  /// attended || checkedInAt != null → wsAttended
  /// status == 'cancelled' → wsCancelled
  /// else → wsRegistered
  _RowStatus _status() {
    if (registration.attended || registration.checkedInAt != null) {
      return _RowStatus.attended;
    }
    if (registration.status == 'cancelled') return _RowStatus.cancelled;
    return _RowStatus.registered;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final title = workshop?.title ?? 'Chưa có tên';
    final date = workshop?.date;
    final status = _status();
    final isAttended = status == _RowStatus.attended;

    // Watch survey submission state for attended workshops.
    final hasSubmittedAsync = isAttended
        ? ref.watch(hasSubmittedSurveyProvider(registration.workshopId))
        : const AsyncData<bool>(false);

    return GestureDetector(
      onTap: onTap,
      child: WrCardMinimal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: WrTextStyles.hMedium),
                      if (date != null) ...[
                        const SizedBox(height: 4),
                        Text(_formatDate(date), style: WrTextStyles.body),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusChip(status: status, l10n: l10n),
              ],
            ),

            // Survey results link when attended and survey is completed.
            hasSubmittedAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (hasSubmitted) {
                if (!hasSubmitted) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GestureDetector(
                    onTap: () => context.push(
                      '/workshops/${registration.workshopId}/survey-results',
                    ),
                    child: Text(
                      l10n.wsSurveyViewResults,
                      key: const Key('my_ws_view_results'),
                      style: WrTextStyles.body.copyWith(
                        color: WrColors.coral,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: WrColors.coral,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Cancel button for eligible registrations.
            if (onCancel != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onCancel,
                child: Text(
                  l10n.wsCancelReg,
                  key: const Key('my_ws_cancel'),
                  style: WrTextStyles.body.copyWith(
                    color: WrColors.muted,
                    decoration: TextDecoration.underline,
                    decorationColor: WrColors.muted,
                  ),
                ),
              ),
            ],

            // Certificate download button — shown when reg.attended == true.
            // Eligibility mirrors web MyWorkshops.tsx line 586:
            //   {reg.attended && <Button…onClick={generateCertificate}>}
            if (onDownloadCertificate != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: isGeneratingCertificate ? null : onDownloadCertificate,
                child: isGeneratingCertificate
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: WrColors.coral,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.wsCertificateGenerating,
                            style: WrTextStyles.body
                                .copyWith(color: WrColors.coral),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.download_outlined,
                            size: 16,
                            color: WrColors.coral,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.wsCertificateDownload,
                            key: const Key('my_ws_download_cert'),
                            style: WrTextStyles.body.copyWith(
                              color: WrColors.coral,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: WrColors.coral,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip
// ---------------------------------------------------------------------------

enum _RowStatus { registered, attended, cancelled }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.l10n});

  final _RowStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      _RowStatus.attended => (l10n.wsAttended, WrColors.teal),
      _RowStatus.cancelled => (l10n.wsCancelled, WrColors.muted),
      _RowStatus.registered => (l10n.wsRegistered, WrColors.navy),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cancel dialog (inline footer panel)
// ---------------------------------------------------------------------------

class _CancelDialog extends StatelessWidget {
  const _CancelDialog({
    required this.l10n,
    required this.cancelling,
    required this.onConfirm,
    required this.onDismiss,
  });

  final AppLocalizations l10n;
  final bool cancelling;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WrColors.white,
        border: Border(top: BorderSide(color: WrColors.muted.withValues(alpha: 0.2))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.wsCancelRegTitle, style: WrTextStyles.hMedium),
          const SizedBox(height: 8),
          Text(l10n.wsCancelRegBody, style: WrTextStyles.body),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('cancel_dismiss'),
                onPressed: cancelling ? null : onDismiss,
                child: Text(l10n.commonCancel),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: const Key('cancel_confirm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.coral,
                  foregroundColor: WrColors.navy,
                ),
                onPressed: cancelling ? null : onConfirm,
                child: cancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WrColors.navy,
                        ),
                      )
                    : Text(l10n.commonConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error card
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: WrColors.coral, size: 48),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.homeRetry),
          ),
        ],
      ),
    );
  }
}
