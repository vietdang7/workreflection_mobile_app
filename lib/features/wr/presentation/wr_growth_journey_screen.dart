// Chặng đường phát triển — màn riêng, mở từ tab Phát triển.
//
// Đây là DIỄN GIẢI (hệ thống đọc ra bạn đã đi được bao xa), nên thuộc Premium
// theo Hai Lớp v1.2 §III.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_premium_lock.dart';
import '../wr_providers.dart';

class WrGrowthJourneyScreen extends ConsumerWidget {
  const WrGrowthJourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final snapshots =
        ref.watch(wrGrowthSnapshotsProvider).valueOrNull ?? const [];
    final canRead = entitlement.canUseFeature(WrPremiumFeature.growthJourney);

    return WrDetailScaffold(
      eyebrow: 'CHẶNG ĐƯỜNG PHÁT TRIỂN',
      title: 'Bạn đã đi được tới đâu',
      children: [
        if (!canRead)
          const WrPremiumLock(
            key: Key('wr_growth_journey_lock'),
            description:
                'Bản đầy đủ tổng kết từng chặng: bạn đã đi được bao xa và '
                'hướng nào đang mở ra tiếp theo.',
            ctaLabel: 'Mở chặng đường phát triển',
            paywallTrigger: 'growth_journey',
          )
        else if (snapshots.isEmpty)
          const Text(
            'Chưa có chặng nào được tổng kết. Sau vài tuần thực hành đều, '
            'WorkReflection sẽ dựng lại chặng đường của bạn ở đây.',
            key: Key('wr_growth_journey_empty'),
            style: TextStyle(
              fontSize: 15,
              color: WrColors.muted,
              height: 1.65,
            ),
          )
        else
          ...snapshots.take(6).map((s) => _SnapshotBlock(snapshot: s)),
      ],
    );
  }
}

class _SnapshotBlock extends StatelessWidget {
  const _SnapshotBlock({required this.snapshot});

  final GrowthJourneySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final entries = snapshot.progress.entries.toList();
    final period = snapshot.periodLabel?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (period.isNotEmpty) ...[
            Text(
              period,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            snapshot.direction ?? 'Chặng này chưa có ghi chú hướng đi.',
            style: const TextStyle(
              fontSize: 16,
              color: WrColors.navy,
              height: 1.65,
            ),
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${e.key}: ${e.value}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: WrColors.dark,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
