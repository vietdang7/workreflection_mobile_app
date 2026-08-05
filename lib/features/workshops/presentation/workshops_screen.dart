// Workshop list screen — Phase 3 Task 9.
//
// Shows all active public workshops as WrCardMinimal cards.
// Handles loading, error (with retry), and empty states.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/workshop_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../workshops_providers.dart';

class WorkshopsScreen extends ConsumerWidget {
  const WorkshopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workshopsAsync = ref.watch(activeWorkshopsProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.wsListTitle, style: WrTextStyles.hMedium),
      ),
      body: workshopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorCard(
          onRetry: () => ref.invalidate(activeWorkshopsProvider),
        ),
        data: (workshops) {
          if (workshops.isEmpty) {
            return Center(
              child: Text(l10n.wsEmpty, style: WrTextStyles.body),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            itemCount: workshops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _WorkshopCard(
                workshop: workshops[index],
                onTap: () => context.push('/workshops/${workshops[index].id}'),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single workshop card
// ---------------------------------------------------------------------------

class _WorkshopCard extends StatelessWidget {
  const _WorkshopCard({required this.workshop, required this.onTap});

  final WorkshopDetail workshop;
  final VoidCallback onTap;

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onTap,
      child: WrCardMinimal(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Optional image
            if (workshop.imageUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  workshop.imageUrl!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category eyebrow
                  if (workshop.category != null) ...[
                    WrEyebrow(workshop.category!),
                    const SizedBox(height: 6),
                  ],

                  // Title
                  Text(workshop.title, style: WrTextStyles.hMedium),
                  const SizedBox(height: 8),

                  // Date + location line
                  Text(
                    workshop.location != null
                        ? '${_formatDate(workshop.date)} · ${workshop.location}'
                        : _formatDate(workshop.date),
                    style: WrTextStyles.body,
                  ),
                  const SizedBox(height: 12),

                  // Chips row
                  Row(
                    children: [
                      // Price chip
                      _Chip(
                        label: workshop.isFree
                            ? l10n.wsFree
                            : _formatPrice(
                                workshop.price, workshop.currency),
                        backgroundColor: workshop.isFree
                            ? WrColors.teal.withValues(alpha: 0.1)
                            : WrColors.navy.withValues(alpha: 0.08),
                        textColor:
                            workshop.isFree ? WrColors.pillTealText : WrColors.dark,
                      ),

                      // Full badge
                      if (workshop.isFull) ...[
                        const SizedBox(width: 8),
                        _Chip(
                          label: l10n.wsFullBadge,
                          backgroundColor:
                              WrColors.destructive.withValues(alpha: 0.1),
                          textColor: WrColors.destructive,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(num price, String currency) {
    final f = NumberFormat('#,###', 'vi_VN');
    return '${f.format(price)} $currency';
  }
}

// ---------------------------------------------------------------------------
// Chip
// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: textColor,
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
