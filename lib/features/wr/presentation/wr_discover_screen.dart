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
import '../../../core/widgets/wr_link_row.dart';
import 'wr_sca_deep_dive_screen.dart' show openScaDeepDive;
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

/// Điểm một trụ trong một lần tự đánh giá.
double? scaScoreFor(ScaSelfCheckResponse? r, SelfCheckPillar pillar) =>
    switch (pillar) {
      SelfCheckPillar.s => r?.structureScore,
      SelfCheckPillar.c => r?.cultureScore,
      SelfCheckPillar.a => r?.activityScore,
    };

/// Cột "Bạn đánh giá" của Career Snapshot có gì để hiện chưa.
///
/// Đòi CẢ BA trụ có điểm chứ không chỉ đòi `latest != null`: có bản ghi thiếu
/// câu thật trong DB (di chứng lỗi nuốt câu đã vá ở `wr_self_check_screen`), và
/// một cột hiện hai dòng rồi bỏ trống dòng thứ ba đọc như lỗi tải dở.
///
/// Nằm ở tầng file chứ không nằm trong thẻ: màn hình cũng cần biết câu trả lời
/// này để quyết định có dựng thêm khối khoá Diễn giải sâu ở dưới hay không.
bool snapshotHasSelfCheck(ScaSelfCheckResponse? latest) =>
    latest != null &&
    SelfCheckPillar.values.every((p) => (scaScoreFor(latest, p) ?? 0) > 0);

/// Người dùng đang tự chấm trụ này là ỔN.
///
/// Chỉ mức cao nhất mới tính, đúng luật `ScaPillarStatus.isReassuring` của màn
/// Diễn giải sâu: "Cần chú ý" nằm giữa thang 1–5 và người tự chấm như vậy KHÔNG
/// nói rằng mình ổn — gộp nó vào đây thì câu "bạn tự đánh giá phần này ổn,
/// nhưng…" sẽ bịa lại lời của họ.
bool pillarStatusIsReassuring(String label) => label == 'Đang phát triển';

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
    // Nguồn sự thật duy nhất của cả màn này (Kiến trúc v2.0 §4.3). Không còn
    // đọc `wr_pattern_counts` ở đâu trên màn Hiểu mình.
    final recent = recentSituationIds(episodes);

    final sitMap = {for (final s in situations) s.code: s.text};
    final reflectionCount = episodes.length;
    final need = dominantNeedFromBehaviour(recent, situations);
    final latestCheck = selfChecks.isEmpty ? null : selfChecks.first;

    // Cột "Xuất hiện" của Career Snapshot — số lần mỗi trụ bị chạm.
    //
    // Đếm trên TOÀN BỘ `episodes`, không đi qua `recent`: `recentSituationIds`
    // chặn ở 30 mục gần nhất, nên lấy nó làm nguồn thì người đã nhìn lại 80 lần
    // vẫn đọc được "14 / 30 lần" (Changelog CareerSnapshot §8).
    final pillarCounts = pillarReflectionCounts(episodes, situations);

    // Khối Snapshot có dựng ra dòng khoảng lệch không — quyết định luôn ở đây
    // vì phần dưới màn phải biết để khỏi mời mua Diễn giải sâu lần thứ hai.
    final snapshotGapShown = snapshotHasSelfCheck(latestCheck) &&
        careerHealthUnlocked(reflectionCount) &&
        dominantPillar(pillarCounts, reflectionCount) != null;

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
              _NeedReadingBlock(need: need),
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

            // ── Career Snapshot — MỘT khối, mỗi trụ đúng một dòng ───────
            _CareerSnapshotCard(
              key: const Key('wr_discover_career_snapshot'),
              latest: latestCheck,
              counts: pillarCounts,
              reflectionTotal: reflectionCount,
              onStartSelfCheck: () => context.push('/wr/self-check'),
              onOpenRepeated: () => context.push('/wr/patterns'),
            ),

            // ── Lời mời làm Self-Check ──────────────────────────────────
            const SizedBox(height: 14),
            _SelfCheckInviteCard(
              answered: latestCheck?.answers.length ?? 0,
              onStart: () => context.push('/wr/self-check'),
            ),

            // ── Diễn giải sâu & theo dõi xu hướng (Premium) ─────────────
            //
            // Chỉ khi khối Career Snapshot phía trên CHƯA có dòng khoảng lệch.
            // Dòng đó đã mang sẵn lối vào Diễn giải sâu (và nút mở khoá cho bản
            // miễn phí); dựng thêm thẻ này nữa là hai lời mời mua cùng một thứ,
            // cách nhau ba dòng.
            if (!snapshotGapShown) ...[
              const SizedBox(height: 14),
              const _SelfCheckDeepLock(),
            ],

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
  const _NeedReadingBlock({required this.need});

  final HumanNeed need;

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
    );
  }
}

