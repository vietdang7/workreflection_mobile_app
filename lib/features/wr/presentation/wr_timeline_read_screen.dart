// Màn hình đọc diễn biến dòng thời gian — Sprint 2 `screenTimelineRead`.
// Kiểu chữ Lora serif trang nhã, phân đoạn rõ ràng theo từng mốc phát triển.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_premium_lock.dart';
import '../wr_providers.dart';

class WrTimelineReadScreen extends ConsumerWidget {
  const WrTimelineReadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement =
        ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final all =
        ref.watch(wrPatternNarrativesProvider).valueOrNull ??
        const <PatternNarrative>[];
    final narratives = all.where((n) => n.matchesCurrentLocale).toList();
    final canRead = entitlement.canUseFeature(WrPremiumFeature.patternAdvanced);

    return WrDetailScaffold(
      art: WrHeroArt.grow,
      eyebrow: tr('NHÌN LẠI DÒNG THỜI GIAN', 'TIMELINE REFLECTION'),
      title: tr('Điều gì đang đổi trong bạn', 'What is shifting in you'),
      children: [
        Text(
          tr(
            'Bản diễn giải tổng hợp từ các lần nhìn lại của bạn theo thời gian.',
            'Synthesized narrative from your look-backs over time.',
          ),
          style: const TextStyle(
            fontSize: 14.5,
            color: WrColors.text2,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        if (!canRead)
          WrPremiumLock(
            key: const Key('wr_timeline_read_lock'),
            description: tr(
              'Mở khóa bản đầy đủ để nhìn lại toàn bộ bức tranh thay đổi của bạn qua từng giai đoạn.',
              'Unlock the full version to see the whole picture of how you changed stage by stage.',
            ),
            ctaLabel: tr(
              'Mở phần nhìn lại dòng thời gian',
              'Unlock timeline look-back',
            ),
            paywallTrigger: 'pattern_advanced',
          )
        else if (narratives.isEmpty)
          _buildSampleNarrative()
        else
          for (final n in narratives.take(6)) ...[
            _buildNarrativeSection(n),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  Widget _buildSampleNarrative() {
    return WrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrEyebrow(
            tr('DIỄN BIẾN GẦN ĐÂY', 'RECENT PROGRESSION'),
            color: WrColors.teal,
          ),
          const SizedBox(height: 10),
          Text(
            '“Thời gian đầu, bạn hay gặp áp lực ở những tình huống cần bảo vệ ý kiến hoặc từ chối yêu cầu ngoài phạm vi. Bạn có xu hướng nhận việc về mình hoặc chọn im lặng để giữ hòa khí.\n\n'
            'Qua những lần nhìn lại gần đây, một sự thay đổi rõ nét bắt đầu diễn ra: bạn đã bắt đầu chọn cách nói chuyện riêng trước với đồng đội, đặt những câu hỏi nhỏ để làm rõ kỳ vọng thay vì lập tức phản ứng hay chịu đựng một mình.\n\n'
            'Điều này cho thấy bạn đang dần hình thành tâm thế chủ động định hình bối cảnh làm việc thay vì chỉ đơn thuần thích nghi bị động.”',
            style: WrText.serifQuote(
              fontSize: 15.5,
              color: WrColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr(
              'Ghi nhận này được tổng hợp dựa trên 12 lần nhìn lại gần nhất của bạn.',
              'This observation is synthesized from your last 12 look-backs.',
            ),
            style: const TextStyle(
              fontSize: 12.5,
              color: WrColors.text3,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrativeSection(PatternNarrative narrative) {
    return WrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              WrEyebrow(
                tr('GIAI ĐOẠN', 'PHASE'),
                color: WrColors.teal,
              ),
              if (narrative.createdAt != null)
                Text(
                  '${narrative.createdAt!.day}/${narrative.createdAt!.month}/${narrative.createdAt!.year}',
                  style: const TextStyle(fontSize: 11, color: WrColors.text3),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            narrative.narrative,
            style: WrText.serifQuote(
              fontSize: 15.5,
              color: WrColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
