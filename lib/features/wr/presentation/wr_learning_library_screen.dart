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

/// Một tài liệu: ảnh bìa, nhãn, tiêu đề, hai dòng mô tả, thời lượng.
class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource});

  final LearningResource resource;

  @override
  Widget build(BuildContext context) {
    final meta = [resource.kindLabel, ?resource.durationLabel].join(' · ');

    return WrCard(
      key: Key('wr_learning_resource_${resource.id}'),
      padding: EdgeInsets.zero,
      onTap: () => openLearningResource(context, resource),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearningCover(resource: resource),
          Padding(
            padding: WrCard.kPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (resource.category != null) ...[
                  _CategoryPill(resource.category!),
                  const SizedBox(height: 8),
                ],
                Text(
                  resource.title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: WrColors.navy,
                    height: 1.4,
                  ),
                ),
                if (resource.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    resource.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: WrColors.muted,
                      height: 1.55,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      resource.isVideo
                          ? Icons.play_circle_outline
                          : Icons.open_in_new,
                      size: 16,
                      color: WrColors.coral,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        meta,
                        style: TextStyle(fontSize: 13.5, color: WrColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ảnh bìa 16:9. Không có ảnh hoặc tải hỏng thì ra một ô navy nhạt có nút phát,
/// để thẻ không co lại thành một khoảng trống.
class LearningCover extends StatelessWidget {
  const LearningCover({super.key, required this.resource});

  final LearningResource resource;

  @override
  Widget build(BuildContext context) {
    final cover = resource.coverUrl;
    final placeholder = ColoredBox(
      color: WrColors.navy.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          resource.isVideo ? Icons.play_circle_outline : Icons.menu_book,
          size: 40,
          color: WrColors.navy.withValues(alpha: 0.5),
        ),
      ),
    );

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover == null)
            placeholder
          else
            Image.network(
              cover,
              key: const Key('wr_learning_cover'),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
            ),
          if (cover != null && resource.isVideo)
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: WrColors.navy.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 32,
                  color: WrColors.white,
                ),
              ),
            ),
        ],
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
