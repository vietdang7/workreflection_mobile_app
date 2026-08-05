import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/l10n_ext.dart';
import '../../../core/models/timeline_event.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../l10n/app_localizations.dart';
import '../journey_providers.dart';

class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _JourneyHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StoryQuoteBlock(),
                  const SizedBox(height: 28),
                  _TimelineSection(),
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

class _JourneyHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.journeyGreeting, style: WrTextStyles.greeting),
          const SizedBox(height: 4),
          Text(l10n.journeyTitle, style: WrTextStyles.dateTitle),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Story quote block
// ---------------------------------------------------------------------------

class _StoryQuoteBlock extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final insightAsync = ref.watch(journeyLatestInsightProvider);

    return insightAsync.when(
      loading: () => const _LoadingCard(),
      error: (e, _) => _ErrorCard(
          onRetry: () => ref.invalidate(journeyLatestInsightProvider)),
      data: (insight) {
        final now = DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WrEyebrow(l10n.journeyEyebrowStory),
            const SizedBox(height: 12),
            Text(
              insight != null
                  ? '"${insight.content}"'
                  : '"Hành trình của bạn đang được ghi nhớ..."',
              style: WrTextStyles.insightQuote,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.journeyCaption(now.month, now.year),
              style: WrTextStyles.body.copyWith(
                fontSize: 13.5,
                color: WrColors.muted,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline section — grouped by month
// ---------------------------------------------------------------------------

class _TimelineSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(journeyTimelineProvider);

    return timelineAsync.when(
      loading: () => const _LoadingCard(),
      error: (e, _) =>
          _ErrorCard(onRetry: () => ref.invalidate(journeyTimelineProvider)),
      data: (events) {
        if (events.isEmpty) {
          return Container(
            key: const Key('journey_timeline_empty'),
            child: Text(
              'Chưa có sự kiện nào trong hành trình.',
              style: WrTextStyles.body,
            ),
          );
        }
        // Group events by (year, month) — events are ordered desc so reverse
        final grouped = <(int, int), List<TimelineEvent>>{};
        for (final e in events) {
          final key = (e.occurredAt.year, e.occurredAt.month);
          grouped.putIfAbsent(key, () => []).add(e);
        }
        // Sort groups descending
        final sortedKeys = grouped.keys.toList()
          ..sort((a, b) {
            final yearCmp = b.$1.compareTo(a.$1);
            if (yearCmp != 0) return yearCmp;
            return b.$2.compareTo(a.$2);
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sortedKeys.map((key) {
            final monthEvents = grouped[key]!;
            return _MonthGroup(
              month: key.$2,
              events: monthEvents,
            );
          }).toList(),
        );
      },
    );
  }
}

class _MonthGroup extends StatelessWidget {
  const _MonthGroup({required this.month, required this.events});
  final int month;
  final List<TimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(l10n.journeyEyebrowMonth(month)),
        const SizedBox(height: 24),
        ...events.map((e) => _TimelineItem(event: e)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.event});
  final TimelineEvent event;

  Color get _dotColor {
    return switch (event.eventType) {
      TimelineEventType.milestone => WrColors.teal,
      TimelineEventType.story => WrColors.coral,
      TimelineEventType.theme => WrColors.navy,
    };
  }

  String get _typeLabel {
    return switch (event.eventType) {
      TimelineEventType.milestone => 'MILESTONE',
      TimelineEventType.story => 'STORY',
      TimelineEventType.theme => 'THEME',
    };
  }

  String get _dotKey {
    final typeName = event.eventType.name; // 'milestone' | 'story' | 'theme'
    return 'tl_dot_${typeName}_${event.id}';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d/M').format(event.occurredAt);
    final dotColor = _dotColor;
    final typeLabel = _typeLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + connector column
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  key: Key(_dotKey),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                // Connector line
                Container(
                  width: 1,
                  height: 60,
                  color: WrColors.navy.withValues(alpha: 0.1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: WrTextStyles.body.copyWith(
                    fontSize: 13.5,
                    color: WrColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(event.title, style: WrTextStyles.hMedium),
                if (event.description != null) ...[
                  const SizedBox(height: 4),
                  Text(event.description!, style: WrTextStyles.body),
                ],
                const SizedBox(height: 6),
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: dotColor,
                    letterSpacing: 0.03 * 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final l10n = context.l10n;
    return Row(
      children: [
        Text(l10n.homeErrorLoadData, style: WrTextStyles.body),
        const SizedBox(width: 8),
        TextButton(onPressed: onRetry, child: Text(l10n.homeRetry)),
      ],
    );
  }
}
