// Diễn biến theo thời gian — màn riêng, mở từ tab Hành trình.
//
// Đây là DIỄN GIẢI (hệ thống đọc ra điều gì đang đổi), nên thuộc Premium
// theo Hai Lớp v1.2 §III. Bản miễn phí chỉ thấy phần ghi nhận ở tab Hành trình.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/wr_tr.dart';
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

    // Vào thẳng màn này (từ thông báo, hoặc mở lại app ở đúng route) mà không đi
    // qua tab Hành trình thì không có ai đánh thức `wr-narrative`. Watch ở cả
    // hai nơi — provider chỉ chạy một lần cho cả hai, Riverpod lo phần đó.
    final refresh = ref.watch(wrNarrativeRefreshProvider).valueOrNull;

    return WrDetailScaffold(
      eyebrow: tr('NHÌN LẠI DÒNG THỜI GIAN', 'LOOK BACK ALONG THE TIMELINE'),
      title: tr('Điều gì đang đổi trong bạn', 'What is changing in you'),
      children: [
        if (!canRead)
          WrPremiumLock(
            key: Key('wr_journey_narrative_lock'),
            description:
                tr('Mở khóa bản đầy đủ để nhìn lại toàn bộ bức tranh thay đổi của '
                'bạn qua từng giai đoạn.', 'Unlock the full version to see the whole picture of how you '
                'have changed, stage by stage.'),
            ctaLabel: tr('Mở phần nhìn lại dòng thời gian', 'Open the timeline look-back'),
            paywallTrigger: 'pattern_advanced',
          )
        else if (narratives.isEmpty)
          WrParagraph(
            _emptyLine(refresh),
            key: const Key('wr_journey_narrative_empty'),
            style: const TextStyle(
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

/// Câu khi chưa có bản kể nào — nói ĐÚNG còn thiếu bao nhiêu.
///
/// Cùng lý do với `_waitingLine` ở tab Hành trình: câu cũ không đếm ngược được
/// nên nó giống hệt nhau ở lần nhìn lại thứ hai và thứ ba mươi. Chữ ở đây dài
/// hơn một chút vì đây là màn đọc, không phải một thẻ tóm tắt.
String _emptyLine(WrNarrativeRefresh? refresh) {
  final needed = refresh?.needed;
  return switch (refresh?.status) {
    // "có chọn tình huống": cùng lý do với `_waitingLine` ở tab Hành trình —
    // hàm chỉ đếm Episode có `situation_code`, còn thẻ Career Health đếm tất.
    WrNarrativeStatus.notEnoughData when needed != null && needed > 0 =>
      tr('Còn $needed lần nhìn lại có chọn tình huống nữa là đủ để kể. Diễn biến '
          'so các tình huống ở hai giai đoạn với nhau, nên những lần bạn tự mô '
          'tả không có tình huống nào để đối chiếu.', '$needed more look-backs with a situation picked and there is enough to '
          'tell. The story compares situations across two stretches, so the '
          'times you wrote your own have nothing to compare against.'),
    WrNarrativeStatus.upToDate =>
      tr('Diễn biến của bạn đang được đọc lại. Quay lại màn này sau một lát nhé.', 'Your story is being read. Come back to this screen in a moment.'),
    _ => tr('Chưa đủ dữ liệu để kể lại diễn biến. Ghi thêm vài lần nữa, '
        'WorkReflection sẽ chỉ ra điều gì đang đổi và điều gì vẫn ở nguyên đó.', 'Not enough yet to tell the story. Record a few more and '
        'WorkReflection will point out what is changing and what has stayed '
        'put.'),
  };
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
