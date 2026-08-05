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
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_link_row.dart';
import '../../../core/widgets/wr_premium_lock.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
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

// Free tier KHÔNG xem được mục ký ức nào — quyết định của khách 2026-07-29:
// "Career Memory đầy đủ bị khoá hoàn toàn với tài khoản Free".
//
// Bản trước cho Free xem 10 mục gần nhất rồi mới cắt; giờ dòng thời gian chỉ
// hiện với Premium. Con số tổng vẫn nói ra, vì đó là việc của chính người dùng
// đã làm (cùng loại với "Bạn đã nhìn lại N lần" ở Hiểu mình) — cái bị khoá là
// nội dung từng mảnh ký ức.

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
    // Không rơi về chính cái mã: `C2-sit-01` là thuật ngữ nội bộ, không phải
    // thứ để người dùng đọc trên dòng thời gian của đời mình (v1.6 §XII.5).
    final title = ev.situationCode != null
        ? (situationLabels[ev.situationCode] ??
            (ev.reflectionText?.trim().isNotEmpty == true
                ? ev.reflectionText!.trim()
                : 'Một lần nhìn lại'))
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

// ---------------------------------------------------------------------------
// Gom theo tuần trong tháng và ngày trong tuần
// ---------------------------------------------------------------------------

/// Một ngày trên dòng thời gian.
class JourneyDay {
  const JourneyDay({
    required this.date,
    required this.label,
    required this.entries,
  });

  final DateTime date;

  /// "Hôm nay", "Hôm qua", hoặc "Thứ Sáu, 01/08".
  final String label;

  final List<JourneyEntry> entries;
}

/// Một tuần trong tháng, chứa các ngày có mục.
class JourneyWeek {
  const JourneyWeek({required this.label, required this.days});

  /// "TUẦN 2 · 05–11/08" — số thứ tự để định vị nhanh, khoảng ngày để khỏi
  /// phải nhẩm xem "tuần 2" là những ngày nào.
  final String label;

  final List<JourneyDay> days;
}

/// Một tháng, đã chia tiếp thành tuần và ngày.
class JourneyMonthDetailed {
  const JourneyMonthDetailed({required this.label, required this.weeks});

  final String label;
  final List<JourneyWeek> weeks;
}

const List<String> _kWeekdayVi = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

String _dd(int n) => n.toString().padLeft(2, '0');

/// Nửa đêm của [d] — khoá gom nhóm theo ngày, bỏ phần giờ.
DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// Thứ Hai của tuần chứa [d]. Tuần bắt đầu từ Thứ Hai theo lịch Việt Nam.
DateTime _mondayOf(DateTime d) =>
    _dayKey(d).subtract(Duration(days: d.weekday - DateTime.monday));

