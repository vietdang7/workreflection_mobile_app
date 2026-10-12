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
import '../../../core/widgets/wr_card.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../../../core/widgets/wr_hero_header.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';

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
      await ref.read(wrIntelligenceRepositoryProvider).setPendingChoice(
            userId: userId,
            themeId: widget.themeId,
            choice: option.title,
          );
      ref.invalidate(practiceEnrollmentsProvider);
      if (mounted) context.pop(option.id);
    } catch (_) {
      if (mounted) context.pop(option.id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final enrollments =
        ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];
    final theme =
        themes.where((t) => t.themeId == widget.themeId).firstOrNull;
    final enrollment =
        enrollments.where((e) => e.themeId == widget.themeId).firstOrNull;

    if (theme == null) {
      return Scaffold(
        backgroundColor: WrColors.pageBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            tr('Không tìm thấy chủ đề', 'Theme not found'),
            style: const TextStyle(fontSize: 16, color: WrColors.muted),
          ),
        ),
      );
    }

    final options = mentorOptionsFor(theme);
    final chosenTitle = enrollment?.pendingChoice;

    return WrDetailScaffold(
      art: WrHeroArt.act,
      eyebrow: tr('BƯỚC 3 · ${theme.title}', 'STEP 3 · ${theme.title}'),
      title: tr('Bạn muốn thử cách nào?', 'Which way do you want to try?'),
      children: [
        Text(
          tr(
            'Không có cách đúng nhất. Mỗi cách hợp với một hoàn cảnh khác nhau. Chọn một cách để mang ra thử, đổi lại lúc nào cũng được.',
            'There is no single right way. Each fits a different context. Pick one way to try out. You can change it anytime.',
          ),
          style: const TextStyle(
            fontSize: 14,
            color: WrColors.text2,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _OptionCard(
            index: i + 1,
            option: options[i],
            isChosen: chosenTitle == options[i].title,
            busy: _saving,
            onTap: () => _pickOption(options[i]),
          ),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
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
    return WrCard(
      onTap: busy ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('CÁCH $index', 'WAY $index'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: WrColors.text3,
                  letterSpacing: 0.5,
                ),
              ),
              if (isChosen)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: WrColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    tr('✓ Cách bạn đang thử', '✓ The way you are trying'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.pillTealText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            option.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.35,
            ),
          ),
          if (option.fit.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              option.fit,
              style: const TextStyle(
                fontSize: 13.5,
                color: WrColors.text2,
                height: 1.55,
              ),
            ),
          ],
          if (option.tradeoff.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${tr('Đánh đổi', 'Trade-off')}: ${option.tradeoff}',
              style: const TextStyle(
                fontSize: 12.5,
                color: WrColors.text3,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              isChosen
                  ? tr('Đang chọn', 'Selected')
                  : tr('Chọn cách này ›', 'Pick this way ›'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isChosen ? WrColors.teal : WrColors.pillTealText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
