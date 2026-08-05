// Thư viện Nội dung Cảm xúc — màn đọc / nghe.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §8.1, §8.2 + họp khách 2026-07-29.
//
// §8.1: `type` quyết định giao diện — audio có thêm khối trình phát phía trên
// phần chữ. BÀI ĐỌC hiện toàn văn; HEALING AUDIO hiện mô tả ngắn dưới khối phát.
//
// Ba điều chỉnh từ buổi họp 2026-07-29:
//
//   1. HEADER GIỮ NGUYÊN KHI CUỘN. "Cái này nó có thể đẩy lên được nhưng mà cái
//      header nó bị mất, cho nên là có cách nào khi mà mình chỉnh á nó chỉ đẩy
//      cái nội dung lên thôi và nó giữ lại cái header." → `SliverAppBar` ghim,
//      tiêu đề bài thu nhỏ lại và ở lại trên đỉnh suốt lúc đọc.
//
//   2. CHỮ GIÃN RA. "Chị đọc chị bị tức mắt, nhìn cảm giác như nó nhiều chữ."
//      → cỡ chữ và giãn dòng tăng, khoảng cách giữa các đoạn rộng hơn, và mỗi
//      đoạn được ngắt bằng một dấu nhỏ để mắt có chỗ nghỉ.
//
//   3. NGHE ĐƯỢC THẬT. Bản trước chỉ vẽ một nút play không kêu. Giờ có bản thu
//      thì phát bằng just_audio; chưa có thì dựng bằng giọng đọc AI (AusyncLab)
//      ngay tại chỗ.
//
// ⚠ §XII.3: màn này KHÔNG hiển thị `script` (kịch bản lồng tiếng). Trường đó
//   không tồn tại trong [MoodContent] vì repository đọc qua view
//   `wr_mood_content_public`. Đây là chủ đích, không phải thiếu sót.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/data/ausynclab_tts_service.dart';
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../mood_content_providers.dart';
import 'wr_mood_library_screen.dart' show WrDraftBadge;

class WrMoodReaderScreen extends ConsumerWidget {
  const WrMoodReaderScreen({super.key, required this.contentId});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(wrMoodLibraryProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _ReaderMissing(),
          data: (grouped) {
            final item = grouped.values
                .expand((items) => items)
                .where((c) => c.id == contentId)
                .firstOrNull;
            if (item == null) return const _ReaderMissing();
            return _ReaderBody(item: item);
          },
        ),
      ),
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({required this.item});

  final MoodContent item;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Header ghim ────────────────────────────────────────────────
        //
        // `pinned: true` là điểm mấu chốt của yêu cầu: cuộn bao xa thì thanh
        // này vẫn ở đó. `FlexibleSpaceBar` co tiêu đề lớn thành tiêu đề nhỏ
        // theo độ cuộn, nên người đọc luôn biết mình đang ở bài nào.
        SliverAppBar(
          key: const Key('wr_mood_reader_header'),
          pinned: true,
          expandedHeight: 148,
          backgroundColor: WrColors.pageBg,
          surfaceTintColor: WrColors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          leading: IconButton(
            key: const Key('wr_mood_reader_back'),
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: WrColors.navy,
            onPressed: () => context.pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.fromLTRB(56, 0, 24, 14),
            title: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 48),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Icon(
                    item.type == MoodContentType.audio
                        ? Icons.headphones_outlined
                        : Icons.menu_book_outlined,
                    size: 15,
                    color: WrColors.teal,
                  ),
                  const SizedBox(width: 7),
                  Flexible(child: WrEyebrow('${item.kind} · ${item.duration}')),
                  if (item.placeholder) ...[
                    const SizedBox(width: 8),
                    const WrDraftBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 22),

              // §8.2: nội dung còn nháp thì nói thẳng, đừng để người dùng tưởng
              // đây là bản chính thức rồi thất vọng.
              if (item.placeholder) ...[
                const _DraftNotice(),
                const SizedBox(height: 22),
              ],

              if (item.type == MoodContentType.audio) ...[
                _AudioPlayerBlock(item: item),
                const SizedBox(height: 26),
              ],

              // Chữ giãn hẳn ra so với bản trước (14/1.75 → 16.5/2.0), và mỗi
              // đoạn cách nhau 22px thay vì 14px. Đây là bài để đọc trên điện
              // thoại lúc đang mệt, không phải một khối tài liệu.
              for (final para in item.paragraphs) ...[
                Text(
                  para,
                  style: const TextStyle(
                    fontSize: 16.5,
                    height: 2.0,
                    color: WrColors.dark,
                    letterSpacing: 0.1,
                  ),
                ),
                if (para != item.paragraphs.last) ...[
                  const SizedBox(height: 22),
                  const _ParagraphBreak(),
                  const SizedBox(height: 22),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Dấu ngắt giữa hai đoạn — chỗ nghỉ cho mắt, thay cho một khoảng trắng trơn.
class _ParagraphBreak extends StatelessWidget {
  const _ParagraphBreak();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 26,
        height: 2,
        decoration: BoxDecoration(
          color: WrColors.teal.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(1),
        ),
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Chưa có bản thu thì dựng trước. Chỉ dựng MỘT lần cho mỗi lần mở màn —
      // `_url` giữ lại kết quả, bấm dừng rồi phát lại không gọi TTS nữa.
      final url = _url ??= await ref.read(ttsServiceProvider).synthesize(
            text: widget.item.body,
            name: widget.item.title,
          );

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
      if (mounted) setState(() => _error = 'Không phát được bản thu này.');
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
                      playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 32,
                      color: WrColors.cream,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error ??
                (_busy
                    ? 'Đang dựng bản thu bằng giọng đọc AI…'
                    : _url != null
                        ? widget.item.duration
                        : 'Nghe bằng giọng đọc AI'),
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

class _DraftNotice extends StatelessWidget {
  const _DraftNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_mood_draft_notice'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WrColors.line),
      ),
      child: const Text(
        'Nội dung nháp, chưa thu âm hoặc biên tập chính thức.',
        style: TextStyle(fontSize: 14, color: WrColors.navy, height: 1.6),
      ),
    );
  }
}

class _ReaderMissing extends StatelessWidget {
  const _ReaderMissing();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Không mở được nội dung này.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: WrColors.muted),
        ),
      ),
    );
  }
}
