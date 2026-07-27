// Hiểu mình — Meaning Surface (WXS §8.5).
//
// Hai tầng rất rõ:
//   • GHI NHẬN (miễn phí): bạn đã phản tư bao nhiêu lần, tình huống nào lặp
//     lại mấy lần. Đây là dữ kiện, không phải diễn giải.
//   • DIỄN GIẢI (Premium): vì sao nó lặp lại, điều gì đang hình thành.
//     Chỉ mở khi đã đủ dữ liệu — mặc định 5 lần cùng một tình huống.
//
// Màn này chỉ liệt kê dòng. Bấm vào một dòng mới mở màn chi tiết
// (yêu cầu khách: không xổ toàn bộ nội dung trên một trang).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../wr_providers.dart';

/// Số lần lặp tối thiểu để hệ thống dám đọc ra nguyên nhân sâu.
/// Yêu cầu khách: "người dùng lặp lại một vấn đề 5 lần".
const int kInsightThreshold = 5;

class WrDiscoverScreen extends ConsumerWidget {
  const WrDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patterns = ref.watch(wrPatternCountsProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final selfChecks =
        ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];

    final sitMap = {for (final s in situations) s.code: s.text};
    final reflectionCount = episodes.length;

    return Scaffold(
      backgroundColor: WrColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
          children: [
            const WrTabBackLink(currentTab: WrTab.discover),
            const Text(
              'Hiểu mình',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: WrColors.navy,
                letterSpacing: -0.96,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 28),

            // ── Ghi nhận hành trình ─────────────────────────────────────
            const WrEyebrow('HÀNH TRÌNH ĐÃ ĐI'),
            const SizedBox(height: 14),
            Text(
              reflectionCount == 0
                  ? 'Chưa có lần nhìn lại nào được ghi.'
                  : 'Bạn đã nhìn lại $reflectionCount lần.',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: WrColors.navy,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 32),
            const WrSectionDivider(),
            const SizedBox(height: 24),

            // ── Tình huống lặp lại ──────────────────────────────────────
            const WrEyebrow('ĐIỀU LẶP LẠI'),
            const SizedBox(height: 14),
            if (patterns.isEmpty)
              const Text(
                'Sau vài lần nhìn lại, những điều lặp lại sẽ hiện ra ở đây.',
                style: TextStyle(
                  fontSize: 14,
                  color: WrColors.muted,
                  height: 1.6,
                ),
              )
            else
              ...patterns.take(6).map(
                    (p) => _PatternRow(
                      label: sitMap[p.situationCode] ??
                          p.situationCode ??
                          'Tình huống',
                      count: p.occurrenceCount,
                      onTap: () => context.push(
                        '/wr/pattern/${p.situationCode ?? ''}',
                      ),
                    ),
                  ),

            const SizedBox(height: 32),
            const WrSectionDivider(),
            const SizedBox(height: 24),

            // ── Môi trường làm việc (SCA) ───────────────────────────────
            const WrEyebrow('MÔI TRƯỜNG LÀM VIỆC'),
            const SizedBox(height: 14),
            _LinkRow(
              key: const Key('wr_discover_selfcheck_row'),
              label: selfChecks.isEmpty
                  ? 'Chưa tự đánh giá lần nào'
                  : 'Đã tự đánh giá ${selfChecks.length} lần',
              hint: selfChecks.isEmpty ? 'Bắt đầu' : 'Xem lại',
              onTap: () => context.push('/wr/self-check'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Một dòng tình huống lặp lại — chỉ con số, không diễn giải.
// ---------------------------------------------------------------------------

class _PatternRow extends StatelessWidget {
  const _PatternRow({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: WrColors.navy,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$count lần',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: count >= kInsightThreshold
                    ? WrColors.coral
                    : WrColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: WrColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: WrColors.navy,
                  height: 1.4,
                ),
              ),
            ),
            Text(
              hint,
              style: const TextStyle(fontSize: 14, color: WrColors.muted),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: WrColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tiện ích dùng chung cho màn chi tiết.
// ---------------------------------------------------------------------------

/// Tên hiển thị của một tình huống theo mã.
String situationLabel(List<WrSituation> situations, String? code) {
  if (code == null) return 'Tình huống';
  for (final s in situations) {
    if (s.code == code) return s.text;
  }
  return code;
}

/// Số lần đã gặp một tình huống.
int occurrenceOf(List<PatternCount> patterns, String code) {
  for (final p in patterns) {
    if (p.situationCode == code) return p.occurrenceCount;
  }
  return 0;
}
