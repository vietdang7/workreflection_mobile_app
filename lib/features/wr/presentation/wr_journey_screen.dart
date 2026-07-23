import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_divider.dart';
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
  return repo.fetchMemoryEventsForUser(userId);
});

// ─────────────────────────────────────────────────────────────────────────────
// WrJourneyScreen
// ─────────────────────────────────────────────────────────────────────────────

class WrJourneyScreen extends ConsumerWidget {
  const WrJourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_memoryEventsProvider);
    final entitlementAsync = ref.watch(wrEntitlementProvider);

    final now = DateTime.now();
    final entitlement =
        entitlementAsync.valueOrNull ?? WrEntitlement(plan: WrPlan.free);
    final allEvents = eventsAsync.valueOrNull ?? const [];

    // Narrative counts (using full list, before truncation)
    final totalEvents = allEvents.length;
    const narrativeWindowDays = 30;
    final rawDays = (allEvents.isNotEmpty && allEvents.last.createdAt != null)
        ? now.difference(allEvents.last.createdAt!).inDays
        : 0;
    final daysSince = rawDays.clamp(0, narrativeWindowDays);
    final narrativeText =
        'Trong $daysSince ngày qua, bạn đã ghi nhận $totalEvents khoảnh khắc'
        ' trong Career Memory của mình.';

    // Free users see at most _kFreeMemoryLimit events; premium sees all.
    final events =
        (!entitlement.isPremium && allEvents.length > _kFreeMemoryLimit)
            ? allEvents.sublist(0, _kFreeMemoryLimit)
            : allEvents;

    // Timeline header month: from first event, else current month
    final timelineMonth = events.isNotEmpty && events.first.createdAt != null
        ? events.first.createdAt!.month
        : now.month;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Top area: "Career Memory" greeting + "Hành trình" title ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 20, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Career Memory',
                      style: TextStyle(
                        fontSize: 14,
                        color: WrColors.muted,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Hành trình',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: WrColors.navy,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Divider ───────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: WrSectionDivider(),
              ),
            ),

            // ── Section: CÂU CHUYỆN CỦA BẠN ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WrEyebrow('CÂU CHUYỆN CỦA BẠN'),
                    const SizedBox(height: 12),
                    // Insight quote style: 20px italic navy, height 1.45
                    Text(
                      narrativeText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        color: WrColors.navy,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Caption: 12px muted
                    Text(
                      'Career Companion · Tháng ${now.month}, ${now.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: WrColors.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Divider ───────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: WrSectionDivider(),
              ),
            ),

            // ── Section: Timeline THÁNG {M} ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                child: WrEyebrow('THÁNG $timelineMonth'),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

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
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      for (int i = 0; i < events.length; i++)
                        _TimelineItem(
                          event: events[i],
                          isLast: i == events.length - 1,
                        ),
                    ],
                  ),
                ),
              ),

            // ── Free lock banner ─────────────────────────────────────────
            if (!entitlement.isPremium && events.length >= _kFreeMemoryLimit)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: _LockBanner(
                    label: 'Xem toàn bộ Career Memory',
                    onTap: () => context.push('/wr/paywall'),
                  ),
                ),
              ),

            // ── Pattern deep-dive lock banner (always shown) ─────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                child: _LockBanner(
                  icon: '◈',
                  label: 'Phân tích mô thức chuyên sâu',
                  onTap: () => context.push('/wr/paywall'),
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
// Helper functions
// ─────────────────────────────────────────────────────────────────────────────

/// Dot color per event behavior/type.
Color _dotColor(CareerMemoryEvent e) {
  return switch (e.behavior) {
    'practice_step_done' => WrColors.teal,
    'practice_theme_done' => WrColors.teal,
    'insight' => const Color(0xFF5B8CC9),
    'decision' => WrColors.coral,
    _ => e.storyId != null
        ? const Color(0xFF5E7A5A)
        : e.situationCode != null
            ? WrColors.navy
            : WrColors.muted,
  };
}

/// Human-readable type label (uppercase per mockup).
String _eventTypeLabel(CareerMemoryEvent e) {
  if (e.behavior == 'practice_step_done' ||
      e.behavior == 'practice_theme_done') {
    return 'THỰC HÀNH';
  }
  if (e.behavior == 'insight') return 'INSIGHT';
  if (e.behavior == 'decision') return 'QUYẾT ĐỊNH';
  if (e.storyId != null) return 'PHẢN CHIẾU';
  if (e.situationCode != null) return 'TRẢI NGHIỆM';
  return 'GHI CHÚ';
}

/// Label color per event type.
Color _labelColor(CareerMemoryEvent e) {
  if (e.behavior == 'practice_step_done' ||
      e.behavior == 'practice_theme_done') {
    return WrColors.teal;
  }
  if (e.behavior == 'insight') return const Color(0xFF5B8CC9);
  if (e.behavior == 'decision') return WrColors.coral;
  if (e.storyId != null) return const Color(0xFF5E7A5A);
  if (e.situationCode != null) return WrColors.navy;
  return WrColors.muted;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Timeline item: dot + vertical connector line + content.
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.event, required this.isLast});
  final CareerMemoryEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final date = event.createdAt;
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '';
    final dot = _dotColor(event);
    final label = _eventTypeLabel(event);
    final labelColor = _labelColor(event);
    final title = event.reflectionText ?? event.emotion ?? '';
    // Body: show emotion when reflectionText is also present as title
    final body = (event.reflectionText != null &&
            event.reflectionText!.isNotEmpty &&
            event.emotion != null &&
            event.emotion!.isNotEmpty)
        ? event.emotion!
        : '';

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: dot + vertical line
          SizedBox(
            width: 11,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Dot (11×11 circle, marginTop 4 per CSS spec)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration:
                        BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                ),
                // Vertical connector (hidden for last item)
                if (!isLast)
                  Positioned(
                    left: 5,
                    top: 15,
                    bottom: -24,
                    child: Container(
                      width: 1,
                      color: WrColors.navy.withValues(alpha: 0.10),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right column: content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date: 12px muted
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: WrColors.muted,
                    ),
                  ),
                if (dateStr.isNotEmpty) const SizedBox(height: 2),
                // Title (h-medium): 16px w600 dark
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: WrColors.dark,
                    ),
                  ),
                // Body text: 14px dark 80% height 1.5
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 14,
                      color: WrColors.dark.withValues(alpha: 0.80),
                      height: 1.5,
                    ),
                  ),
                ],
                // Type label: 11px w700 colored per type
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
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
