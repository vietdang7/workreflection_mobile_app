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

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_career_memory_rules.dart';
import '../../../core/logic/wr_chapters.dart'
    show buildChapters, kWrChaptersVisible;
import '../../../core/logic/wr_dominant_need.dart';
import '../../../core/logic/wr_reflect_flow.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_practice_v47.dart';
import '../../../core/logic/wr_reflect_v47.dart' show rebuildEpisodeInsight;
import '../../../core/logic/wr_skill_formation.dart'
    show kPracticeMaintainedBehavior;
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_episode.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../../../core/widgets/wr_small_button.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

/// Số dòng mặc định khi thu gọn bản kể
const int kNarrativeCollapsedLines = 4;

/// Loại mục của "Những gì bạn đã học" (mockup v47): Cột mốc hay Điều đã thử.
enum JourneyLearnedKind { milestone, tried }

/// Loại mảnh ký ức theo bốn loại của script (`TYPE_META`), cộng một loại "khác"
/// cho các mảnh thực hành / ghi chú.
///
/// Nhãn hiển thị ([JourneyEntry.label]) không đủ để phân loại: STORY mang nhãn
/// "Câu chuyện" ở Career Memory nhưng "Phản chiếu" ở phần xem trước của tab
/// Hành trình, và INSIGHT phải khoá với bản miễn phí ở mọi nơi hiện nó.
enum JourneyEntryKind { story, milestone, theme, insight, other }

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
    this.learned,
    this.kind = JourneyEntryKind.other,
  });

  /// Loại của mảnh, xem [JourneyEntryKind].
  final JourneyEntryKind kind;

  /// INSIGHT chỉ dành cho Premium (script: "INSIGHT … luôn gắn nhãn Premium",
  /// "chỉ hiển thị cho người dùng Premium").
  bool get premiumOnly => kind == JourneyEntryKind.insight;

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

  /// Khác null nghĩa là mục này là một điều đã thật sự xảy ra (một bài học,
  /// một lần thử) và hiện cả ở "Những gì bạn đã học" (mockup v47).
  final JourneyLearnedKind? learned;
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

/// Câu trích của một Episode trên dòng thời gian, dựng lại theo ngôn ngữ đang
/// bật. Null khi Episode không có gì để trích.
///
/// Ưu tiên bản dựng lại; chỉ khi Episode không có ghi chú `reframe` NÀO và cũng
/// không tra được câu aha thì mới đọc `draft_meaning` — những Episode ghi từ
/// trước lúc tách `notes` ra khỏi bản gộp.
String? _ownInsight(ReflectionEpisode e) {
  if (e.notes[ReflectionPattern.reframe.dbValue]?.trim().isNotEmpty == true) {
    return null;
  }
  final own = e.draftMeaning?.trim();
  return own == null || own.isEmpty ? null : own;
}

String? _episodeExcerpt(ReflectionEpisode e, String? aha) {
  final hasNote =
      e.notes[ReflectionPattern.reframe.dbValue]?.trim().isNotEmpty == true;
  if (hasNote || aha != null) {
    final live = liveMeaning(notes: e.notes, storyAha: aha).trim();
    if (live.isNotEmpty) return live;
  }
  final frozen = e.draftMeaning?.trim();
  return frozen == null || frozen.isEmpty ? null : frozen;
}

/// Dựng dòng thời gian từ Episode + Career Memory event, mới nhất trước.
///
/// Chỉ Episode đã khép lại mới vào Hành trình — WDA Inv.6: chưa có ý nghĩa
/// thì chưa phải ký ức nghề nghiệp.
/// Đọc lại một dòng chữ đã ĐÓNG BĂNG theo ngôn ngữ đang bật.
///
/// [frozen] là `reflection_text` của mảnh ký ức thực hành, ghép sẵn lúc người
/// dùng bấm xong bước. Ba dạng nó có thể mang:
///
///   "‹chủ đề› · ‹bước›"      — xong một bước
///   "‹chủ đề›"                — xong cả chủ đề
///   "‹bước›: ‹lời người dùng›" — điều mình ghi lại
///
/// Chỉ phần TÊN được tra lại; lời người dùng viết giữ nguyên văn.
///
/// Dạng thứ ba không tách được bằng cách cắt ở dấu hai chấm ĐẦU TIÊN: chính tên
/// bước đã chứa dấu hai chấm ("Thử nghiệm: Chủ động hỏi lý do thay đổi"). Nên
/// đi theo chiều ngược lại — thử khớp tên DÀI NHẤT mà đoạn chữ mở đầu bằng nó.
String localizeFrozenPracticeText(String frozen, Map<String, String> labels) {
  if (labels.isEmpty) return frozen;

  String segment(String raw) {
    final s = raw.trim();
    final exact = labels[s];
    if (exact != null) return exact;

    String? bestKey;
    for (final key in labels.keys) {
      if (!s.startsWith('$key: ')) continue;
      if (bestKey == null || key.length > bestKey.length) bestKey = key;
    }
    if (bestKey == null) {
      // Bản ghi trước 05/08: "‹chủ đề› — ‹giai đoạn›" ("Dám lên tiếng — Nhận
      // diện"). Chỉ đổi khi CẢ HAI vế đều là tên — tên bước cũ cũng chứa " — ".
      final dash = s.indexOf(' — ');
      if (dash > 0) {
        final head = labels[s.substring(0, dash)];
        final tail = labels[s.substring(dash + 3)];
        if (head != null && tail != null) return '$head — $tail';
      }
      return raw;
    }
    // Phần sau dấu hai chấm cũng có thể là một TÊN: mảnh duy trì ghi
    // "Duy trì: ‹chủ đề›". Chỉ đổi khi khớp trọn một tên — lời người dùng tự
    // viết thì giữ nguyên.
    final rest = s.substring(bestKey.length + 2);
    return '${labels[bestKey]}: ${labels[rest.trim()] ?? rest}';
  }

  return frozen.split(' · ').map(segment).join(' · ');
}

/// Câu Cột mốc do app tự viết rồi lưu vào `reflection_text` — đóng băng theo
/// ngôn ngữ lúc GHI. Mỗi cặp là (bản Việt, bản Anh) đúng như chỗ ghi.
const _kFrozenMilestoneSentences = [
  // `wr_stance_keep_screen.dart` — `_confirmStance`.
  (
    'Bạn xác nhận một tâm thế đang hình thành',
    'You confirmed a stance that is taking shape',
  ),
];

