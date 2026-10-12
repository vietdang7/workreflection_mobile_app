// Diễn giải Trải nghiệm — Màn hình tầng trong của tab Hiểu mình.
// Theo đặc tả Sprint 2 (WorkReflection_ Sprint 2 · Companion with a Memory.html
// §screenExpInterpret, §screenExpByReflect, §screenExpBySurvey, §screenExpSynthesis).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_career_health.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_sca_deep_dive.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../wr_providers.dart';
import 'wr_sca_deep_dive_screen.dart' show openScaDeepDive;

class WrExperienceInterpretScreen extends ConsumerStatefulWidget {
  const WrExperienceInterpretScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<WrExperienceInterpretScreen> createState() =>
      _WrExperienceInterpretScreenState();
}

class _WrExperienceInterpretScreenState
    extends ConsumerState<WrExperienceInterpretScreen> {
  late int _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final selfChecks =
        ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];
    final latestCheck = selfChecks.isEmpty ? null : selfChecks.first;
    final hasSurvey = (latestCheck?.answers.length ?? 0) >= 15;
    final tally = pillarTally(episodes, situations);
    final reflectionTotal = episodes.length;

    return WrDetailScaffold(
      art: WrHeroArt.understand,
      eyebrow: tr('HIỂU MÌNH', 'UNDERSTAND'),
      title: tr('Trải nghiệm của bạn', 'Your Experience'),
      children: [
        if (_activeTab == 0) ...[
          WrParagraph(
            tr(
              'Mấy cách đọc cùng một thứ. Bạn có thể vào từng phần, hoặc đọc thẳng phần tổng hợp.',
              'Multiple ways to read the same experience. You can explore each part, or read the full synthesis directly.',
            ),
            style: const TextStyle(
              fontSize: 14.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),

          // 1. Nhìn lại Chặng 3
          _MenuCard(
            title: tr('Nhìn lại chặng 3', 'Review Chapter 3'),
            subtitle: tr(
              'Tháng 8 đến tháng 10. Điều gì mới nổi lên, điều gì đã thôi quay lại.',
              'August to October. What emerged new, what stopped recurring.',
            ),
            isNew: true,
            isPremium: true,
            onTap: () => context.push('/wr/chapter/ch3'),
          ),

          // 2. Theo những lần nhìn lại
          _MenuCard(
            title: tr('Xem theo những lần nhìn lại', 'View by look-backs'),
            subtitle: tr(
              'Điều gì quay lại nhiều nhất, và nó thuộc nhóm trải nghiệm nào.',
              'What recurs most often, and which experience group it belongs to.',
            ),
            onTap: () => setState(() => _activeTab = 1),
          ),

          // 3. Theo khảo sát điều kiện làm việc
          _MenuCard(
            title: tr(
              'Xem theo khảo sát điều kiện làm việc',
              'View by workplace survey',
            ),
            subtitle: tr(
              'Bạn tự đánh giá ba nhóm trải nghiệm đang ở mức nào.',
              'How you rate the 3 experience pillars yourself.',
            ),
            ready: hasSurvey,
            notReadyLabel: tr('Cần làm khảo sát trước ›', 'Survey needed first ›'),
            onTap: () {
              if (hasSurvey) {
                setState(() => _activeTab = 2);
              } else {
                context.push('/wr/self-check');
              }
            },
          ),

          // 4. Tổng hợp từ hệ thống
          _MenuCard(
            title: tr('Tổng hợp từ hệ thống', 'System Synthesis'),
            subtitle: tr(
              'Hai nguồn trên nói gì khi đặt cạnh nhau, và nó đang đổi ra sao.',
              'What the two sources say side by side, and how they evolve.',
            ),
            isPremium: true,
            onTap: () => setState(() => _activeTab = 3),
          ),
        ] else if (_activeTab == 1) ...[
          // Màn con 1: Theo những lần nhìn lại
          _BackToMenuButton(onTap: () => setState(() => _activeTab = 0)),
          const SizedBox(height: 12),
          _ExpByReflectView(
            total: reflectionTotal,
            tally: tally,
          ),
        ] else if (_activeTab == 2) ...[
          // Màn con 2: Theo khảo sát điều kiện
          _BackToMenuButton(onTap: () => setState(() => _activeTab = 0)),
          const SizedBox(height: 12),
          _ExpBySurveyView(
            latestCheck: latestCheck,
            hasSurvey: hasSurvey,
          ),
        ] else if (_activeTab == 3) ...[
          // Màn con 3: Tổng hợp từ hệ thống
          _BackToMenuButton(onTap: () => setState(() => _activeTab = 0)),
          const SizedBox(height: 12),
          _ExpSynthesisView(
            total: reflectionTotal,
            tally: tally,
            latestCheck: latestCheck,
            hasSurvey: hasSurvey,
          ),
        ],
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isNew = false,
    this.isPremium = false,
    this.ready = true,
    this.notReadyLabel,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isNew;
  final bool isPremium;
  final bool ready;
  final String? notReadyLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WrCardMinimal(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                            title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: WrColors.navy,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: WrColors.muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isNew) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: WrColors.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tr('Mới', 'New'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: WrColors.coral,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (isPremium) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: WrColors.navy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
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
                    ] else
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: WrColors.text3,
                        size: 20,
                      ),
                  ],
                ),
                if (!ready && notReadyLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    notReadyLabel!,
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
    );
  }
}