/// Gom dòng thời gian theo tháng → tuần → ngày, giữ nguyên thứ tự mới-trước.
///
/// Vì sao chia ba tầng thay vì đổ phẳng theo tháng: một tháng đủ dùng có thể
/// có ba bốn chục mảnh, và khi mọi dòng chỉ mang "01/08" thì không đọc ra được
/// nhịp — hôm nào dày, hôm nào cả tuần không ghi gì. Tách ngày ra thành tiêu đề
/// cũng bỏ được ngày lặp lại trên từng dòng.
///
/// [now] truyền vào chứ không gọi `DateTime.now()` bên trong: nhãn "Hôm nay" /
/// "Hôm qua" phải kiểm được bằng test mà không phụ thuộc lúc chạy.
///
/// Mục không có thời gian dồn vào một tháng "CHƯA RÕ THỜI GIAN" ở cuối, một
/// tuần một ngày không nhãn — vẫn đọc được, và không bịa cho chúng một ngày.
List<JourneyMonthDetailed> groupJourneyByWeekAndDay(
  List<JourneyEntry> entries, {
  required DateTime now,
}) {
  final today = _dayKey(now);
  final yesterday = today.subtract(const Duration(days: 1));

  // Gom theo tháng trước, giữ nguyên thứ tự đã sắp (mới trước).
  final monthOrder = <String>[];
  final byMonth = <String, List<JourneyEntry>>{};
  final undated = <JourneyEntry>[];

  for (final e in entries) {
    final at = e.at;
    if (at == null) {
      undated.add(e);
      continue;
    }
    final key = 'THÁNG ${at.month}, ${at.year}';
    if (!byMonth.containsKey(key)) {
      monthOrder.add(key);
      byMonth[key] = [];
    }
    byMonth[key]!.add(e);
  }

  final months = <JourneyMonthDetailed>[];

  for (final monthLabel in monthOrder) {
    final monthEntries = byMonth[monthLabel]!;

    // Trong tháng: gom theo Thứ Hai của tuần, rồi theo ngày.
    final weekOrder = <DateTime>[];
    final byWeek = <DateTime, List<JourneyEntry>>{};
    for (final e in monthEntries) {
      final monday = _mondayOf(e.at!);
      if (!byWeek.containsKey(monday)) {
        weekOrder.add(monday);
        byWeek[monday] = [];
      }
      byWeek[monday]!.add(e);
    }

    // Số thứ tự tuần đếm từ đầu tháng, nên phải xếp tăng dần rồi mới đánh số —
    // danh sách đang là mới-trước.
    final ascending = [...weekOrder]..sort();
    final weekNumber = <DateTime, int>{
      for (var i = 0; i < ascending.length; i++) ascending[i]: i + 1,
    };

    final anyDate = monthEntries.first.at!;
    final firstOfMonth = DateTime(anyDate.year, anyDate.month, 1);
    final lastOfMonth = DateTime(anyDate.year, anyDate.month + 1, 0);

    final weeks = <JourneyWeek>[];
    for (final monday in weekOrder) {
      // Tuần đầu và tuần cuối tháng thường bị cắt — hiện khoảng ngày THẬT nằm
      // trong tháng, chứ không phải Thứ Hai của tháng trước.
      final sunday = monday.add(const Duration(days: 6));
      final from = monday.isBefore(firstOfMonth) ? firstOfMonth : monday;
      final to = sunday.isAfter(lastOfMonth) ? lastOfMonth : sunday;
      final range = '${_dd(from.day)}–${_dd(to.day)}/${_dd(from.month)}';

      final dayOrder = <DateTime>[];
      final byDay = <DateTime, List<JourneyEntry>>{};
      for (final e in byWeek[monday]!) {
        final day = _dayKey(e.at!);
        if (!byDay.containsKey(day)) {
          dayOrder.add(day);
          byDay[day] = [];
        }
        byDay[day]!.add(e);
      }

      weeks.add(JourneyWeek(
        label: 'TUẦN ${weekNumber[monday]} · $range',
        days: [
          for (final day in dayOrder)
            JourneyDay(
              date: day,
              label: switch (day) {
                _ when day == today => 'Hôm nay',
                _ when day == yesterday => 'Hôm qua',
                _ => '${_kWeekdayVi[day.weekday - 1]}, '
                    '${_dd(day.day)}/${_dd(day.month)}',
              },
              entries: byDay[day]!,
            ),
        ],
      ));
    }

    months.add(JourneyMonthDetailed(label: monthLabel, weeks: weeks));
  }

  if (undated.isNotEmpty) {
    months.add(JourneyMonthDetailed(
      label: 'CHƯA RÕ THỜI GIAN',
      weeks: [
        JourneyWeek(
          label: '',
          days: [
            JourneyDay(
              date: DateTime(0),
              label: '',
              entries: undated,
            ),
          ],
        ),
      ],
    ));
  }

  return months;
}

String emotionLabel(String? emotion) => switch (emotion) {
      'low' => 'Mệt mỏi',
      'ok' => 'Ổn',
      'good' => 'Vui',
      _ => emotion ?? 'Ghi chú',
    };

