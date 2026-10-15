// Trải nghiệm của bạn — màn hình tầng trong của tab Hiểu mình.
//
// Theo "Logic đọc hiểu mình.docx" (15/10/2026) và mockup v77:
// `screenExpInterpret` (mục lục), `screenExpByReflect`, `screenExpBySurvey`,
// `screenExpPillarSurvey`, `screenExpSynthesis`. Mỗi màn con là một lượt mở
// route riêng (`/wr/experience-interpret?tab=1|2|3`, bên trong một nhóm điều
// kiện thêm `&pillar=s|c|a`), nên nút quay lại đưa về đúng màn trước.
//
// Hai nguồn đọc, hai chủ ngữ: phần từ những lần nhìn lại lấy NGƯỜI DÙNG làm
// chủ ngữ; phần từ khảo sát lấy MÔI TRƯỜNG làm chủ ngữ. Hai phần đó là dữ liệu
// của người dùng nên luôn miễn phí; Tổng quan và chặng là việc hệ thống đọc
// ra nên là Premium.
//
// Khối "Bạn đang khó ở chỗ nào" (AI viết hai câu từ những chuyện đang quay
// lại) và màn bên trong một nhóm trải nghiệm CHƯA làm: chờ khách chốt ngưỡng
// và cách sinh hai mảnh câu dùng chung với Tổng quan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_reading_feedback_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_career_health.dart';
import '../../../core/logic/wr_chapters.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_experience_reading.dart';
import '../../../core/logic/wr_sca_deep_dive.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_episode.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../wr_providers.dart';
import 'wr_discover_screen.dart' show scriptPillarColor;

/// Có kết quả khảo sát đủ 15 câu chưa (script: `scaAnswers` đủ 15).
bool _hasSurvey(ScaSelfCheckResponse? latest) =>
    (latest?.answers.length ?? 0) >= 15;

/// Màu ba mức của tài liệu §3. Mỗi màu đạt 4.5:1 trên nền giấy; vàng cũ
/// #B8862F chỉ 3.11:1 nên đã đổi thành #94681A.
const Color kCondUpColor = Color(0xFF0E7A76);
const Color kCondMidColor = Color(0xFF94681A);
const Color kCondDownColor = Color(0xFFC6402F);

Color condColor(CondLevel? level) => switch (level) {
  CondLevel.up => kCondUpColor,
  CondLevel.mid => kCondMidColor,
  CondLevel.down => kCondDownColor,
  null => WrColors.text3,
};

String _surveyPath([SelfCheckPillar? p]) =>
    '/wr/experience-interpret?tab=2${p == null ? '' : '&pillar=${p.name}'}';

class WrExperienceInterpretScreen extends ConsumerWidget {
  const WrExperienceInterpretScreen({
    super.key,
    this.initialTab = 0,
    this.pillar,
  });

  /// 0 = mục lục, 1 = từ những lần nhìn lại, 2 = từ điều kiện quanh bạn,
  /// 3 = tổng quan.
  final int initialTab;

