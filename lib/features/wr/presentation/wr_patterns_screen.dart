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

class _RepeatLogItem {
  const _RepeatLogItem({required this.date, required this.text});
  final String date;
  final String text;
}

const _kScriptDemoLogs = <String, List<_RepeatLogItem>>{
  'C2-01': [
    _RepeatLogItem(
      date: '24/08',
      text: 'Mình đã chuẩn bị kỹ nhưng tới lượt thì nói hơi nhanh.',
    ),
    _RepeatLogItem(
      date: '17/08',
      text: 'Lần này mình nói sau, và cũng không ai hỏi lại.',
    ),
    _RepeatLogItem(date: '09/08', text: ''),
    _RepeatLogItem(
      date: '02/08',
      text: 'Anh T nhắc lại đúng ý mình vừa nói.',
    ),
    _RepeatLogItem(date: '28/07', text: ''),
  ],
  'A3-02': [
    _RepeatLogItem(
      date: '22/08',
      text: 'Ngủ đủ mà vẫn thấy nặng đầu từ sáng.',
    ),
    _RepeatLogItem(date: '15/08', text: ''),
    _RepeatLogItem(
      date: '06/08',
      text: 'Không có việc gì gấp, vẫn thấy mệt.',
    ),
  ],
  'C2-07': [
    _RepeatLogItem(
      date: '20/08',
      text: 'Cả phòng im nên mình cũng thôi.',
    ),
    _RepeatLogItem(date: '11/08', text: ''),
  ],
  'S1-01': [
    _RepeatLogItem(
      date: '19/08',
      text: 'Nhận việc rồi mới biết phần nào là của mình.',
    ),
    _RepeatLogItem(date: '05/08', text: ''),
  ],
  'S1-02': [
    _RepeatLogItem(
      date: '13/08',
      text: 'Tự đoán cách làm, xong thấy người khác làm kiểu khác.',
    ),
    _RepeatLogItem(date: '01/08', text: ''),
  ],
  'A1-01': [
    _RepeatLogItem(
      date: '24/08',
      text: 'Lên kế hoạch rất chi tiết nhưng cuối ngày lại tự hỏi mục đích thật là gì.',
    ),
    _RepeatLogItem(
      date: '17/08',
      text: 'Hoàn thành mọi đầu việc nhưng cảm giác trống rỗng.',
    ),
    _RepeatLogItem(date: '09/08', text: ''),
    _RepeatLogItem(
      date: '02/08',
      text: 'Mọi người khen nhanh nhẹn, nhưng mình không biết bước tiếp theo là đâu.',
    ),
  ],
  'A1-02': [
    _RepeatLogItem(
      date: '21/08',
      text: 'Lại mở tin tuyển dụng trong giờ nghỉ.',
    ),
    _RepeatLogItem(date: '12/08', text: ''),
    _RepeatLogItem(
      date: '03/08',
      text: 'Muốn đổi môi trường nhưng chưa hình dung rõ điều mình cần.',
    ),
  ],
  'A1-03': [
    _RepeatLogItem(
      date: '18/08',
      text: 'Tuần này rất bận, nhưng nhìn lại không biết mình làm vì điều gì.',
    ),
    _RepeatLogItem(date: '10/08', text: ''),
  ],
};

class WrPatternsScreen extends ConsumerStatefulWidget {
  const WrPatternsScreen({super.key});

  @override
  ConsumerState<WrPatternsScreen> createState() => _WrPatternsScreenState();
}

class _WrPatternsScreenState extends ConsumerState<WrPatternsScreen> {
  String? _expandedCode;

  List<_RepeatLogItem> _resolveLogs(
    String code,
    List<ReflectionEpisode> episodes,
  ) {
    final relevant = episodes.where((e) => e.situationCode == code).toList();
    relevant.sort((a, b) {
      final aTime = a.closedAt ?? a.updatedAt ?? a.openedAt ?? DateTime(2000);
      final bTime = b.closedAt ?? b.updatedAt ?? b.openedAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    final realItems = <_RepeatLogItem>[];
    for (final e in relevant) {
      final at = (e.closedAt ?? e.updatedAt ?? e.openedAt)?.toLocal();
      final dateStr = at != null
          ? '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}'
          : '';
      final text = e.notes['detail'] ??
          e.notes['notice'] ??
          e.draftMeaning ??
          '';
      realItems.add(_RepeatLogItem(date: dateStr, text: text));
    }

    if (realItems.isNotEmpty) {
      return realItems;
    }

    return _kScriptDemoLogs[code] ??
        const [
          _RepeatLogItem(date: 'Gần đây', text: ''),
        ];
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
    final total = episodes.length;

    return WrDetailScaffold(
      art: WrHeroArt.understand,
      eyebrow: tr('HIỂU MÌNH', 'UNDERSTAND'),
      title: tr('Những điều đang lặp lại', 'Recurring Patterns'),
      children: [
        if (repeated.isEmpty)
          Text(
            recentSituationIds(episodes).isEmpty
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
                  ),
            style: const TextStyle(
              fontSize: 14.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          )
        else ...[
          Text(
            tr(
              'Xếp theo số lần quay lại trong $total lần nhìn lại gần đây. '
                  'Chạm vào một dòng để xem bạn đã viết gì những lần đó.',
              'Sorted by recurrences in your last $total look-backs. '
                  'Tap a row to see what you wrote each time.',
            ),
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
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
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
                    tr('$count lần', '$count times'),
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
                            l.date,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: WrColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (l.text.isNotEmpty)
                            Text(
                              '“${l.text}”',
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
                              tr(
                                'Bạn không viết gì lần này',
                                'You wrote nothing this time',
                              ),
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
