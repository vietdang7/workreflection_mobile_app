// Một chủ đề thực hành — mockup v47 `practiceDetail`.
//
// Thứ tự khối, đúng mockup:
//   nguồn + "Giai đoạn x/4" → tên chủ đề → thẻ teal "Điều bạn từng viết" →
//   (chủ đề tự thêm) "Thông tin bạn đã thêm" → (vừa đánh dấu) thẻ "Cột mốc mới
//   / Đã ghi nhận" → "Bước tiếp theo" → "Bạn muốn thử cách nào?" (ba cách, mỗi
//   cách có Phù hợp / Đánh đổi) → "Cách bạn chọn" + "Lưu cách tôi muốn thử" →
//   "Tôi đã thử" → danh sách bốn bước, mỗi bước có ghi chú viết ngay tại chỗ.
//
// Ngoài mockup, giữ theo chữ khách: khối "Giai đoạn duy trì" của kỹ năng
// (khách 04/08) sau khi đã khép các bước.
//
// Bước Premium mờ đi và có lối mở khoá; giấu hẳn thì người dùng không biết mình
// đang bỏ lỡ gì (Hai Lớp v1.2 §IV).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_practice_v47.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/models/wr_mood_content.dart' show PracticeStepNote;
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_text.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_back_circle.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_paragraph.dart';
import '../../../core/widgets/wr_small_button.dart';
import '../../../core/widgets/wr_voice_field.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'wr_practice_note_sheet.dart';
import 'wr_practice_step_completion.dart';
import 'wr_skill_moment.dart';

class WrPracticeThemeScreen extends ConsumerStatefulWidget {
  const WrPracticeThemeScreen({super.key, required this.themeId});

  final String themeId;

  @override
  ConsumerState<WrPracticeThemeScreen> createState() =>
      _WrPracticeThemeScreenState();
}

class _WrPracticeThemeScreenState extends ConsumerState<WrPracticeThemeScreen> {
  /// id của cách đang chọn. Null = chưa chọn (hoặc đang lấy từ cách đã lưu).
  String? _picked;

  /// Bước đang mở ô "Bạn đã thử như thế nào?".
  String? _writingStep;
  final _note = TextEditingController();

