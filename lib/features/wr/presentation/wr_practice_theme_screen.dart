// Một chủ đề thực hành — script Sprint 2 `practiceDetail`.
//
// Thứ tự khối, đúng script:
//   eyebrow "Đang thực hành" / "Tự thêm" → tên chủ đề → "Điều bạn từng viết"
//   → "Bốn bước làm quen · n / 4" + câu chú thích → danh sách bốn bước →
//   (hết các bước) thẻ "Hết một vòng" hoặc "Đang duy trì".
//
// Mỗi bước ở một trong ba trạng thái:
//   done : đã thử, thu lại một dòng, hiện ghi chú nếu có
//   on   : bước đang làm, mở ra, có nút "Tôi đã thử bước này"
//   next : chưa tới, chỉ một dòng mờ, không mô tả
// Ba cách ở bước 3 KHÔNG xổ tại chỗ: một dòng "Xem ba cách gợi ý" dẫn sang màn
// riêng (`WrStepOptionsScreen`).
//
// Giữ theo luật gói hiện hành (không có trong script): bước 4 khoá Premium với
// bản miễn phí, có lối "Premium · Mở khoá" sang paywall. Giấu hẳn thì người
// dùng không biết mình đang bỏ lỡ gì (Hai Lớp v1.2 §IV).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../core/widgets/wr_small_button.dart';
import '../../../core/widgets/wr_voice_field.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'wr_practice_note_sheet.dart';
import 'wr_practice_step_completion.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

class WrPracticeThemeScreen extends ConsumerStatefulWidget {
  const WrPracticeThemeScreen({super.key, required this.themeId});

  final String themeId;

  @override
  ConsumerState<WrPracticeThemeScreen> createState() =>
      _WrPracticeThemeScreenState();
}

