import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/development_theme.dart';
import '../../../core/models/practice.dart';
import '../../../core/models/workshop.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../develop_providers.dart';

class DevelopScreen extends ConsumerWidget {
  const DevelopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _DevelopHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ThemeFocusSection(),
                  const SizedBox(height: 28),
                  _PracticesSection(),
                  const SizedBox(height: 28),
                  _OpportunitySection(),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _DevelopHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.developGreeting, style: WrTextStyles.greeting),
          const SizedBox(height: 4),
          Text(l10n.developTitle, style: WrTextStyles.dateTitle),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme focus card (WrCardDark)
// ---------------------------------------------------------------------------

class _ThemeFocusSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(activeThemeProvider);

    return themeAsync.when(
      loading: () => const _LoadingCard(),
      error: (e, _) =>
          _ErrorCard(onRetry: () => ref.invalidate(activeThemeProvider)),
      data: (theme) {
        if (theme == null) {
          final l10n = AppLocalizations.of(context)!;
          return Container(
            key: const Key('develop_no_theme'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WrColors.cream,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l10n.developNoTheme,
              style: WrTextStyles.body,
            ),
          );
        }
        return _ThemeCard(theme: theme);
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme});
  final DevelopmentTheme theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return WrCardDark(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(l10n.developEyebrowFocus),
          const SizedBox(height: 8),
          Text(
            theme.code,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: WrColors.white,
              letterSpacing: -0.03 * 40,
            ),
          ),
          Text(
            theme.title,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xB3FFFFFF), // white 70%
            ),
          ),
          const SizedBox(height: 16),
          WrProgressTrack(
            value: theme.progress,
            color: WrColors.white,
            trackColor: WrColors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.developStage(theme.stage, theme.totalStages),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0x80FFFFFF), // white 50%
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Practices list
// ---------------------------------------------------------------------------

class _PracticesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final practicesAsync = ref.watch(practicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.developEyebrowPractices),
        const SizedBox(height: 12),
        practicesAsync.when(
          loading: () => const _LoadingCard(),
          error: (e, _) =>
              _ErrorCard(onRetry: () => ref.invalidate(practicesProvider)),
          data: (practices) {
            if (practices.isEmpty) {
              return Text(l10n.developNoPractices, style: WrTextStyles.body);
            }
            return Column(
              children: practices
                  .map((p) => _PracticeRow(practice: p))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PracticeRow extends ConsumerWidget {
  const _PracticeRow({required this.practice});
  final Practice practice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDone = practice.status == PracticeStatus.done;

    Color iconColor;
    IconData iconData;
    String statusLabel;
    Color statusColor;

    switch (practice.status) {
      case PracticeStatus.done:
        iconColor = WrColors.teal;
        iconData = Icons.check_circle_outline;
        statusLabel = l10n.developStatusDone;
        statusColor = WrColors.teal;
      case PracticeStatus.doing:
        iconColor = WrColors.coral;
        iconData = Icons.play_circle_outline;
        statusLabel = l10n.developStatusDoing;
        statusColor = WrColors.coral;
      case PracticeStatus.todo:
        iconColor = WrColors.muted;
        iconData = Icons.radio_button_unchecked;
        statusLabel = l10n.developStatusTodo;
        statusColor = WrColors.muted;
    }

    return GestureDetector(
      onTap: isDone
          ? null
          : () => ref.read(practicesProvider.notifier).advanceStatus(practice.id),
      child: Opacity(
        opacity: isDone ? 0.45 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iconData, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      practice.title,
                      style: isDone
                          ? WrTextStyles.hMedium.copyWith(
                              decoration: TextDecoration.lineThrough,
                            )
                          : WrTextStyles.hMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Opportunity (workshop) card
// ---------------------------------------------------------------------------

class _OpportunitySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workshopAsync = ref.watch(upcomingWorkshopProvider);

    return workshopAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (workshop) {
        if (workshop == null) return const SizedBox.shrink();
        return _OpportunityCard(workshop: workshop, l10n: l10n);
      },
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.workshop, required this.l10n});
  final Workshop workshop;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.developEyebrowOpportunity),
        const SizedBox(height: 12),
        // Opportunity card uses r16 per HTML .opp-card spec (not the standard r20 card)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WrColors.cream,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: WrColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mic_none_outlined,
                  color: WrColors.navy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.developWorkshopTag.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: WrColors.teal,
                        letterSpacing: 0.04 * 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(workshop.title,
                        style: WrTextStyles.hMedium.copyWith(fontSize: 15)),
                    const SizedBox(height: 6),
                    WrActionLink(
                      label: l10n.developWorkshopLink,
                      onTap: () => context.push('/workshops/${workshop.id}'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        WrActionLink(
          key: const Key('develop_view_workshops'),
          label: l10n.developViewWorkshops,
          onTap: () => context.push('/workshops'),
        ),
        const SizedBox(height: 8),
        WrActionLink(
          key: const Key('develop_view_coaching'),
          label: l10n.developViewCoaching,
          onTap: () => context.push('/coaching'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(l10n.developErrorLoadData, style: WrTextStyles.body),
        const SizedBox(width: 8),
        TextButton(onPressed: onRetry, child: Text(l10n.homeRetry)),
      ],
    );
  }
}
