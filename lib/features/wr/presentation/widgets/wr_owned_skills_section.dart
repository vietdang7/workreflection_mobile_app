// Khối "Chứng chỉ, khoá học, kỹ năng đã có" ở màn Thông tin công việc (họp
// khách 01/10/2026, Task D2).
//
// Người dùng khai những gì họ ĐÃ có để app không đề xuất lại: gợi ý chủ đề,
// đối chiếu kỹ năng với JD và trợ lý trò chuyện đều bỏ qua các chủ đề đã tích.
// Khai tay mở cho mọi gói (mặc định Q5).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/wr_tr.dart';
import '../../../../core/models/wr_owned_skill.dart';
import '../../../../core/theme/wr_colors.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/wr_link_row.dart';
import '../../growth_providers.dart';
import '../../owned_skill_providers.dart';
import '../wr_owned_skill_sheet.dart';

class WrOwnedSkillsSection extends ConsumerWidget {
  const WrOwnedSkillsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(wrOwnedSkillsProvider).valueOrNull ?? const [];
    final themes = ref.watch(practiceThemesProvider).valueOrNull ?? const [];
    final titleOf = {for (final t in themes) t.themeId: t.title};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WrEyebrow(
          tr(
            'CHỨNG CHỈ, KHOÁ HỌC, KỸ NĂNG ĐÃ CÓ',
            'CERTIFICATES, COURSES, SKILLS YOU HAVE',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            'Khai những gì bạn đã có để app không gợi ý lại. (Không bắt buộc)',
            'List what you already have so the app does not suggest it '
                'again. (Optional)',
          ),
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.65,
            color: WrColors.muted,
          ),
        ),
        const SizedBox(height: 10),
        for (final s in skills)
          _OwnedSkillTile(
            key: Key('wr_work_info_owned_skill_${s.id}'),
            skill: s,
            themeTitles: [
              for (final id in s.themeIds)
                if (titleOf[id] case final t?) t,
            ],
          ),
        WrLinkRow(
          key: const Key('wr_work_info_owned_skill_add'),
          label: tr(
            'Thêm chứng chỉ, khoá học hoặc kỹ năng',
            'Add a certificate, course or skill',
          ),
          onTap: () => showOwnedSkillSheet(context),
        ),
      ],
    );
  }
}

class _OwnedSkillTile extends StatelessWidget {
  const _OwnedSkillTile({
    super.key,
    required this.skill,
    required this.themeTitles,
  });

  final WrOwnedSkill skill;
  final List<String> themeTitles;

  IconData get _icon => switch (skill.kind) {
    OwnedSkillKind.certificate => Icons.workspace_premium_outlined,
    OwnedSkillKind.course => Icons.school_outlined,
    OwnedSkillKind.skill => Icons.handyman_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final meta = [
      skill.kind.label,
      if (skill.issuer != null && skill.issuer!.isNotEmpty) skill.issuer!,
      if (skill.completedOn != null) '${skill.completedOn!.year}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showOwnedSkillSheet(context, existing: skill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: WrColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WrColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: WrColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_icon, size: 19, color: WrColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: WrColors.navy,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: WrColors.muted,
                        height: 1.45,
                      ),
                    ),
                    if (themeTitles.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        tr(
                          'Không gợi ý lại: ${themeTitles.join(', ')}',
                          'Not suggested again: ${themeTitles.join(', ')}',
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: WrColors.pillTealText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: WrColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
