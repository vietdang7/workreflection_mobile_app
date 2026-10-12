// Đọc Báo cáo theo chặng (3 tháng) — Màn hình tầng trong.
// Theo mockup Sprint 2 (WorkReflection_ Sprint 2 · Companion with a Memory.html
// §screenChapterRead, §CHAPTERS).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../wr_providers.dart';
import 'wr_sca_deep_dive_screen.dart' show openScaDeepDive;

class ChapterItem {
  const ChapterItem({
    required this.id,
    required this.label,
    required this.range,
    required this.entries,
    required this.isNew,
    required this.lead,
    this.rose,
    this.faded,
    this.steady,
    required this.note,
    this.ask,
  });

  final String id;
  final String label;
  final String range;
  final int entries;
  final bool isNew;
  final String lead;
  final ({String title, int count, int? wasCount})? rose;
  final ({String title, int count, int? wasCount})? faded;
  final ({String title, int count})? steady;
  final String note;
  final String? ask;
}

final kChaptersData = <ChapterItem>[
  const ChapterItem(
    id: 'ch3',
    label: 'Chặng 3',
    range: 'Tháng 8 đến tháng 10',
    entries: 11,
    isNew: true,
    lead: 'Những gì bạn ghi lại ở chặng này đã đổi chỗ so với chặng trước.',
    rose: (title: 'Ranh giới giữa vai trò và kỳ vọng', count: 7, wasCount: 2),
    faded: (title: 'Phụ thuộc vào một người để việc chạy', count: 1, wasCount: 6),
    steady: (title: 'Mối quan hệ trong công việc', count: 5),
    note:
        'Chuyện "phụ thuộc vào một người" gần như không còn xuất hiện ở chặng này, sau khi chiếm phần lớn chặng trước. Nó có thể đã được giải quyết, cũng có thể chỉ là bạn đã quen với nó.',
    ask: 'Chuyện đó đã nhẹ đi thật, hay bạn chỉ thôi để ý tới nó?',
  ),
  const ChapterItem(
    id: 'ch2',
    label: 'Chặng 2',
    range: 'Tháng 6 đến tháng 7',
    entries: 9,
    isNew: false,
    lead: 'Phần lớn chặng này xoay quanh việc chờ người khác quyết.',
    rose: (title: 'Phụ thuộc vào một người để việc chạy', count: 6, wasCount: 3),
    faded: (title: 'Không rõ phạm vi việc được giao', count: 1, wasCount: 4),
    steady: (title: 'Mối quan hệ trong công việc', count: 4),
    note:
        'Chuyện phạm vi công việc thôi xuất hiện, đúng giai đoạn bạn ghi là đã viết xong bản mô tả công việc.',
    ask: 'Việc viết ra phạm vi có giúp được đến đâu?',
  ),
  const ChapterItem(
    id: 'ch1',
    label: 'Chặng 1',
    range: 'Tháng 4 đến tháng 5',
    entries: 7,
    isNew: false,
    lead: 'Chặng đầu tiên. Chưa có chặng nào trước để so, nên đây là nền.',
    rose: (title: 'Không rõ phạm vi việc được giao', count: 4, wasCount: null),
    faded: null,
    steady: (title: 'Mối quan hệ trong công việc', count: 3),
    note: 'Đây là chặng nền. Từ chặng sau, phần "đã thôi lặp lại" mới có nghĩa.',
    ask: null,
  ),
];

class WrChapterReadScreen extends ConsumerStatefulWidget {
  const WrChapterReadScreen({super.key, this.chapterId = 'ch3'});

  final String chapterId;

  @override
  ConsumerState<WrChapterReadScreen> createState() => _WrChapterReadScreenState();
}

