// Màn "Diễn giải sâu & xu hướng" — Premium.
//
// Nguồn: WorkReflection_Changelog_20260824.docx §7, mockup v16 `screenScaDeepDive`.
//
// §7 mở đầu bằng đúng lỗi cần chữa: "Trước đây nút Mở khoá ở tính năng này chỉ
// dẫn tới màn Paywall chung, không có màn đích thực sự". Nên màn này tồn tại
// trước hết để cái nút đó có chỗ để đến.
//
// Ba lớp cho mỗi trụ nằm hết ở `wr_sca_deep_dive.dart` — ở đây chỉ dựng.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_deep_interpretation.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_sca_deep_dive.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../wr_providers.dart';

/// Đường vào màn này từ bất kỳ nút "Mở khoá" nào của tính năng Self-Check sâu.
///
/// §7: "nút Mở khoá ở màn Understand và màn Kết quả Self-Check giờ trỏ thẳng
/// vào màn này nếu người dùng đã Premium; nếu chưa, vẫn qua Paywall như cũ, và
/// sau khi mua với trigger sca_deep sẽ vào thẳng màn này."
///
/// Lấy `router` TRƯỚC khi đi, giống `_openPayment` ở paywall: mua xong thì quyền
/// đổi, mà quyền đổi thì chính cái nút gọi hàm này bị gỡ khỏi cây.
Future<void> openScaDeepDive(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context, listen: false);

  Future<bool> hasAccess() async {
    try {
      final e = await container.read(wrEntitlementProvider.future);
      return e.canUseFeature(WrPremiumFeature.selfCheckDeepDive);
    } catch (_) {
      // Không đọc được quyền thì coi như chưa có: đưa nhầm người chưa mua vào
      // màn Premium tệ hơn là mời họ xem trang giới thiệu một lần nữa.
      return false;
    }
  }

  if (await hasAccess()) {
    router.push('/wr/sca-deep-dive');
    return;
  }

  await router.push('/wr/paywall?trigger=sca_deep');
  if (await hasAccess()) router.push('/wr/sca-deep-dive');
}

class WrScaDeepDiveScreen extends ConsumerWidget {
  const WrScaDeepDiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        foregroundColor: WrColors.navy,
        title: const Text(
          'Diễn giải sâu & xu hướng',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
      ),
      body: SafeArea(
        child: entitlement.canUseFeature(WrPremiumFeature.selfCheckDeepDive)
            ? const _Body()
            : const _Locked(),
      ),
    );
  }
}