  /// Với [initialTab] 2: mở thẳng năm điều kiện của một nhóm.
  final SelfCheckPillar? pillar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final selfChecks =
        ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];
    final latestCheck = selfChecks.isEmpty ? null : selfChecks.first;
    final hasSurvey = _hasSurvey(latestCheck);
    // Tài liệu §2: phạm vi đọc là toàn bộ lịch sử, không phải cửa sổ 30 ngày.
    final tally = pillarTally(episodes, situations);
    final reflectionTotal = episodes.length;
    final premium =
        ref
            .watch(wrEntitlementProvider)
            .valueOrNull
            ?.canUseFeature(WrPremiumFeature.selfCheckDeepDive) ??
        false;
    final readingTitle = tr('Trải nghiệm của bạn', 'Your experience');

    switch (initialTab) {
      case 1:
        return WrDetailScaffold(
          art: WrHeroArt.understand,
          eyebrow: readingTitle,
          title: tr('Từ những lần bạn nhìn lại', 'From your look-backs'),
          children: [_ExpByReflectView(total: reflectionTotal, tally: tally)],
        );
      case 2:
        final p = pillar;
        if (p != null && hasSurvey && latestCheck != null) {
          return WrDetailScaffold(
            art: WrHeroArt.understand,
            eyebrow: p.displayName,
            title: pillarCondLabel(latestCheck.answers, p).text,
            children: [
              _ExpPillarSurveyView(pillar: p, answers: latestCheck.answers),
            ],
          );
        }
        return WrDetailScaffold(
          art: WrHeroArt.understand,
          eyebrow: readingTitle,
          title: tr('Từ điều kiện quanh bạn', 'From the conditions around you'),
          children: [
            _ExpBySurveyView(latestCheck: latestCheck, hasSurvey: hasSurvey),
          ],
        );
      case 3:
        return WrDetailScaffold(
          art: WrHeroArt.understand,
          eyebrow: readingTitle,
          title: tr('Tổng quan', 'Overview'),
          children: [
            _ExpSynthesisView(
              premium: premium,
              episodes: episodes,
              tally: tally,
              latestCheck: latestCheck,
              hasSurvey: hasSurvey,
            ),
          ],
        );
    }

    // Dòng chặng lấy từ chặng THẬT gần nhất. Chưa khép chặng nào thì ẩn dòng.
    final labels = {for (final s in situations) s.code: s.text};
    final chapters = buildChapters(
      episodes,
      labels: labels,
      now: DateTime.now(),
    );
    final latestChapter = chapters.isEmpty ? null : chapters.last;
    final dom = _dominant(tally);
    final counts = tally.appearance;

    String surveySubtitle() {
      if (!hasSurvey || latestCheck == null) {
        return tr(
          'Mười lăm câu ngắn về cách công việc quanh bạn đang được tổ chức.',
          'Fifteen short questions on how the work around you is organised.',
        );
      }
      var nDown = 0, nUp = 0;
      for (final p in SelfCheckPillar.values) {
        final s = condSplit(latestCheck.answers, p);
        nDown += s.down.length;
        nUp += s.up.length;
      }
      return nDown > 0
          ? tr(
              '$nDown điều đang cản trở, $nUp điều đang nâng đỡ bạn.',
              '$nDown holding you back, $nUp supporting you.',
            )
          : tr(
              'Điều gì quanh bạn đang nâng đỡ, điều gì còn thất thường.',
              'What around you is supporting you, and what is still uneven.',
            );
    }

    return WrDetailScaffold(
      art: WrHeroArt.understand,
      eyebrow: tr('Hiểu mình', 'Understand'),
      title: readingTitle,
      children: [
        WrParagraph(
          tr(
            'Hai phần đầu đọc từ hai nguồn khác nhau. Phần thứ nhất lấy từ '
                'chính những gì bạn viết ra, nên nó nói về cách bạn cảm nhận '
                'công việc. Phần thứ hai lấy từ bộ khảo sát, nên nó nói về cách '
                'công việc quanh bạn đang được tổ chức.',
            'The first two parts read from two different sources. The first '
                'comes from what you write yourself, so it is about how you '
                'experience your work. The second comes from the survey, so it '
                'is about how the work around you is organised.',
          ),
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontSize: 14.5,
            color: WrColors.muted,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 18),

        _MenuCard(
          key: const Key('wr_exp_menu_reflect'),
          title: tr('Từ những lần bạn nhìn lại', 'From your look-backs'),
          subtitle: reflectionTotal < kExperienceMinReflections
              ? tr(
                  'Cần $kExperienceMinReflections lần nhìn lại, bạn đã có '
                      '$reflectionTotal lần.',
                  'Needs $kExperienceMinReflections look-backs, you have '
                      '$reflectionTotal.',
                )
              : dom == null
              ? tr(
                  'Điều gì bạn hay dừng lại, chia theo ba nhóm trải nghiệm.',
                  'What you stop at, across the three groups of experience.',
                )
              : tr(
                  '${counts[dom]} trong $reflectionTotal lần dừng lại ở '
                      '${dom.displayName}.',
                  '${counts[dom]} of $reflectionTotal times you stopped at '
                      '${dom.displayName}.',
                ),
          onTap: () => context.push('/wr/experience-interpret?tab=1'),
        ),

        _MenuCard(
          key: const Key('wr_exp_menu_survey'),
          title: tr('Từ điều kiện quanh bạn', 'From the conditions around you'),
          subtitle: surveySubtitle(),
          ready: hasSurvey,
          notReadyLabel: tr(
            'Cần làm khảo sát trước ›',
            'Take the survey first ›',
          ),
          onTap: () => hasSurvey
              ? context.push(_surveyPath())
              : context.push('/wr/self-check'),
        ),

        _MenuCard(
          key: const Key('wr_exp_menu_synthesis'),
          title: tr('Tổng quan', 'Overview'),
          subtitle: tr(
            'Hai phần trên nói gì khi đặt cạnh nhau, và chỗ nào đáng bắt đầu '
                'trước.',
            'What the two parts say side by side, and where it is worth '
                'starting.',
          ),
          locked: !premium,
          onTap: () => context.push('/wr/experience-interpret?tab=3'),
        ),

        // Tạm ẩn theo họp khách 14/10, xem [kWrChaptersVisible].
        if (kWrChaptersVisible && latestChapter != null)
          _MenuCard(
            key: const Key('wr_exp_menu_chapter'),
            title: tr(
              'Nhìn lại ${latestChapter.label.toLowerCase()}',
              'Look back on ${latestChapter.label.toLowerCase()}',
            ),
            subtitle: tr(
              '${latestChapter.range}. Điều gì mới nổi lên, điều gì đã thôi '
                  'quay lại.',
              '${latestChapter.range}. What has surfaced, and what has stopped '
                  'coming back.',
            ),
            isNew: latestChapter.isLatest,
            locked: !premium,
            onTap: () => context.push('/wr/chapter/${latestChapter.id}'),
          ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isNew = false,
    this.locked = false,
    this.ready = true,
    this.notReadyLabel,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isNew;

  /// Nhãn "Premium" thay cho mũi tên — chỉ khi người dùng CHƯA có Premium.
  final bool locked;
  final bool ready;
  final String? notReadyLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: WrColors.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Opacity(
              opacity: ready ? 1.0 : 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wrKeepCompounds(title),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: WrColors.navy,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              wrKeepCompounds(subtitle),
                              style: const TextStyle(
                                fontSize: 13,
                                color: WrColors.muted,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isNew) ...[
                        const _Pill(
                          text: null,
                          fg: WrColors.pillCoralText,
                          bg: Color(0x1FFF6859),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (locked)
                        const _Pill(
                          text: 'Premium',
                          fg: WrColors.navy,
                          bg: Color(0x14093774),
                        )
                      else
                        const Text(
                          '›',
                          style: TextStyle(
                            fontSize: 17,
                            color: WrColors.muted,
                            height: 1.0,
                          ),
                        ),
                    ],
                  ),
                  if (!ready && notReadyLabel != null) ...[
                    const SizedBox(height: 9),
                    Text(
                      wrKeepCompounds(notReadyLabel!),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: WrColors.teal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Viên nhãn nhỏ. [text] null = nhãn "Mới" (dịch theo ngôn ngữ đang bật).
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.fg, required this.bg});

  final String? text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        wrKeepCompounds(text ?? tr('Mới', 'New')),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

const _lead = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: WrColors.navy,
  height: 1.55,
);
const _para = TextStyle(fontSize: 14.5, color: WrColors.muted, height: 1.65);

/// Một hàng trụ: chấm màu + tên ngắn + phần bên phải.
Widget _pillarRow(SelfCheckPillar p, Widget trailing) => Row(
  children: [
    Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: scriptPillarColor(p),
        shape: BoxShape.circle,
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        wrKeepCompounds(p.displayName),
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: WrColors.navy,
        ),
      ),
    ),
    const SizedBox(width: 10),
    trailing,
  ],
);