/// Nhãn loại của một mốc trên timeline Hành trình.
///
/// v1.6 §9.1 liệt kê bốn nhãn MILESTONE/STORY/THEME/INSIGHT, nhưng đó là tên
/// loại nội bộ. §XII.5 yêu cầu không phơi thuật ngữ nội bộ ra người dùng, nên ở
/// đây dùng tiếng Việt — quyết định đã chốt với owner 2026-07-28.
String eventTypeLabel(CareerMemoryEvent e) {
  if (e.behavior == kEpisodeBehavior) return 'PHẢN TƯ';
  if (e.behavior == 'skill_certified') return 'KỸ NĂNG';
  if (e.behavior == kPracticeStepNoteBehavior) return 'ĐIỀU MÌNH GHI LẠI';
  if (e.behavior == 'practice_step_done' ||
      e.behavior == 'practice_theme_done') {
    return 'THỰC HÀNH';
  }
  if (e.behavior == 'insight') return 'NHẬN RA';
  if (e.behavior == 'decision') return 'QUYẾT ĐỊNH';
  if (e.storyId != null) return 'PHẢN CHIẾU';
  if (e.situationCode != null) return 'TRẢI NGHIỆM';
  return 'GHI CHÚ';
}

Color eventColor(CareerMemoryEvent e) {
  if (e.behavior == kEpisodeBehavior) return WrColors.navy;
  if (e.behavior == 'skill_certified') return WrColors.teal;
  if (e.behavior == kPracticeStepNoteBehavior) return const Color(0xFF5E7A5A);
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

/// Số mảnh ký ức hiện thẳng ở tab Hành trình.
///
/// Người dùng lâu năm có hàng chục mảnh; đổ hết ra thì tab này thành một cuộn
/// dài vô tận và mọi thứ nằm dưới Career Memory (Cơ hội phát triển, ô hỏi tự
/// do) coi như không ai thấy. Phần còn lại nằm ở màn riêng.
const int kJourneyPreviewCount = 5;

/// Dựng dòng thời gian từ các provider — dùng chung giữa tab Hành trình và màn
/// Career Memory đầy đủ, để hai nơi không bao giờ liệt kê khác nhau.
List<JourneyEntry> watchJourneyEntries(WidgetRef ref) {
  final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
  final events = ref.watch(wrMemoryEventsProvider).valueOrNull ?? const [];
  final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
  return buildJourneyEntries(
    episodes: episodes,
    events: events,
    situationLabels: {for (final s in situations) s.code: s.text},
  );
}

class WrJourneyScreen extends ConsumerWidget {
  const WrJourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patterns = ref.watch(wrPatternCountsProvider).valueOrNull ?? const [];
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);

    final all = watchJourneyEntries(ref);
    final locked = !entitlement.isPremium;
    final shown =
        locked ? const <JourneyEntry>[] : all.take(kJourneyPreviewCount).toList();
    final hasMore = !locked && all.length > shown.length;

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
          children: [
            const WrTabBackLink(currentTab: WrTab.journey),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Career Memory',
                        style: TextStyle(fontSize: 15.5, color: WrColors.muted),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hành trình',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: WrColors.navy,
                          letterSpacing: -0.96,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                // v1.6 §9.1: "Tôi" là avatar ở mọi màn tab, không còn tab riêng.
                const WrProfileAvatar(),
              ],
            ),
            const SizedBox(height: 28),

            // Diễn biến theo thời gian — thẻ mở đầu tab, theo giao diện mẫu
            // Sprint 2. Trước đây nó là một dòng dẫn nằm tận cuối màn, nên thứ
            // duy nhất tóm được cả chặng đường lại là thứ dễ bỏ sót nhất.
            const _NarrativeCard(),
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

            if (all.isNotEmpty && locked) ...[
              const SizedBox(height: 24),
              const WrPremiumLock(
                key: Key('wr_journey_memory_lock'),
                description:
                    'Bản đầy đủ mở lại từng mảnh ký ức nghề nghiệp bạn đã để '
                    'lại, đọc lại được bất cứ lúc nào, theo đúng dòng thời gian.',
                ctaLabel: 'Mở toàn bộ Career Memory',
                paywallTrigger: 'career_memory',
              ),
            ],

            if (all.isNotEmpty && !locked) ...[
              const SizedBox(height: 32),
              const WrSectionDivider(),
              const SizedBox(height: 24),
              ...buildJourneyTimeline(
                context,
                groupJourneyByWeekAndDay(shown, now: DateTime.now()),
              ),
              if (hasMore)
                WrLinkRow(
                  key: const Key('wr_journey_memory_see_all'),
                  label: 'Xem tất cả ${all.length} mảnh ký ức',
                  hint: 'Còn ${all.length - shown.length} mảnh nữa',
                  onTap: () => context.push('/wr/career-memory'),
                ),
            ],

            // Cơ hội phát triển — §XI. Nằm dưới Career Memory vì nó là điều
            // rút ra TỪ chặng đường, không phải một mục của chặng đường.
            const _GrowthOpportunitySection(),

            const SizedBox(height: 24),
            const WrSectionDivider(),
            const SizedBox(height: 12),

            // Trò chuyện với trợ lý phản chiếu. Đặt ở tab Hành trình vì câu hỏi
            // người dùng muốn đặt ("tôi có phù hợp với công việc đó không") chỉ
            // trả lời được từ Career Memory, tức từ chính tab này.
            //
            // Trước 2026-08-03 đây là ô hỏi một chiều chờ trả lời qua email
            // (họp khách 2026-07-29); giờ là hội thoại nhiều lượt.
            WrLinkRow(
              key: const Key('wr_journey_ask_row'),
              label: 'Trò chuyện về hành trình của bạn',
              hint: 'Hỏi và trả lời ngay',
              onTap: () => context.push('/wr/ask'),
            ),

            if (patterns.isNotEmpty)
              WrLinkRow(
                key: const Key('wr_journey_discover_row'),
                label: 'Xem trong Hiểu mình',
                onTap: () => context.go('/wr/discover?from=journey'),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diễn biến theo thời gian — thẻ mở đầu tab Hành trình
// ---------------------------------------------------------------------------

/// Thẻ navy mở đầu tab: hệ thống đọc ra điều gì đang đổi trong bạn.
///
/// Đây là DIỄN GIẢI nên thuộc Premium (Hai Lớp v1.2 §III). Bản miễn phí thấy
/// thẻ và biết mình đang bỏ lỡ gì, nhưng không thấy một chữ nào của nội dung —
/// khác với làm mờ, vì chữ mờ vẫn là chữ đã gửi xuống máy người dùng.
class _NarrativeCard extends ConsumerWidget {
  const _NarrativeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final narratives =
        ref.watch(wrPatternNarrativesProvider).valueOrNull ?? const [];
    final canRead =
        entitlement.canUseFeature(WrPremiumFeature.patternAdvanced);
    final latest = narratives.isNotEmpty ? narratives.first.narrative : null;

    return WrCardNavy(
      key: const Key('wr_journey_narrative_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canRead ? Icons.auto_awesome : Icons.lock_outline,
                size: 14,
                color: WrColors.coral,
              ),
              const SizedBox(width: 6),
              Text(
                canRead ? 'DIỄN BIẾN THEO THỜI GIAN' : 'PREMIUM',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: WrColors.coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            canRead && latest != null
                ? latest
                : canRead
                    ? 'Chưa đủ dữ liệu để kể lại diễn biến. Ghi thêm vài lần '
                        'nữa, WorkReflection sẽ chỉ ra điều gì đang đổi.'
                    : 'Bản đầy đủ kể lại những mẫu hình của bạn đã đổi thế nào '
                        'qua từng giai đoạn, điều gì đang nhạt dần và điều gì '
                        'vẫn quay lại.',
            style: TextStyle(
              fontSize: 16.5,
              height: 1.65,
              // Kem, không phải trắng mờ: chữ trên thẻ navy ở cả bốn tab là kem.
              color: WrColors.cream,
              fontStyle: canRead && latest != null
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            key: const Key('wr_journey_narrative_row'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/wr/journey/narrative'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  canRead ? 'Đọc toàn bộ diễn biến' : 'Xem bản đầy đủ có gì',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.coral,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.arrow_forward, size: 14, color: WrColors.coral),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cơ hội phát triển — Hai Lớp v1.6 §XI
// ---------------------------------------------------------------------------

/// Khối "Cơ hội phát triển" dưới Career Memory.
///
/// Ba điều kiện của §XI được cài ở đây:
///   §11.3  Chưa suy ra được gợi ý nào thì cả khối biến mất, không hiện khung
///          rỗng cũng không hiện lời mời chung chung.
///   §11.4  Free chỉ thấy khối khoá; nội dung gợi ý không lọt ra ngoài paywall.
///   §XII.7 [GrowthOpportunity.suggestionText] và [GrowthOpportunity.confidenceNote]
///          dựng chung một chỗ — không nhánh nào hiện câu gợi ý mà thiếu ghi chú.
class _GrowthOpportunitySection extends ConsumerWidget {
  const _GrowthOpportunitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunity = ref.watch(wrGrowthOpportunityProvider).valueOrNull;
    if (opportunity == null) return const SizedBox.shrink();

    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WrSectionDivider(),
          const SizedBox(height: 24),
          const WrEyebrow('CƠ HỘI PHÁT TRIỂN'),
          const SizedBox(height: 14),
          if (!entitlement.isPremium)
            const WrPremiumLock(
              key: Key('wr_journey_growth_opportunity_lock'),
              description:
                  'Từ những gì bạn đã nhìn lại, bản đầy đủ chỉ ra một hướng '
                  'năng lực đáng phát triển tiếp, kèm lý do vì sao là hướng đó.',
              ctaLabel: 'Mở Cơ hội phát triển',
              paywallTrigger: 'growth_opportunity',
            )
          else
            WrCardMinimal(
              key: const Key('wr_journey_growth_opportunity'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opportunity.suggestionText,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(
                      fontSize: 16.5,
                      height: 1.6,
                      color: WrColors.navy,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    opportunity.confidenceNote,
                    key: const Key('wr_journey_growth_confidence'),
                    textAlign: TextAlign.justify,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: WrColors.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          WrLinkRow(
            key: const Key('wr_journey_work_info_row'),
            label: 'Thông tin công việc hiện tại',
            hint: 'Gợi ý sát hơn',
            onTap: () => context.push('/wr/work-info'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bộ lọc theo loại
// ---------------------------------------------------------------------------

/// Một loại mục có mặt trong danh sách, kèm số lượng.
class JourneyFacet {
  const JourneyFacet({required this.label, required this.count});

  final String label;
  final int count;
}

/// Các loại thật sự có trong [entries], nhiều trước.
///
/// Dựng từ chính dữ liệu chứ không liệt kê cứng 9 nhãn của [eventTypeLabel]:
/// một cái chip "KỸ NĂNG (0)" chỉ để đó cho người dùng bấm vào rồi thấy trang
/// trống là một lời hứa suông.
///
/// Loại bằng điểm nhau xếp theo bảng chữ cái, để thứ tự chip không nhảy giữa
/// hai lần mở màn.
List<JourneyFacet> journeyTypeFacets(List<JourneyEntry> entries) {
  final tally = <String, int>{};
  for (final e in entries) {
    tally[e.label] = (tally[e.label] ?? 0) + 1;
  }
  final facets = tally.entries
      .map((e) => JourneyFacet(label: e.key, count: e.value))
      .toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });
  return facets;
}

/// Lọc theo loại. [type] null nghĩa là không lọc.
List<JourneyEntry> filterJourneyByType(
  List<JourneyEntry> entries,
  String? type,
) {
  if (type == null) return entries;
  return entries.where((e) => e.label == type).toList();
}

/// Dựng dòng thời gian ba tầng: tháng → tuần → ngày.
///
/// Trả về một danh sách phẳng để nhét thẳng vào `children` của ListView hoặc
/// WrDetailScaffold — hai màn dùng chung, nên không nơi nào tự vẽ lại tầng nào.
///
/// Ngày nằm ở tiêu đề chứ không lặp trên từng dòng, nên [_EntryRow] ở đây tắt
/// phần ngày đi.
List<Widget> buildJourneyTimeline(
  BuildContext context,
  List<JourneyMonthDetailed> months,
) {
  final out = <Widget>[];
  for (final month in months) {
    out
      ..add(WrEyebrow(month.label))
      ..add(const SizedBox(height: 14));

    for (final week in month.weeks) {
      if (week.label.isNotEmpty) {
        out
          ..add(Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              week.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.06,
                color: WrColors.navy.withValues(alpha: 0.45),
              ),
            ),
          ))
          ..add(const SizedBox(height: 6));
      }

      for (final day in week.days) {
        if (day.label.isNotEmpty) {
          out.add(Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              day.label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
              ),
            ),
          ));
        }
        for (var i = 0; i < day.entries.length; i++) {
          final entry = day.entries[i];
          out.add(_EntryRow(
            entry: entry,
            isLast: i == day.entries.length - 1,
            showDate: false,
            onTap: entry.episodeId == null
                ? null
                : () => context.push('/wr/episode/${entry.episodeId}'),
          ));
        }
      }
      out.add(const SizedBox(height: 14));
    }
    out.add(const SizedBox(height: 8));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Career Memory đầy đủ — màn riêng, mở từ tab Hành trình
// ---------------------------------------------------------------------------

/// Toàn bộ dòng thời gian, không cắt bớt.
///
/// Tab Hành trình chỉ hiện [kJourneyPreviewCount] mảnh gần nhất; ai muốn đọc
/// hết thì sang đây. Cùng một hàm dựng dữ liệu ([watchJourneyEntries]) và cùng
/// một dòng ([_EntryRow]) với tab, nên hai nơi không thể lệch nhau.
///
/// Vẫn là nội dung Premium: khoá ở đây y như ở tab, để mở thẳng bằng đường dẫn
/// không thành lối đi vòng qua cổng.
class WrCareerMemoryScreen extends ConsumerStatefulWidget {
  const WrCareerMemoryScreen({super.key});

  @override
  ConsumerState<WrCareerMemoryScreen> createState() =>
      _WrCareerMemoryScreenState();
}

class _WrCareerMemoryScreenState extends ConsumerState<WrCareerMemoryScreen> {
  /// Loại đang lọc. null = xem tất cả.
  String? _type;

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final all = watchJourneyEntries(ref);
    final locked = !entitlement.isPremium;

    // Các chip dựng từ TOÀN BỘ danh sách, không phải từ danh sách đã lọc —
    // nếu không, chọn một loại xong là mọi chip khác biến mất và không còn
    // đường quay lại.
    final facets = journeyTypeFacets(all);
    final shown = filterJourneyByType(all, _type);

    return WrDetailScaffold(
      eyebrow: 'CAREER MEMORY',
      title: locked || all.isEmpty
          ? 'Career Memory'
          : _type == null
              ? 'Tất cả ${all.length} mảnh ký ức'
              : '${shown.length} mảnh · ${_type!.toLowerCase()}',
      children: [
        if (locked)
          const WrPremiumLock(
            key: Key('wr_career_memory_lock'),
            description:
                'Bản đầy đủ mở lại từng mảnh ký ức nghề nghiệp bạn đã để '
                'lại, đọc lại được bất cứ lúc nào, theo đúng dòng thời gian.',
            ctaLabel: 'Mở toàn bộ Career Memory',
            paywallTrigger: 'career_memory',
          )
        else if (all.isEmpty)
          const Text(
            'Chưa có mảnh ký ức nào. Mỗi lần nhìn lại sẽ để lại một dấu ở đây.',
            key: Key('wr_career_memory_empty'),
            style: TextStyle(
              fontSize: 16.5,
              color: WrColors.muted,
              height: 1.65,
            ),
          )
        else ...[
          // Một loại duy nhất thì không có gì để lọc — hàng chip khi đó chỉ là
          // hai nút cùng cho ra một kết quả.
          if (facets.length > 1) ...[
            _TypeFilterBar(
              facets: facets,
              total: all.length,
              selected: _type,
              onSelect: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 20),
          ],
          if (shown.isEmpty)
            const Text(
              'Không có mảnh nào thuộc loại này.',
              key: Key('wr_career_memory_filter_empty'),
              style: TextStyle(
                fontSize: 16.5,
                color: WrColors.muted,
                height: 1.65,
              ),
            )
          else
            ...buildJourneyTimeline(
              context,
              groupJourneyByWeekAndDay(shown, now: DateTime.now()),
            ),
        ],
      ],
    );
  }
}

/// Hàng chip lọc theo loại, cuộn ngang.
///
/// Cuộn ngang chứ không xuống dòng: tối đa 9 loại, gói thành ba hàng chip sẽ
/// đẩy dòng thời gian xuống quá sâu trên màn điện thoại.
class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({
    required this.facets,
    required this.total,
    required this.selected,
    required this.onSelect,
  });

  final List<JourneyFacet> facets;
  final int total;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        key: const Key('wr_career_memory_filter_bar'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          _Chip(
            label: 'Tất cả',
            count: total,
            active: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final f in facets)
            _Chip(
              label: f.label,
              count: f.count,
              active: selected == f.label,
              onTap: () => onSelect(selected == f.label ? null : f.label),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        key: Key('wr_career_memory_filter_$label'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: active ? WrColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? WrColors.navy
                  : WrColors.navy.withValues(alpha: 0.16),
            ),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.04,
              color: active ? WrColors.white : WrColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

/// Một mốc trên dòng thời gian, THU GỌN sẵn.
///
/// Mặc định chỉ hiện loại mốc ("PHẢN TƯ", "CHECK-IN"…). Điều người dùng rút ra
/// và tình huống họ đã chọn chỉ hiện ra khi họ chạm vào.
///
/// Dòng thời gian là nơi nhìn lại cả một tháng. Mỗi mốc trải ra ba dòng chữ đậm
/// cộng một dòng phụ thì một tuần bận đã dài hơn cả màn hình, và tác dụng "nhìn
/// một cái thấy hết" mất sạch. Thu lại thì cả tháng nằm gọn trong một lần cuộn,
/// còn chi tiết vẫn ở nguyên đó, cách một cú chạm.
///
/// Chạm vào hàng để mở ra hoặc thu lại; mở màn đọc riêng thì qua "Xem chi tiết"
/// bên trong. Trước bản này chạm vào hàng là đi thẳng sang màn khác — giữ nguyên
/// vậy thì không còn cử chỉ nào để mở ra tại chỗ, mà nhét việc mở ra vào cái
/// mũi tên 13px thì mục tiêu chạm nhỏ tới mức khó trúng.
class _EntryRow extends StatefulWidget {
  const _EntryRow({
    required this.entry,
    required this.isLast,
    this.onTap,
    this.showDate = true,
  });

  final JourneyEntry entry;
  final bool isLast;

  /// Mở màn đọc riêng của mốc này. Null khi mốc không có màn riêng.
  final VoidCallback? onTap;

  /// Tắt khi ngày đã nằm ở tiêu đề nhóm ngày — in lại "01/08" ngay dưới dòng
  /// "Thứ Sáu, 01/08" là nói cùng một điều hai lần.
  final bool showDate;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isLast = widget.isLast;
    final onTap = widget.onTap;
    final showDate = widget.showDate;
    final at = entry.at;
    final dateStr = (at == null || !showDate)
        ? ''
        // Năm đã nằm ở tiêu đề tháng, không lặp lại trên từng dòng.
        : '${at.day.toString().padLeft(2, '0')}/'
            '${at.month.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
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
                            fontSize: 13.5,
                            color: WrColors.muted,
                          ),
                        ),
                      // Loại mốc luôn hiện — thu gọn lại thì đây là thứ DUY
                      // NHẤT còn đọc được, nên nó gánh cả việc phân biệt các
                      // mốc với nhau.
                      Text(
                        entry.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: entry.color,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (_open) ...[
                        const SizedBox(height: 6),
                        Text(
                          entry.title,
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
                              fontSize: 14.5,
                              color: WrColors.muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                        // Mở màn đọc riêng nằm ở đây chứ không ở cú chạm vào
                        // hàng: cú chạm đó giờ dùng để mở ra và thu lại.
                        if (onTap != null) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onTap,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Xem chi tiết',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: entry.color,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 11,
                                  color: entry.color,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                // Mũi tên là thứ duy nhất báo rằng hàng này còn chữ bên trong.
                // Bỏ đi thì phần nội dung xem như biến mất hẳn: không ai chạm
                // vào một dòng nhãn trông đã trọn vẹn.
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: WrColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}