class _BackToMenuButton extends StatelessWidget {
  const _BackToMenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: WrColors.teal,
            ),
            const SizedBox(width: 6),
            Text(
              tr('Quay lại danh mục', 'Back to menu'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: WrColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpByReflectView extends StatelessWidget {
  const _ExpByReflectView({
    required this.total,
    required this.tally,
  });

  final int total;
  final PillarTally tally;

  @override
  Widget build(BuildContext context) {
    final effectiveTotal = total > 0 ? total : 1;
    final pillars = [
      (
        code: SelfCheckPillar.s,
        label: tr('Cấu trúc công việc', 'Work Structure'),
        color: const Color(0xFF5B8CC9),
        count: tally.appearance[SelfCheckPillar.s] ?? 0,
      ),
      (
        code: SelfCheckPillar.c,
        label: tr('Mối quan hệ & Văn hoá', 'Relationships & Culture'),
        color: WrColors.teal,
        count: tally.appearance[SelfCheckPillar.c] ?? 0,
      ),
      (
        code: SelfCheckPillar.a,
        label: tr('Hoạt động hàng ngày', 'Daily Activities'),
        color: const Color(0xFF5E7A5A),
        count: tally.appearance[SelfCheckPillar.a] ?? 0,
      ),
    ];

    pillars.sort((a, b) => b.count.compareTo(a.count));
    final dom = pillars.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(tr('DIỄN GIẢI', 'INTERPRETATION')),
        const SizedBox(height: 6),
        Text(
          tr('Theo những lần nhìn lại', 'By look-backs'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          tr(
            'Trong $total lần nhìn lại gần đây, những chuyện bạn ghi lại không rải đều. Chúng dồn về một nhóm.',
            'Across your last $total look-backs, what you recorded did not spread evenly. They clustered around one group.',
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: WrColors.navy,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        WrCardMinimal(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < pillars.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: WrColors.lineSoft),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: pillars[i].color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pillars[i].label,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: WrColors.navy,
                          ),
                        ),
                      ),
                      Text(
                        '${pillars[i].count} / $total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: WrColors.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pillars[i].count / effectiveTotal,
                      minHeight: 6,
                      backgroundColor: WrColors.lineSoft,
                      valueColor: AlwaysStoppedAnimation<Color>(pillars[i].color),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr(
            '${dom.label} là nhóm bạn quay lại nhiều nhất, ${dom.count} trong $total lần. Nghĩa là phần lớn những gì làm bạn dừng lại để ghi một dòng đều nằm quanh nhóm này.',
            '${dom.label} is the group you returned to most, ${dom.count} out of $total times.',
          ),
          style: const TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
        ),
        const SizedBox(height: 10),
        Text(
          tr(
            'Điều này chưa nói nhóm đó đang tốt hay đang khó. Nó chỉ nói đây là chỗ bạn đang để tâm nhiều nhất.',
            'This does not state if this group is going well or hard. It only reflects where you give the most attention.',
          ),
          style: const TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
        ),
      ],
    );
  }
}

