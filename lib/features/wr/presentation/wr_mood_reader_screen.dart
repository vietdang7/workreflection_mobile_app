// Thư viện Nội dung Cảm xúc — màn đọc / nghe (mockup v47 `screenContentReader`).
// Kiến trúc Dữ liệu Hai Lớp v1.6 §8.1, §8.2 + họp khách 2026-07-29.
//
// Bố cục v47: dải phong cảnh theo cảm xúc của bài · chip cảm xúc + "Đọc · 5
// phút" · tiêu đề · (bài nghe: khối phát) · lời dẫn · thân bài · "Câu hỏi để
// mang theo" · nút "Xong, đọc bài khác".
//
// Giữ từ buổi họp 2026-07-29:
//   1. HEADER GIỮ NGUYÊN KHI CUỘN: nút lùi luôn ở đỉnh, cuộn qua tiêu đề thì
//      thanh phủ nền và hiện tên bài thu nhỏ.
//   2. CHỮ GIÃN RA ("đọc bị tức mắt"): cỡ chữ lớn hơn mockup một bậc.
//   3. NGHE ĐƯỢC THẬT: có bản thu thì phát bằng just_audio. Chưa có thì trước
//      đây dựng bằng giọng AI tại chỗ; từ v47 việc đó đi theo `kAiVoiceEnabled`
//      (mặc định tắt).
//
// ⚠ §XII.3: màn này KHÔNG hiển thị `script` (kịch bản lồng tiếng) dù mockup có
//   khối "Kịch bản lồng tiếng (nội bộ)". Trường đó không tồn tại trong
//   [MoodContent] vì repository đọc qua view `wr_mood_content_public`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/data/ausynclab_tts_service.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_ai_voice.dart';
import '../../../core/widgets/wr_ai_consent_sheet.dart';
import '../../../core/models/checkin.dart' show Mood;
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/wr_back_circle.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../mood_content_providers.dart';
import 'wr_mood_library_screen.dart' show moodContentMeta;

class WrMoodReaderScreen extends ConsumerWidget {
  const WrMoodReaderScreen({
    super.key,
    required this.contentId,
    this.fromLibrary = false,
  });

  final String contentId;

  /// Mở từ màn Thư viện: "Xong, đọc bài khác" chỉ cần lùi về đó. Mở từ Home
  /// thì nút đó thay màn này bằng Thư viện.
  final bool fromLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(wrMoodLibraryProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _ReaderMissing(),
        data: (grouped) {
          final item = grouped.values
              .expand((items) => items)
              .where((c) => c.id == contentId)
              .firstOrNull;
          if (item == null) return const _ReaderMissing();
          return _ReaderBody(item: item, fromLibrary: fromLibrary);
        },
      ),
    );
  }
}

/// Tách bài thành ba phần như mockup (`screenContentReader`): đoạn đầu là lời
/// dẫn, đoạn cuối là "Câu hỏi để mang theo" nếu bài có từ ba đoạn trở lên và
/// đoạn cuối kết bằng dấu hỏi, còn lại là thân bài.
({String? lead, List<String> body, String? ask}) splitMoodArticle(
  List<String> paragraphs,
) {
  if (paragraphs.isEmpty) return (lead: null, body: const [], ask: null);
  final hasAsk =
      paragraphs.length > 2 && RegExp(r'\?\s*$').hasMatch(paragraphs.last);
  return (
    lead: paragraphs.first,
    body: paragraphs.sublist(
      1,
      hasAsk ? paragraphs.length - 1 : paragraphs.length,
    ),
    ask: hasAsk ? paragraphs.last : null,
  );
}

class _ReaderBody extends StatefulWidget {
  const _ReaderBody({required this.item, required this.fromLibrary});

  final MoodContent item;
  final bool fromLibrary;