/// Tiền tố của câu Cột mốc ghép với một tên (chủ đề / việc thực hành).
const _kFrozenMilestonePrefixes = [
  // `wr_practice_step_completion.dart` — hết bốn bước của chủ đề.
  ('Hết một vòng: ', 'One full round: '),
  // `wr_user_actions_section.dart` — đủ 5 ngày một việc tự đặt.
  ('Đã hoàn thành 5 ngày thực hành: ', 'Completed 5-day practice: '),
];

/// Câu trả lời cuối chặng (`wr_chapter_read_screen.dart`).
const _kFrozenChapterExcerpts = [
  ('Chuyện đó đã nhẹ đi thật.', 'It really has eased.'),
  ('Mình chỉ thôi để ý tới nó.', 'I just stopped noticing it.'),
];

final _frozenChapterLine = RegExp(
  r'^(?:Chặng|Chapter) (\d+): (?:bạn trả lời câu hỏi cuối chặng|you answered the end-of-chapter question)\. ?(.*)$',
  dotAll: true,
);

/// Đọc lại câu Cột mốc đã ĐÓNG BĂNG theo ngôn ngữ đang bật.
///
/// Cùng bệnh với [localizeFrozenPracticeText]: câu được ghép bằng `tr()` lúc
/// GHI rồi lưu nguyên vào DB, nên ghi lúc đang tiếng Việt thì bật tiếng Anh vẫn
/// đọc ra tiếng Việt (máy thật 16/10: "Bạn xác nhận một tâm thế đang hình
/// thành"). Chỉ nhận đúng những câu app tự viết; Cột mốc người dùng tự viết
/// (màn Tâm thế, "Ghi lại") không khớp mẫu nào nên giữ nguyên văn.
String localizeFrozenMilestoneText(
  String frozen,
  Map<String, String> labels,
) {
  final s = frozen.trim();
  for (final (vi, en) in _kFrozenMilestoneSentences) {
    if (s == vi || s == en) return tr(vi, en);
  }
  for (final (vi, en) in _kFrozenMilestonePrefixes) {
    final prefix = s.startsWith(vi) ? vi : (s.startsWith(en) ? en : null);
    if (prefix == null) continue;
    final name = s.substring(prefix.length);
    return '${tr(vi, en)}${labels[name.trim()] ?? name}';
  }
  final chapter = _frozenChapterLine.firstMatch(s);
  if (chapter != null) {
    final n = chapter.group(1)!;
    var excerpt = chapter.group(2)!.trim();
    for (final (vi, en) in _kFrozenChapterExcerpts) {
      if (excerpt == vi || excerpt == en) excerpt = tr(vi, en);
    }
    return tr(
      'Chặng $n: bạn trả lời câu hỏi cuối chặng. $excerpt',
      'Chapter $n: you answered the end-of-chapter question. $excerpt',
    ).trim();
  }
  return frozen;
}

