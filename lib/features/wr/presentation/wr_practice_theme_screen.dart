// Một chủ đề thực hành — toàn bộ các bước nằm ở đây.
//
// Giao diện mẫu Sprint 2 (practiceDetail): tab Phát triển chỉ liệt kê chủ đề,
// bấm vào một chủ đề mới mở ra chuỗi bước. Nhờ vậy người dùng thấy được cả
// đường đi của chủ đề — đã qua đâu, đang ở đâu, còn gì phía trước — thay vì
// chỉ thấy đúng một bước kế tiếp.
//
// Bước Premium vẫn hiện nguyên nội dung mờ kèm nút mở khoá (Hai Lớp v1.2 §IV,
// khoá cấp nội dung): giấu hẳn thì người dùng không biết mình đang bỏ lỡ gì.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_list_card.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'wr_practice_step_completion.dart';
import 'wr_skill_moment.dart';
import '../../../core/widgets/wr_paragraph.dart';

class WrPracticeThemeScreen extends ConsumerWidget {
  const WrPracticeThemeScreen({super.key, required this.themeId});

  final String themeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final enrollments =
        ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final stepsAsync = ref.watch(practiceStepsProvider(themeId));

    final theme = themes.where((t) => t.themeId == themeId).firstOrNull;
    final enrollment =
        enrollments.where((e) => e.themeId == themeId).firstOrNull;

    if (theme == null) {
      return const WrDetailScaffold(
        eyebrow: 'THỰC HÀNH',
        title: 'Không tìm thấy chủ đề',
        children: [
          WrParagraph(
            'Chủ đề này không còn nữa. Quay lại tab Phát triển để chọn chủ đề khác.',
            key: Key('wr_practice_theme_gone'),
            style: TextStyle(fontSize: 16.5, color: WrColors.muted, height: 1.6),
          ),
        ],
      );
    }

    final steps = (stepsAsync.valueOrNull ?? const <PracticeStep>[]).toList()
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    final completed = enrollment?.completedSteps ?? const <String>[];
    final doneCount = steps.where((s) => completed.contains(s.stepId)).length;

    return WrDetailScaffold(
      // Xong ba bước KHÔNG phải là hết chuyện — chủ đề chuyển sang giai đoạn
      // duy trì. Gọi nó là "ĐÃ HOÀN THÀNH" thì người dùng đóng màn này lại và
      // không bao giờ quay lại, trong khi phần lặp lại mới là phần làm nên kỹ
      // năng.
      eyebrow: enrollment == null
          ? 'CHƯA BẮT ĐẦU'
          : (enrollment.completedAt != null
              ? 'ĐANG DUY TRÌ'
              : 'ĐANG THỰC HÀNH'),
      title: theme.title,
      children: [
        if (theme.description != null) ...[
          WrParagraph(
            theme.description!,
            style: const TextStyle(
              fontSize: 15.5,
              color: WrColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
        ],
        WrPracticeProgressDots(total: steps.length, done: doneCount),
        const SizedBox(height: 8),
        Text(
          steps.isEmpty
              ? 'Chủ đề này chưa có bước nào.'
              : '$doneCount/${steps.length} bước hoàn thành',
          key: const Key('wr_practice_theme_progress'),
          style: const TextStyle(fontSize: 14.5, color: WrColors.muted),
        ),
        const SizedBox(height: 24),
        // MỖI bước một thẻ riêng, nối nhau bằng một đoạn kẻ dọc (yêu cầu
        // 05/08). Ba bước là ba việc làm ở ba lúc khác nhau, nên chúng cần
        // ranh giới thật; nhưng chúng cũng là một chuỗi, nên phải có thứ nối
        // chúng lại — nếu không thì trông như ba việc rời rạc.
        //
        // Đoạn nối chuyển sang xanh khi bước phía trên đã xong: người dùng
        // nhìn dọc theo đường kẻ là thấy mình đang ở đâu trong chuỗi.
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            _StepConnector(
              isPassed: completed.contains(steps[i - 1].stepId),
            ),
          _StepBlock(
            step: steps[i],
            index: i,
            isDone: completed.contains(steps[i].stepId),
            isLocked: steps[i].isPremium &&
                !entitlement.canAccessPracticeStep(isPremiumStep: true),
            // Chỉ bước liền sau bước đã xong mới bấm được: chuỗi thực hành
            // đi theo thứ tự, không nhảy cóc.
            isNext: !completed.contains(steps[i].stepId) &&
                completed.length == steps[i].stepOrder - 1,
            // Không chặn theo `completedAt`: người dùng miễn phí khép giai
            // đoạn làm quen ở bước 2 (bước 3 khoá). Nâng cấp lên Premium
            // rồi thì bước "Chuyển hóa" phải bấm được, chứ không phải khoá
            // vĩnh viễn chỉ vì hôm trước đã khép chủ đề. Thứ tự vẫn do
            // `isNext` giữ.
            canAct: enrollment != null,
            onDone: () => completePracticeStep(
              context: context,
              ref: ref,
              theme: theme,
              enrollment: enrollment!,
              stepId: steps[i].stepId,
              allSteps: steps,
            ),
          ),
        ],
        if (enrollment?.completedAt != null) ...[
          const SizedBox(height: 20),
          _MaintainBlock(theme: theme),
        ],
      ],
    );
  }
}

/// Giai đoạn duy trì — mở ra sau khi ba bước làm quen đã xong.
///
/// Ba bước là làm quen với một hành vi, làm một lần. Cái biến hành vi ấy thành
/// phản xạ là những lần lặp lại sau đó; đây là chỗ ghi nhận chúng.
class _MaintainBlock extends ConsumerWidget {
  const _MaintainBlock({required this.theme});