  @override
  State<_ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends State<_ReaderBody> {
  final _scroll = ScrollController();

  /// Chiều cao thanh ghim trên cùng (chưa tính thanh trạng thái).
  static const _barHeight = 56.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _done() {
    if (widget.fromLibrary && context.canPop()) {
      context.pop();
    } else {
      context.pushReplacement(
        '/wr/mood-library?mood=${widget.item.mood.moodContentKey}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final mood = item.mood.moodContentKey;
    final top = MediaQuery.paddingOf(context).top;
    final parts = splitMoodArticle(item.paragraphs);

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Dải phong cảnh trôi theo nội dung, như mockup.
              AnimatedBuilder(
                animation: _scroll,
                builder: (_, child) => Positioned(
                  top: -(_scroll.hasClients ? _scroll.offset : 0.0),
                  left: 0,
                  right: 0,
                  child: child!,
                ),
                child: WrReflectBand(mood: mood),
              ),
              ListView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(22, top + _barHeight + 4, 22, 24),
                children: [
                  Row(
                    children: [
                      _MoodChip(mood: item.mood),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          moodContentMeta(item),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: WrColors.text3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    key: const Key('wr_mood_reader_title'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (item.type == MoodContentType.audio) ...[
                    _AudioPlayerBlock(item: item),
                    const SizedBox(height: 18),
                  ],
                  // Chữ to và giãn (khách 2026-07-29: "đọc bị tức mắt"): lời
                  // dẫn 17.5, thân bài 16 giãn 1.85 — lớn hơn mockup một bậc
                  // theo quy ước cỡ chữ của app.
                  if (parts.lead != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        parts.lead!,
                        key: const Key('wr_mood_reader_lead'),
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w500,
                          color: WrColors.navy,
                          height: 1.65,
                        ),
                      ),
                    ),
                  for (final p in parts.body)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 16,
                          color: WrColors.text2,
                          height: 1.85,
                        ),
                      ),
                    ),
                  if (parts.ask != null) _AskBlock(question: parts.ask!),
                  // §8.2: nội dung còn nháp thì nói thẳng, đừng để người dùng
                  // tưởng đây là bản chính thức.
                  if (item.placeholder) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        tr(
                          'Bản nháp, chưa biên tập chính thức',
                          'Draft, not yet properly edited',
                        ),
                        key: const Key('wr_mood_draft_notice'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: WrColors.text3.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // ── Thanh ghim ───────────────────────────────────────────────
              //
              // Khách 2026-07-29: "nó chỉ đẩy cái nội dung lên thôi và nó giữ
              // lại cái header". Nút lùi luôn ở đó; cuộn qua tiêu đề thì thanh
              // phủ nền và hiện tên bài thu nhỏ.
              AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) {
                  final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                  final t = (offset / 60).clamp(0.0, 1.0);
                  return Container(
                    key: const Key('wr_mood_reader_header'),
                    height: top + _barHeight,
                    padding: EdgeInsets.fromLTRB(22, top, 22, 0),
                    decoration: BoxDecoration(
                      color: WrColors.pageBg.withValues(alpha: t),
                      border: Border(
                        bottom: BorderSide(
                          color: WrColors.line.withValues(alpha: t),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        WrBackCircle(
                          key: const Key('wr_mood_reader_back'),
                          onTap: () => context.pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Opacity(
                            opacity: t,
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: WrColors.navy,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // `.rf-cta`
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('wr_mood_reader_done'),
                onPressed: _done,
                style: FilledButton.styleFrom(
                  backgroundColor: WrColors.coral,
                  foregroundColor: WrColors.navy,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  tr('Xong, đọc bài khác', 'Done, read another'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `.mood-chip` — chấm màu + tên cảm xúc của bài.
class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.mood});

  final Mood mood;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: WrColors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WrColors.navy.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: WrMoodPalette.dot(mood.moodContentKey),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            moodLabel(mood),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: WrColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.rd-ask` — "Câu hỏi để mang theo".
class _AskBlock extends StatelessWidget {
  const _AskBlock({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_mood_reader_ask'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: WrColors.coral.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
        border: const Border(left: BorderSide(color: WrColors.coral, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('CÂU HỎI ĐỂ MANG THEO', 'A QUESTION TO TAKE WITH YOU'),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: WrColors.pillCoralText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question,
            style: WrText.serifQuote(fontSize: 16, color: WrColors.navy),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Khối trình phát cho HEALING AUDIO.
//
// Ba trạng thái, và cả ba đều nói ra đúng điều đang xảy ra:
//   • có `audioUrl`  → phát ngay
//   • chưa có        → nút "Nghe bằng giọng đọc AI", dựng tại chỗ rồi phát
//   • dựng thất bại  → hiện nguyên văn lý do (ví dụ gói API chưa mở)
//
// Bản thu dựng ở đây KHÔNG được lưu xuống DB từ phía app: client chỉ có quyền
// đọc thư viện. Đội vận hành dựng sẵn rồi ghi vào `wr_mood_content.audio_url`;
// nút này là lối thoát cho bài chưa kịp dựng, không phải quy trình chính.
// ---------------------------------------------------------------------------

class _AudioPlayerBlock extends ConsumerStatefulWidget {
  const _AudioPlayerBlock({required this.item});

  final MoodContent item;

  @override
  ConsumerState<_AudioPlayerBlock> createState() => _AudioPlayerBlockState();
}

class _AudioPlayerBlockState extends ConsumerState<_AudioPlayerBlock> {
  /// Tạo muộn: hàm dựng của [AudioPlayer] chạm platform channel, mà màn này
  /// được dựng trong widget test không có nền tảng thật.
  AudioPlayer? _player;

  String? _url;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = widget.item.hasAudio ? widget.item.audioUrl : null;
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;

    // Dựng bản thu nghĩa là gửi đoạn chữ thẳng sang Ausynclab — màn này gọi
    // `AusynclabTtsService` trực tiếp, không đi qua Edge Function nào, nên
    // không có chốt chặn phía máy chủ nào đỡ cho nó. Cổng chặn ở đây là chốt
    // DUY NHẤT của luồng này.
    //
    // Hỏi trước cả `_url` đã có sẵn hay chưa: lần phát lại không gửi gì thêm,
    // nhưng lần đầu thì có, và người dùng cần biết trước lần đầu đó.
    // Giọng AI đang tắt (mockup v47, khách 06/10): bài chưa có bản thu thì
    // không dựng tại chỗ nữa.
    if (_url == null && !kAiVoiceEnabled) return;
    if (_url == null && !await ensureAiConsent(context, ref)) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Chưa có bản thu thì dựng trước. Chỉ dựng MỘT lần cho mỗi lần mở màn —
      // `_url` giữ lại kết quả, bấm dừng rồi phát lại không gọi TTS nữa.
      final url = _url ??= await ref
          .read(ttsServiceProvider)
          .synthesize(text: widget.item.body, name: widget.item.title);

      final player = _player ??= AudioPlayer();
      if (player.playing) {
        await player.pause();
      } else {
        if (player.audioSource == null) await player.setUrl(url);
        await player.play();
      }
    } on TtsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'Không phát được bản thu này.',
            'Could not play this recording.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = _player?.playing ?? false;

    return Container(
      key: const Key('wr_mood_audio_player'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: WrColors.navy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          GestureDetector(
            key: const Key('wr_mood_audio_play'),
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: WrColors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(19),
                      child: CircularProgressIndicator(
                        color: WrColors.cream,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 32,
                      color: WrColors.cream,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error ??
                (_busy
                    ? tr(
                        'Đang dựng bản thu bằng giọng đọc AI…',
                        'Building the recording with the AI voice…',
                      )
                    : _url != null
                    ? widget.item.durationLabel
                    : kAiVoiceEnabled
                    ? tr('Nghe bằng giọng đọc AI', 'Listen with the AI voice')
                    : tr(
                        'Bản thu đang được chuẩn bị.',
                        'The recording is on its way.',
                      )),
            key: const Key('wr_mood_audio_status'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: _error != null
                  ? WrColors.coral
                  : WrColors.cream.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderMissing extends StatelessWidget {
  const _ReaderMissing();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          tr('Không mở được nội dung này.', 'Could not open this content.'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: WrColors.muted),
        ),
      ),
    );
  }
}
