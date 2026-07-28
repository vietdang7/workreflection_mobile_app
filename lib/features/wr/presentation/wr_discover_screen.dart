// Hiểu mình — Meaning Surface (WXS §8.5).
//
// Bố cục lấy theo giao-dien-chinh.html §screen-understand:
//   Điều bạn đang tìm kiếm → Tình huống lặp lại (có thanh so sánh) →
//   Trải nghiệm hiện tại (SCA) → Hành trình đã đi.
//
// Hai tầng vẫn giữ nguyên như trước:
//   • GHI NHẬN (miễn phí): bạn đã phản tư bao nhiêu lần, tình huống nào lặp
//     lại mấy lần, nhu cầu nào đang nổi lên. Đây là dữ kiện đếm được.
//   • DIỄN GIẢI (Premium): vì sao nó lặp lại, điều gì đang hình thành —
//     nằm ở màn chi tiết, mở khi đã đủ 5 lần cùng một tình huống.
//
// Màn này chỉ liệt kê. Bấm vào một dòng mới mở màn chi tiết
// (yêu cầu khách: không xổ toàn bộ nội dung trên một trang).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_dominant_need.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_content.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/tab_back_link.dart';
import '../../../core/widgets/wr_profile_avatar.dart';
import '../../../core/widgets/wr_card.dart';
import '../wr_providers.dart';

/// Số lần lặp tối thiểu để hệ thống dám đọc ra nguyên nhân sâu.
/// Yêu cầu khách: "người dùng lặp lại một vấn đề 5 lần".
const int kInsightThreshold = 5;

/// Dưới ngưỡng này thanh so sánh mờ đi — mới một lần thì chưa thành nếp.
const int kPatternFaintThreshold = 2;

// ---------------------------------------------------------------------------
// Trạng thái một trụ SCA, suy từ điểm tự đánh giá gần nhất (thang 1–5).
// Ngưỡng giữ đúng như màn Tự đánh giá để hai nơi không nói khác nhau.
// ---------------------------------------------------------------------------

/// null = chưa từng tự đánh giá trụ này.
String pillarStatusLabel(double? score) {
  if (score == null || score <= 0) return 'Chưa đánh giá';
  if (score >= 3.8) return 'Đang phát triển';
  if (score >= 2.5) return 'Cần chú ý';
  return 'Ưu tiên cải thiện';
}

Color pillarStatusColor(double? score) {
  if (score == null || score <= 0) return WrColors.muted;
  return score >= 3.8 ? WrColors.teal : WrColors.coral;
}

/// Màu nhận diện của từng trụ — trùng với màn Tự đánh giá.
Color pillarColor(SelfCheckPillar pillar) => switch (pillar) {
      SelfCheckPillar.s => const Color(0xFF5B8CC9),
      SelfCheckPillar.c => WrColors.teal,
      SelfCheckPillar.a => const Color(0xFF5E7A5A),
    };

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
    final need = dominantNeedFromBehaviour(patterns, situations);
    final latestCheck = selfChecks.isEmpty ? null : selfChecks.first;

    // Thanh so sánh lấy tình huống lặp nhiều nhất làm mốc — người dùng thấy
    // ngay điều nào đang lớn hơn điều nào.
    final top = patterns.take(6).toList();
    final maxCount = top.fold<int>(1, (m, p) => p.occurrenceCount > m ? p.occurrenceCount : m);

    return Scaffold(
      backgroundColor: WrColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
          children: [
            const WrTabBackLink(currentTab: WrTab.discover),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Career Snapshot',
                        style: TextStyle(fontSize: 14, color: WrColors.muted),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hiểu mình',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: WrColors.navy,
                          letterSpacing: -0.96,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                // v1.6 §9.1: "Tôi" là avatar ở mọi màn tab, không còn tab riêng.
                const WrProfileAvatar(),
              ],
            ),

            // ── Điều bạn đang tìm kiếm ──────────────────────────────────
            // Chưa đủ tình huống lặp lại thì chưa có nhu cầu nào nổi lên —
            // im lặng, không đoán bừa (WXS Orch. Inv.5).
            if (need != null) ...[
              const SizedBox(height: 24),
              _SeekingBlock(need: need),
            ],

            const SizedBox(height: 28),
            const WrSectionDivider(),
            const SizedBox(height: 24),

            // ── Tình huống lặp lại ──────────────────────────────────────
            const WrEyebrow('TÌNH HUỐNG LẶP LẠI'),
            const SizedBox(height: 16),
            if (top.isEmpty)
              const Text(
                'Sau vài lần nhìn lại, những điều lặp lại sẽ hiện ra ở đây.',
                style: TextStyle(
                  fontSize: 14,
                  color: WrColors.muted,
                  height: 1.6,
                ),
              )
            else
              for (final p in top) ...[
                _PatternRow(
                  label: sitMap[p.situationCode] ??
                      p.situationCode ??
                      'Tình huống',
                  count: p.occurrenceCount,
                  ratio: p.occurrenceCount / maxCount,
                  onTap: () => context.push(
                    '/wr/pattern/${p.situationCode ?? ''}',
                  ),
                ),
                if (p != top.last) const SizedBox(height: 18),
              ],

            const SizedBox(height: 28),
            const WrSectionDivider(),
            const SizedBox(height: 24),

            // ── Trải nghiệm hiện tại (SCA) ──────────────────────────────
            _ScaCard(
              key: const Key('wr_discover_selfcheck_row'),
              latest: latestCheck,
              takenCount: selfChecks.length,
              onTap: () => context.push('/wr/self-check'),
            ),

            const SizedBox(height: 28),

            // ── Hành trình đã đi ────────────────────────────────────────
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
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Điều bạn đang tìm kiếm" — canh giữa, chữ nghiêng lớn như giao diện mẫu.
// ---------------------------------------------------------------------------

