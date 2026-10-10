// Thư viện học tập — video, tài liệu online của web, xem ngay trong app.
//
//   /wr/learning-library        danh sách, mỗi tài liệu một thẻ có ảnh bìa
//   /wr/learning-library/:id    một video: trình phát YouTube + mô tả
//
// Lối vào: thẻ ngay dưới Trà Chiều ở tab Phát triển. Bối cảnh và các quyết định
// của khách nằm ở `wr_learning_resource.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/data/wr_learning_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/models/wr_learning_resource.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../../../core/widgets/wr_link_row.dart';

/// Nhãn chương trình — dùng chung cho thẻ ở tab Phát triển và màn danh sách.
String get kLearningLibraryLabel => tr('Thư viện học tập', 'Learning library');

/// Câu giới thiệu — nguyên văn trang Thư viện học tập của web.
String get kLearningLibraryIntro => tr(
  'Video, tài liệu online để bạn tự học mọi lúc mọi nơi',
  'Videos and online materials to learn at your own pace, anywhere',
);

/// Mở một tài liệu: video YouTube thì phát trong app, còn lại mở link ngoài.
void openLearningResource(BuildContext context, LearningResource resource) {
  if (resource.youtubeId != null) {
    context.push('/wr/learning-library/${resource.id}');
    return;
  }
  final url = resource.url;
  if (url != null) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

// ---------------------------------------------------------------------------

class WrLearningLibraryScreen extends ConsumerWidget {
  const WrLearningLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wrLearningResourcesProvider);

    return WrDetailScaffold(
      art: WrHeroArt.act,
      eyebrow: tr('HỌC MỌI LÚC', 'LEARN ANYTIME'),
      title: kLearningLibraryLabel,
      children: [
        Text(
          kLearningLibraryIntro,
          style: TextStyle(fontSize: 15.5, color: WrColors.muted, height: 1.6),
        ),
        const SizedBox(height: 22),
        ...async.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, _) => [
            _Notice(
              key: const Key('wr_learning_library_error'),
              text: tr(
                'Chưa tải được thư viện. Kiểm tra kết nối rồi thử lại.',
                'Could not load the library. Check your connection and try again.',
              ),
              action: tr('Thử lại', 'Try again'),
              onAction: () => ref.invalidate(wrLearningResourcesProvider),
            ),
          ],
          data: (items) => items.isEmpty
              ? [
                  _Notice(
                    key: const Key('wr_learning_library_empty'),
                    text: tr(
                      'Thư viện chưa có tài liệu nào.',
                      'The library has no materials yet.',
                    ),
                  ),
                ]
              : [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: WrCard.kGap),
                      child: _ResourceCard(resource: item),
                    ),
                ],
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 15.5, color: WrColors.dark, height: 1.6),
          ),
          if (action != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

/// Tông màu của một tài liệu, chọn theo danh mục.
///
/// Ba tông của thương hiệu, xoay vòng theo tên danh mục: cùng danh mục thì
/// cùng màu ở mọi lần mở, khác danh mục thì danh sách có nhịp màu thay vì một
/// cột thẻ trắng giống hệt nhau.
typedef LearningTone = ({
  Color tile,
  Color markBg,
  Color markIcon,
  Color onTile,
  Color chipBg,
  Color chipFg,
});

LearningTone learningTone(String? category) {
  final key = (category ?? '').trim().toLowerCase();
  final index = key.isEmpty ? 0 : key.codeUnits.fold(0, (a, c) => a + c) % 3;
  return switch (index) {
    0 => (
      tile: WrColors.navy,
      markBg: WrColors.coral,
      markIcon: WrColors.navy,
      onTile: WrColors.white,
      chipBg: WrColors.navy.withValues(alpha: 0.08),
      chipFg: WrColors.navy,
    ),
    1 => (
      tile: WrColors.teal,
      markBg: WrColors.white,
      markIcon: WrColors.navy,
      onTile: WrColors.navy,
      chipBg: WrColors.teal.withValues(alpha: 0.14),
      chipFg: const Color(0xFF0B7A76),
    ),
    _ => (
      tile: WrColors.coral,
      markBg: WrColors.navy,
      markIcon: WrColors.white,
      onTile: WrColors.navy,
      chipBg: WrColors.coral.withValues(alpha: 0.14),
      chipFg: const Color(0xFFB8402F),
    ),
  };
}

/// Một tài liệu trong danh sách.
///
/// Người dùng 10/10 qua ba vòng: bỏ ảnh bìa ("mất công canh ảnh khi upload"),
/// bỏ mô tả dài ("nhiều chữ, khó đọc"), rồi bản chỉ-tiêu-đề lại "cơ bản quá" —
/// muốn có màu và thông tin kèm cho rõ. Nên: một ô màu bên trái (dấu phát +
/// thời lượng) thay chỗ ảnh, bên phải là nhãn danh mục, tiêu đề, và MỘT hàng
/// thông tin ngắn có biểu tượng. Mô tả vẫn chỉ ở màn xem video.
class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource});

  final LearningResource resource;

  @override
  Widget build(BuildContext context) {
    final tone = learningTone(resource.category);
    final added = resource.createdAt?.toLocal();

    return WrCard(
      key: Key('wr_learning_resource_${resource.id}'),
      padding: EdgeInsets.zero,
      onTap: () => openLearningResource(context, resource),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Ô màu: dấu phát + thời lượng ──────────────────────────────
            Container(
              width: 78,
              color: tone.tile,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tone.markBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      resource.isVideo
                          ? Icons.play_arrow_rounded
                          : Icons.menu_book_rounded,
                      size: resource.isVideo ? 26 : 20,
                      color: tone.markIcon,
                    ),
                  ),
                  if (resource.durationLabel != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      resource.durationLabel!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: tone.onTile,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // ── Chữ ────────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (resource.category != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tone.chipBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          resource.category!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: tone.chipFg,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    Text(
                      resource.title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.38,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _MetaItem(
                          icon: resource.isVideo
                              ? Icons.smart_display_outlined
                              : Icons.description_outlined,
                          label: resource.kindLabel,
                        ),
                        if (added != null)
                          _MetaItem(
                            key: const Key('wr_learning_added'),
                            icon: Icons.event_outlined,
                            label: tr(
                              'Đăng ${added.day}/${added.month}/${added.year}',
                              'Added ${added.day}/${added.month}/${added.year}',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: WrColors.muted),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: WrColors.muted)),
      ],
    );
  }
}