  final PracticeTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formation = ref
        .watch(wrSkillFormationsProvider)
        .where((f) => f.themeId == theme.themeId)
        .firstOrNull;
    if (formation == null) return const SizedBox.shrink();

    return Container(
      key: const Key('wr_practice_maintain_block'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: WrColors.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formation.skillFormed
                ? 'ĐÃ THÀNH KỸ NĂNG'
                : 'GIAI ĐOẠN DUY TRÌ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: WrColors.muted,
            ),
          ),
          const SizedBox(height: 9),
          WrParagraph(
            formation.skillFormed
                ? 'Bạn đã thực hành điều này ${formation.practiceCount} lần. '
                    'Ghi nhận tiếp mỗi khi bạn dùng tới nó.'
                : 'Đã ${formation.practiceCount}/${formation.threshold} lần. '
                    'Còn ${formation.remaining} lần nữa là điều này thành kỹ '
                    'năng của bạn.',
            key: const Key('wr_practice_maintain_count'),
            style: const TextStyle(
              fontSize: 15,
              color: WrColors.navy,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          WrMaintainPracticeAction(theme: theme),
        ],
      ),
    );
  }
}

/// Dải chấm tiến độ của một chủ đề — mỗi chấm là một bước.
class WrPracticeProgressDots extends StatelessWidget {
  const WrPracticeProgressDots({
    super.key,
    required this.total,
    required this.done,
  });

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    return Row(
      children: [
        for (int i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 22,
            height: 5,
            decoration: BoxDecoration(
              color: i < done
                  ? WrColors.teal
                  : WrColors.navy.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}

/// Đoạn kẻ dọc nối hai thẻ bước liền nhau.
///
/// Ba thẻ rời nhau nói rõ ranh giới, nhưng cũng làm mất cảm giác đây là MỘT
/// chuỗi. Đoạn kẻ này trả lại điều đó. Nó nằm thẳng dưới vòng tròn số thứ tự
/// (16 lề thẻ + 13 nửa vòng tròn = 29), nên mắt đi dọc từ vòng tròn này xuống
/// vòng tròn kia.
///
/// [isPassed] = bước phía trên đã xong: đoạn kẻ chuyển sang xanh, thành một
/// thanh tiến độ dọc đọc được bằng liếc mắt.
class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.isPassed});

  final bool isPassed;

  @override
  Widget build(BuildContext context) {
    // [Align] là thứ bắt buộc, không phải trang trí: màn này dựng bằng
    // `ListView`, mà ListView ép con chiếm trọn bề ngang. Không có Align thì
    // `width: 2` bị bỏ qua và đoạn kẻ dọc biến thành một thanh ngang dày chắn
    // giữa hai thẻ.
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 28),
        child: Container(
          key: const Key('wr_practice_step_connector'),
          width: 2,
          height: 18,
          color: isPassed ? WrColors.teal : WrColors.line,
        ),
      ),
    );
  }
}

class _StepBlock extends StatelessWidget {
  const _StepBlock({
    required this.step,
    required this.index,
    required this.isDone,
    required this.isLocked,
    required this.isNext,
    required this.canAct,
    required this.onDone,
  });

  final PracticeStep step;
  final int index;
  final bool isDone;
  final bool isLocked;
  final bool isNext;
  final bool canAct;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tag = practiceStageTag(step.stepOrder);

    // Xong rồi thì thẻ mờ hẳn đi (yêu cầu 05/08): việc đã làm lùi lại phía
    // sau, nhường chỗ cho bước đang chờ. Vẫn đọc được, chỉ là thôi tranh mắt.
    // Bước khoá mờ nhẹ hơn — nó chưa làm được, nhưng cũng chưa xong.
    return Opacity(
      opacity: isDone
          ? 0.55
          : isLocked
              ? 0.72
              : 1,
      child: Container(
        key: Key('wr_practice_step_${step.stepId}'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: WrColors.white,
          border: Border.all(color: WrColors.line),
          borderRadius: BorderRadius.circular(kWrCardRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? WrColors.teal
                    : WrColors.navy.withValues(alpha: 0.08),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 15, color: WrColors.white)
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLocked) ...[
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 13, color: WrColors.amber),
                        SizedBox(width: 5),
                        Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: WrColors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (tag != null) ...[
                    Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: WrColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Xong rồi thì dấu tick nói đủ. KHÔNG gạch ngang chữ (yêu
                  // cầu 05/08): gạch ngang là cách đánh dấu một việc bị huỷ
                  // hay một câu viết sai, không phải một việc vừa làm được —
                  // và nó làm chính dòng chữ người dùng vừa hoàn thành trở
                  // thành thứ khó đọc nhất màn hình.
                  WrParagraph(
                    step.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: isDone ? WrColors.muted : WrColors.navy,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  if (step.content != null && step.content!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    WrParagraph(
                      step.content!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: WrColors.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                  if (isLocked) ...[
                    const SizedBox(height: 12),
                    _StepButton(
                      key: Key('wr_practice_step_unlock_${step.stepId}'),
                      label: 'Mở khoá bước này',
                      onTap: () =>
                          context.push('/wr/paywall?trigger=practice_step'),
                    ),
                  ] else if (!isDone && isNext && canAct) ...[
                    const SizedBox(height: 12),
                    _StepButton(
                      key: Key('wr_practice_step_done_${step.stepId}'),
                      label: 'Đánh dấu hoàn thành',
                      onTap: onDone,
                    ),
                  ] else if (!isDone && !isNext) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Xong bước trước rồi mở tiếp',
                      style: TextStyle(fontSize: 13.5, color: WrColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: WrColors.navy,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: WrColors.white,
          ),
        ),
      ),
    );
  }
}
