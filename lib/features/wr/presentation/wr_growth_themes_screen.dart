// Thực hành khác — màn riêng, mở từ tab Phát triển.
//
// Tab Phát triển chỉ giữ chủ đề đang thực hành và bước kế tiếp. Danh sách chủ
// đề chưa bắt đầu nằm ở đây, để mỗi màn chỉ có một việc cần làm.
//
// Bản miễn phí mở tối đa 2 chủ đề cùng lúc (yêu cầu khách 2026-07-27) —
// vượt quota thì dòng chủ đề dẫn sang paywall thay vì nút bắt đầu.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/wr_detail_scaffold.dart';
import '../growth_providers.dart';
import '../wr_providers.dart';

class WrGrowthThemesScreen extends ConsumerStatefulWidget {
  const WrGrowthThemesScreen({super.key});

  @override
  ConsumerState<WrGrowthThemesScreen> createState() =>
      _WrGrowthThemesScreenState();
}

class _WrGrowthThemesScreenState extends ConsumerState<WrGrowthThemesScreen> {
  final Set<String> _enrolling = {};

  Future<void> _enroll(String themeId) async {
    if (_enrolling.contains(themeId)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _enrolling.add(themeId));
    try {
      await ref.read(wrIntelligenceRepositoryProvider).enrollTheme(
            PracticeEnrollment(
              userId: userId,
              themeId: themeId,
              completedSteps: const [],
            ),
          );
      ref.invalidate(practiceEnrollmentsProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không bắt đầu được. Thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _enrolling.remove(themeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final enrollments =
        ref.watch(practiceEnrollmentsProvider).valueOrNull ?? const [];
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);

    final enrolledIds = enrollments.map((e) => e.themeId).toSet();
    final available =
        themes.where((t) => !enrolledIds.contains(t.themeId)).toList();
    final activeCount = enrollments.where((e) => e.completedAt == null).length;
    final canEnroll = entitlement.canEnrollPracticeTheme(activeCount);
    final quota = entitlement.maxActivePracticeThemes;

    return WrDetailScaffold(
      eyebrow: 'THỰC HÀNH KHÁC',
      title: 'Chủ đề bạn có thể bắt đầu',
      children: [
        if (quota != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              canEnroll
                  ? 'Bạn đang mở $activeCount/$quota chủ đề.'
                  : 'Bản miễn phí mở tối đa $quota chủ đề cùng lúc. '
                      'Hoàn thành một chủ đề để mở chỗ mới.',
              key: const Key('wr_growth_themes_quota'),
              style: const TextStyle(
                fontSize: 14,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
          ),
        if (available.isEmpty)
          const Text(
            'Bạn đã bắt đầu tất cả chủ đề hiện có.',
            style: TextStyle(fontSize: 14, color: WrColors.muted, height: 1.6),
          )
        else
          ...available.map(
            (t) => _ThemeRow(
              key: Key('wr_growth_theme_${t.themeId}'),
              theme: t,
              canEnroll: canEnroll,
              isEnrolling: _enrolling.contains(t.themeId),
              onEnroll: () => _enroll(t.themeId),
              onPaywall: () => context.push('/wr/paywall'),
            ),
          ),
      ],
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    super.key,
    required this.theme,
    required this.canEnroll,
    required this.isEnrolling,
    required this.onEnroll,
    required this.onPaywall,
  });

  final PracticeTheme theme;
  final bool canEnroll;
  final bool isEnrolling;
  final VoidCallback onEnroll;
  final VoidCallback onPaywall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            theme.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: WrColors.navy,
              height: 1.35,
            ),
          ),
          if (theme.description != null) ...[
            const SizedBox(height: 6),
            Text(
              theme.description!,
              style: const TextStyle(
                fontSize: 14,
                color: WrColors.muted,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (canEnroll)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isEnrolling ? null : onEnroll,
                style: TextButton.styleFrom(
                  backgroundColor: WrColors.navy,
                  foregroundColor: WrColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isEnrolling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: WrColors.white,
                          strokeWidth: 1.5,
                        ),
                      )
                    : const Text(
                        'Bắt đầu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            )
          else
            GestureDetector(
              onTap: onPaywall,
              child: const Text(
                '⭐ Premium',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD4A017),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