/// Dấu tròn coral thay cho ảnh bìa: nút phát cho video, mũi tên ra ngoài cho
/// tài liệu khác. Nút coral chữ navy — quy ước nút chính của app.
class LearningPlayMark extends StatelessWidget {
  const LearningPlayMark({super.key, required this.resource, this.size = 44});

  final LearningResource resource;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: WrColors.coral,
        shape: BoxShape.circle,
      ),
      child: Icon(
        resource.isVideo ? Icons.play_arrow_rounded : Icons.open_in_new,
        size: resource.isVideo ? size * 0.6 : size * 0.45,
        color: WrColors.navy,
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: WrColors.teal.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: WrColors.navy,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class WrLearningVideoScreen extends ConsumerWidget {
  const WrLearningVideoScreen({super.key, required this.resourceId});

  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wrLearningResourceProvider(resourceId));
    final resource = async.valueOrNull;

    if (resource == null || resource.youtubeId == null) {
      return WrDetailScaffold(
        art: WrHeroArt.act,
        eyebrow: kLearningLibraryLabel.toUpperCase(),
        title: async.isLoading
            ? ''
            : tr('Không tìm thấy video', 'Video not found'),
        children: [
          if (async.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Text(
              tr(
                'Video này có thể đã được gỡ khỏi thư viện.',
                'This video may have been removed from the library.',
              ),
              style: TextStyle(
                fontSize: 15.5,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
        ],
      );
    }

    return WrDetailScaffold(
      art: WrHeroArt.act,
      eyebrow: [
        kLearningLibraryLabel.toUpperCase(),
        ?resource.durationLabel?.toUpperCase(),
      ].join(' · '),
      title: resource.title,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(WrCard.kRadius),
          child: _YoutubeView(videoId: resource.youtubeId!),
        ),
        if (resource.category != null) ...[
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: _CategoryPill(resource.category!),
          ),
        ],
        if (resource.description != null) ...[
          const SizedBox(height: 14),
          Text(
            resource.description!,
            style: TextStyle(
              fontSize: 15.5,
              color: WrColors.dark,
              height: 1.75,
            ),
          ),
        ],
      ],
    );
  }
}

