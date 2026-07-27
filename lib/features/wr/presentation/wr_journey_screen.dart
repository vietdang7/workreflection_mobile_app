// Hành trình — Memory Surface (WXS §8.4).
//
// Nguồn chính của dòng thời gian là Reflection Episode: mỗi Episode đã khép
// lại là một đơn vị ý nghĩa hoàn chỉnh (WXS §1.6), có khoảnh khắc, có điều
// nhận ra, có bước nhỏ. Các sự kiện Career Memory khác (thực hành, kỹ năng,
// insight rời) được trộn vào theo thời gian.
//
// Episode đã tự ghi một memory event `reflection_episode` khi khép lại, nên
// khi đọc được Episode thì loại các event đó ra để không đếm hai lần.
//
// Màn này chỉ liệt kê. Bấm vào một lần nhìn lại mới mở màn đọc riêng.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_episode.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_link_row.dart';
import '../wr_providers.dart';

/// Bản ghi hiển thị trên dòng thời gian — Episode hoặc Career Memory event.
class JourneyEntry {
  const JourneyEntry({
    required this.at,
    required this.label,
    required this.title,
    required this.color,
    this.subtitle,
    this.episodeId,
  });

  final DateTime? at;
  final String label;
  final String title;
  final String? subtitle;
  final Color color;

  /// Có id nghĩa là bấm vào mở được màn đọc riêng.
  final String? episodeId;
}

/// Free tier: hiện tối đa 10 mục trước khi mời mở bản đầy đủ.
const int kFreeJourneyLimit = 10;

/// Mã behavior mà Episode ghi vào Career Memory khi khép lại.
const String kEpisodeBehavior = 'reflection_episode';

/// Dựng dòng thời gian từ Episode + Career Memory event, mới nhất trước.
///
/// Chỉ Episode đã khép lại mới vào Hành trình — WDA Inv.6: chưa có ý nghĩa
/// thì chưa phải ký ức nghề nghiệp.
List<JourneyEntry> buildJourneyEntries({
  required List<ReflectionEpisode> episodes,
  required List<CareerMemoryEvent> events,
  required Map<String, String> situationLabels,
}) {
  final entries = <JourneyEntry>[];

  final closed = episodes
      .where((e) => e.state == ExperienceState.integrated)
      .toList(growable: false);

  for (final e in closed) {
    entries.add(JourneyEntry(
      at: e.closedAt ?? e.updatedAt ?? e.openedAt,
      label: 'PHẢN TƯ',
      title: e.draftMeaning?.trim().isNotEmpty == true
          ? e.draftMeaning!.trim()
          : e.humanMoment.label,
      subtitle: e.situationCode != null
          ? situationLabels[e.situationCode]
          : e.humanMoment.label,
      color: WrColors.navy,
      episodeId: e.id,
    ));
  }

  // Khi đã đọc được Episode thì bỏ event do chính Episode sinh ra.
  final skipEpisodeEvents = closed.isNotEmpty;
  for (final ev in events) {
    if (skipEpisodeEvents && ev.behavior == kEpisodeBehavior) continue;
    final title = ev.situationCode != null
        ? (situationLabels[ev.situationCode] ?? ev.situationCode!)
        : (ev.reflectionText?.trim().isNotEmpty == true
            ? ev.reflectionText!.trim()
            : emotionLabel(ev.emotion));
    final mood =
        ev.emotion?.isNotEmpty == true ? emotionLabel(ev.emotion) : null;
    entries.add(JourneyEntry(
      at: ev.createdAt,
      label: eventTypeLabel(ev),
      title: title,
      subtitle: mood == title ? null : mood,
      color: eventColor(ev),
    ));
  }

  entries.sort((a, b) {
    final av = a.at;
    final bv = b.at;
    if (av == null && bv == null) return 0;
    if (av == null) return 1;
    if (bv == null) return -1;
    return bv.compareTo(av);
  });
  return entries;
}

/// Một cụm mục cùng tháng trên dòng thời gian.
class JourneyMonth {
  const JourneyMonth({required this.label, required this.entries});

  final String label;
  final List<JourneyEntry> entries;
}

/// Gom dòng thời gian theo tháng, giữ nguyên thứ tự mới-trước đã sắp.
///
/// Mắt người đọc mốc thời gian theo cụm chứ không theo từng dòng — không có
/// tiêu đề tháng thì một danh sách dài trông như một khối phẳng.
List<JourneyMonth> groupJourneyByMonth(List<JourneyEntry> entries) {
  final months = <JourneyMonth>[];
  final undated = <JourneyEntry>[];

  for (final e in entries) {
    final at = e.at;
    if (at == null) {
      undated.add(e);
      continue;
    }
    final label = 'THÁNG ${at.month}, ${at.year}';
    if (months.isNotEmpty && months.last.label == label) {
      months.last.entries.add(e);
    } else {
      months.add(JourneyMonth(label: label, entries: [e]));
    }
  }

  if (undated.isNotEmpty) {
    months.add(JourneyMonth(label: 'CHƯA RÕ THỜI GIAN', entries: undated));
  }
  return months;
}

