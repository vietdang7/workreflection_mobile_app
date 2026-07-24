import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/action_link.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/tab_back_link.dart';
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
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Map emotion string → tiếng Việt (dùng cho cả title fallback và body).
String _emotionLabel(String? emotion) => switch (emotion) {
      'low' => 'Mệt mỏi',
      'ok' => 'Ổn',
      'good' => 'Vui',
      _ => emotion ?? '',
    };

/// Map HumanNeed → label tiếng Việt ngắn (dùng cho chip chủ đề).
String _humanNeedLabel(HumanNeed need) => switch (need) {
      HumanNeed.roRang => 'Rõ ràng',
      HumanNeed.ketNoi => 'Kết nối',
      HumanNeed.thichNghi => 'Thích nghi',
      HumanNeed.phatTrien => 'Phát triển',
    };

// ─────────────────────────────────────────────────────────────────────────────
// WrJourneyScreen
// ─────────────────────────────────────────────────────────────────────────────

class WrJourneyScreen extends ConsumerWidget {
  const WrJourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_memoryEventsProvider);
    final entitlementAsync = ref.watch(wrEntitlementProvider);
    final situationsAsync = ref.watch(wrSituationsProvider);
    final patternsAsync = ref.watch(wrPatternCountsProvider);

    final now = DateTime.now();
    final entitlement =
        entitlementAsync.valueOrNull ?? WrEntitlement(plan: WrPlan.free);
    final allEvents = eventsAsync.valueOrNull ?? const [];
    final situations = situationsAsync.valueOrNull ?? const [];
    final patterns = patternsAsync.valueOrNull ?? const [];

    // sitMap: code → display text
    final sitMap = {for (final s in situations) s.code: s.text};

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

    // Stats by event type
    final statExperience =
        allEvents.where((e) => e.situationCode != null).length;
    final statReflection = allEvents.where((e) => e.storyId != null).length;
    final statPractice = allEvents
        .where((e) =>
            e.behavior == 'practice_step_done' ||
            e.behavior == 'practice_theme_done')
        .length;
    final statInsight =
        allEvents.where((e) => e.behavior == 'insight').length;
    final hasStats =
        statExperience > 0 || statReflection > 0 || statPractice > 0 || statInsight > 0;

    // Top 3 patterns for "CHỦ ĐỀ LẶP LẠI" section
    final topPatterns = patterns.take(3).toList();
    final maxCount = topPatterns.isEmpty
        ? 1.0
        : topPatterns.first.occurrenceCount.toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Top area: "Career Memory" greeting + "Hành trình" title ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    WrTabBackLink(currentTab: WrTab.journey),
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

                    // Task C: Stats theo loại (chỉ hiện khi có ít nhất 1 loại)
                    if (hasStats) ...[
                      const SizedBox(height: 20),
                      _StatsRow(
                        key: const Key('journey_stats_row'),
                        experience: statExperience,
                        reflection: statReflection,
                        practice: statPractice,
                        insight: statInsight,
                      ),
                    ],

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

            // ── Task B: Section CHỦ ĐỀ LẶP LẠI ──────────────────────────
            if (topPatterns.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  child: _RecurringThemesSection(
                    patterns: topPatterns,
                    sitMap: sitMap,
                    maxCount: maxCount,
                    onViewDiscover: () => context.go('/wr/discover'),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: WrSectionDivider(),
                ),
              ),
            ],

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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
                  child: _EmptyMemoryCard(
                    onCreateFirst: () => context.go('/home'),
                  ),
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
                          sitMap: sitMap,
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

