// Hiểu mình — Meaning Surface (WXS §8.5).
//
// Bố cục lấy theo giao-dien-chinh.html §screen-understand:
//   Điều bạn đang tìm kiếm → Tình huống lặp lại (có thanh so sánh) →
//   Trải nghiệm hiện tại → Hành trình đã đi.
//
// Nhãn cố tình không kèm chữ "SCA" (v1.6 §XII.5: thuật ngữ nội bộ không phơi
// ra người dùng), dù bên dưới vẫn là ba trụ SCA.
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
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_career_health.dart';
import '../../../core/logic/wr_repeated_situations.dart';
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
import '../../../core/widgets/wr_premium_lock.dart';
import '../wr_providers.dart';
import '../../../core/widgets/wr_paragraph.dart';

/// Số lần lặp tối thiểu để hệ thống dám đọc ra nguyên nhân sâu.
/// Yêu cầu khách: "người dùng lặp lại một vấn đề 5 lần".
const int kInsightThreshold = 5;

/// Dưới ngưỡng này thanh so sánh mờ đi — vừa chớm thành nếp thì chưa tô đậm.
///
/// Buộc vào [kRepeatedSituationsMinCount]: bậc thấp nhất còn được hiện là bậc
/// mờ. Để nguyên số 2 như trước thì mọi dòng lọt qua ngưỡng đều đậm và trạng
/// thái mờ thành nhánh chết.
const int kPatternFaintThreshold = kRepeatedSituationsMinCount + 1;

