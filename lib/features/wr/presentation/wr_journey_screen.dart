import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../wr_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Free tier: show at most 10 memory events before showing lock banner.
const _kFreeMemoryLimit = 10;

// ─────────────────────────────────────────────────────────────────────────────
// Local providers
// ─────────────────────────────────────────────────────────────────────────────

final _memoryEventsProvider =
    FutureProvider<List<CareerMemoryEvent>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrContentRepositoryProvider);
  // Fetch all events; screen truncates to _kFreeMemoryLimit for free users.
  // Avoids sequential async dependency on wrEntitlementProvider.
  return repo.fetchMemoryEventsForUser(userId);
});

final _patternCountsProvider =
    FutureProvider<List<PatternCount>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchPatternCounts(userId);
});

final _situationsProvider =
    FutureProvider<List<WrSituation>>((ref) async {
  final repo = ref.watch(wrContentRepositoryProvider);
  return repo.fetchSituations();
});

// ─────────────────────────────────────────────────────────────────────────────
// WrJourneyScreen
// ─────────────────────────────────────────────────────────────────────────────

class WrJourneyScreen extends ConsumerWidget {
  const WrJourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_memoryEventsProvider);
    final patternsAsync = ref.watch(_patternCountsProvider);
    final situationsAsync = ref.watch(_situationsProvider);
    final entitlementAsync = ref.watch(wrEntitlementProvider);

    final entitlement =
        entitlementAsync.valueOrNull ?? WrEntitlement(plan: WrPlan.free);
    final allEvents = eventsAsync.valueOrNull ?? const [];
    // Free users see at most _kFreeMemoryLimit events; premium sees all.
    final events = (!entitlement.isPremium && allEvents.length > _kFreeMemoryLimit)
        ? allEvents.sublist(0, _kFreeMemoryLimit)
        : allEvents;
    final patterns = patternsAsync.valueOrNull ?? const [];
    final situations = situationsAsync.valueOrNull ?? const [];

    // Map situation code → text for pattern display
    final sitMap = {for (final s in situations) s.code: s.text};

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 12, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hành trình',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFA3A3A3),
                        letterSpacing: 0.02,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Career Memory',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: WrColors.dark,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Section: Hành trình của bạn ─────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 0, 22, 8),
                child: Text(
                  'HÀNH TRÌNH CỦA BẠN',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFA3A3A3),
                    letterSpacing: 0.08,
                  ),
                ),
              ),
            ),

            if (eventsAsync.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: LinearProgressIndicator(),
                ),
              )
            else if (events.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 0, 22, 4),
                  child: _EmptyMemoryCard(),
                ),
              )
            else ...[
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                    child: _MemoryEventCard(event: events[i]),
                  ),
                  childCount: events.length,
                ),
              ),
              // Free lock banner when exactly at limit
              if (!entitlement.isPremium && events.length >= _kFreeMemoryLimit)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
                    child: _LockBanner(
                      label: 'Xem toàn bộ Career Memory',
                      onTap: () => context.push('/wr/paywall'),
                    ),
                  ),
                ),
            ],

            // ── Section: Mô thức của bạn ────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 16, 22, 8),
                child: Text(
                  'MÔ THỨC CỦA BẠN',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFA3A3A3),
                    letterSpacing: 0.08,
                  ),
                ),
              ),
            ),

            if (patternsAsync.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: LinearProgressIndicator(),
                ),
              )
            else if (patterns.where((p) => p.occurrenceCount >= 2).isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 0, 22, 0),
                  child: Text(
                    'Chưa có mô thức — tiếp tục phản chiếu để nhìn thấy xu hướng.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF737373),
                      height: 1.6,
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final p = patterns
                        .where((p) => p.occurrenceCount >= 2)
                        .toList()[i];
                    final text = p.situationCode != null
                        ? sitMap[p.situationCode] ?? p.situationCode!
                        : '—';
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                      child: _PatternRow(text: text, count: p.occurrenceCount),
                    );
                  },
                  childCount:
                      patterns.where((p) => p.occurrenceCount >= 2).length,
                ),
              ),

            // Pattern deep-dive lock card (always shown)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                child: _LockBanner(
                  icon: '◈',
                  label: 'Phân tích mô thức chuyên sâu',
                  onTap: () => context.push('/wr/paywall'),
                ),
              ),
            ),

            // ── Section: Hồ sơ nghề nghiệp ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
                child: GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: WrColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x0F000000)),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: const Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 18, color: WrColors.dark),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Hồ sơ nghề nghiệp',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: WrColors.dark,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 16, color: Color(0xFFA3A3A3)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyMemoryCard extends StatelessWidget {
  const _EmptyMemoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Career Memory trống',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: WrColors.dark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Mỗi lần phản chiếu sẽ tạo ra một mảnh ký ức nghề nghiệp được lưu tại đây.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF737373),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dot color per event behavior/type.
Color _dotColor(CareerMemoryEvent e) {
  return switch (e.behavior) {
    'practice_step_done' => WrColors.teal,
    'practice_theme_done' => WrColors.teal,
    'insight' => const Color(0xFF5B8CC9),
    'decision' => WrColors.coral,
    _ => e.storyId != null
        ? const Color(0xFF5E7A5A)
        : const Color(0xFFA3A3A3),
  };
}

/// Human-readable type label.
String _eventTypeLabel(CareerMemoryEvent e) {
  if (e.behavior == 'practice_step_done' ||
      e.behavior == 'practice_theme_done') {
    return 'Thực hành';
  }
  if (e.situationCode != null) return 'Trải nghiệm';
  if (e.storyId != null) return 'Phản chiếu';
  if (e.behavior == 'insight') return 'Insight';
  if (e.behavior == 'decision') return 'Quyết định';
  return 'Ghi chú';
}

class _MemoryEventCard extends StatelessWidget {
  const _MemoryEventCard({required this.event});
  final CareerMemoryEvent event;

  @override
  Widget build(BuildContext context) {
    final date = event.createdAt;
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '';
    final dot = _dotColor(event);
    final typeLabel = _eventTypeLabel(event);
    final content = event.reflectionText ?? event.emotion ?? '';

    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored dot
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x0D000000),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF737373),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFA3A3A3),
                      ),
                    ),
                  ],
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: WrColors.dark,
                      height: 1.55,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternRow extends StatelessWidget {
  const _PatternRow({required this.text, required this.count});
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '«$text»',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: WrColors.dark,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$count lần',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF737373),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockBanner extends StatelessWidget {
  const _LockBanner({
    required this.label,
    required this.onTap,
    this.icon,
  });
  final String label;
  final VoidCallback onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 0.7,
        child: Container(
          decoration: BoxDecoration(
            color: WrColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x0F000000)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Text(icon!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: WrColors.dark,
                  ),
                ),
              ),
              const Text(
                '⭐ Premium',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD4A017),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