/// Task C: Hàng stats đếm event theo loại.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    super.key,
    required this.experience,
    required this.reflection,
    required this.practice,
    required this.insight,
  });

  final int experience;
  final int reflection;
  final int practice;
  final int insight;

  @override
  Widget build(BuildContext context) {
    final items = <({int count, String label})>[
      if (experience > 0) (count: experience, label: 'Trải nghiệm'),
      if (reflection > 0) (count: reflection, label: 'Phản chiếu'),
      if (practice > 0) (count: practice, label: 'Thực hành'),
      if (insight > 0) (count: insight, label: 'Insight'),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    final dividerColor = WrColors.navy.withValues(alpha: 0.12);

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 32,
              color: dividerColor,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${items[i].count}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: WrColors.navy,
                  height: 1.1,
                ),
              ),
              Text(
                items[i].label,
                style: const TextStyle(
                  fontSize: 11,
                  color: WrColors.muted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Task B: Section "CHỦ ĐỀ LẶP LẠI".
class _RecurringThemesSection extends StatelessWidget {
  const _RecurringThemesSection({
    required this.patterns,
    required this.sitMap,
    required this.maxCount,
    required this.onViewDiscover,
  });

  final List<PatternCount> patterns;
  final Map<String, String> sitMap;
  final double maxCount;
  final VoidCallback onViewDiscover;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WrEyebrow('CHỦ ĐỀ LẶP LẠI'),
        const SizedBox(height: 12),
        ...patterns.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final name = sitMap[p.situationCode] ?? p.situationCode ?? '?';
          final Color countColor;
          final FontWeight countWeight;
          final Color trackColor;
          if (i == 0) {
            countColor = WrColors.coral;
            countWeight = FontWeight.w700;
            trackColor = WrColors.coral;
          } else if (i == 1) {
            countColor = WrColors.teal;
            countWeight = FontWeight.w600;
            trackColor = WrColors.navy;
          } else {
            countColor = WrColors.muted;
            countWeight = FontWeight.w600;
            trackColor = WrColors.navy.withValues(alpha: 0.4);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                    Text(
                      '${p.occurrenceCount} lần',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: countWeight,
                        color: countColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                WrProgressTrack(
                  value: maxCount > 0 ? p.occurrenceCount / maxCount : 0,
                  color: trackColor,
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        WrActionLink(
          label: 'Xem trong Hiểu mình',
          onTap: onViewDiscover,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Timeline item: dot + vertical connector line + content.
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.sitMap,
  });
  final CareerMemoryEvent event;
  final bool isLast;
  final Map<String, String> sitMap;

  @override
  Widget build(BuildContext context) {
    final date = event.createdAt;
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '';
    final dot = _dotColor(event);
    final label = _eventTypeLabel(event);
    final labelColor = _labelColor(event);

    // Task A: Title ưu tiên situationCode → reflectionText → emotion (tiếng Việt)
    final String title;
    if (event.situationCode != null) {
      title = sitMap[event.situationCode] ?? event.situationCode!;
    } else if (event.reflectionText != null &&
        event.reflectionText!.isNotEmpty) {
      title = event.reflectionText!;
    } else {
      title = _emotionLabel(event.emotion);
    }

    // Body: hiện emotion (tiếng Việt) khi title không phải emotion
    final String body;
    if (event.emotion != null && event.emotion!.isNotEmpty) {
      final emotionVn = _emotionLabel(event.emotion);
      // Chỉ hiện body nếu title khác với emotion label
      body = (title != emotionVn) ? emotionVn : '';
    } else {
      body = '';
    }

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
                // Type label row (với chip humanNeed nếu có)
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: labelColor,
                      ),
                    ),
                    // Task A: Chip chủ đề từ humanNeed
                    if (event.humanNeed != null) ...[
                      const SizedBox(width: 8),
                      _HumanNeedChip(need: event.humanNeed!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip pill nhỏ hiển thị humanNeed label.
class _HumanNeedChip extends StatelessWidget {
  const _HumanNeedChip({required this.need});
  final HumanNeed need;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: WrColors.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _humanNeedLabel(need),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: WrColors.navy,
        ),
      ),
    );
  }
}

/// Task D: Empty state mới với grid 2×2 + nút.
class _EmptyMemoryCard extends StatelessWidget {
  const _EmptyMemoryCard({required this.onCreateFirst});
  final VoidCallback onCreateFirst;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Career Memory trống',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: WrColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mỗi lần phản chiếu sẽ tạo ra một mảnh ký ức nghề nghiệp được lưu tại đây.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF737373),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          // Grid 2×2 loại sự kiện
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: const [
              _TypeCard(icon: '◎', title: 'Trải nghiệm', desc: 'Điều bạn gặp mỗi ngày'),
              _TypeCard(icon: '◈', title: 'Phản chiếu', desc: 'Từ câu chuyện bạn đọc'),
              _TypeCard(icon: '✦', title: 'Thực hành', desc: 'Bước bạn hoàn thành'),
              _TypeCard(icon: '◇', title: 'Insight', desc: 'Góc nhìn thay đổi'),
            ],
          ),
          const SizedBox(height: 16),
          // Nút full-width navy
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onCreateFirst,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: WrColors.navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Tạo Memory đầu tiên →',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: WrColors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ loại sự kiện trong grid empty state.
class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.desc,
  });
  final String icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WrColors.navy.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: WrColors.dark,
            ),
          ),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 10,
              color: WrColors.muted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
