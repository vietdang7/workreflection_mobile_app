// Thư viện Nội dung Cảm xúc — màn đọc / nghe.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §8.1, §8.2.
//
// §8.1: `type` quyết định giao diện — audio có thêm khối trình phát phía trên
// phần chữ. BÀI ĐỌC hiện toàn văn; HEALING AUDIO hiện mô tả ngắn dưới khối phát.
//
// ⚠ §XII.3: màn này KHÔNG hiển thị `script` (kịch bản lồng tiếng). Trường đó
//   không tồn tại trong [MoodContent] vì repository đọc qua view
//   `wr_mood_content_public`. Đây là chủ đích, không phải thiếu sót.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        surfaceTintColor: WrColors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('wr_mood_reader_back'),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: WrColors.navy,
          onPressed: () => context.pop(),
        ),
      ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      children: [
        Row(
          children: [
            Flexible(child: WrEyebrow('${item.kind} · ${item.duration}')),
            if (item.placeholder) ...[
              const SizedBox(width: 8),
              const WrDraftBadge(),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text(
          item.title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
            height: 1.3,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),

        // §8.2: nội dung còn nháp thì nói thẳng, đừng để người dùng tưởng đây
        // là bản chính thức rồi thất vọng.
        if (item.placeholder) ...[
          const _DraftNotice(),
          const SizedBox(height: 20),
        ],

        if (item.type == MoodContentType.audio) ...[
          const _AudioPlayerBlock(),
          const SizedBox(height: 20),
        ],

        for (final para in item.paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              para,
              style: const TextStyle(
                fontSize: 14,
                height: 1.75,
                color: WrColors.dark,
              ),
            ),
          ),
      ],
    );
  }
}

/// Khối trình phát cho HEALING AUDIO.
///
/// Chưa nối file thật: §8.2 nói toàn bộ 20 mục đang `placeholder = true`, chưa
/// thu âm. Khối này dựng đúng chỗ và đúng hình để khi có bản ghi thì chỉ cần
/// nối nguồn phát, không phải sửa bố cục.
class _AudioPlayerBlock extends StatelessWidget {
  const _AudioPlayerBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_mood_audio_player'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: WrColors.navy,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: WrColors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 30,
              color: WrColors.cream,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: 0,
              minHeight: 3,
              backgroundColor: WrColors.white.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(
                WrColors.cream.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Bản thu đang được chuẩn bị',
            style: TextStyle(
              fontSize: 11,
              color: WrColors.cream.withValues(alpha: 0.6),
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
        color: WrColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Nội dung nháp, chưa thu âm hoặc biên tập chính thức.',
        style: TextStyle(fontSize: 12, color: WrColors.navy, height: 1.5),
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
          style: TextStyle(fontSize: 13.5, color: WrColors.muted),
        ),
      ),
    );
  }
}