String emotionLabel(String? emotion) => switch (emotion) {
      'low' => 'Mệt mỏi',
      'ok' => 'Ổn',
      'good' => 'Vui',
      _ => emotion ?? 'Ghi chú',
    };

String eventTypeLabel(CareerMemoryEvent e) {
  if (e.behavior == kEpisodeBehavior) return 'PHẢN TƯ';
  if (e.behavior == 'skill_certified') return 'KỸ NĂNG';
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

Color eventColor(CareerMemoryEvent e) {
  if (e.behavior == kEpisodeBehavior) return WrColors.navy;
  if (e.behavior == 'skill_certified') return WrColors.teal;
  if (e.behavior == 'practice_step_done' ||
      e.behavior == 'practice_theme_done') {
    return WrColors.teal;
  }
  if (e.behavior == 'insight') return const Color(0xFF5B8CC9);
  if (e.behavior == 'decision') return WrColors.coral;
  if (e.storyId != null) return const Color(0xFF5E7A5A);
  return WrColors.muted;
}

// ---------------------------------------------------------------------------

class WrJourneyScreen extends ConsumerWidget {
  const WrJourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final events = ref.watch(wrMemoryEventsProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final patterns = ref.watch(wrPatternCountsProvider).valueOrNull ?? const [];
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);

    final sitMap = {for (final s in situations) s.code: s.text};
    final all = buildJourneyEntries(
      episodes: episodes,
      events: events,
      situationLabels: sitMap,
    );
    final capped = !entitlement.isPremium && all.length > kFreeJourneyLimit;
    final shown = capped ? all.sublist(0, kFreeJourneyLimit) : all;

    return Scaffold(
      backgroundColor: WrColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
          children: [
            const WrTabBackLink(currentTab: WrTab.journey),
            const Text(
              'Career Memory',
              style: TextStyle(fontSize: 14, color: WrColors.muted),
            ),
            const SizedBox(height: 2),
            const Text(
              'Hành trình',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: WrColors.navy,
                letterSpacing: -0.96,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 28),

            const WrEyebrow('CAREER MEMORY'),
            const SizedBox(height: 14),
            Text(
              all.isEmpty
                  ? 'Chưa có mảnh ký ức nào. Mỗi lần nhìn lại sẽ để lại một dấu ở đây.'
                  : 'Bạn đã để lại ${all.length} mảnh ký ức nghề nghiệp.',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: WrColors.navy,
                height: 1.4,
              ),
            ),

            if (all.isNotEmpty) ...[
              const SizedBox(height: 32),
              const WrSectionDivider(),
              const SizedBox(height: 24),
              for (final month in groupJourneyByMonth(shown)) ...[
                WrEyebrow(month.label),
                const SizedBox(height: 16),
                for (int i = 0; i < month.entries.length; i++)
                  _EntryRow(
                    entry: month.entries[i],
                    isLast: i == month.entries.length - 1,
                    onTap: month.entries[i].episodeId == null
                        ? null
                        : () => context.push(
                              '/wr/episode/${month.entries[i].episodeId}',
                            ),
                  ),
                const SizedBox(height: 20),
              ],
              if (capped)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: WrLinkRow(
                    key: const Key('wr_journey_full_memory_row'),
                    label: 'Xem toàn bộ Career Memory',
                    hint: '⭐ Premium',
                    onTap: () => context.push('/wr/paywall'),
                  ),
                ),
            ],

            const SizedBox(height: 24),
            const WrSectionDivider(),
            const SizedBox(height: 12),

            if (patterns.isNotEmpty)
              WrLinkRow(
                key: const Key('wr_journey_discover_row'),
                label: 'Xem trong Hiểu mình',
                onTap: () => context.go('/wr/discover?from=journey'),
              ),
            WrLinkRow(
              key: const Key('wr_journey_narrative_row'),
              label: 'Diễn biến theo thời gian',
              onTap: () => context.push('/wr/journey/narrative'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.isLast,
    this.onTap,
  });

  final JourneyEntry entry;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final at = entry.at;
    final dateStr = at == null
        ? ''
        // Năm đã nằm ở tiêu đề tháng, không lặp lại trên từng dòng.
        : '${at.day.toString().padLeft(2, '0')}/'
            '${at.month.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          // Đường nối các mốc — dòng thời gian phải trông liền mạch, không
          // phải một danh sách chấm rời.
          if (!isLast)
            Positioned(
              left: 5,
              top: 24,
              bottom: 0,
              child: Container(
                width: 1,
                color: WrColors.navy.withValues(alpha: 0.1),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: isLast ? 8 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: entry.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: WrColors.muted,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        entry.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: WrColors.navy,
                          height: 1.45,
                        ),
                      ),
                      if (entry.subtitle != null &&
                          entry.subtitle!.isNotEmpty &&
                          entry.subtitle != entry.title) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: WrColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        entry.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: entry.color,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 13,
                      color: WrColors.muted,
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