class _SeekingBlock extends StatelessWidget {
  const _SeekingBlock({required this.need});

  final HumanNeed need;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('wr_discover_seeking'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WrEyebrow('ĐIỀU BẠN ĐANG TÌM KIẾM', center: true),
          const SizedBox(height: 16),
          Text(
            '"${needSeekingSentence(need)}"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: WrColors.navy,
              height: 1.35,
              letterSpacing: -0.52,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${needLabel(need).toUpperCase()} · Nhu cầu chủ đạo',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: WrColors.muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Một dòng tình huống lặp lại — số lần + thanh so sánh, không diễn giải.
// ---------------------------------------------------------------------------

class _PatternRow extends StatelessWidget {
  const _PatternRow({
    required this.label,
    required this.count,
    required this.ratio,
    required this.onTap,
  });

  final String label;
  final int count;
  final double ratio;
  final VoidCallback onTap;

  bool get _isStrong => count >= kInsightThreshold;
  bool get _isFaint => count < kPatternFaintThreshold;

  @override
  Widget build(BuildContext context) {
    final barColor = _isStrong
        ? WrColors.coral
        : WrColors.navy.withValues(alpha: _isFaint ? 0.4 : 1);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                    fontSize: 13,
                    fontWeight: _isStrong ? FontWeight.w700 : FontWeight.w600,
                    color: _isStrong
                        ? WrColors.coral
                        : (_isFaint ? WrColors.muted : WrColors.teal),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 11,
                  color: WrColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            WrProgressTrack(value: ratio, color: barColor),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thẻ "Trải nghiệm hiện tại (SCA)" — ba trụ, đọc từ lần tự đánh giá gần nhất.
// ---------------------------------------------------------------------------

class _ScaCard extends StatelessWidget {
  const _ScaCard({
    super.key,
    required this.latest,
    required this.takenCount,
    required this.onTap,
  });

  final ScaSelfCheckResponse? latest;
  final int takenCount;
  final VoidCallback onTap;

  double? _scoreOf(SelfCheckPillar pillar) => switch (pillar) {
        SelfCheckPillar.s => latest?.structureScore,
        SelfCheckPillar.c => latest?.cultureScore,
        SelfCheckPillar.a => latest?.activityScore,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: WrCardMinimal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WrEyebrow('TRẢI NGHIỆM HIỆN TẠI'),
            const SizedBox(height: 6),
            for (final pillar in SelfCheckPillar.values)
              _ScaRow(pillar: pillar, score: _scoreOf(pillar)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  takenCount == 0
                      ? 'Chưa tự đánh giá lần nào'
                      : 'Đã tự đánh giá $takenCount lần',
                  style: const TextStyle(fontSize: 13, color: WrColors.muted),
                ),
                const Spacer(),
                Text(
                  takenCount == 0 ? 'Bắt đầu' : 'Xem lại',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WrColors.coral,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 14, color: WrColors.coral),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaRow extends StatelessWidget {
  const _ScaRow({required this.pillar, required this.score});

  final SelfCheckPillar pillar;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final color = pillarColor(pillar);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Text(
              pillar.name.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pillar.displayName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: WrColors.navy,
              ),
            ),
          ),
          Text(
            pillarStatusLabel(score),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: pillarStatusColor(score),
            ),
          ),
        ],
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
