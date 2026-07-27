// Chi tiết một điều lặp lại — màn riêng, mở từ tab Hiểu mình.
//
// Ranh giới Free/Premium ở đây là ranh giới GHI NHẬN / DIỄN GIẢI:
//   • Free thấy: đã gặp bao nhiêu lần, gặp lần gần nhất khi nào, những lần
//     nhìn lại nào thuộc về nó. Toàn dữ kiện của chính người dùng.
//   • Premium thấy thêm: hệ thống đọc ra điều gì đứng sau sự lặp lại đó
//     (WrPremiumFeature.patternAdvanced), và chỉ khi đã đủ 5 lần.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/wr_premium_lock.dart';
import '../wr_providers.dart';
import 'wr_discover_screen.dart' show kInsightThreshold, occurrenceOf, situationLabel;

class WrPatternDetailScreen extends ConsumerWidget {
  const WrPatternDetailScreen({super.key, required this.situationCode});

  final String situationCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patterns = ref.watch(wrPatternCountsProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final narratives =
        ref.watch(wrPatternNarrativesProvider).valueOrNull ?? const [];

    final label = situationLabel(situations, situationCode);
    final count = occurrenceOf(patterns, situationCode);
    final related =
        episodes.where((e) => e.situationCode == situationCode).toList();
    final hasEnoughData = count >= kInsightThreshold;
    final canRead =
        entitlement.canUseFeature(WrPremiumFeature.patternAdvanced);

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        surfaceTintColor: WrColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: WrColors.navy,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          children: [
            const WrEyebrow('ĐIỀU LẶP LẠI'),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                height: 1.3,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              count <= 1
                  ? 'Bạn mới ghi lại điều này một lần.'
                  : 'Bạn đã ghi lại điều này $count lần.',
              style: const TextStyle(
                fontSize: 15,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 32),
            const WrSectionDivider(),
            const SizedBox(height: 24),

            // ── Những lần bạn đã nhìn lại (ghi nhận — luôn miễn phí) ─────
            const WrEyebrow('NHỮNG LẦN BẠN ĐÃ NHÌN LẠI'),
            const SizedBox(height: 14),
            if (related.isEmpty)
              const Text(
                'Chưa có lần nhìn lại nào gắn với điều này.',
                style: TextStyle(
                  fontSize: 14,
                  color: WrColors.muted,
                  height: 1.6,
                ),
              )
            else
              ...related.take(10).map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.humanMoment.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: WrColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.draftMeaning ?? '(chưa đặt tên điều nhận ra)',
                            style: const TextStyle(
                              fontSize: 15,
                              color: WrColors.navy,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

            const SizedBox(height: 24),
            const WrSectionDivider(),
            const SizedBox(height: 24),

            // ── Diễn giải (Premium, và chỉ khi đủ dữ liệu) ───────────────
            const WrEyebrow('ĐIỀU ĐỨNG SAU SỰ LẶP LẠI'),
            const SizedBox(height: 14),
            if (!hasEnoughData)
              Text(
                'Cần thêm ${kInsightThreshold - count} lần nữa để hệ thống đủ '
                'dữ liệu đọc ra điều đứng sau.',
                key: const Key('wr_pattern_not_enough_data'),
                style: const TextStyle(
                  fontSize: 14,
                  color: WrColors.muted,
                  height: 1.6,
                ),
              )
            else if (!canRead)
              const WrPremiumLock(
                key: Key('wr_pattern_premium_lock'),
                description:
                    'Bản đầy đủ đọc ra nguyên nhân sâu đứng sau điều lặp lại '
                    'này, và điều gì đang dần thay đổi trong bạn.',
                ctaLabel: 'Mở phần diễn giải',
                paywallTrigger: 'pattern_advanced',
              )
            else
              Text(
                narratives.isNotEmpty
                    ? narratives.first.narrative
                    : 'Hệ thống đang tổng hợp phần diễn giải cho điều này.',
                key: const Key('wr_pattern_narrative'),
                style: const TextStyle(
                  fontSize: 16,
                  color: WrColors.navy,
                  height: 1.65,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
