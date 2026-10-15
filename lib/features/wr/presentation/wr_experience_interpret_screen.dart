// Diễn giải Trải nghiệm — Màn hình tầng trong của tab Hiểu mình.
//
// Theo script Sprint 2: `screenExpInterpret` (mục lục), `screenExpByReflect`,
// `screenExpBySurvey`, `screenExpSynthesis`. Mỗi màn con có đầu màn riêng
// (`expHeader('Diễn giải', <tiêu đề>, 'expInterpret')`), nên mỗi màn con là một
// lượt mở route riêng (`/wr/experience-interpret?tab=1|2|3`): nút quay lại ở
// đầu màn con đưa về đúng mục lục.
//
// Ranh giới miễn phí / Premium của script: hai màn đọc DỮ LIỆU của người dùng
// (theo những lần nhìn lại, theo khảo sát) luôn miễn phí; bản đọc theo chặng và
// phần tổng hợp là việc hệ thống đọc ra, nên là Premium.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_career_health.dart';
import '../../../core/logic/wr_chapters.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_sca_deep_dive.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../wr_providers.dart';
import 'wr_discover_screen.dart' show scaStatusColor, scriptPillarColor;

/// Có kết quả khảo sát đủ 15 câu chưa (script: `scaAnswers` đủ 15).
bool _hasSurvey(ScaSelfCheckResponse? latest) =>
    (latest?.answers.length ?? 0) >= 15;

/// Điểm một trụ của lần khảo sát gần nhất.
double? _scoreOf(ScaSelfCheckResponse? r, SelfCheckPillar p) => switch (p) {
  SelfCheckPillar.s => r?.structureScore,
  SelfCheckPillar.c => r?.cultureScore,
  SelfCheckPillar.a => r?.activityScore,
};

class WrExperienceInterpretScreen extends ConsumerWidget {
  const WrExperienceInterpretScreen({super.key, this.initialTab = 0});