/// Trụ được quay lại nhiều nhất theo luật script (`sort` giảm dần, lấy đầu;
/// hoà thì theo thứ tự S · C · A). Null khi cả ba đều 0.
SelfCheckPillar? _dominant(PillarTally tally) =>
    scriptDominantPillar(tally.appearance);

const _tiny = TextStyle(fontSize: 12.5, color: WrColors.text3, height: 1.55);

Widget _eyebrow(String text, Color color) => Text(
  wrKeepCompounds(text),
  style: TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: color,
  ),
);

Widget _ghostButton(Key key, String label, VoidCallback onPressed) =>
    OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: WrColors.navy,
        minimumSize: const Size.fromHeight(44),
        side: const BorderSide(color: WrColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(wrKeepCompounds(label), textAlign: TextAlign.center),
    );

Widget _primaryButton(Key key, String label, VoidCallback onPressed) =>
    ElevatedButton(
      key: key,
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: WrColors.coral,
        foregroundColor: WrColors.navy,
        elevation: 0,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(wrKeepCompounds(label)),
    );

// ---------------------------------------------------------------------------
// Màn con 1 — Từ những lần bạn nhìn lại (`screenExpByReflect`)
// ---------------------------------------------------------------------------
//
// Chủ ngữ là NGƯỜI DÙNG. Không có câu rút lại kiểu "Điều này chưa nói nhóm đó
// đang tốt hay đang khó" (tài liệu §8 luật 5, và chính là ví dụ "Không đạt").

class _ExpByReflectView extends StatelessWidget {
  const _ExpByReflectView({required this.total, required this.tally});

  final int total;
  final PillarTally tally;

