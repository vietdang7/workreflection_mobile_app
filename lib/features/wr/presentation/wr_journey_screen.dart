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

import '../../../core/logic/wr_career_memory_rules.dart';
import '../../../core/logic/wr_dominant_need.dart';
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
import '../../../core/widgets/wr_paragraph.dart';

/// Bản ghi hiển thị trên dòng thời gian — Episode hoặc Career Memory event.
class JourneyEntry {
  const JourneyEntry({
    required this.at,
    required this.label,
    required this.title,
    required this.color,
    this.subtitle,
    this.detail,
    this.episodeId,
  });

  final DateTime? at;
  final String label;

  /// Tên gọi ngắn của mảnh — mockup v16 gọi là `title`. Luôn hiện.
  final String title;

  /// Nội dung của mảnh — mockup v16 gọi là `excerpt`. Luôn hiện.
  final String? subtitle;

  /// VÌ SAO mảnh này có mặt ở đây — mockup v16 gọi là `detail`.
  ///
  /// Chỉ hiện khi người dùng bấm mở. Ba loại được sinh THÊM (Cột mốc · Chủ đề ·
  /// Insight) đều do hệ thống tự gắn, nên không nói ra luật thì người dùng mở
  /// Career Memory và thấy những dòng không rõ từ đâu ra.
  final String? detail;

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

  final closed = closedStories(episodes);

  // Cột mốc là CỜ trên STORY, không phải một mảnh ký ức riêng (changelog 24/08
  // §8.2). Tính ở đây thay vì ghi thêm một hàng: ghi thêm hàng thì mỗi lượt
  // Reflection đầu tiên hoá thành hai mảnh, và con số "bạn đã để lại N mảnh"
  // ngay phía trên lệch khỏi số lần người dùng thật sự ngồi xuống nhìn lại.
  final milestones = milestonesByStoryId(closed);

  for (final e in closed) {
    final milestone = e.id == null ? null : milestones[e.id];
    final situation =
        e.situationCode != null ? situationLabels[e.situationCode] : null;
    entries.add(JourneyEntry(
      at: e.closedAt ?? e.updatedAt ?? e.openedAt,
      label: milestone == null ? kStoryLabel : kMilestoneLabel,
      // Mockup v16: title là TÊN GỌI của mảnh ("Reflection: Cuộc họp bị ngắt
      // lời"), excerpt mới là nội dung. Bản trước đặt điều-nhận-ra vào title
      // rồi nhét tình huống xuống dưới, nên hai mảnh cùng một tình huống trông
      // không liên quan gì tới nhau trên dòng thời gian.
      title: situation != null && situation.trim().isNotEmpty
          ? 'Nhìn lại: ${situation.trim()}'
          : e.humanMoment.label,
      subtitle: e.draftMeaning?.trim().isNotEmpty == true
          ? e.draftMeaning!.trim()
          : situation ?? e.humanMoment.label,
      detail: memoryDetailForStory(
        story: e,
        countThisMonth: needCountThisMonth(e, closed),
        milestoneText: milestone,
      ),
      color: milestone == null ? WrColors.navy : WrColors.coral,
      episodeId: e.id,
    ));
  }

