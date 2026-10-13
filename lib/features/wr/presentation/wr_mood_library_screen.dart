// Thư viện Nội dung Cảm xúc — màn danh sách (mockup v47 `screenContentLibrary`).
// Kiến trúc Dữ liệu Hai Lớp v1.6 §VIII, §8.3.
//
// Mở từ "Thư viện →" trên thẻ gợi ý ở Home. Mặc định mở ĐÚNG nhóm của cảm xúc
// vừa check-in (khách chốt 2026-07-29: "hiển thị theo cảm xúc của khách hàng
// chọn thôi chứ không hiển thị hết 1 list"). v47 giữ nguyên ý đó nhưng thêm
// hàng chip để người dùng tự chuyển sang nhóm khác khi muốn, thay vì bày cả
// sáu nhóm nối nhau.
//
// Bố cục: dải phong cảnh theo cảm xúc đang chọn · "Gợi ý cho bạn" · chip cảm xúc
// · Tất cả / Đọc / Nghe + số gợi ý · thẻ "Nên bắt đầu từ đây" (bài đầu nhóm) ·
// các bài còn lại trong một thẻ.
//
// §8.3: MIỄN PHÍ toàn bộ, không phân lớp Free/Paid. Không có khoá, không có
// paywall trên màn này.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/models/checkin.dart';
import '../../../core/models/wr_mood_content.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_back_circle.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../mood_content_providers.dart';
import '../wr_providers.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

/// Thứ tự chip cố định, khớp thứ tự sáu ô check-in ở Home
/// (`kCheckinOptions`). Đọc từ `Mood.values` chứ không liệt kê tay: enum đã
/// khai đúng thứ tự đó.
const List<Mood> kMoodLibraryOrder = Mood.values;

/// Khoảng từ đáy nút quay lại tới khối chữ đầu tiên ở màn Thư viện và màn đọc.
///
/// Mockup: `.backrow` đệm trên 16 + nút 30 + đệm dưới 54, rồi khối chữ cách
/// thêm 18, nên chữ bắt đầu ở 118, ngay dưới dải ảnh cao 112. Nút của app cao
/// 32, nên đệm dưới còn 52 để chữ vẫn bắt đầu ở 118.
const double kWrBandContentGap = 52;

/// Bộ lọc loại nội dung: `.lib-seg` Tất cả / Đọc / Nghe.
enum MoodLibraryFilter {
  all,
  reading,
  audio;

  String get label => switch (this) {
    MoodLibraryFilter.all => tr('Tất cả', 'All'),
    MoodLibraryFilter.reading => tr('Đọc', 'Read'),
    MoodLibraryFilter.audio => tr('Nghe', 'Listen'),
  };

  bool accepts(MoodContent c) => switch (this) {
    MoodLibraryFilter.all => true,
    MoodLibraryFilter.reading => c.type == MoodContentType.reading,
    MoodLibraryFilter.audio => c.type == MoodContentType.audio,
  };
}

/// "Đọc · 2 phút đọc" / "Nghe · 3 phút nghe".
///
/// Nguyên văn mockup Sprint 2 (`meta = (audio ? 'Nghe' : 'Đọc') + ' · ' +
/// c.duration`): giữ nguyên chữ thời lượng, kể cả chữ "đọc"/"nghe" ở đuôi.
String moodContentMeta(MoodContent c) {
  final kind = c.type == MoodContentType.audio
      ? tr('Nghe', 'Listen')
      : tr('Đọc', 'Read');
  return '$kind · ${c.durationLabel}';
}

class WrMoodLibraryScreen extends ConsumerStatefulWidget {
  const WrMoodLibraryScreen({super.key, this.initialMood});

  /// Mở sẵn nhóm này (`/wr/mood-library?mood=stress`). Null thì lấy cảm xúc
  /// check-in hôm nay, chưa check-in thì "Khá ổn" như mockup.
  final Mood? initialMood;

  @override
  ConsumerState<WrMoodLibraryScreen> createState() =>
      _WrMoodLibraryScreenState();
}

