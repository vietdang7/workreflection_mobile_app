// Đọc một chặng — script `screenChapterRead` + `answerChapter`.
//
// Ba phần: MỚI NỔI LÊN · ĐÃ THÔI LẶP LẠI · VẪN VẬY, tính từ Episode thật của
// chặng so với chặng liền trước (`wr_chapters.dart`). Không còn dữ liệu cứng
// `CHAPTERS` của script.
//
// Câu trả lời cho câu hỏi cuối chặng được GHI VÀO HÀNH TRÌNH thật: một mảnh ký
// ức Cột mốc trong `wr_career_memory_events`, đúng `answerChapter` của script
// (`type:'MILESTONE'`). Khối "ĐÃ GHI VÀO HÀNH TRÌNH" chỉ hiện khi lượt ghi đó
// thành công; SharedPreferences chỉ nhớ để lần mở sau không hỏi lại.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/wr_content_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_career_memory_rules.dart' show kMilestoneBehavior;
import '../../../core/logic/wr_chapters.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../wr_providers.dart';

/// Hai câu trả lời của câu hỏi cuối chặng (script `answerChapter`).
enum ChapterAnswer { real, unnoticed }

class WrChapterReadScreen extends ConsumerStatefulWidget {
  const WrChapterReadScreen({super.key, this.chapterId = 'latest'});

  /// `ch{số}`; mã không khớp chặng nào thì mở chặng gần nhất.
  final String chapterId;

  @override
  ConsumerState<WrChapterReadScreen> createState() =>
      _WrChapterReadScreenState();
}

class _WrChapterReadScreenState extends ConsumerState<WrChapterReadScreen> {
  ChapterAnswer? _answer;
  bool _saving = false;
  String? _error;

  /// Khoá nhớ câu trả lời: theo người dùng + mốc mở chặng, để một chặng khép
  /// lại khác (sau khi lịch sử đổi) không mượn câu trả lời của chặng cũ.
  String _prefsKey(String uid, WrChapter c) =>
      'wr_chapter_answer_${uid}_${c.id}_${c.start.millisecondsSinceEpoch}';

  String? _loadedFor;

