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
            ? _Body(ref: ref)
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

class _Body extends StatelessWidget {
  const _Body({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final history =
        ref.watch(wrSelfCheckHistoryProvider).valueOrNull ?? const [];
    final episodes = ref.watch(wrEpisodeHistoryProvider).valueOrNull ?? const [];
    final situations = ref.watch(wrSituationsProvider).valueOrNull ?? const [];

    final pillars = buildScaDeepDive(
      history: history,
      episodes: episodes,
      situations: situations,
      now: nowVn(),
    );

    if (pillars.isEmpty) return const _Empty();

    final previous = () {
      final scored = scoredSelfChecks(history);
      return scored.length > 1 ? scored[1] : null;
    }();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
      children: [
        const WrParagraph(
          'Đối chiếu điểm Self-Check với chính bạn qua thời gian, và với những '
          'điều lặp lại bạn đã ghi khi nhìn lại.',
          style: TextStyle(
            fontSize: 14.5,
            height: 1.65,
            color: WrColors.muted,
          ),
        ),
        const SizedBox(height: 20),
        for (final p in pillars) ...[
          _PillarCard(data: p),
          const SizedBox(height: 12),
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

/// Một trụ, ba lớp xếp dọc, ngăn nhau bằng một đường mảnh.
class _PillarCard extends StatelessWidget {
  const _PillarCard({required this.data});

  final ScaDeepDivePillar data;

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WrColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lớp 1 — mức điểm hiện tại.
          Row(
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
            ],
          ),
          const SizedBox(height: 10),

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
    );
  }
}
