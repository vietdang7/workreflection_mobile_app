// My Workshops screen — Phase 3 Task 11.
//
// Shows all the current user's workshop registrations, each paired with
// workshop detail. Tapping a row navigates to the workshop detail screen.
// Handles loading, error (with retry), and empty states.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/workshop_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../workshops_providers.dart';

class MyWorkshopsScreen extends ConsumerWidget {
  const MyWorkshopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final myAsync = ref.watch(myWorkshopsProvider);

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
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
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single row
// ---------------------------------------------------------------------------

class _MyWorkshopRow extends StatelessWidget {
  const _MyWorkshopRow({
    required this.registration,
    required this.workshop,
    required this.onTap,
  });

  final WorkshopRegistration registration;
  final WorkshopDetail? workshop;
  final VoidCallback onTap;

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = workshop?.title ?? '—';
    final date = workshop?.date;
    final status = _status();

    return GestureDetector(
      onTap: onTap,
      child: WrCardMinimal(
        child: Row(
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