  /// Thẻ "Cột mốc mới / Đã ghi nhận" sau lần đánh dấu gần nhất.
  PracticeStepCompletion? _notice;

  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _saveChoice(PracticeMentorOption option) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(wrIntelligenceRepositoryProvider)
          .setPendingChoice(
            userId: userId,
            themeId: widget.themeId,
            choice: option.title,
          );
      ref.invalidate(practiceEnrollmentsProvider);
    } catch (_) {
      /* thử lại được: nút vẫn còn */
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete({
    required PracticeTheme theme,
    required PracticeEnrollment enrollment,
    required PracticeStep step,
    required List<PracticeStep> steps,
    required bool withNote,
    String? choice,
  }) async {
    if (_busy) return;
    final note = _note.text.trim();
    setState(() => _busy = true);
    try {
      final result = await completePracticeStep(
        context: context,
        ref: ref,
        theme: theme,
        enrollment: enrollment,
        stepId: step.stepId,
        allSteps: steps,
        presetNote: withNote && note.isNotEmpty
            ? PracticeNoteResult(
                action: PracticeNoteAction.saveWithNote,
                note: note,
              )
            : const PracticeNoteResult(action: PracticeNoteAction.skip),
        choice: choice,
      );
      if (!mounted) return;
      setState(() {
        _notice = result;
        _writingStep = null;
        _picked = null;
        _note.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final enrollments =
        ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];
    final entitlement =
        ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final notes =
        ref.watch(practiceStepNotesProvider).valueOrNull ??
        const <String, PracticeStepNote>{};
    final stepsAsync = ref.watch(practiceStepsProvider(widget.themeId));

    final theme = themes.where((t) => t.themeId == widget.themeId).firstOrNull;
    final enrollment = enrollments
        .where((e) => e.themeId == widget.themeId)
        .firstOrNull;

    if (theme == null) {
      return _Shell(
        children: [
          Text(tr('Không tìm thấy chủ đề', 'Theme not found'), style: _h1),
          const SizedBox(height: 8),
          Text(
            tr(
              'Chủ đề này không còn nữa. Quay lại tab Phát triển để chọn chủ đề khác.',
              'This theme is gone. Go back to the Grow tab and pick another.',
            ),
            key: const Key('wr_practice_theme_gone'),
            style: _muted,
          ),
        ],
      );
    }

    final steps = (stepsAsync.valueOrNull ?? const <PracticeStep>[]).toList()
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    final completed = enrollment?.completedSteps ?? const <String>[];
    final doneCount = steps.where((s) => completed.contains(s.stepId)).length;
    final next = steps.where((s) => !completed.contains(s.stepId)).firstOrNull;
    final options = mentorOptionsFor(theme);
    final saved = enrollment?.pendingChoice;
    final pickedId =
        _picked ??
        (saved == null
            ? null
            : options.where((o) => o.title == saved).firstOrNull?.id);
    final selected = options.where((o) => o.id == pickedId).firstOrNull;
    final isSaved = selected != null && saved == selected.title;
    final nextLocked =
        next != null &&
        next.isPremium &&
        !entitlement.canAccessPracticeStep(isPremiumStep: true);
    final stage = steps.isEmpty
        ? 0
        : (doneCount + 1).clamp(1, steps.length).toInt();
    final doneColor = theme.isUserAdded ? WrColors.navy : WrColors.teal;

    return _Shell(
      children: [
        // ── Nguồn + giai đoạn ───────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: WrEyebrow(
                practiceThemeSourceLabel(theme, enrollment?.startedAt),
              ),
            ),
            if (steps.isNotEmpty)
              _Pill(
                key: const Key('wr_practice_theme_progress'),
                label: tr(
                  'Giai đoạn $stage/${steps.length}',
                  'Stage $stage/${steps.length}',
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(theme.title, style: _h1),
        if (theme.isUserAdded && enrollment?.startedAt != null) ...[
          const SizedBox(height: 5),
          Text(
            tr(
              'Bạn bắt đầu chủ đề này từ ${_dm(enrollment!.startedAt!)}.',
              'You started this theme on ${_dm(enrollment.startedAt!)}.',
            ),
            style: _tiny,
          ),
        ],
        const SizedBox(height: 14),

        // ── Điều bạn từng viết ──────────────────────────────────────────
        Container(
          key: const Key('wr_practice_written'),
          padding: WrCard.kPadding,
          decoration: BoxDecoration(
            color: WrColors.teal.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(WrCard.kRadius),
            border: Border.all(color: WrColors.teal.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WrEyebrow(
                tr('ĐIỀU BẠN TỪNG VIẾT', 'WHAT YOU ONCE WROTE'),
                color: WrColors.pillTealText,
              ),
              const SizedBox(height: 5),
              Text(
                theme.isUserAdded
                    ? tr(
                        'Các cách dưới đây dựa trên chính thông tin bạn đã '
                            'thêm. Bạn sẽ luôn có thể sửa lại phần mô tả nếu '
                            'hoàn cảnh thay đổi.',
                        'The ways below are based on what you added. You can '
                            'always change the description if things change.',
                      )
                    : (theme.description?.trim().isNotEmpty ?? false)
                    ? theme.description!.trim()
                    : tr(
                        'Bạn đã từng nhìn lại những tình huống liên quan đến '
                            'chủ đề này. Không cần làm lại giống lần trước; lần '
                            'này bạn có thể chọn một cách khác.',
                        'You have looked back on situations related to this '
                            'theme. No need to repeat last time; this time you '
                            'can pick a different way.',
                      ),
                style: _muted,
              ),
            ],
          ),
        ),

        // ── Thông tin bạn đã thêm ───────────────────────────────────────
        if (theme.isUserAdded && theme.intake != null) ...[
          const SizedBox(height: 14),
          Container(
            key: const Key('wr_practice_intake'),
            width: double.infinity,
            padding: WrCard.kPadding,
            decoration: BoxDecoration(
              color: WrColors.navy.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(WrCard.kRadius),
              border: Border.all(color: WrColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrEyebrow(tr('THÔNG TIN BẠN ĐÃ THÊM', 'WHAT YOU ADDED')),
                const SizedBox(height: 8),
                Text(tr('Đang xảy ra', 'What is happening'), style: _tiny),
                Text(theme.intake!.situation, style: _muted),
                const SizedBox(height: 8),
                Text(
                  tr('Bạn muốn khác đi', 'What you want to change'),
                  style: _tiny,
                ),
                Text(theme.intake!.goal, style: _muted),
                if (theme.intake!.tried?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text(tr('Đã thử', 'Already tried'), style: _tiny),
                  Text(theme.intake!.tried!, style: _muted),
                ],
              ],
            ),
          ),
        ],

        // ── Cột mốc mới / Đã ghi nhận ──────────────────────────────────
        if (_notice != null) ...[
          const SizedBox(height: 14),
          Container(
            key: const Key('wr_practice_notice'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: WrColors.coral.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(14),
              ),
              border: const Border(
                left: BorderSide(color: WrColors.coral, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrEyebrow(
                  _notice!.firstMilestone
                      ? tr('CỘT MỐC MỚI', 'NEW MILESTONE')
                      : tr('ĐÃ GHI NHẬN', 'RECORDED'),
                  color: WrColors.pillCoralText,
                ),
                const SizedBox(height: 5),
                Text(practiceStepAction(_notice!.stepTitle), style: _cardTitle),
                const SizedBox(height: 5),
                Text(
                  tr(
                    'Đã lưu vào Career Memory · Hành trình của bạn',
                    'Saved to Career Memory · Your journey',
                  ),
                  style: _tiny,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),

        if (next != null) ...[
          // ── Bước tiếp theo ────────────────────────────────────────────
          WrEyebrow(tr('BƯỚC TIẾP THEO', 'NEXT STEP')),
          const SizedBox(height: 6),
          Text(
            wrKeepWords(practiceStepAction(next.title)),
            key: const Key('wr_practice_next_step'),
            style: _h2,
          ),
          if (next.content?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(wrKeepWords(next.content!.trim()), style: _muted),
          ],
          if (enrollment != null && !nextLocked) ...[
            const SizedBox(height: 18),

            // ── Bạn muốn thử cách nào? ──────────────────────────────────
            Text(
              tr('Bạn muốn thử cách nào?', 'Which way do you want to try?'),
              style: _h2,
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Không có cách đúng nhất. Hãy chọn cách hợp với hoàn cảnh của '
                    'bạn lúc này.',
                'There is no single right way. Pick the one that fits where you '
                    'are right now.',
              ),
              style: _muted,
            ),
            const SizedBox(height: 11),
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _MentorCard(
                key: Key('wr_practice_option_${options[i].id}'),
                option: options[i],
                selected: options[i].id == pickedId,
                onTap: () => setState(() => _picked = options[i].id),
              ),
            ],

            // ── Cách bạn chọn ───────────────────────────────────────────
            if (selected != null) ...[
              const SizedBox(height: 14),
              Container(
                key: const Key('wr_practice_choice'),
                width: double.infinity,
                padding: WrCard.kPadding,
                decoration: BoxDecoration(
                  color: WrColors.coral.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(WrCard.kRadius),
                  border: Border.all(
                    color: WrColors.coral.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WrEyebrow(
                      tr('CÁCH BẠN CHỌN', 'THE WAY YOU PICKED'),
                      color: WrColors.pillCoralText,
                    ),
                    const SizedBox(height: 6),
                    Text(selected.title, style: _cardTitle),
                    const SizedBox(height: 7),
                    Text(practiceStepAction(next.title), style: _muted),
                    if (!isSaved) ...[
                      const SizedBox(height: 11),
                      WrSmallButton(
                        key: const Key('wr_practice_save_choice'),
                        label: tr(
                          'Lưu cách tôi muốn thử',
                          'Save the way I want to try',
                        ),
                        onTap: _busy ? null : () => _saveChoice(selected),
                      ),
                    ] else ...[
                      const SizedBox(height: 9),
                      Text(
                        tr(
                          'Đã lưu. Khi có dịp, hãy thử trong đời thật.',
                          'Saved. When the moment comes, try it for real.',
                        ),
                        key: const Key('wr_practice_choice_saved'),
                        style: _tiny.copyWith(
                          color: WrColors.pillTealText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      WrSmallButton(
                        key: const Key('wr_practice_tried'),
                        kind: WrSmallButtonKind.dark,
                        arrow: true,
                        label: tr('Tôi đã thử', 'I tried it'),
                        onTap: () => setState(() {
                          _writingStep = next.stepId;
                          _note.clear();
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ] else ...[
          Container(
            key: const Key('wr_practice_all_done'),
            width: double.infinity,
            padding: WrCard.kPadding,
            decoration: BoxDecoration(
              color: WrColors.teal.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(WrCard.kRadius),
              border: Border.all(color: WrColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'Bạn đã đi hết các bước hiện tại.',
                    'You have gone through all the current steps.',
                  ),
                  style: _h2,
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    'Đây là lúc nhìn lại điều đã thay đổi, thay vì tạo thêm '
                        'việc để làm.',
                    'This is the time to look at what changed, rather than '
                        'adding more to do.',
                  ),
                  style: _muted,
                ),
              ],
            ),
          ),
        ],
        if (enrollment?.completedAt != null) ...[
          const SizedBox(height: 14),
          _MaintainBlock(theme: theme),
        ],
        const SizedBox(height: 14),

        // ── Danh sách bước ──────────────────────────────────────────────
        if (steps.isEmpty)
          Text(
            tr('Chủ đề này chưa có bước nào.', 'This theme has no steps yet.'),
            style: _muted,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: WrColors.white,
              borderRadius: BorderRadius.circular(WrCard.kRadius),
              border: Border.all(color: WrColors.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _StepRow(
                    step: steps[i],
                    index: i,
                    last: i == steps.length - 1,
                    doneColor: doneColor,
                    isDone: completed.contains(steps[i].stepId),
                    note: notes[steps[i].stepId]?.note,
                    isLocked:
                        steps[i].isPremium &&
                        !entitlement.canAccessPracticeStep(isPremiumStep: true),
                    canAct: enrollment != null && !_busy,
                    writing: _writingStep == steps[i].stepId,
                    noteController: _note,
                    onStart: () => setState(() {
                      _writingStep = steps[i].stepId;
                      _note.clear();
                    }),
                    onCancel: () => setState(() => _writingStep = null),
                    onSave: (withNote) => _complete(
                      theme: theme,
                      enrollment: enrollment!,
                      step: steps[i],
                      steps: steps,
                      withNote: withNote,
                      // Chỉ cách đã bấm "Lưu cách tôi muốn thử"; chạm
                      // chọn mà chưa lưu thì chưa phải lựa chọn.
                      choice: steps[i].stepId == next?.stepId ? saved : null,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static String _dm(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}';
  }
}

/// Khung màn: nút lùi tròn + nội dung cuộn.
class _Shell extends StatelessWidget {
  const _Shell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: WrBackCircle(
                key: const Key('wr_practice_back'),
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/wr/growth'),
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// `.rf-mentor-card` — một cách, có "Phù hợp" và "Đánh đổi".
class _MentorCard extends StatelessWidget {
  const _MentorCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PracticeMentorOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String text) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${label.toUpperCase()}  ',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: WrColors.text3,
              ),
            ),
            TextSpan(text: wrKeepWords(text)),
          ],
        ),
        style: const TextStyle(
          fontSize: 12.5,
          color: WrColors.text2,
          height: 1.5,
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? WrColors.coral.withValues(alpha: 0.045)
              : WrColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? WrColors.coral
                : WrColors.navy.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(option.title, style: _cardTitle),
            const SizedBox(height: 3),
            row(tr('Phù hợp', 'Fits'), option.fit),
            row(tr('Đánh đổi', 'Trade-off'), option.tradeoff),
            if (selected) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check, size: 14, color: WrColors.coral),
                  const SizedBox(width: 5),
                  Text(
                    tr(
                      'Bạn đang cân nhắc cách này',
                      'You are considering this way',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: WrColors.coral,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Một bước trong danh sách bốn bước.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.last,
    required this.doneColor,
    required this.isDone,
    required this.note,
    required this.isLocked,
    required this.canAct,
    required this.writing,
    required this.noteController,
    required this.onStart,
    required this.onCancel,
    required this.onSave,
  });

  final PracticeStep step;
  final int index;
  final bool last;
  final Color doneColor;
  final bool isDone;
  final String? note;
  final bool isLocked;
  final bool canAct;
  final bool writing;
  final TextEditingController noteController;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final ValueChanged<bool> onSave;

  @override
  Widget build(BuildContext context) {
    final tag = practiceStageTag(step.stepOrder);
    return Opacity(
      opacity: isLocked && !isDone ? 0.55 : 1,
      child: Container(
        key: Key('wr_practice_step_${step.stepId}'),
        padding: WrCard.kPadding,
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: WrColors.lineSoft)),
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
                    ? doneColor
                    : WrColors.navy.withValues(alpha: 0.08),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 15, color: WrColors.white)
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag != null) ...[
                    Text(
                      tag,
                      style: _tiny.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    practiceStepAction(step.title),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: WrColors.navy,
                      height: 1.4,
                    ),
                  ),
                  if (step.content?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(step.content!.trim(), style: _muted),
                  ],
                  if (isDone)
                    if (note?.trim().isNotEmpty ?? false)
                      Container(
                        margin: const EdgeInsets.only(top: 9),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: WrColors.teal.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('Bạn đã ghi lại', 'You wrote down'),
                              style: _tiny.copyWith(
                                color: WrColors.pillTealText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '“${note!.trim()}”',
                              style: WrText.serifQuote(
                                fontSize: 14,
                                color: WrColors.text2,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          tr(
                            'Đã đánh dấu, bạn không ghi chú gì lần này.',
                            'Marked done, no note this time.',
                          ),
                          style: _tiny.copyWith(
                            color: WrColors.text3.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                  else if (isLocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: GestureDetector(
                        key: Key('wr_practice_step_unlock_${step.stepId}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            context.push('/wr/paywall?trigger=practice_step'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 13,
                              color: WrColors.pillCoralText,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              tr('Premium · Mở khoá', 'Premium · Unlock'),
                              style: _tiny.copyWith(
                                color: WrColors.pillCoralText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (writing)
                    _NoteWriter(
                      stepId: step.stepId,
                      controller: noteController,
                      enabled: canAct,
                      onSave: onSave,
                      onCancel: onCancel,
                    )
                  else if (canAct)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: WrSmallButton(
                        key: Key('wr_practice_step_done_${step.stepId}'),
                        kind: WrSmallButtonKind.ghost,
                        label: tr('Tôi đã thử bước này', 'I tried this step'),
                        onTap: onStart,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Bạn đã thử như thế nào?" · Lưu lại · Chỉ đánh dấu · Để sau.
class _NoteWriter extends StatefulWidget {
  const _NoteWriter({
    required this.stepId,
    required this.controller,
    required this.enabled,
    required this.onSave,
    required this.onCancel,
  });

  final String stepId;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<bool> onSave;
  final VoidCallback onCancel;

  @override
  State<_NoteWriter> createState() => _NoteWriterState();
}

class _NoteWriterState extends State<_NoteWriter> {
  @override
  void initState() {
    super.initState();
    // "Tôi đã thử" ở thẻ bước tiếp theo mở ô viết trong danh sách bước bên
    // dưới; cuộn tới để người dùng thấy ngay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('wr_practice_writer_${widget.stepId}'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Bạn đã thử như thế nào?', 'How did it go?'),
            style: _tiny.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          WrVoiceField(
            fieldKey: const Key('wr_practice_note_field'),
            controller: widget.controller,
            hintText: tr(
              'Ví dụ: Mình đã hỏi lại một câu trong cuộc họp sáng nay, và '
                  'không khó như mình tưởng.',
              'For example: I asked a follow-up question in this morning’s '
                  'meeting, and it was easier than I thought.',
            ),
            italic: true,
            minLines: 3,
            maxLines: 6,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: WrSmallButton(
                  key: const Key('wr_practice_note_save'),
                  label: tr('Lưu lại', 'Save'),
                  onTap:
                      widget.enabled && widget.controller.text.trim().isNotEmpty
                      ? () => widget.onSave(true)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: WrSmallButton(
                  key: const Key('wr_practice_note_skip'),
                  kind: WrSmallButtonKind.ghost,
                  label: tr('Chỉ đánh dấu', 'Just mark it'),
                  onTap: widget.enabled ? () => widget.onSave(false) : null,
                ),
              ),
            ],
          ),
          Center(
            child: TextButton(
              key: const Key('wr_practice_note_later'),
              onPressed: widget.onCancel,
              style: TextButton.styleFrom(foregroundColor: WrColors.text3),
              child: Text(
                tr('Để sau', 'Later'),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.pill.pill-navy`.
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: WrColors.navy.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: WrColors.navy,
      ),
    ),
  );
}

/// `.h1` (21px).
const _h1 = TextStyle(
  fontSize: 21,
  fontWeight: FontWeight.w800,
  color: WrColors.navy,
  height: 1.32,
);

/// `.h2` (15.5px) +1.5.
const _h2 = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  color: WrColors.navy,
  height: 1.35,
);

/// Chữ đậm 13–13.5px trong thẻ, +1.5.
const _cardTitle = TextStyle(
  fontSize: 14.5,
  fontWeight: FontWeight.w700,
  color: WrColors.navy,
  height: 1.42,
);

/// `.muted` (12.5px) +1.5.
const _muted = TextStyle(fontSize: 14, color: WrColors.text2, height: 1.6);

/// `.tiny` (11px) +1.5.
const _tiny = TextStyle(fontSize: 12.5, color: WrColors.text3);

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
                ? tr('ĐÃ THÀNH KỸ NĂNG', 'NOW A SKILL')
                : tr('GIAI ĐOẠN DUY TRÌ', 'UPKEEP STAGE'),
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
                ? tr(
                    'Bạn đã thực hành điều này ${formation.practiceCount} lần. '
                        'Ghi nhận tiếp mỗi khi bạn dùng tới nó.',
                    'You have practised this ${formation.practiceCount} times. '
                        'Keep recording it whenever you use it.',
                  )
                : tr(
                    'Đã ${formation.practiceCount}/${formation.threshold} lần. '
                        'Còn ${formation.remaining} lần nữa là điều này thành kỹ '
                        'năng của bạn.',
                    '${formation.practiceCount}/${formation.threshold} so far. '
                        '${formation.remaining} more and this becomes a skill of '
                        'yours.',
                  ),
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