// ---------------------------------------------------------------------------
// "Điều bạn đang tìm kiếm" — canh giữa, chữ nghiêng lớn như giao diện mẫu.
// ---------------------------------------------------------------------------

class _SeekingBlock extends StatelessWidget {
  const _SeekingBlock({super.key, required this.need});

  final HumanNeed need;

  @override
  Widget build(BuildContext context) {
    // Câu NHU CẦU, không phải câu Insight (họp 26_1). Nhãn của khối hứa "điều
    // bạn đang tìm kiếm"; câu aha đọc vị một tình huống cụ thể thì trả lời một
    // câu hỏi khác, và người dùng đọc xong không biết nó liên quan gì tới nhãn.
    final text = needSeekingSentence(need);
    // Bốn câu nhu cầu đều ngắn, nhưng giữ luật co chữ phòng khi nội dung đổi.
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
// Career Snapshot — MỘT khối, mỗi trụ đúng một dòng, hai nguồn đặt cạnh nhau
// ---------------------------------------------------------------------------
//
// Thay hẳn hai khối cũ: "Trải nghiệm hiện tại" (`_ScaCard`) và "Career Health
// Check" (`_CareerHealthCard`). Nguồn: `Changelog_CareerSnapshot.docx` §3,
// hàm tham chiếu `careerSnapshotCard()` trong mockup v18.
//
// VÌ SAO PHẢI GỘP. Sau khi Career Health Check mở khoá, CÙNG ba trụ xuất hiện
// hai lần trong một màn hình, cách nhau vài dòng, với kết luận ngược nhau:
//
//     Sự rõ ràng      Cần chú ý   |   Đang phát triển
//     Mối quan hệ     Cần chú ý   |   Ưu tiên cải thiện
//     Cách làm việc   Cần chú ý   |   Cần chú ý
//
// Người dùng đọc đây là lỗi hệ thống, không phải hai góc nhìn bổ sung nhau. §1
// chỉ đúng dấu hiệu: khi giao diện cần một đoạn văn để giải thích vì sao hai
// bảng giống hệt nhau lại nói ngược nhau, thì thiết kế đang sai, không phải
// người dùng chưa hiểu. Bản trước có đúng đoạn văn đó.
//
// Nguyên nhân kỹ thuật (§1.1): hai khối dùng chung MỘT thang từ vựng đánh giá.
// Dùng chung thang đo thì người đọc mặc định chúng đang đo cùng một đối tượng.
//
// HAI NGUỒN ĐO HAI THỨ KHÁC NHAU (§2):
//
//                  Self-Check                  Pattern Reflection
//   Hỏi            "Môi trường của tôi có       "Chuyện thiếu rõ ràng có hay
//                   rõ ràng không?"              xảy đến với tôi không?"
//   Đo             CHẤT LƯỢNG điều kiện        TẦN SUẤT trải nghiệm
//   Nguồn          tự chấm, 15 câu             hành vi thật, tích luỹ
//   Tính chất      ảnh chụp một thời điểm      dòng chảy liên tục
//   Từ vựng        thang đánh giá              thang tần suất — SỐ LẦN, hết
//
// Nên cột phải KHÔNG có nhãn đánh giá nào. Xem khối chú thích ở
// `wr_career_health.dart` chỗ đã bỏ `behaviourPillarLabel`.
//
// BA TRẠNG THÁI (§4). Hai nguồn độc lập, mỗi nguồn tự mở phần của mình. Không
// bắt buộc phải có cả hai mới hiện khối. Lý do: Reflection là thói quen hàng
// ngày nằm ngay Home, còn Self-Check phải chủ động tìm vào tab Hiểu. Đa số
// người dùng tích luỹ Reflection trước, và nhiều người sẽ không bao giờ làm
// Self-Check. Khoá cả khối cho đến khi đủ hai nguồn là vừa lãng phí dữ liệu họ
// đã tạo ra, vừa biến một việc vốn tuỳ chọn thành cửa ải bắt buộc.
//
// Ô TRỐNG LÀ LỜI MỜI, KHÔNG PHẢI Ổ KHOÁ. Không dùng hiệu ứng mờ cho các ô
// trống này — mờ đang dành riêng cho nội dung Premium. Nhầm hai tín hiệu là để
// người dùng tưởng phải trả tiền mới xem được, trong khi chỉ cần làm thêm một
// việc miễn phí.
// ---------------------------------------------------------------------------

class _CareerSnapshotCard extends ConsumerWidget {
  const _CareerSnapshotCard({
    super.key,
    required this.latest,
    required this.counts,
    required this.reflectionTotal,
    required this.onStartSelfCheck,
    required this.onOpenRepeated,
  });

  /// Lần tự đánh giá gần nhất. Null = chưa từng làm.
  final ScaSelfCheckResponse? latest;

  /// Số lần mỗi trụ bị chạm, đếm trên toàn bộ lịch sử nhìn lại.
  final Map<SelfCheckPillar, int> counts;

  /// Mẫu số của cột "Xuất hiện" — tổng số lần nhìn lại.
  final int reflectionTotal;

  final VoidCallback onStartSelfCheck;
  final VoidCallback onOpenRepeated;

  double? _scoreOf(SelfCheckPillar pillar) => scaScoreFor(latest, pillar);

  bool get _hasSelfCheck => snapshotHasSelfCheck(latest);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReflection = careerHealthUnlocked(reflectionTotal);
    final takenAt = latest?.takenAt;

    return WrCardMinimal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WrEyebrow('CAREER SNAPSHOT'),
          const SizedBox(height: 6),
          const WrParagraph(
            'Cùng ba trụ, nhìn từ hai phía: điều bạn tự đánh giá, và điều đang '
            'thực sự lặp lại trong các lần nhìn lại.',
            style: TextStyle(fontSize: 14.5, color: WrColors.muted, height: 1.6),
          ),

          // §5 — Self-Check cũ đi theo thời gian, nên LUÔN hiện thời điểm kèm
          // cột đánh giá. Một người chấm hồi tháng 3 rồi phản chiếu đều tới
          // tháng 9 mà màn hình vẫn nói "Bạn đánh giá: Cần chú ý" như đánh giá
          // hiện tại là sai lệch — và hệ thống còn lấy chính con số cũ đó đối
          // chiếu với hành vi mới, nên kết luận khoảng lệch sai theo.
          if (_hasSelfCheck && takenAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Self-Check gần nhất: ${selfCheckDateLabel(takenAt)}',
              key: const Key('wr_snapshot_self_check_date'),
              style: const TextStyle(fontSize: 13.5, color: WrColors.muted),
            ),
            if (selfCheckIsStale(takenAt, DateTime.now())) ...[
              const SizedBox(height: 6),
              WrParagraph(
                'Đã hơn ${kSelfCheckStaleDays ~/ 30} tháng kể từ lần đó. Công '
                'việc có thể đã khác đi, bạn thử cập nhật lại để bức tranh sát '
                'với hiện tại hơn nhé.',
                key: const Key('wr_snapshot_self_check_stale'),
                style: const TextStyle(
                  fontSize: 13.5,
                  color: WrColors.muted,
                  height: 1.55,
                ),
              ),
            ],
          ],

          const SizedBox(height: 8),
          for (final pillar in SelfCheckPillar.values)
            _SnapshotRow(
              key: Key('wr_snapshot_pillar_${pillar.name}'),
              pillar: pillar,
              // Nhãn của cột trái vẫn là thang đánh giá đã có (§3: "giữ nguyên
              // thang đánh giá đã có, lấy từ pillarLevelText").
              rating: _hasSelfCheck ? pillarStatusLabel(_scoreOf(pillar)) : null,
              ratingColor: pillarStatusColor(_scoreOf(pillar)),
              count: hasReflection ? counts[pillar] ?? 0 : null,
              total: reflectionTotal,
              last: pillar == SelfCheckPillar.values.last,
            ),

          // ── Lời mời cho nguồn còn trống ───────────────────────────────
          //
          // HAI `if` độc lập, không phải if/else. Mockup v18 dùng else-if nên
          // người mới — chưa Self-Check, mới nhìn lại vài lần — chỉ thấy lời
          // mời làm Self-Check và không bao giờ biết cột bên kia còn thiếu bao
          // nhiêu. §4 nói rõ hai nguồn độc lập, mỗi nguồn tự mở phần của mình;
          // vậy thì mỗi nguồn cũng tự nói phần của mình còn thiếu gì.
          if (!_hasSelfCheck)
            _SnapshotInvite(
              key: const Key('wr_snapshot_invite_self_check'),
              text: 'Cột "Bạn đánh giá" sẽ hiện sau khi bạn trả lời bộ '
                  'Self-Check ${kSelfCheckQuestions.length} câu, để so với '
                  'những gì đang thực sự lặp lại.',
              action: _SnapshotButton(
                label: 'Làm Self-Check',
                onTap: onStartSelfCheck,
              ),
            ),
          if (!hasReflection)
            _SnapshotInvite(
              key: const Key('wr_snapshot_invite_reflection'),
              text: 'Cột "Xuất hiện" sẽ mở sau '
                  '${kCareerHealthThreshold - reflectionTotal} lần nhìn lại '
                  'nữa, khi đã đủ dữ liệu để thấy điều gì đang trở đi trở lại. '
                  'Một lần được tính khi bạn đã chọn một tình huống; chạm ô cảm '
                  'xúc rồi rời đi thì lần đó chưa vào đây.',
              action: WrProgressTrack(
                value: reflectionTotal / kCareerHealthThreshold,
                color: WrColors.coral,
              ),
            ),

          // Đã mở đủ hai cột thì mang theo một lối đi chạm được sang danh sách
          // đầy đủ. Khách báo 2026-08-24: đủ 15 lần rồi mà "không có nút để
          // click vào xem bức tranh" — lối đi đó phải sống sót qua lần gộp này.
          if (hasReflection)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: WrLinkRow(
                key: const Key('wr_snapshot_open_repeated'),
                label: 'Xem các vấn đề thường lặp lại',
                onTap: onOpenRepeated,
              ),
            ),