/// Vào thẳng route mà chưa mua — deep link, hoặc quyền hết hạn giữa chừng.
class _Locked extends StatelessWidget {
  const _Locked();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('wr_sca_deep_dive_locked'),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
      children: [
        const WrEyebrow('PREMIUM'),
        const SizedBox(height: 10),
        const WrParagraph(
          'Phần này đọc kỹ từng mặt theo khoảng điểm của bạn, so với những lần '
          'tự soi trước, và đối chiếu với những tình huống bạn hay gặp khi nhìn '
          'lại.',
          style: TextStyle(
            fontSize: 16.5,
            height: 1.65,
            color: WrColors.muted,
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () => context.push('/wr/paywall?trigger=sca_deep'),
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.dark,
            foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Mở diễn giải sâu',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thân màn — MỘT insight dẫn dắt, rồi xu hướng, rồi ba trụ rút gọn
// ---------------------------------------------------------------------------
//
// `DienGiaiSau §8` nói thẳng vì sao phải đảo lại: "Bản Diễn giải sâu hiện tại
// đang hiển thị 3 trụ nhân 3 lớp thông tin, thành 9 khối văn bản. Đó là một bản
// báo cáo, và người dùng sẽ đọc lướt rồi bỏ qua."
//
// Nên thứ tự mới:
//   1 · Đúng MỘT điều đáng chú ý nhất, viết thành một đoạn hoàn chỉnh.
//   2 · Xu hướng, nếu đã đủ điều kiện mở.
//   3 · Ba trụ ở dạng rút gọn, bấm mới mở rộng.
//
// "Một insight được đọc kỹ có giá trị hơn chín insight bị lướt qua."
//
// Trụ nào sinh ra đoạn dẫn dắt thì mở sẵn — người vừa đọc xong một đoạn về nó
// mà phải tự tìm rồi bấm mở lần nữa để xem chi tiết là bắt họ làm việc thừa.

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final history =
        ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];
    final now = nowVn();

    final pillars = buildScaDeepDive(
      history: history,
      episodes: episodes,
      situations: situations,
      now: now,
    );

    final content = buildDeepInterpretation(
      history: history,
      episodes: episodes,
      situations: situations,
      now: now,
    );

    // Chưa Self-Check thì tầng 1 và tầng 3 đều câm, nhưng tầng 2 KHÔNG cần
    // Self-Check (§4: "Tầng này dựa vào Reflection chứ không dựa vào
    // Self-Check… Nếu xu hướng chỉ dựa vào Self-Check, người vừa mua Premium mà
    // mới làm Self-Check một lần sẽ phải chờ nhiều tháng mới thấy được gì").
    //
    // Nên chỉ mời đi làm 15 câu khi thật sự KHÔNG CÓ GÌ để nói. Người đã nhìn
    // lại đều đặn hai tháng mà vừa trả tiền xong lại gặp một màn hình rỗng là
    // đúng cái §6 gọi là phần dễ làm hỏng trải nghiệm nhất.
    if (pillars.isEmpty && !content.facts.tier2Unlocked) return const _Empty();

    final dominant = content.facts.dominant;

    // Lần đầu dựng: mở sẵn đúng trụ vừa được nói tới ở đoạn dẫn dắt.
    if (_open.isEmpty && dominant != null) _open.add(dominant.name);

    final previous = () {
      final scored = scoredSelfChecks(history);
      return scored.length > 1 ? scored[1] : null;
    }();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
      children: [
        // ── 1 · Một insight dẫn dắt ─────────────────────────────────────
        _LeadCard(
          text: content.leadText,
          highlight: content.branch == DeepGapBranch.outOfSync,
        ),

        // Self-Check đã cũ thì mời cập nhật ngay dưới đoạn dẫn dắt — chính đoạn
        // đó vừa dùng con số cũ để kết luận, nên cảnh báo phải đứng cạnh nó.
        if (content.staleSelfCheckText case final String stale) ...[
          const SizedBox(height: 12),
          WrParagraph(
            stale,
            key: const Key('wr_deep_stale_self_check'),
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: WrColors.text3,
            ),
          ),
        ],

        // ── 2 · Xu hướng ────────────────────────────────────────────────
        const SizedBox(height: 26),
        const WrEyebrow('XU HƯỚNG'),
        const SizedBox(height: 12),
        WrParagraph(
          content.trendText,
          key: const Key('wr_deep_trend'),
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontSize: 15,
            height: 1.7,
            color: WrColors.muted,
          ),
        ),
        if (content.selfCheckTrendText case final String t) ...[
          const SizedBox(height: 14),
          WrParagraph(
            t,
            key: const Key('wr_deep_self_check_trend'),
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: WrColors.muted,
            ),
          ),
        ],

        // ── 3 · Ba trụ, rút gọn ─────────────────────────────────────────
        //
        // Chưa Self-Check thì không có mức nào để bày — phần này vắng mặt thay
        // vì hiện ba thẻ "Chưa đánh giá".
        if (pillars.isNotEmpty) ...[
          const SizedBox(height: 26),
          const WrEyebrow('TỪNG TRỤ MỘT'),
          const SizedBox(height: 12),
          for (final p in pillars) ...[
            _PillarCard(
              data: p,
              expanded: _open.contains(p.pillar.name),
              onToggle: () => setState(() {
                if (!_open.remove(p.pillar.name)) _open.add(p.pillar.name);
              }),
            ),
            const SizedBox(height: 10),
          ],
        ] else ...[
          const SizedBox(height: 22),
          WrParagraph(
            kDeepOneSelfCheckOnly,
            key: const Key('wr_deep_no_self_check_yet'),
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.65,
              color: WrColors.text3,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            key: const Key('wr_sca_deep_dive_start_self_check'),
            onPressed: () => context.push('/wr/self-check'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WrColors.dark,
              foregroundColor: WrColors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Làm Self-Check',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],

        const SizedBox(height: 6),
        Text(
          scaDeepDiveFootnote(previous),
          key: const Key('wr_sca_deep_dive_footnote'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.55,
            color: WrColors.text3,
          ),
        ),
      ],
    );
  }
}