  // Khi đã đọc được Episode thì bỏ event do chính Episode sinh ra.
  final skipEpisodeEvents = closed.isNotEmpty;
  for (final ev in events) {
    if (skipEpisodeEvents && ev.behavior == kEpisodeBehavior) continue;

    final text = ev.reflectionText?.trim();
    final hasText = text != null && text.isNotEmpty;

    // Chủ đề và Insight có TÊN GỌI riêng, và nội dung do máy sinh ra thì xuống
    // làm excerpt. Mockup v16: "Chủ đề mới xuất hiện: …" / "Pattern được nhận
    // diện". Bản trước đẩy nguyên đoạn văn lên làm tiêu đề, nên thu gọn lại thì
    // dòng thời gian là một cột những đoạn dài không phân biệt được với nhau.
    if (ev.behavior == kThemeBehavior || ev.behavior == kInsightBehavior) {
      final isTheme = ev.behavior == kThemeBehavior;
      final need = ev.humanNeed;
      entries.add(JourneyEntry(
        at: ev.createdAt,
        label: eventTypeLabel(ev),
        title: isTheme
            ? (need != null
                ? 'Chủ đề mới xuất hiện: ${needSeekingLabel(need)}'
                : 'Một chủ đề mới xuất hiện')
            : 'Điều hệ thống đọc ra',
        subtitle: hasText ? text : null,
        detail: isTheme ? kThemeDetail : kInsightDetail,
        color: eventColor(ev),
      ));
      continue;
    }

    // Không rơi về chính cái mã: `C2-sit-01` là thuật ngữ nội bộ, không phải
    // thứ để người dùng đọc trên dòng thời gian của đời mình (v1.6 §XII.5).
    final title = ev.situationCode != null
        ? (situationLabels[ev.situationCode] ??
            (hasText ? text : 'Một lần nhìn lại'))
        : (hasText ? text : emotionLabel(ev.emotion));
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
  const JourneyWeek({
    required this.label,
    required this.days,
    this.isCurrent = false,
  });

  /// "TUẦN 2 · 05–11/08" — số thứ tự để định vị nhanh, khoảng ngày để khỏi
  /// phải nhẩm xem "tuần 2" là những ngày nào.
  final String label;

  final List<JourneyDay> days;

  /// Tuần chứa hôm nay — `g.current` trong mockup v16.
  ///
  /// Đây là ranh giới bản miễn phí đọc được: tuần này mở, những tuần trước khoá.
  final bool isCurrent;
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
        isCurrent: monday == _mondayOf(now),
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

/// Bốn nhãn của Career Memory — `TYPE_META` trong mockup v16, §8.1 changelog.
///
/// §8.1 nêu đích danh việc phải sửa: "Đồng bộ nhãn hiển thị: cả hai màn dùng
/// chung nhãn tiếng Việt (Cột mốc / Câu chuyện / Chủ đề / Insight) … thay vì
/// mỗi nơi hiển thị một kiểu".
///
/// `CÂU CHUYỆN` chứ không phải `PHẢN TƯ`: hai chữ cũ không nằm trong bộ nhãn nào
/// của tài liệu, và "phản tư" là từ chuyên môn — người dùng đọc dòng thời gian
/// của chính đời mình không nên phải tra nghĩa.
const String kStoryLabel = 'CÂU CHUYỆN';
const String kMilestoneLabel = 'CỘT MỐC';
const String kThemeLabel = 'CHỦ ĐỀ';
const String kInsightLabel = 'INSIGHT';

/// Nhãn loại của một mốc trên timeline Hành trình.
///
/// v1.6 §9.1 liệt kê bốn nhãn MILESTONE/STORY/THEME/INSIGHT, nhưng đó là tên
/// loại nội bộ. §XII.5 yêu cầu không phơi thuật ngữ nội bộ ra người dùng, nên ở
/// đây dùng tiếng Việt — quyết định đã chốt với owner 2026-07-28.
String eventTypeLabel(CareerMemoryEvent e) {
  if (e.behavior == kEpisodeBehavior) return kStoryLabel;
  // Ba loại được SINH THÊM từ STORY (changelog 24/08 §8.2). Nhãn tiếng Việt
  // đúng như §8.1 đòi: Cột mốc / Chủ đề / Insight, không phải mã viết hoa.
  if (e.behavior == kMilestoneBehavior) return kMilestoneLabel;
  if (e.behavior == kThemeBehavior) return kThemeLabel;
  if (e.behavior == kInsightBehavior) return kInsightLabel;
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
  // Bốn màu đúng `TYPE_META` của mockup v16: Cột mốc coral · Câu chuyện navy ·
  // Chủ đề teal · Insight coral. Bản trước dùng hổ phách cho Chủ đề và xanh
  // dương cho Insight — hai màu không có trong bảng màu nào của thiết kế.
  if (e.behavior == kMilestoneBehavior) return WrColors.coral;
  if (e.behavior == kThemeBehavior) return WrColors.teal;
  if (e.behavior == kInsightBehavior) return WrColors.coral;
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
/// BỐN, đúng mockup v16 §8.1: "thẻ xem trước lấy 4 mục gần nhất". Bản trước để
/// 5 — lệch nhỏ nhưng không có lý do nào để lệch.
const int kJourneyPreviewCount = 4;

/// Tách con số "mảnh ký ức" thành các phần hợp thành nó.
///
/// Đọc từ CHÍNH danh sách đang hiển thị chứ không đếm lại từ provider: đếm lại
/// là mở đúng cái cửa vừa đóng — hai phép đếm theo hai luật rồi lệch nhau, và
/// dòng giải thích lại thành một con số thứ ba cần giải thích.
String _memoryBreakdown(List<JourneyEntry> all) {
  // Nhận diện bằng `episodeId`, KHÔNG bằng nhãn: từ changelog 24/08 §8.2 một
  // lần nhìn lại có thể mang nhãn "CỘT MỐC" thay vì "CÂU CHUYỆN", mà nó vẫn là
  // một lần nhìn lại. Đếm theo nhãn thì mỗi cột mốc lại làm hụt con số này đúng
  // một đơn vị — và dòng sinh ra để giải thích con số lại tự nói sai.
  final reflections = all
      .where((e) => e.episodeId != null || e.label == kStoryLabel)
      .length;
  final others = all.length - reflections;

  final parts = StringBuffer('Gồm $reflections lần nhìn lại đã khép');
  if (others > 0) parts.write(' và $others dấu mốc thực hành');
  parts.write('. Lần nhìn lại còn dở chưa vào đây, nên con số ở tab Hiểu mình '
      'có thể lớn hơn.');
  return parts.toString();
}

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
    // Bản miễn phí KHÔNG còn thấy một danh sách trống.
    //
    // Quyết định 2026-07-29 là "Career Memory đầy đủ bị khoá hoàn toàn với tài
    // khoản Free", và app làm đúng vậy: `shown` là rỗng. Nhưng mockup v16 —
    // bản chuẩn mới, 24/08 — khoá theo TUẦN chứ không khoá cả màn
    // (`!g.current && !state.isPremium`), nên tuần này vẫn đọc được. Bày ra
    // đúng cái mình đang khoá thì lời mời trả tiền mới có nghĩa; một khung
    // trống thì không mời được ai.
    final shown = all.take(kJourneyPreviewCount).toList();
    final hasMore = all.length > shown.length;

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
            WrParagraph(
              all.isEmpty
                  ? 'Chưa có mảnh ký ức nào. Mỗi lần nhìn lại sẽ để lại một dấu ở đây.'
                  : 'Bạn đã để lại ${all.length} mảnh ký ức nghề nghiệp.',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: WrColors.navy,
                height: 1.4,
              ),
              textAlign: TextAlign.start,
            ),

            // Con số này phải TỰ GIẢI THÍCH, nếu không nó là một con số lạ.
            //
            // Khách mở đầu phản hồi 2026-08-24 bằng "dữ liệu trong app chưa
            // được kết nối với nhau", và đây là ví dụ rõ nhất: màn này nói "21
            // mảnh ký ức" trong khi tab Hiểu mình ngay bên cạnh nói "15 lần
            // nhìn lại". Hai con số đo hai thứ khác nhau VÀ lọc khác nhau —
            // mảnh ký ức gộp cả dấu mốc thực hành nhưng bỏ những lần còn dở,
            // còn "lần nhìn lại" đếm mọi Episode. Không nơi nào nói ra điều đó,
            // nên người dùng chỉ còn cách kết luận là app đếm sai.
            if (all.isNotEmpty) ...[
              const SizedBox(height: 10),
              WrParagraph(
                _memoryBreakdown(all),
                key: const Key('wr_journey_memory_breakdown'),
                style: const TextStyle(
                  fontSize: 14,
                  color: WrColors.muted,
                  height: 1.6,
                ),
                textAlign: TextAlign.start,
              ),
            ],

            if (all.isNotEmpty) ...[
              const SizedBox(height: 32),
              const WrSectionDivider(),
              const SizedBox(height: 24),
              ...buildJourneyTimeline(
                context,
                groupJourneyByWeekAndDay(shown, now: DateTime.now()),
                lockOlderWeeks: locked,
              ),
              if (locked) ...[
                const SizedBox(height: 16),
                const WrPremiumLock(
                  key: Key('wr_journey_memory_lock'),
                  description:
                      'Bản đầy đủ mở lại từng mảnh ký ức nghề nghiệp bạn đã để '
                      'lại, đọc lại được bất cứ lúc nào, theo đúng dòng thời gian.',
                  ctaLabel: 'Mở toàn bộ Career Memory',
                  paywallTrigger: 'career_memory',
                ),
                const SizedBox(height: 8),
              ],
              // LUÔN hiện, kể cả khi màn này đã bày hết (changelog 24/08 §8.1).
              //
              // Trước đây dòng này chỉ hiện khi còn mảnh chưa bày. Nghe hợp lý,
              // nhưng nó khoá người dùng ở bản xem trước: màn đầy đủ mới có bộ
              // lọc theo loại và chỗ mở rộng từng mục, mà người có đúng bốn
              // mảnh ký ức thì không bao giờ thấy lối sang đó.
              WrLinkRow(
                key: const Key('wr_journey_memory_see_all'),
                label: 'Xem toàn bộ Career Memory',
                hint: hasMore
                    ? 'Còn ${all.length - shown.length} mảnh nữa'
                    : 'Lọc theo loại, mở rộng từng mảnh',
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
/// Câu hiện ra khi chưa có bản kể nào.
///
/// Bản cũ luôn nói đúng một câu: "Ghi thêm vài lần nữa". Câu đó sai ở hai điểm
/// cùng lúc — nó không đếm ngược được nên người ghi lần thứ 30 vẫn đọc y hệt
/// người ghi lần thứ hai, và nó hứa rằng ghi thêm sẽ có, trong khi thứ đứng sau
/// lời hứa ấy chưa hề tồn tại.
///
/// [refresh] null nghĩa là chưa hỏi xong máy chủ — giữ câu trung tính, đừng nói
/// "chưa đủ" khi chưa biết có đủ hay không.
///
/// NÓI RÕ "có chọn tình huống". `wr-narrative` chỉ đếm Episode CÓ
/// `situation_code` (nó so hai giai đoạn theo tình huống, không có mã thì không
/// có gì để so), trong khi thẻ Career Health ở tab Hiểu mình đếm MỌI Episode.
/// Bỏ mấy chữ này là hai màn nói hai con số cho cùng một chữ "lần nhìn lại" —
/// đúng cái khách gọi tên là "dữ liệu trong app chưa được kết nối với nhau".
String _waitingLine(WrNarrativeRefresh? refresh) {
  final needed = refresh?.needed;
  return switch (refresh?.status) {
    WrNarrativeStatus.notEnoughData when needed != null && needed > 0 =>
      'Còn $needed lần nhìn lại có chọn tình huống nữa là WorkReflection kể '
          'lại được diễn biến của bạn.',
    WrNarrativeStatus.notEnoughData =>
      'Chưa đủ dữ liệu để kể lại diễn biến. Ghi thêm vài lần nữa nhé.',
    // Đã kể rồi mà `latest` rỗng thì bản kể chưa kịp về tới màn — nói vậy còn
    // hơn nói "chưa đủ dữ liệu", vì dữ liệu thì đủ rồi.
    WrNarrativeStatus.upToDate =>
      'Diễn biến của bạn đang được đọc lại. Mở lại tab này sau một lát nhé.',
    _ => 'Chưa đủ dữ liệu để kể lại diễn biến. Ghi thêm vài lần nữa, '
        'WorkReflection sẽ chỉ ra điều gì đang đổi.',
  };
}

/// Số dòng đoạn Diễn biến hiện ra khi chưa mở rộng.
///
/// Khách 26_1: "đoạn AI này dài ngắn thất thường, có hôm đẩy hết mọi thứ khác
/// xuống dưới màn hình". Bản kể do `wr-narrative` sinh ra không có giới hạn độ
/// dài, nên chiều cao thẻ phụ thuộc vào mô hình chứ không phải vào thiết kế —
/// kẹp lại ở đây để mọi hôm mở tab Hành trình đều thấy cùng một bố cục.
const int kNarrativeCollapsedLines = 4;

class _NarrativeCard extends ConsumerStatefulWidget {
  const _NarrativeCard();

  @override
  ConsumerState<_NarrativeCard> createState() => _NarrativeCardState();
}

class _NarrativeCardState extends ConsumerState<_NarrativeCard> {
  /// Mở rộng là trạng thái của LẦN XEM này, không lưu lại.
  ///
  /// Cố tình không nhớ: thẻ này nằm giữa một danh sách, người dùng mở ra đọc
  /// xong rồi rời tab thì lần sau quay lại vẫn nên thấy bố cục gọn như cũ.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final narratives =
        ref.watch(wrPatternNarrativesProvider).valueOrNull ?? const [];
    final canRead =
        entitlement.canUseFeature(WrPremiumFeature.patternAdvanced);
    final latest = narratives.isNotEmpty ? narratives.first.narrative : null;

    // Đánh thức `wr-narrative`. Chỉ `watch` để provider chạy — giá trị dùng
    // đúng một việc: nói còn thiếu bao nhiêu lần nữa.
    //
    // Trước bản 2026-08-24 KHÔNG có dòng này, và cũng không có gì khác trong
    // toàn hệ thống ghi vào `wr_pattern_narratives`. Thẻ đọc một cái bảng không
    // ai ghi, nên nó nói "Chưa đủ dữ liệu" mãi mãi, kể cả với người đã để lại
    // hàng chục mảnh ký ức.
    final refresh = ref.watch(wrNarrativeRefreshProvider).valueOrNull;

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
          GestureDetector(
            // Bấm vào chính đoạn chữ để mở/thu — khách xin "bấm vào là nó bung
            // ra", không phải đi tìm một nút riêng.
            key: const Key('wr_journey_narrative_expand'),
            behavior: HitTestBehavior.opaque,
            onTap: latest == null || !canRead
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: WrParagraph(
              canRead && latest != null
                  ? latest
                  : canRead
                      ? _waitingLine(refresh)
                      : 'Bản đầy đủ kể lại những mẫu hình của bạn đã đổi thế nào '
                          'qua từng giai đoạn, điều gì đang nhạt dần và điều gì '
                          'vẫn quay lại.',
              // Chỉ kẹp bản kể của AI. Câu chờ và câu quảng cáo Premium đều do
              // mình viết, độ dài đã biết trước, kẹp thêm chỉ tổ cắt cụt.
              maxLines: canRead && latest != null && !_expanded
                  ? kNarrativeCollapsedLines
                  : null,
              overflow: canRead && latest != null && !_expanded
                  ? TextOverflow.ellipsis
                  : null,
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
          ),
          if (canRead && latest != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              key: const Key('wr_journey_narrative_expand_label'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? 'Thu gọn' : 'Mở rộng',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: WrColors.cream,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: WrColors.cream,
                  ),
                ],
              ),
            ),
          ],
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
  List<JourneyMonthDetailed> months, {
  bool lockOlderWeeks = false,
}) {
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
        // Mockup v16: `const locked = !g.current && !state.isPremium;` — khoá
        // theo TUẦN, không khoá cả màn.
        final locked = lockOlderWeeks && !week.isCurrent;
        for (var i = 0; i < day.entries.length; i++) {
          final entry = day.entries[i];
          out.add(_EntryRow(
            entry: entry,
            isLast: i == day.entries.length - 1,
            showDate: false,
            locked: locked,
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

    final now = DateTime.now();
    final grouped = groupJourneyByWeekAndDay(shown, now: now);
    // Số mảnh bản miễn phí đọc được — chỉ tuần này (mockup v16 `g.current`).
    final readable = locked
        ? grouped
            .expand((m) => m.weeks)
            .where((w) => w.isCurrent)
            .expand((w) => w.days)
            .expand((d) => d.entries)
            .length
        : shown.length;

    return WrDetailScaffold(
      eyebrow: 'CAREER MEMORY',
      // Mockup v16: "Bạn đã để lại N mảnh ký ức nghề nghiệp." — con số TỔNG,
      // kể cả với bản miễn phí. Việc mình đã làm thì luôn được nói ra; cái bị
      // khoá là nội dung từng mảnh.
      title: all.isEmpty
          ? 'Career Memory'
          : _type == null
              ? 'Bạn đã để lại ${all.length} mảnh ký ức nghề nghiệp.'
              : '${shown.length} mảnh · ${_type!.toLowerCase()}',
      children: [
        if (all.isEmpty)
          const WrParagraph(
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
            ...buildJourneyTimeline(context, grouped, lockOlderWeeks: locked),

          // Chân màn — mockup v16 có hai câu khác nhau cho hai bản.
          const SizedBox(height: 8),
          if (locked)
            WrPremiumLock(
              key: const Key('wr_career_memory_lock'),
              description: shown.length > readable
                  ? 'Còn ${shown.length - readable} mảnh ký ức nữa, thuộc các '
                      'tuần và tháng trước đó. Bản đầy đủ mở lại từng mảnh, '
                      'đọc lại được bất cứ lúc nào.'
                  : 'Bản đầy đủ mở lại từng mảnh ký ức nghề nghiệp bạn đã để '
                      'lại, đọc lại được bất cứ lúc nào, theo đúng dòng thời '
                      'gian.',
              ctaLabel: 'Mở khoá toàn bộ Career Memory',
              paywallTrigger: 'career_memory',
            )
          else
            Text(
              'Đã hiện ${shown.length}/${all.length} mảnh ký ức gần nhất.',
              key: const Key('wr_career_memory_shown_count'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: WrColors.muted),
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

/// Một mảnh ký ức trên dòng thời gian.
///
/// BA TẦNG CHỮ, đúng `CAREER_MEMORY_ENTRIES` của mockup v16:
///
///   nhãn loại + tiêu đề + trích  · luôn hiện
///   chi tiết ("vì sao mảnh này có mặt")  · chỉ hiện khi bấm mở
///
/// Bản trước thu gọn tới mức chỉ còn NHÃN LOẠI — một cột "CÂU CHUYỆN · CÂU
/// CHUYỆN · CỘT MỐC" không phân biệt được mảnh nào với mảnh nào, và người dùng
/// phải mở từng cái ra mới biết mình đang nhìn gì. Mockup bày tiêu đề và trích
/// ngay từ đầu; thứ nằm sau cú chạm là dòng luật, không phải nội dung.
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
    this.locked = false,
  });

  final JourneyEntry entry;
  final bool isLast;

  /// Mở màn đọc riêng của mốc này. Null khi mốc không có màn riêng.
  final VoidCallback? onTap;

  /// Tắt khi ngày đã nằm ở tiêu đề nhóm ngày — in lại "01/08" ngay dưới dòng
  /// "Thứ Sáu, 01/08" là nói cùng một điều hai lần.
  final bool showDate;

  /// Mảnh nằm ngoài phần bản miễn phí đọc được (mockup v16: `!g.current &&
  /// !isPremium`). Nhãn loại và ngày vẫn hiện — người dùng thấy mình đã để lại
  /// bao nhiêu, chỉ nội dung là khoá.
  final bool locked;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isLast = widget.isLast;
    final locked = widget.locked;
    final onTap = locked ? null : widget.onTap;
    final showDate = widget.showDate;
    final at = entry.at;
    final dateStr = (at == null || !showDate)
        ? ''
        // Năm đã nằm ở tiêu đề tháng, không lặp lại trên từng dòng.
        : '${at.day.toString().padLeft(2, '0')}/'
            '${at.month.toString().padLeft(2, '0')}';

    return InkWell(
      // Mảnh đã khoá thì không mở ra được — không có gì bên trong để mở.
      onTap: locked ? null : () => setState(() => _open = !_open),
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
                      // Tiêu đề và trích LUÔN hiện — mockup v16. Khoá thì thay
                      // bằng câu nói rõ là đang khoá, không để trống: một hàng
                      // chỉ còn nhãn loại đọc như một lỗi tải dở.
                      const SizedBox(height: 6),
                      WrParagraph(
                        locked ? 'Nội dung đã khoá' : entry.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: locked ? WrColors.muted : WrColors.navy,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.start,
                      ),
                      if (locked) ...[
                        const SizedBox(height: 4),
                        const WrParagraph(
                          'Mở bản đầy đủ để đọc lại mảnh ký ức này.',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: WrColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ] else if (entry.subtitle != null &&
                          entry.subtitle!.isNotEmpty &&
                          entry.subtitle != entry.title) ...[
                        const SizedBox(height: 4),
                        WrParagraph(
                          entry.subtitle!,
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: WrColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (_open && !locked) ...[
                        // Dòng luật — vì sao mảnh này có mặt ở đây. Tách khỏi
                        // nội dung bằng một đường kẻ, đúng mockup.
                        if (entry.detail != null &&
                            entry.detail!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            height: 1,
                            color: WrColors.navy.withValues(alpha: 0.1),
                          ),
                          const SizedBox(height: 10),
                          WrParagraph(
                            entry.detail!,
                            key: const Key('wr_journey_entry_detail'),
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: WrColors.muted,
                              height: 1.55,
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
                // Mảnh đã khoá thì KHÔNG có mũi tên — mockup v16 cũng vậy: mời
                // chạm vào một thứ không mở ra được là một lời hứa hụt.
                if (!locked) ...[
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
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}