  Future<void> _loadAnswer(WrChapter c) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final key = _prefsKey(uid, c);
    if (_loadedFor == key) return;
    _loadedFor = key;
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(key);
      final a = ChapterAnswer.values.where((e) => e.name == v).firstOrNull;
      if (mounted && a != null) setState(() => _answer = a);
    } catch (_) {
      /* không đọc được thì hỏi lại, không sao */
    }
  }

  Future<void> _submit(WrChapter c, ChapterAnswer kind) async {
    final uid = ref.read(currentUserIdProvider);
    if (_saving || uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final excerpt = kind == ChapterAnswer.real
        ? tr('Chuyện đó đã nhẹ đi thật.', 'It really has eased.')
        : tr('Mình chỉ thôi để ý tới nó.', 'I just stopped noticing it.');
    try {
      await ref
          .read(wrContentRepositoryProvider)
          .insertMemoryEvent(
            CareerMemoryEvent(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userId: uid,
              behavior: kMilestoneBehavior,
              reflectionText: tr(
                '${c.label}: bạn trả lời câu hỏi cuối chặng. $excerpt',
                '${c.label}: you answered the end-of-chapter question. '
                    '$excerpt',
              ),
            ),
          );
      ref.invalidate(wrMemoryEventsProvider);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey(uid, c), kind.name);
      } catch (_) {
        /* đã ghi vào Hành trình rồi; nhớ cục bộ chỉ là tiện lợi */
      }
      if (mounted) setState(() => _answer = kind);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'Chưa ghi được vào Hành trình. Thử lại nhé.',
            'Could not save this to your Journey. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodes =
        ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final labels = {for (final s in situations) s.code: s.text};
    final chapters = buildChapters(
      episodes,
      labels: labels,
      now: DateTime.now(),
    );
    final premium =
        ref
            .watch(wrEntitlementProvider)
            .valueOrNull
            ?.canUseFeature(WrPremiumFeature.selfCheckDeepDive) ??
        false;

    if (chapters.isEmpty) {
      return WrDetailScaffold(
        art: WrHeroArt.understand,
        eyebrow: tr('Diễn giải', 'Reading'),
        title: tr('Chưa có chặng nào', 'No chapter yet'),
        children: [
          WrParagraph(
            tr(
              'Chặng đầu tiên sẽ khép lại khi bạn có đủ $kChapterMinEntries '
                  'lần nhìn lại trong khoảng $kChapterMinWeeks tuần. Hệ thống '
                  'tự đọc, bạn chỉ cần mở ra xem.',
              'Your first chapter closes once you have $kChapterMinEntries '
                  'look-backs across about $kChapterMinWeeks weeks. The system '
                  'reads it for you; you only need to open it.',
            ),
            key: const Key('wr_chapter_read_empty'),
            textAlign: TextAlign.start,
            style: _para,
          ),
        ],
      );
    }

    final chapter =
        chapters.where((c) => c.id == widget.chapterId).firstOrNull ??
        chapters.last;
    if (premium && chapter.ask != null) _loadAnswer(chapter);

    return WrDetailScaffold(
      art: WrHeroArt.understand,
      eyebrow: chapter.label,
      title: chapter.range,
      children: premium ? _read(chapter) : _locked(chapter),
    );
  }

  List<Widget> _locked(WrChapter c) => [
    WrParagraph(c.lead, textAlign: TextAlign.start, style: _lead),
    const SizedBox(height: 10),
    WrParagraph(
      tr(
        'Bản đọc theo chặng so chặng này với chặng liền trước: điều gì mới nổi '
            'lên, điều gì đã thôi quay lại, điều gì vẫn vậy.',
        'The chapter reading compares this chapter with the one just before: '
            'what has surfaced, what has stopped coming back, what has stayed '
            'the same.',
      ),
      textAlign: TextAlign.start,
      style: _para,
    ),
    const SizedBox(height: 16),
    WrCardNavy(
      key: const Key('wr_chapter_read_locked'),
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
                    color: WrColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            wrKeepCompounds(tr('Mở khoá bản đọc theo chặng', 'Unlock the chapter reading')),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WrColors.cream,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            wrKeepCompounds(tr(
              'Phần “đã thôi lặp lại” chỉ xuất hiện khi có từ hai chặng trở lên. '
                  'Đây là thứ chỉ thời gian mới tạo ra được.',
              'The “no longer repeating” part only appears once there are two '
                  'chapters or more. It is something only time can create.',
            )),
            style: TextStyle(
              fontSize: 13.5,
              color: WrColors.cream.withValues(alpha: 0.72),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('wr_chapter_read_unlock'),
              onPressed: () => context.push('/wr/paywall?trigger=sca_deep'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.navy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(wrKeepCompounds(tr('Mở khoá', 'Unlock'))),
            ),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _read(WrChapter c) {
    final blocks = <Widget>[
      if (c.rose case final r?)
        _ChapterGroupTile(
          key: const Key('wr_chapter_rose'),
          label: tr('MỚI NỔI LÊN', 'NEWLY SURFACED'),
          color: WrColors.pillCoralText,
          title: r.title,
          detail: r.previousCount == null
              ? tr('${r.count} lần trong chặng này', '${r.count} times in this chapter')
              : tr(
                  '${r.count} lần, chặng trước ${r.previousCount} lần',
                  '${r.count} times, ${r.previousCount} in the chapter before',
                ),
        ),
      if (c.faded case final f?)
        _ChapterGroupTile(
          key: const Key('wr_chapter_faded'),
          label: tr('ĐÃ THÔI LẶP LẠI', 'NO LONGER REPEATING'),
          color: WrColors.pillTealText,
          title: f.title,
          detail: tr(
            '${f.count} lần, chặng trước ${f.previousCount} lần',
            '${f.count} times, ${f.previousCount} in the chapter before',
          ),
        ),
      if (c.steady case final s?)
        _ChapterGroupTile(
          key: const Key('wr_chapter_steady'),
          label: tr('VẪN VẬY', 'STILL THE SAME'),
          color: WrColors.text3,
          title: s.title,
          detail: tr(
            '${s.count} lần, không đổi nhiều',
            '${s.count} times, not much change',
          ),
        ),
    ];

    final ask = c.ask;
    return [
      Text(
        wrKeepCompounds(tr(
          '${c.entries} lần nhìn lại trong chặng này',
          '${c.entries} look-backs in this chapter',
        )),
        key: const Key('wr_chapter_entries'),
        style: const TextStyle(fontSize: 13, color: WrColors.text3),
      ),
      const SizedBox(height: 11),
      WrParagraph(c.lead, textAlign: TextAlign.start, style: _lead),
      if (blocks.isNotEmpty) ...[
        const SizedBox(height: 14),
        WrCardMinimal(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < blocks.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: WrColors.lineSoft),
                blocks[i],
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      WrParagraph(c.note, textAlign: TextAlign.start, style: _para),
      if (ask != null) ...[
        const SizedBox(height: 16),
        if (_answer case final a?)
          Container(
            key: const Key('wr_chapter_answer_saved'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WrColors.teal.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WrColors.teal.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wrKeepCompounds(tr('ĐÃ GHI VÀO HÀNH TRÌNH', 'SAVED TO YOUR JOURNEY')),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.pillTealText,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                WrParagraph(
                  a == ChapterAnswer.real
                      ? tr(
                          'Bạn thấy chuyện đó đã nhẹ đi thật. Chặng sau sẽ được '
                              'đọc trên nền này.',
                          'You feel it really has eased. The next chapter will '
                              'be read against that.',
                        )
                      : tr(
                          'Bạn thấy mình chỉ thôi để ý tới nó. Chặng sau sẽ chú '
                              'ý xem nó có quay lại không.',
                          'You feel you just stopped noticing it. The next '
                              'chapter will watch whether it comes back.',
                        ),
                  textAlign: TextAlign.start,
                  style: _para,
                ),
              ],
            ),
          )
        else
          WrCardMinimal(
            key: const Key('wr_chapter_ask'),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wrKeepCompounds(tr('MỘT CÂU HỎI CHO BẠN', 'A QUESTION FOR YOU')),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.pillTealText,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  wrKeepCompounds(ask),
                  style: WrText.serifQuote(fontSize: 15.5, color: WrColors.navy),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: _AnswerButton(
                        key: const Key('wr_chapter_answer_real'),
                        label: tr('Nhẹ đi thật', 'Really eased'),
                        onTap: _saving
                            ? null
                            : () => _submit(c, ChapterAnswer.real),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AnswerButton(
                        key: const Key('wr_chapter_answer_unnoticed'),
                        label: tr('Chỉ thôi để ý', 'Stopped noticing'),
                        onTap: _saving
                            ? null
                            : () => _submit(c, ChapterAnswer.unnoticed),
                      ),
                    ),
                  ],
                ),
                if (_error case final e?) ...[
                  const SizedBox(height: 10),
                  Text(
                    wrKeepCompounds(e),
                    key: const Key('wr_chapter_answer_error'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: WrColors.pillCoralText,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    ];
  }
}

const _lead = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: WrColors.navy,
  height: 1.55,
);
const _para = TextStyle(fontSize: 14.5, color: WrColors.muted, height: 1.65);

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0x40093774), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        wrKeepCompounds(label),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: WrColors.navy,
        ),
      ),
    );
  }
}

class _ChapterGroupTile extends StatelessWidget {
  const _ChapterGroupTile({
    super.key,
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wrKeepCompounds(label),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            wrKeepCompounds(title),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            wrKeepCompounds(detail),
            style: const TextStyle(fontSize: 12.5, color: WrColors.text3),
          ),
        ],
      ),
    );
  }
}
