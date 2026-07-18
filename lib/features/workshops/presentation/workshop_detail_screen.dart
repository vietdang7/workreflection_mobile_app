// Workshop detail screen — Phase 3 Task 10.
//
// Sections: header image, category eyebrow, title, date/time, location,
// participants count, description, price, CTA area, resources section.
//
// CTA logic:
//   - no registration + isFree + !isFull  → Register button (free)
//   - no registration + !isFree            → Register button → paid dialog
//   - no registration + isFull             → disabled full button
//   - registered + checkedInAt==null       → status chip + Check-in button
//   - registered + checkedInAt!=null       → status chip + survey area
// Resources: shown when registered + attachments non-empty; locked text when
//   not registered + attachments non-empty; hidden when attachments empty.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/data/workshop_repository.dart';
import '../../../core/models/workshop_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../workshops_providers.dart';

class WorkshopDetailScreen extends ConsumerWidget {
  const WorkshopDetailScreen({super.key, required this.workshopId});

  final String workshopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(workshopDetailProvider(workshopId));
    final registrationAsync = ref.watch(myRegistrationProvider(workshopId));

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.wsListTitle, style: WrTextStyles.hMedium),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorCard(
          onRetry: () {
            ref.invalidate(workshopDetailProvider(workshopId));
            ref.invalidate(myRegistrationProvider(workshopId));
          },
        ),
        data: (workshop) {
          if (workshop == null) {
            return Center(child: Text(l10n.wsEmpty, style: WrTextStyles.body));
          }
          return registrationAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorCard(
              onRetry: () {
                ref.invalidate(workshopDetailProvider(workshopId));
                ref.invalidate(myRegistrationProvider(workshopId));
              },
            ),
            data: (registration) => _DetailBody(
              workshopId: workshopId,
              workshop: workshop,
              registration: registration,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail body
// ---------------------------------------------------------------------------

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({
    required this.workshopId,
    required this.workshop,
    required this.registration,
  });

  final String workshopId;
  final WorkshopDetail workshop;
  final WorkshopRegistration? registration;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _registering = false;

  String _formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  String _formatTime(DateTime d) => DateFormat('HH:mm').format(d);

  String _formatPrice(num price, String currency) {
    final f = NumberFormat('#,###', 'vi_VN');
    return '${f.format(price)} $currency';
  }

  Future<void> _registerFree() async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(workshopRepositoryProvider);
    setState(() => _registering = true);
    try {
      await repo.registerFree(widget.workshopId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.wsRegisterSuccess)),
      );
      ref.invalidate(myRegistrationProvider(widget.workshopId));
      ref.invalidate(workshopDetailProvider(widget.workshopId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.wsRegisterError)),
      );
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  void _showPaidDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.wsPaidDialogTitle),
        content: Text(l10n.wsPaidDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.wsPaidDialogOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final w = widget.workshop;
    final reg = widget.registration;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header image
          if (w.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                w.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          const SizedBox(height: 16),

          // Category eyebrow
          if (w.category != null) ...[
            WrEyebrow(w.category!),
            const SizedBox(height: 6),
          ],

          // Title
          Text(w.title, style: WrTextStyles.hLarge),
          const SizedBox(height: 12),

          // Date/time row
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            text: w.startsAt != null && w.endsAt != null
                ? '${_formatDate(w.date)} · ${_formatTime(w.startsAt!)} – ${_formatTime(w.endsAt!)}'
                : _formatDate(w.date),
          ),

          // Location
          if (w.location != null) ...[
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.location_on_outlined, text: w.location!),
          ],

          // Participants count
          if (w.maxParticipants != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.people_outline,
              text: l10n.wsParticipants(
                  w.currentParticipants, w.maxParticipants!),
            ),
          ],

          const SizedBox(height: 16),

          // Description
          if (w.description != null) ...[
            Text(w.description!, style: WrTextStyles.body),
            const SizedBox(height: 16),
          ],

          // Price line
          Text(
            w.isFree
                ? l10n.wsFree
                : _formatPrice(w.price, w.currency),
            style: WrTextStyles.hMedium.copyWith(
              color: w.isFree ? WrColors.teal : WrColors.navy,
            ),
          ),

          const SizedBox(height: 24),

          // CTA area
          _CtaArea(
            workshopId: widget.workshopId,
            workshop: w,
            registration: reg,
            registering: _registering,
            onRegisterFree: _registerFree,
            onRegisterPaid: _showPaidDialog,
          ),

          const SizedBox(height: 32),

          // Resources section
          _ResourcesSection(
            workshopId: widget.workshopId,
            registration: reg,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CTA area
// ---------------------------------------------------------------------------

class _CtaArea extends ConsumerWidget {
  const _CtaArea({
    required this.workshopId,
    required this.workshop,
    required this.registration,
    required this.registering,
    required this.onRegisterFree,
    required this.onRegisterPaid,
  });

  final String workshopId;
  final WorkshopDetail workshop;
  final WorkshopRegistration? registration;
  final bool registering;
  final VoidCallback onRegisterFree;
  final VoidCallback onRegisterPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // No registration branch
    if (registration == null) {
      if (workshop.isFull) {
        return WrPillButton(
          label: l10n.wsFullBadge,
          onPressed: null,
        );
      }
      if (workshop.isFree) {
        return WrPillButton(
          label: l10n.wsRegister,
          onPressed: registering ? null : onRegisterFree,
          isLoading: registering,
        );
      }
      // Paid
      return WrPillButton(
        label: l10n.wsRegister,
        onPressed: onRegisterPaid,
        variant: WrPillVariant.coral,
      );
    }

    // Registered branch
    final reg = registration!;
    final isCheckedIn = reg.checkedInAt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status chip
        _StatusChip(registration: reg, l10n: l10n),
        const SizedBox(height: 16),

        // Check-in button (only when not yet checked in)
        if (!isCheckedIn)
          WrPillButton(
            label: l10n.wsCheckin,
            onPressed: () => context.push('/workshops/checkin'),
          ),

        // Survey area (only when checked in)
        if (isCheckedIn) ...[
          _SurveyArea(workshopId: workshopId),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.registration, required this.l10n});

  final WorkshopRegistration registration;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isAttended =
        registration.attended || registration.checkedInAt != null;
    final label = isAttended ? l10n.wsAttended : l10n.wsRegistered;
    final color = isAttended ? WrColors.teal : WrColors.navy;

    String chipLabel = label;
    if (isAttended && registration.checkedInAt != null) {
      final time =
          DateFormat('HH:mm dd/MM').format(registration.checkedInAt!);
      chipLabel = l10n.wsCheckedInAt(time);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        chipLabel,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Survey area
// ---------------------------------------------------------------------------

class _SurveyArea extends ConsumerWidget {
  const _SurveyArea({required this.workshopId});

  final String workshopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasSubmittedAsync = ref.watch(hasSubmittedSurveyProvider(workshopId));

    return hasSubmittedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (hasSubmitted) {
        if (hasSubmitted) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.wsSurveyDone, style: WrTextStyles.body),
              const SizedBox(height: 8),
              WrActionLink(
                key: const Key('ws_detail_view_results'),
                label: l10n.wsSurveyViewResults,
                onTap: () => context
                    .push('/workshops/$workshopId/survey-results'),
              ),
            ],
          );
        }
        return WrActionLink(
          label: l10n.wsSurveyCta,
          onTap: () => context.push('/workshops/$workshopId/survey'),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Resources section
// ---------------------------------------------------------------------------

class _ResourcesSection extends ConsumerWidget {
  const _ResourcesSection({
    required this.workshopId,
    required this.registration,
  });

  final String workshopId;
  final WorkshopRegistration? registration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final attachmentsAsync =
        ref.watch(workshopAttachmentsProvider(workshopId));

    return attachmentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (attachments) {
        // Hide entirely when empty AND registered (nothing to show)
        if (attachments.isEmpty && registration != null) {
          return const SizedBox.shrink();
        }
        // Hide entirely when empty AND not registered
        if (attachments.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WrEyebrow(l10n.wsResources),
            const SizedBox(height: 12),

            if (registration == null) ...[
              Text(l10n.wsResourcesLocked, style: WrTextStyles.body),
            ] else ...[
              WrCardMinimal(
                child: Column(
                  children: [
                    for (final att in attachments) ...[
                      _AttachmentRow(attachment: att),
                      if (att != attachments.last)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Attachment row
// ---------------------------------------------------------------------------

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment});

  final WorkshopAttachment attachment;

  IconData get _icon => switch (attachment.category) {
        'image' => Icons.image_outlined,
        'video' => Icons.videocam_outlined,
        _ => Icons.insert_drive_file_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_icon, color: WrColors.navy),
      title: Text(attachment.fileName, style: WrTextStyles.body),
      onTap: () async {
        final l10n = AppLocalizations.of(context)!;
        await Clipboard.setData(ClipboardData(text: attachment.fileUrl));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.wsLinkCopied)),
          );
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Info row
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: WrColors.muted),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: WrTextStyles.body)),
      ],
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
