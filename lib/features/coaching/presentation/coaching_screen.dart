// Coaching packages screen — Phase 3 Task 14 / Phase 5 Task 6.
//
// Sections:
//   1. Audience toggle (ChoiceChip) — filters packages by targetAudience
//   2. Package cards (WrCardMinimal) — name, sessions/duration, features,
//      price, CTA (free claim or paid dialog)
//   3. Coaches section — CircleAvatar, name, title, specializations, years exp
//   4. Reviews section — avg rating + up to 6 recent review cards (Phase 5)
//
// AppBar action: "Xem lịch của tôi" → pushes '/coaching/sessions'.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/data/coaching_repository.dart';
import '../../../core/models/coaching_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../coaching_providers.dart';

class CoachingScreen extends ConsumerStatefulWidget {
  const CoachingScreen({super.key});

  @override
  ConsumerState<CoachingScreen> createState() => _CoachingScreenState();
}

class _CoachingScreenState extends ConsumerState<CoachingScreen> {
  // null = show all; 'young' or 'manager'
  String? _audience;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final packagesAsync = ref.watch(coachingPackagesProvider);
    final coachesAsync = ref.watch(coachesProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.coachTitle, style: WrTextStyles.hMedium),
        actions: [
          TextButton.icon(
            key: const Key('coachViewMyBtn'),
            icon: const Icon(Icons.calendar_today_outlined,
                size: 16, color: WrColors.navy),
            label: Text(
              l10n.coachViewMy,
              style: const TextStyle(color: WrColors.navy),
            ),
            onPressed: () => context.push('/coaching/sessions'),
          ),
        ],
      ),
      body: packagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorCard(
          onRetry: () {
            ref.invalidate(coachingPackagesProvider);
            ref.invalidate(coachesProvider);
          },
        ),
        data: (packages) {
          return coachesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorCard(
              onRetry: () {
                ref.invalidate(coachingPackagesProvider);
                ref.invalidate(coachesProvider);
              },
            ),
            data: (coaches) => _Body(
              packages: packages,
              coaches: coaches,
              audience: _audience,
              onAudienceChanged: (v) => setState(() => _audience = v),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _Body extends ConsumerWidget {
  const _Body({
    required this.packages,
    required this.coaches,
    required this.audience,
    required this.onAudienceChanged,
  });

  final List<CoachingPackage> packages;
  final List<Coach> coaches;
  final String? audience;
  final ValueChanged<String?> onAudienceChanged;

  List<CoachingPackage> _filtered(List<CoachingPackage> all) {
    if (audience == null) return all;
    return all
        .where((p) =>
            p.targetAudience == null ||
            p.targetAudience == audience)
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _filtered(packages);
    final reviewsAsync = ref.watch(coachReviewsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Audience toggle ──────────────────────────────────────────────
          _AudienceToggle(
            selected: audience,
            onChanged: onAudienceChanged,
          ),
          const SizedBox(height: 24),

          // ── Package cards ────────────────────────────────────────────────
          if (visible.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.wsEmpty, style: WrTextStyles.body),
              ),
            )
          else
            ...visible.map(
              (pkg) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _PackageCard(pkg: pkg),
              ),
            ),

          const SizedBox(height: 8),

          // ── Coaches section ──────────────────────────────────────────────
          if (coaches.isNotEmpty) ...[
            WrEyebrow(l10n.coachOurCoaches),
            const SizedBox(height: 16),
            WrCardMinimal(
              child: Column(
                children: [
                  for (var i = 0; i < coaches.length; i++) ...[
                    _CoachRow(coach: coaches[i]),
                    if (i < coaches.length - 1)
                      const Divider(height: 24),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Reviews section ─────────────────────────────────────────────
          reviewsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (summary) {
              if (summary.totalCount == 0) return const SizedBox.shrink();
              return _ReviewsSection(summary: summary);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audience toggle
// ---------------------------------------------------------------------------

class _AudienceToggle extends StatelessWidget {
  const _AudienceToggle({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: 8,
      children: [
        _chip(
          label: l10n.coachAudienceYoung,
          value: 'young',
          selected: selected,
          onChanged: onChanged,
        ),
        _chip(
          label: l10n.coachAudienceManager,
          value: 'manager',
          selected: selected,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required String value,
    required String? selected,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(isSelected ? null : value),
      selectedColor: WrColors.navy,
      labelStyle: TextStyle(
        color: isSelected ? WrColors.white : WrColors.dark,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: WrColors.navy.withValues(alpha: 0.08),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    );
  }
}

// ---------------------------------------------------------------------------
// Package card
// ---------------------------------------------------------------------------

class _PackageCard extends ConsumerStatefulWidget {
  const _PackageCard({required this.pkg});
  final CoachingPackage pkg;

  @override
  ConsumerState<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends ConsumerState<_PackageCard> {
  bool _claiming = false;

  String _formatPrice(num price, String currency) {
    final f = NumberFormat('#,###', 'vi_VN');
    return '${f.format(price)} $currency';
  }

  Future<void> _onClaimFree() async {
    final l10n = AppLocalizations.of(context)!;

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.coachClaimConfirmTitle),
        content: Text(l10n.coachClaimConfirmBody(widget.pkg.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('claimOkBtn'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _claiming = true);
    try {
      final repo = ref.read(coachingRepositoryProvider);
      await repo.claimFreePackage(widget.pkg);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.coachClaimSuccess)),
      );
      ref.invalidate(myBookingsProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.coachClaimError)),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  void _onPaid() {
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
    final pkg = widget.pkg;
    final duration = pkg.durationMinutes ?? 60;

    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(pkg.name, style: WrTextStyles.hMedium),
          const SizedBox(height: 4),

          // Sessions fmt
          Text(
            l10n.coachSessionsFmt(pkg.sessionsCount, duration),
            style: WrTextStyles.body,
          ),
          const SizedBox(height: 12),

          // Features bullet list
          if (pkg.features.isNotEmpty) ...[
            ...pkg.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: WrColors.muted)),
                    Expanded(child: Text(f, style: WrTextStyles.body)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Price
          Text(
            pkg.isFree
                ? l10n.wsFree
                : _formatPrice(pkg.price, pkg.currency),
            style: WrTextStyles.hMedium.copyWith(
              color: WrColors.navy,
            ),
          ),
          const SizedBox(height: 16),

          // CTA
          if (pkg.isFree)
            WrPillButton(
              label: l10n.coachClaimFree,
              onPressed: _claiming ? null : _onClaimFree,
              isLoading: _claiming,
            )
          else
            WrPillButton(
              label: l10n.wsRegister,
              onPressed: _onPaid,
              variant: WrPillVariant.coral,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coach row
// ---------------------------------------------------------------------------

class _CoachRow extends StatelessWidget {
  const _CoachRow({required this.coach});
  final Coach coach;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = coach;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        CircleAvatar(
          radius: 28,
          backgroundColor: WrColors.navy.withValues(alpha: 0.1),
          backgroundImage: c.avatarUrl != null
              ? NetworkImage(c.avatarUrl!)
              : null,
          child: c.avatarUrl == null
              ? Text(
                  c.initials,
                  style: const TextStyle(
                    color: WrColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.fullName, style: WrTextStyles.hMedium),
              if (c.title != null) ...[
                const SizedBox(height: 2),
                Text(c.title!, style: WrTextStyles.body),
              ],
              if (c.specializations.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  c.specializations.join(' · '),
                  style: WrTextStyles.body.copyWith(color: WrColors.muted),
                ),
              ],
              if (c.experienceYears != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.coachYearsExp(c.experienceYears!),
                  style: WrTextStyles.body.copyWith(color: WrColors.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reviews section
// ---------------------------------------------------------------------------

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.summary});
  final CoachReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final avg = summary.avgRating.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: eyebrow + avg rating badge
        Row(
          children: [
            Expanded(child: WrEyebrow(l10n.coachReviewsTitle)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: WrColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 14, color: WrColors.pillTealText),
                  const SizedBox(width: 4),
                  Text(
                    '$avg/5.0',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.pillTealText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Review cards
        ...summary.reviews.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReviewCard(review: r),
            )),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final CoachReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WrColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Star row
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < review.rating.round()
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 16,
                color: WrColors.teal,
              );
            }),
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"${review.comment}"',
              style:
                  WrTextStyles.body.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: WrColors.navy.withValues(alpha: 0.1),
                child: Text(
                  review.reviewerName.isNotEmpty
                      ? review.reviewerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                review.reviewerName,
                style: WrTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600),
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