  @override
  Widget build(BuildContext context) {
    final counts = tally.appearance;
    final dom = _dominant(tally);

    final String lead;
    if (total < kExperienceMinReflections) {
      final left = kExperienceMinReflections - total;
      lead = tr(
        'Phần này đọc từ những lần bạn nhìn lại, và cần ít nhất '
            '$kExperienceMinReflections lần. Bạn đã có $total lần, còn $left '
            'lần nữa.',
        'This part reads from your look-backs and needs at least '
            '$kExperienceMinReflections. You have $total, $left to go.',
      );
    } else if (dom == null) {
      lead = tr(
        'Trong $total lần nhìn lại, chưa lần nào gắn được với một nhóm trải '
            'nghiệm.',
        'None of your $total look-backs is tied to a group of experience yet.',
      );
    } else {
      final top = counts[dom] ?? 0;
      final tied = [
        for (final p in SelfCheckPillar.values)
          if ((counts[p] ?? 0) == top) p.displayName,
      ];
      lead = tied.length == 1
          ? tr(
              'Trong $total lần nhìn lại, bạn dừng lại ở ${dom.displayName} '
                  'nhiều hơn hai nhóm còn lại: $top lần.',
              'Across $total look-backs, you stopped at ${dom.displayName} '
                  'more than the other two groups: $top times.',
            )
          : tr(
              'Trong $total lần nhìn lại, bạn dừng lại ở '
                  '${tied.join(' và ')} nhiều nhất, mỗi nhóm $top lần.',
              'Across $total look-backs, you stopped at '
                  '${tied.join(' and ')} most, $top times each.',
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrParagraph(
          lead,
          key: const Key('wr_exp_reflect_lead'),
          textAlign: TextAlign.start,
          style: _lead,
        ),
        const SizedBox(height: 6),
        Text(
          wrKeepCompounds(
            tr(
              'Phần đọc này lấy từ chính những gì bạn viết ra, nên nó nói về '
                  'cách bạn cảm nhận công việc.',
              'This reading comes from what you write yourself, so it is about '
                  'how you experience your work.',
            ),
          ),
          style: _tiny,
        ),
        if (total > 0) ...[
          const SizedBox(height: 22),
          _eyebrow(tr('BA NHÓM TRẢI NGHIỆM', 'THREE GROUPS'), WrColors.text3),
          const SizedBox(height: 10),
          WrCardMinimal(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Column(
              children: [
                for (final p in SelfCheckPillar.values) ...[
                  if (p != SelfCheckPillar.s)
                    const Divider(height: 1, color: WrColors.lineSoft),
                  Padding(
                    key: Key('wr_exp_reflect_row_${p.name}'),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pillarRow(
                          p,
                          Text(
                            wrKeepCompounds('${counts[p] ?? 0} / $total'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: WrColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (counts[p] ?? 0) / total,
                            minHeight: 6,
                            backgroundColor: WrColors.lineSoft,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              WrColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Màn con 2 — Từ điều kiện quanh bạn (`screenExpBySurvey`)
// ---------------------------------------------------------------------------
//
// Chủ ngữ là MÔI TRƯỜNG. Đọc từng câu, không lấy điểm bình quân: điểm bình
// quân là thứ sinh ra nhãn kiểu "Ổn, còn dư địa" mà người đọc không biết ứng
// với điều gì.

/// Dòng ghi nguồn + dòng nhắc khi khảo sát đã cũ. Khảo sát cũng xuất phát từ
/// cách một người nhìn, nên không được trình bày như dữ kiện khách quan.
List<Widget> _surveySource(
  ScaSelfCheckResponse latest, {
  bool withScope = true,
}) {
  final date = selfCheckDateLabel(latest.takenAt.toLocal());
  return [
    Text(
      wrKeepCompounds(
        tr(
          '${withScope ? 'Phần đọc này nói về cách công việc quanh bạn được tổ '
                        'chức, không phải cảm nhận của bạn về nó. ' : ''}Nguồn là mười '
              'lăm câu bạn đã trả lời, lần gần nhất ngày $date.',
          '${withScope ? 'This reading is about how the work around you is '
                        'organised, not how you feel about it. ' : ''}It comes from '
              'the fifteen questions you answered, most recently on $date.',
        ),
      ),
      key: const Key('wr_exp_survey_date'),
      style: _tiny,
    ),
    if (surveyIsStale(latest.takenAt, DateTime.now())) ...[
      const SizedBox(height: 6),
      Text(
        wrKeepCompounds(kSurveyStaleNote),
        key: const Key('wr_exp_survey_stale'),
        style: _tiny.copyWith(color: kCondMidColor),
      ),
    ],
  ];
}

class _SurveyMissing extends StatelessWidget {
  const _SurveyMissing();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WrParagraph(
          tr(
            'Phần này đọc về cách công việc quanh bạn đang được tổ chức, không '
                'phải cảm nhận của bạn về nó.',
            'This part reads how the work around you is organised, not how you '
                'feel about it.',
          ),
          textAlign: TextAlign.start,
          style: _lead,
        ),
        const SizedBox(height: 10),
        WrParagraph(
          tr(
            'Mười lăm câu ngắn, khoảng ba phút. Sau đó phần này sẽ gọi tên từng '
                'điều đang nâng đỡ và từng điều đang cản trở bạn.',
            'Fifteen short questions, about three minutes. After that this part '
                'names each thing that supports you and each thing that holds '
                'you back.',
          ),
          textAlign: TextAlign.start,
          style: _para,
        ),
        const SizedBox(height: 16),
        _primaryButton(
          const Key('wr_exp_survey_start'),
          tr('Bắt đầu khảo sát', 'Start the survey'),
          () => context.push('/wr/self-check'),
        ),
      ],
    );
  }
}

class _ExpBySurveyView extends StatelessWidget {
  const _ExpBySurveyView({required this.latestCheck, required this.hasSurvey});

  final ScaSelfCheckResponse? latestCheck;
  final bool hasSurvey;

  @override
  Widget build(BuildContext context) {
    final latest = latestCheck;
    if (!hasSurvey || latest == null) return const _SurveyMissing();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WrParagraph(
          surveyLead(latest.answers),
          key: const Key('wr_exp_survey_lead'),
          textAlign: TextAlign.start,
          style: _lead,
        ),
        const SizedBox(height: 6),
        ..._surveySource(latest),
        const SizedBox(height: 16),
        WrCardMinimal(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(
            children: [
              for (final p in SelfCheckPillar.values) ...[
                if (p != SelfCheckPillar.s)
                  const Divider(height: 1, color: WrColors.lineSoft),
                _SurveyPillarRow(pillar: p, answers: latest.answers),
              ],
            ],
          ),
        ),
        const SizedBox(height: 9),
        Text(
          wrKeepCompounds(
            tr(
              'Bấm vào một nhóm để đọc đủ năm điều kiện trong nhóm đó.',
              'Tap a group to read all five conditions in it.',
            ),
          ),
          style: _tiny,
        ),
        const SizedBox(height: 16),
        _ghostButton(
          const Key('wr_exp_survey_update'),
          tr('Cập nhật khảo sát', 'Update the survey'),
          () => context.push('/wr/self-check'),
        ),
        const SizedBox(height: 9),
        Text(
          wrKeepCompounds(
            tr(
              'Điều kiện làm việc đổi theo giai đoạn. Phần này đáng cập nhật lại '
                  'mỗi khi công việc có thay đổi rõ rệt.',
              'Working conditions change with the period. This part is worth '
                  'updating whenever your work changes in a clear way.',
            ),
          ),
          style: _tiny,
        ),
      ],
    );
  }
}

/// Một nhóm: tên + nhãn (xuống dòng riêng vì "3 điều đang cản trở" dài) +
/// dòng phụ gọi tên tối đa hai điều.
class _SurveyPillarRow extends StatelessWidget {
  const _SurveyPillarRow({required this.pillar, required this.answers});

  final SelfCheckPillar pillar;
  final Map<String, dynamic> answers;

  @override
  Widget build(BuildContext context) {
    final label = pillarCondLabel(answers, pillar);
    return InkWell(
      key: Key('wr_exp_survey_row_${pillar.name}'),
      onTap: () => context.push(_surveyPath(pillar)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _pillarRow(
              pillar,
              const Text(
                '›',
                style: TextStyle(fontSize: 15, color: WrColors.text3),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              wrKeepCompounds(label.text),
              key: Key('wr_exp_survey_label_${pillar.name}'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: condColor(label.tone),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              wrKeepCompounds(pillarCondSubline(condSplit(answers, pillar))),
              key: Key('wr_exp_survey_sub_${pillar.name}'),
              style: _tiny,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Màn con 2b — Năm điều kiện của một nhóm (`screenExpPillarSurvey`)
// ---------------------------------------------------------------------------

class _ExpPillarSurveyView extends StatelessWidget {
  const _ExpPillarSurveyView({required this.pillar, required this.answers});

  final SelfCheckPillar pillar;
  final Map<String, dynamic> answers;

  @override
  Widget build(BuildContext context) {
    final s = condSplit(answers, pillar);

    Widget group(String label, CondLevel level) {
      final items = s.phrasesOf(level);
      if (items.isEmpty) return const SizedBox.shrink();
      final color = condColor(level);
      return Padding(
        key: Key('wr_exp_pillar_group_${level.name}'),
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _eyebrow(label, color),
            const SizedBox(height: 9),
            WrCardMinimal(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: WrColors.lineSoft),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '·',
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              wrKeepCompounds(items[i]),
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.5,
                                color: WrColors.navy,
                              ),
                            ),
                          ),
                        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WrParagraph(
          pillarCondLead(pillar, s),
          key: const Key('wr_exp_pillar_lead'),
          textAlign: TextAlign.start,
          style: _lead,
        ),
        group(tr('ĐANG CẢN TRỞ BẠN', 'HOLDING YOU BACK'), CondLevel.down),
        group(tr('CÒN THẤT THƯỜNG', 'STILL UNEVEN'), CondLevel.mid),
        group(tr('ĐANG NÂNG ĐỠ BẠN', 'SUPPORTING YOU'), CondLevel.up),
        const SizedBox(height: 16),
        Text(
          wrKeepCompounds(
            tr(
              'Mỗi dòng ở đây là một câu trong bộ khảo sát. Phần “còn thất '
                  'thường” là những điều có lúc có, có lúc không, nên chưa '
                  'thành chỗ dựa.',
              'Each line here is one question in the survey. “Still uneven” '
                  'means it is there some of the time and not at others, so it '
                  'is not yet something to lean on.',
            ),
          ),
          style: _tiny,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Màn con 3 — Tổng quan (`screenExpSynthesis`)
// ---------------------------------------------------------------------------
//
// Hai biến: dom (nhóm nhiều lần nhìn lại nhất) và blocked (nhóm nhiều điều
// kiện đang cản trở nhất). Bốn trường hợp: trùng nhau, lệch nhau, không có cản
// trở, thiếu một phía. Xem [buildOverview].
//
// Vòng phản hồi (tài liệu §7): "Khớp với tôi" / "Chưa đúng lắm". Sau "Chưa
// đúng lắm" không xin lỗi, không đổi câu ngay: giữ nguyên bản cũ kèm ghi nhận
// cho tới khi có thêm [kRereadAfterReflections] lần nhìn lại.

class _ExpSynthesisView extends ConsumerStatefulWidget {
  const _ExpSynthesisView({
    required this.premium,
    required this.episodes,
    required this.tally,
    required this.latestCheck,
    required this.hasSurvey,
  });

  final bool premium;
  final List<ReflectionEpisode> episodes;
  final PillarTally tally;
  final ScaSelfCheckResponse? latestCheck;
  final bool hasSurvey;

  @override
  ConsumerState<_ExpSynthesisView> createState() => _ExpSynthesisViewState();
}

class _ExpSynthesisViewState extends ConsumerState<_ExpSynthesisView> {
  /// Phản hồi vừa bấm trong lượt mở màn này, cùng bản đọc đã được phản hồi.
  bool? _verdict;
  OverviewInputs? _verdictInputs;

  Future<void> _answer(OverviewInputs inputs, bool match) async {
    setState(() {
      _verdict = match;
      _verdictInputs = inputs;
    });
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await ref
          .read(wrReadingFeedbackRepositoryProvider)
          .insert(
            userId: userId,
            kind: kReadingKindOverview,
            readingKey: buildOverview(inputs).key,
            reading: inputs.toJson(),
            match: match,
          );
      ref.invalidate(wrOverviewFeedbackProvider);
    } catch (_) {
      // Ghi không được thì lần mở sau hỏi lại; lượt này vẫn giữ câu trả lời.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.premium) return const _SynthesisLocked();

    final total = widget.episodes.length;
    final dom = _dominant(widget.tally);
    final latest = widget.latestCheck;
    final hasReflections = total >= kExperienceMinReflections && dom != null;
    if (!hasReflections || !widget.hasSurvey || latest == null) {
      return _SynthesisMissing(
        total: total,
        hasSurvey: widget.hasSurvey,
        hasDom: dom != null,
      );
    }

    final current = OverviewInputs(
      dom: dom,
      domCount: widget.tally.appearance[dom] ?? 0,
      total: total,
      answers: latest.answers,
    );

    // Bản nào đang hiện, và phản hồi nào đi kèm.
    var inputs = current;
    bool? verdict;
    var waitLeft = kRereadAfterReflections;
    if (_verdict != null && _verdictInputs != null) {
      inputs = _verdictInputs!;
      verdict = _verdict;
    } else {
      final fb = ref.watch(wrOverviewFeedbackProvider).valueOrNull;
      if (fb != null) {
        final since = widget.episodes
            .where((e) => e.openedAt?.isAfter(fb.createdAt) ?? false)
            .length;
        final held = OverviewInputs.fromJson(fb.reading);
        if (!fb.match && since < kRereadAfterReflections && held != null) {
          inputs = held;
          verdict = false;
          waitLeft = kRereadAfterReflections - since;
        } else if (fb.match && fb.readingKey == buildOverview(current).key) {
          verdict = true;
        }
      }
    }
    final o = buildOverview(inputs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WrParagraph(
          o.head,
          key: Key('wr_exp_overview_${o.kind.name}'),
          textAlign: TextAlign.start,
          style: _lead,
        ),
        if (surveyIsStale(latest.takenAt, DateTime.now())) ...[
          const SizedBox(height: 6),
          Text(
            wrKeepCompounds(kSurveyStaleNote),
            key: const Key('wr_exp_survey_stale'),
            style: _tiny.copyWith(color: kCondMidColor),
          ),
        ],
        const SizedBox(height: 10),
        WrParagraph(
          o.body,
          key: const Key('wr_exp_overview_body'),
          textAlign: TextAlign.start,
          style: _para,
        ),
        if (o.link != null) ...[
          const SizedBox(height: 10),
          WrParagraph(
            o.link!,
            key: const Key('wr_exp_overview_link'),
            textAlign: TextAlign.start,
            style: _para,
          ),
        ],
        const SizedBox(height: 18),
        _StartHereCard(overview: o),
        const SizedBox(height: 20),
        if (verdict == null)
          _FeedbackAsk(
            onOff: () => _answer(inputs, false),
            onMatch: () => _answer(inputs, true),
          )
        else
          _FeedbackDone(match: verdict, waitLeft: waitLeft),
        const SizedBox(height: 14),
        WrCardMinimal(
          key: const Key('wr_exp_synthesis_over_time'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _eyebrow(
                tr('ĐÃ ĐỔI RA SAO', 'HOW IT HAS CHANGED'),
                WrColors.pillTealText,
              ),
              const SizedBox(height: 7),
              WrParagraph(
                tr(
                  'So kết quả giữa các lần khảo sát, để thấy điều kiện quanh bạn '
                      'đã đổi ra sao và khoảng lệch giữa hai phía đang rộng ra '
                      'hay hẹp lại.',
                  'Compare results across surveys, to see how the conditions '
                      'around you have changed and whether the gap between the '
                      'two sides is widening or narrowing.',
                ),
                textAlign: TextAlign.start,
                style: _para,
              ),
              const SizedBox(height: 12),
              _ghostButton(
                const Key('wr_exp_synthesis_trend'),
                tr('Xem xu hướng', 'See the trend'),
                () => context.push('/wr/sca-deep-dive'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thẻ "Chỗ đáng bắt đầu trước": một nhóm, một câu lý do, một nút dẫn thẳng
/// sang năm điều kiện của nhóm đó.
class _StartHereCard extends StatelessWidget {
  const _StartHereCard({required this.overview});

  final ExperienceOverview overview;

  @override
  Widget build(BuildContext context) {
    final p = overview.startPillar;
    return Container(
      key: const Key('wr_exp_overview_start'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1215B5B0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x4D15B5B0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _eyebrow(
            tr('CHỖ ĐÁNG BẮT ĐẦU TRƯỚC', 'WHERE TO START'),
            WrColors.pillTealText,
          ),
          const SizedBox(height: 7),
          Text(
            wrKeepCompounds(p.displayName),
            key: const Key('wr_exp_overview_start_pillar'),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          WrParagraph(
            overview.startReason,
            textAlign: TextAlign.start,
            style: _para,
          ),
          const SizedBox(height: 12),
          _ghostButton(
            const Key('wr_exp_overview_start_open'),
            tr('Xem năm điều kiện ở nhóm này', 'See the five conditions here'),
            () => context.push(_surveyPath(p)),
          ),
        ],
      ),
    );
  }
}

class _FeedbackAsk extends StatelessWidget {
  const _FeedbackAsk({required this.onOff, required this.onMatch});

  final VoidCallback onOff;
  final VoidCallback onMatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: WrColors.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            wrKeepCompounds(
              tr(
                'Đây là một quan sát từ hệ thống. Bạn xem lại với những gì mình '
                    'đang trải nghiệm rồi cho biết nó có khớp không.',
                'This is an observation from the system. Check it against what '
                    'you are going through, then say whether it fits.',
              ),
            ),
            style: _tiny,
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _ghostButton(
                  const Key('wr_exp_overview_off'),
                  tr('Chưa đúng lắm', 'Not quite'),
                  onOff,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _primaryButton(
                  const Key('wr_exp_overview_match'),
                  tr('Khớp với tôi', 'That fits me'),
                  onMatch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackDone extends StatelessWidget {
  const _FeedbackDone({required this.match, required this.waitLeft});

  final bool match;

  /// Còn bao nhiêu lần nhìn lại nữa thì đọc lại (chỉ dùng khi chưa khớp).
  final int waitLeft;

  @override
  Widget build(BuildContext context) {
    return WrCardMinimal(
      key: Key(match ? 'wr_exp_overview_matched' : 'wr_exp_overview_held'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _eyebrow(
            tr('ĐÃ GHI NHẬN', 'NOTED'),
            match ? WrColors.pillTealText : WrColors.pillCoralText,
          ),
          const SizedBox(height: 6),
          WrParagraph(
            match
                ? tr(
                    'Bạn thấy phần đọc này khớp. Ghi nhận đó đã được lưu lại.',
                    'You found this reading fits. That has been saved.',
                  )
                : tr(
                    'Phần đọc này chưa khớp. Hệ thống giữ lại ghi nhận đó và '
                        'đọc lại sau $waitLeft lần bạn nhìn lại nữa, vì một bản '
                        'đọc lệch thường là dấu hiệu dữ liệu còn mỏng ở một '
                        'phía.',
                    'This reading does not fit yet. The system keeps that note '
                        'and reads again after $waitLeft more look-backs, '
                        'because a reading that is off usually means the data '
                        'is still thin on one side.',
                  ),
            textAlign: TextAlign.start,
            style: _para,
          ),
          if (!match) ...[
            const SizedBox(height: 12),
            _ghostButton(
              const Key('wr_exp_overview_review'),
              tr(
                'Xem phần từ những lần nhìn lại',
                'See the part from your look-backs',
              ),
              () => context.push('/wr/experience-interpret?tab=1'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thiếu một phía: nói rõ thiếu phía nào, không đưa ra bản đọc một phía.
class _SynthesisMissing extends StatelessWidget {
  const _SynthesisMissing({
    required this.total,
    required this.hasSurvey,
    required this.hasDom,
  });

  final int total;
  final bool hasSurvey;
  final bool hasDom;

  @override
  Widget build(BuildContext context) {
    final reflectionGap = total < kExperienceMinReflections
        ? tr(
            'cần $kExperienceMinReflections lần nhìn lại, bạn đã có $total lần',
            'it needs $kExperienceMinReflections look-backs, you have $total',
          )
        : tr(
            'chưa lần nhìn lại nào gắn được với một nhóm trải nghiệm',
            'none of your look-backs is tied to a group of experience yet',
          );
    final hasReflections = total >= kExperienceMinReflections && hasDom;
    final String detail;
    if (hasReflections) {
      detail = tr(
        'Phần đọc từ những lần nhìn lại đã có. Còn thiếu phần điều kiện quanh '
            'bạn, là mười lăm câu khảo sát. Khi có đủ hai phía, hệ thống mới '
            'nói được chỗ nào đáng bắt đầu trước.',
        'The reading from your look-backs is ready. The conditions around you '
            'are still missing: the fifteen survey questions. Only with both '
            'sides can the system say where it is worth starting.',
      );
    } else if (hasSurvey) {
      detail = tr(
        'Phần điều kiện quanh bạn đã có. Còn thiếu phần từ những lần nhìn lại: '
            '$reflectionGap. Khi có đủ hai phía, hệ thống mới nói được chỗ nào '
            'đáng bắt đầu trước.',
        'The conditions around you are ready. The part from your look-backs is '
            'still missing: $reflectionGap. Only with both sides can the system '
            'say where it is worth starting.',
      );
    } else {
      detail = tr(
        'Còn thiếu cả hai phía: mười lăm câu khảo sát điều kiện làm việc, và '
            'phần từ những lần nhìn lại ($reflectionGap). Khi có đủ hai phía, '
            'hệ thống mới nói được chỗ nào đáng bắt đầu trước.',
        'Both sides are still missing: the fifteen workplace conditions '
            'questions, and the part from your look-backs ($reflectionGap). '
            'Only with both sides can the system say where it is worth '
            'starting.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WrParagraph(
          tr(
            'Phần tổng quan cần cả hai phía mới đọc được.',
            'The overview needs both sides to read.',
          ),
          textAlign: TextAlign.start,
          style: _lead,
        ),
        const SizedBox(height: 10),
        WrParagraph(
          detail,
          key: Key(
            hasSurvey
                ? 'wr_exp_synthesis_need_reflections'
                : 'wr_exp_synthesis_need_survey',
          ),
          textAlign: TextAlign.start,
          style: _para,
        ),
        if (!hasSurvey) ...[
          const SizedBox(height: 16),
          _primaryButton(
            const Key('wr_exp_synthesis_take_survey'),
            tr('Làm khảo sát', 'Take the survey'),
            () => context.push('/wr/self-check'),
          ),
        ],
      ],
    );
  }
}

/// Bản chưa Premium của Tổng quan. Ranh giới: dữ liệu của người dùng luôn
/// miễn phí, phần hệ thống đọc ra mới tính phí.
class _SynthesisLocked extends StatelessWidget {
  const _SynthesisLocked();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('wr_exp_synthesis_locked'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WrParagraph(
          tr(
            'Hai phần trước là dữ liệu của bạn. Phần này là việc hệ thống đặt '
                'chúng cạnh nhau.',
            'The two parts before are your data. This part is the system '
                'setting them side by side.',
          ),
          textAlign: TextAlign.start,
          style: _lead,
        ),
        const SizedBox(height: 10),
        WrParagraph(
          tr(
            'Nó trả lời ba câu: chỗ bạn để tâm nhiều nhất có trùng với chỗ điều '
                'kiện đang cản trở không, nếu không trùng thì hai chỗ đó liên hệ '
                'với nhau ra sao, và chỗ nào đáng bắt đầu trước.',
            'It answers three questions: does where your attention goes most '
                'match where the conditions hold you back, if not how the two '
                'are linked, and where it is worth starting.',
          ),
          textAlign: TextAlign.start,
          style: _para,
        ),
        const SizedBox(height: 16),
        WrCardNavy(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: WrColors.coral,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: WrColors.coral,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                wrKeepCompounds(
                  tr('Mở khoá phần tổng quan', 'Unlock the overview'),
                ),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: WrColors.cream,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                wrKeepCompounds(
                  tr(
                    'Hai phần trước luôn miễn phí, vì đó là dữ liệu của bạn. '
                        'Phần này là phần hệ thống đọc và theo dõi thay đổi theo '
                        'thời gian.',
                    'The two parts before are always free, because they are '
                        'your data. This part is what the system reads, and '
                        'tracking how it changes over time.',
                  ),
                ),
                style: TextStyle(
                  fontSize: 13.5,
                  color: WrColors.cream.withValues(alpha: 0.72),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                child: _primaryButton(
                  const Key('wr_exp_synthesis_unlock'),
                  tr('Mở khoá', 'Unlock'),
                  () => context.push('/wr/paywall?trigger=sca_deep'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