class _WrPracticeThemeScreenState extends ConsumerState<WrPracticeThemeScreen> {
  /// Bước đang mở ô ghi (script `openStepNote`).
  String? _writingStep;
  final _note = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
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
      await completePracticeStep(
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
        _writingStep = null;
        _note.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moveToKeep(
    PracticeTheme theme,
    PracticeEnrollment enrollment,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await movePracticeThemeToKeep(
        ref: ref,
        theme: theme,
        enrollment: enrollment,
      );
      if (!mounted) return;
      if (ok) {
        // Script `moveToKeep`: chuyển thẳng sang màn Tâm thế & duy trì.
        context.pushReplacement('/wr/growth/stance-keep');
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              wrKeepCompounds(tr(
                'Chưa ghi nhận được. Thử lại.',
                'Could not save it. Try again.',
              )),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openOptions() => context.push('/wr/practice-options/${widget.themeId}');

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
          Text(wrKeepCompounds(tr('Không tìm thấy chủ đề', 'Theme not found')), style: _h1),
          const SizedBox(height: 8),
          Text(
            wrKeepCompounds(tr(
              'Chủ đề này không còn nữa. Quay lại tab Phát triển để chọn chủ đề khác.',
              'This theme is gone. Go back to the Grow tab and pick another.',
            )),
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
    final current = steps.indexWhere((s) => !completed.contains(s.stepId));
    final options = step3OptionsFor(theme);
    final step3 = steps.where((s) => s.stepOrder == 3).firstOrNull;
    final chosen =
        findPracticeOption(options, enrollment?.pendingChoice) ??
        findPracticeOption(options, notes[step3?.stepId]?.choice);
    final allDone =
        enrollment != null &&
        steps.isNotEmpty &&
        practiceReachableDone(
          steps: steps,
          completed: completed,
          entitlement: entitlement,
        );

    bool locked(PracticeStep s) =>
        s.isPremium && !entitlement.canAccessPracticeStep(isPremiumStep: true);

    return _Shell(
      children: [
        WrEyebrow(
          theme.isUserAdded
              ? tr('Tự thêm', 'Added by you')
              : tr('Đang thực hành', 'Practising'),
        ),
        const SizedBox(height: 6),
        Text(wrKeepCompounds(theme.title), style: _h1),
        const SizedBox(height: 14),

        // ── Điều bạn từng viết ──────────────────────────────────────────
        _WrittenBlock(theme: theme),
        const SizedBox(height: 20),

        // ── Bốn bước làm quen ───────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: WrEyebrow(tr('Bốn bước làm quen', 'Four steps'))),
            Text(
              wrKeepCompounds('$doneCount / ${steps.isEmpty ? kPracticeStageCount : steps.length}'),
              key: const Key('wr_practice_theme_progress'),
              style: _tiny,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          wrKeepCompounds(tr(
            'Cùng với việc thực hành mỗi bước trong công việc hàng ngày, bạn sẽ '
                'làm quen với tâm thế tạo sự chủ động trong trải nghiệm.',
            'As you practise each step in your daily work, you get used to a '
                'stance of taking initiative in what you go through.',
          )),
          style: _tiny.copyWith(height: 1.55),
        ),
        const SizedBox(height: 10),
        if (steps.isEmpty)
          Text(
            wrKeepCompounds(tr('Chủ đề này chưa có bước nào.', 'This theme has no steps yet.')),
            style: _muted,
          )
        else
          WrCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: WrColors.lineSoft,
                    ),
                  _buildStep(
                    theme: theme,
                    enrollment: enrollment,
                    steps: steps,
                    index: i,
                    isDone: completed.contains(steps[i].stepId),
                    isCurrent: i == current,
                    isLocked: locked(steps[i]),
                    note: notes[steps[i].stepId]?.note,
                    chosen: chosen,
                  ),
                ],
              ],
            ),
          ),

        // ── Hết một vòng / Đang duy trì ─────────────────────────────────
        if (allDone) ...[
          const SizedBox(height: 12),
          if (enrollment.completedAt != null)
            _KeepingCard(onOpen: () => context.push('/wr/growth/stance-keep'))
          else
            _RoundDoneCard(
              busy: _busy,
              onMove: () => _moveToKeep(theme, enrollment),
            ),
        ],
      ],
    );
  }

  Widget _buildStep({
    required PracticeTheme theme,
    required PracticeEnrollment? enrollment,
    required List<PracticeStep> steps,
    required int index,
    required bool isDone,
    required bool isCurrent,
    required bool isLocked,
    required String? note,
    required PracticeMentorOption? chosen,
  }) {
    final step = steps[index];
    final last = index == steps.length - 1;
    final isChoose = step.stepOrder == 3;
    final tag = practiceStageTag(step.stepOrder) ?? '';
    final action = practiceStepAction(step.title);
    final hasNote = note?.trim().isNotEmpty ?? false;

    // ── done / next: thu lại một dòng ────────────────────────────────────
    if (isDone || !isCurrent) {
      final extra = !isDone
          ? ''
          : last
          ? (hasNote
                ? tr(' · đã ghi', ' · noted')
                : tr(' · để sau', ' · later'))
          : tr(' · đã thử', ' · tried');
      final title = isChoose && isDone && chosen != null
          ? tr('Thử: ${chosen.title}', 'Tried: ${chosen.title}')
          : action;
      return _StepFrame(
        key: Key('wr_practice_step_${step.stepId}'),
        number: index + 1,
        state: isDone ? _StepState.done : _StepState.next,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wrKeepCompounds('$tag${extra.toUpperCase()}'), style: _slab),
                      const SizedBox(height: 2),
                      Text(
                        wrKeepCompounds(title),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: isDone ? WrColors.text2 : WrColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDone) Text(wrKeepCompounds('›'), style: _tiny),
              ],
            ),
            if (isDone && hasNote) _NoteQuote(note!.trim()),
            // Bước khoá Premium vẫn có lối mở khoá, kể cả khi chưa tới: giấu
            // hẳn thì người dùng không biết mình đang bỏ lỡ gì (§IV).
            if (!isDone && isLocked) _UnlockLink(stepId: step.stepId),
          ],
        ),
      );
    }

    // ── on: bước đang làm ────────────────────────────────────────────────
    final writing = _writingStep == step.stepId;
    final canAct = enrollment != null && !_busy;
    final prompt = practiceStepPrompt(step.stepOrder);
    final desc = step.content?.trim();
    final hideDesc = writing || (isChoose && chosen != null);

    final body = <Widget>[
      Text(wrKeepCompounds(tag), style: _slab),
      const SizedBox(height: 3),
      Text(wrKeepCompounds(action), style: _cardTitle),
      if (!hideDesc && desc != null && desc.isNotEmpty) ...[
        const SizedBox(height: 5),
        Text(wrKeepCompounds(desc), style: _muted),
      ],
    ];

    if (isLocked) {
      body.add(_UnlockLink(stepId: step.stepId));
      return _StepFrame(
        key: Key('wr_practice_step_${step.stepId}'),
        number: index + 1,
        state: _StepState.on,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: body,
        ),
      );
    }

    if (isChoose) {
      if (chosen != null) {
        body.add(_ChosenOption(option: chosen));
      } else {
        body.add(_OpenOptionsRow(onTap: _openOptions));
      }
    }

    // Chưa chọn cách thì chưa có gì để đánh dấu đã thử.
    if (!(isChoose && chosen == null) && canAct) {
      if (writing) {
        body.add(
          _NoteWriter(
            stepId: step.stepId,
            question: prompt.q,
            hint: prompt.ph,
            last: last,
            controller: _note,
            enabled: canAct,
            onSave: (withNote) => _complete(
              theme: theme,
              enrollment: enrollment,
              step: step,
              steps: steps,
              withNote: withNote,
              choice: isChoose ? chosen?.title : null,
            ),
            onCancel: () => setState(() => _writingStep = null),
          ),
        );
      } else {
        body.add(
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Align(
              alignment: Alignment.centerLeft,
              child: WrSmallButton(
                key: Key('wr_practice_step_done_${step.stepId}'),
                label: last
                    ? tr('Ghi lại câu hỏi', 'Write down the question')
                    : isChoose
                    ? tr('Tôi đã thử cách này', 'I tried this way')
                    : tr('Tôi đã thử bước này', 'I tried this step'),
                onTap: () => setState(() {
                  _writingStep = step.stepId;
                  _note.clear();
                }),
              ),
            ),
          ),
        );
        if (isChoose && chosen != null) {
          body.add(
            Center(
              child: TextButton(
                key: const Key('wr_practice_change_option'),
                onPressed: _openOptions,
                style: TextButton.styleFrom(foregroundColor: WrColors.text3),
                child: Text(
                  wrKeepCompounds(tr('Đổi sang cách khác', 'Switch to another way')),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          );
        }
      }
    }

    return _StepFrame(
      key: Key('wr_practice_step_${step.stepId}'),
      number: index + 1,
      state: _StepState.on,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: body,
      ),
    );
  }
}

