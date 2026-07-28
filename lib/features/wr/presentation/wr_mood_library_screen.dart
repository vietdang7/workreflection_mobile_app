// Thư viện Nội dung Cảm xúc — màn danh sách.
// Kiến trúc Dữ liệu Hai Lớp v1.6 §VIII, §8.3.
//
// Mở từ "Xem thêm gợi ý trong thư viện" ở Home. Liệt kê đủ 5 mục mỗi nhóm cảm
// xúc, không chỉ nhóm vừa check-in — người dùng có thể đang tìm một bài đã đọc
// hôm khác, lúc tâm trạng khác.
//
// §8.3: MIỄN PHÍ toàn bộ, không phân lớp Free/Paid. Không có khoá, không có
// paywall trên màn này.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/checkin.dart';
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../mood_content_providers.dart';

/// Thứ tự nhóm cố định, khớp thứ tự bốn ô check-in ở Home.
const List<Mood> kMoodLibraryOrder = [
  Mood.stressed,
  Mood.tired,
  Mood.okay,
  Mood.happy,
];

class WrMoodLibraryScreen extends ConsumerWidget {
  const WrMoodLibraryScreen({super.key});

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
          key: const Key('wr_mood_library_back'),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: WrColors.navy,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _LibraryEmpty(),
          data: (grouped) {
            if (grouped.isEmpty) return const _LibraryEmpty();
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              children: [
                const WrEyebrow('THƯ VIỆN'),
                const SizedBox(height: 14),
                const Text(
                  'Gợi ý theo cảm xúc',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 24),
                for (final mood in kMoodLibraryOrder)
                  if ((grouped[mood] ?? const []).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 6),
                      child: Text(
                        moodLabel(mood),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: WrColors.navy,
                        ),
                      ),
                    ),
                    for (final item in grouped[mood]!)
                      WrMoodContentRow(item: item),
                    const SizedBox(height: 20),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Một dòng trong thư viện. Dùng lại được ở Home nên tách ra public.
class WrMoodContentRow extends StatelessWidget {
  const WrMoodContentRow({super.key, required this.item});

  final MoodContent item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('wr_mood_row_${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/wr/mood-content/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: WrColors.cream,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                item.type == MoodContentType.audio
                    ? Icons.mic_none_outlined
                    : Icons.menu_book_outlined,
                size: 20,
                color: WrColors.navy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: WrColors.navy,
                          ),
                        ),
                      ),
                      if (item.placeholder) ...[
                        const SizedBox(width: 6),
                        const WrDraftBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.kind} · ${item.duration}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: WrColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: WrColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Nhãn "Nháp" cho nội dung chưa thu âm hoặc biên tập chính thức.
///
/// §8.2 + §XII.3: nội dung còn `placeholder = true` chưa sẵn sàng phát hành.
/// Hiện nhãn để người dùng biết đây là bản demo luồng, không phải nội dung thật.
class WrDraftBadge extends StatelessWidget {
  const WrDraftBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: WrColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Text(
        'Nháp',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: WrColors.navy,
        ),
      ),
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty();

  @override
  Widget build(BuildContext context) {
    // WXS Orch. Inv.5: im lặng là lựa chọn hợp lệ, không bịa nội dung mẫu.
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Chưa có nội dung nào trong thư viện.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: WrColors.muted),
        ),
      ),
    );
  }
}