class _WrMoodLibraryScreenState extends ConsumerState<WrMoodLibraryScreen> {
  Mood? _picked;
  MoodLibraryFilter _filter = MoodLibraryFilter.all;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(wrMoodLibraryProvider);
    final mood =
        _picked ??
        widget.initialMood ??
        ref.watch(todayCheckinProvider).valueOrNull?.mood ??
        Mood.okay;
    final key = mood.moodContentKey;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: WrReflectBand(mood: key),
          ),
          SafeArea(
            bottom: false,
            child: library.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _LibraryEmpty(onBack: () => context.pop()),
              data: (grouped) {
                if (grouped.isEmpty) {
                  return _LibraryEmpty(onBack: () => context.pop());
                }
                final items = (grouped[mood] ?? const <MoodContent>[])
                    .where(_filter.accepts)
                    .toList();
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    // `.scr-body.rf .backrow { padding: 16px 22px 54px }`:
                    // chỉ nút quay lại nằm trên dải ảnh, chữ bắt đầu dưới dải.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        22,
                        16,
                        22,
                        kWrBandContentGap,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: WrBackCircle(
                          key: const Key('wr_mood_library_back'),
                          onTap: () => context.pop(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WrEyebrow(tr('THƯ VIỆN', 'LIBRARY')),
                          const SizedBox(height: 6),
                          Text(
                            wrKeepCompounds(tr('Gợi ý cho bạn', 'Ideas for you')),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: WrColors.navy,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            wrKeepCompounds(tr(
                              'Chọn theo cảm xúc. Mỗi bài chỉ vài phút.',
                              'Pick by feeling. Each one takes a few minutes.',
                            )),
                            style: const TextStyle(
                              fontSize: 14,
                              color: WrColors.text2,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _MoodChips(
                      selected: mood,
                      onPick: (m) => setState(() => _picked = m),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                      child: Row(
                        children: [
                          _FilterSegment(
                            value: _filter,
                            onPick: (f) => setState(() => _filter = f),
                          ),
                          const Spacer(),
                          Text(
                            wrKeepCompounds(tr(
                              '${items.length} gợi ý',
                              '${items.length} '
                                  '${items.length == 1 ? 'idea' : 'ideas'}',
                            )),
                            key: const Key('wr_mood_library_count'),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: WrColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: items.isEmpty
                          ? Padding(
                              key: const Key('wr_mood_library_none'),
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                wrKeepCompounds(tr(
                                  'Chưa có gợi ý loại này cho cảm xúc đang chọn.',
                                  'No ideas of this kind for this feeling yet.',
                                )),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: WrColors.text2,
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FeaturedCard(item: items.first, mood: key),
                                if (items.length > 1) ...[
                                  const SizedBox(height: 12),
                                  WrCard(
                                    padding: EdgeInsets.zero,
                                    child: Column(
                                      children: [
                                        for (
                                          var k = 1;
                                          k < items.length;
                                          k++
                                        ) ...[
                                          if (k > 1)
                                            const Divider(
                                              height: 1,
                                              thickness: 1,
                                              color: WrColors.line,
                                            ),
                                          WrMoodContentRow(item: items[k]),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Mở một bài từ Thư viện. `from=library` để nút "Xong, đọc bài khác" ở màn
/// đọc chỉ cần lùi về đây.
void openMoodContent(BuildContext context, MoodContent item) =>
    context.push('/wr/mood-content/${item.id}?from=library');

/// `.lib-chips`: sáu chip cảm xúc cuộn ngang, chip đang chọn tô navy.
class _MoodChips extends StatelessWidget {
  const _MoodChips({required this.selected, required this.onPick});

  final Mood selected;
  final ValueChanged<Mood> onPick;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          for (final m in kMoodLibraryOrder) ...[
            if (m != kMoodLibraryOrder.first) const SizedBox(width: 6),
            _MoodChip(mood: m, on: m == selected, onTap: () => onPick(m)),
          ],
        ],
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.mood, required this.on, required this.onTap});

  final Mood mood;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('wr_mood_chip_${mood.moodContentKey}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? WrColors.navy : WrColors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on ? WrColors.navy : WrColors.navy.withValues(alpha: 0.14),
          ),
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
              wrKeepCompounds(moodLabel(mood)),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: on ? WrColors.cream : WrColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.lib-seg`: Tất cả / Đọc / Nghe.
class _FilterSegment extends StatelessWidget {
  const _FilterSegment({required this.value, required this.onPick});

  final MoodLibraryFilter value;
  final ValueChanged<MoodLibraryFilter> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: WrColors.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in MoodLibraryFilter.values)
            GestureDetector(
              key: Key('wr_mood_filter_${f.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(f),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: f == value
                    ? BoxDecoration(
                        color: WrColors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: WrColors.navy.withValues(alpha: 0.12),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      )
                    : null,
                child: Text(
                  wrKeepCompounds(f.label),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: f == value ? WrColors.navy : WrColors.text2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `.lib-feat` — "Nên bắt đầu từ đây": bài đầu tiên của nhóm.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item, required this.mood});

  final MoodContent item;
  final String mood;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('wr_mood_featured_${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => openMoodContent(context, item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WrColors.navy.withValues(alpha: 0.08)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [WrMoodPalette.of(mood)[0], WrColors.white],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WrEyebrow(tr('NÊN BẮT ĐẦU TỪ ĐÂY', 'START HERE')),
            const SizedBox(height: 6),
            // `.serif` 16, đậm thường như mockup.
            Text(
              wrKeepCompounds(item.title),
              style: const TextStyle(
                fontFamily: WrText.serifFamily,
                fontSize: 16,
                color: WrColors.navy,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    wrKeepCompounds(moodContentMeta(item)),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WrColors.text2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: WrColors.coral,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: WrColors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Một dòng trong danh sách "các bài còn lại" của Thư viện.
class WrMoodContentRow extends StatelessWidget {
  const WrMoodContentRow({super.key, required this.item});

  final MoodContent item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('wr_mood_row_${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => openMoodContent(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: WrColors.navy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                item.type == MoodContentType.audio
                    ? Icons.mic_none_outlined
                    : Icons.menu_book_outlined,
                size: 19,
                color: WrColors.navy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wrKeepCompounds(item.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: WrColors.navy,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    wrKeepCompounds(moodContentMeta(item)),
                    style: const TextStyle(fontSize: 12, color: WrColors.text2),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: WrColors.text3),
          ],
        ),
      ),
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // WXS Orch. Inv.5: im lặng là lựa chọn hợp lệ, không bịa nội dung mẫu.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: WrBackCircle(
            key: const Key('wr_mood_library_back'),
            onTap: onBack,
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                wrKeepCompounds(tr(
                  'Chưa có nội dung nào trong thư viện.',
                  'Nothing in the library yet.',
                )),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: WrColors.muted),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
