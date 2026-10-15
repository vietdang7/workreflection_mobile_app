// Toàn bộ điều lặp lại — Màn hình tầng trong của tab Hiểu mình.
// Theo đặc tả Sprint 2 (WorkReflection_ Sprint 2 · Companion with a Memory.html §screenRepeatList).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_repeated_situations.dart';
import '../../../core/models/wr_episode.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../wr_providers.dart';
import 'wr_discover_screen.dart' show situationLabelFor;
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

class _RepeatLogItem {
  const _RepeatLogItem({required this.date, required this.text});
  final String date;
  final String text;
}

class WrPatternsScreen extends ConsumerStatefulWidget {
  const WrPatternsScreen({super.key});

  @override
  ConsumerState<WrPatternsScreen> createState() => _WrPatternsScreenState();
}

class _WrPatternsScreenState extends ConsumerState<WrPatternsScreen> {
  String? _expandedCode;

  /// Từng lần của một tình huống — CHÍNH những lần đứng sau con số "n lần"
  /// của dòng đó: cùng `episodesForSituation`, cùng cửa sổ
  /// [kRecentSituationsWindow] lần gần nhất, mới nhất đứng đầu. Lấy tập khác
  /// (toàn bộ lịch sử) là để dòng ghi "3 lần" mà xổ ra năm mục.
  ///
  /// Không có Episode thì không có mục nào; không bao giờ bày dữ liệu mẫu.
  List<_RepeatLogItem> _resolveLogs(
    String code,
    List<ReflectionEpisode> episodes,
  ) => [
    for (final e in episodesForSituation(episodes, code))
      _RepeatLogItem(
        date: _dayMonth(e.openedAt ?? e.updatedAt ?? e.closedAt),
        // Câu người dùng đã kể ở bước "Kể lại khoảnh khắc".
        text: e.notes[ReflectionPattern.explore.dbValue]?.trim() ?? '',
      ),
  ];

  static String _dayMonth(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final sitMap = {for (final s in situations) s.code: s.text};

    final repeated = repeatedSituations(
      episodes,
      minCount: kRepeatedSituationsMinCount,
    );
    // Mẫu số phải cùng phạm vi với số đếm: số đếm lấy trong cửa sổ
    // `recentSituationIds` (30 lần gần nhất), nên mẫu số cũng là số lần trong
    // cửa sổ đó. Lấy tổng mọi lần sẽ ra câu sai nghĩa "4 lần trong 50 lần"
    // trong khi 4 chỉ đếm trên 30 lần (máy thật 13/10). Cùng con số với thẻ
    // "Quay lại nhiều nhất" của tab Hiểu mình.
    final total = recentSituationIds(episodes).length;

    return WrDetailScaffold(
      art: WrHeroArt.understand,
      eyebrow: tr('HIỂU MÌNH', 'UNDERSTAND'),
      title: tr('Những điều đang lặp lại', 'What keeps coming back'),
      children: [
        if (repeated.isEmpty)
          Text(
            wrKeepCompounds(recentSituationIds(episodes).isEmpty
                ? tr(
                    'Sau vài lần nhìn lại có chọn tình huống, những điều lặp lại '
                        'sẽ hiện ra ở đây.',
                    'After a few look-backs where you pick a situation, the things '
                        'that repeat will show up here.',
                  )
                : tr(
                    'Chưa điều nào trở lại đủ $kRepeatedSituationsMinCount lần. '
                        'Những gì bạn đã ghi vẫn còn nguyên trong Hành trình.',
                    'Nothing has come back $kRepeatedSituationsMinCount times yet. '
                        'Everything you recorded is still there in your Journey.',
                  )),
            style: const TextStyle(
              fontSize: 14.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          )
        else ...[
          Text(
            wrKeepCompounds(tr(
              'Xếp theo số lần quay lại trong $total lần nhìn lại gần đây. '
                  'Chạm vào một dòng để xem bạn đã viết gì những lần đó.',
              'Sorted by recurrences in your last $total look-backs. '
                  'Tap a row to see what you wrote each time.',
            )),
            style: const TextStyle(
              fontSize: 14,
              color: WrColors.muted,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
              color: WrColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: WrColors.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var idx = 0; idx < repeated.length; idx++) ...[
                  _RepeatSituationRow(
                    code: repeated[idx].situationCode,
                    title: situationLabelFor(sitMap, repeated[idx].situationCode),
                    count: repeated[idx].count,
                    isOpen: _expandedCode == repeated[idx].situationCode,
                    onToggle: () {
                      setState(() {
                        _expandedCode =
                            _expandedCode == repeated[idx].situationCode
                                ? null
                                : repeated[idx].situationCode;
                      });
                    },
                    entries: _resolveLogs(
                      repeated[idx].situationCode,
                      episodes,
                    ),
                  ),
                  if (idx < repeated.length - 1)
                    const Divider(height: 1, color: WrColors.lineSoft),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RepeatSituationRow extends StatelessWidget {
  const _RepeatSituationRow({
    required this.code,
    required this.title,
    required this.count,
    required this.isOpen,
    required this.onToggle,
    required this.entries,
  });

  final String code;
  final String title;
  final int count;
  final bool isOpen;
  final VoidCallback onToggle;
  final List<_RepeatLogItem> entries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: Key('wr_patterns_row_$code'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    wrKeepCompounds(title),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: WrColors.navy,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: WrColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    wrKeepCompounds(tr('$count lần', '$count times')),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: WrColors.text3,
                  ),
                ),
              ],
            ),
          ),
          if (isOpen) ...[
            Container(
              key: Key('wr_patterns_row_log_$code'),
              margin: const EdgeInsets.only(top: 11),
              padding: const EdgeInsets.only(left: 11),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: WrColors.lineSoft,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wrKeepCompounds(l.date),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: WrColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (l.text.isNotEmpty)
                            Text(
                              wrKeepCompounds('“${l.text}”'),
                              style: const TextStyle(
                                fontFamily: 'Lora',
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                                color: WrColors.muted,
                                height: 1.55,
                              ),
                            )
                          else
                            Text(
                              wrKeepCompounds(tr(
                                'Bạn không viết gì lần này',
                                'You wrote nothing this time',
                              )),
                              style: TextStyle(
                                fontSize: 11,
                                color: WrColors.muted.withValues(alpha: 0.55),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