/// Đoạn dẫn dắt — thứ duy nhất trên màn được viết thành một đoạn hoàn chỉnh.
class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.text, required this.highlight});

  final String text;

  /// Nhánh lệch pha — §3.1 gọi đây là "nhánh có giá trị cao nhất của cả tính
  /// năng", nên nó được một nhãn riêng thay vì trôi lẫn vào các đoạn khác.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_deep_lead'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WrColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlight) ...[
            const Text(
              'Khoảng lệch đáng chú ý',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: WrColors.teal,
              ),
            ),
            const SizedBox(height: 8),
          ],
          WrParagraph(
            text,
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontSize: 16,
              height: 1.75,
              color: WrColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chưa từng làm đủ 15 câu — cả ba lớp đều không có gì để nói.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('wr_sca_deep_dive_empty'),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
      children: [
        const WrParagraph(
          'Phần này đọc từ kết quả Self-Check của bạn, mà bạn thì chưa làm lần '
          'nào. Trả lời 15 câu một lượt, rồi quay lại đây.',
          style: TextStyle(
            fontSize: 16.5,
            height: 1.65,
            color: WrColors.muted,
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          key: const Key('wr_sca_deep_dive_start_self_check'),
          onPressed: () => context.push('/wr/self-check'),
          style: ElevatedButton.styleFrom(
            backgroundColor: WrColors.dark,
            foregroundColor: WrColors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Làm Self-Check',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Một trụ ở dạng rút gọn: luôn thấy tên, mức và số lần; ba lớp chữ chỉ hiện
/// khi bấm mở (§8).
class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.data,
    required this.expanded,
    required this.onToggle,
  });

  final ScaDeepDivePillar data;
  final bool expanded;
  final VoidCallback onToggle;

  // Cùng bảng màu với ba thanh điểm ở màn Kết quả Self-Check.
  Color get _accent => switch (data.pillar.name) {
        's' => const Color(0xFF5B8CC9),
        'c' => WrColors.teal,
        _ => const Color(0xFF5E7A5A),
      };

  @override
  Widget build(BuildContext context) {
    final reassuring = data.status.isReassuring;
    return Container(
      key: Key('wr_sca_deep_dive_pillar_${data.pillar.name}'),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WrColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng luôn hiện — chạm vào đâu trên hàng cũng mở được, không phải
          // nhắm đúng một mũi tên nhỏ.
          GestureDetector(
            key: Key('wr_deep_pillar_toggle_${data.pillar.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: WrParagraph(
                      data.pillarName,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: WrColors.navy,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: reassuring
                          ? const Color(0xFFE6F7F7)
                          : const Color(0xFFFFEEEB),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      data.status.label,
                      key: Key('wr_sca_deep_dive_status_${data.pillar.name}'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: reassuring
                            ? WrColors.pillTealText
                            : WrColors.pillCoralText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: WrColors.muted,
                  ),
                ],
              ),
            ),
          ),

          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lớp 2 — xu hướng.
                  WrParagraph(
                    data.trendText ?? kScaNoTrendText,
                    key: Key('wr_sca_deep_dive_trend_${data.pillar.name}'),
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      color: WrColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: WrColors.line),
                  const SizedBox(height: 10),

                  // Lớp 3 — đối chiếu Pattern Reflection.
                  WrParagraph(
                    data.patternText,
                    key: Key('wr_sca_deep_dive_pattern_${data.pillar.name}'),
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      color: WrColors.muted,
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
