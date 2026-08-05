// Diễn biến theo thời gian — màn riêng, mở từ tab Hành trình.
//
// Đây là DIỄN GIẢI (hệ thống đọc ra điều gì đang đổi), nên thuộc Premium
// theo Hai Lớp v1.2 §III. Bản miễn phí chỉ thấy phần ghi nhận ở tab Hành trình.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_premium_lock.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

class WrJourneyNarrativeScreen extends ConsumerWidget {
  const WrJourneyNarrativeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final narratives =
        ref.watch(wrPatternNarrativesProvider).valueOrNull ?? const [];
    final canRead =
        entitlement.canUseFeature(WrPremiumFeature.patternAdvanced);

    return WrDetailScaffold(
      eyebrow: 'DIỄN BIẾN THEO THỜI GIAN',
      title: 'Điều gì đang đổi trong bạn',
      children: [
        if (!canRead)
          const WrPremiumLock(
            key: Key('wr_journey_narrative_lock'),
            description:
                'Bản đầy đủ kể lại những mẫu hình của bạn đã đổi thế nào qua '
                'từng giai đoạn, điều gì đang nhạt dần và điều gì vẫn quay lại.',
            ctaLabel: 'Mở diễn biến theo thời gian',
            paywallTrigger: 'pattern_advanced',
          )
        else if (narratives.isEmpty)
          const WrParagraph(
            'Chưa đủ dữ liệu để kể lại diễn biến. Ghi thêm vài lần nữa, '
            'WorkReflection sẽ chỉ ra điều gì đang đổi và điều gì vẫn ở nguyên đó.',
            key: Key('wr_journey_narrative_empty'),
            style: TextStyle(
              fontSize: 16.5,
              color: WrColors.muted,
              height: 1.65,
            ),
          )
        else
          ...narratives.take(6).map((n) => _NarrativeBlock(narrative: n)),
      ],
    );
  }
}

class _NarrativeBlock extends StatelessWidget {
  const _NarrativeBlock({required this.narrative});

  final PatternNarrative narrative;

  @override
  Widget build(BuildContext context) {
    final period = _period(narrative);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (period != null) ...[
            Text(
              period,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 8),
          ],
          WrParagraph(
            narrative.narrative,
            style: const TextStyle(
              fontSize: 16,
              color: WrColors.navy,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

String? _period(PatternNarrative n) {
  final start = n.periodStart;
  final end = n.periodEnd;
  if (start == null && end == null) return null;
  String f(DateTime d) => '${d.day}/${d.month}/${d.year}';
  if (start != null && end != null) return '${f(start)} → ${f(end)}';
  return f((start ?? end)!);
}