/// Số tình huống hiện thẳng ở tab Hiểu mình.
///
/// Ba, không phải sáu: màn này là tấm gương chứ không phải bảng số liệu, và
/// một danh sách dài thì không ai đọc hết. Phần còn lại nằm sau "Xem thêm",
/// mở ra màn riêng — không xổ tất cả trên một trang.
const int kDiscoverPatternPreview = 3;

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
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final selfChecks =
        ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];
    // Nội dung của khối "Điều bạn đang tìm kiếm" đọc từ đây (aha_message trùng
    // mã chip theo v2.0 §2.2) khi tình huống không có expected_outcome riêng.
    final stories = ref.watch(wrStoriesProvider).valueOrNull ?? const [];

    // Nguồn sự thật duy nhất của cả màn này (Kiến trúc v2.0 §4.3). Không còn
    // đọc `wr_pattern_counts` ở đâu trên màn Hiểu mình.
    final recent = recentSituationIds(episodes);

    final sitMap = {for (final s in situations) s.code: s.text};
    final reflectionCount = episodes.length;
    final need = dominantNeedFromBehaviour(recent, situations);
    final latestCheck = selfChecks.isEmpty ? null : selfChecks.first;

    // Hướng 1 — đủ 15 LẦN nhìn lại thì bức tranh tổng thể mở ra, và ba trụ đọc
    // được từ chính hành vi mà không cần bộ Self-Check. Chưa từng tự đánh giá
    // mới dùng đường này: có điểm tự đánh giá thì điểm đó chính xác hơn.
    //
    // Dùng thẳng `reflectionCount` — cùng một biến với câu "Bạn đã nhìn lại N
    // lần" ở cuối màn, nên hai chỗ không thể nói hai con số khác nhau.
    final behaviourShares =
        latestCheck == null && careerHealthUnlocked(reflectionCount)
            ? pillarShares(recent, situations)
            : null;

    // "Tình huống lặp lại" — v2.0 §4.3: đếm số lần xuất hiện của từng
    // situationId trong recentSituationIds, lấy ba tình huống nhiều nhất.
    // Phần còn lại nằm sau "Xem thêm".
    //
    // Yêu cầu khách 2026-07-31: chỉ những điều đã trở lại từ
    // kRepeatedSituationsMinCount lần mới được gọi là đang lặp. Lọc TRƯỚC khi
    // cắt ba dòng, nếu không "Xem thêm N" sẽ hứa một con số mà màn đầy đủ
    // không có.
    final repeated =
        rankSituations(recent, minCount: kRepeatedSituationsMinCount);
    final top = repeated.take(kRepeatedSituationsTop).toList();
    final hidden = repeated.length - top.length;

    // Thanh so sánh lấy tình huống lặp nhiều nhất làm mốc — người dùng thấy
    // ngay điều nào đang lớn hơn điều nào. Mốc tính trên TOÀN BỘ danh sách để
    // ba thanh ở đây và danh sách đầy đủ đo cùng một thước.
    final maxCount =
        repeated.fold<int>(1, (m, p) => p.count > m ? p.count : m);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
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
                        style: TextStyle(fontSize: 15.5, color: WrColors.muted),
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
              _NeedReadingBlock(
                need: need,
                insight: seekingInsight(
                  recent: recent,
                  situations: situations,
                  stories: stories,
                ),
              ),
            ],

            const SizedBox(height: 28),
            const WrSectionDivider(),
            const SizedBox(height: 24),

            // ── Tình huống lặp lại ──────────────────────────────────────
            const WrEyebrow('TÌNH HUỐNG LẶP LẠI'),
            const SizedBox(height: 16),
            // Hai kiểu rỗng khác hẳn nhau, và từ khi có ngưỡng lặp thì kiểu thứ
            // hai lại xuất hiện. Đã ghi lại mấy lần rồi mà vẫn thấy đúng câu
            // "sau vài lần nữa" thì người dùng tưởng app nuốt mất dữ liệu —
            // phải nói rõ là đã ghi nhận, chỉ chưa điều nào lặp tới ngưỡng.
            if (top.isEmpty)
              if (recent.isEmpty)
                const WrParagraph(
                  'Sau vài lần nhìn lại có chọn tình huống, những điều lặp lại '
                  'sẽ hiện ra ở đây.',
                  key: Key('wr_discover_patterns_empty'),
                  style: TextStyle(
                    fontSize: 15.5,
                    color: WrColors.muted,
                    height: 1.6,
                  ),
                )
              else
                WrParagraph(
                  'Bạn đã chọn tình huống ${recent.length} lần, nhưng chưa '
                  'điều nào trở lại đủ $kRepeatedSituationsMinCount lần. Khi '
                  'một điều quay lại tới đó, nó sẽ hiện ở đây.',
                  key: const Key('wr_discover_patterns_below_threshold'),
                  style: const TextStyle(
                    fontSize: 15.5,
                    color: WrColors.muted,
                    height: 1.6,
                  ),
                )
            else ...[
              for (final p in top) ...[
                WrPatternRow(
                  label: situationLabelFor(sitMap, p.situationCode),
                  count: p.count,
                  ratio: p.count / maxCount,
                  onTap: () => context.push('/wr/pattern/${p.situationCode}'),
                ),
                if (p != top.last) const SizedBox(height: 18),
              ],
              if (hidden > 0) ...[
                const SizedBox(height: 18),
                _SeeMoreLink(
                  count: hidden,
                  onTap: () => context.push('/wr/patterns'),
                ),
              ],
            ],

            const SizedBox(height: 28),
            const WrSectionDivider(),
            const SizedBox(height: 24),

            // ── Trải nghiệm hiện tại (SCA) ──────────────────────────────
            _ScaCard(
              key: const Key('wr_discover_selfcheck_row'),
              latest: latestCheck,
              behaviourShares: behaviourShares,
            ),

            // ── Career Health Check — tiến độ tới bức tranh tổng thể ─────
            //
            // Chưa nhìn lại lần nào thì KHÔNG dựng thẻ này. Một thanh 0/15 đặt
            // ngay trên câu "Chưa có lần nhìn lại nào được ghi" chỉ nói lại
            // đúng điều vừa nói, bằng một hình dạng nặng hơn — và biến màn mời
            // bắt đầu thành màn báo cáo một con số bằng không.
            //
            // Đi QUÁ ngưỡng thì cũng bỏ luôn: thẻ chỉ có việc đo đường tới mốc
            // 15, mà "40/15" thì vừa hết việc vừa đọc như lỗi hiển thị. Đúng
            // mốc (15/15) vẫn giữ một lần để báo tin đã mở, sau đó thôi.
            if (reflectionCount > 0 &&
                reflectionCount <= kCareerHealthThreshold) ...[
              const SizedBox(height: 14),
              _CareerHealthCard(reflectionCount: reflectionCount),
            ],

            // ── Lời mời làm Self-Check ──────────────────────────────────
            const SizedBox(height: 14),
            _SelfCheckInviteCard(
              answered: latestCheck?.answers.length ?? 0,
              onStart: () => context.push('/wr/self-check'),
            ),

            // ── Diễn giải sâu & theo dõi xu hướng (Premium) ─────────────
            const SizedBox(height: 14),
            const _SelfCheckDeepLock(),

            // Mục "Hành trình đã đi" (Bạn đã nhìn lại N lần) đã bỏ: thẻ Career
            // Health phía trên đọc CÙNG con số đó, chỉ khác là nói luôn còn bao
            // xa tới đích. Giữ cả hai là hiện một con số hai lần ở hai chỗ.
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Đọc vị nhu cầu — ba lớp, Premium (quyết định của khách 2026-07-29).
//
// Free thấy đúng một khối khoá: mọi câu diễn giải đều nằm sau paywall, kể cả
// tên nhu cầu chủ đạo. Ranh giới giữ nguyên tinh thần cũ — Free xem dữ kiện
// đếm được (tình huống nào lặp mấy lần, đã nhìn lại bao nhiêu lần), Premium
// mới đọc ra điều đứng sau những con số đó.
// ---------------------------------------------------------------------------