class _WrChapterReadScreenState extends ConsumerState<WrChapterReadScreen> {
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('wr_chapter_fb_${widget.chapterId}');
    if (mounted && val != null) {
      setState(() => _feedback = val);
    }
  }

  Future<void> _saveFeedback(String kind) async {
    setState(() => _feedback = kind);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wr_chapter_fb_${widget.chapterId}', kind);
  }

  @override
  Widget build(BuildContext context) {
    final chapter = kChaptersData.firstWhere(
      (c) => c.id == widget.chapterId,
      orElse: () => kChaptersData.first,
    );

    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull;
    final isPremium =
        entitlement?.canUseFeature(WrPremiumFeature.selfCheckDeepDive) ?? false;

    return WrDetailScaffold(
      art: WrHeroArt.understand,
      eyebrow: chapter.label.toUpperCase(),
      title: chapter.range,
      children: [
        if (!isPremium) ...[
          WrParagraph(
            chapter.lead,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: WrColors.navy,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              'Bản đọc theo chặng so chặng này với chặng liền trước: điều gì mới nổi lên, điều gì đã thôi quay lại, điều gì vẫn vậy.',
              'Quarterly review compares this chapter with the previous one: what emerged, what stopped recurring, and what stayed steady.',
            ),
            style: const TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
          ),
          const SizedBox(height: 20),
          WrCardNavy(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: WrColors.coral, size: 16),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: WrColors.coral,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Premium',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WrColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tr('Mở khoá bản đọc theo chặng', 'Unlock chapter review'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: WrColors.cream,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Phần "đã thôi lặp lại" chỉ xuất hiện khi có từ hai chặng trở lên. Đây là thứ chỉ thời gian mới tạo ra được.',
                    'The "stopped recurring" section only appears after 2+ chapters. It is something only time creates.',
                  ),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: WrColors.cream.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => openScaDeepDive(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WrColors.coral,
                    foregroundColor: WrColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr('Mở khoá', 'Unlock')),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            tr(
              '${chapter.entries} lần nhìn lại trong chặng này',
              '${chapter.entries} look-backs in this chapter',
            ),
            style: const TextStyle(fontSize: 13, color: WrColors.text3),
          ),
          const SizedBox(height: 10),
          WrParagraph(
            chapter.lead,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: WrColors.navy,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // 3 blocks: MỚI NỔI LÊN, ĐÃ THÔI LẶP LẠI, VẪN VẬY
          WrCardMinimal(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  if (chapter.rose != null) ...[
                    _ChapterGroupTile(
                      label: tr('MỚI NỔI LÊN', 'EMERGING'),
                      color: WrColors.coral,
                      title: chapter.rose!.title,
                      detail: chapter.rose!.wasCount == null
                          ? tr(
                              '${chapter.rose!.count} lần trong chặng này',
                              '${chapter.rose!.count} times in this chapter',
                            )
                          : tr(
                              '${chapter.rose!.count} lần, chặng trước ${chapter.rose!.wasCount} lần',
                              '${chapter.rose!.count} times, previously ${chapter.rose!.wasCount}',
                            ),
                    ),
                  ],
                  if (chapter.faded != null) ...[
                    const Divider(height: 1, color: WrColors.lineSoft),
                    _ChapterGroupTile(
                      label: tr('ĐÃ THÔI LẶP LẠI', 'STOPPED RECURRING'),
                      color: WrColors.teal,
                      title: chapter.faded!.title,
                      detail: tr(
                        '${chapter.faded!.count} lần, chặng trước ${chapter.faded!.wasCount} lần',
                        '${chapter.faded!.count} times, previously ${chapter.faded!.wasCount}',
                      ),
                    ),
                  ],
                  if (chapter.steady != null) ...[
                    const Divider(height: 1, color: WrColors.lineSoft),
                    _ChapterGroupTile(
                      label: tr('VẪN VẬY', 'STEADY'),
                      color: WrColors.text3,
                      title: chapter.steady!.title,
                      detail: tr(
                        '${chapter.steady!.count} lần, không đổi nhiều',
                        '${chapter.steady!.count} times, relatively unchanged',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(
            chapter.note,
            style: const TextStyle(fontSize: 14.5, color: WrColors.muted, height: 1.6),
          ),
          const SizedBox(height: 20),

          // Reflection Question
          if (chapter.ask != null) ...[
            if (_feedback != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WrColors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WrColors.teal.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('ĐÃ GHI VÀO HÀNH TRÌNH', 'RECORDED TO JOURNEY'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.teal,
                        letterSpacing: 0.06,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _feedback == 'real'
                          ? tr(
                              'Bạn thấy chuyện đó đã nhẹ đi thật. Chặng sau sẽ được đọc trên nền này.',
                              'You feel it truly lightened up. The next chapter will build on this baseline.',
                            )
                          : tr(
                              'Bạn thấy mình chỉ thôi để ý tới nó. Chặng sau sẽ chú ý xem nó có quay lại không.',
                              'You feel you just stopped paying attention to it. The next chapter will watch if it returns.',
                            ),
                      style: const TextStyle(fontSize: 13.5, color: WrColors.navy, height: 1.5),
                    ),
                  ],
                ),
              ),
            ] else ...[
              WrCardMinimal(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('MỘT CÂU HỎI CHO BẠN', 'A QUESTION FOR YOU'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: WrColors.teal,
                          letterSpacing: 0.06,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        chapter.ask!,
                        style: WrText.serifQuote(fontSize: 15.5, color: WrColors.navy),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _saveFeedback('real'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: WrColors.line),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                tr('Nhẹ đi thật', 'Truly lightened'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: WrColors.navy,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _saveFeedback('unnoticed'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: WrColors.line),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                tr('Chỉ thôi để ý', 'Just stopped minding'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: WrColors.navy,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }
}

class _ChapterGroupTile extends StatelessWidget {
  const _ChapterGroupTile({
    required this.label,
    required this.color,
    required this.title,
    required this.detail,
  });

  final String label;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.06,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(fontSize: 12.5, color: WrColors.text3),
          ),
        ],
      ),
    );
  }
}
