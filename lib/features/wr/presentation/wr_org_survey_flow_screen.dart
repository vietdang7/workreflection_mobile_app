// Khảo sát tổ chức — luồng trả lời. Mockup Sprint 2, `screenEsiFlow` +
// `screenEnpsQuestion`.
//
// Một màn một câu, chọn xong tự sang câu sau sau ~220ms. Câu cuối là eNPS với
// lưới 0..10, khác thang 5 mức của 12 câu trước — nên nó là một bước riêng chứ
// không phải câu thứ 13 cùng kiểu.
//
// Chưa gửi gì lên máy chủ cho tới khi trả lời xong câu cuối. Ghi dần từng câu
// sẽ tạo ra những bản ghi dở dang của người chỉ mở ra xem rồi thoát — và những
// bản ghi đó sẽ chảy thẳng vào mặt bằng chung của mọi người.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_org_survey_repository.dart';
import '../../../core/models/wr_org_survey.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../org_survey_providers.dart';

class WrOrgSurveyFlowScreen extends ConsumerStatefulWidget {
  const WrOrgSurveyFlowScreen({super.key});

  @override
  ConsumerState<WrOrgSurveyFlowScreen> createState() =>
      _WrOrgSurveyFlowScreenState();
}

class _WrOrgSurveyFlowScreenState extends ConsumerState<WrOrgSurveyFlowScreen> {
  final Map<String, int> _answers = {};
  int? _enps;
  int _index = 0;
  bool _submitting = false;
  String? _error;

  bool get _hasAnything => _answers.isNotEmpty || _enps != null;

  void _answer(String questionId, int value) {
    setState(() => _answers[questionId] = value);
    _advanceSoon();
  }

  void _answerEnps(int value) {
    setState(() => _enps = value);
    _advanceSoon();
  }

  void _advanceSoon() {
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      final total = ref.read(wrOrgSurveyQuestionsProvider).valueOrNull?.length;
      if (total == null) return;
      if (_index >= total) {
        _submit();
      } else {
        setState(() => _index++);
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(wrOrgSurveyRepositoryProvider)
          .submit(answers: _answers, enps: _enps);
      // Thẻ trên màn Hồ sơ và mặt bằng chung đều vừa cũ đi: câu trả lời này đã
      // là một phần của mẫu.
      ref.invalidate(wrOrgSurveyLatestProvider);
      ref.invalidate(wrOrgSurveyBenchmarkProvider);
      if (!mounted) return;
      // `pushReplacement`: quay lại từ màn kết quả phải về Hồ sơ, không rơi
      // ngược vào câu cuối của bài vừa làm xong.
      context.pushReplacement('/wr/org-survey/result', extra: saved);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Chưa gửi được câu trả lời. Bạn thử lại nhé.';
      });
    }
  }

  Future<void> _close() async {
    // Bỏ giữa chừng là mất hết, vì chưa có gì được ghi. Hỏi lại một câu trước
    // khi mất 12 câu vừa trả lời.
    if (_hasAnything) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Thoát khảo sát?'),
          content: const Text(
            'Câu trả lời chưa được gửi đi. Thoát bây giờ là mất hết.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Ở lại'),
            ),
            TextButton(
              key: const Key('wr_org_survey_leave_confirm'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Thoát'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  void _back() {
    if (_index == 0) {
      _close();
    } else {
      setState(() => _index--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions =
        ref.watch(wrOrgSurveyQuestionsProvider).valueOrNull ?? const [];
    if (questions.isEmpty) {
      return const Scaffold(
        backgroundColor: WrColors.pageBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final total = questions.length + 1; // +1 cho câu eNPS
    final isEnps = _index >= questions.length;

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(
              progress: (_index + 1) / total,
              onBack: _submitting ? null : _back,
              onClose: _submitting ? null : _close,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
              child: WrEyebrow(
                isEnps
                    ? 'CÂU $total / $total, CÂU CUỐI'
                    : 'CÂU ${_index + 1} / $total',
              ),
            ),
            Expanded(
              child: isEnps
                  ? _EnpsStep(
                      selected: _enps,
                      onSelect: _submitting ? null : _answerEnps,
                    )
                  : _ScaleStep(
                      question: questions[_index],
                      selected: _answers[questions[_index].id],
                      onSelect: _submitting
                          ? null
                          : (v) => _answer(questions[_index].id, v),
                    ),
            ),
            if (_submitting)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Center(
                  child: Text(
                    'Đang gửi…',
                    style: TextStyle(fontSize: 14, color: WrColors.muted),
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      key: const Key('wr_org_survey_submit_error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: WrColors.coral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('wr_org_survey_retry'),
                      onPressed: _submit,
                      child: const Text('Gửi lại'),
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

// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.progress,
    required this.onBack,
    required this.onClose,
  });

  final double progress;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('wr_org_survey_back'),
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
            color: WrColors.navy,
            onPressed: onBack,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                key: const Key('wr_org_survey_progress'),
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: WrColors.line,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(WrColors.navy),
              ),
            ),
          ),
          TextButton(
            key: const Key('wr_org_survey_close'),
            onPressed: onClose,
            child: const Text(
              'Đóng',
              style: TextStyle(fontSize: 14, color: WrColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// 12 câu thang 5 mức hài lòng.
class _ScaleStep extends StatelessWidget {
  const _ScaleStep({
    required this.question,
    required this.selected,
    required this.onSelect,
  });

  final OrgSurveyQuestion question;
  final int? selected;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      children: [
        Text(
          question.text,
          key: const Key('wr_org_survey_question_text'),
          style: const TextStyle(
            fontSize: 17,
            height: 1.55,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
        const SizedBox(height: 26),
        for (final (i, label) in kOrgSurveyScale.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Option(
              key: Key('wr_org_survey_option_$i'),
              label: label,
              selected: selected == i,
              onTap: onSelect == null ? null : () => onSelect!(i),
            ),
          ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? WrColors.coral.withValues(alpha: 0.10)
                : WrColors.white,
            border: Border.all(
              width: 1.5,
              color: selected ? WrColors.coral : WrColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: WrColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

/// Câu cuối: eNPS 0..10.
class _EnpsStep extends StatelessWidget {
  const _EnpsStep({required this.selected, required this.onSelect});

  final int? selected;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      children: [
        const Text(
          'Trên thang từ 0 đến 10, bạn sẽ giới thiệu nơi mình đang làm việc cho '
          'bạn bè hoặc người quen ở mức nào?',
          style: TextStyle(
            fontSize: 17,
            height: 1.55,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '0 là chắc chắn không, 10 là chắc chắn có.',
          style: TextStyle(fontSize: 14, color: WrColors.muted),
        ),
        const SizedBox(height: 22),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 6,
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          children: [
            for (var n = 0; n <= kEnpsMaxScore; n++)
              Semantics(
                button: true,
                selected: selected == n,
                child: InkWell(
                  key: Key('wr_org_survey_enps_$n'),
                  onTap: onSelect == null ? null : () => onSelect!(n),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: selected == n
                          ? WrColors.coral.withValues(alpha: 0.10)
                          : WrColors.white,
                      border: Border.all(
                        width: 1.5,
                        color:
                            selected == n ? WrColors.coral : WrColors.line,
                      ),
                    ),
                    child: Text(
                      '$n',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: WrColors.navy,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
