// Những chặng đã đi qua — mở từ Hành trình (script `screenChapterList`).
//
// Chặng tính từ Episode thật (`wr_chapters.dart`), không còn ba chặng dữ liệu
// cứng của script.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_chapters.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../wr_providers.dart';

class WrChaptersScreen extends ConsumerWidget {
  const WrChaptersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final labels = {for (final s in situations) s.code: s.text};
    final chapters = buildChapters(
      episodes,
      labels: labels,
      now: DateTime.now(),
    );
    final openEntries = openChapterEntries(episodes, chapters);

    return WrDetailScaffold(
      art: WrHeroArt.grow,
      eyebrow: tr('Hành trình', 'Journey'),
      title: tr('Những chặng đã đi qua', 'The chapters behind you'),
      children: [
        WrParagraph(
          tr(
            'Mỗi chặng là một quãng đủ dài để thấy được thay đổi: ít nhất '
                '$kChapterMinEntries lần nhìn lại và cách chặng trước khoảng '
                '$kChapterMinWeeks tuần. Hệ thống tự đọc, bạn chỉ cần mở ra '
                'xem.',
            'Each chapter is a stretch long enough to see change: at least '
                '$kChapterMinEntries look-backs and about $kChapterMinWeeks '
                'weeks after the one before. The system reads it for you; you '
                'only need to open it.',
          ),
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontSize: 14.5,
            color: WrColors.muted,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 18),
        if (chapters.isEmpty)
          WrCardMinimal(
            key: const Key('wr_chapters_empty'),
            padding: const EdgeInsets.all(16),
            child: WrParagraph(
              tr(
                'Chặng đầu tiên sẽ khép lại khi bạn có đủ $kChapterMinEntries '
                    'lần nhìn lại trong khoảng $kChapterMinWeeks tuần. Hiện '
                    'chặng đang đi có $openEntries lần.',
                'Your first chapter closes once you have $kChapterMinEntries '
                    'look-backs across about $kChapterMinWeeks weeks. The '
                    'current one has $openEntries so far.',
              ),
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: 14.5,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
          ),
        // Mới nhất đứng đầu, đúng thứ tự `CHAPTERS` của script.
        for (final c in chapters.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _ChapterCard(chapter: c),
          ),
      ],
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter});

  final WrChapter chapter;

  @override
  Widget build(BuildContext context) {
    final c = chapter;
    return Material(
      key: Key('wr_chapters_card_${c.id}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/wr/chapter/${c.id}'),
        borderRadius: BorderRadius.circular(20),
        child: WrCardMinimal(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      wrKeepCompounds(c.label.toUpperCase()),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.text3,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  if (c.isLatest)
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
                        wrKeepCompounds(tr('Chặng gần nhất', 'Latest chapter')),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WrColors.pillCoralText,
                        ),
                      ),
                    )
                  else
                    Text(
                      wrKeepCompounds(tr('${c.entries} lần', '${c.entries} times')),
                      style: const TextStyle(
                        fontSize: 12,
                        color: WrColors.text3,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                wrKeepCompounds(c.range),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
              const SizedBox(height: 5),
              WrParagraph(
                c.lead,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: WrColors.muted,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
