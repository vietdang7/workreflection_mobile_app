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

import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_deep_interpretation.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_polish_guard.dart';
import '../../../core/logic/wr_repeated_situations.dart';
import '../../../core/logic/wr_sca_deep_dive.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/logic/vn_date.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../wr_providers.dart';
import 'wr_discover_screen.dart' show WrPatternRow;

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
        title: Text(
          tr('Diễn giải sâu & xu hướng', 'Deep reading & trends'),
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
        WrParagraph(
          tr('Phần này đọc kỹ từng mặt theo khoảng điểm của bạn, so với những lần '
          'tự soi trước, và đối chiếu với những tình huống bạn hay gặp khi nhìn '
          'lại.', 'This reads each side closely against your score band, sets it beside '
          'your earlier self-checks, and compares it with the situations you '
          'meet most when looking back.'),
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
          child: Text(
            tr('Mở diễn giải sâu', 'Open the deep reading'),
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thân màn — MỘT insight dẫn dắt, rồi những vòng lặp, rồi xu hướng
// ---------------------------------------------------------------------------
//
// `DienGiaiSau v1 §8` nói thẳng vì sao phải đảo lại: "Bản Diễn giải sâu hiện
// tại đang hiển thị 3 trụ nhân 3 lớp thông tin, thành 9 khối văn bản. Đó là một
// bản báo cáo, và người dùng sẽ đọc lướt rồi bỏ qua."
//
// Thứ tự của `DienGiaiSau v2 §7`:
//   1 · Khối chính — đúng một nội dung từ thang ưu tiên năm bậc.
//   2 · Những vòng lặp quen thuộc — danh sách tình huống kèm số lần.
//   3 · Xu hướng — chỉ hiện khi đã đủ dữ liệu.
//   4 · Xem chi tiết theo nhóm — đóng mặc định.
//   5 · Một dòng duy nhất cho những tầng còn đang chờ.
//
// BA ĐIỀU §7 ĐỔI SO VỚI BẢN TRƯỚC, và vì sao.
//
//   · Thêm khối "những vòng lặp quen thuộc". Nó là chính lớp dữ liệu mà cả năm
//     bậc đang đọc, nên bày ra để người dùng kiểm chứng được câu ở khối chính
//     thay vì phải tin.
//
//   · Khối "Từng trụ một" đổi tên thành "Xem chi tiết theo nhóm", đóng mặc
//     định, và ĐỔI HẲN NỘI DUNG. §1.3: khối cũ hiện nhãn mức đánh giá và số lần
//     xuất hiện — cả hai đã có nguyên ở Career Snapshot bản miễn phí — cộng một
//     câu gần như giống hệt nhau ba lần. Nay mỗi trụ liệt kê tình huống cụ thể
//     của chính nó, là thứ Career Snapshot không có.
//
//   · Hai đoạn chờ dài rút thành một dòng ở cuối. §6: "hai đoạn giải thích dài
//     về việc chờ thêm đang chiếm nhiều diện tích hơn cả phần nội dung thật,
//     khiến màn hình trông như toàn lời hẹn."
//
// "Một insight được đọc kỹ có giá trị hơn chín insight bị lướt qua."

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final Set<String> _open = {};

  /// Lớp 3 — câu AI viết lại, nếu có; không thì chính câu gốc (§7).
  ///
  /// [allowed] false là câu chỉ dẫn của mục 6: §7.3 cấm nhờ AI viết lại chúng.
  ///
  /// KHÔNG chờ, KHÔNG hiện vòng xoay. §7.2 rào chắn 3 nói rõ người dùng không
  /// bao giờ được thấy màn hình trống ở đây; nên lượt dựng đầu tiên hiện câu
  /// gốc, và nếu bản viết lại về kịp thì Riverpod dựng lại với câu mới. Người
  /// dùng thấy chữ ngay từ khung đầu tiên trong mọi trường hợp.
  ///
  /// Cờ tắt (mặc định) thì provider trả null ngay, không đi mạng.
  String _polished(String original, {required bool allowed}) {
    if (!allowed || !kPolishEnabled) return original;
    final polished = ref.watch(wrPolishedTextProvider(original)).valueOrNull;
    return polishedOrOriginal(original: original, polished: polished);
  }

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

    // Ba nguồn, không nguồn nào có gì để nói: chưa Self-Check lần nào, chưa đủ
    // 15 lần nhìn lại, và tầng 2 cũng chưa mở. Chỉ lúc đó mới là màn mời gọi.
    //
    // Vế `leadUnlocked` là vế MỚI. Bốn trong năm bậc của thang ưu tiên đọc từ
    // tình huống chứ không đọc từ điểm Self-Check (v2 §4), nên người đã nhìn lại
    // đủ nhiều mà chưa tự đánh giá lần nào vẫn có một khối chính đầy đủ để đọc.
    final f = content.facts;
    if (pillars.isEmpty && !f.leadUnlocked && !f.tier2Unlocked) {
      return const _Empty();
    }

    final previous = () {
      final scored = scoredSelfChecks(history);
      return scored.length > 1 ? scored[1] : null;
    }();

    final loops = f.situations
        .where((s) => s.count >= kRepeatedSituationsMinCount)
        .toList();
    final maxLoop = loops.fold<int>(1, (m, s) => s.count > m ? s.count : m);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
      children: [
        // ── 1 · Khối chính ──────────────────────────────────────────────
        _LeadCard(
          text: _polished(
            content.leadText,
            allowed: content.rung != null &&
                !deepTextIsGuidance(content.leadText),
          ),
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

        // ── 2 · Những vòng lặp quen thuộc ───────────────────────────────
        //
        // §7 khối phụ: "dạng danh sách tình huống kèm số lần. Có thể tái dùng
        // component đã có ở tab Hiểu mình." Dùng đúng `WrPatternRow` của màn
        // kia, nên hai màn không thể vẽ ra hai kiểu hàng khác nhau.
        //
        // Cửa sổ ở đây là $kScaPatternWindowDays NGÀY, còn tab Hiểu mình đếm
        // trên 30 MỤC gần nhất. Hai đơn vị khác nhau nên hai màn có thể ra hai
        // con số cho cùng một tình huống — dòng chú thích cuối màn nói rõ cửa sổ
        // của màn này, và đó là lý do nó phải ở lại.
        if (loops.isNotEmpty) ...[
          const SizedBox(height: 26),
          WrEyebrow(tr('NHỮNG VÒNG LẶP QUEN THUỘC', 'FAMILIAR LOOPS')),
          const SizedBox(height: 12),
          for (final s in loops) ...[
            WrPatternRow(
              key: Key('wr_deep_loop_${s.code}'),
              label: s.label,
              count: s.count,
              ratio: s.count / maxLoop,
              onTap: () => context.push('/wr/pattern/${s.code}'),
            ),
            if (s != loops.last) const SizedBox(height: 16),
          ],
        ],

        // ── 3 · Xu hướng ────────────────────────────────────────────────
        //
        // Cả khối vắng mặt khi chưa đủ dữ liệu — §6 điều chỉnh 2. Lời hẹn dồn
        // xuống một dòng ở cuối màn.
        if (content.hasTrendBlock) ...[
          const SizedBox(height: 26),
          WrEyebrow(tr('XU HƯỚNG', 'TRENDS')),
          const SizedBox(height: 12),
          if (content.realTrendText case final String t)
            WrParagraph(
              _polished(t, allowed: true),
              key: const Key('wr_deep_trend'),
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
                color: WrColors.muted,
              ),
            ),
          if (content.realSelfCheckTrendText case final String t) ...[
            if (content.realTrendText != null) const SizedBox(height: 14),
            WrParagraph(
              _polished(t, allowed: true),
              key: const Key('wr_deep_self_check_trend'),
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
                color: WrColors.muted,
              ),
            ),
          ],
        ],

        // ── 4 · Xem chi tiết theo nhóm, đóng mặc định ───────────────────
        if (pillars.isNotEmpty) ...[
          const SizedBox(height: 26),
          WrEyebrow(tr('XEM CHI TIẾT THEO NHÓM', 'DETAIL BY GROUP')),
          const SizedBox(height: 12),
          for (final p in pillars) ...[
            _PillarCard(
              data: p,
              situations: f.situationsOf(p.pillar),
              expanded: _open.contains(p.pillar.name),
              onToggle: () => setState(() {
                if (!_open.remove(p.pillar.name)) _open.add(p.pillar.name);
              }),
            ),
            const SizedBox(height: 10),
          ],
        ] else ...[
          // Chưa Self-Check thì không có mức nào để bày. Lời mời ở đây NGẮN và
          // đứng cuối, khác hẳn bản trước: khối chính phía trên đã đầy đủ rồi,
          // nên Self-Check không còn là cửa vào mà là thứ mở thêm bậc R3.
          const SizedBox(height: 22),
          WrParagraph(
            tr('Làm bộ Self-Check ${kSelfCheckQuestions.length} câu sẽ thêm một '
                'lớp nữa vào đây: so điều bạn tự đánh giá với điều đang thực sự '
                'lặp lại.', 'Taking the ${kSelfCheckQuestions.length}-question Self-Check adds '
                'another layer here: what you rate yourself against what '
                'actually keeps repeating.'),
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
            child: Text(
              tr('Làm Self-Check', 'Take the Self-Check'),
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],

        // ── 5 · Một dòng cho những tầng còn đang chờ ────────────────────
        if (content.waitingLine case final String line) ...[
          const SizedBox(height: 22),
          WrParagraph(
            line,
            key: const Key('wr_deep_waiting_line'),
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: WrColors.text3,
            ),
          ),
        ],

        const SizedBox(height: 12),
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
            Text(
              tr('Khoảng lệch đáng chú ý', 'A gap worth noticing'),
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
        WrParagraph(
          tr('Phần này đọc từ kết quả Self-Check của bạn, mà bạn thì chưa làm lần '
          'nào. Trả lời 15 câu một lượt, rồi quay lại đây.', 'This reads from your Self-Check results, and you have not taken it '
          'yet. Answer the 15 questions in one go, then come back here.'),
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
          child: Text(
            tr('Làm Self-Check', 'Take the Self-Check'),
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Một trụ ở dạng rút gọn, đóng mặc định (§7).
///
/// HAI THỨ ĐÃ BỎ KHỎI THẺ NÀY, cả hai vì §1.3 và điều kiện nghiệm thu §9 việc 5
/// ("không có dòng thông tin nào xuất hiện giống hệt ở cả hai màn"):
///
///   · Huy hiệu mức đánh giá. Đúng bằng cột "Bạn đánh giá" của Career Snapshot.
///   · Câu đối chiếu pattern theo trụ. Nó nói lại điều khối chính vừa nói, và
///     nói ba lần với ba trụ — §1.3: "Nói với người dùng ba lần rằng không có
///     gì nổi trội thì đúng về logic nhưng vô nghĩa về trải nghiệm."
///
/// Thay vào đó là danh sách tình huống cụ thể của chính trụ ấy. Câu xu hướng
/// điểm số ở lại: nó so với LẦN SELF-CHECK TRƯỚC, và Career Snapshot không có
/// phép so đó.
class _PillarCard extends StatelessWidget {
  const _PillarCard({
    required this.data,
    required this.situations,
    required this.expanded,
    required this.onToggle,
  });

  final ScaDeepDivePillar data;

  /// Tình huống thuộc trụ này trong cửa sổ, nhiều lần nhất đứng đầu.
  final List<DeepSituation> situations;

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
                  Text(
                    situations.isEmpty
                        ? tr('chưa có', 'none yet')
                        : tr('${situations.length} tình huống',
                            '${situations.length} situations'),
                    key: Key('wr_deep_pillar_count_${data.pillar.name}'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: WrColors.muted,
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
                  // So với LẦN SELF-CHECK TRƯỚC — phép so duy nhất ở thẻ này
                  // mà Career Snapshot không có.
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

                  // Tình huống cụ thể của trụ này (§7 lưu ý cho dev: "phải thêm
                  // thông tin mới, ví dụ liệt kê các tình huống cụ thể thuộc
                  // trụ đó, chứ không lặp lại con số tổng").
                  if (situations.isEmpty)
                    WrParagraph(
                      tr('Chưa lần nhìn lại nào trong cửa sổ này rơi vào nhóm '
                          'đó.', 'No look-back in this window falls into that group.'),
                      key: Key('wr_deep_pillar_empty_${data.pillar.name}'),
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.6,
                        color: WrColors.muted,
                      ),
                    )
                  else
                    for (final s in situations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: WrParagraph(
                                s.label,
                                key: Key('wr_deep_pillar_sit_${s.code}'),
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  height: 1.5,
                                  color: WrColors.navy,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              tr('${s.count} lần', '${s.count}×'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: WrColors.muted,
                              ),
                            ),
                          ],
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