  /// 0 = mục lục, 1 = theo những lần nhìn lại, 2 = theo khảo sát, 3 = tổng hợp.
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final selfChecks =
        ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];
    final latestCheck = selfChecks.isEmpty ? null : selfChecks.first;
    final hasSurvey = _hasSurvey(latestCheck);
    final tally = pillarTally(episodes, situations);
    // Mẫu số của script là `reflectionTotal` — tổng số lần nhìn lại thật.
    final reflectionTotal = episodes.length;
    final premium =
        ref
            .watch(wrEntitlementProvider)
            .valueOrNull
            ?.canUseFeature(WrPremiumFeature.selfCheckDeepDive) ??
        false;

    switch (initialTab) {
      case 1:
        return WrDetailScaffold(
          art: WrHeroArt.understand,
          eyebrow: tr('Diễn giải', 'Reading'),
          title: tr('Theo những lần nhìn lại', 'By your look-backs'),
          children: [_ExpByReflectView(total: reflectionTotal, tally: tally)],
        );
      case 2:
        return WrDetailScaffold(
          art: WrHeroArt.understand,
          eyebrow: tr('Diễn giải', 'Reading'),
          title: tr('Theo khảo sát điều kiện', 'By the conditions survey'),
          children: [
            _ExpBySurveyView(latestCheck: latestCheck, hasSurvey: hasSurvey),
          ],
        );
      case 3:
        return WrDetailScaffold(
          art: WrHeroArt.understand,
          eyebrow: tr('Diễn giải', 'Reading'),
          title: tr('Tổng hợp từ hệ thống', 'What the system reads'),
          children: [
            _ExpSynthesisView(
              premium: premium,
              total: reflectionTotal,
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

    return WrDetailScaffold(
      art: WrHeroArt.understand,
      eyebrow: tr('Hiểu mình', 'Understand'),
      title: tr('Trải nghiệm của bạn', 'Your experience'),
      children: [
        WrParagraph(
          tr(
            'Mấy cách đọc cùng một thứ. Bạn có thể vào từng phần, hoặc đọc '
                'thẳng phần tổng hợp.',
            'A few ways of reading the same thing. Open each part, or go '
                'straight to the synthesis.',
          ),
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontSize: 14.5,
            color: WrColors.muted,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 18),

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

        _MenuCard(
          key: const Key('wr_exp_menu_reflect'),
          title: tr('Xem theo những lần nhìn lại', 'View by your look-backs'),
          subtitle: tr(
            'Điều gì quay lại nhiều nhất, và nó thuộc nhóm trải nghiệm nào.',
            'What comes back most, and which group of experience it belongs '
                'to.',
          ),
          onTap: () => context.push('/wr/experience-interpret?tab=1'),
        ),

        _MenuCard(
          key: const Key('wr_exp_menu_survey'),
          title: tr(
            'Xem theo khảo sát điều kiện làm việc',
            'View by the workplace conditions survey',
          ),
          subtitle: tr(
            'Bạn tự đánh giá ba nhóm trải nghiệm đang ở mức nào.',
            'Where you rate the three groups of experience yourself.',
          ),
          ready: hasSurvey,
          notReadyLabel: tr(
            'Cần làm khảo sát trước ›',
            'Take the survey first ›',
          ),
          onTap: () => hasSurvey
              ? context.push('/wr/experience-interpret?tab=2')
              : context.push('/wr/self-check'),
        ),

        _MenuCard(
          key: const Key('wr_exp_menu_synthesis'),
          title: tr('Tổng hợp từ hệ thống', 'What the system reads'),
          subtitle: tr(
            'Hai nguồn trên nói gì khi đặt cạnh nhau, và nó đang đổi ra sao.',
            'What the two sources say side by side, and how that is changing.',
          ),
          locked: !premium,
          onTap: () => context.push('/wr/experience-interpret?tab=3'),
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
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
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

// ---------------------------------------------------------------------------
// Màn con 1 — Theo những lần nhìn lại (`screenExpByReflect`)
// ---------------------------------------------------------------------------

class _ExpByReflectView extends StatelessWidget {
  const _ExpByReflectView({required this.total, required this.tally});

  final int total;
  final PillarTally tally;

  @override
  Widget build(BuildContext context) {
    final counts = tally.appearance;
    final dom = _dominant(tally);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrParagraph(
          tr(
            'Trong $total lần nhìn lại gần đây, những chuyện bạn ghi lại không '
                'rải đều. Chúng dồn về một nhóm.',
            'Across your last $total look-backs, what you wrote down is not '
                'spread evenly. It gathers around one group.',
          ),
          textAlign: TextAlign.start,
          style: _lead,
        ),
        const SizedBox(height: 16),
        WrCardMinimal(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final p in SelfCheckPillar.values) ...[
                if (p != SelfCheckPillar.s)
                  const Divider(height: 1, color: WrColors.lineSoft),
                Padding(
                  key: Key('wr_exp_reflect_row_${p.name}'),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Column(
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
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total > 0 ? (counts[p] ?? 0) / total : 0,
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
        if (dom != null) ...[
          const SizedBox(height: 16),
          WrParagraph(
            tr(
              '${dom.displayName} là nhóm bạn quay lại nhiều nhất, '
                  '${counts[dom]} trong $total lần. Nghĩa là phần lớn những gì '
                  'làm bạn dừng lại để ghi một dòng đều nằm quanh nhóm này.',
              '${dom.displayName} is the group you return to most, '
                  '${counts[dom]} out of $total times. Most of what makes you '
                  'stop and write a line sits around this group.',
            ),
            textAlign: TextAlign.start,
            style: _para,
          ),
          const SizedBox(height: 10),
          WrParagraph(
            tr(
              'Điều này chưa nói nhóm đó đang tốt hay đang khó. Nó chỉ nói đây '
                  'là chỗ bạn đang để tâm nhiều nhất.',
              'This does not say whether that group is going well or badly. It '
                  'only says this is where your attention goes most.',
            ),
            textAlign: TextAlign.start,
            style: _para,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Màn con 2 — Theo khảo sát điều kiện (`screenExpBySurvey`)
// ---------------------------------------------------------------------------

class _ExpBySurveyView extends StatelessWidget {
  const _ExpBySurveyView({required this.latestCheck, required this.hasSurvey});

  final ScaSelfCheckResponse? latestCheck;
  final bool hasSurvey;

  @override
  Widget build(BuildContext context) {
    final latest = latestCheck;
    if (!hasSurvey || latest == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrParagraph(
            tr(
              'Phần này cần kết quả khảo sát điều kiện làm việc.',
              'This part needs your workplace conditions survey.',
            ),
            textAlign: TextAlign.start,
            style: _lead,
          ),
          const SizedBox(height: 10),
          WrParagraph(
            tr(
              'Mười lăm câu hỏi ngắn, khoảng ba phút. Sau đó phần này sẽ hiện '
                  'cách bạn tự đánh giá ba nhóm trải nghiệm.',
              'Fifteen short questions, about three minutes. After that this '
                  'part shows how you rate the three groups of experience.',
            ),
            textAlign: TextAlign.start,
            style: _para,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('wr_exp_survey_start'),
            onPressed: () => context.push('/wr/self-check'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WrColors.coral,
              foregroundColor: WrColors.navy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(wrKeepCompounds(tr('Bắt đầu khảo sát', 'Start the survey'))),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrParagraph(
          tr(
            'Đây là cách bạn tự đánh giá điều kiện làm việc quanh mình, ở lần '
                'khảo sát gần nhất.',
            'This is how you rated the working conditions around you, in your '
                'latest survey.',
          ),
          textAlign: TextAlign.start,
          style: _lead,
        ),
        const SizedBox(height: 6),
        Text(
          wrKeepCompounds(tr(
            'Khảo sát gần nhất: ${selfCheckDateLabel(latest.takenAt.toLocal())}',
            'Latest survey: ${selfCheckDateLabel(latest.takenAt.toLocal())}',
          )),
          key: const Key('wr_exp_survey_date'),
          style: const TextStyle(fontSize: 12.5, color: WrColors.text3),
        ),
        const SizedBox(height: 14),
        WrCardMinimal(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final p in SelfCheckPillar.values) ...[
                if (p != SelfCheckPillar.s)
                  const Divider(height: 1, color: WrColors.lineSoft),
                Padding(
                  key: Key('wr_exp_survey_row_${p.name}'),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Builder(
                    builder: (_) {
                      final score = _scoreOf(latest, p);
                      final status = (score == null || score <= 0)
                          ? null
                          : scaPillarStatus(score);
                      return _pillarRow(
                        p,
                        Text(
                          wrKeepCompounds(status?.label ?? tr('Chưa đánh giá', 'Not rated yet')),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: status == null
                                ? WrColors.text3
                                : scaStatusColor(status),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        WrParagraph(
          tr(
            'Đây là cảm nhận của bạn tại một thời điểm, không phải một kết quả '
                'đo. Nó có thể đổi sau một tuần nhiều việc, hoặc sau một cuộc '
                'họp nhẹ nhõm.',
            'This is how it felt to you at one moment, not a measurement. It can '
                'change after a heavy week, or after an easy meeting.',
          ),
          textAlign: TextAlign.start,
          style: _para,
        ),
        const SizedBox(height: 10),
        WrParagraph(
          tr(
            'Vì vậy phần này đáng cập nhật lại mỗi khi công việc có thay đổi rõ '
                'rệt.',
            'So this part is worth updating whenever your work changes in a '
                'clear way.',
          ),
          textAlign: TextAlign.start,
          style: _para,
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          key: const Key('wr_exp_survey_update'),
          onPressed: () => context.push('/wr/self-check'),
          style: OutlinedButton.styleFrom(
            foregroundColor: WrColors.navy,
            minimumSize: const Size.fromHeight(44),
            side: const BorderSide(color: WrColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(wrKeepCompounds(tr('Cập nhật khảo sát', 'Update the survey'))),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Màn con 3 — Tổng hợp từ hệ thống (`screenExpSynthesis`)
// ---------------------------------------------------------------------------
//
// Logic đúng script: lấy trụ được quay lại nhiều nhất trong những lần nhìn
// lại, rồi tra mức tự đánh giá CỦA CHÍNH TRỤ ĐÓ ở lần khảo sát gần nhất.
//   · mức "Đang cản trở" hoặc "Ổn, còn dư địa" → hai nguồn KHỚP nhau
//   · mức "Đang hỗ trợ tốt"                     → hai nguồn LỆCH nhau
// Script không so với trụ thấp nhất của khảo sát; khớp/lệch chỉ xét một trụ.

class _ExpSynthesisView extends StatelessWidget {
  const _ExpSynthesisView({
    required this.premium,
    required this.total,
    required this.tally,
    required this.latestCheck,
    required this.hasSurvey,
  });

  final bool premium;
  final int total;
  final PillarTally tally;
  final ScaSelfCheckResponse? latestCheck;
  final bool hasSurvey;

  @override
  Widget build(BuildContext context) {
    if (!premium) return const _SynthesisLocked();

    final counts = tally.appearance;
    final dom = _dominant(tally);
    final score = dom == null ? null : _scoreOf(latestCheck, dom);
    final st = (hasSurvey && score != null && score > 0)
        ? scaPillarStatus(score)
        : null;
    final aligned = st != null && st != ScaPillarStatus.developing;
    final level = st?.label.toLowerCase() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dom == null)
          WrParagraph(
            tr(
              'Chưa có lần nhìn lại nào gắn được với một nhóm trải nghiệm, nên '
                  'chưa có gì để đặt cạnh khảo sát.',
              'None of your look-backs is tied to a group of experience yet, so '
                  'there is nothing to set beside the survey.',
            ),
            key: const Key('wr_exp_synthesis_no_data'),
            textAlign: TextAlign.start,
            style: _lead,
          )
        else ...[
          WrParagraph(
            tr(
              '${dom.displayName} là nhóm bạn quay lại nhiều nhất, '
                  '${counts[dom]} trong $total lần nhìn lại.',
              '${dom.displayName} is the group you return to most, '
                  '${counts[dom]} out of $total look-backs.',
            ),
            key: const Key('wr_exp_synthesis_lead'),
            textAlign: TextAlign.start,
            style: _lead,
          ),
          const SizedBox(height: 12),
          if (st != null) ...[
            WrParagraph(
              aligned
                  ? tr(
                      'Và đây cũng là nhóm bạn tự đánh giá ở mức “$level”. Hai '
                          'nguồn đang nói cùng một chuyện: chỗ bạn để tâm nhiều '
                          'nhất cũng là chỗ bạn thấy chưa ổn.',
                      'And it is also the group you rated as “$level”. The two '
                          'sources are saying the same thing: where your '
                          'attention goes most is also where things feel not '
                          'quite right.',
                    )
                  : tr(
                      'Nhưng bạn lại tự đánh giá nhóm này ở mức “$level”. Hai '
                          'nguồn đang lệch nhau, và chỗ lệch thường đáng chú ý '
                          'hơn chỗ trùng.',
                      'Yet you rated this group as “$level”. The two sources '
                          'disagree, and where they disagree is usually more '
                          'telling than where they match.',
                    ),
              key: Key(
                aligned
                    ? 'wr_exp_synthesis_aligned'
                    : 'wr_exp_synthesis_diverged',
              ),
              textAlign: TextAlign.start,
              style: _para,
            ),
            const SizedBox(height: 10),
            WrParagraph(
              aligned
                  ? tr(
                      'Khi hai nguồn trùng nhau, điều đáng làm không phải là '
                          'xác nhận thêm, mà là chọn một việc nhỏ để thử trong '
                          'nhóm đó.',
                      'When the two sources match, the thing worth doing is '
                          'not to confirm it again, but to pick one small thing '
                          'to try in that group.',
                    )
                  : tr(
                      'Có thể bạn đã quen với nó đến mức không còn thấy nó '
                          'nặng, hoặc điều làm bạn dừng lại ghi chép không phải '
                          'là điều làm bạn khó chịu nhất.',
                      'You may have grown so used to it that it no longer feels '
                          'heavy, or what makes you stop and write is not what '
                          'bothers you most.',
                    ),
              textAlign: TextAlign.start,
              style: _para,
            ),
          ],
        ],
        if (st == null) ...[
          if (dom == null) const SizedBox(height: 12),
          WrParagraph(
            tr(
              'Phần tổng hợp đầy đủ cần thêm kết quả khảo sát điều kiện làm '
                  'việc, để đặt cạnh những gì đang lặp lại.',
              'The full synthesis also needs your workplace conditions survey, '
                  'to set beside what keeps repeating.',
            ),
            key: const Key('wr_exp_synthesis_need_survey'),
            textAlign: TextAlign.start,
            style: _para,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('wr_exp_synthesis_take_survey'),
            onPressed: () => context.push('/wr/self-check'),
            style: OutlinedButton.styleFrom(
              foregroundColor: WrColors.navy,
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: WrColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(wrKeepCompounds(tr('Làm khảo sát', 'Take the survey'))),
          ),
        ],
        const SizedBox(height: 18),
        WrCardMinimal(
          key: const Key('wr_exp_synthesis_over_time'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                wrKeepCompounds(tr('THEO THỜI GIAN', 'OVER TIME')),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: WrColors.pillTealText,
                ),
              ),
              const SizedBox(height: 7),
              WrParagraph(
                tr(
                  'So sánh kết quả giữa các lần khảo sát, để thấy điều kiện làm '
                      'việc của bạn đã đổi ra sao và khoảng lệch đang rộng ra '
                      'hay hẹp lại.',
                  'Compare results across surveys, to see how your working '
                      'conditions have changed and whether the gap is widening '
                      'or narrowing.',
                ),
                textAlign: TextAlign.start,
                style: _para,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('wr_exp_synthesis_trend'),
                onPressed: () => context.push('/wr/sca-deep-dive'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: WrColors.navy,
                  minimumSize: const Size.fromHeight(44),
                  side: const BorderSide(color: WrColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(wrKeepCompounds(tr('Xem xu hướng', 'See the trend'))),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bản chưa Premium của phần tổng hợp.
class _SynthesisLocked extends StatelessWidget {
  const _SynthesisLocked();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('wr_exp_synthesis_locked'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrParagraph(
          tr(
            'Hai nguồn trên là dữ liệu của bạn. Phần này là việc hệ thống đọc '
                'chúng cạnh nhau.',
            'The two sources above are your data. This part is the system '
                'reading them side by side.',
          ),
          textAlign: TextAlign.start,
          style: _lead,
        ),
        const SizedBox(height: 10),
        WrParagraph(
          tr(
            'Nó trả lời: chỗ bạn để tâm nhiều nhất có trùng với chỗ bạn thấy '
                'khó nhất không, khoảng lệch giữa hai điều đó nói lên gì, và nó '
                'đang rộng ra hay hẹp lại theo thời gian.',
            'It answers: does where your attention goes most match where things '
                'feel hardest, what the gap between the two says, and whether it '
                'is widening or narrowing over time.',
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
                wrKeepCompounds(tr('Mở khoá phần tổng hợp', 'Unlock the synthesis')),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: WrColors.cream,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                wrKeepCompounds(tr(
                  'Hai phần trước luôn miễn phí, vì đó là dữ liệu của bạn. Phần '
                      'này là diễn giải và theo dõi thay đổi theo thời gian.',
                  'The two parts before are always free, because they are your '
                      'data. This part is the reading, and tracking how it '
                      'changes over time.',
                )),
                style: TextStyle(
                  fontSize: 13.5,
                  color: WrColors.cream.withValues(alpha: 0.72),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('wr_exp_synthesis_unlock'),
                  onPressed: () =>
                      context.push('/wr/paywall?trigger=sca_deep'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WrColors.coral,
                    foregroundColor: WrColors.navy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(wrKeepCompounds(tr('Mở khoá', 'Unlock'))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