          // ── Dòng diễn giải khoảng lệch — chỉ khi có ĐỦ CẢ HAI nguồn ────
          if (_hasSelfCheck && hasReflection)
            _SnapshotGapLine(
              dominant: dominantPillar(counts, reflectionTotal),
              counts: counts,
              reflectionTotal: reflectionTotal,
              ratingOf: (p) => pillarStatusLabel(_scoreOf(p)),
              onOpenRepeated: onOpenRepeated,
            ),
        ],
      ),
    );
  }
}

/// Một trụ: tên ở trên, hai nguồn đặt cạnh nhau bên dưới.
///
/// Hai cột không còn "cãi nhau" vì hiển nhiên là hai loại thông tin khác nhau —
/// một bên là chữ đánh giá, một bên là phân số.
class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    super.key,
    required this.pillar,
    required this.rating,
    required this.ratingColor,
    required this.count,
    required this.total,
    required this.last,
  });

  final SelfCheckPillar pillar;

  /// Nhãn cột "Bạn đánh giá". Null = chưa làm Self-Check.
  final String? rating;
  final Color ratingColor;

  /// Số lần cột "Xuất hiện". Null = chưa đủ số lần nhìn lại.
  final int? count;
  final int total;

  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: WrColors.navy.withValues(alpha: 0.08),
                ),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Chấm màu, không phải chữ "S/C/A": ba trụ vẫn phân biệt được
              // bằng màu, nhưng người dùng không phải đọc mã của bộ khung nội bộ.
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pillarColor(pillar),
                ),
              ),
              const SizedBox(width: 12),
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
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SnapshotCell(
                    caption: 'Bạn đánh giá',
                    // Ô trống là LỜI MỜI, không phải ổ khoá — chữ thường, màu
                    // nhạt, không mờ, không ổ khoá.
                    value: rating ?? 'Chưa có',
                    color: rating == null ? WrColors.muted : ratingColor,
                    strong: rating != null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SnapshotCell(
                    caption: 'Xuất hiện',
                    // Ngôn ngữ TẦN SUẤT, không nhãn đánh giá nào (§2).
                    value: count == null ? 'Chưa đủ dữ liệu' : '$count / $total lần',
                    color: count == null ? WrColors.muted : WrColors.navy,
                    strong: count != null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCell extends StatelessWidget {
  const _SnapshotCell({
    required this.caption,
    required this.value,
    required this.color,
    required this.strong,
  });

  final String caption;
  final String value;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: const TextStyle(fontSize: 13, color: WrColors.muted),
        ),
        const SizedBox(height: 3),
        WrParagraph(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
            color: color,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Lời mời cho nguồn còn trống. Không mờ, không ổ khoá (§4).
class _SnapshotInvite extends StatelessWidget {
  const _SnapshotInvite({
    super.key,
    required this.text,
    required this.action,
  });

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WrParagraph(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          action,
        ],
      ),
    );
  }
}