class _ExpBySurveyView extends StatelessWidget {
  const _ExpBySurveyView({
    required this.latestCheck,
    required this.hasSurvey,
  });

  final ScaSelfCheckResponse? latestCheck;
  final bool hasSurvey;

  @override
  Widget build(BuildContext context) {
    if (!hasSurvey) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(tr('DIỄN GIẢI', 'INTERPRETATION')),
          const SizedBox(height: 6),
          Text(
            tr('Theo khảo sát điều kiện', 'By workplace survey'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr(
              'Phần này cần kết quả khảo sát điều kiện làm việc.',
              'This section needs workplace survey results.',
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WrColors.navy),
          ),
          const SizedBox(height: 10),
          Text(
            tr(
              'Mười lăm câu hỏi ngắn, khoảng ba phút. Sau đó phần này sẽ hiện cách bạn tự đánh giá ba nhóm trải nghiệm.',
              '15 short questions, about 3 minutes. Afterwards this section shows your rating across the 3 pillars.',
            ),
            style: const TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => context.push('/wr/self-check'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WrColors.coral,
              foregroundColor: WrColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(tr('Bắt đầu khảo sát', 'Start survey')),
          ),
        ],
      );
    }

    final pillars = [
      (
        code: SelfCheckPillar.s,
        label: tr('Cấu trúc công việc', 'Work Structure'),
        color: const Color(0xFF5B8CC9),
        score: latestCheck?.structureScore ?? 0,
      ),
      (
        code: SelfCheckPillar.c,
        label: tr('Mối quan hệ & Văn hoá', 'Relationships & Culture'),
        color: WrColors.teal,
        score: latestCheck?.cultureScore ?? 0,
      ),
      (
        code: SelfCheckPillar.a,
        label: tr('Hoạt động hàng ngày', 'Daily Activities'),
        color: const Color(0xFF5E7A5A),
        score: latestCheck?.activityScore ?? 0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(tr('DIỄN GIẢI', 'INTERPRETATION')),
        const SizedBox(height: 6),
        Text(
          tr('Theo khảo sát điều kiện', 'By workplace survey'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          tr(
            'Đây là cách bạn tự đánh giá điều kiện làm việc quanh mình, ở lần khảo sát gần nhất.',
            'Here is how you self-evaluated your workplace conditions in the latest survey.',
          ),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WrColors.navy, height: 1.5),
        ),
        const SizedBox(height: 16),
        WrCardMinimal(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < pillars.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: WrColors.lineSoft),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: pillars[i].color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pillars[i].label,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: WrColors.navy,
                          ),
                        ),
                      ),
                      Text(
                        scaPillarStatus(pillars[i].score).label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: pillars[i].score >= 3.8
                              ? WrColors.teal
                              : (pillars[i].score >= 2.8 ? WrColors.navy : WrColors.coral),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr(
            'Đây là cảm nhận của bạn tại một thời điểm, không phải một kết quả đo. Nó có thể đổi sau một tuần nhiều việc, hoặc sau một cuộc họp nhẹ nhõm.',
            'This is your feeling at a point in time, not an absolute test score. It can change after a busy week or an easy meeting.',
          ),
          style: const TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
        ),
        const SizedBox(height: 10),
        Text(
          tr(
            'Vì vậy phần này đáng cập nhật lại mỗi khi công việc có thay đổi rõ rệt.',
            'Therefore, it is worth updating whenever your work condition visibly changes.',
          ),
          style: const TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.push('/wr/self-check'),
          style: OutlinedButton.styleFrom(
            foregroundColor: WrColors.navy,
            side: const BorderSide(color: WrColors.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(tr('Cập nhật khảo sát', 'Update survey')),
        ),
      ],
    );
  }
}

