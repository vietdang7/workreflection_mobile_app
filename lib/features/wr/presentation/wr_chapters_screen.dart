// Danh sách các chặng — Mở từ tab Hành trình hoặc Hiểu mình.
// Theo mockup Sprint 2 (WorkReflection_ Sprint 2 · Companion with a Memory.html §screenChapterList).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_paragraph.dart';
import 'wr_chapter_read_screen.dart' show kChaptersData;

class WrChaptersScreen extends StatelessWidget {
  const WrChaptersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WrDetailScaffold(
      art: WrHeroArt.grow,
      eyebrow: tr('HÀNH TRÌNH', 'JOURNEY'),
      title: tr('Những chặng đã đi qua', 'Past Chapters'),
      children: [
        WrParagraph(
          tr(
            'Mỗi chặng là một quãng đủ dài để thấy được thay đổi: ít nhất 8 lần nhìn lại và cách chặng trước khoảng 6 tuần. Hệ thống tự đọc, bạn chỉ cần mở ra xem.',
            'Each chapter is a period long enough to notice shift: at least 8 look-backs and ~6 weeks since the last. The system reads them automatically.',
          ),
          style: const TextStyle(
            fontSize: 14.5,
            color: WrColors.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        for (final c in kChaptersData) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WrCardMinimal(
              child: InkWell(
                onTap: () => context.push('/wr/chapter/${c.id}'),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            c.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: WrColors.text3,
                              letterSpacing: 0.06,
                            ),
                          ),
                          if (c.isNew)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: WrColors.coral.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tr('Chặng gần nhất', 'Latest'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: WrColors.coral,
                                ),
                              ),
                            )
                          else
                            Text(
                              tr('${c.entries} lần', '${c.entries} entries'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: WrColors.text3,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.range,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: WrColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.lead,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: WrColors.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