class _SnapshotButton extends StatelessWidget {
  const _SnapshotButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: WrColors.coral,
          foregroundColor: WrColors.navy,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dòng khoảng lệch — ranh giới miễn phí / Premium (§6)
// ---------------------------------------------------------------------------
//
// Cách đối chiếu Self-Check với Pattern Reflection CHÍNH LÀ lớp 3 của tính năng
// Premium "Diễn giải sâu". Nếu bản miễn phí đã làm đúng việc đó thì người dùng
// không còn lý do trả tiền.
//
// Nhưng cũng không giấu sạch: khi đã đủ hai nguồn mà chưa Premium, khối vẫn nói
// rằng "hai cột trên đang cho thấy một khoảng lệch", kèm nút mở khoá. Người
// dùng thấy giá trị CỤ THỂ đang bị khoá, thay vì một lời quảng cáo chung chung.
// ---------------------------------------------------------------------------

class _SnapshotGapLine extends ConsumerWidget {
  const _SnapshotGapLine({
    required this.dominant,
    required this.counts,
    required this.reflectionTotal,
    required this.ratingOf,
    required this.onOpenRepeated,
  });

  /// Trụ nổi trội, hoặc null khi phân bố tương đối đều.
  final SelfCheckPillar? dominant;
  final Map<SelfCheckPillar, int> counts;
  final int reflectionTotal;
  final String Function(SelfCheckPillar) ratingOf;
  final VoidCallback onOpenRepeated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pillar = dominant;
    // Chưa trụ nào vượt 40% thì KHÔNG có khoảng lệch nào để nói. Bày một dòng
    // "Khoảng lệch đáng chú ý" lên trên ba con số gần bằng nhau là khẳng định
    // một xu hướng không có thật, và bán một thứ không tồn tại.
    if (pillar == null) return const SizedBox.shrink();

    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final premium =
        entitlement.canUseFeature(WrPremiumFeature.selfCheckDeepDive);

