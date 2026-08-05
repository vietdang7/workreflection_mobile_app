// Coaching schedule screen — Phase 5 Task 6.
//
// Route: /coaching/schedule/:bookingId
//
// Mirrors web CoachingSchedule.tsx exactly:
//   - Calendar picker starting from tomorrow.
//   - Static TIME_SLOTS chips (9:00 … 16:00).
//   - Optional notes field.
//   - On confirm: UPDATE cc_coaching_bookings via repo.scheduleBooking().
//   - On success: invalidate myBookingsProvider, pop back.
//
// No cc_coach_availability table is consulted (web doesn't use one either).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/coaching_repository.dart';
import '../../../core/logic/coaching_schedule_logic.dart';
import '../../../core/models/coaching_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../coaching_providers.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CoachingScheduleScreen extends ConsumerStatefulWidget {
  const CoachingScheduleScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<CoachingScheduleScreen> createState() =>
      _CoachingScheduleScreenState();
}

class _CoachingScheduleScreenState
    extends ConsumerState<CoachingScheduleScreen> {
  final _today = DateTime.now();
  late int _month;
  late int _year;
  String? _selectedDate;
  String? _selectedTime;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Start on tomorrow's month.
    final tomorrow = _today.add(const Duration(days: 1));
    _month = tomorrow.month;
    _year = tomorrow.year;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Navigation
  // --------------------------------------------------------------------------

  void _prevMonth() {
    if (!canGoPrevMonth(_year, _month, _today)) return;
    final (y, m) = prevMonth(_year, _month);
    setState(() {
      _year = y;
      _month = m;
    });
  }

  void _nextMonth() {
    final (y, m) = nextMonth(_year, _month);
    setState(() {
      _year = y;
      _month = m;
    });
  }

  // --------------------------------------------------------------------------
  // Submit
  // --------------------------------------------------------------------------

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.coachSchedPickDate)),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.coachSchedPickTime)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.coachSchedConfirmTitle),
        content: Text(
          l10n.coachSchedConfirmBody(
            _selectedDate!.split('-').reversed.join('/'),
            _selectedTime!,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('scheduleConfirmBtn'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(coachingRepositoryProvider);
      await repo.scheduleBooking(
        bookingId: widget.bookingId,
        date: _selectedDate!,
        time: _selectedTime!,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      ref.invalidate(myBookingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.coachSchedSuccess)),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.coachSchedError)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bookingAsync = ref.watch(myBookingsProvider);

    // Find this booking to verify it exists and is schedulable.
    final booking = bookingAsync.valueOrNull?.cast<CoachingBooking?>().firstWhere(
          (b) => b?.id == widget.bookingId,
          orElse: () => null,
        );

    // If loading show spinner; if not found show error.
    if (bookingAsync.isLoading) {
      return Scaffold(
        backgroundColor: WrColors.pageBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (booking == null) {
      return Scaffold(
        backgroundColor: WrColors.pageBg,
        appBar: AppBar(
          backgroundColor: WrColors.pageBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: WrColors.navy),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(l10n.coachSchedNotFound, style: WrTextStyles.body),
        ),
      );
    }

    final cells = buildCalendarCells(
      year: _year,
      month: _month,
      today: _today,
    );

    final monthLabel = _monthName(l10n, _month);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.coachSchedTitle, style: WrTextStyles.hMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session info chip
            _SessionInfo(booking: booking),
            const SizedBox(height: 20),

            // --- Calendar card ---
            _SectionCard(
              icon: Icons.calendar_today_outlined,
              title: l10n.coachSchedChooseDate,
              child: Column(
                children: [
                  // Month nav
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: canGoPrevMonth(_year, _month, _today)
                            ? _prevMonth
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          '$monthLabel $_year',
                          textAlign: TextAlign.center,
                          style: WrTextStyles.hMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Weekday headers
                  Row(
                    children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                        .map(
                          (d) => Expanded(
                            child: Text(
                              d,
                              textAlign: TextAlign.center,
                              style: WrTextStyles.body.copyWith(
                                color: WrColors.muted,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  // Calendar grid
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    children: cells.map((cell) {
                      if (cell == null) {
                        return const SizedBox.shrink();
                      }
                      final isSelected = _selectedDate == cell.dateKey;
                      return GestureDetector(
                        onTap: cell.isSelectable
                            ? () => setState(
                                () => _selectedDate = cell.dateKey)
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? WrColors.coral
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${cell.date.day}',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: !cell.isSelectable
                                  ? WrColors.muted.withValues(alpha: 0.4)
                                  : isSelected
                                      ? WrColors.white
                                      : WrColors.navy,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.coachSchedSelectedDate} ${_selectedDate!.split('-').reversed.join('/')}',
                      style:
                          WrTextStyles.body.copyWith(color: WrColors.muted),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- Time slots card ---
            _SectionCard(
              icon: Icons.access_time_outlined,
              title: l10n.coachSchedChooseTime,
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
                children: kTimeSlots.map((slot) {
                  final isSelected = _selectedTime == slot;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTime = slot),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? WrColors.coral : WrColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: WrColors.line),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        slot,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // --- Notes card ---
            _SectionCard(
              icon: Icons.notes_outlined,
              title: l10n.coachSchedNotes,
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.coachSchedNotesHint,
                  hintStyle:
                      WrTextStyles.body.copyWith(color: WrColors.muted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: WrColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: WrColors.coral),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Submit button ---
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                key: const Key('scheduleSubmitBtn'),
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.coral,
                  foregroundColor: WrColors.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WrColors.white,
                        ),
                      )
                    : Text(
                        l10n.coachSchedSubmit,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _monthName(AppLocalizations l10n, int month) {
    const names = [
      '', // index 0 unused
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12',
    ];
    return names[month];
  }
}

// ---------------------------------------------------------------------------
// Session info row
// ---------------------------------------------------------------------------

class _SessionInfo extends StatelessWidget {
  const _SessionInfo({required this.booking});
  final CoachingBooking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final n = booking.sessionNumber ?? 1;
    final total = booking.totalSessions ?? 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: WrColors.navy.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        l10n.coachSessionOf(n, total),
        style: WrTextStyles.body.copyWith(
          color: WrColors.navy,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section card wrapper
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WrColors.white,
        border: Border.all(color: WrColors.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: WrColors.navy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: WrColors.coral),
              const SizedBox(width: 8),
              Text(title, style: WrTextStyles.hMedium),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