List<JourneyEntry> buildJourneyEntries({
  required List<ReflectionEpisode> episodes,
  required List<CareerMemoryEvent> events,
  required Map<String, String> situationLabels,
  Map<String, String> ahaByCode = const {},
  Map<String, String> practiceLabels = const {},
  // Cần CẢ HAI bản ngôn ngữ của nhãn tình huống, nên không dùng lại được
  // [situationLabels] — map đó chỉ giữ bản đang bật. Xem
  // `localizeFrozenInsightText`.
  List<WrSituation> situations = const [],
  // Tên chủ đề thực hành theo ngôn ngữ đang bật, theo `theme_id` — cho Cột mốc
  // "Lần đầu thử một cách khác: …", vốn chỉ lưu tên tiếng Việt.
  Map<String, String> themeTitles = const {},
  // Để dựng lại câu Insight v47 đã lưu theo ngôn ngữ đang bật
  // (`rebuildEpisodeInsight`).
  List<WrStory> stories = const [],
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
    final situation = e.situationCode != null
        ? situationLabels[e.situationCode]
        : null;
    entries.add(
      JourneyEntry(
        at: e.closedAt ?? e.updatedAt ?? e.openedAt,
        label: milestone == null ? kStoryLabel : kMilestoneLabel,
        // Mockup v16: title là TÊN GỌI của mảnh ("Reflection: Cuộc họp bị ngắt
        // lời"), excerpt mới là nội dung. Bản trước đặt điều-nhận-ra vào title
        // rồi nhét tình huống xuống dưới, nên hai mảnh cùng một tình huống trông
        // không liên quan gì tới nhau trên dòng thời gian.
        kind: milestone == null
            ? JourneyEntryKind.story
            : JourneyEntryKind.milestone,
        // Script `CAREER_MEMORY_ENTRIES`: "Reflection: ‹tên tình huống›".
        title: situation != null && situation.trim().isNotEmpty
            ? tr(
                'Lần nhìn lại: ${situation.trim().replaceFirst(RegExp(r'^Tôi vừa '), '')}',
                'Look-back: ${situation.trim()}',
              )
            : e.humanMoment.label,
        // Dựng LẠI câu ý nghĩa thay vì đọc `draft_meaning` đã đóng băng.
        //
        // `draft_meaning` được ghi bằng ngôn ngữ đang bật lúc bấm lưu và không bao
        // giờ đổi nữa. Tiêu đề ngay trên nó thì đọc `wr_situations.text_en` nên
        // dịch được — thành ra bật tiếng Anh lên là mỗi dòng trên Hành trình có
        // một nửa tiếng Anh, một nửa tiếng Việt. Đó là chỗ khách chỉ ra 10/09.
        //
        // [liveMeaning] ghép lại từ chữ người dùng (giữ nguyên) và câu aha của
        // story (đọc lại theo ngôn ngữ đang bật). Rơi về `draft_meaning` khi
        // Episode không có ghi chú lẫn story — dữ liệu cũ trước lúc tách notes.
        subtitle:
            // Câu Insight v47 do app dựng trọn: dựng lại đúng câu người dùng
            // đã giữ, theo ngôn ngữ đang bật.
            (e.draftMeaning == null
                ? null
                : rebuildEpisodeInsight(
                    e.draftMeaning!,
                    episode: e,
                    situations: situations,
                    stories: stories,
                  )) ??
            // Lượt v47 không có ghi chú bước reframe: `draft_meaning` không
            // dựng lại được tức là câu người dùng bấm "Chưa đúng" rồi tự viết.
            // Giữ nguyên chữ của họ, đừng rơi xuống câu aha mẫu.
            _ownInsight(e) ??
            _episodeExcerpt(e, ahaByCode[e.situationCode]) ??
            situation ??
            e.humanMoment.label,
        detail: memoryDetailForStory(
          story: e,
          countThisMonth: needCountThisMonth(e, closed),
          milestoneText: milestone,
        ),
        color: milestone == null ? WrColors.navy : WrColors.coral,
        episodeId: e.id,
      ),
    );
  }

  // Khi đã đọc được Episode thì bỏ event do chính Episode sinh ra.
  final skipEpisodeEvents = closed.isNotEmpty;
  for (final ev in events) {
    if (skipEpisodeEvents && ev.behavior == kEpisodeBehavior) continue;

    final text = ev.reflectionText?.trim();
    final hasText = text != null && text.isNotEmpty;

    // Mockup v47: lần đầu thử một bước của chủ đề, và bài học ghi ở màn "Bạn
    // vừa học được điều hữu ích". Câu tiêu đề dựng lúc hiển thị, DB chỉ giữ tên
    // chủ đề / lời người dùng.
    if (ev.behavior == kMilestoneBehavior && ev.themeId != null) {
      final name = (themeTitles[ev.themeId] ?? (hasText ? text : '')).trim();
      entries.add(
        JourneyEntry(
          at: ev.createdAt,
          label: kMilestoneLabel,
          title: name.isEmpty
              ? tr(
                  'Lần đầu thử một cách khác',
                  'First time trying a different way',
                )
              : tr(
                  'Lần đầu thử một cách khác: $name',
                  'First time trying a different way: $name',
                ),
          subtitle: tr(
            'Bạn đã thử bước đầu tiên của chủ đề này.',
            'You tried the first step of this theme.',
          ),
          color: WrColors.coral,
          learned: JourneyLearnedKind.milestone,
          kind: JourneyEntryKind.milestone,
        ),
      );
      continue;
    }
    if (ev.behavior == kLearningBehavior) {
      entries.add(
        JourneyEntry(
          at: ev.createdAt,
          label: kMilestoneLabel,
          title: tr(
            'Bạn vừa học được điều hữu ích',
            'You just learned something useful',
          ),
          subtitle: hasText ? text : null,
          color: WrColors.coral,
          learned: JourneyLearnedKind.milestone,
          kind: JourneyEntryKind.milestone,
        ),
      );
      continue;
    }

    // Chủ đề và Insight có TÊN GỌI riêng, và nội dung do máy sinh ra thì xuống
    // làm excerpt. Mockup v16: "Chủ đề mới xuất hiện: …" / "Pattern được nhận
    // diện". Bản trước đẩy nguyên đoạn văn lên làm tiêu đề, nên thu gọn lại thì
    // dòng thời gian là một cột những đoạn dài không phân biệt được với nhau.
    if (ev.behavior == kThemeBehavior || ev.behavior == kInsightBehavior) {
      final isTheme = ev.behavior == kThemeBehavior;
      final need = ev.humanNeed;
      entries.add(
        JourneyEntry(
          at: ev.createdAt,
          label: eventTypeLabel(ev),
          title: isTheme
              ? (need != null
                    ? tr(
                        'Chủ đề mới xuất hiện: ${needSeekingLabel(need)}',
                        'A new theme appeared: ${needSeekingLabel(need)}',
                      )
                    : tr('Một chủ đề mới xuất hiện', 'A new theme appeared'))
              // Script `CAREER_MEMORY_ENTRIES`: INSIGHT mang tên gọi cố định
              // "Pattern được nhận diện".
              : tr('Điều đang lặp lại', 'Something that keeps coming back'),
          // Câu này được GHÉP SẴN lúc khép lượt nhìn lại rồi lưu vào
          // `reflection_text`, nên nó mang ngôn ngữ của thời điểm GHI chứ không
          // phải thời điểm đọc — dựng lại theo ngôn ngữ đang bật, cùng cách đã
          // làm cho chữ thực hành ngay bên dưới.
          subtitle: hasText
              ? localizeFrozenInsightText(text, situations: situations)
              : null,
          detail: isTheme ? kThemeDetail : kInsightDetail,
          color: eventColor(ev),
          kind: isTheme ? JourneyEntryKind.theme : JourneyEntryKind.insight,
        ),
      );
      continue;
    }

    // Ba loại mảnh ký ức thực hành mang chữ GHÉP SẴN từ tên chủ đề và tên bước
    // — tra lại theo ngôn ngữ đang bật, xem `localizeFrozenPracticeText`.
    final isPracticeText =
        ev.behavior == 'practice_step_done' ||
        ev.behavior == 'practice_theme_done' ||
        ev.behavior == kPracticeMaintainedBehavior ||
        ev.behavior == kPracticeStepNoteBehavior ||
        // Kỹ năng hình thành lưu đúng TÊN chủ đề.
        ev.behavior == 'skill_certified';
    // Cột mốc không gắn chủ đề (đã xử lý ở trên) và việc tự đặt xong 5 ngày:
    // câu do app viết, xem `localizeFrozenMilestoneText`.
    final isMilestoneText =
        ev.behavior == kMilestoneBehavior ||
        ev.behavior == 'user_action_completed';
    final shownText = !hasText
        ? text
        : isPracticeText
        ? localizeFrozenPracticeText(text, practiceLabels)
        : isMilestoneText
        ? localizeFrozenMilestoneText(text, practiceLabels)
        : text;

    // Mockup v47: một lần thử là "Thực hành: ‹việc›" + "Bạn đã thử: ‹việc›.".
    // `reflection_text` mang "‹chủ đề› · ‹bước›", việc là phần sau nhãn giai
    // đoạn của bước.
    if (ev.behavior == 'practice_step_done' && hasText) {
      final action = practiceStepAction(shownText!.split(' · ').last);
      entries.add(
        JourneyEntry(
          at: ev.createdAt,
          label: eventTypeLabel(ev),
          title: tr('Thực hành: $action', 'Practice: $action'),
          subtitle: tr('Bạn đã thử: $action.', 'You tried: $action.'),
          color: eventColor(ev),
          learned: JourneyLearnedKind.tried,
        ),
      );
      continue;
    }

    // Không rơi về chính cái mã: `C2-sit-01` là thuật ngữ nội bộ, không phải
    // thứ để người dùng đọc trên dòng thời gian của đời mình (v1.6 §XII.5).
    final title = ev.situationCode != null
        ? (situationLabels[ev.situationCode] ??
              (hasText ? shownText! : tr('Một lần nhìn lại', 'One look back')))
        : (hasText ? shownText! : emotionLabel(ev.emotion));
    final mood = ev.emotion?.isNotEmpty == true
        ? emotionLabel(ev.emotion)
        : null;
    entries.add(
      JourneyEntry(
        at: ev.createdAt,
        label: eventTypeLabel(ev),
        title: title,
        subtitle: mood == title ? null : mood,
        color: eventColor(ev),
      ),
    );
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

List<String> get _kWeekdayVi => [
  tr('Thứ Hai', 'Monday'),
  tr('Thứ Ba', 'Tuesday'),
  tr('Thứ Tư', 'Wednesday'),
  tr('Thứ Năm', 'Thursday'),
  tr('Thứ Sáu', 'Friday'),
  tr('Thứ Bảy', 'Saturday'),
  tr('Chủ Nhật', 'Sunday'),
];

String _dd(int n) => n.toString().padLeft(2, '0');

/// Nửa đêm của [d] theo giờ máy — khoá gom nhóm theo ngày, bỏ phần giờ.
///
/// `created_at`/`closed_at` từ Supabase là UTC: không đổi sang giờ máy thì một
/// mục ghi lúc 5 giờ sáng Thứ Hai ở Việt Nam rơi về Chủ Nhật tuần trước.
DateTime _dayKey(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Thứ Hai của tuần chứa [d]. Tuần bắt đầu từ Thứ Hai theo lịch Việt Nam.
DateTime _mondayOf(DateTime d) =>
    _dayKey(d).subtract(Duration(days: d.toLocal().weekday - DateTime.monday));

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
    final at = e.at?.toLocal();
    if (at == null) {
      undated.add(e);
      continue;
    }
    final key = tr('THÁNG ${at.month}, ${at.year}', '${at.month}/${at.year}');
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

    final anyDate = monthEntries.first.at!.toLocal();
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

      weeks.add(
        JourneyWeek(
          label: tr(
            'TUẦN ${weekNumber[monday]} · $range',
            'WEEK ${weekNumber[monday]} · $range',
          ),
          isCurrent: monday == _mondayOf(now),
          days: [
            for (final day in dayOrder)
              JourneyDay(
                date: day,
                label: switch (day) {
                  _ when day == today => tr('Hôm nay', 'Today'),
                  _ when day == yesterday => tr('Hôm qua', 'Yesterday'),
                  _ =>
                    '${_kWeekdayVi[day.weekday - 1]}, '
                        '${_dd(day.day)}/${_dd(day.month)}',
                },
                entries: byDay[day]!,
              ),
          ],
        ),
      );
    }

    months.add(JourneyMonthDetailed(label: monthLabel, weeks: weeks));
  }

  if (undated.isNotEmpty) {
    months.add(
      JourneyMonthDetailed(
        label: tr('CHƯA RÕ THỜI GIAN', 'NO DATE'),
        weeks: [
          JourneyWeek(
            label: '',
            days: [JourneyDay(date: DateTime(0), label: '', entries: undated)],
          ),
        ],
      ),
    );
  }

  return months;
}

