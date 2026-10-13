// Nhìn lại dòng thời gian — script `screenTimelineRead`.
//
// Bản miễn phí ĐỌC ĐƯỢC phần mở đầu + bốn đoạn; chỉ thẻ "DIỄN BIẾN ĐẦY ĐỦ" là
// lối vào Premium (nút mở paywall `ai_insight`). Bản trước khoá cả màn và, khi
// chưa có bản kể nào, hiện một đoạn văn mẫu viết cứng như thể là của người
// dùng — giờ chưa có bản kể thật thì nói thẳng là chưa có.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/wr_app_background.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../../../core/widgets/wr_small_button.dart';
import '../wr_providers.dart';

/// Ảnh đầu màn — `CARD_TIMELINE` của script.
const String kTimelineReadImage = 'assets/images/card_timeline.webp';

/// Số đoạn thân bài hiện dưới phần mở đầu (script `TIMELINE_READ.paras`).
const int kTimelineReadParagraphs = 4;

/// Tách một bản kể thành phần mở đầu + các đoạn.
///
/// Model viết đoạn cách nhau bằng dòng trống; bản cũ có khi chỉ xuống một
/// dòng. Trả về danh sách rỗng khi không có chữ nào.
List<String> splitTimelineNarrative(String? narrative) {
  final text = narrative?.trim() ?? '';
  if (text.isEmpty) return const [];
  var parts = text.split(RegExp(r'\n\s*\n'));
  if (parts.length == 1) parts = text.split('\n');
  return [
    for (final p in parts)
      if (p.trim().isNotEmpty) p.trim(),
  ];
}

String _ddmm(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/'
      '${l.month.toString().padLeft(2, '0')}';
}

class WrTimelineReadScreen extends ConsumerWidget {
  const WrTimelineReadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement =
        ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final pro = entitlement.isPremium;

    // Bản Premium đã cho phép xử lý bằng AI thì xin máy chủ kể lại khi tới kỳ.
    // Provider tự dừng nếu chưa có quyền hoặc chưa được phép — không có dữ
    // liệu nào rời máy ở đây với bản miễn phí.
    if (pro) ref.watch(wrNarrativeRefreshProvider);

    final all =
        ref.watch(wrPatternNarrativesProvider).valueOrNull ??
        const <PatternNarrative>[];
    final latest = currentLocaleNarrative(all);
    final parts = splitTimelineNarrative(latest?.narrative);
    final lead = parts.isEmpty ? null : parts.first;
    final paras = parts.skip(1).take(kTimelineReadParagraphs).toList();

    // Câu mở đầu thẻ bản miễn phí: script ghi "Bài trên đọc bốn tháng gần
    // đây", nhưng `wr-narrative` đọc 30 lần nhìn lại gần nhất chứ không theo
    // tháng — nói đúng quãng thật của bài thay vì một con số cố định.
    final start = latest?.periodStart;
    final end = latest?.periodEnd;
    final scope = (start != null && end != null)
        ? tr(
            'Bài trên đọc quãng từ ${_ddmm(start)} đến ${_ddmm(end)}.',
            'The piece above reads ${_ddmm(start)} to ${_ddmm(end)}.',
          )
        : tr(
            'Bài trên đọc những lần nhìn lại gần đây.',
            'The piece above reads your recent look-backs.',
          );

    return WrAppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            const _TimelineHero(),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 17, 22, 0),
              child: lead == null
                  ? WrParagraph(
                      tr(
                        'Chưa có bản đọc nào về dòng thời gian của bạn. Khi '
                            'đủ những lần nhìn lại có chọn tình huống, bản đọc '
                            'sẽ xuất hiện ở đây.',
                        'There is no reading of your timeline yet. Once there '
                            'are enough look-backs with a chosen situation, it '
                            'will appear here.',
                      ),
                      key: const Key('wr_timeline_read_empty'),
                      style: const TextStyle(
                        fontSize: 15,
                        color: WrColors.text2,
                        height: 1.7,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // `.rd-lead`
                        Text(
                          wrKeepCompounds(lead),
                          key: const Key('wr_timeline_read_lead'),
                          style: WrText.serifQuote(
                            fontSize: 17,
                            color: WrColors.navy,
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // `.rd-p`
                        for (var i = 0; i < paras.length; i++) ...[
                          WrParagraph(
                            paras[i],
                            key: Key('wr_timeline_read_p_$i'),
                            style: const TextStyle(
                              fontSize: 15,
                              color: WrColors.text2,
                              height: 1.8,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              child: WrCard(
                key: const Key('wr_timeline_read_full_card'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      wrKeepCompounds(tr('DIỄN BIẾN ĐẦY ĐỦ', 'THE FULL STORY')),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: pro ? WrColors.pillTealText : WrColors.text3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    WrParagraph(
                      pro
                          ? tr(
                              'Bản đọc theo từng chặng, từ ghi nhận đầu tiên '
                                  'đến hôm nay.',
                              'A reading chapter by chapter, from your first '
                                  'entry to today.',
                            )
                          : '$scope ${tr('Bản đầy đủ đi từ ghi nhận đầu tiên, theo từng chặng.', 'The full version goes from your first entry, chapter by chapter.')}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: WrColors.text2,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    WrSmallButton(
                      key: const Key('wr_timeline_read_full_cta'),
                      kind: pro
                          ? WrSmallButtonKind.primary
                          : WrSmallButtonKind.ghost,
                      label: tr(
                        'Đọc toàn bộ diễn biến  →',
                        'Read the full story  →',
                      ),
                      onTap: () => context.push(
                        pro
                            ? '/wr/journey/narrative/full'
                            : '/wr/paywall?trigger=ai_insight',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Đầu màn: ảnh `CARD_TIMELINE` 168px, lớp phủ, nút quay lại, eyebrow
/// "Hành trình" và tiêu đề "Nhìn lại dòng thời gian".
class _TimelineHero extends StatelessWidget {
  const _TimelineHero();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      key: const Key('wr_timeline_read_hero'),
      height: 168 + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(kTimelineReadImage, fit: BoxFit.cover),
          // `.hero-scrim`: phủ sáng để chữ navy đọc được trên ảnh, đáy tan vào
          // nền màn.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33FFFFFF), Color(0xB3FFFFFF)],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, top + 4, 22, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Script `.hero2 .backbtn`: trên ảnh, nút lùi là vòng tròn 34px
                // nền navy .82, icon cream, viền cream mờ. Một dấu "<" trần trên
                // ảnh gần như vô hình (máy thật 13/10).
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 6),
                  child: Semantics(
                    button: true,
                    label: tr('Quay lại', 'Back'),
                    child: InkResponse(
                      key: const Key('wr_detail_back'),
                      onTap: () => context.pop(),
                      radius: 22,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: WrColors.navy.withValues(alpha: 0.82),
                          border: Border.all(
                            color: WrColors.cream.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: WrColors.navy.withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          size: 22,
                          color: WrColors.cream,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wrKeepCompounds(tr('HÀNH TRÌNH', 'JOURNEY')),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: WrColors.eyebrow,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wrKeepCompounds(tr(
                          'Nhìn lại dòng thời gian',
                          'Looking back along the timeline',
                        )),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: WrColors.navy,
                          height: 1.32,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