/// Khung màn: nút lùi tròn + nội dung cuộn.
class _Shell extends StatelessWidget {
  const _Shell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return WrInnerBandBackdrop(
      art: WrHeroArt.act,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: WrBackCircle(
                  key: const Key('wr_practice_back'),
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go('/wr/growth'),
                ),
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// "ĐIỀU BẠN TỪNG VIẾT" — vạch teal bên trái, chữ nghiêng.
///
/// Chủ đề tự thêm: trích nguyên câu "Điều gì đang xảy ra?" người dùng đã viết
/// (script `t.intake.situation`). Chủ đề thư viện: script chỉ có một câu mẫu,
/// nên dùng mô tả thật của chủ đề, KHÔNG đặt trong ngoặc kép vì đó không phải
/// lời người dùng.
class _WrittenBlock extends StatelessWidget {
  const _WrittenBlock({required this.theme});

  final PracticeTheme theme;

  @override
  Widget build(BuildContext context) {
    final situation = theme.isUserAdded ? theme.intake?.situation.trim() : null;
    final description = theme.description?.trim();
    final text = (situation != null && situation.isNotEmpty)
        ? '“$situation”'
        : (description != null && description.isNotEmpty)
        ? description
        : tr(
            'Bạn đã từng nhìn lại những tình huống liên quan đến chủ đề này. '
                'Không cần làm lại giống lần trước; lần này bạn có thể chọn một '
                'cách khác.',
            'You have looked back on situations related to this theme. No need '
                'to repeat last time; this time you can pick a different way.',
          );
    return Container(
      key: const Key('wr_practice_written'),
      padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: WrColors.teal.withValues(alpha: 0.45),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wrKeepCompounds(tr('ĐIỀU BẠN TỪNG VIẾT', 'WHAT YOU ONCE WROTE')),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: WrColors.pillTealText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            wrKeepCompounds(text),
            style: WrText.serifQuote(
              fontSize: 15,
              color: WrColors.navy,
              height: 1.58,
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, on, next }

/// `.pstep`: số thứ tự tròn bên trái + nội dung.
class _StepFrame extends StatelessWidget {
  const _StepFrame({
    super.key,
    required this.number,
    required this.state,
    required this.child,
  });

  final int number;
  final _StepState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      _StepState.done => (
        WrColors.teal.withValues(alpha: 0.16),
        WrColors.pillTealText,
      ),
      _StepState.on => (WrColors.teal, WrColors.white),
      _StepState.next => (
        WrColors.navy.withValues(alpha: 0.07),
        WrColors.text3,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
            child: state == _StepState.done
                ? Icon(Icons.check, size: 13, color: fg)
                : Text(
                    wrKeepCompounds('$number'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
          ),
          const SizedBox(width: 11),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// "Premium · Mở khoá" dẫn sang paywall `practice_step`.
class _UnlockLink extends StatelessWidget {
  const _UnlockLink({required this.stepId});

  final String stepId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        key: Key('wr_practice_step_unlock_$stepId'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/wr/paywall?trigger=practice_step'),
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
              wrKeepCompounds(tr('Premium · Mở khoá', 'Premium · Unlock')),
              style: _tiny.copyWith(
                color: WrColors.pillCoralText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.pnote` — ghi chú của bước đã thử.
class _NoteQuote extends StatelessWidget {
  const _NoteQuote(this.note);

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 7),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: WrColors.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        wrKeepCompounds('“$note”'),
        style: WrText.serifQuote(
          fontSize: 14,
          color: WrColors.navy,
          height: 1.55,
        ),
      ),
    );
  }
}

/// `.p-open` — "Xem ba cách gợi ý ›".
class _OpenOptionsRow extends StatelessWidget {
  const _OpenOptionsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('wr_practice_open_options'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: WrColors.teal.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: WrColors.teal.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                wrKeepCompounds(tr('Xem ba cách gợi ý', 'See three suggested ways')),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: WrColors.pillTealText,
                ),
              ),
            ),
            const Text(
              '›',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: WrColors.pillTealText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.p-opt.on` — cách đang thử, ở lại trên màn sau khi chọn.
class _ChosenOption extends StatelessWidget {
  const _ChosenOption({required this.option});

  final PracticeMentorOption option;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_practice_choice'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: WrColors.coral.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WrColors.coral, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(wrKeepCompounds(option.title), style: _cardTitle),
          if (option.fit.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              wrKeepCompounds(option.fit),
              style: const TextStyle(
                fontSize: 13.5,
                color: WrColors.text2,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 7),
          Text(
            wrKeepCompounds(tr('✓ Cách bạn đang thử', '✓ The way you are trying')),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: WrColors.coral,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô ghi khi bấm "Tôi đã thử bước này": câu hỏi riêng của bước (script
/// `STEP_PROMPTS`) · Lưu lại · Chỉ đánh dấu (bước cuối: Chưa có) · Để sau.
class _NoteWriter extends StatefulWidget {
  const _NoteWriter({
    required this.stepId,
    required this.question,
    required this.hint,
    required this.last,
    required this.controller,
    required this.enabled,
    required this.onSave,
    required this.onCancel,
  });

  final String stepId;
  final String question;
  final String hint;
  final bool last;
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
      padding: const EdgeInsets.only(top: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            wrKeepCompounds(widget.question),
            key: const Key('wr_practice_note_question'),
            style: _tiny.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          WrVoiceField(
            fieldKey: const Key('wr_practice_note_field'),
            controller: widget.controller,
            hintText: widget.hint,
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
                  label: widget.last
                      ? tr('Chưa có', 'Not yet')
                      : tr('Chỉ đánh dấu', 'Just mark it'),
                  onTap: widget.enabled ? () => widget.onSave(false) : null,
                ),
              ),
            ],
          ),
          if (widget.last)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                wrKeepCompounds(tr(
                  'Chưa nghĩ ra cũng không sao. Quay lại khi bạn nghĩ ra.',
                  'It is fine if nothing comes yet. Come back when it does.',
                )),
                key: const Key('wr_practice_note_last_hint'),
                textAlign: TextAlign.center,
                style: _tiny.copyWith(height: 1.5),
              ),
            )
          else
            Center(
              child: TextButton(
                key: const Key('wr_practice_note_later'),
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(foregroundColor: WrColors.text3),
                child: Text(
                  wrKeepCompounds(tr('Để sau', 'Later')),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "HẾT MỘT VÒNG" — hết các bước, chưa đưa vào duy trì.
class _RoundDoneCard extends StatelessWidget {
  const _RoundDoneCard({required this.busy, required this.onMove});

  final bool busy;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    return WrCard(
      key: const Key('wr_practice_round_done'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(wrKeepCompounds(tr('HẾT MỘT VÒNG', 'ONE FULL ROUND')), style: _eyebrowTeal),
          const SizedBox(height: 5),
          Text(
            wrKeepCompounds(tr(
              'Bạn vừa đi hết bốn bước',
              'You just went through all four steps',
            )),
            style: _cardTitle,
          ),
          const SizedBox(height: 6),
          Text(
            wrKeepCompounds(tr(
              'Một vòng không phải là xong. Điều vừa thử sẽ cần làm lại vài lần '
                  'nữa mới thành quen.',
              'One round is not the end. What you just tried needs a few more '
                  'goes before it becomes familiar.',
            )),
            style: _muted,
          ),
          const SizedBox(height: 11),
          Align(
            alignment: Alignment.centerLeft,
            child: WrSmallButton(
              key: const Key('wr_practice_move_to_keep'),
              label: tr('Đưa vào phần duy trì', 'Move into upkeep'),
              onTap: busy ? null : onMove,
            ),
          ),
        ],
      ),
    );
  }
}

/// "ĐANG DUY TRÌ" — chủ đề đã đưa vào phần duy trì.
class _KeepingCard extends StatelessWidget {
  const _KeepingCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wr_practice_keeping'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: WrColors.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(WrCard.kRadius),
        border: Border.all(color: WrColors.teal.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(wrKeepCompounds(tr('ĐANG DUY TRÌ', 'IN UPKEEP')), style: _eyebrowTeal),
          const SizedBox(height: 6),
          Text(
            wrKeepCompounds(tr(
              'Chủ đề này đã đi hết một vòng. Giờ nó nằm trong phần duy trì, nơi '
                  'bạn đánh dấu mỗi lần làm lại.',
              'This theme has gone a full round. It now sits in upkeep, where '
                  'you mark each time you do it again.',
            )),
            style: _muted,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: WrSmallButton(
              key: const Key('wr_practice_open_keep'),
              kind: WrSmallButtonKind.ghost,
              label: tr('Xem phần duy trì', 'See upkeep'),
              onTap: onOpen,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.h1` (21px).
const _h1 = TextStyle(
  fontSize: 21,
  fontWeight: FontWeight.w800,
  color: WrColors.navy,
  height: 1.32,
);

/// Chữ đậm 13–13.5px trong thẻ, +1.5.
const _cardTitle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  color: WrColors.navy,
  height: 1.35,
);

/// `.muted` (12.5px) +1.5.
const _muted = TextStyle(fontSize: 14, color: WrColors.text2, height: 1.6);

/// `.tiny` (11px) +1.5.
const _tiny = TextStyle(fontSize: 12.5, color: WrColors.text3);

/// `.slab` (9.5px in hoa) +1.5.
const _slab = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.9,
  color: WrColors.text3,
);

const _eyebrowTeal = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.7,
  color: WrColors.pillTealText,
);

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