String emotionLabel(String? emotion) => switch (emotion) {
  'low' => tr('Mệt mỏi', 'Drained'),
  'ok' => tr('Ổn', 'Okay'),
  'good' => 'Vui',
  _ => emotion ?? tr('Ghi chú', 'Note'),
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
String get kStoryLabel => tr('CÂU CHUYỆN', 'STORY');
String get kMilestoneLabel => tr('CỘT MỐC', 'MILESTONE');
String get kThemeLabel => tr('CHỦ ĐỀ', 'THEME');
// "Insight" vào danh sách từ đã bỏ ("Logic đọc hiểu mình" §8, 15/10/2026),
// thay bằng "Phần đọc", dù mockup v77 vẫn ghi Insight.
String get kInsightLabel => tr('PHẦN ĐỌC', 'READING');

/// Nhãn loại của một mốc trên timeline Hành trình.
///
/// v1.6 §9.1 liệt kê bốn nhãn MILESTONE/STORY/THEME/INSIGHT, nhưng đó là tên
/// loại nội bộ. §XII.5 yêu cầu không phơi thuật ngữ nội bộ ra người dùng, nên ở
/// đây dùng tiếng Việt — quyết định đã chốt với owner 2026-07-28.
String eventTypeLabel(CareerMemoryEvent e) {
  if (e.behavior == kEpisodeBehavior) return kStoryLabel;
  // Ba loại được SINH THÊM từ STORY (changelog 24/08 §8.2). Nhãn tiếng Việt
  // đúng như §8.1 đòi: Cột mốc / Chủ đề / Insight, không phải mã viết hoa.
  if (e.behavior == kMilestoneBehavior || e.behavior == kLearningBehavior) {
    return kMilestoneLabel;
  }
  if (e.behavior == kThemeBehavior) return kThemeLabel;
  if (e.behavior == kInsightBehavior) return kInsightLabel;
  if (e.behavior == 'skill_certified') return tr('KỸ NĂNG', 'SKILL');
  if (e.behavior == 'user_action_completed') {
    return tr('TỰ RÈN LUYỆN', 'SELF PRACTICE');
  }
  if (e.behavior == kPracticeStepNoteBehavior) {
    return tr('ĐIỀU MÌNH GHI LẠI', 'WHAT I WROTE DOWN');
  }
  if (e.behavior == 'practice_step_done' ||
      e.behavior == 'practice_theme_done') {
    return tr('THỰC HÀNH', 'PRACTICE');
  }
  if (e.behavior == 'insight') return tr('NHẬN RA', 'NOTICED');
  if (e.behavior == 'decision') return tr('QUYẾT ĐỊNH', 'DECISION');
  if (e.storyId != null) return tr('PHẢN CHIẾU', 'LOOK-BACK');
  if (e.situationCode != null) return tr('TRẢI NGHIỆM', 'EXPERIENCE');
  return tr('GHI CHÚ', 'NOTE');
}

Color eventColor(CareerMemoryEvent e) {
  if (e.behavior == kEpisodeBehavior) return WrColors.navy;
  // Bốn màu đúng `TYPE_META` của mockup v16: Cột mốc coral · Câu chuyện navy ·
  // Chủ đề teal · Insight coral. Bản trước dùng hổ phách cho Chủ đề và xanh
  // dương cho Insight — hai màu không có trong bảng màu nào của thiết kế.
  if (e.behavior == kMilestoneBehavior || e.behavior == kLearningBehavior) {
    return WrColors.coral;
  }
  if (e.behavior == kThemeBehavior) return WrColors.teal;
  if (e.behavior == kInsightBehavior) return WrColors.coral;
  if (e.behavior == 'skill_certified') return WrColors.teal;
  if (e.behavior == 'user_action_completed') return WrColors.teal;
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
/// BỐN, đúng mockup v16 §8.1: "thẻ xem trước lấy 4 mục gần nhất".
/// Sprint 2 chốt 3 thẻ: kJourneyPreviewCount = 3.
const int kJourneyPreviewCount = 3;

/// Dựng dòng thời gian từ các provider — dùng chung giữa tab Hành trình và màn
/// Career Memory đầy đủ, để hai nơi không bao giờ liệt kê khác nhau.
List<JourneyEntry> watchJourneyEntries(WidgetRef ref) {
  final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
  final events = ref.watch(wrMemoryEventsProvider).valueOrNull ?? const [];
  final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
  final stories = ref.watch(wrStoriesProvider).valueOrNull ?? const [];
  return buildJourneyEntries(
    episodes: episodes,
    events: events,
    situationLabels: {for (final s in situations) s.code: s.text},
    // `story.ahaMessage` đi qua `trDb` nên map này tự đúng ngôn ngữ đang bật.
    ahaByCode: {
      for (final s in stories)
        if (s.ahaMessage != null) s.storyId: s.ahaMessage!,
    },
    practiceLabels: ref.watch(wrPracticeLabelMapProvider),
    situations: situations,
    stories: stories,
    themeTitles: {
      for (final t
          in ref.watch(practiceThemesProvider).valueOrNull ??
              const <PracticeTheme>[])
        t.themeId: t.title,
    },
  );
}

class WrJourneyScreen extends ConsumerWidget {
  const WrJourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement =
        ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);

    final all = watchJourneyEntries(ref);
    final shown = all.take(kJourneyPreviewCount).toList();
    // Script `screenGrow`: phần xem trước KHÔNG khoá theo tuần, mục nào cũng
    // chỉ mở ra / thu lại tại chỗ. Thứ duy nhất khoá là INSIGHT với bản miễn
    // phí (script: "INSIGHT … luôn gắn nhãn Premium").
    bool isLocked(JourneyEntry e) => e.premiumOnly && !entitlement.isPremium;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        // Padding tường minh: `ListView` không có padding sẽ xoá phần thanh
        // trạng thái khỏi `MediaQuery` của con, ảnh hero hết tràn lên.
        padding: const EdgeInsets.only(bottom: 34),
        children: [
          WrHeroHeader.inner(
            key: const Key('wr_journey_hero'),
            art: WrHeroArt.grow,
            eyebrow: tr('Hành trình', 'Journey'),
            title: tr('Hành trình của bạn', 'Your journey'),
            subtitle: tr(
              // Ngắt cho hai dòng dài gần bằng nhau: dòng dài quá thì cả khối
              // bị thu nhỏ theo nó (máy thật 15/10).
              'Nhìn lại những gì đã ở lại, để thấy\nmình đã thật sự đi qua '
                  'điều gì.',
              'Look back at what stayed, to see\nwhat you have truly been '
                  'through.',
            ),
            // v1.6 §9.1: "Tôi" là avatar ở mọi màn tab.
            trailing: const WrProfileAvatar(),
          ),
          const SizedBox(height: WrHeroHeader.kContentGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WrTabBackLink(currentTab: WrTab.journey),

                // ── Dấu ấn hành trình ─────────────────────────────────────
                // Script khách: Career Memory lên ĐẦU TRANG.
                Text(wrKeepCompounds(tr('Dấu ấn hành trình', 'Journey marks')), style: _h2),
                const SizedBox(height: 4),
                Text(
                  wrKeepCompounds(tr(
                    'Những lần bạn dừng lại và ghi nhận, thực hành một điều gì đó, giờ các dấu ấn đang cùng ở đây.',
                    'The moments you paused, noticed, and practiced something are all gathered here.',
                  )),
                  style: _muted,
                ),
                const SizedBox(height: 5),
                Text(
                  wrKeepCompounds(tr(
                    '${all.length} ghi nhận đã lưu',
                    '${all.length} saved entries',
                  )),
                  key: const Key('wr_journey_memory_count'),
                  style: _tiny,
                ),
                const SizedBox(height: 12),
                if (all.isEmpty)
                  WrCard(
                    key: const Key('wr_journey_memory_empty'),
                    child: Text(
                      wrKeepCompounds(tr(
                        'Nhật ký sự nghiệp của bạn chưa có ghi nhận nào. Hãy '
                            'bắt đầu một lần nhìn lại để lưu giữ những dấu ấn '
                            'của riêng bạn.',
                        'Your career journal has nothing in it yet. Start a '
                            'look back to keep the marks that are yours.',
                      )),
                      style: _muted,
                    ),
                  )
                else ...[
                  _TimelinePreview(entries: shown, isLocked: isLocked),
                  const SizedBox(height: 4),
                  Center(
                    child: WrSmallButton(
                      key: const Key('wr_journey_memory_see_all'),
                      kind: WrSmallButtonKind.ghost,
                      label: tr('Xem toàn bộ lịch sử', 'See the whole history'),
                      onTap: () => context.push('/wr/career-memory'),
                    ),
                  ),
                ],
                const SizedBox(height: 26),

                // ── HÀNH TRÌNH THEO CHẶNG ─────────────────────────────────
                // Mockup v47 / screenGrow.js: các mốc đã khép lại. Tạm ẩn
                // theo họp khách 14/10, xem [kWrChaptersVisible].
                if (kWrChaptersVisible) ...[
                  const _ChapterJourneyCard(),
                  const SizedBox(height: 26),
                ],

                // ── Trò chuyện về hành trình ──────────────────────────────
                // Script khách: thẻ nổi bật, bấm vào mở trợ lý chat.
                const _AskCard(),
                const SizedBox(height: 26),

                // ── Dòng nhìn lại thời gian ───────────────────────────────
                // Script khách: đẩy xuống dưới Career Memory.
                const _NarrativeCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiêu đề thay thế cho mục bị khoá ở bản Free — cùng chữ với màn Career
/// Memory đầy đủ.
String get kLockedEntryTitle => tr('Nội dung đã khoá', 'Locked');

/// Câu thay cho nội dung mục bị khoá — script `screenCareerMemory`.
String get kLockedEntryBody => tr(
  'Mở khoá Premium để xem toàn bộ ghi nhận này.',
  'Unlock Premium to see this whole entry.',
);

/// Nhãn STORY ở phần xem trước của tab Hành trình — script `screenGrow`.
String get kStoryPreviewLabel => tr('PHẢN CHIẾU', 'LOOK-BACK');

/// Nhãn loại của một mảnh ký ức, kèm thẻ "PREMIUM" với INSIGHT.
class _TypeLabel extends StatelessWidget {
  const _TypeLabel({
    required this.label,
    required this.color,
    required this.premium,
  });

  final String label;
  final Color color;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      wrKeepCompounds(label),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: color,
      ),
    );
    if (!premium) return text;
    return Row(
      children: [
        text,
        const SizedBox(width: 6),
        Container(
          key: const Key('wr_journey_insight_premium_tag'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: WrColors.coral,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'PREMIUM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: WrColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}

const _h2 = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  color: WrColors.navy,
  height: 1.35,
);

const _tiny = TextStyle(fontSize: 12.5, color: WrColors.text3);

const _muted = TextStyle(fontSize: 14, color: WrColors.text2, height: 1.6);

String _ddmm(DateTime d) {
  final l = d.toLocal();
  return '${_dd(l.day)}/${_dd(l.month)}';
}

// ---------------------------------------------------------------------------
// Dấu ấn hành trình — dòng thời gian 4 mục (mockup v47 `.timeline-*`)
// ---------------------------------------------------------------------------

class _TimelinePreview extends StatelessWidget {
  const _TimelinePreview({required this.entries, required this.isLocked});

  final List<JourneyEntry> entries;
  final bool Function(JourneyEntry) isLocked;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // `.timeline-line`: kẻ dọc 2px nối các chấm.
        const Positioned(
          left: 4,
          top: 6,
          bottom: 0,
          child: SizedBox(
            width: 2,
            child: ColoredBox(color: WrColors.lineSoft),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < entries.length; i++)
              _TimelineItem(
                key: Key('wr_journey_timeline_$i'),
                entry: entries[i],
                locked: isLocked(entries[i]),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimelineItem extends StatefulWidget {
  const _TimelineItem({super.key, required this.entry, required this.locked});

  final JourneyEntry entry;
  final bool locked;

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final excerpt = e.subtitle?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // `.timeline-dot`: chấm 10px, viền trắng 4px.
          Positioned(
            left: 0,
            top: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: e.color,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.white, spreadRadius: 4),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Material(
              color: _expanded ? const Color(0x05093774) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: WrColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.locked
                    ? () => context.push('/wr/paywall?trigger=ai_insight')
                    : () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TypeLabel(
                        // Script `screenGrow` TYPE_META: ở phần xem trước STORY
                        // mang nhãn "Phản chiếu" (Career Memory: "Câu chuyện").
                        label: e.kind == JourneyEntryKind.story
                            ? kStoryPreviewLabel
                            : e.label.toUpperCase(),
                        color: e.color,
                        premium: e.premiumOnly,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            // Khoá thì giấu cả tiêu đề: với nhiều loại mục,
                            // tiêu đề chính là lời người dùng viết.
                            child: Text(
                              wrKeepCompounds(widget.locked ? kLockedEntryTitle : e.title),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: widget.locked
                                    ? WrColors.text2
                                    : WrColors.navy,
                                height: 1.35,
                              ),
                            ),
                          ),
                          if (e.at != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              wrKeepCompounds(_ddmm(e.at!)),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: WrColors.text3,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_expanded &&
                          excerpt != null &&
                          excerpt.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          wrKeepCompounds('“$excerpt”'),
                          key: Key('wr_journey_timeline_excerpt_${e.title}'),
                          style: WrText.serifQuote(
                            fontSize: 14,
                            color: WrColors.text2,
                            height: 1.5,
                          ),
                        ),
                        if (e.episodeId != null) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () =>
                                context.push('/wr/episode/${e.episodeId}'),
                            child: Text(
                              wrKeepCompounds(tr(
                                'Đọc lại lần nhìn lại này',
                                'Read this look back',
                              )),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: WrColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (!_expanded) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              wrKeepCompounds(widget.locked
                                  ? tr('Premium · Mở khoá', 'Premium · Unlock')
                                  : tr('Chạm để xem', 'Tap to see')),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: WrColors.text3,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              widget.locked
                                  ? Icons.lock_outline
                                  : Icons.expand_more,
                              size: 14,
                              color: WrColors.text3,
                            ),
                          ],
                        ),
                      ],
                    ],
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

// ---------------------------------------------------------------------------
// Hành trình theo chặng — mockup v47 / screenGrow.js
// ---------------------------------------------------------------------------

/// Số ngày kể từ lúc chặng gần nhất khép mà thẻ vẫn gắn nhãn "Có chặng mới".
///
/// Script `screenGrow` gắn pill khi `latestChapter().isNew`; app chưa lưu trạng
/// thái "đã đọc" của từng chặng, nên "mới" ở đây là chặng vừa khép trong vòng
/// hai tuần.
const int kChapterNewDays = 14;

class _ChapterJourneyCard extends ConsumerWidget {
  const _ChapterJourneyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    // Chặng tính từ Episode thật (`buildChapters`, luật khép chặng của
    // script), không còn ước lượng "mỗi 5 lần là một chặng".
    final chapters = buildChapters(
      episodes,
      labels: {for (final s in situations) s.code: s.text},
      now: now,
    );
    final latest = chapters.isEmpty ? null : chapters.last;
    final hasNew =
        latest != null &&
        now.difference(latest.end).inDays < kChapterNewDays;

    return WrCard(
      key: const Key('wr_journey_chapters_card'),
      onTap: () => context.push('/wr/chapters'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                wrKeepCompounds(tr('HÀNH TRÌNH THEO CHẶNG', 'JOURNEY BY CHAPTERS')),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: WrColors.text3,
                  letterSpacing: 0.6,
                ),
              ),
              if (hasNew)
                Container(
                  key: const Key('wr_journey_chapters_new'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: WrColors.coral,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    wrKeepCompounds(tr('Có chặng mới', 'New chapter')),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                    ),
                  ),
                )
              else
                const Text(
                  '›',
                  style: TextStyle(
                    fontSize: 16,
                    color: WrColors.text3,
                    fontWeight: FontWeight.w300,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            wrKeepCompounds(chapters.isEmpty
                ? tr('Chưa có chặng nào khép lại', 'No chapter closed yet')
                : tr(
                    '${chapters.length} chặng đã đi qua',
                    '${chapters.length} chapters passed',
                  )),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            wrKeepCompounds(tr(
              'Cứ sau một quãng đủ dài, hệ thống đọc lại quãng đó và ghi ra điều gì đã đổi so với chặng trước.',
              'After a long enough stretch, the system reads through it and notes what changed compared to previous chapter.',
            )),
            style: const TextStyle(
              fontSize: 13.5,
              color: WrColors.text2,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trò chuyện về hành trình — thẻ nổi bật (script khách)
// ---------------------------------------------------------------------------

class _AskCard extends StatelessWidget {
  const _AskCard();

  @override
  Widget build(BuildContext context) {
    return WrCardNavy(
      key: const Key('wr_journey_ask_card'),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/wr/ask'),
        borderRadius: BorderRadius.circular(WrCard.kRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(WrCard.kRadius),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 88,
                    width: double.infinity,
                    child: Image.asset(
                      'assets/images/card_chat.webp',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.08),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            WrColors.navy.withValues(alpha: 0.0),
                            WrColors.navy,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 6, 17, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wrKeepCompounds(tr('NGƯỜI ĐỒNG HÀNH', 'COMPANION')),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: WrColors.cream.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wrKeepCompounds(tr('Trò chuyện về hành trình', 'Talk about your journey')),
                    style: const TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: WrColors.cream,
                      height: 1.32,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    wrKeepCompounds(tr(
                      'Bạn còn những suy tư chưa chia sẻ, cũng như những câu chuyện chưa được sáng tỏ. Hãy trò chuyện cùng người đồng hành để khơi mở sâu hơn nhé.',
                      'You still have thoughts left unsaid and stories waiting to unfold. Talk to your companion to explore deeper.',
                    )),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.6,
                      color: WrColors.cream.withValues(alpha: 0.84),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      key: const Key('wr_journey_ask_row'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: WrColors.coral,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: WrColors.coral.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            wrKeepCompounds(tr('Bắt đầu trò chuyện', 'Start a conversation')),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ],
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


class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard();

  @override
  Widget build(BuildContext context) {
    return WrCard(
      key: const Key('wr_journey_narrative_card'),
      padding: EdgeInsets.zero,
      onTap: () => context.push('/wr/journey/narrative'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(WrCard.kRadius),
            ),
            child: SizedBox(
              height: 110,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.66, 1.0],
                  colors: [Colors.black, Colors.transparent],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  'assets/images/card_timeline.webp',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wrKeepCompounds(tr('Nhìn lại dòng thời gian', 'Looking back along the timeline')),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  wrKeepCompounds(tr(
                    'Những lần nhìn lại của bạn đang chuyển dịch theo một hướng. Dành vài phút đọc chậm.',
                    'Your look-backs are shifting in a meaningful direction. Take a few minutes to read slowly.',
                  )),
                  style: _muted,
                ),
                const SizedBox(height: 12),
                WrSmallButton(
                  key: const Key('wr_journey_narrative_row'),
                  // Script: `btn btn-primary btn-sm` — nút coral.
                  kind: WrSmallButtonKind.primary,
                  label: tr('Đọc diễn giải', 'Read interpretation'),
                  onTap: () => context.push('/wr/journey/narrative'),
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
  final facets =
      tally.entries
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

/// Dựng danh sách Career Memory: mỗi tuần một tiêu đề, mỗi mục một thẻ riêng.
///
/// Script `screenCareerMemory`: nhãn tuần (chữ nhỏ) + nhãn ngày (h2), rồi các
/// thẻ `card card-pad` có chấm màu 8px. Không còn tầng "THÁNG X" ở trên — tuần
/// đã mang khoảng ngày kèm tháng ("TUẦN 2 · 05–11/08").
///
/// Trả về một danh sách phẳng để nhét thẳng vào `children` của WrDetailScaffold.
///
/// [lockOlderWeeks]: bản miễn phí chỉ đọc được tuần này (script: `const locked
/// = !g.current && !state.isPremium`). INSIGHT thì khoá với bản miễn phí ở MỌI
/// tuần ([JourneyEntry.premiumOnly]).
List<Widget> buildJourneyTimeline(
  BuildContext context,
  List<JourneyMonthDetailed> months, {
  bool lockOlderWeeks = false,
}) {
  final out = <Widget>[];
  for (final month in months) {
    for (final week in month.weeks) {
      // Mục không rõ ngày không có nhãn tuần — dùng nhãn "tháng" của nó
      // ("CHƯA RÕ THỜI GIAN") làm tiêu đề.
      final weekLabel = week.label.isNotEmpty ? week.label : month.label;
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            wrKeepCompounds(weekLabel),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.06,
              color: WrColors.navy.withValues(alpha: 0.6),
            ),
          ),
        ),
      );

      final weekLocked = lockOlderWeeks && !week.isCurrent;
      for (final day in week.days) {
        if (day.label.isNotEmpty) {
          out.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                wrKeepCompounds(day.label),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
            ),
          );
        }
        for (final entry in day.entries) {
          out.add(
            _EntryRow(
              entry: entry,
              locked: weekLocked || (lockOlderWeeks && entry.premiumOnly),
              onTap: entry.episodeId == null
                  ? null
                  : () => context.push('/wr/episode/${entry.episodeId}'),
            ),
          );
        }
      }
      out.add(const SizedBox(height: 14));
    }
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
    final entitlement =
        ref.watch(wrEntitlementProvider).valueOrNull ??
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
    // Số mảnh thuộc các tuần trước — bản miễn phí không đọc được (script
    // `screenCareerMemory`: `remaining`).
    final olderCount = locked
        ? grouped
              .expand((m) => m.weeks)
              .where((w) => !w.isCurrent)
              .expand((w) => w.days)
              .expand((d) => d.entries)
              .length
        : 0;
    // INSIGHT tuần này cũng khoá với bản miễn phí.
    final hasLocked =
        locked && (olderCount > 0 || shown.any((e) => e.premiumOnly));

    return WrDetailScaffold(
      art: WrHeroArt.grow,
      eyebrow: tr('DẤU ẤN HÀNH TRÌNH', 'JOURNEY MARKS'),
      // Mockup v16: "Bạn đã để lại N mảnh ký ức nghề nghiệp." — con số TỔNG,
      // kể cả với bản miễn phí. Việc mình đã làm thì luôn được nói ra; cái bị
      // khoá là nội dung từng mục.
      //
      // Từ dùng cho VẬT CHỨA là "ghi nhận" (Changelog CareerSnapshot §9). Đợt 1
      // đổi sang "cột mốc" theo §12.2, và §9.1 bác lại chính cách đó: "Cột mốc"
      // là tên của MỘT trong bốn loại (Câu chuyện · Cột mốc · Chủ đề · Insight),
      // nên gọi vật chứa như vậy sẽ ra "42 cột mốc" ở tiêu đề trong khi bên dưới
      // chỉ vài mục thật sự mang nhãn đó. Luật đếm không đổi.
      title: all.isEmpty
          ? tr('Dấu ấn hành trình', 'Journey marks')
          : _type == null
          ? tr(
              'Bạn đã để lại ${all.length} ghi nhận trên hành trình sự nghiệp.',
              'You have left ${all.length} entries on your career journey.',
            )
          : tr(
              '${shown.length} ghi nhận · ${_type!.toLowerCase()}',
              '${shown.length} entries · ${_type!.toLowerCase()}',
            ),
      children: [
        if (all.isEmpty)
          WrParagraph(
            tr(
              'Nhật ký sự nghiệp của bạn chưa có ghi nhận nào. Hãy bắt đầu '
                  'một lần nhìn lại để lưu giữ những dấu ấn của riêng bạn.',
              'Your career journal has nothing in it yet. Start a look back '
                  'to keep the marks that are yours.',
            ),
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
            Text(
              wrKeepCompounds(tr(
                'Không có ghi nhận nào thuộc loại này.',
                'No entries of this type.',
              )),
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
          if (hasLocked)
            // Script: chân bản miễn phí CHỈ có một câu và một nút.
            WrCard(
              key: const Key('wr_career_memory_lock'),
              child: Column(
                children: [
                  if (olderCount > 0) ...[
                    Text(
                      wrKeepCompounds(tr(
                        'Còn $olderCount ghi nhận nữa, thuộc các tuần và '
                            'tháng trước đó.',
                        '$olderCount more entries, from earlier weeks and '
                            'months.',
                      )),
                      textAlign: TextAlign.center,
                      style: _muted,
                    ),
                    const SizedBox(height: 10),
                  ],
                  WrSmallButton(
                    key: const Key('wr_career_memory_unlock'),
                    kind: WrSmallButtonKind.primary,
                    label: tr(
                      'Mở khoá toàn bộ Dấu ấn hành trình',
                      'Unlock all of your Journey marks',
                    ),
                    onTap: () =>
                        context.push('/wr/paywall?trigger=career_memory'),
                  ),
                ],
              ),
            )
          else if (!locked)
            Text(
              wrKeepCompounds(tr(
                'Đã hiện ${shown.length}/${all.length} ghi nhận gần nhất.',
                'Showing the ${shown.length} most recent of ${all.length}.',
              )),
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
            label: tr('Tất cả', 'All'),
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
            wrKeepCompounds('$label $count'),
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

/// Một mảnh ký ức trong Career Memory — một thẻ riêng, đúng script
/// `screenCareerMemory`:
///
///   chấm màu 8px · nhãn loại · tiêu đề · trích     — luôn hiện
///   chi tiết ("vì sao mảnh này có mặt")             — chỉ hiện khi bấm mở
///
/// Mảnh bị khoá: thẻ mờ, tiêu đề "Nội dung đã khoá", trích thay bằng câu mời mở
/// khoá, không mũi tên, không mở ra được. INSIGHT bị khoá thì bấm vào mở paywall
/// `ai_insight`.
///
/// Mở màn đọc riêng của Episode qua "Xem chi tiết" bên trong phần mở ra (tính
/// năng thêm của app, script không có nhưng không mâu thuẫn).
class _EntryRow extends StatefulWidget {
  const _EntryRow({required this.entry, this.onTap, this.locked = false});

  final JourneyEntry entry;

  /// Mở màn đọc riêng của mốc này. Null khi mốc không có màn riêng.
  final VoidCallback? onTap;

  /// Mảnh nằm ngoài phần bản miễn phí đọc được.
  final bool locked;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final locked = widget.locked;
    final onTap = locked ? null : widget.onTap;
    final excerpt = entry.subtitle?.trim();
    final hasExcerpt =
        excerpt != null && excerpt.isNotEmpty && excerpt != entry.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: locked ? 0.45 : 1,
        child: WrCard(
          onTap: locked
              ? (entry.premiumOnly
                    ? () => context.push('/wr/paywall?trigger=ai_insight')
                    : null)
              : () => setState(() => _open = !_open),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: entry.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TypeLabel(
                        label: entry.label.toUpperCase(),
                        color: entry.color,
                        premium: entry.premiumOnly,
                      ),
                      const SizedBox(height: 3),
                      WrParagraph(
                        locked ? kLockedEntryTitle : entry.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: WrColors.navy,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.start,
                      ),
                      if (locked) ...[
                        const SizedBox(height: 3),
                        WrParagraph(
                          kLockedEntryBody,
                          style: const TextStyle(
                            fontSize: 14,
                            color: WrColors.text2,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ] else if (hasExcerpt) ...[
                        const SizedBox(height: 3),
                        WrParagraph(
                          excerpt,
                          style: const TextStyle(
                            fontSize: 14,
                            color: WrColors.text2,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ],
                      if (_open && !locked) ...[
                        if (entry.detail != null &&
                            entry.detail!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(height: 1, color: WrColors.lineSoft),
                          const SizedBox(height: 8),
                          WrParagraph(
                            entry.detail!,
                            key: const Key('wr_journey_entry_detail'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: WrColors.text2,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ],
                        if (onTap != null) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onTap,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  wrKeepCompounds(tr('Xem chi tiết', 'See details')),
                                  style: TextStyle(
                                    fontSize: 14,
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
                // Mảnh đã khoá thì KHÔNG có mũi tên — script cũng vậy.
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
        ),
      ),
    );
  }
}