/// Trình phát YouTube nhúng (iFrame API qua WebView). Chưa tự phát: người dùng
/// bấm nút phát của YouTube, tránh bật tiếng đột ngột khi vừa mở màn.
class _YoutubeView extends StatefulWidget {
  const _YoutubeView({required this.videoId});

  final String videoId;

  @override
  State<_YoutubeView> createState() => _YoutubeViewState();
}

class _YoutubeViewState extends State<_YoutubeView> {
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: false,
        params: YoutubePlayerParams(
          showFullscreenButton: true,
          strictRelatedVideos: true,
          interfaceLanguage: wrEnglish ? 'en' : 'vi',
          captionLanguage: wrEnglish ? 'en' : 'vi',
        ),
      );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      key: const Key('wr_learning_player'),
      controller: _controller,
      aspectRatio: 16 / 9,
      keepAlive: true,
    );
  }
}

// ---------------------------------------------------------------------------
// Khối Thư viện học tập ở tab Phát triển
//
// Người dùng 10/10, hai vòng:
//   1. thẻ trắng một dòng "cơ bản quá, không có ấn tượng gì";
//   2. thẻ lớn dọc (ảnh bìa nửa thẻ + mô tả + nút to) "đẹp mắt hơn nhưng to và
//      chiếm chỗ quá".
//   3. bỏ luôn ảnh bìa: "mất công canh ảnh khi upload lên cho phù hợp".
// Bản này: MỘT thẻ nền kem cao cỡ một dòng chủ đề — dấu phát coral, nhãn,
// tiêu đề. Các tập khác nằm sau "Xem tất cả".
//
// Bấm thẻ là PHÁT LUÔN tập mới nhất. Kem chứ không navy: thẻ Trà Chiều navy
// nằm ngay trên, hai khối navy chồng nhau thì nặng.
// ---------------------------------------------------------------------------

class WrLearningLibrarySection extends StatelessWidget {
  const WrLearningLibrarySection({super.key, required this.items});

  /// Mới nhất trước — đúng thứ tự `fetchActive` trả về. Không được rỗng.
  final List<LearningResource> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(kLearningLibraryLabel, style: WrLinkRow.labelStyle),
            ),
            InkWell(
              key: const Key('wr_learning_see_all'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/wr/learning-library'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      items.length > 1
                          ? tr(
                              'Xem tất cả (${items.length})',
                              'See all (${items.length})',
                            )
                          : tr('Xem tất cả', 'See all'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: WrColors.navy,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: WrColors.navy,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _FeaturedCard(resource: items.first),
      ],
    );
  }
}

/// Màu kem của mockup v55 (`rgba(255,247,238,…)`) — tách thẻ này khỏi các thẻ
/// trắng và thẻ Trà Chiều navy ngay trên.
const Color _kCreamWash = Color(0xFFFFF7EE);

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.resource});

  final LearningResource resource;

  @override
  Widget build(BuildContext context) {
    final isNew =
        resource.createdAt != null &&
        DateTime.now().difference(resource.createdAt!).inDays <= 30;
    final meta = [
      resource.kindLabel.toUpperCase(),
      ?resource.durationLabel?.toUpperCase(),
    ].join(' · ');

    return Material(
      key: const Key('wr_growth_learning_library'),
      color: _kCreamWash,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WrCard.kRadius),
        side: const BorderSide(color: WrColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openLearningResource(context, resource),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              LearningPlayMark(resource: resource, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isNew) ...[
                          _Chip(
                            label: tr('MỚI', 'NEW'),
                            background: WrColors.coral,
                            foreground: WrColors.navy,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            meta,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: WrColors.teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      resource.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: WrColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: foreground,
        ),
      ),
    );
  }
}