    return Container(
      key: const Key('wr_snapshot_gap'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: WrColors.navy.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            premium ? 'Khoảng lệch đáng chú ý' : 'Premium',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: premium ? WrColors.teal : WrColors.coral,
            ),
          ),
          const SizedBox(height: 6),
          WrParagraph(
            premium
                ? _gapText(pillar)
                : 'Hai cột trên đang cho thấy một khoảng lệch. Mở khoá để đọc '
                    'ý nghĩa của khoảng lệch đó, và theo dõi nó thay đổi ra sao '
                    'theo thời gian.',
            key: const Key('wr_snapshot_gap_text'),
            style: const TextStyle(
              fontSize: 14.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          if (premium)
            WrLinkRow(
              key: const Key('wr_snapshot_gap_open'),
              label: 'Xem diễn giải sâu & xu hướng',
              onTap: () => openScaDeepDive(context, ref),
            )
          else
            // Nút trần, KHÔNG dùng `WrPremiumLock`: khối đó tự dựng một thẻ
            // hoàn chỉnh kèm ổ khoá và chữ "Premium" của riêng nó, đặt vào đây
            // là thẻ lồng trong thẻ và nói chữ "Premium" hai lần cách nhau ba
            // dòng.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('wr_snapshot_gap_unlock'),
                // Mua xong đi thẳng vào màn đích, không rơi lại tab Hiểu mình.
                onPressed: () => openScaDeepDive(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.navy,
                  foregroundColor: WrColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Mở khoá diễn giải',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Hai nhánh của §6, dựng từ chính hai con số đang hiện ở hai cột.
  String _gapText(SelfCheckPillar pillar) {
    final rating = ratingOf(pillar).toLowerCase();
    final count = counts[pillar] ?? 0;
    final name = pillar.displayName.toLowerCase();

    // Tự chấm là ổn nhất, mà lại là trụ quay lại nhiều nhất — đây là nhánh có
    // giá trị cao nhất của cả tính năng.
    if (pillarStatusIsReassuring(ratingOf(pillar))) {
      return 'Bạn tự đánh giá $name ở mức "$rating", nhưng đây lại là trụ xuất '
          'hiện nhiều nhất trong các lần nhìn lại gần đây ($count trong '
          '$reflectionTotal lần).';
    }
    return '${pillar.displayName} là trụ bạn quay lại nhiều nhất ($count trong '
        '$reflectionTotal lần), và cũng là trụ bạn tự đánh giá ở mức "$rating". '
        'Hai nguồn đang xác nhận lẫn nhau.';
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
            'Chỉ với $total câu hỏi ngắn giúp hệ thống hiểu rõ hơn trạng thái '
            'hiện tại của bạn. Đừng quên cập nhật lại bất cứ khi nào bạn thấy '
            'có sự thay đổi trong công việc nhé.',
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
                shown > 0 ? 'Cập nhật lại Self-Check' : 'Bắt đầu Self-Check',
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
// Người đã Premium KHÔNG còn thấy thẻ khoá, nhưng vẫn thấy một dòng dẫn sang
// màn Diễn giải sâu. Trước changelog 24/08 §7 thì thẻ này biến mất hẳn với họ,
// nghĩa là người đã trả tiền không còn lối nào vào tính năng mình vừa mua từ
// tab Hiểu mình — chỗ tự nhiên nhất để tìm nó.
// ---------------------------------------------------------------------------

class _SelfCheckDeepLock extends ConsumerWidget {
  const _SelfCheckDeepLock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    if (entitlement.canUseFeature(WrPremiumFeature.selfCheckDeepDive)) {
      return WrLinkRow(
        key: const Key('wr_discover_sca_deep_open'),
        label: 'Diễn giải sâu & xu hướng',
        onTap: () => openScaDeepDive(context, ref),
      );
    }
    return WrPremiumLock(
      key: const Key('wr_discover_sca_deep_lock'),
      title: 'Diễn giải sâu & theo dõi xu hướng',
      description:
          'So sánh kết quả theo thời gian để thấy điều kiện làm việc của bạn đã '
          'thay đổi ra sao và đối chiếu với các ghi chú trước đó.',
      ctaLabel: 'Mở khoá',
      paywallTrigger: 'sca_deep',
      // Mua xong đi thẳng vào màn đích, không rơi lại tab Hiểu mình (§7).
      onPressed: () => openScaDeepDive(context, ref),
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
