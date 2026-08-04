// My coaching sessions screen — Phase 3 Task 15 / Phase 5 Task 6.
//
// Groups bookings from myBookingsProvider by status:
//   - upcoming:  status == 'scheduled'
//   - pending:   status == 'pending'  ← now shows "Đặt lịch" button
//   - history:   status == 'completed' | 'cancelled'
//
// Pending bookings (no scheduled_at) show a "Đặt lịch" button that pushes
// /coaching/schedule/:bookingId (Phase 5 Task 6 — scheduling now in-app).
// Meeting link row taps copy to clipboard and shows a SnackBar.
// Empty/error states handled.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/coaching_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../l10n/app_localizations.dart';
import '../coaching_providers.dart';

class CoachingSessionsScreen extends ConsumerWidget {
  const CoachingSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.coachMyTitle, style: WrTextStyles.hMedium),
      ),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorCard(
          onRetry: () => ref.invalidate(myBookingsProvider),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Text(l10n.coachMyEmpty, style: WrTextStyles.body),
            );
          }
          return _BookingsList(bookings: bookings);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bookings list
// ---------------------------------------------------------------------------

class _BookingsList extends StatelessWidget {
  const _BookingsList({required this.bookings});
  final List<CoachingBooking> bookings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final upcoming =
        bookings.where((b) => b.status == 'scheduled').toList();
    final pending =
        bookings.where((b) => b.status == 'pending').toList();
    final history = bookings
        .where((b) => b.status == 'completed' || b.status == 'cancelled')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (upcoming.isNotEmpty) ...[
            WrEyebrow(l10n.coachScheduled),
            const SizedBox(height: 12),
            ...upcoming.map((b) => _SessionRow(booking: b)),
            const SizedBox(height: 24),
          ],
          if (pending.isNotEmpty) ...[
            WrEyebrow(l10n.coachPending),
            const SizedBox(height: 12),
            ...pending.map((b) => _SessionRow(booking: b)),
            const SizedBox(height: 24),
          ],
          if (history.isNotEmpty) ...[
            WrEyebrow(l10n.coachCompleted),
            const SizedBox(height: 12),
            ...history.map((b) => _SessionRow(booking: b)),
            const SizedBox(height: 24),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session row
// ---------------------------------------------------------------------------

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.booking});
  final CoachingBooking booking;

  String _formatScheduledAt(DateTime? dt) {
    if (dt == null) return 'Chưa có lịch';
    return DateFormat('HH:mm dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final b = booking;
    final n = b.sessionNumber ?? 1;
    final total = b.totalSessions ?? 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WrColors.cream,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session x/y + status chip row
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.coachSessionOf(n, total),
                    style: WrTextStyles.hMedium,
                  ),
                ),
                _StatusChip(status: b.status),
              ],
            ),
            const SizedBox(height: 8),

            // Scheduled at
            if (b.status == 'scheduled') ...[
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: WrColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    _formatScheduledAt(b.scheduledAt),
                    style: WrTextStyles.body,
                  ),
                ],
              ),
            ],

            // "Đặt lịch" button for pending bookings
            if (b.status == 'pending') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: Key('scheduleBtn_${b.id}'),
                  icon: const Icon(Icons.calendar_today_outlined,
                      size: 16, color: WrColors.coral),
                  label: Text(
                    l10n.coachSchedButton,
                    style: const TextStyle(color: WrColors.coral),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: WrColors.coral),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () =>
                      context.push('/coaching/schedule/${b.id}'),
                ),
              ),
            ],

            // Meeting link
            if (b.meetingLink != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                key: const Key('meetingLinkRow'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: b.meetingLink!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text(AppLocalizations.of(context)!.wsLinkCopied)),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 16, color: WrColors.navy),
                    const SizedBox(width: 6),
                    Text(
                      l10n.coachMeetingLink,
                      style: WrTextStyles.body.copyWith(
                        color: WrColors.navy,
                        decoration: TextDecoration.underline,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final (label, color) = switch (status) {
      'scheduled' => (l10n.coachScheduled, WrColors.teal),
      'pending' => (l10n.coachPending, WrColors.navy),
      'completed' => (l10n.coachCompleted, WrColors.muted),
      'cancelled' => (l10n.coachCancelledStatus, WrColors.destructive),
      _ => (status, WrColors.muted),
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
            child: Text(AppLocalizations.of(context)!.homeRetry),
          ),
        ],
      ),
    );
  }
}