class _NeedReadingBlock extends ConsumerWidget {
  const _NeedReadingBlock({required this.need, required this.insight});

  final HumanNeed need;

  /// Câu đọc từ tình huống người dùng lặp nhiều nhất. Null = nội dung DB không
  /// có gì cho tình huống đó, rơi về câu định nghĩa nhu cầu.
  final String? insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    if (!entitlement.canUseFeature(WrPremiumFeature.aiInsight)) {
      return const WrPremiumLock(
        key: Key('wr_discover_need_lock'),
        description:
            'Bản đầy đủ đọc ra điều bạn đang thật sự tìm kiếm đứng sau những '
            'tình huống lặp lại này, bằng lời của đời sống chứ không phải con số.',
        ctaLabel: 'Mở phần đọc vị',
        paywallTrigger: 'need_reading',
      );
    }

    // Một câu, hết. Ba khối "MONG ĐỢI KẾT QUẢ / NHU CẦU CỐT LÕI / GÓC NHÌN" đã
    // bỏ (khách 2026-08-04): chúng là chữ gán cứng theo nhu cầu, nói lại cùng
    // một ý bằng ba giọng, và kéo màn Hiểu mình thành một trang đọc dài.
    return _SeekingBlock(
      key: const Key('wr_discover_need_reading'),
      need: need,
      insight: insight,
    );
  }
}

// ---------------------------------------------------------------------------
// "Điều bạn đang tìm kiếm" — canh giữa, chữ nghiêng lớn như giao diện mẫu.
// ---------------------------------------------------------------------------

class _SeekingBlock extends StatelessWidget {
  const _SeekingBlock({super.key, required this.need, required this.insight});

  final HumanNeed need;
  final String? insight;