class _ExpSynthesisView extends ConsumerWidget {
  const _ExpSynthesisView({
    required this.total,
    required this.tally,
    required this.latestCheck,
    required this.hasSurvey,
  });

  final int total;
  final PillarTally tally;
  final ScaSelfCheckResponse? latestCheck;
  final bool hasSurvey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull;
    final isPremium = entitlement?.canUseFeature(WrPremiumFeature.selfCheckDeepDive) ?? false;

    if (!isPremium) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(tr('DIỄN GIẢI', 'INTERPRETATION')),
          const SizedBox(height: 6),
          Text(
            tr('Tổng hợp từ hệ thống', 'System synthesis'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr(
              'Hai nguồn trên là dữ liệu của bạn. Phần này là việc hệ thống đọc chúng cạnh nhau.',
              'The two sources above are your data. This section is how the system reads them side by side.',
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WrColors.navy, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            tr(
              'Nó trả lời: chỗ bạn để tâm nhiều nhất có trùng với chỗ bạn thấy khó nhất không, khoảng lệch giữa hai điều đó nói lên gì, và nó đang rộng ra hay hẹp lại theo thời gian.',
              'It answers: does what you focus on most align with where you struggle most, what that gap signifies, and how it shifts over time.',
            ),
            style: const TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
          ),
          const SizedBox(height: 20),
          WrCardNavy(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: WrColors.coral, size: 16),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: WrColors.coral,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Premium',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WrColors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tr('Mở khoá phần tổng hợp', 'Unlock system synthesis'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: WrColors.cream),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Hai phần trước luôn miễn phí, vì đó là dữ liệu của bạn. Phần này là diễn giải và theo dõi thay đổi theo thời gian.',
                    'The previous two parts are always free. This section tracks deeper shifts over time.',
                  ),
                  style: TextStyle(fontSize: 13.5, color: WrColors.cream.withValues(alpha: 0.8), height: 1.5),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => openScaDeepDive(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WrColors.coral,
                    foregroundColor: WrColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr('Mở khoá', 'Unlock')),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Premium unlocked view
    final dom = dominantPillar(tally.appearance, tally.classified);
    final domLabel = switch (dom) {
      SelfCheckPillar.s => tr('Cấu trúc công việc', 'Work Structure'),
      SelfCheckPillar.c => tr('Mối quan hệ & Văn hoá', 'Relationships & Culture'),
      SelfCheckPillar.a => tr('Hoạt động hàng ngày', 'Daily Activities'),
      null => tr('Các nhóm', 'All pillars'),
    };
    final count = dom != null ? (tally.appearance[dom] ?? 0) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(tr('DIỄN GIẢI', 'INTERPRETATION')),
        const SizedBox(height: 6),
        Text(
          tr('Tổng hợp từ hệ thống', 'System synthesis'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          tr(
            '$domLabel là nhóm bạn quay lại nhiều nhất, $count trong $total lần nhìn lại.',
            '$domLabel is the group you returned to most, $count out of $total look-backs.',
          ),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WrColors.navy, height: 1.5),
        ),
        const SizedBox(height: 12),
        if (hasSurvey && dom != null) ...[
          Text(
            tr(
              'Hệ thống so sánh giữa tần suất bạn phản tư và đánh giá điều kiện làm việc để nhận diện xu hướng phát triển và các điểm nghẽn tiềm ẩn.',
              'The system compares reflection frequency with self-check ratings to spot emerging growth trends and bottlenecks.',
            ),
            style: const TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
          ),
        ],
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () => context.push('/wr/sca-deep-dive'),
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.navy,
            foregroundColor: WrColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(tr('Xem phân tích chi tiết & xu hướng', 'View in-depth analysis & trends')),
        ),
      ],
    );
  }
}
