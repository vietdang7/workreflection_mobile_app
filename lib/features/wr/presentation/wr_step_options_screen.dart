// Màn hình chọn 1 trong 3 cách gợi ý ở Bước 3 — Sprint 2 `screenStepOptions`.
// Tách ra màn riêng để bảng thực hành không bị tràn ngập chữ.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/logic/wr_practice_v47.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';
import 'package:workreflection_mobile/core/widgets/wr_paragraph.dart';

class WrStepOptionsScreen extends ConsumerStatefulWidget {
  const WrStepOptionsScreen({super.key, required this.themeId});

  final String themeId;

  @override
  ConsumerState<WrStepOptionsScreen> createState() =>
      _WrStepOptionsScreenState();
}

class _WrStepOptionsScreenState extends ConsumerState<WrStepOptionsScreen> {
  bool _saving = false;

  Future<void> _pickOption(PracticeMentorOption option) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _saving) return;

    setState(() => _saving = true);
    try {
      // Lưu `id` của cách, không lưu tên: tên đổi theo ngôn ngữ, id thì không.
      await ref
          .read(wrIntelligenceRepositoryProvider)
          .setPendingChoice(
            userId: userId,
            themeId: widget.themeId,
            choice: option.id,
          );
      ref.invalidate(practiceEnrollmentsProvider);
    } catch (_) {
      // Lưu hỏng thì vẫn quay lại màn chủ đề; người dùng chọn lại được.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    // Script `pickStepOption`: chọn xong là về màn chủ đề.
    if (mounted) context.pop(option.id);
  }

  @override
  Widget build(BuildContext context) {
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final enrollments =
        ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];
    final theme = themes.where((t) => t.themeId == widget.themeId).firstOrNull;
    final enrollment = enrollments
        .where((e) => e.themeId == widget.themeId)
        .firstOrNull;

    if (theme == null) {
      return Scaffold(
        backgroundColor: WrColors.pageBg,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Text(
            wrKeepCompounds(tr('Không tìm thấy chủ đề', 'Theme not found')),
            style: const TextStyle(fontSize: 16, color: WrColors.muted),
          ),
        ),
      );
    }

    final options = step3OptionsFor(theme);
    final chosen = findPracticeOption(options, enrollment?.pendingChoice);
    final steps =
        ref.watch(practiceStepsProvider(widget.themeId)).valueOrNull ??
        const <PracticeStep>[];
    final step3 = steps.where((s) => s.stepOrder == 3).firstOrNull;
    final footer = step3?.content?.trim();

    return WrDetailScaffold(
      art: WrHeroArt.act,
      eyebrow: tr('BƯỚC 3 · ${theme.title}', 'STEP 3 · ${theme.title}'),
      title: tr('Bạn muốn thử cách nào?', 'Which way do you want to try?'),
      children: [
        Text(
          wrKeepCompounds(tr(
            'Không có cách đúng nhất. Mỗi cách hợp với một hoàn cảnh khác nhau. Chọn một cách để mang ra thử, đổi lại lúc nào cũng được.',
            'There is no single right way. Each fits a different context. Pick one way to try out. You can change it anytime.',
          )),
          style: const TextStyle(
            fontSize: 14,
            color: WrColors.text2,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 11),
          _OptionCard(
            key: Key('wr_step_option_${options[i].id}'),
            index: i + 1,
            option: options[i],
            isChosen: chosen?.id == options[i].id,
            busy: _saving,
            onTap: () => _pickOption(options[i]),
          ),
        ],
        // Script: chân trang là mô tả của bước 3.
        if (footer != null && footer.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            wrKeepCompounds(footer),
            key: const Key('wr_step_options_footer'),
            style: const TextStyle(
              fontSize: 12.5,
              color: WrColors.text3,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}

/// `.p-opt` — một cách: số thứ tự, tên cách, một dòng "hợp khi".
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.index,
    required this.option,
    required this.isChosen,
    required this.busy,
    required this.onTap,
  });

  final int index;
  final PracticeMentorOption option;
  final bool isChosen;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
        decoration: BoxDecoration(
          color: isChosen
              ? WrColors.coral.withValues(alpha: 0.045)
              : WrColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isChosen ? WrColors.coral : WrColors.line,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wrKeepCompounds(tr('CÁCH $index', 'WAY $index')),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WrColors.text3,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              wrKeepCompounds(option.title),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: WrColors.navy,
                height: 1.35,
              ),
            ),
            if (option.fit.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                wrKeepCompounds(option.fit),
                style: const TextStyle(
                  fontSize: 14,
                  color: WrColors.text2,
                  height: 1.6,
                ),
              ),
            ],
            SizedBox(height: isChosen ? 9 : 10),
            Text(
              wrKeepCompounds(isChosen
                  ? tr('✓ Cách bạn đang thử', '✓ The way you are trying')
                  : tr('Chọn cách này ›', 'Pick this way ›')),
              style: TextStyle(
                fontSize: isChosen ? 13 : 12.5,
                fontWeight: FontWeight.w700,
                color: isChosen ? WrColors.coral : WrColors.pillTealText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