  @override
  Widget build(BuildContext context) {
    // Nội dung thật trước, câu định nghĩa nhu cầu chỉ là lưới an toàn.
    final text = insight ?? needSeekingSentence(need);
    // Câu lấy từ DB dài ngắn không đều — aha_message thường là hai vế. Cỡ chữ
    // mockup (26) chỉ vừa cho câu ngắn; câu dài để nguyên sẽ tràn kín màn.
    final fontSize = text.length > 90 ? 20.0 : 26.0;

    return Padding(
      key: const Key('wr_discover_seeking'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WrEyebrow('ĐIỀU BẠN ĐANG TÌM KIẾM', center: true),
          const SizedBox(height: 16),
          WrParagraph(
            '"$text"',
            // Câu trích canh giữa là có chủ ý — căn đều sẽ phá dáng khối này.
            // Vẫn cần giữ cụm cuối câu để dòng chót không còn trơ một chữ.
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
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
            style: const TextStyle(fontSize: 14.5, color: WrColors.muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Một dòng tình huống lặp lại — số lần + thanh so sánh, không diễn giải.
// ---------------------------------------------------------------------------

class WrPatternRow extends StatelessWidget {
  const WrPatternRow({
    super.key,
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
                  // Tên tình huống hay dài hơn một dòng; canh trái như cũ,
                  // chỉ chặn chỗ ngắt cuối để không còn "…nhưng đi / đâu?".
                  child: WrParagraph(
                    label,
                    textAlign: TextAlign.start,
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
                    fontSize: 14.5,
                    fontWeight: _isStrong ? FontWeight.w700 : FontWeight.w600,
                    color: _isStrong
                        ? WrColors.coral
                        : (_isFaint ? WrColors.muted : WrColors.navy),
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
// "Xem thêm" — lối sang danh sách đầy đủ, giữ màn chính gọn đúng ba dòng.
// ---------------------------------------------------------------------------

class _SeeMoreLink extends StatelessWidget {
  const _SeeMoreLink({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('wr_discover_see_more'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              'Xem thêm $count điều lặp lại',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 14, color: WrColors.navy),
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
    this.behaviourShares,
  });

  final ScaSelfCheckResponse? latest;

  /// Tỉ trọng bị chạm của ba trụ, chỉ khác null khi CHƯA tự đánh giá lần nào mà
  /// đã đủ 15 lần check-in — Hướng 1. Có điểm tự đánh giá thì bỏ qua đường này.
  final Map<SelfCheckPillar, double>? behaviourShares;

  double? _scoreOf(SelfCheckPillar pillar) => switch (pillar) {
        SelfCheckPillar.s => latest?.structureScore,
        SelfCheckPillar.c => latest?.cultureScore,
        SelfCheckPillar.a => latest?.activityScore,
      };

  /// Nhãn + màu của một trụ. Ưu tiên điểm tự đánh giá; chưa có thì đọc từ hành
  /// vi 15 lần nhìn lại; chưa có cả hai thì "Chưa đánh giá".
  (String, Color) _statusOf(SelfCheckPillar pillar) {
    final shares = behaviourShares;
    if (latest == null && shares != null) {
      final share = shares[pillar] ?? 0;
      return (
        behaviourPillarLabel(share),
        behaviourPillarIsHealthy(share) ? WrColors.teal : WrColors.coral,
      );
    }
    final score = _scoreOf(pillar);
    return (pillarStatusLabel(score), pillarStatusColor(score));
  }

  @override
  Widget build(BuildContext context) {
    // Không còn dòng chân thẻ "Đã tự đánh giá N lần" và không còn bấm được:
    // đó là con số thứ ba trên màn, và lối vào bộ câu hỏi đã là cái nút to màu
    // coral ngay bên dưới. Một thẻ bấm được mà không có dấu hiệu gì báo là bấm
    // được thì cũng như không có.
    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WrEyebrow('TRẢI NGHIỆM HIỆN TẠI'),
          const SizedBox(height: 6),
          for (final pillar in SelfCheckPillar.values)
            _ScaRow(pillar: pillar, status: _statusOf(pillar)),
          // Ba nhãn đọc ra từ hành vi thì phải nói rõ nguồn — đây là câu chữ,
          // không phải con số. Bỏ nó đi là để người dùng tưởng mình đã tự đánh
          // giá lúc nào rồi trong khi chưa hề.
          if (latest == null && behaviourShares != null) ...[
            const SizedBox(height: 10),
            Text(
              'Đọc từ $kCareerHealthThreshold lần nhìn lại của bạn',
              key: const Key('wr_discover_sca_source'),
              style: const TextStyle(fontSize: 14.5, color: WrColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScaRow extends StatelessWidget {
  const _ScaRow({required this.pillar, required this.status});

  final SelfCheckPillar pillar;

  /// (nhãn, màu nhãn) — đã do thẻ cha quyết định lấy từ tự đánh giá hay hành vi.
  final (String, Color) status;

  @override
  Widget build(BuildContext context) {
    final color = pillarColor(pillar);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Chấm màu, không phải chữ "S/C/A": ba trụ vẫn phân biệt được bằng
          // màu, nhưng người dùng không phải đọc mã của bộ khung nội bộ.
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              pillar.displayName,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                color: WrColors.navy,
              ),
            ),
          ),
          Text(
            status.$1,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: status.$2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Career Health Check — thanh tiến độ tới bức tranh tổng thể.
//
// Giao diện mẫu Sprint 2: thẻ VIỀN ĐỨT, một câu nói còn bao nhiêu, rồi thanh.
// Viền đứt là có chủ đích — đây là thứ CHƯA mở, không phải một thẻ nội dung.
//
// Đơn vị là LẦN, đúng con số câu "Bạn đã nhìn lại N lần" ở cuối màn. Mẫu ghi
// "5/15 Reflection" và bản đầu đếm NGÀY theo đó, nhưng hai con số đo hai đơn vị
// đứng cách nhau một màn hình thì không ai đoán ra — khách chốt gộp về một.
//
// Con số hiện ra KHÔNG bị chặn ở 15: đã nhìn lại 16 lần thì thẻ nói 16/15, vì
// nói "15/15" là mâu thuẫn ngay với câu "16 lần" bên dưới. Chỉ thanh tiến độ
// mới chặn — nó không vẽ quá đầy được.
// ---------------------------------------------------------------------------

class _CareerHealthCard extends StatelessWidget {
  const _CareerHealthCard({required this.reflectionCount});

  final int reflectionCount;

  @override
  Widget build(BuildContext context) {
    final unlocked = careerHealthUnlocked(reflectionCount);
    return Container(
      key: const Key('wr_discover_career_health'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WrColors.navy.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Career Health Check',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          WrParagraph(
            unlocked
                ? 'Bạn đã nhìn lại $reflectionCount/$kCareerHealthThreshold '
                    'lần. Bức tranh tổng thể đã mở.'
                : 'Bạn đã nhìn lại $reflectionCount/$kCareerHealthThreshold '
                    'lần. Đủ $kCareerHealthThreshold lần, bức tranh tổng thể '
                    'sẽ mở ra.',
            key: const Key('wr_discover_career_health_text'),
            style: const TextStyle(
              fontSize: 14.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          WrProgressTrack(
            value: unlocked ? 1 : reflectionCount / kCareerHealthThreshold,
            color: unlocked ? WrColors.teal : WrColors.coral,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lời mời làm Self-Check — mô tả, tiến độ lần gần nhất, nút bắt đầu.
//
// Thẻ "Trải nghiệm hiện tại" ở trên đã bấm được để mở bộ câu hỏi, nhưng nó nói
// KẾT QUẢ chứ không nói bộ câu hỏi là gì và mất bao lâu. Người chưa từng làm
// không có lý do nào để bấm vào một thẻ ghi "Chưa đánh giá" ba lần.
//
// Đây cũng là cửa của Hướng 2 (khách chốt 2026-07-31): ai không muốn đợi đủ 15
// lần check-in thì làm 15 câu này là có chủ đề thực hành ngay.
// ---------------------------------------------------------------------------

class _SelfCheckInviteCard extends StatelessWidget {
  const _SelfCheckInviteCard({required this.answered, required this.onStart});

  /// Số câu đã lưu ở lần tự đánh giá GẦN NHẤT.
  ///
  /// Đọc từ chính `answers` chứ không suy ra từ "đã làm hay chưa": có bản ghi
  /// thiếu câu thật (bản 30/7 chỉ còn 12/15, di chứng của lỗi nuốt câu đã vá ở
  /// `wr_self_check_screen.dart`), và dòng này phải nói ra đúng cái đang có
  /// trong DB chứ không làm tròn thành 15.
  final int answered;

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final total = kSelfCheckQuestions.length;
    final shown = answered > total ? total : answered;
    return WrCardMinimal(
      key: const Key('wr_discover_self_check_invite'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrParagraph(
            '$total câu hỏi tình huống ngắn, giúp phác thảo điều kiện làm việc '
            'đang hỗ trợ hoặc cản trở bạn. Có thể làm lại bất kỳ lúc nào.',
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.65,
              color: WrColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Tiến độ lần gần nhất: $shown/$total',
            key: const Key('wr_discover_self_check_progress'),
            style: const TextStyle(fontSize: 13.5, color: WrColors.muted),
          ),
          const SizedBox(height: 8),
          WrProgressTrack(
            value: shown / total,
            color: shown == 0 ? WrColors.muted : WrColors.teal,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                shown > 0 ? 'Làm lại Self-Check' : 'Bắt đầu Self-Check',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diễn giải sâu & theo dõi xu hướng — Premium.
//
// Ranh giới giống mọi chỗ khác trên màn này: Free thấy CON SỐ của lần gần nhất,
// Premium mới thấy nó đang đi theo hướng nào và vì sao.
//
// Người đã Premium thì thẻ này biến mất chứ không đổi thành nút — phần diễn
// giải nằm ở màn kết quả Self-Check, mời họ mua lại thứ đã mua là vô nghĩa.
// ---------------------------------------------------------------------------

class _SelfCheckDeepLock extends ConsumerWidget {
  const _SelfCheckDeepLock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    if (entitlement.canUseFeature(WrPremiumFeature.selfCheckDeepDive)) {
      return const SizedBox.shrink();
    }
    return WrPremiumLock(
      key: const Key('wr_discover_sca_deep_lock'),
      title: 'Diễn giải sâu & theo dõi xu hướng',
      description:
          'Cùng ${kSelfCheckQuestions.length} câu này, chạy lại theo thời gian '
          'để thấy điều kiện làm việc của bạn thay đổi ra sao, và đối chiếu '
          'với những điều lặp lại bạn đã ghi.',
      ctaLabel: 'Mở khoá',
      paywallTrigger: 'sca_deep',
    );
  }
}

// ---------------------------------------------------------------------------
// Tiện ích dùng chung cho màn chi tiết.
// ---------------------------------------------------------------------------

/// Tên hiển thị của một tình huống theo mã.
///
/// Không bao giờ trả về chính cái mã. `C2-sit-01` là thuật ngữ nội bộ (v1.6
/// §XII.5) — hiện nó ra là phơi bộ khung SCA cho người dùng, mà đúng lúc tệ
/// nhất: khi thư viện tình huống chưa tải xong hoặc mất mạng.
String situationLabel(List<WrSituation> situations, String? code) {
  if (code == null) return 'Tình huống';
  for (final s in situations) {
    if (s.code == code) return s.text;
  }
  return 'Tình huống';
}

/// Bản dùng map — cùng luật với [situationLabel].
String situationLabelFor(Map<String, String> labels, String? code) {
  if (code == null) return 'Tình huống';
  return labels[code] ?? 'Tình huống';
}

/// Số lần đã gặp một tình huống.
int occurrenceOf(List<PatternCount> patterns, String code) {
  for (final p in patterns) {
    if (p.situationCode == code) return p.occurrenceCount;
  }
  return 0;
}
